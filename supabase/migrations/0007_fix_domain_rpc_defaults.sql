-- =============================================================================
-- 0007_fix_domain_rpc_defaults.sql
-- Fix: domain RPCs reject every sale/product with pg_23502 (NOT NULL violation).
--
-- Root cause: pos_record_sale and pos_create_product materialize rows via
--   INSERT INTO T SELECT (jsonb_populate_record(NULL::T, p_payload)).*
-- jsonb_populate_record fills missing JSONB keys with NULL on the seed record,
-- and the resulting INSERT provides every column explicitly, so column DEFAULT
-- clauses do not apply. Any payload that omits a NOT NULL DEFAULT column
-- (e.g. orders.discount_kobo when there's no discount, products.is_available
-- when the client uses Drift's withDefault and Value.absent()) crashes the
-- whole envelope. The atomic envelope means the entire sale (orders, items,
-- inventory deltas, payments, wallet tx) never reaches the cloud, so cross-
-- device sync silently breaks for these tables.
--
-- Fix: inject a defaults-JSONB into the populate call, exploiting the
-- right-wins semantics of `||` so client-provided keys still override.
-- The defaults match the cloud schema in 0001_initial.sql verbatim.
--
-- pos_inventory_delta is unchanged — it uses explicit column-list INSERT,
-- not jsonb_populate_record, and was never affected.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. pos_record_sale — single-transaction checkout.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.pos_record_sale(
  p_business_id     uuid,
  p_order           jsonb,
  p_items           jsonb,
  p_stock_movements jsonb,
  p_payment         jsonb DEFAULT NULL,
  p_wallet_tx       jsonb DEFAULT NULL
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
  -- NOT NULL DEFAULT seeds for tables we populate from JSONB. Keys missing
  -- from the client payload fall back to these; keys present override via ||.
  c_orders_defaults              CONSTANT jsonb := '{
    "discount_kobo": 0,
    "amount_paid_kobo": 0,
    "rider_name": "Pick-up Order",
    "crate_deposit_paid_kobo": 0
  }'::jsonb;
  c_order_items_defaults         CONSTANT jsonb := '{"buying_price_kobo": 0}'::jsonb;
  c_wallet_tx_defaults           CONSTANT jsonb := '{"customer_verified": false}'::jsonb;
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

  -- Idempotent order insert.
  WITH ins AS (
    INSERT INTO public.orders
    SELECT (jsonb_populate_record(
      NULL::public.orders,
      c_orders_defaults || p_order
    )).*
    ON CONFLICT (id) DO NOTHING
    RETURNING id
  )
  SELECT COUNT(*) > 0 INTO v_is_new_sale FROM ins;

  IF NOT v_is_new_sale THEN
    -- Retry of an already-applied sale. Compose response from existing state.
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

  -- Items
  INSERT INTO public.order_items
  SELECT (jsonb_populate_record(
    NULL::public.order_items,
    c_order_items_defaults || item
  )).*
    FROM jsonb_array_elements(p_items) AS item
  ON CONFLICT (id) DO NOTHING;

  -- Atomic inventory deltas.
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

  -- Stock transaction ledger rows. No NOT NULL DEFAULT columns the client
  -- might omit besides timestamps (always set), so no defaults injection.
  INSERT INTO public.stock_transactions
  SELECT (jsonb_populate_record(NULL::public.stock_transactions,
            mv || jsonb_build_object('order_id', v_order_id))).*
    FROM jsonb_array_elements(p_stock_movements) AS mv
  ON CONFLICT (id) DO NOTHING;

  SELECT COALESCE(jsonb_agg((mv->>'id')::uuid), '[]'::jsonb)
    INTO v_stx_ids
    FROM jsonb_array_elements(p_stock_movements) AS mv;

  -- Payment transaction (optional). No NOT NULL DEFAULT columns beyond
  -- timestamps (always client-set).
  IF p_payment IS NOT NULL THEN
    IF (p_payment->>'business_id')::uuid <> p_business_id THEN
      RAISE EXCEPTION 'payment_business_id_mismatch' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO public.payment_transactions
    SELECT (jsonb_populate_record(NULL::public.payment_transactions, p_payment)).*
    ON CONFLICT (id) DO NOTHING;
    v_payment_id := (p_payment->>'id')::uuid;
  END IF;

  -- Wallet transaction (optional).
  IF p_wallet_tx IS NOT NULL THEN
    IF (p_wallet_tx->>'business_id')::uuid <> p_business_id THEN
      RAISE EXCEPTION 'wallet_tx_business_id_mismatch' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO public.wallet_transactions
    SELECT (jsonb_populate_record(
      NULL::public.wallet_transactions,
      c_wallet_tx_defaults || p_wallet_tx
    )).*
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
-- 2. pos_create_product — product + optional initial stock in one txn.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.pos_create_product(
  p_business_id   uuid,
  p_product       jsonb,
  p_initial_stock jsonb DEFAULT NULL
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
  c_products_defaults CONSTANT jsonb := '{
    "unit": "Bottle",
    "retail_price_kobo": 0,
    "selling_price_kobo": 0,
    "buying_price_kobo": 0,
    "is_available": true,
    "is_deleted": false,
    "low_stock_threshold": 5,
    "avg_daily_sales": 0.0,
    "lead_time_days": 0,
    "safety_stock_qty": 0,
    "monthly_target_units": 0,
    "empty_crate_value_kobo": 0,
    "track_empties": false,
    "version": 1
  }'::jsonb;
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
  SELECT (jsonb_populate_record(
    NULL::public.products,
    c_products_defaults || p_product
  )).*
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
