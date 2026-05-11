-- =============================================================================
-- wipe_test_data.sql — DESTRUCTIVE. Empties all tenant data + auth users.
-- Run from Supabase Dashboard → SQL Editor (uses service-role privileges).
-- Safe to re-run; idempotent. DO NOT run in production.
-- =============================================================================

BEGIN;

-- 1. Sweep public schema. FK ON DELETE CASCADE from every tenant table to
--    public.businesses means truncating businesses takes all 33 tenant
--    tables with it. RESTART IDENTITY resets any sequences. TRUNCATE
--    bypasses the BEFORE DELETE forbid_delete triggers on append-only
--    ledgers, so no trigger juggling required.
TRUNCATE TABLE public.businesses RESTART IDENTITY CASCADE;

-- 2. Global config (no business_id). Re-seed feature flags afterward so the
--    domain RPC v2 gates exist (default false, matching production state).
TRUNCATE TABLE public.system_config RESTART IDENTITY;

INSERT INTO public.system_config (key, value) VALUES
  ('feature.domain_rpcs_v2.record_sale',         'false'::jsonb),
  ('feature.domain_rpcs_v2.inventory_delta',     'false'::jsonb),
  ('feature.domain_rpcs_v2.create_product',      'false'::jsonb),
  ('feature.domain_rpcs_v2.cancel_order',        'false'::jsonb),
  ('feature.domain_rpcs_v2.approve_crate_return','false'::jsonb),
  ('feature.domain_rpcs_v2.wallet_topup',        'false'::jsonb),
  ('feature.domain_rpcs_v2.void_wallet_txn',     'false'::jsonb),
  ('feature.domain_rpcs_v2.record_crate_return', 'false'::jsonb),
  ('feature.domain_rpcs_v2.record_expense',      'false'::jsonb),
  ('feature.domain_rpcs_v2.create_customer',     'false'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- 3. Auth users. Cannot TRUNCATE auth.users (Supabase forbids it); DELETE
--    is fine and cascades through Supabase's own FKs to auth.identities,
--    auth.sessions, and auth.refresh_tokens.
DELETE FROM auth.users;

COMMIT;

-- Post-wipe assertions (run separately to confirm):
-- SELECT count(*) FROM public.businesses;     -- 0
-- SELECT count(*) FROM public.activity_logs;  -- 0 (forbid_delete bypassed)
-- SELECT count(*) FROM auth.users;            -- 0
-- SELECT count(*) FROM public.system_config;  -- 10
