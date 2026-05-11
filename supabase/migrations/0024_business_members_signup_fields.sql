-- =============================================================================
-- 0024_business_members_signup_fields.sql — Wizard-collected staff data.
--
-- Adds the staff contact + next-of-kin + guarantor columns the rev 3 four-
-- screen signup wizard collects. All nullable because:
--   1. The membership row is created by accept_invite BEFORE the wizard
--      runs in some flows (e.g. retry / resume), so the columns must
--      tolerate "not yet provided" for the row's first existence.
--   2. CEO membership rows (created by complete_onboarding) never go
--      through the wizard and have no values for these.
--   3. Backfilled / grandfathered rows from 0020 obviously have nothing.
--
-- The accept_invite RPC (0026) populates the columns when called with the
-- wizard payload. Staff can also edit them later from their own profile.
--
-- `verification_extensions_used` already exists on business_members from
-- 0020. NOT re-added here.
--
-- Idempotent. Apply after 0023_complete_onboarding_seeds_membership.sql.
-- =============================================================================

ALTER TABLE public.business_members
  ADD COLUMN IF NOT EXISTS staff_phone           text,
  ADD COLUMN IF NOT EXISTS next_of_kin_name      text,
  ADD COLUMN IF NOT EXISTS next_of_kin_phone     text,
  ADD COLUMN IF NOT EXISTS next_of_kin_relation  text,
  ADD COLUMN IF NOT EXISTS guarantor_name        text,
  ADD COLUMN IF NOT EXISTS guarantor_phone       text,
  ADD COLUMN IF NOT EXISTS guarantor_relation    text;

-- =============================================================================
-- Verification:
--   SELECT column_name FROM information_schema.columns
--   WHERE table_schema='public' AND table_name='business_members'
--     AND column_name IN ('staff_phone','next_of_kin_name','next_of_kin_phone',
--                         'next_of_kin_relation','guarantor_name',
--                         'guarantor_phone','guarantor_relation');
--   -- expect 7 rows
-- =============================================================================
