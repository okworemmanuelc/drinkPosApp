-- =============================================================================
-- 0006_domain_rpcs.sql — Atomic domain RPCs that collapse multi-table sync
-- traffic into one server-side transaction per business action.
--
-- Background: the client outbox (sync_queue) currently emits one row per
-- table touched by a single business action. A 3-item cash sale produces
-- ~11 outbox rows (1 order + 3 items + 3 inventory + 3 stock_transactions +
-- 1 payment_transaction + optional 1 wallet_transaction), each pushed
-- separately via PostgREST. The new RPCs let the client enqueue ONE
-- domain envelope (action_type 'domain:pos_record_sale' etc.) which is
-- pushed via _supabase.rpc(...) and applied atomically.
--
-- Why server-side atomic for inventory: with client-LWW on absolute
-- quantity, two devices selling the same product simultaneously each
-- compute (qty - units_sold) locally and the cloud upsert keeps the later
-- write — silently overwriting one of the decrements. The new RPC sends
-- the *delta* and the server runs UPDATE inventory SET quantity =
-- quantity + delta WHERE quantity + delta >= 0 RETURNING. Postgres takes
-- a row-level lock on the matched row so concurrent calls serialize; the
-- second one either succeeds with a smaller-but-correct quantity or
-- raises P0001 'insufficient_stock' and the whole RPC rolls back.
--
-- Idempotency under retry: every row carries a client-generated UUIDv7,
-- and every INSERT uses ON CONFLICT (id) DO NOTHING. Append-only ledger
-- triggers (0001_initial.sql:876-903) fire only on UPDATE/DELETE so DO
-- NOTHING is safe. The orders insert uses ON CONFLICT (id) DO NOTHING
-- inside a CTE so a retry after a network blip is detected as "order
-- already exists" and the function returns existing state without
-- reapplying the inventory deltas.
--
-- SECURITY DEFINER + manual tenant guard: matches the pattern of
-- pos_pull_snapshot in 0005_sync_rpcs.sql. Functions run as the function
-- owner and bypass RLS; the explicit business_id() check is what
-- enforces tenant isolation.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. pos_record_sale — single-transaction checkout.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.pos_record_sale(
  p_business_id     uuid,
  p_order           jsonb,
  p_items           jsonb,            -- JSON array of order_items rows
  p_stock_movements jsonb,            -- JSON array: {id, product_id, location_id, quantity_delta (negative), order_id?, performed_by?}
  p_payment         jsonb DEFAULT NULL,  -- single payment_transactions row, optional
  p_wallet_tx       jsonb DEFAULT NULL   -- single wallet_transactions row, optional
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_caller_business uuid;
  v_order_id        uuid;
  v_is_new_sale     boolean := false;
  v_order_lua       timestamptz;
  v_mv              jsonb;
  v_new_qty         int;
  v_inv_after       jsonb := '[]'::jsonb;
  v_stx_ids         jsonb := '[]'::jsonb;
  v_payment_id      uuid;
  v_wallet_tx_id    uuid;
BEGIN
  -- Tenant guard
  v_caller_business := public.business_id();
  IF v_caller_business IS NULL THEN
    RAISE EXCEPTION 'no_business_for_caller' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF v_caller_business <> p_business_id THEN
    RAISE EXCEPTION 'tenant_mismatch' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF (p_order->>'business_id')::uuid <> p_business_id THEN
    RAISE EXCEPTION 'order_business_id_mismatch' USING ERRCODE = 'insufficient_privilege';
  END IF;

  v_order_id := (p_order->>'id')::uuid;
  IF v_order_id IS NULL THEN
    RAISE EXCEPTION 'order_id_required' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- Idempotent order insert. ON CONFLICT DO NOTHING + CTE detects whether
  -- this is a fresh sale or a retry of a previously-applied one.
  WITH ins AS (
    INSERT INTO public.orders
    SELECT (jsonb_populate_record(NULL::public.orders, p_order)).*
    ON CONFLICT (id) DO NOTHING
    RETURNING id
  )
  SELECT COUNT(*) > 0 INTO v_is_new_sale FROM ins;

  IF NOT v_is_new_sale THEN
    -- Retry of an already-applied sale. Compose response from existing state
    -- and return without re-running the inventory deltas.
    SELECT last_updated_at INTO v_order_lua FROM public.orders WHERE id = v_order_id;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'product_id',      i.product_id,
             'warehouse_id',    i.warehouse_id,
             'quantity',        i.quantity,
             'last_updated_at', i.last_updated_at)), '[]'::jsonb)
      INTO v_inv_after
      FROM public.inventory i
      JOIN jsonb_array_elements(p_stock_movements) AS m ON
           i.product_id   = (m->>'product_id')::uuid
       AND i.warehouse_id = (m->>'location_id')::uuid
     WHERE i.business_id = p_business_id;

    RETURN jsonb_build_object(
      'order_id',              v_order_id,
      'order_last_updated_at', v_order_lua,
      'inventory_after',       v_inv_after,
      'stock_transaction_ids', v_stx_ids,
      'payment_transaction_id', NULL,
      'wallet_transaction_id',  NULL,
      'replayed',              true
    );
  END IF;

  -- Items (append-only from the client's perspective)
  INSERT INTO public.order_items
  SELECT (jsonb_populate_record(NULL::public.order_items, item)).*
    FROM jsonb_array_elements(p_items) AS item
  ON CONFLICT (id) DO NOTHING;

  -- Atomic inventory deltas. Per movement: row-locked UPDATE that fails if
  -- the resulting quantity would go negative.
  FOR v_mv IN SELECT * FROM jsonb_array_elements(p_stock_movements) LOOP
    IF (v_mv->>'business_id') IS NOT NULL
       AND (v_mv->>'business_id')::uuid <> p_business_id THEN
      RAISE EXCEPTION 'movement_business_id_mismatch' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF (v_mv->>'quantity_delta')::int >= 0 THEN
      RAISE EXCEPTION 'sale_movement_must_be_negative_delta'
        USING ERRCODE = 'invalid_parameter_value';
    END IF;

    UPDATE public.inventory
       SET quantity = quantity + (v_mv->>'quantity_delta')::int
     WHERE business_id  = p_business_id
       AND product_id   = (v_mv->>'product_id')::uuid
       AND warehouse_id = (v_mv->>'location_id')::uuid
       AND quantity + (v_mv->>'quantity_delta')::int >= 0
    RETURNING quantity INTO v_new_qty;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'insufficient_stock'
        USING ERRCODE = 'P0001',
              DETAIL  = format('product_id=%s warehouse_id=%s requested_delta=%s',
                               v_mv->>'product_id',
                               v_mv->>'location_id',
                               v_mv->>'quantity_delta'),
              HINT    = jsonb_build_object(
                          'product_id',   v_mv->>'product_id',
                          'warehouse_id', v_mv->>'location_id',
                          'requested_delta', (v_mv->>'quantity_delta')::int
                        )::text;
    END IF;

    v_inv_after := v_inv_after || jsonb_build_object(
      'product_id',      (v_mv->>'product_id')::uuid,
      'warehouse_id',    (v_mv->>'location_id')::uuid,
      'quantity',        v_new_qty,
      'last_updated_at', now()
    );
  END LOOP;

  -- Stock transaction ledger rows (append-only; trigger forbids UPDATE on
  -- non-void columns but we never UPDATE these).
  INSERT INTO public.stock_transactions
  SELECT (jsonb_populate_record(NULL::public.stock_transactions,
            mv || jsonb_build_object('order_id', v_order_id))).*
    FROM jsonb_array_elements(p_stock_movements) AS mv
  ON CONFLICT (id) DO NOTHING;

  SELECT COALESCE(jsonb_agg((mv->>'id')::uuid), '[]'::jsonb)
    INTO v_stx_ids
    FROM jsonb_array_elements(p_stock_movements) AS mv;

  -- Payment transaction (optional)
  IF p_payment IS NOT NULL THEN
    IF (p_payment->>'business_id')::uuid <> p_business_id THEN
      RAISE EXCEPTION 'payment_business_id_mismatch' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO public.payment_transactions
    SELECT (jsonb_populate_record(NULL::public.payment_transactions, p_payment)).*
    ON CONFLICT (id) DO NOTHING;
    v_payment_id := (p_payment->>'id')::uuid;
  END IF;

  -- Wallet transaction (optional)
  IF p_wallet_tx IS NOT NULL THEN
    IF (p_wallet_tx->>'business_id')::uuid <> p_business_id THEN
      RAISE EXCEPTION 'wallet_tx_business_id_mismatch' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO public.wallet_transactions
    SELECT (jsonb_populate_record(NULL::public.wallet_transactions, p_wallet_tx)).*
    ON CONFLICT (id) DO NOTHING;
    v_wallet_tx_id := (p_wallet_tx->>'id')::uuid;
  END IF;

  SELECT last_updated_at INTO v_order_lua FROM public.orders WHERE id = v_order_id;

  RETURN jsonb_build_object(
    'order_id',              v_order_id,
    'order_last_updated_at', v_order_lua,
    'inventory_after',       v_inv_after,
    'stock_transaction_ids', v_stx_ids,
    'payment_transaction_id', v_payment_id,
    'wallet_transaction_id',  v_wallet_tx_id,
    'replayed',              false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_record_sale(uuid, jsonb, jsonb, jsonb, jsonb, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_record_sale(uuid, jsonb, jsonb, jsonb, jsonb, jsonb)
  TO authenticated, service_role;


-- -----------------------------------------------------------------------------
-- 2. pos_inventory_delta — batch atomic deltas for non-sale movements.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.pos_inventory_delta(
  p_business_id uuid,
  p_movements   jsonb       -- JSON array: {id, product_id, warehouse_id, quantity_delta, movement_type, ref_type, ref_id?, performed_by?}
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_caller_business uuid;
  v_mv              jsonb;
  v_new_qty         int;
  v_inv_after       jsonb := '[]'::jsonb;
  v_stx_ids         jsonb := '[]'::jsonb;
  v_movement_type   text;
  v_ref_type        text;
  v_ref_id          uuid;
BEGIN
  v_caller_business := public.business_id();
  IF v_caller_business IS NULL THEN
    RAISE EXCEPTION 'no_business_for_caller' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF v_caller_business <> p_business_id THEN
    RAISE EXCEPTION 'tenant_mismatch' USING ERRCODE = 'insufficient_privilege';
  END IF;

  FOR v_mv IN SELECT * FROM jsonb_array_elements(p_movements) LOOP
    v_movement_type := v_mv->>'movement_type';
    v_ref_type      := v_mv->>'ref_type';
    v_ref_id        := NULLIF(v_mv->>'ref_id', '')::uuid;

    -- Sales must go through pos_record_sale; that path applies the order
    -- write atomically with the deltas. Allowing a 'sale' here would skip
    -- the order/items/payment writes.
    IF v_movement_type = 'sale' THEN
      RAISE EXCEPTION 'sale_must_use_pos_record_sale'
        USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF v_movement_type NOT IN ('return','damage','transfer_out','transfer_in','purchase_received','adjustment') THEN
      RAISE EXCEPTION 'invalid_movement_type: %', v_movement_type
        USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- Apply delta. Negative deltas use the locked-update guard. Non-negative
    -- deltas upsert (the row may not yet exist for first-time stock-in).
    IF (v_mv->>'quantity_delta')::int < 0 THEN
      UPDATE public.inventory
         SET quantity = quantity + (v_mv->>'quantity_delta')::int
       WHERE business_id  = p_business_id
         AND product_id   = (v_mv->>'product_id')::uuid
         AND warehouse_id = (v_mv->>'warehouse_id')::uuid
         AND quantity + (v_mv->>'quantity_delta')::int >= 0
      RETURNING quantity INTO v_new_qty;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'insufficient_stock'
          USING ERRCODE = 'P0001',
                HINT = jsonb_build_object(
                  'product_id',      v_mv->>'product_id',
                  'warehouse_id',    v_mv->>'warehouse_id',
                  'requested_delta', (v_mv->>'quantity_delta')::int
                )::text;
      END IF;
    ELSE
      INSERT INTO public.inventory (id, business_id, product_id, warehouse_id, quantity)
      VALUES (
        gen_random_uuid(),
        p_business_id,
        (v_mv->>'product_id')::uuid,
        (v_mv->>'warehouse_id')::uuid,
        (v_mv->>'quantity_delta')::int
      )
      ON CONFLICT (business_id, product_id, warehouse_id)
        DO UPDATE SET quantity = public.inventory.quantity + EXCLUDED.quantity
      RETURNING quantity INTO v_new_qty;
    END IF;

    -- Insert ledger row. The CHECK at 0001_initial.sql:529-534 requires
    -- exactly one parent FK; route ref_id by ref_type.
    INSERT INTO public.stock_transactions (
      id, business_id, product_id, location_id, quantity_delta, movement_type,
      order_id, transfer_id, adjustment_id, purchase_id,
      performed_by, created_at, last_updated_at
    )
    VALUES (
      COALESCE((v_mv->>'id')::uuid, gen_random_uuid()),
      p_business_id,
      (v_mv->>'product_id')::uuid,
      (v_mv->>'warehouse_id')::uuid,
      (v_mv->>'quantity_delta')::int,
      v_movement_type,
      CASE WHEN v_ref_type = 'order'      THEN v_ref_id END,
      CASE WHEN v_ref_type = 'transfer'   THEN v_ref_id END,
      CASE WHEN v_ref_type = 'adjustment' THEN v_ref_id END,
      CASE WHEN v_ref_type = 'purchase'   THEN v_ref_id END,
      NULLIF(v_mv->>'performed_by','')::uuid,
      now(), now()
    )
    ON CONFLICT (id) DO NOTHING;

    v_stx_ids := v_stx_ids || jsonb_build_array(COALESCE((v_mv->>'id')::uuid, NULL));
    v_inv_after := v_inv_after || jsonb_build_object(
      'product_id',      (v_mv->>'product_id')::uuid,
      'warehouse_id',    (v_mv->>'warehouse_id')::uuid,
      'quantity',        v_new_qty,
      'last_updated_at', now()
    );
  END LOOP;

  RETURN jsonb_build_object(
    'inventory_after',       v_inv_after,
    'stock_transaction_ids', v_stx_ids
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_inventory_delta(uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_inventory_delta(uuid, jsonb)
  TO authenticated, service_role;


-- -----------------------------------------------------------------------------
-- 3. pos_create_product — product + optional initial stock in one txn.
-- -----------------------------------------------------------------------------
--
-- The stock_transactions CHECK (0001_initial.sql:529-534) requires exactly
-- one of (order_id, transfer_id, adjustment_id, purchase_id) to be non-null
-- on every row. There is no slot for "product-creation initial stock", so
-- we anchor the ledger row to a stock_adjustments row with reason
-- 'initial_stock' — same trick used by InventoryDao.adjustStock locally.

CREATE OR REPLACE FUNCTION public.pos_create_product(
  p_business_id   uuid,
  p_product       jsonb,
  p_initial_stock jsonb DEFAULT NULL   -- {warehouse_id, quantity, performed_by?}
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_caller_business uuid;
  v_product_id      uuid;
  v_product_lua     timestamptz;
  v_qty             int;
  v_warehouse_id    uuid;
  v_adjustment_id   uuid;
  v_stx_id          uuid;
  v_inventory_id    uuid;
  v_new_qty         int;
BEGIN
  v_caller_business := public.business_id();
  IF v_caller_business IS NULL THEN
    RAISE EXCEPTION 'no_business_for_caller' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF v_caller_business <> p_business_id THEN
    RAISE EXCEPTION 'tenant_mismatch' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF (p_product->>'business_id')::uuid <> p_business_id THEN
    RAISE EXCEPTION 'product_business_id_mismatch' USING ERRCODE = 'insufficient_privilege';
  END IF;

  v_product_id := (p_product->>'id')::uuid;
  IF v_product_id IS NULL THEN
    RAISE EXCEPTION 'product_id_required' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- Idempotent product insert. On UPDATE we trust the client's payload —
  -- this is a domain RPC, the client is sending a complete row.
  INSERT INTO public.products
  SELECT (jsonb_populate_record(NULL::public.products, p_product)).*
  ON CONFLICT (id) DO UPDATE SET
    name                = EXCLUDED.name,
    subtitle            = EXCLUDED.subtitle,
    sku                 = EXCLUDED.sku,
    size                = EXCLUDED.size,
    unit                = EXCLUDED.unit,
    retail_price_kobo   = EXCLUDED.retail_price_kobo,
    selling_price_kobo  = EXCLUDED.selling_price_kobo,
    buying_price_kobo   = EXCLUDED.buying_price_kobo,
    category_id         = EXCLUDED.category_id,
    crate_group_id      = EXCLUDED.crate_group_id,
    manufacturer_id     = EXCLUDED.manufacturer_id,
    supplier_id         = EXCLUDED.supplier_id,
    is_available        = EXCLUDED.is_available,
    is_deleted          = EXCLUDED.is_deleted,
    low_stock_threshold = EXCLUDED.low_stock_threshold,
    track_empties       = EXCLUDED.track_empties,
    image_path          = EXCLUDED.image_path,
    last_updated_at     = now();

  SELECT last_updated_at INTO v_product_lua FROM public.products WHERE id = v_product_id;

  IF p_initial_stock IS NOT NULL THEN
    v_qty          := COALESCE((p_initial_stock->>'quantity')::int, 0);
    v_warehouse_id := (p_initial_stock->>'warehouse_id')::uuid;

    IF v_qty > 0 AND v_warehouse_id IS NOT NULL THEN
      -- Anchor for the stock_transactions row.
      INSERT INTO public.stock_adjustments (
        id, business_id, product_id, warehouse_id, quantity_diff, reason, performed_by
      ) VALUES (
        gen_random_uuid(),
        p_business_id,
        v_product_id,
        v_warehouse_id,
        v_qty,
        'initial_stock',
        NULLIF(p_initial_stock->>'performed_by','')::uuid
      )
      RETURNING id INTO v_adjustment_id;

      INSERT INTO public.inventory (id, business_id, product_id, warehouse_id, quantity)
      VALUES (gen_random_uuid(), p_business_id, v_product_id, v_warehouse_id, v_qty)
      ON CONFLICT (business_id, product_id, warehouse_id)
        DO UPDATE SET quantity = public.inventory.quantity + EXCLUDED.quantity
      RETURNING id, quantity INTO v_inventory_id, v_new_qty;

      INSERT INTO public.stock_transactions (
        id, business_id, product_id, location_id, quantity_delta, movement_type,
        adjustment_id, performed_by
      ) VALUES (
        gen_random_uuid(),
        p_business_id,
        v_product_id,
        v_warehouse_id,
        v_qty,
        'adjustment',
        v_adjustment_id,
        NULLIF(p_initial_stock->>'performed_by','')::uuid
      )
      RETURNING id INTO v_stx_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'product_id',             v_product_id,
    'product_last_updated_at', v_product_lua,
    'inventory_id',           v_inventory_id,
    'inventory_quantity',     v_new_qty,
    'stock_adjustment_id',    v_adjustment_id,
    'stock_transaction_id',   v_stx_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_create_product(uuid, jsonb, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_create_product(uuid, jsonb, jsonb)
  TO authenticated, service_role;


-- -----------------------------------------------------------------------------
-- 4. Realtime publication membership check.
--    The client subscribes to a wildcard 'public:*' channel filtered by
--    business_id. The wildcard only delivers events for tables that are
--    members of supabase_realtime; missing tables silently never fire.
--    Add every synced tenant table to the publication.
-- -----------------------------------------------------------------------------

DO $$
DECLARE
  t text;
  synced_tables text[] := ARRAY[
    'businesses','profiles','users','sessions','invites',
    'warehouses','manufacturers','crate_groups','categories','suppliers',
    'products','price_lists',
    'customers','customer_wallets','wallet_transactions',
    'customer_crate_balances','manufacturer_crate_balances','crate_ledger',
    'inventory','crates','stock_transfers','stock_adjustments','stock_transactions',
    'orders','order_items','purchases','purchase_items',
    'drivers','delivery_receipts','saved_carts','pending_crate_returns',
    'payment_transactions',
    'expense_categories','expenses','activity_logs','notifications',
    'settings','system_config'
  ];
  v_in_pub boolean;
BEGIN
  -- The publication may not exist on a fresh non-Supabase database
  -- (self-hosted Postgres without realtime). Skip silently in that case.
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    RAISE NOTICE 'supabase_realtime publication absent; skipping realtime membership step';
    RETURN;
  END IF;

  FOREACH t IN ARRAY synced_tables LOOP
    SELECT EXISTS (
      SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime'
         AND schemaname = 'public'
         AND tablename = t
    ) INTO v_in_pub;
    IF NOT v_in_pub THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
      RAISE NOTICE 'Added % to supabase_realtime', t;
    END IF;
  END LOOP;
END $$;


-- -----------------------------------------------------------------------------
-- 5. Defensive last_updated_at backfill.
--    The schema declares NOT NULL DEFAULT now() (0001_initial.sql:12) and
--    a BEFORE UPDATE trigger keeps it fresh, so this should be a no-op.
--    Cheap insurance against historic rows from before triggers attached.
-- -----------------------------------------------------------------------------

DO $$
DECLARE
  t text;
  synced_tables text[] := ARRAY[
    'businesses','profiles','users','sessions','invites',
    'warehouses','manufacturers','crate_groups','categories','suppliers',
    'products','price_lists',
    'customers','customer_wallets','wallet_transactions',
    'customer_crate_balances','manufacturer_crate_balances','crate_ledger',
    'inventory','crates','stock_transfers','stock_adjustments','stock_transactions',
    'orders','order_items','purchases','purchase_items',
    'drivers','delivery_receipts','saved_carts','pending_crate_returns',
    'payment_transactions',
    'expense_categories','expenses','activity_logs','notifications',
    'settings','system_config'
  ];
BEGIN
  FOREACH t IN ARRAY synced_tables LOOP
    EXECUTE format(
      'UPDATE public.%I SET last_updated_at = COALESCE(last_updated_at, created_at, now()) WHERE last_updated_at IS NULL',
      t
    );
  END LOOP;
END $$;

-- =============================================================================
-- End of 0006_domain_rpcs.sql.
-- =============================================================================
