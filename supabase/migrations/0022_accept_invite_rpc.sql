-- =============================================================================
-- 0022_accept_invite_rpc.sql — Atomic invite acceptance.
--
-- Replaces the per-table inserts the legacy redeem-invite Edge Function used
-- to do (insert profile, insert users, mark invite accepted) with a single
-- SECURITY DEFINER RPC that:
--
--   1. Validates the calling auth user's email against the invite's email.
--   2. Finds-or-creates the public.users row for this auth user.
--   3. Reads onboarding.verification_grace_days from settings (default 7).
--   4. Creates the public.business_members row with verification_status =
--      'not_started' and verification_due_at = now() + grace.
--   5. Marks the invite accepted.
--   6. Inserts an activity_log entry.
--   7. Returns canonical {user, membership, invite} rows the client applies
--      via _applyDomainResponse to seed local Drift without an extra pull.
--
-- Idempotent: replay of the same (invite_id, auth.uid()) returns the same
-- {user, membership} pair without inserting duplicates. The invite UPDATE
-- is conditional on status='pending' so a re-run is a no-op.
--
-- Inviter-removal handling: the function does NOT validate that
-- invites.created_by is still active. Per spec §12, an invite belongs to
-- the business, not to the individual who sent it. The membership FK to
-- created_by is non-cascading for the same reason.
--
-- Apply after 0021_invites_phase2.sql.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.accept_invite(
  p_invite_id uuid,
  p_user_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_auth_uid       uuid := auth.uid();
  v_auth_email     text;
  v_invite         public.invites%ROWTYPE;
  v_user_id        uuid;
  v_membership_id  uuid;
  v_grace_days     int;
  v_due_at         timestamptz;
  v_role_tier      int;
  v_clean_name     text;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'unauthenticated'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  v_clean_name := COALESCE(NULLIF(trim(p_user_name), ''), 'Unknown');

  -- Lock the invite row to keep concurrent claims from racing each other.
  SELECT * INTO v_invite
    FROM public.invites
   WHERE id = p_invite_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite_not_found'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- Allow both 'pending' (first claim) and 'accepted' (idempotent replay).
  -- 'expired' / 'revoked' fail loud.
  IF v_invite.status NOT IN ('pending', 'accepted') THEN
    RAISE EXCEPTION 'invite_status_invalid:%', v_invite.status
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  IF v_invite.status = 'pending' AND v_invite.expires_at < now() THEN
    RAISE EXCEPTION 'invite_expired'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- Email-match guard: the auth user's email on file must equal the email
  -- the invite was issued to. Prevents an attacker who somehow obtains a
  -- token from claiming an invite with their own auth credentials.
  SELECT email INTO v_auth_email FROM auth.users WHERE id = v_auth_uid;
  IF v_auth_email IS NULL
     OR lower(v_auth_email) <> lower(v_invite.email) THEN
    RAISE EXCEPTION 'email_mismatch'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Map invite role → role_tier. CHECK constraint on both tables enforces
  -- the (1,4,5) trio. admin and manager share tier 4 — they are equivalent
  -- for `roleTier >= 4` permission gates (manager-or-above) and are
  -- distinguished only by `role` text (e.g. invite-eligibility filtering
  -- in the Edge Function: admin can invite manager+staff, manager can only
  -- invite staff). CEO is not a valid invite role (issue.ts rejects it
  -- pre-emptively) but the CASE handles it defensively.
  v_role_tier := CASE v_invite.role
    WHEN 'ceo'     THEN 5
    WHEN 'admin'   THEN 4
    WHEN 'manager' THEN 4
    WHEN 'staff'   THEN 1
  END;

  -- 1. Find-or-create users row.
  --    Phase 1 keeps users.business_id NOT NULL and (business_id, email)
  --    UNIQUE — multi-business support arrives in Phase 5 with the column
  --    drops. For now, one users row per (business, email).
  SELECT id INTO v_user_id
    FROM public.users
   WHERE auth_user_id = v_auth_uid
     AND business_id  = v_invite.business_id
   LIMIT 1;

  IF v_user_id IS NULL THEN
    INSERT INTO public.users (
      auth_user_id, business_id, name, email,
      role, role_tier, warehouse_id
    ) VALUES (
      v_auth_uid, v_invite.business_id, v_clean_name, v_invite.email,
      v_invite.role, v_role_tier, v_invite.warehouse_id
    )
    ON CONFLICT (business_id, email) DO UPDATE
      SET auth_user_id = EXCLUDED.auth_user_id,
          name         = EXCLUDED.name,
          role         = EXCLUDED.role,
          role_tier    = EXCLUDED.role_tier,
          warehouse_id = EXCLUDED.warehouse_id,
          last_updated_at = now()
    RETURNING id INTO v_user_id;
  END IF;

  -- 2. Resolve grace window. Settings rows are tenant-scoped; default 7 if
  --    the CEO has not configured one.
  SELECT (value)::int INTO v_grace_days
    FROM public.settings
   WHERE business_id = v_invite.business_id
     AND key = 'onboarding.verification_grace_days';
  v_grace_days := COALESCE(v_grace_days, 7);
  v_due_at := now() + make_interval(days => v_grace_days);

  -- 3. Find-or-create membership. Replay returns the existing row.
  SELECT id INTO v_membership_id
    FROM public.business_members
   WHERE business_id = v_invite.business_id
     AND user_id     = v_user_id;

  IF v_membership_id IS NULL THEN
    INSERT INTO public.business_members (
      business_id, user_id, role, role_tier, warehouse_id,
      status, verification_status, verification_due_at,
      joined_at, created_by
    ) VALUES (
      v_invite.business_id,
      v_user_id,
      v_invite.role,
      v_role_tier,
      v_invite.warehouse_id,
      'active',
      'not_started',
      v_due_at,
      now(),
      v_invite.created_by
    )
    RETURNING id INTO v_membership_id;
  END IF;

  -- 4. Mark invite accepted. Conditional on status='pending' so replay is a
  --    no-op. used_at is set on first acceptance only.
  UPDATE public.invites
     SET status  = 'accepted',
         used_at = COALESCE(used_at, now()),
         last_updated_at = now()
   WHERE id = p_invite_id
     AND status = 'pending';

  -- 5. Audit log. activity_logs.action is freeform text; the
  --    constants live in lib/core/constants/activity_actions.dart on the
  --    client side.
  INSERT INTO public.activity_logs (
    business_id, user_id, action, description
  ) VALUES (
    v_invite.business_id,
    v_user_id,
    'invite.accepted',
    format('%s joined as %s via invite %s',
           v_clean_name, v_invite.role, p_invite_id)
  );

  -- 6. Return canonical rows for _applyDomainResponse on the client.
  RETURN jsonb_build_object(
    'user',       (SELECT to_jsonb(u) FROM public.users           u WHERE u.id = v_user_id),
    'membership', (SELECT to_jsonb(m) FROM public.business_members m WHERE m.id = v_membership_id),
    'invite',     (SELECT to_jsonb(i) FROM public.invites          i WHERE i.id = p_invite_id)
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.accept_invite(uuid, text) FROM public;
GRANT EXECUTE ON FUNCTION public.accept_invite(uuid, text) TO authenticated, service_role;

-- =============================================================================
-- Verification (paste into the SQL editor while signed in as a freshly-auth'd
-- invitee whose email matches a pending invite):
--
--   1. First call returns full canonical row trio:
--      SELECT public.accept_invite('<invite-id>', 'Test User');
--      -- expect a JSON object with user, membership, invite keys.
--
--   2. Replay is idempotent (same call again):
--      SELECT public.accept_invite('<invite-id>', 'Test User');
--      -- expect the same membership.id as call 1; no duplicate rows.
--
--   3. Email mismatch rejected:
--      -- (sign in as a different auth user whose email differs from the
--      -- invite email, then call accept_invite with the same invite id)
--      -- expect: ERROR: email_mismatch
--
--   4. Expired invite rejected:
--      UPDATE public.invites SET expires_at = now() - interval '1 day' WHERE id = '<id>';
--      SELECT public.accept_invite('<id>', 'Test');
--      -- expect: ERROR: invite_expired
-- =============================================================================
