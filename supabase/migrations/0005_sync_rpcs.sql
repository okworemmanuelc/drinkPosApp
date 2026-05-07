-- =============================================================================
-- 0005_sync_rpcs.sql — Server-side helpers that collapse multi-table sync
-- traffic into a single round-trip.
--
-- pos_pull_snapshot(p_business_id, p_since)
--   Returns one jsonb blob keyed by table name, containing every row in that
--   business updated after p_since (or all rows when p_since IS NULL).
--   Lets a fresh-device login or a reconnect-replay drain the catalog in a
--   single HTTP call instead of 33 parallel selects.
--
-- A pos_push_batch RPC was scoped here originally but deferred: client writes
-- frequently come from partial Drift Companions (e.g. markCompleted writes
-- {status, completed_at, last_updated_at} only). Server-side
-- ON CONFLICT DO UPDATE SET col = EXCLUDED.col would overwrite the missing
-- columns with NULL. The PostgREST batched-array upsert path the client now
-- uses preserves partial-update semantics natively, so a single round-trip
-- per table is achievable without sacrificing correctness.
--
-- SECURITY DEFINER with an explicit business_id() check inside: the function
-- runs as the function owner and bypasses RLS, so the manual tenant guard
-- below is what enforces isolation.
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
  -- Tables scoped per-tenant by `business_id`. Order matches the client's
  -- existing _restoreTableData switch so logs read sensibly; FK ordering is
  -- enforced by the client when it inserts the rows locally.
  v_tenant_tables   text[] := ARRAY[
    'profiles','warehouses','manufacturers','crate_groups',
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
  -- 1. Tenant check: the caller may only pull their own business.
  v_caller_business := public.business_id();
  IF v_caller_business IS NULL THEN
    RAISE EXCEPTION 'no_business_for_caller'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF v_caller_business <> p_business_id THEN
    RAISE EXCEPTION 'tenant_mismatch'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- 2. The businesses row itself — always included so children never insert
  --    against a missing FK target on a fresh device.
  SELECT COALESCE(jsonb_agg(to_jsonb(b)), '[]'::jsonb)
    INTO v_rows
    FROM public.businesses b
    WHERE b.id = p_business_id
      AND (p_since IS NULL OR b.last_updated_at > p_since);
  v_result := v_result || jsonb_build_object('businesses', v_rows);

  -- 3. Per-tenant tables. EXECUTE because the table name varies; format()'s
  --    %I escapes prevent injection. Filter is uniform: business_id matches
  --    + last_updated_at > since (every synced table has the column per
  --    0001_initial.sql line 12).
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

  -- 4. system_config is global (no business_id column).
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
  TO authenticated, service_role;
