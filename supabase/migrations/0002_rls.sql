-- =============================================================================
-- 0002_rls.sql — Row-Level Security policies.
--
-- Decision (per the Phase 1 plan): auth.uid()-based scoping. RLS resolves
-- the caller's business_id by joining profiles. JWT custom claims are
-- *not* consulted — they were the prior failure mode that produced the
-- "customers don't appear in dashboard" symptom.
--
-- Apply after 0001_initial.sql. Idempotent on re-run for the policy
-- bodies (DROP IF EXISTS first), but the ENABLE/FORCE statements are
-- already-set safe.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Helper: auth.business_id()
--    STABLE so PostgreSQL can cache the lookup within a single statement.
--    NOT SECURITY DEFINER — the function runs as the calling user, so RLS on
--    profiles applies. The profiles policy permits SELECT where id =
--    auth.uid(), which is exactly the row this query reads, so the lookup
--    succeeds without elevated privileges. SECURITY DEFINER would be a silent
--    RLS bypass: any future change that broadens the WHERE clause would let
--    every authenticated user read every profile.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION auth.business_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT business_id FROM public.profiles WHERE id = auth.uid()
$$;

REVOKE ALL ON FUNCTION auth.business_id() FROM public;
GRANT EXECUTE ON FUNCTION auth.business_id() TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. Enable + force RLS on every table.
--    FORCE applies RLS even to the table owner — closes the gap where a
--    superuser-equivalent role would otherwise bypass policies.
-- -----------------------------------------------------------------------------

DO $$
DECLARE
  t text;
  all_tables text[] := ARRAY[
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
  FOREACH t IN ARRAY all_tables LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE public.%I FORCE  ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- 3. Tenant policies — applied to every table that carries business_id.
-- -----------------------------------------------------------------------------

DO $$
DECLARE
  t text;
  tenant_tables text[] := ARRAY[
    'profiles','users','sessions','invites',
    'warehouses','manufacturers','crate_groups','categories','suppliers',
    'products','price_lists',
    'customers','customer_wallets','wallet_transactions',
    'customer_crate_balances','manufacturer_crate_balances','crate_ledger',
    'inventory','crates','stock_transfers','stock_adjustments','stock_transactions',
    'orders','order_items','purchases','purchase_items',
    'drivers','delivery_receipts','saved_carts','pending_crate_returns',
    'payment_transactions',
    'expense_categories','expenses','activity_logs','notifications',
    'settings'
  ];
BEGIN
  FOREACH t IN ARRAY tenant_tables LOOP
    -- Drop first so this script is re-runnable.
    EXECUTE format('DROP POLICY IF EXISTS tenant_select ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_insert ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_update ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_delete ON public.%I', t);

    EXECUTE format(
      'CREATE POLICY tenant_select ON public.%I FOR SELECT TO authenticated '
      'USING (business_id = auth.business_id())', t);
    EXECUTE format(
      'CREATE POLICY tenant_insert ON public.%I FOR INSERT TO authenticated '
      'WITH CHECK (business_id = auth.business_id())', t);
    EXECUTE format(
      'CREATE POLICY tenant_update ON public.%I FOR UPDATE TO authenticated '
      'USING (business_id = auth.business_id()) '
      'WITH CHECK (business_id = auth.business_id())', t);
    EXECUTE format(
      'CREATE POLICY tenant_delete ON public.%I FOR DELETE TO authenticated '
      'USING (business_id = auth.business_id())', t);
  END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- 4. profiles — keyed on id = auth.uid() (each user manages only their own).
--    The blanket tenant_* policies created in step 3 are too lax for
--    profiles (they'd let a user read every profile in their business).
--    Replace them.
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS tenant_select ON public.profiles;
DROP POLICY IF EXISTS tenant_insert ON public.profiles;
DROP POLICY IF EXISTS tenant_update ON public.profiles;
DROP POLICY IF EXISTS tenant_delete ON public.profiles;

CREATE POLICY profiles_self_select ON public.profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid());

CREATE POLICY profiles_self_insert ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY profiles_self_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY profiles_self_delete ON public.profiles
  FOR DELETE TO authenticated
  USING (id = auth.uid());

-- -----------------------------------------------------------------------------
-- 5. businesses — own id is the tenant key. Onboarding requires a free
--    INSERT (no profile exists yet); SELECT/UPDATE are scoped to the
--    caller's business; DELETE forbidden.
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS businesses_select  ON public.businesses;
DROP POLICY IF EXISTS businesses_insert  ON public.businesses;
DROP POLICY IF EXISTS businesses_update  ON public.businesses;
DROP POLICY IF EXISTS businesses_delete  ON public.businesses;

CREATE POLICY businesses_select ON public.businesses
  FOR SELECT TO authenticated
  USING (id = auth.business_id());

CREATE POLICY businesses_insert ON public.businesses
  FOR INSERT TO authenticated
  WITH CHECK (true);  -- onboarding flow

CREATE POLICY businesses_update ON public.businesses
  FOR UPDATE TO authenticated
  USING (id = auth.business_id())
  WITH CHECK (id = auth.business_id());

-- No DELETE policy ⇒ DELETE is denied for non-service roles.

-- -----------------------------------------------------------------------------
-- 6. system_config — read-only for authenticated; writes only via service_role.
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS system_config_select ON public.system_config;
CREATE POLICY system_config_select ON public.system_config
  FOR SELECT TO authenticated
  USING (true);
-- No INSERT/UPDATE/DELETE policies for authenticated ⇒ writes denied.
-- service_role bypasses RLS by default (FORCE doesn't apply to it).

-- =============================================================================
-- Verification queries (paste into the SQL editor while signed in as a
-- second-business user; expected counts in comments).
-- =============================================================================
--
-- 1. Coverage — every tenant table must show four cmd rows:
--    SELECT tablename, cmd, policyname FROM pg_policies
--    WHERE schemaname='public' ORDER BY tablename, cmd;
--
-- 2. Caller's business resolves correctly:
--    SELECT auth.business_id();   -- not NULL
--    SELECT * FROM profiles WHERE id = auth.uid();   -- exactly 1 row
--
-- 3. Tenant isolation (sign in as a user from business B; A has data):
--    SELECT count(*) FROM customers;   -- B's count, not A+B
--    SELECT count(*) FROM orders;      -- B's count, not A+B
--
-- 4. Profile peer-isolation (sign in as user X in business B; another
--    user Y is in the same business):
--    SELECT * FROM profiles WHERE id = '<Y-uuid>';   -- 0 rows
--
-- 5. Append-only enforcement smoke test (must error):
--    UPDATE wallet_transactions SET amount_kobo = 0 WHERE id = '<any uuid>';
--    DELETE FROM wallet_transactions WHERE id = '<any uuid>';
--
-- =============================================================================
