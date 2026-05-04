-- =============================================================================
-- 0004_onboarding_resume.sql — Resumable onboarding.
--
-- Adds owner_id and onboarding_complete to businesses so an interrupted
-- onboarding can be resumed on next launch with all entered data intact.
--
-- The companion change in app code: AuthService.createNewOwner calls the
-- public.start_onboarding(...) RPC defined below. The RPC inserts the
-- businesses + profiles rows in a single atomic SECURITY DEFINER call,
-- which means once createNewOwner returns successfully the profile exists
-- and public.business_id() resolves for the rest of onboarding. That lets
-- every other onboarding write rely on the standard tenant_select/insert
-- RLS policies — businesses_select does NOT need an owner_id-based
-- extension.
--
-- Apply after 0003_grants.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Schema additions on businesses.
-- -----------------------------------------------------------------------------

ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS owner_id            uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS onboarding_complete boolean NOT NULL DEFAULT false;

-- Back-fill existing businesses. Pick the CEO profile (role_tier = 5)
-- deterministically — businesses with multiple profiles (CEO + staff)
-- would otherwise get a non-deterministic owner_id.
-- Orphan businesses (no profile at all) stay onboarding_complete = false /
-- owner_id = NULL and remain invisible to the resume gate, which is fine.
UPDATE public.businesses b
SET onboarding_complete = true,
    owner_id = (
      SELECT id FROM public.profiles
      WHERE business_id = b.id AND role_tier = 5
      ORDER BY created_at ASC
      LIMIT 1
    )
WHERE EXISTS (SELECT 1 FROM public.profiles WHERE business_id = b.id);

-- Partial index — only the rows the resume gate ever queries
-- (SELECT id FROM businesses WHERE owner_id = ? AND onboarding_complete = false).
-- Disappears as rows complete, so the index never grows beyond
-- the count of in-flight onboardings.
CREATE INDEX IF NOT EXISTS idx_businesses_owner_incomplete
  ON public.businesses (owner_id)
  WHERE onboarding_complete = false;

-- -----------------------------------------------------------------------------
-- 2. Tighten businesses_insert.
--    The previous WITH CHECK (true) let any authenticated user insert any
--    business row, including spoofing owner_id or pre-completing onboarding.
--    Now: an authenticated user may only insert a business they own that is
--    starting in the incomplete state.
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS businesses_insert ON public.businesses;
CREATE POLICY businesses_insert ON public.businesses
  FOR INSERT TO authenticated
  WITH CHECK (
    owner_id = auth.uid()
    AND onboarding_complete = false
  );

-- businesses_select stays as is from 0002 (id = public.business_id()).
-- Profile is created atomically with the business in start_onboarding(),
-- so business_id() resolves once onboarding starts.
--
-- businesses_update stays as is — the completion flip
-- (UPDATE ... SET onboarding_complete = true) succeeds because by then
-- the profile exists.

-- -----------------------------------------------------------------------------
-- 3. start_onboarding RPC.
--    Atomically creates the businesses row + the profiles row in one
--    transaction, scoped to auth.uid(). SECURITY DEFINER bypasses the
--    tightened businesses_insert (we still enforce the owner_id check
--    inside the function body) and the profiles_self_insert policy.
--
--    Returns void — the businessId is the caller-supplied p_business_id,
--    so the client already knows it. (Returning it would just echo input.)
--
--    Idempotent on profiles via ON CONFLICT, so a retry after a partial
--    failure does not throw a duplicate-key error.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.start_onboarding(
  p_business_id uuid,
  p_name        text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'start_onboarding requires an authenticated session';
  END IF;

  INSERT INTO public.businesses (id, owner_id, onboarding_complete, name)
    VALUES (p_business_id, auth.uid(), false, p_name)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.profiles (id, business_id, name, role, role_tier)
    VALUES (auth.uid(), p_business_id, p_name, 'ceo', 5)
  ON CONFLICT (id) DO UPDATE
    SET business_id = EXCLUDED.business_id,
        name        = EXCLUDED.name,
        role        = EXCLUDED.role,
        role_tier   = EXCLUDED.role_tier;
END;
$$;

REVOKE ALL    ON FUNCTION public.start_onboarding(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.start_onboarding(uuid, text) TO authenticated;
