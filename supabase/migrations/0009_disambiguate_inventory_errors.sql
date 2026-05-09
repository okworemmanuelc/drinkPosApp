-- =============================================================================
-- 0009_disambiguate_inventory_errors.sql
--
-- pos_record_sale: the inventory delta loop conflates "no inventory row for
-- this product/warehouse" with "insufficient stock", and silently accepts a
-- NULL quantity_delta (cast yields NULL, the >= 0 check returns NULL not
-- false, then the WHERE-with-NULL matches nothing and reports
-- insufficient_stock). Split into:
--   - missing quantity_delta  → quantity_delta_required (invalid_parameter_value)
--   - non-negative delta      → sale_movement_must_be_negative_delta (unchanged)
--   - no matching inventory   → missing_inventory_row (P0001)
--   - delta would underflow   → insufficient_stock (P0001, with available qty)
--
-- Lock the row via SELECT ... FOR UPDATE so the existence check and the
-- subsequent UPDATE see the same state under concurrent sales.
--
-- Everything else is identical to 0008: same defaults injection, same body.
-- pos_create_product is untouched (its initial_stock idempotency gap is a
-- separate change — needs client to pass adjustment/transaction IDs).
-- =============================================================================

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
  v_delta           int;
  v_current_qty     int;
  v_new_qty         int;
  v_inv_after       jsonb := '[]'::jsonb;
  v_stx_ids         jsonb := '[]'::jsonb;
  v_payment_id      uuid;
  v_wallet_tx_id    uuid;
  v_now             timestamptz := now();
  v_ts_defaults     jsonb;
  c_orders_defaults              CONSTANT jsonb := '{
    "discount_kobo": 0,
    "amount_paid_kobo": 0,
    "rider_name": "Pick-up Order",
    "crate_deposit_paid_kobo": 0
  }'::jsonb;
  c_order_items_defaults         CONSTANT jsonb := '{"buying_price_kobo": 0}'::jsonb;
  c_wallet_tx_defaults           CONSTANT jsonb := '{"customer_verified": false}'::jsonb;
BEGIN
  v_ts_defaults := jsonb_build_object(
    'created_at',      v_now,
    'last_updated_at', v_now
  );

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

  WITH ins AS (
    INSERT INTO public.orders
    SELECT (jsonb_populate_record(
      NULL::public.orders,
      v_ts_defaults || c_orders_defaults || p_order
    )).*
    ON CONFLICT (id) DO NOTHING
    RETURNING id
  )
  SELECT COUNT(*) > 0 INTO v_is_new_sale FROM ins;

  IF NOT v_is_new_sale THEN
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

  INSERT INTO public.order_items
  SELECT (jsonb_populate_record(
    NULL::public.order_items,
    v_ts_defaults || c_order_items_defaults || item
  )).*
    FROM jsonb_array_elements(p_items) AS item
  ON CONFLICT (id) DO NOTHING;

  FOR v_mv IN SELECT * FROM jsonb_array_elements(p_stock_movements) LOOP
    IF (v_mv->>'business_id') IS NOT NULL
       AND (v_mv->>'business_id')::uuid <> p_business_id THEN
      RAISE EXCEPTION 'movement_business_id_mismatch' USING ERRCODE = 'insufficient_privilege';
    END IF;

    IF (v_mv->>'quantity_delta') IS NULL THEN
      RAISE EXCEPTION 'quantity_delta_required'
        USING ERRCODE = 'invalid_parameter_value',
              DETAIL  = format('product_id=%s warehouse_id=%s',
                               v_mv->>'product_id',
                               v_mv->>'location_id');
    END IF;
    v_delta := (v_mv->>'quantity_delta')::int;
    IF v_delta >= 0 THEN
      RAISE EXCEPTION 'sale_movement_must_be_negative_delta'
        USING ERRCODE = 'invalid_parameter_value';
    END IF;

    SELECT quantity INTO v_current_qty
      FROM public.inventory
     WHERE business_id  = p_business_id
       AND product_id   = (v_mv->>'product_id')::uuid
       AND warehouse_id = (v_mv->>'location_id')::uuid
     FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'missing_inventory_row'
        USING ERRCODE = 'P0001',
              DETAIL  = format('product_id=%s warehouse_id=%s',
                               v_mv->>'product_id',
                               v_mv->>'location_id'),
              HINT    = jsonb_build_object(
                          'product_id',   v_mv->>'product_id',
                          'warehouse_id', v_mv->>'location_id'
                        )::text;
    END IF;

    v_new_qty := v_current_qty + v_delta;
    IF v_new_qty < 0 THEN
      RAISE EXCEPTION 'insufficient_stock'
        USING ERRCODE = 'P0001',
              DETAIL  = format('product_id=%s warehouse_id=%s requested_delta=%s available=%s',
                               v_mv->>'product_id',
                               v_mv->>'location_id',
                               v_delta,
                               v_current_qty),
              HINT    = jsonb_build_object(
                          'product_id',   v_mv->>'product_id',
                          'warehouse_id', v_mv->>'location_id',
                          'requested_delta', v_delta,
                          'available',       v_current_qty
                        )::text;
    END IF;

    UPDATE public.inventory
       SET quantity = v_new_qty
     WHERE business_id  = p_business_id
       AND product_id   = (v_mv->>'product_id')::uuid
       AND warehouse_id = (v_mv->>'location_id')::uuid;

    v_inv_after := v_inv_after || jsonb_build_object(
      'product_id',      (v_mv->>'product_id')::uuid,
      'warehouse_id',    (v_mv->>'location_id')::uuid,
      'quantity',        v_new_qty,
      'last_updated_at', v_now
    );
  END LOOP;

  INSERT INTO public.stock_transactions
  SELECT (jsonb_populate_record(
    NULL::public.stock_transactions,
    v_ts_defaults || mv || jsonb_build_object('order_id', v_order_id)
  )).*
    FROM jsonb_array_elements(p_stock_movements) AS mv
  ON CONFLICT (id) DO NOTHING;

  SELECT COALESCE(jsonb_agg((mv->>'id')::uuid), '[]'::jsonb)
    INTO v_stx_ids
    FROM jsonb_array_elements(p_stock_movements) AS mv;

  IF p_payment IS NOT NULL THEN
    IF (p_payment->>'business_id')::uuid <> p_business_id THEN
      RAISE EXCEPTION 'payment_business_id_mismatch' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO public.payment_transactions
    SELECT (jsonb_populate_record(
      NULL::public.payment_transactions,
      v_ts_defaults || p_payment
    )).*
    ON CONFLICT (id) DO NOTHING;
    v_payment_id := (p_payment->>'id')::uuid;
  END IF;

  IF p_wallet_tx IS NOT NULL THEN
    IF (p_wallet_tx->>'business_id')::uuid <> p_business_id THEN
      RAISE EXCEPTION 'wallet_tx_business_id_mismatch' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO public.wallet_transactions
    SELECT (jsonb_populate_record(
      NULL::public.wallet_transactions,
      v_ts_defaults || c_wallet_tx_defaults || p_wallet_tx
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
