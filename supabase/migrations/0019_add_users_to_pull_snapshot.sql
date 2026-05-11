-- =============================================================================
-- 0019_add_users_to_pull_snapshot.sql — Add `users` to the snapshot RPC.
--
-- `pos_pull_snapshot` (originally defined in 0005_sync_rpcs.sql) iterates a
-- hard-coded `v_tenant_tables` array. `public.users` was omitted from that
-- list, so a fresh-device login received zero staff rows from the RPC. The
-- client's `_restoreTableData` then tripped FK violations the moment it tried
-- to insert any row referencing `users.id` — orders.staff_id, stock_*.
-- performed_by, wallet_transactions.performed_by, crate_ledger.performed_by,
-- etc. — surfaced as a generic "Couldn't load your business" toast.
--
-- The client carries a supplementary postgrest fetch for `users` as a stopgap
-- so older environments without this migration still work. This migration is
-- the canonical fix: once it lands, the supplementary fetch becomes a no-op
-- (the snapshot already includes the rows) and we avoid an extra round-trip
-- per login.
--
-- Function body is byte-identical to the 0005 version except for the
-- v_tenant_tables array literal. `CREATE OR REPLACE` is idempotent; safe to
-- re-run.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.pos_pull_snapshot(
  p_business_id uuid,
  p_since       timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_caller_business uuid;
  v_result          jsonb := '{}'::jsonb;
  v_table           text;
  v_rows            jsonb;
  v_query           text;
  v_tenant_tables   text[] := ARRAY[
    'profiles','users','warehouses','manufacturers','crate_groups',
    'categories','products','inventory','customers','suppliers',
    'orders','order_items','purchases','purchase_items',
    'expenses','expense_categories',
    'customer_crate_balances','delivery_receipts','drivers',
    'stock_transfers','stock_adjustments','activity_logs',
    'notifications','stock_transactions',
    'customer_wallets','wallet_transactions',
    'saved_carts','pending_crate_returns','invites',
    'manufacturer_crate_balances','crate_ledger',
    'price_lists','payment_transactions','sessions','settings'
  ];
BEGIN
  v_caller_business := public.business_id();
  IF v_caller_business IS NULL THEN
    RAISE EXCEPTION 'no_business_for_caller'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF v_caller_business <> p_business_id THEN
    RAISE EXCEPTION 'tenant_mismatch'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(b)), '[]'::jsonb)
    INTO v_rows
    FROM public.businesses b
    WHERE b.id = p_business_id
      AND (p_since IS NULL OR b.last_updated_at > p_since);
  v_result := v_result || jsonb_build_object('businesses', v_rows);

  FOREACH v_table IN ARRAY v_tenant_tables LOOP
    v_query := format(
      'SELECT COALESCE(jsonb_agg(to_jsonb(t)), ''[]''::jsonb)
         FROM public.%I t
         WHERE t.business_id = $1
           AND ($2::timestamptz IS NULL OR t.last_updated_at > $2)',
      v_table
    );
    EXECUTE v_query INTO v_rows USING p_business_id, p_since;
    v_result := v_result || jsonb_build_object(v_table, v_rows);
  END LOOP;

  SELECT COALESCE(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
    INTO v_rows
    FROM public.system_config s
    WHERE (p_since IS NULL OR s.last_updated_at > p_since);
  v_result := v_result || jsonb_build_object('system_config', v_rows);

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.pos_pull_snapshot(uuid, timestamptz) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_pull_snapshot(uuid, timestamptz)
  TO authenticated;
