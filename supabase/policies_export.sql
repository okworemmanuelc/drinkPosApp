-- RLS policy snapshot. Run in the Supabase SQL editor and paste the result
-- into rls_snapshot.md.
--
-- For each tenant table (customers, orders, products, expenses, inventory,
-- manufacturers, suppliers, warehouses, customer_wallets, ...) confirm that
-- policies exist for SELECT, INSERT, UPDATE, DELETE and that each references
-- business_id. Tables that scope by warehouse need warehouse_id too.

SELECT schemaname, tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, cmd;

-- 2026-04-27 snapshot showed every tenant policy delegates to a SQL helper
-- get_user_business_id(). Run this to see what it actually resolves to:
--
-- SELECT pg_get_functiondef('public.get_user_business_id'::regproc);
--
-- And, while signed in as the affected user, this confirms whether the
-- function returns NULL (which silently fails every insert):
--
-- SELECT get_user_business_id();
