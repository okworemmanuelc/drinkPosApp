-- One-time bootstrap for Tier-2 integration tests.
-- Run in Supabase Studio → SQL editor as service_role AFTER creating the auth
-- user under Authentication → Users.
--
-- 1. Replace <PASTE_AUTH_UID_HERE> with the new user's auth.users.id.
-- 2. Run this whole block.
-- 3. Copy the two ids printed in the NOTICE messages into your .envrc as
--    TEST_BUSINESS_ID and TEST_USER_ID.

DO $$
DECLARE
  v_auth_uid     uuid := '<PASTE_AUTH_UID_HERE>';
  v_business_id  uuid := gen_random_uuid();
  v_user_id      uuid := gen_random_uuid();
BEGIN
  INSERT INTO public.businesses (id, owner_id, onboarding_complete, name)
    VALUES (v_business_id, v_auth_uid, true, 'Sync Tests');

  INSERT INTO public.profiles (id, business_id, name, role, role_tier)
    VALUES (v_auth_uid, v_business_id, 'Test User', 'ceo', 5);

  INSERT INTO public.users (id, business_id, auth_user_id, name, role, pin)
    VALUES (v_user_id, v_business_id, v_auth_uid, 'Test User', 'admin', '0000');

  RAISE NOTICE 'TEST_BUSINESS_ID=%', v_business_id;
  RAISE NOTICE 'TEST_USER_ID=%', v_user_id;
END $$;
