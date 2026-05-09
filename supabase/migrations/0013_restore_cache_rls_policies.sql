-- =============================================================================
-- 0013_restore_cache_rls_policies.sql — undo the premature cache-RLS
-- lockdown that an earlier draft of 0010_schema_redesign.sql shipped.
--
-- Background: 0010's first version dropped the tenant_insert / tenant_update
-- / tenant_delete policies on inventory, customer_crate_balances, and
-- manufacturer_crate_balances on the assumption that domain RPCs would be
-- the only writers post-Phase-C. Several call sites (OrdersDao.markCancelled,
-- CrateReturnApprovalService.approve, CrateLedgerDao.record*) still upsert
-- those tables directly via the standard outbox path, so the lockdown
-- silently broke them for any tenant that received it.
--
-- This migration restores the policies to their 0002_rls.sql definitions.
-- The lockdown will return in a later migration once Phase C cuts every
-- cache-touching path over to v2 RPCs and `_syncedTenantTables` no longer
-- contains the cache tables.
--
-- Idempotent: each policy is dropped-if-exists before being re-created.
-- Safe to run on a database that never had 0010's lockdown applied — the
-- DROP IF EXISTS becomes a no-op and the CREATE POLICY proceeds.
-- =============================================================================

DO $$
DECLARE
  t text;
  cache_tables text[] := ARRAY[
    'inventory',
    'customer_crate_balances',
    'manufacturer_crate_balances'
  ];
BEGIN
  FOREACH t IN ARRAY cache_tables LOOP
    -- Drop first so this script is re-runnable without `policy already
    -- exists` errors.
    EXECUTE format('DROP POLICY IF EXISTS tenant_insert ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_update ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_delete ON public.%I', t);

    EXECUTE format(
      'CREATE POLICY tenant_insert ON public.%I FOR INSERT TO authenticated '
      'WITH CHECK (business_id = public.business_id())', t);
    EXECUTE format(
      'CREATE POLICY tenant_update ON public.%I FOR UPDATE TO authenticated '
      'USING (business_id = public.business_id()) '
      'WITH CHECK (business_id = public.business_id())', t);
    EXECUTE format(
      'CREATE POLICY tenant_delete ON public.%I FOR DELETE TO authenticated '
      'USING (business_id = public.business_id())', t);
  END LOOP;
END $$;

-- =============================================================================
-- Verification:
--
--   SELECT tablename, cmd, policyname FROM pg_policies
--    WHERE schemaname = 'public'
--      AND tablename IN ('inventory','customer_crate_balances','manufacturer_crate_balances')
--    ORDER BY tablename, cmd;
--   -- expect 4 rows per table: SELECT (tenant_select), INSERT, UPDATE, DELETE
--
--   -- Authenticated INSERT into own tenant succeeds:
--   INSERT INTO public.inventory
--     (id, business_id, product_id, warehouse_id, quantity)
--   VALUES (gen_random_uuid(), public.business_id(),
--           '<product uuid>', '<warehouse uuid>', 0);
--   -- expect: success.
--
-- =============================================================================
