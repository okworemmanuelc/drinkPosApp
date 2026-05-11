-- =============================================================================
-- 0026_accept_invite_v3.sql — accept_invite with wizard fields + notification
-- fan-out, plus the recipient_user_id column on notifications that the
-- fan-out depends on.
--
-- Three concerns bundled:
--
--   1. Schema: notifications.recipient_user_id (NULL = broadcast, set =
--      targeted to one user). Backward-compatible: existing rows with
--      NULL keep the old "visible to all in business" semantics.
--
--   2. Drop the old accept_invite(uuid, text) signature from 0022. We're
--      changing the signature; CREATE OR REPLACE only works when the arg
--      list is identical.
--
--   3. New accept_invite with the four-screen wizard fields, default
--      verification grace bumped to 14 days, and a transactional
--      notification fan-out:
--        • CEO membership → 1 notification (any warehouse).
--        • Admin/manager memberships in the SAME warehouse as the new
--          staff → 1 notification each.
--        • Admin/manager memberships in OTHER warehouses → none.
--      Gated on `xmax = 0` from the membership INSERT so a replay (same
--      invite + same auth user) does not duplicate notifications.
--
-- Apply after 0025_invite_codes_v3.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. notifications.recipient_user_id.
-- -----------------------------------------------------------------------------

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS recipient_user_id uuid REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_notifications_business_recipient_lua
  ON public.notifications (business_id, recipient_user_id, last_updated_at);

-- -----------------------------------------------------------------------------
-- 2. Drop the old signature (changing arg list — CREATE OR REPLACE won't do).
-- -----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.accept_invite(uuid, text);

-- -----------------------------------------------------------------------------
-- 3. New accept_invite.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.accept_invite(
  p_invite_id            uuid,
  p_user_name            text,
  p_staff_phone          text,
  p_next_of_kin_name     text,
  p_next_of_kin_phone    text,
  p_next_of_kin_relation text,
  p_guarantor_name       text DEFAULT NULL,
  p_guarantor_phone      text DEFAULT NULL,
  p_guarantor_relation   text DEFAULT NULL
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
  v_just_inserted  boolean;
  v_grace_days     int;
  v_due_at         timestamptz;
  v_role_tier      int;
  v_clean_name     text;
  v_warehouse_id   uuid;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'unauthenticated'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  v_clean_name := COALESCE(NULLIF(trim(p_user_name), ''), 'Unknown');

  -- Lock the invite row to keep concurrent claims from racing.
  SELECT * INTO v_invite
    FROM public.invites
   WHERE id = p_invite_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invite_not_found'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  IF v_invite.status NOT IN ('pending', 'accepted') THEN
    RAISE EXCEPTION 'invite_status_invalid:%', v_invite.status
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  IF v_invite.status = 'pending' AND v_invite.expires_at < now() THEN
    RAISE EXCEPTION 'invite_expired'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- Email-match guard.
  SELECT email INTO v_auth_email FROM auth.users WHERE id = v_auth_uid;
  IF v_auth_email IS NULL
     OR lower(v_auth_email) <> lower(v_invite.email) THEN
    RAISE EXCEPTION 'email_mismatch'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- role → role_tier (admin & manager both 4; staff 1; ceo 5 — defensive).
  v_role_tier := CASE v_invite.role
    WHEN 'ceo'     THEN 5
    WHEN 'admin'   THEN 4
    WHEN 'manager' THEN 4
    WHEN 'staff'   THEN 1
  END;

  v_warehouse_id := v_invite.warehouse_id;

  -- 1. Find-or-create users row (Phase 1 model: one users row per
  --    (business, email); auth_user_id UNIQUE).
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
      v_invite.role, v_role_tier, v_warehouse_id
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

  -- 2. Resolve grace window. Default 14 (was 7 in rev 2).
  SELECT (value)::int INTO v_grace_days
    FROM public.settings
   WHERE business_id = v_invite.business_id
     AND key = 'onboarding.verification_grace_days';
  v_grace_days := COALESCE(v_grace_days, 14);
  v_due_at := now() + make_interval(days => v_grace_days);

  -- 3. Find-or-create membership. Capture xmax = 0 to gate notification
  --    fan-out: true on first insert, false on idempotent replay.
  INSERT INTO public.business_members (
    business_id, user_id, role, role_tier, warehouse_id,
    status, verification_status, verification_due_at,
    joined_at, created_by,
    staff_phone, next_of_kin_name, next_of_kin_phone, next_of_kin_relation,
    guarantor_name, guarantor_phone, guarantor_relation
  ) VALUES (
    v_invite.business_id, v_user_id, v_invite.role, v_role_tier, v_warehouse_id,
    'active', 'not_started', v_due_at,
    now(), v_invite.created_by,
    NULLIF(trim(p_staff_phone), ''),
    NULLIF(trim(p_next_of_kin_name), ''),
    NULLIF(trim(p_next_of_kin_phone), ''),
    NULLIF(trim(p_next_of_kin_relation), ''),
    NULLIF(trim(coalesce(p_guarantor_name, '')), ''),
    NULLIF(trim(coalesce(p_guarantor_phone, '')), ''),
    NULLIF(trim(coalesce(p_guarantor_relation, '')), '')
  )
  ON CONFLICT (business_id, user_id) DO UPDATE
    SET role            = EXCLUDED.role,
        role_tier       = EXCLUDED.role_tier,
        last_updated_at = now()
  RETURNING id, (xmax = 0) INTO v_membership_id, v_just_inserted;

  -- 4. Mark invite accepted (idempotent).
  UPDATE public.invites
     SET status  = 'accepted',
         used_at = COALESCE(used_at, now()),
         last_updated_at = now()
   WHERE id = p_invite_id
     AND status = 'pending';

  -- 5. Activity log.
  INSERT INTO public.activity_logs (
    business_id, user_id, action, description
  ) VALUES (
    v_invite.business_id,
    v_user_id,
    'invite.accepted',
    format('%s joined as %s via invite %s',
           v_clean_name, v_invite.role, p_invite_id)
  );

  -- 6. Notification fan-out — only on first acceptance (replay skipped).
  --    CEO sees every staff joining; admin/manager only see staff joining
  --    THEIR warehouse. Iterates over memberships (not users) so the
  --    routing matches the rev 3 plan exactly.
  IF v_just_inserted THEN
    INSERT INTO public.notifications (
      business_id, type, message, linked_record_id, recipient_user_id
    )
    SELECT
      v_invite.business_id,
      'member.created',
      format('%s joined as %s', v_clean_name, v_invite.role),
      v_membership_id,
      bm.user_id
    FROM public.business_members bm
    WHERE bm.business_id = v_invite.business_id
      AND bm.is_deleted = false
      AND bm.status = 'active'
      AND bm.user_id <> v_user_id  -- don't notify the joiner
      AND (
        bm.role = 'ceo'
        OR (
          bm.role IN ('admin', 'manager')
          AND (
            -- warehouse-targeted: only when the new staff has a warehouse
            -- AND the recipient is assigned to the same one
            v_warehouse_id IS NOT NULL
            AND bm.warehouse_id = v_warehouse_id
          )
        )
      );
  END IF;

  -- 7. Return canonical rows for _applyDomainResponse.
  RETURN jsonb_build_object(
    'user',       (SELECT to_jsonb(u) FROM public.users           u WHERE u.id = v_user_id),
    'membership', (SELECT to_jsonb(m) FROM public.business_members m WHERE m.id = v_membership_id),
    'invite',     (SELECT to_jsonb(i) FROM public.invites          i WHERE i.id = p_invite_id)
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.accept_invite(uuid, text, text, text, text, text, text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION public.accept_invite(uuid, text, text, text, text, text, text, text, text) TO authenticated, service_role;

-- =============================================================================
-- Verification:
--
--   1. Function exists with new signature (9 args):
--      \df public.accept_invite
--
--   2. Replay produces no duplicate notifications:
--      -- (run accept_invite twice with same auth context + invite_id)
--      SELECT count(*) FROM public.notifications
--      WHERE linked_record_id = '<membership_id>';
--      -- expect: 1 per intended recipient (CEO + warehouse-matched), not 2x
--
--   3. Notification routing — see manual check #6 in the plan.
-- =============================================================================
