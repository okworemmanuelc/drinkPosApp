-- =============================================================================
-- 0011_domain_rpcs_v2.sql — Phase B of the schema/sync redesign.
--
-- Adds v2 ("thin intent") domain RPCs covering every multi-table operation
-- in the app, not just the original three from 0006. Goal: after the client
-- cuts over (Phase C), every multi-table business action becomes a single
-- atomic RPC envelope, removing all torn-state failure modes.
--
-- Design contract (applies to every v2 RPC):
--
--   Input  — minimal: business_id, actor_id, an idempotency uuid (the
--            primary entity's id, generated client-side as UUIDv7), refs,
--            and action-specific scalars only. No timestamps, no totals,
--            no cache values, no full-row payloads.
--
--   Body   — SECURITY DEFINER, runs as postgres (BYPASSRLS). First call
--            is public._assert_caller_owns_business() to enforce tenant
--            isolation. Server computes timestamps, totals, denorms, and
--            cache deltas. Idempotent under retry via ON CONFLICT (id) DO
--            NOTHING on the primary entity; replay returns the existing
--            state without re-applying side effects. Single PostgreSQL
--            txn — partial failure rolls back the whole envelope.
--
--   Output — jsonb shaped per-RPC, but always carries: (a) the
--            authoritative `last_updated_at` for any header row the
--            client mirrors, (b) the ids of every row written, (c) the
--            cache rows the client should write back via
--            _applyDomainResponse, (d) `replayed: bool` so the client can
--            tell idempotent retries from new applications.
--
-- v1 RPCs (pos_record_sale, pos_inventory_delta, pos_create_product) stay
-- in place during rollout, gated by the existing feature.domain_rpcs.*
-- flags. v2 RPCs get their own flags. Phase E (0012) drops v1 once
-- telemetry shows zero v1 traffic.
--
-- Apply after 0010_schema_redesign.sql.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 0. Shared tenant-guard helper.
--    Every RPC starts with this. Lifting it out keeps the bodies focused.
--    Marked STABLE so PostgreSQL can short-circuit repeated calls in the
--    same statement.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._assert_caller_owns_business(p_business_id uuid)
RETURNS void
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_caller uuid;
BEGIN
  v_caller := public.business_id();
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'no_business_for_caller' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF v_caller <> p_business_id THEN
    RAISE EXCEPTION 'tenant_mismatch' USING ERRCODE = 'insufficient_privilege';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public._assert_caller_owns_business(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public._assert_caller_owns_business(uuid)
  TO authenticated, service_role;


-- =============================================================================
-- 1. pos_record_sale_v2 — atomic checkout.
--    Tables: orders, order_items, stock_transactions, payment_transactions,
--            wallet_transactions, inventory.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pos_record_sale_v2(
  p_business_id             uuid,
  p_actor_id                uuid,
  p_order_id                uuid,           -- idempotency key
  p_order_number            text,
  p_warehouse_id            uuid,
  p_payment_type            text,
  p_items                   jsonb,          -- [{product_id, quantity, unit_price_kobo, buying_price_kobo?, price_snapshot?}]
  p_status                  text DEFAULT 'completed',
  p_customer_id             uuid DEFAULT NULL,
  p_discount_kobo           int  DEFAULT 0,
  p_amount_paid_kobo        int  DEFAULT 0,
  p_crate_deposit_paid_kobo int  DEFAULT 0,
  p_rider_name              text DEFAULT 'Pick-up Order',
  p_barcode                 text DEFAULT NULL,
  p_payment_method          text DEFAULT NULL,   -- required if amount_paid > 0
  p_wallet_amount_kobo      int  DEFAULT 0,      -- portion of amount_paid drawn from wallet
  p_customer_verified       bool DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_total_amount       int;
  v_net_amount         int;
  v_now                timestamptz := now();
  v_inserted           bool := false;
  v_order_lua          timestamptz;
  v_order_row          jsonb;
  v_item               jsonb;
  v_item_id            uuid;
  v_total_kobo         int;
  v_new_qty            int;
  v_stx_id             uuid;
  v_inv_after          jsonb := '[]'::jsonb;
  v_order_items        jsonb := '[]'::jsonb;
  v_stock_txns         jsonb := '[]'::jsonb;
  v_payment_id         uuid;
  v_payment_row        jsonb;
  v_wallet_id          uuid;
  v_wallet_balance     int;
  v_wallet_txn_id      uuid;
  v_wallet_txn_row     jsonb;
BEGIN
  PERFORM public._assert_caller_owns_business(p_business_id);

  IF p_order_id IS NULL THEN
    RAISE EXCEPTION 'order_id_required' USING ERRCODE = 'invalid_parameter_value';
  END IF;
  IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'items_required' USING ERRCODE = 'invalid_parameter_value';
  END IF;
  IF p_amount_paid_kobo > 0 AND p_payment_method IS NULL THEN
    RAISE EXCEPTION 'payment_method_required_when_paid' USING ERRCODE = 'invalid_parameter_value';
  END IF;
  IF p_wallet_amount_kobo > 0 AND p_customer_id IS NULL THEN
    RAISE EXCEPTION 'wallet_payment_requires_customer' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- Server-computed totals.
  SELECT COALESCE(SUM((it->>'quantity')::int * (it->>'unit_price_kobo')::int), 0)
    INTO v_total_amount
    FROM jsonb_array_elements(p_items) AS it;

  v_net_amount := v_total_amount - p_discount_kobo + p_crate_deposit_paid_kobo;

  -- Idempotent order insert.
  WITH ins AS (
    INSERT INTO public.orders (
      id, business_id, order_number, customer_id,
      total_amount_kobo, discount_kobo, net_amount_kobo, amount_paid_kobo,
      payment_type, status, rider_name, barcode,
      staff_id, warehouse_id, crate_deposit_paid_kobo,
      completed_at, cancelled_at, created_at, last_updated_at
    )
    VALUES (
      p_order_id, p_business_id, p_order_number, p_customer_id,
      v_total_amount, p_discount_kobo, v_net_amount, p_amount_paid_kobo,
      p_payment_type, p_status, p_rider_name, p_barcode,
      p_actor_id, p_warehouse_id, p_crate_deposit_paid_kobo,
      CASE WHEN p_status = 'completed' THEN v_now ELSE NULL END,
      NULL, v_now, v_now
    )
    ON CONFLICT (id) DO NOTHING
    RETURNING 1
  )
  SELECT EXISTS(SELECT 1 FROM ins) INTO v_inserted;

  IF NOT v_inserted THEN
    -- Replay path. Compose the response from existing state.
    SELECT to_jsonb(o.*), o.last_updated_at INTO v_order_row, v_order_lua
      FROM public.orders o WHERE o.id = p_order_id;

    SELECT COALESCE(jsonb_agg(to_jsonb(oi.*)), '[]'::jsonb) INTO v_order_items
      FROM public.order_items oi WHERE oi.order_id = p_order_id;

    SELECT COALESCE(jsonb_agg(to_jsonb(stx.*)), '[]'::jsonb) INTO v_stock_txns
      FROM public.stock_transactions stx WHERE stx.order_id = p_order_id;

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'product_id',      i.product_id,
             'warehouse_id',    i.warehouse_id,
             'quantity',        i.quantity,
             'last_updated_at', i.last_updated_at)), '[]'::jsonb)
      INTO v_inv_after
      FROM public.inventory i
      WHERE i.business_id  = p_business_id
        AND i.warehouse_id = p_warehouse_id
        AND i.product_id IN (
          SELECT (it->>'product_id')::uuid FROM jsonb_array_elements(p_items) it
        );

    SELECT to_jsonb(pt.*) INTO v_payment_row
      FROM public.payment_transactions pt
      WHERE pt.order_id = p_order_id AND pt.voided_at IS NULL
      ORDER BY pt.created_at LIMIT 1;

    SELECT to_jsonb(wt.*) INTO v_wallet_txn_row
      FROM public.wallet_transactions wt
      WHERE wt.order_id = p_order_id AND wt.voided_at IS NULL
      ORDER BY wt.created_at LIMIT 1;

    RETURN jsonb_build_object(
      'order',                v_order_row,
      'order_items',          v_order_items,
      'stock_transactions',   v_stock_txns,
      'payment_transaction',  v_payment_row,
      'wallet_transaction',   v_wallet_txn_row,
      'inventory_after',      v_inv_after,
      'replayed',             true
    );
  END IF;

  -- Items + inventory deltas + stock_transactions.
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    IF (v_item->>'quantity')::int <= 0 THEN
      RAISE EXCEPTION 'item_quantity_must_be_positive' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_item_id    := gen_random_uuid();
    v_total_kobo := (v_item->>'quantity')::int * (v_item->>'unit_price_kobo')::int;

    INSERT INTO public.order_items (
      id, business_id, order_id, product_id, warehouse_id,
      quantity, unit_price_kobo, buying_price_kobo, total_kobo, price_snapshot,
      created_at, last_updated_at
    )
    VALUES (
      v_item_id, p_business_id, p_order_id,
      (v_item->>'product_id')::uuid, p_warehouse_id,
      (v_item->>'quantity')::int,
      (v_item->>'unit_price_kobo')::int,
      COALESCE((v_item->>'buying_price_kobo')::int, 0),
      v_total_kobo,
      CASE WHEN v_item ? 'price_snapshot' THEN v_item->'price_snapshot' ELSE NULL END,
      v_now, v_now
    );

    v_order_items := v_order_items || to_jsonb((SELECT oi FROM public.order_items oi WHERE oi.id = v_item_id));

    -- Inventory delta — locked update, fails if would go negative.
    UPDATE public.inventory
       SET quantity = quantity - (v_item->>'quantity')::int
     WHERE business_id  = p_business_id
       AND product_id   = (v_item->>'product_id')::uuid
       AND warehouse_id = p_warehouse_id
       AND quantity    >= (v_item->>'quantity')::int
    RETURNING quantity INTO v_new_qty;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'insufficient_stock'
        USING ERRCODE = 'P0001',
              HINT = jsonb_build_object(
                'product_id',      v_item->>'product_id',
                'warehouse_id',    p_warehouse_id,
                'requested_qty',   (v_item->>'quantity')::int
              )::text;
    END IF;

    v_inv_after := v_inv_after || jsonb_build_object(
      'product_id',      (v_item->>'product_id')::uuid,
      'warehouse_id',    p_warehouse_id,
      'quantity',        v_new_qty,
      'last_updated_at', v_now
    );

    -- Ledger row.
    v_stx_id := gen_random_uuid();
    INSERT INTO public.stock_transactions (
      id, business_id, product_id, location_id, quantity_delta, movement_type,
      order_id, performed_by, created_at, last_updated_at
    )
    VALUES (
      v_stx_id, p_business_id, (v_item->>'product_id')::uuid, p_warehouse_id,
      -(v_item->>'quantity')::int, 'sale',
      p_order_id, p_actor_id, v_now, v_now
    );

    v_stock_txns := v_stock_txns || to_jsonb((SELECT stx FROM public.stock_transactions stx WHERE stx.id = v_stx_id));
  END LOOP;

  -- Payment (optional).
  IF p_amount_paid_kobo > 0 THEN
    v_payment_id := gen_random_uuid();
    INSERT INTO public.payment_transactions (
      id, business_id, amount_kobo, method, type,
      order_id, performed_by, created_at, last_updated_at
    )
    VALUES (
      v_payment_id, p_business_id, p_amount_paid_kobo, p_payment_method, 'sale',
      p_order_id, p_actor_id, v_now, v_now
    );
    SELECT to_jsonb(pt.*) INTO v_payment_row
      FROM public.payment_transactions pt WHERE pt.id = v_payment_id;
  END IF;

  -- Wallet portion (optional).
  IF p_wallet_amount_kobo > 0 THEN
    SELECT id INTO v_wallet_id
      FROM public.customer_wallets
      WHERE business_id = p_business_id AND customer_id = p_customer_id
      LIMIT 1;

    IF v_wallet_id IS NULL THEN
      RAISE EXCEPTION 'customer_wallet_missing' USING ERRCODE = 'P0001';
    END IF;

    SELECT COALESCE(SUM(signed_amount_kobo), 0) INTO v_wallet_balance
      FROM public.wallet_transactions
      WHERE wallet_id = v_wallet_id;
    IF v_wallet_balance < p_wallet_amount_kobo THEN
      RAISE EXCEPTION 'insufficient_wallet_balance'
        USING ERRCODE = 'P0001',
              HINT = jsonb_build_object(
                'wallet_id',      v_wallet_id,
                'available_kobo', v_wallet_balance,
                'requested_kobo', p_wallet_amount_kobo
              )::text;
    END IF;

    v_wallet_txn_id := gen_random_uuid();
    INSERT INTO public.wallet_transactions (
      id, business_id, wallet_id, customer_id, type,
      amount_kobo, signed_amount_kobo, reference_type, order_id,
      performed_by, customer_verified, created_at, last_updated_at
    )
    VALUES (
      v_wallet_txn_id, p_business_id, v_wallet_id, p_customer_id, 'debit',
      p_wallet_amount_kobo, -p_wallet_amount_kobo, 'order_payment', p_order_id,
      p_actor_id, p_customer_verified, v_now, v_now
    );
    SELECT to_jsonb(wt.*) INTO v_wallet_txn_row
      FROM public.wallet_transactions wt WHERE wt.id = v_wallet_txn_id;
  END IF;

  SELECT to_jsonb(o.*), o.last_updated_at INTO v_order_row, v_order_lua
    FROM public.orders o WHERE o.id = p_order_id;

  RETURN jsonb_build_object(
    'order',                v_order_row,
    'order_items',          v_order_items,
    'stock_transactions',   v_stock_txns,
    'payment_transaction',  v_payment_row,
    'wallet_transaction',   v_wallet_txn_row,
    'inventory_after',      v_inv_after,
    'replayed',             false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_record_sale_v2(
  uuid, uuid, uuid, text, uuid, text, jsonb, text, uuid, int, int, int, text, text, text, int, bool
) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_record_sale_v2(
  uuid, uuid, uuid, text, uuid, text, jsonb, text, uuid, int, int, int, text, text, text, int, bool
) TO authenticated, service_role;


-- =============================================================================
-- 2. pos_inventory_delta_v2 — non-sale stock movements.
--    Tables: stock_adjustments (when movement_type='adjustment'),
--            stock_transactions, inventory.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pos_inventory_delta_v2(
  p_business_id uuid,
  p_actor_id    uuid,
  p_movements   jsonb   -- [{movement_id, product_id, warehouse_id, quantity_delta, movement_type, ref_type?, ref_id?, reason?}]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_now           timestamptz := now();
  v_mv            jsonb;
  v_mv_id         uuid;
  v_movement_type text;
  v_ref_type      text;
  v_ref_id        uuid;
  v_adjustment_id uuid;
  v_new_qty       int;
  v_stx_id        uuid;
  v_inv_after     jsonb := '[]'::jsonb;
  v_stock_txns    jsonb := '[]'::jsonb;
  v_adjustments   jsonb := '[]'::jsonb;
  v_already_done  bool;
BEGIN
  PERFORM public._assert_caller_owns_business(p_business_id);

  IF jsonb_typeof(p_movements) <> 'array' THEN
    RAISE EXCEPTION 'movements_must_be_array' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  FOR v_mv IN SELECT * FROM jsonb_array_elements(p_movements) LOOP
    v_mv_id         := (v_mv->>'movement_id')::uuid;
    v_movement_type := v_mv->>'movement_type';
    v_ref_type      := v_mv->>'ref_type';
    v_ref_id        := NULLIF(v_mv->>'ref_id', '')::uuid;

    IF v_mv_id IS NULL THEN
      RAISE EXCEPTION 'movement_id_required' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF v_movement_type = 'sale' THEN
      RAISE EXCEPTION 'sale_must_use_pos_record_sale_v2' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF v_movement_type NOT IN ('return','damage','transfer_out','transfer_in','purchase_received','adjustment') THEN
      RAISE EXCEPTION 'invalid_movement_type: %', v_movement_type USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- Replay detection on the ledger row's idempotency id.
    SELECT EXISTS(SELECT 1 FROM public.stock_transactions WHERE id = v_mv_id) INTO v_already_done;
    IF v_already_done THEN
      v_stock_txns := v_stock_txns || to_jsonb(
        (SELECT stx FROM public.stock_transactions stx WHERE stx.id = v_mv_id));
      CONTINUE;
    END IF;

    -- Apply inventory delta.
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
      INSERT INTO public.inventory (id, business_id, product_id, warehouse_id, quantity, created_at, last_updated_at)
      VALUES (
        gen_random_uuid(), p_business_id,
        (v_mv->>'product_id')::uuid, (v_mv->>'warehouse_id')::uuid,
        (v_mv->>'quantity_delta')::int, v_now, v_now
      )
      ON CONFLICT (business_id, product_id, warehouse_id)
        DO UPDATE SET quantity = public.inventory.quantity + EXCLUDED.quantity
      RETURNING quantity INTO v_new_qty;
    END IF;

    -- For movement_type='adjustment' with no ref, mint a stock_adjustments
    -- row to satisfy the ledger's exactly-one-FK CHECK.
    IF v_movement_type = 'adjustment' AND v_ref_type IS NULL THEN
      v_adjustment_id := gen_random_uuid();
      INSERT INTO public.stock_adjustments (
        id, business_id, product_id, warehouse_id, quantity_diff, reason,
        performed_by, created_at, last_updated_at
      )
      VALUES (
        v_adjustment_id, p_business_id,
        (v_mv->>'product_id')::uuid, (v_mv->>'warehouse_id')::uuid,
        (v_mv->>'quantity_delta')::int,
        COALESCE(v_mv->>'reason', 'manual_adjustment'),
        p_actor_id, v_now, v_now
      );
      v_ref_type := 'adjustment';
      v_ref_id   := v_adjustment_id;
      v_adjustments := v_adjustments || to_jsonb(
        (SELECT sa FROM public.stock_adjustments sa WHERE sa.id = v_adjustment_id));
    END IF;

    INSERT INTO public.stock_transactions (
      id, business_id, product_id, location_id, quantity_delta, movement_type,
      order_id, transfer_id, adjustment_id, purchase_id,
      performed_by, created_at, last_updated_at
    )
    VALUES (
      v_mv_id, p_business_id,
      (v_mv->>'product_id')::uuid, (v_mv->>'warehouse_id')::uuid,
      (v_mv->>'quantity_delta')::int, v_movement_type,
      CASE WHEN v_ref_type = 'order'      THEN v_ref_id END,
      CASE WHEN v_ref_type = 'transfer'   THEN v_ref_id END,
      CASE WHEN v_ref_type = 'adjustment' THEN v_ref_id END,
      CASE WHEN v_ref_type = 'purchase'   THEN v_ref_id END,
      p_actor_id, v_now, v_now
    );

    v_stock_txns := v_stock_txns || to_jsonb(
      (SELECT stx FROM public.stock_transactions stx WHERE stx.id = v_mv_id));
    v_inv_after := v_inv_after || jsonb_build_object(
      'product_id',      (v_mv->>'product_id')::uuid,
      'warehouse_id',    (v_mv->>'warehouse_id')::uuid,
      'quantity',        v_new_qty,
      'last_updated_at', v_now
    );
  END LOOP;

  RETURN jsonb_build_object(
    'stock_transactions', v_stock_txns,
    'stock_adjustments',  v_adjustments,
    'inventory_after',    v_inv_after
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_inventory_delta_v2(uuid, uuid, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_inventory_delta_v2(uuid, uuid, jsonb)
  TO authenticated, service_role;


-- =============================================================================
-- 3. pos_create_product_v2 — product + optional initial stock.
--    Tables: products, stock_adjustments, stock_transactions, inventory.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pos_create_product_v2(
  p_business_id              uuid,
  p_actor_id                 uuid,
  p_product_id               uuid,
  p_name                     text,
  p_unit                     text     DEFAULT 'Bottle',
  p_subtitle                 text     DEFAULT NULL,
  p_sku                      text     DEFAULT NULL,
  p_size                     text     DEFAULT NULL,
  p_retail_price_kobo        int      DEFAULT 0,
  p_selling_price_kobo       int      DEFAULT 0,
  p_buying_price_kobo        int      DEFAULT 0,
  p_bulk_breaker_price_kobo  int      DEFAULT NULL,
  p_distributor_price_kobo   int      DEFAULT NULL,
  p_category_id              uuid     DEFAULT NULL,
  p_crate_group_id           uuid     DEFAULT NULL,
  p_manufacturer_id          uuid     DEFAULT NULL,
  p_supplier_id              uuid     DEFAULT NULL,
  p_low_stock_threshold      int      DEFAULT 5,
  p_track_empties            bool     DEFAULT false,
  p_image_path               text     DEFAULT NULL,
  p_initial_stock            jsonb    DEFAULT NULL  -- {warehouse_id, quantity}
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_now           timestamptz := now();
  v_inserted      bool := false;
  v_product_row   jsonb;
  v_warehouse_id  uuid;
  v_qty           int;
  v_adjustment_id uuid;
  v_stx_id        uuid;
  v_new_qty       int;
  v_inv_after     jsonb := '[]'::jsonb;
  v_adjustments   jsonb := '[]'::jsonb;
  v_stock_txns    jsonb := '[]'::jsonb;
BEGIN
  PERFORM public._assert_caller_owns_business(p_business_id);

  IF p_product_id IS NULL THEN
    RAISE EXCEPTION 'product_id_required' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  WITH ins AS (
    INSERT INTO public.products (
      id, business_id, category_id, crate_group_id, manufacturer_id, supplier_id,
      name, subtitle, sku, size, unit,
      retail_price_kobo, bulk_breaker_price_kobo, distributor_price_kobo,
      selling_price_kobo, buying_price_kobo,
      is_available, is_deleted, low_stock_threshold,
      track_empties, image_path,
      created_at, last_updated_at
    )
    VALUES (
      p_product_id, p_business_id, p_category_id, p_crate_group_id, p_manufacturer_id, p_supplier_id,
      p_name, p_subtitle, p_sku, p_size, p_unit,
      p_retail_price_kobo, p_bulk_breaker_price_kobo, p_distributor_price_kobo,
      p_selling_price_kobo, p_buying_price_kobo,
      true, false, p_low_stock_threshold,
      p_track_empties, p_image_path,
      v_now, v_now
    )
    ON CONFLICT (id) DO NOTHING
    RETURNING 1
  )
  SELECT EXISTS(SELECT 1 FROM ins) INTO v_inserted;

  SELECT to_jsonb(p.*) INTO v_product_row FROM public.products p WHERE p.id = p_product_id;

  IF v_inserted AND p_initial_stock IS NOT NULL THEN
    v_qty          := COALESCE((p_initial_stock->>'quantity')::int, 0);
    v_warehouse_id := (p_initial_stock->>'warehouse_id')::uuid;

    IF v_qty > 0 AND v_warehouse_id IS NOT NULL THEN
      v_adjustment_id := gen_random_uuid();
      INSERT INTO public.stock_adjustments (
        id, business_id, product_id, warehouse_id, quantity_diff, reason,
        performed_by, created_at, last_updated_at
      )
      VALUES (
        v_adjustment_id, p_business_id, p_product_id, v_warehouse_id,
        v_qty, 'initial_stock', p_actor_id, v_now, v_now
      );
      v_adjustments := v_adjustments || to_jsonb(
        (SELECT sa FROM public.stock_adjustments sa WHERE sa.id = v_adjustment_id));

      INSERT INTO public.inventory (id, business_id, product_id, warehouse_id, quantity, created_at, last_updated_at)
      VALUES (gen_random_uuid(), p_business_id, p_product_id, v_warehouse_id, v_qty, v_now, v_now)
      ON CONFLICT (business_id, product_id, warehouse_id)
        DO UPDATE SET quantity = public.inventory.quantity + EXCLUDED.quantity
      RETURNING quantity INTO v_new_qty;

      v_inv_after := jsonb_build_array(jsonb_build_object(
        'product_id',      p_product_id,
        'warehouse_id',    v_warehouse_id,
        'quantity',        v_new_qty,
        'last_updated_at', v_now
      ));

      v_stx_id := gen_random_uuid();
      INSERT INTO public.stock_transactions (
        id, business_id, product_id, location_id, quantity_delta, movement_type,
        adjustment_id, performed_by, created_at, last_updated_at
      )
      VALUES (
        v_stx_id, p_business_id, p_product_id, v_warehouse_id,
        v_qty, 'adjustment', v_adjustment_id, p_actor_id, v_now, v_now
      );
      v_stock_txns := jsonb_build_array(to_jsonb(
        (SELECT stx FROM public.stock_transactions stx WHERE stx.id = v_stx_id)));
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'product',            v_product_row,
    'stock_adjustments',  v_adjustments,
    'stock_transactions', v_stock_txns,
    'inventory_after',    v_inv_after,
    'replayed',           NOT v_inserted
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_create_product_v2(
  uuid, uuid, uuid, text, text, text, text, text,
  int, int, int, int, int, uuid, uuid, uuid, uuid,
  int, bool, text, jsonb
) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_create_product_v2(
  uuid, uuid, uuid, text, text, text, text, text,
  int, int, int, int, int, uuid, uuid, uuid, uuid,
  int, bool, text, jsonb
) TO authenticated, service_role;


-- =============================================================================
-- 4. pos_cancel_order — atomic cancellation with full reversal.
--    Tables: orders (UPDATE), stock_transactions (return), inventory,
--            payment_transactions (void original + refund row),
--            wallet_transactions (compensating credit if order had wallet payment).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pos_cancel_order(
  p_business_id          uuid,
  p_actor_id             uuid,
  p_order_id             uuid,
  p_cancellation_reason  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_now            timestamptz := now();
  v_existing       record;
  v_oi             record;
  v_pt             record;
  v_wt             record;
  v_stx_id         uuid;
  v_refund_id      uuid;
  v_compensate_id  uuid;
  v_new_qty        int;
  v_order_row      jsonb;
  v_stock_txns     jsonb := '[]'::jsonb;
  v_inv_after      jsonb := '[]'::jsonb;
  v_voided_payments jsonb := '[]'::jsonb;
  v_refund_payments jsonb := '[]'::jsonb;
  v_wallet_compens  jsonb := '[]'::jsonb;
BEGIN
  PERFORM public._assert_caller_owns_business(p_business_id);

  -- Lock and read existing.
  SELECT * INTO v_existing FROM public.orders
   WHERE id = p_order_id AND business_id = p_business_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found' USING ERRCODE = 'P0001';
  END IF;

  -- Replay: already cancelled, return existing state.
  IF v_existing.status = 'cancelled' THEN
    SELECT to_jsonb(o.*) INTO v_order_row FROM public.orders o WHERE o.id = p_order_id;
    RETURN jsonb_build_object(
      'order',                v_order_row,
      'stock_transactions',   '[]'::jsonb,
      'inventory_after',      '[]'::jsonb,
      'voided_payments',      '[]'::jsonb,
      'refund_payments',      '[]'::jsonb,
      'wallet_compensations', '[]'::jsonb,
      'replayed',             true
    );
  END IF;

  IF v_existing.status NOT IN ('pending','completed') THEN
    RAISE EXCEPTION 'cannot_cancel_status_%', v_existing.status USING ERRCODE = 'P0001';
  END IF;

  -- Update order header.
  UPDATE public.orders
     SET status              = 'cancelled',
         cancelled_at        = v_now,
         cancellation_reason = p_cancellation_reason
   WHERE id = p_order_id;

  -- Restore inventory + stock_transactions(return) per item.
  FOR v_oi IN
    SELECT id, product_id, warehouse_id, quantity
      FROM public.order_items WHERE order_id = p_order_id
  LOOP
    INSERT INTO public.inventory (id, business_id, product_id, warehouse_id, quantity, created_at, last_updated_at)
    VALUES (gen_random_uuid(), p_business_id, v_oi.product_id, v_oi.warehouse_id, v_oi.quantity, v_now, v_now)
    ON CONFLICT (business_id, product_id, warehouse_id)
      DO UPDATE SET quantity = public.inventory.quantity + EXCLUDED.quantity
    RETURNING quantity INTO v_new_qty;

    v_inv_after := v_inv_after || jsonb_build_object(
      'product_id',      v_oi.product_id,
      'warehouse_id',    v_oi.warehouse_id,
      'quantity',        v_new_qty,
      'last_updated_at', v_now
    );

    v_stx_id := gen_random_uuid();
    INSERT INTO public.stock_transactions (
      id, business_id, product_id, location_id, quantity_delta, movement_type,
      order_id, performed_by, created_at, last_updated_at
    )
    VALUES (
      v_stx_id, p_business_id, v_oi.product_id, v_oi.warehouse_id,
      v_oi.quantity, 'return', p_order_id, p_actor_id, v_now, v_now
    );
    v_stock_txns := v_stock_txns || to_jsonb(
      (SELECT stx FROM public.stock_transactions stx WHERE stx.id = v_stx_id));
  END LOOP;

  -- Void existing non-voided payments + write a compensating refund row each.
  FOR v_pt IN
    SELECT * FROM public.payment_transactions
     WHERE order_id = p_order_id AND voided_at IS NULL
  LOOP
    UPDATE public.payment_transactions
       SET voided_at = v_now, voided_by = p_actor_id, void_reason = COALESCE(p_cancellation_reason, 'order_cancelled')
     WHERE id = v_pt.id;
    v_voided_payments := v_voided_payments || to_jsonb(
      (SELECT pt FROM public.payment_transactions pt WHERE pt.id = v_pt.id));

    v_refund_id := gen_random_uuid();
    INSERT INTO public.payment_transactions (
      id, business_id, amount_kobo, method, type,
      order_id, performed_by, created_at, last_updated_at
    )
    VALUES (
      v_refund_id, p_business_id, v_pt.amount_kobo, v_pt.method, 'refund',
      p_order_id, p_actor_id, v_now, v_now
    );
    v_refund_payments := v_refund_payments || to_jsonb(
      (SELECT pt FROM public.payment_transactions pt WHERE pt.id = v_refund_id));
  END LOOP;

  -- Compensate each non-voided wallet debit on this order with a credit.
  FOR v_wt IN
    SELECT * FROM public.wallet_transactions
     WHERE order_id = p_order_id AND voided_at IS NULL AND type = 'debit'
  LOOP
    UPDATE public.wallet_transactions
       SET voided_at = v_now, voided_by = p_actor_id, void_reason = COALESCE(p_cancellation_reason, 'order_cancelled')
     WHERE id = v_wt.id;

    v_compensate_id := gen_random_uuid();
    INSERT INTO public.wallet_transactions (
      id, business_id, wallet_id, customer_id, type,
      amount_kobo, signed_amount_kobo, reference_type, order_id,
      performed_by, customer_verified, created_at, last_updated_at
    )
    VALUES (
      v_compensate_id, p_business_id, v_wt.wallet_id, v_wt.customer_id, 'credit',
      v_wt.amount_kobo, v_wt.amount_kobo, 'refund', p_order_id,
      p_actor_id, false, v_now, v_now
    );
    v_wallet_compens := v_wallet_compens || to_jsonb(
      (SELECT wt FROM public.wallet_transactions wt WHERE wt.id = v_compensate_id));
  END LOOP;

  SELECT to_jsonb(o.*) INTO v_order_row FROM public.orders o WHERE o.id = p_order_id;

  RETURN jsonb_build_object(
    'order',                v_order_row,
    'stock_transactions',   v_stock_txns,
    'inventory_after',      v_inv_after,
    'voided_payments',      v_voided_payments,
    'refund_payments',      v_refund_payments,
    'wallet_compensations', v_wallet_compens,
    'replayed',             false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_cancel_order(uuid, uuid, uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_cancel_order(uuid, uuid, uuid, text)
  TO authenticated, service_role;


-- =============================================================================
-- 5. pos_approve_crate_return — approve a pending crate return.
--    Tables: pending_crate_returns (UPDATE), crate_ledger (INSERT),
--            customer_crate_balances (UPSERT).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pos_approve_crate_return(
  p_business_id        uuid,
  p_actor_id           uuid,
  p_pending_return_id  uuid,
  p_ledger_id          uuid   -- idempotency key for crate_ledger row
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_now           timestamptz := now();
  v_pending       record;
  v_already       bool;
  v_balance_row   record;
  v_ledger_row    jsonb;
  v_pending_row   jsonb;
  v_balance_jsonb jsonb;
BEGIN
  PERFORM public._assert_caller_owns_business(p_business_id);

  SELECT * INTO v_pending FROM public.pending_crate_returns
   WHERE id = p_pending_return_id AND business_id = p_business_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'pending_return_not_found' USING ERRCODE = 'P0001';
  END IF;

  -- Replay path.
  SELECT EXISTS(SELECT 1 FROM public.crate_ledger WHERE id = p_ledger_id) INTO v_already;
  IF v_already AND v_pending.status = 'approved' THEN
    SELECT to_jsonb(pcr.*) INTO v_pending_row FROM public.pending_crate_returns pcr WHERE pcr.id = p_pending_return_id;
    SELECT to_jsonb(cl.*)  INTO v_ledger_row  FROM public.crate_ledger cl WHERE cl.id = p_ledger_id;
    SELECT to_jsonb(ccb.*) INTO v_balance_jsonb
      FROM public.customer_crate_balances ccb
      WHERE ccb.business_id = p_business_id
        AND ccb.customer_id = v_pending.customer_id
        AND ccb.crate_group_id = v_pending.crate_group_id;
    RETURN jsonb_build_object(
      'pending_return',    v_pending_row,
      'crate_ledger_row',  v_ledger_row,
      'balance_row',       v_balance_jsonb,
      'replayed',          true
    );
  END IF;

  IF v_pending.status <> 'pending' THEN
    RAISE EXCEPTION 'cannot_approve_status_%', v_pending.status USING ERRCODE = 'P0001';
  END IF;

  -- Update pending row.
  UPDATE public.pending_crate_returns
     SET status      = 'approved',
         approved_by = p_actor_id,
         approved_at = v_now
   WHERE id = p_pending_return_id;

  -- Insert ledger row.
  INSERT INTO public.crate_ledger (
    id, business_id, customer_id, manufacturer_id, crate_group_id,
    quantity_delta, movement_type, reference_order_id, reference_return_id,
    performed_by, created_at, last_updated_at
  )
  VALUES (
    p_ledger_id, p_business_id, v_pending.customer_id, NULL, v_pending.crate_group_id,
    v_pending.quantity, 'returned', NULL, p_pending_return_id,
    p_actor_id, v_now, v_now
  )
  ON CONFLICT (id) DO NOTHING;

  -- Upsert customer crate balance cache.
  INSERT INTO public.customer_crate_balances (
    id, business_id, customer_id, crate_group_id, balance, created_at, last_updated_at
  )
  VALUES (
    gen_random_uuid(), p_business_id, v_pending.customer_id, v_pending.crate_group_id,
    v_pending.quantity, v_now, v_now
  )
  ON CONFLICT (business_id, customer_id, crate_group_id)
    DO UPDATE SET balance = public.customer_crate_balances.balance + EXCLUDED.balance,
                  last_updated_at = v_now
  RETURNING * INTO v_balance_row;

  SELECT to_jsonb(pcr.*) INTO v_pending_row FROM public.pending_crate_returns pcr WHERE pcr.id = p_pending_return_id;
  SELECT to_jsonb(cl.*)  INTO v_ledger_row  FROM public.crate_ledger cl WHERE cl.id = p_ledger_id;

  RETURN jsonb_build_object(
    'pending_return',   v_pending_row,
    'crate_ledger_row', v_ledger_row,
    'balance_row',      to_jsonb(v_balance_row),
    'replayed',         false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_approve_crate_return(uuid, uuid, uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_approve_crate_return(uuid, uuid, uuid, uuid)
  TO authenticated, service_role;


-- =============================================================================
-- 6. pos_wallet_topup — credit wallet + record payment.
--    Tables: wallet_transactions, payment_transactions.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pos_wallet_topup(
  p_business_id     uuid,
  p_actor_id        uuid,
  p_wallet_txn_id   uuid,
  p_payment_id      uuid,
  p_customer_id     uuid,
  p_amount_kobo     int,
  p_method          text,         -- 'cash' | 'transfer' | 'card' | 'pos' | 'other'
  p_reference_type  text          -- 'topup_cash' | 'topup_transfer'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_now             timestamptz := now();
  v_wallet_id       uuid;
  v_already_wallet  bool;
  v_wallet_row      jsonb;
  v_payment_row     jsonb;
BEGIN
  PERFORM public._assert_caller_owns_business(p_business_id);

  IF p_amount_kobo <= 0 THEN
    RAISE EXCEPTION 'amount_must_be_positive' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  SELECT id INTO v_wallet_id FROM public.customer_wallets
   WHERE business_id = p_business_id AND customer_id = p_customer_id LIMIT 1;
  IF v_wallet_id IS NULL THEN
    RAISE EXCEPTION 'customer_wallet_missing' USING ERRCODE = 'P0001';
  END IF;

  SELECT EXISTS(SELECT 1 FROM public.wallet_transactions WHERE id = p_wallet_txn_id)
    INTO v_already_wallet;

  IF NOT v_already_wallet THEN
    INSERT INTO public.wallet_transactions (
      id, business_id, wallet_id, customer_id, type,
      amount_kobo, signed_amount_kobo, reference_type, order_id,
      performed_by, customer_verified, created_at, last_updated_at
    )
    VALUES (
      p_wallet_txn_id, p_business_id, v_wallet_id, p_customer_id, 'credit',
      p_amount_kobo, p_amount_kobo, p_reference_type, NULL,
      p_actor_id, false, v_now, v_now
    );
  END IF;

  INSERT INTO public.payment_transactions (
    id, business_id, amount_kobo, method, type,
    wallet_txn_id, performed_by, created_at, last_updated_at
  )
  VALUES (
    p_payment_id, p_business_id, p_amount_kobo, p_method, 'wallet_topup',
    p_wallet_txn_id, p_actor_id, v_now, v_now
  )
  ON CONFLICT (id) DO NOTHING;

  SELECT to_jsonb(wt.*) INTO v_wallet_row FROM public.wallet_transactions wt WHERE wt.id = p_wallet_txn_id;
  SELECT to_jsonb(pt.*) INTO v_payment_row FROM public.payment_transactions pt WHERE pt.id = p_payment_id;

  RETURN jsonb_build_object(
    'wallet_transaction',  v_wallet_row,
    'payment_transaction', v_payment_row,
    'replayed',            v_already_wallet
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_wallet_topup(uuid, uuid, uuid, uuid, uuid, int, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_wallet_topup(uuid, uuid, uuid, uuid, uuid, int, text, text)
  TO authenticated, service_role;


-- =============================================================================
-- 7. pos_void_wallet_txn — void a wallet transaction with compensating entry.
--    Tables: wallet_transactions (UPDATE void cols + INSERT compensating row).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pos_void_wallet_txn(
  p_business_id     uuid,
  p_actor_id        uuid,
  p_original_id     uuid,
  p_compensating_id uuid,
  p_void_reason     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_now             timestamptz := now();
  v_orig            record;
  v_already         bool;
  v_orig_row        jsonb;
  v_compens_row     jsonb;
BEGIN
  PERFORM public._assert_caller_owns_business(p_business_id);

  SELECT * INTO v_orig FROM public.wallet_transactions
   WHERE id = p_original_id AND business_id = p_business_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'wallet_txn_not_found' USING ERRCODE = 'P0001';
  END IF;

  SELECT EXISTS(SELECT 1 FROM public.wallet_transactions WHERE id = p_compensating_id)
    INTO v_already;

  IF v_orig.voided_at IS NOT NULL AND v_already THEN
    SELECT to_jsonb(wt.*) INTO v_orig_row    FROM public.wallet_transactions wt WHERE wt.id = p_original_id;
    SELECT to_jsonb(wt.*) INTO v_compens_row FROM public.wallet_transactions wt WHERE wt.id = p_compensating_id;
    RETURN jsonb_build_object(
      'voided_transaction',       v_orig_row,
      'compensating_transaction', v_compens_row,
      'replayed',                 true
    );
  END IF;

  IF v_orig.voided_at IS NULL THEN
    UPDATE public.wallet_transactions
       SET voided_at = v_now, voided_by = p_actor_id, void_reason = p_void_reason
     WHERE id = p_original_id;
  END IF;

  IF NOT v_already THEN
    INSERT INTO public.wallet_transactions (
      id, business_id, wallet_id, customer_id, type,
      amount_kobo, signed_amount_kobo, reference_type, order_id,
      performed_by, customer_verified, created_at, last_updated_at
    )
    VALUES (
      p_compensating_id, p_business_id, v_orig.wallet_id, v_orig.customer_id,
      CASE WHEN v_orig.type = 'credit' THEN 'debit' ELSE 'credit' END,
      v_orig.amount_kobo, -v_orig.signed_amount_kobo, 'void', v_orig.order_id,
      p_actor_id, false, v_now, v_now
    );
  END IF;

  SELECT to_jsonb(wt.*) INTO v_orig_row    FROM public.wallet_transactions wt WHERE wt.id = p_original_id;
  SELECT to_jsonb(wt.*) INTO v_compens_row FROM public.wallet_transactions wt WHERE wt.id = p_compensating_id;

  RETURN jsonb_build_object(
    'voided_transaction',       v_orig_row,
    'compensating_transaction', v_compens_row,
    'replayed',                 false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_void_wallet_txn(uuid, uuid, uuid, uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_void_wallet_txn(uuid, uuid, uuid, uuid, text)
  TO authenticated, service_role;


-- =============================================================================
-- 8. pos_record_crate_return — issue/return crates to customer or manufacturer.
--    Tables: crate_ledger, customer_crate_balances OR manufacturer_crate_balances.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pos_record_crate_return(
  p_business_id          uuid,
  p_actor_id             uuid,
  p_ledger_id            uuid,
  p_owner_kind           text,        -- 'customer' | 'manufacturer'
  p_owner_id             uuid,
  p_crate_group_id       uuid,
  p_quantity_delta       int,
  p_movement_type        text,        -- one of crate_ledger.movement_type allowed values
  p_reference_order_id   uuid DEFAULT NULL,
  p_reference_return_id  uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_now           timestamptz := now();
  v_already       bool;
  v_balance_row   record;
  v_ledger_row    jsonb;
  v_balance_jsonb jsonb;
BEGIN
  PERFORM public._assert_caller_owns_business(p_business_id);

  IF p_owner_kind NOT IN ('customer','manufacturer') THEN
    RAISE EXCEPTION 'invalid_owner_kind: %', p_owner_kind USING ERRCODE = 'invalid_parameter_value';
  END IF;
  IF p_movement_type NOT IN ('issued','returned','damaged','adjusted','transferred_in','transferred_out') THEN
    RAISE EXCEPTION 'invalid_movement_type: %', p_movement_type USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- Replay detection on ledger id.
  SELECT EXISTS(SELECT 1 FROM public.crate_ledger WHERE id = p_ledger_id) INTO v_already;
  IF v_already THEN
    SELECT to_jsonb(cl.*) INTO v_ledger_row FROM public.crate_ledger cl WHERE cl.id = p_ledger_id;
    IF p_owner_kind = 'customer' THEN
      SELECT to_jsonb(b.*) INTO v_balance_jsonb FROM public.customer_crate_balances b
       WHERE b.business_id = p_business_id AND b.customer_id = p_owner_id AND b.crate_group_id = p_crate_group_id;
    ELSE
      SELECT to_jsonb(b.*) INTO v_balance_jsonb FROM public.manufacturer_crate_balances b
       WHERE b.business_id = p_business_id AND b.manufacturer_id = p_owner_id AND b.crate_group_id = p_crate_group_id;
    END IF;
    RETURN jsonb_build_object(
      'crate_ledger_row', v_ledger_row,
      'balance_row',      v_balance_jsonb,
      'replayed',         true
    );
  END IF;

  INSERT INTO public.crate_ledger (
    id, business_id, customer_id, manufacturer_id, crate_group_id,
    quantity_delta, movement_type, reference_order_id, reference_return_id,
    performed_by, created_at, last_updated_at
  )
  VALUES (
    p_ledger_id, p_business_id,
    CASE WHEN p_owner_kind = 'customer'     THEN p_owner_id END,
    CASE WHEN p_owner_kind = 'manufacturer' THEN p_owner_id END,
    p_crate_group_id, p_quantity_delta, p_movement_type,
    p_reference_order_id, p_reference_return_id,
    p_actor_id, v_now, v_now
  );

  IF p_owner_kind = 'customer' THEN
    INSERT INTO public.customer_crate_balances (
      id, business_id, customer_id, crate_group_id, balance, created_at, last_updated_at
    )
    VALUES (
      gen_random_uuid(), p_business_id, p_owner_id, p_crate_group_id,
      p_quantity_delta, v_now, v_now
    )
    ON CONFLICT (business_id, customer_id, crate_group_id)
      DO UPDATE SET balance = public.customer_crate_balances.balance + EXCLUDED.balance,
                    last_updated_at = v_now
    RETURNING * INTO v_balance_row;
  ELSE
    INSERT INTO public.manufacturer_crate_balances (
      id, business_id, manufacturer_id, crate_group_id, balance, created_at, last_updated_at
    )
    VALUES (
      gen_random_uuid(), p_business_id, p_owner_id, p_crate_group_id,
      p_quantity_delta, v_now, v_now
    )
    ON CONFLICT (business_id, manufacturer_id, crate_group_id)
      DO UPDATE SET balance = public.manufacturer_crate_balances.balance + EXCLUDED.balance,
                    last_updated_at = v_now
    RETURNING * INTO v_balance_row;
  END IF;

  SELECT to_jsonb(cl.*) INTO v_ledger_row FROM public.crate_ledger cl WHERE cl.id = p_ledger_id;

  RETURN jsonb_build_object(
    'crate_ledger_row', v_ledger_row,
    'balance_row',      to_jsonb(v_balance_row),
    'replayed',         false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_record_crate_return(uuid, uuid, uuid, text, uuid, uuid, int, text, uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_record_crate_return(uuid, uuid, uuid, text, uuid, uuid, int, text, uuid, uuid)
  TO authenticated, service_role;


-- =============================================================================
-- 9. pos_record_expense — expense + activity log + payment.
--    Tables: expenses, activity_logs, payment_transactions.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pos_record_expense(
  p_business_id     uuid,
  p_actor_id        uuid,
  p_expense_id      uuid,
  p_payment_id      uuid,
  p_activity_log_id uuid,
  p_amount_kobo     int,
  p_description     text,
  p_category_id     uuid DEFAULT NULL,
  p_payment_method  text DEFAULT NULL,    -- 'cash'|'transfer'|'card'|'pos'|'other'
  p_reference       text DEFAULT NULL,
  p_warehouse_id    uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_now            timestamptz := now();
  v_already        bool;
  v_expense_row    jsonb;
  v_activity_row   jsonb;
  v_payment_row    jsonb;
BEGIN
  PERFORM public._assert_caller_owns_business(p_business_id);

  IF p_amount_kobo <= 0 THEN
    RAISE EXCEPTION 'amount_must_be_positive' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  SELECT EXISTS(SELECT 1 FROM public.expenses WHERE id = p_expense_id) INTO v_already;

  IF NOT v_already THEN
    INSERT INTO public.expenses (
      id, business_id, category_id, amount_kobo, description, payment_method,
      recorded_by, reference, warehouse_id, is_deleted, created_at, last_updated_at
    )
    VALUES (
      p_expense_id, p_business_id, p_category_id, p_amount_kobo, p_description, p_payment_method,
      p_actor_id, p_reference, p_warehouse_id, false, v_now, v_now
    );

    INSERT INTO public.activity_logs (
      id, business_id, user_id, action, description, expense_id,
      created_at, last_updated_at
    )
    VALUES (
      p_activity_log_id, p_business_id, p_actor_id,
      'expense_recorded', p_description, p_expense_id, v_now, v_now
    );

    IF p_payment_method IS NOT NULL THEN
      INSERT INTO public.payment_transactions (
        id, business_id, amount_kobo, method, type,
        expense_id, performed_by, created_at, last_updated_at
      )
      VALUES (
        p_payment_id, p_business_id, p_amount_kobo, p_payment_method, 'expense',
        p_expense_id, p_actor_id, v_now, v_now
      );
    END IF;
  END IF;

  SELECT to_jsonb(e.*)  INTO v_expense_row  FROM public.expenses e        WHERE e.id = p_expense_id;
  SELECT to_jsonb(a.*)  INTO v_activity_row FROM public.activity_logs a   WHERE a.id = p_activity_log_id;
  SELECT to_jsonb(pt.*) INTO v_payment_row  FROM public.payment_transactions pt WHERE pt.id = p_payment_id;

  RETURN jsonb_build_object(
    'expense',             v_expense_row,
    'activity_log',        v_activity_row,
    'payment_transaction', v_payment_row,
    'replayed',            v_already
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_record_expense(uuid, uuid, uuid, uuid, uuid, int, text, uuid, text, text, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_record_expense(uuid, uuid, uuid, uuid, uuid, int, text, uuid, text, text, uuid)
  TO authenticated, service_role;


-- =============================================================================
-- 10. pos_create_customer — customer + wallet.
--     Tables: customers, customer_wallets.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pos_create_customer(
  p_business_id          uuid,
  p_customer_id          uuid,
  p_wallet_id            uuid,
  p_name                 text,
  p_phone                text DEFAULT NULL,
  p_email                text DEFAULT NULL,
  p_address              text DEFAULT NULL,
  p_google_maps_location text DEFAULT NULL,
  p_customer_group       text DEFAULT 'retailer',
  p_wallet_limit_kobo    int  DEFAULT 0,
  p_warehouse_id         uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_now           timestamptz := now();
  v_inserted      bool;
  v_customer_row  jsonb;
  v_wallet_row    jsonb;
BEGIN
  PERFORM public._assert_caller_owns_business(p_business_id);

  WITH ins AS (
    INSERT INTO public.customers (
      id, business_id, warehouse_id, name, phone, email, address,
      google_maps_location, customer_group, wallet_limit_kobo,
      is_deleted, created_at, last_updated_at
    )
    VALUES (
      p_customer_id, p_business_id, p_warehouse_id, p_name, p_phone, p_email, p_address,
      p_google_maps_location, p_customer_group, p_wallet_limit_kobo,
      false, v_now, v_now
    )
    ON CONFLICT (id) DO NOTHING
    RETURNING 1
  )
  SELECT EXISTS(SELECT 1 FROM ins) INTO v_inserted;

  INSERT INTO public.customer_wallets (
    id, business_id, customer_id, currency, is_active, is_deleted, created_at, last_updated_at
  )
  VALUES (
    p_wallet_id, p_business_id, p_customer_id, 'NGN', true, false, v_now, v_now
  )
  ON CONFLICT (business_id, customer_id) DO NOTHING;

  SELECT to_jsonb(c.*)  INTO v_customer_row FROM public.customers c        WHERE c.id = p_customer_id;
  SELECT to_jsonb(cw.*) INTO v_wallet_row   FROM public.customer_wallets cw WHERE cw.customer_id = p_customer_id AND cw.business_id = p_business_id;

  RETURN jsonb_build_object(
    'customer',         v_customer_row,
    'customer_wallet',  v_wallet_row,
    'replayed',         NOT v_inserted
  );
END;
$$;

REVOKE ALL ON FUNCTION public.pos_create_customer(uuid, uuid, uuid, text, text, text, text, text, text, int, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_create_customer(uuid, uuid, uuid, text, text, text, text, text, text, int, uuid)
  TO authenticated, service_role;


-- =============================================================================
-- 11. Feature flags — one per v2 RPC. Default off; client cuts over per flag.
-- =============================================================================

INSERT INTO public.system_config (key, value) VALUES
  ('feature.domain_rpcs_v2.record_sale',       'false'::jsonb),
  ('feature.domain_rpcs_v2.inventory_delta',   'false'::jsonb),
  ('feature.domain_rpcs_v2.create_product',    'false'::jsonb),
  ('feature.domain_rpcs_v2.cancel_order',      'false'::jsonb),
  ('feature.domain_rpcs_v2.approve_crate_return', 'false'::jsonb),
  ('feature.domain_rpcs_v2.wallet_topup',      'false'::jsonb),
  ('feature.domain_rpcs_v2.void_wallet_txn',   'false'::jsonb),
  ('feature.domain_rpcs_v2.record_crate_return', 'false'::jsonb),
  ('feature.domain_rpcs_v2.record_expense',    'false'::jsonb),
  ('feature.domain_rpcs_v2.create_customer',   'false'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- =============================================================================
-- Verification — paste into the SQL editor while authenticated:
--
--   1. All ten v2 functions exist:
--      SELECT proname FROM pg_proc
--       WHERE pronamespace = 'public'::regnamespace
--         AND proname LIKE 'pos_%v2' OR proname IN
--           ('pos_cancel_order','pos_approve_crate_return','pos_wallet_topup',
--            'pos_void_wallet_txn','pos_record_crate_return','pos_record_expense',
--            'pos_create_customer')
--       ORDER BY proname;
--      -- expect 10 rows
--
--   2. Tenant guard fires with someone else's business_id:
--      SELECT public.pos_create_customer(
--        '<other-tenant-uuid>', gen_random_uuid(), gen_random_uuid(), 'X');
--      -- expect ERROR: tenant_mismatch (insufficient_privilege)
--
--   3. Idempotent replay returns replayed=true on second call with same id.
--
--   4. v1 RPCs still callable (rollback path during rollout).
--
-- =============================================================================
