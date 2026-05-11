-- =============================================================================
-- 0027_regenerate_and_extend_rpcs.sql — code regeneration + grace extension.
--
-- Two RPCs new to rev 3:
--
--   regenerate_invite_code(p_invite_id uuid)
--     For unredeemed invites only. Revokes the old row, mints a new row
--     with a fresh 8-char human_code, links new→old via regenerated_from.
--     Caller must be ceo / admin / manager of the same business. Returns
--     the new invite row as jsonb so the client renders the new code in
--     the share screen.
--
--   extend_verification(p_membership_id uuid, p_extra_days int, p_reason text)
--     Adds days to a membership's verification_due_at. Capped at 2 prior
--     extensions per the staff-onboarding plan §4.1 (rev 2 carryover).
--     Cap is enforced in the RPC body (not via column CHECK) so the
--     caller gets a clean named exception instead of a raw constraint
--     violation.
--
-- Apply after 0026_accept_invite_v3.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- regenerate_invite_code
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.regenerate_invite_code(p_invite_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_caller_business uuid := public.business_id();
  v_caller_tier     int;
  v_invite          public.invites%ROWTYPE;
  v_new_id          uuid;
  v_new_code        text;
  v_new_human_code  text;
  v_now             timestamptz := now();
  v_expires_at      timestamptz;
  v_alphabet        text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_attempt         int;
  v_ttl_days        int;
BEGIN
  IF v_caller_business IS NULL THEN
    RAISE EXCEPTION 'unauthenticated'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Caller must be ceo / admin / manager.
  SELECT role_tier INTO v_caller_tier
    FROM public.profiles
   WHERE id = auth.uid();
  IF v_caller_tier IS NULL OR v_caller_tier < 4 THEN
    RAISE EXCEPTION 'forbidden'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Lock the invite, validate it belongs to the caller's business and is
  -- still pending (regen only works on unredeemed).
  SELECT * INTO v_invite
    FROM public.invites
   WHERE id = p_invite_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite_not_found'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;
  IF v_invite.business_id <> v_caller_business THEN
    RAISE EXCEPTION 'forbidden'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION 'invite_not_pending:%', v_invite.status
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- TTL — read setting, fallback 7 days.
  SELECT (value)::int INTO v_ttl_days
    FROM public.settings
   WHERE business_id = v_caller_business
     AND key = 'onboarding.invite_ttl_days';
  v_ttl_days := COALESCE(v_ttl_days, 7);
  v_expires_at := v_now + make_interval(days => v_ttl_days);

  -- 1. Revoke the old row.
  UPDATE public.invites
     SET status = 'revoked',
         last_updated_at = v_now
   WHERE id = v_invite.id;

  -- 2. Mint a fresh 8-char code, retrying on collision (partial unique
  --    index uq_invites_pending_human_code can fire). 32^8 ≈ 1.1T values
  --    so collisions are vanishingly rare; 5 attempts is generous.
  FOR v_attempt IN 1..5 LOOP
    SELECT string_agg(
      substr(v_alphabet, 1 + (floor(random() * 32))::int, 1), ''
    ) INTO v_new_human_code
    FROM generate_series(1, 8);

    -- Legacy 8-char `code` column — keep populated for any consumer still
    -- reading it; same alphabet, same length, separate value.
    SELECT string_agg(
      substr(v_alphabet, 1 + (floor(random() * 32))::int, 1), ''
    ) INTO v_new_code
    FROM generate_series(1, 8);

    BEGIN
      INSERT INTO public.invites (
        business_id, email, code, human_code, phone,
        role, warehouse_id, created_by, invitee_name,
        status, expires_at,
        regenerated_from, regenerated_at
      ) VALUES (
        v_invite.business_id, v_invite.email, v_new_code, v_new_human_code,
        v_invite.phone, v_invite.role, v_invite.warehouse_id, v_invite.created_by,
        v_invite.invitee_name, 'pending', v_expires_at,
        v_invite.id, v_now
      )
      RETURNING id INTO v_new_id;
      EXIT;  -- success
    EXCEPTION WHEN unique_violation THEN
      IF v_attempt = 5 THEN
        RAISE EXCEPTION 'code_generation_failed_collisions'
          USING ERRCODE = 'unique_violation';
      END IF;
    END;
  END LOOP;

  -- 3. Activity log.
  INSERT INTO public.activity_logs (business_id, user_id, action, description)
  VALUES (
    v_caller_business,
    (SELECT id FROM public.users WHERE auth_user_id = auth.uid() AND business_id = v_caller_business LIMIT 1),
    'invite.regenerated',
    format('regenerated invite %s → %s', v_invite.id, v_new_id)
  );

  -- 4. Return the new row.
  RETURN to_jsonb(i.*) FROM public.invites i WHERE i.id = v_new_id;
END;
$$;

REVOKE ALL    ON FUNCTION public.regenerate_invite_code(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.regenerate_invite_code(uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- extend_verification
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.extend_verification(
  p_membership_id uuid,
  p_extra_days    int,
  p_reason        text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_caller_business uuid := public.business_id();
  v_caller_tier     int;
  v_member          public.business_members%ROWTYPE;
  v_clean_reason    text;
  v_new_due_at      timestamptz;
BEGIN
  IF v_caller_business IS NULL THEN
    RAISE EXCEPTION 'unauthenticated'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Caller must be ceo / admin / manager.
  SELECT role_tier INTO v_caller_tier
    FROM public.profiles
   WHERE id = auth.uid();
  IF v_caller_tier IS NULL OR v_caller_tier < 4 THEN
    RAISE EXCEPTION 'forbidden'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF p_extra_days IS NULL OR p_extra_days <= 0 OR p_extra_days > 60 THEN
    RAISE EXCEPTION 'invalid_extra_days:%', p_extra_days
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  v_clean_reason := NULLIF(trim(coalesce(p_reason, '')), '');
  IF v_clean_reason IS NULL THEN
    RAISE EXCEPTION 'reason_required'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- Lock the membership row, validate it's the caller's business.
  SELECT * INTO v_member
    FROM public.business_members
   WHERE id = p_membership_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'member_not_found'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;
  IF v_member.business_id <> v_caller_business THEN
    RAISE EXCEPTION 'forbidden'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Cap-check in the RPC body (not via column CHECK — see plan §C / pickup).
  IF v_member.verification_extensions_used >= 2 THEN
    RAISE EXCEPTION 'extension_cap_reached'
      USING ERRCODE = 'check_violation';
  END IF;

  v_new_due_at := COALESCE(v_member.verification_due_at, now())
                  + make_interval(days => p_extra_days);

  UPDATE public.business_members
     SET verification_due_at          = v_new_due_at,
         verification_extensions_used = verification_extensions_used + 1,
         last_updated_at              = now()
   WHERE id = p_membership_id;

  -- Activity log captures who, when, why.
  INSERT INTO public.activity_logs (business_id, user_id, action, description)
  VALUES (
    v_caller_business,
    (SELECT id FROM public.users WHERE auth_user_id = auth.uid() AND business_id = v_caller_business LIMIT 1),
    'verification.extended',
    format('extended membership %s by %s days; reason: %s',
           p_membership_id, p_extra_days, v_clean_reason)
  );

  RETURN jsonb_build_object(
    'membership_id',                p_membership_id,
    'verification_due_at',          v_new_due_at,
    'verification_extensions_used', v_member.verification_extensions_used + 1
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.extend_verification(uuid, int, text) FROM public;
GRANT EXECUTE ON FUNCTION public.extend_verification(uuid, int, text) TO authenticated, service_role;

-- =============================================================================
-- Verification:
--
--   1. RPCs exist:
--      \df public.regenerate_invite_code
--      \df public.extend_verification
--
--   2. Regenerate creates new row, revokes old:
--      SELECT public.regenerate_invite_code('<existing-pending-invite>');
--      -- old row status='revoked', new row status='pending', regenerated_from set
--
--   3. Extend cap enforced:
--      -- run extend_verification three times against same membership
--      -- first two succeed; third raises 'extension_cap_reached'
-- =============================================================================
