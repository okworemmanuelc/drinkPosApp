-- =============================================================================
-- 0023_complete_onboarding_seeds_membership.sql — CEO membership at signup.
--
-- complete_onboarding (0018) inserts businesses + profiles + warehouses +
-- settings. With business_members live (0020), the CEO also needs a paired
-- membership row created at the same atomic moment so post-onboarding
-- bootstrap reads find a membership that matches their auth user.
--
-- Body is byte-identical to 0018 except for the new INSERT INTO
-- business_members at the end. CEO membership is auto-approved because the
-- business owner does not need to verify themselves.
--
-- Idempotent on (business_id, user_id) so retries after a transient network
-- failure are safe.
--
-- Apply after 0022_accept_invite_rpc.sql.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.complete_onboarding(
  p_business_id    uuid,
  p_warehouse_id   uuid,
  p_owner_name     text,
  p_business_name  text,
  p_business_type  text,
  p_business_phone text,
  p_business_email text,
  p_location       jsonb,
  p_settings       jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_loc_name text;
  v_loc_combined text;
  v_currency text;
  v_timezone text;
  v_tax text;
  v_user_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'complete_onboarding requires an authenticated session';
  END IF;

  IF p_business_id IS NULL OR p_warehouse_id IS NULL THEN
    RAISE EXCEPTION 'complete_onboarding requires non-null p_business_id and p_warehouse_id';
  END IF;

  IF p_owner_name IS NULL OR length(trim(p_owner_name)) = 0
     OR p_business_name IS NULL OR length(trim(p_business_name)) = 0 THEN
    RAISE EXCEPTION 'complete_onboarding requires non-empty p_owner_name and p_business_name';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = p_business_id AND owner_id IS NOT NULL AND owner_id <> v_uid
  ) THEN
    RAISE EXCEPTION 'complete_onboarding: business % is owned by a different user', p_business_id;
  END IF;

  -- 1. businesses.
  INSERT INTO public.businesses (id, owner_id, onboarding_complete, name, type, phone, email)
    VALUES (p_business_id, v_uid, true, p_business_name, p_business_type, p_business_phone, p_business_email)
  ON CONFLICT (id) DO UPDATE
    SET name                = EXCLUDED.name,
        type                = EXCLUDED.type,
        phone               = EXCLUDED.phone,
        email               = EXCLUDED.email,
        onboarding_complete = true;

  -- 2. profiles.
  INSERT INTO public.profiles (id, business_id, name, role, role_tier)
    VALUES (v_uid, p_business_id, p_owner_name, 'ceo', 5)
  ON CONFLICT (id) DO UPDATE
    SET business_id = EXCLUDED.business_id,
        name        = EXCLUDED.name,
        role        = EXCLUDED.role,
        role_tier   = EXCLUDED.role_tier;

  -- 3. warehouses.
  v_loc_name := COALESCE(NULLIF(trim(p_location ->> 'name'), ''), 'Main Warehouse');
  v_loc_combined := concat_ws(', ',
    NULLIF(trim(coalesce(p_location ->> 'street', '')), ''),
    NULLIF(trim(coalesce(p_location ->> 'city',   '')), ''),
    NULLIF(trim(coalesce(p_location ->> 'country',''))  , '')
  );

  INSERT INTO public.warehouses (id, business_id, name, location, is_deleted)
    VALUES (p_warehouse_id, p_business_id, v_loc_name, NULLIF(v_loc_combined, ''), false)
  ON CONFLICT (id) DO UPDATE
    SET name     = EXCLUDED.name,
        location = EXCLUDED.location;

  -- 4. settings.
  v_currency := COALESCE(NULLIF(trim(p_settings ->> 'currency'), ''), 'NGN');
  v_timezone := COALESCE(NULLIF(trim(p_settings ->> 'timezone'), ''), 'Africa/Lagos');
  v_tax      := NULLIF(trim(coalesce(p_settings ->> 'tax_reg_number', '')), '');

  INSERT INTO public.settings (business_id, key, value)
    VALUES (p_business_id, 'default_currency', v_currency)
  ON CONFLICT (business_id, key) DO UPDATE SET value = EXCLUDED.value;

  INSERT INTO public.settings (business_id, key, value)
    VALUES (p_business_id, 'timezone', v_timezone)
  ON CONFLICT (business_id, key) DO UPDATE SET value = EXCLUDED.value;

  IF v_tax IS NOT NULL THEN
    INSERT INTO public.settings (business_id, key, value)
      VALUES (p_business_id, 'tax_registration_number', v_tax)
    ON CONFLICT (business_id, key) DO UPDATE SET value = EXCLUDED.value;
  END IF;

  -- 5. users — find-or-create. Onboarding flow historically wrote the row
  --    client-side after this RPC returned, but that left a window where
  --    the membership lookup below could find no users row. Mint it here
  --    so the membership FK resolves cleanly. Idempotent on (auth_user_id).
  SELECT id INTO v_user_id
    FROM public.users
   WHERE auth_user_id = v_uid AND business_id = p_business_id
   LIMIT 1;

  IF v_user_id IS NULL THEN
    INSERT INTO public.users (
      auth_user_id, business_id, name, email,
      role, role_tier
    ) VALUES (
      v_uid, p_business_id, p_owner_name, p_business_email,
      'ceo', 5
    )
    ON CONFLICT (business_id, email) DO UPDATE
      SET auth_user_id    = EXCLUDED.auth_user_id,
          name            = EXCLUDED.name,
          role            = EXCLUDED.role,
          role_tier       = EXCLUDED.role_tier,
          last_updated_at = now()
    RETURNING id INTO v_user_id;
  END IF;

  -- 6. business_members — CEO membership, auto-approved (no verification
  --    required for the business owner). Idempotent on (business_id, user_id).
  INSERT INTO public.business_members (
    business_id, user_id, role, role_tier,
    status, verification_status, verification_due_at,
    joined_at
  ) VALUES (
    p_business_id, v_user_id, 'ceo', 5,
    'active', 'approved', NULL,
    now()
  )
  ON CONFLICT (business_id, user_id) DO UPDATE
    SET role                = EXCLUDED.role,
        role_tier           = EXCLUDED.role_tier,
        status              = EXCLUDED.status,
        verification_status = EXCLUDED.verification_status,
        verification_due_at = EXCLUDED.verification_due_at,
        last_updated_at     = now();
END;
$$;

REVOKE ALL    ON FUNCTION public.complete_onboarding(uuid, uuid, text, text, text, text, text, jsonb, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.complete_onboarding(uuid, uuid, text, text, text, text, text, jsonb, jsonb) TO authenticated;
