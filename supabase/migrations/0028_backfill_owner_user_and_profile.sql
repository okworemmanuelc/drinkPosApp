-- =============================================================================
-- 0028_backfill_owner_user_and_profile.sql — Repair grandfathered CEO rows.
--
-- CEOs whose accounts were created before 0020/0023 shipped were left with
-- two broken bits of state on the cloud side:
--
--   • public.users.auth_user_id = NULL.
--       _shared/auth.ts loadCaller resolves the caller via
--       (auth_user_id = auth.uid() AND business_id = profiles.business_id).
--       With auth_user_id NULL the lookup returns 0 rows, loadCaller returns
--       null, and every authenticated Edge Function call surfaces
--       'unauthenticated' (rendered client-side as "Please sign in again.").
--
--   • public.users.role_tier = 1, copied verbatim into business_members
--       during the 0020 backfill. The client staff screen buckets staff by
--       users.role_tier; a tier-1 CEO falls into the "Rider" section.
--
-- The profiles row was already correct (0018's complete_onboarding has been
-- writing role_tier=5 for CEOs since before this CEO signed up). No fixup
-- needed there.
--
-- last_updated_at is bumped to now() on both touched tables so the client's
-- incremental pull picks the corrected rows up — without the bump, a device
-- that wrote locally more recently than the cloud row would LWW-reject the
-- update and keep the stale role_tier.
--
-- Idempotent: the WHERE clauses filter on the broken state, so re-running
-- after the rows are repaired is a no-op.
--
-- Apply after 0027.
-- =============================================================================

-- 1. public.users — wire auth_user_id and bump role_tier for owners.
--    Match is (users.business_id, users.role='ceo') + businesses.owner_id
--    chain. One CEO per business (out-of-scope in CLAUDE.md §11), so this
--    uniquely identifies the owner's row.
UPDATE public.users u
SET auth_user_id    = b.owner_id,
    role_tier       = 5,
    last_updated_at = now()
FROM public.businesses b
WHERE u.business_id   = b.id
  AND u.role          = 'ceo'
  AND b.owner_id     IS NOT NULL
  AND (u.auth_user_id IS NULL OR u.role_tier <> 5);

-- 2. public.business_members — bump role_tier for owner memberships.
--    Joined via the users row repaired above; covers the case where the
--    membership was created by the 0020 backfill against a stale users
--    row (role_tier copied as 1).
UPDATE public.business_members bm
SET role_tier       = 5,
    last_updated_at = now()
FROM public.users u
WHERE bm.user_id    = u.id
  AND bm.role       = 'ceo'
  AND bm.role_tier <> 5;

-- =============================================================================
-- Verification (paste into the SQL editor after deploy):
--
--   -- A. No CEO users row left with broken auth_user_id or role_tier.
--   SELECT count(*) AS broken_users
--   FROM public.users u
--   JOIN public.businesses b ON b.id = u.business_id
--   WHERE u.role = 'ceo' AND b.owner_id IS NOT NULL
--     AND (u.auth_user_id IS NULL OR u.role_tier <> 5);
--   -- expect 0
--
--   -- B. No CEO membership left at the wrong tier.
--   SELECT count(*) AS broken_members
--   FROM public.business_members
--   WHERE role = 'ceo' AND role_tier <> 5;
--   -- expect 0
--
--   -- C. loadCaller can now resolve the CEO. Spot check one:
--   SELECT u.id, u.auth_user_id, u.role_tier, p.role_tier AS profile_tier
--   FROM public.users u
--   JOIN public.profiles p ON p.id = u.auth_user_id
--   WHERE u.role = 'ceo'
--   LIMIT 5;
--   -- every row: auth_user_id NOT NULL, both tier columns = 5
-- =============================================================================
