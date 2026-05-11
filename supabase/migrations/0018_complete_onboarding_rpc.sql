-- =============================================================================
-- 0018_complete_onboarding_rpc.sql — Atomic onboarding commit.
--
-- Adds public.complete_onboarding(...) which inserts businesses + profiles +
-- warehouses + settings in one transaction with onboarding_complete = true.
-- The redesigned wizard (collect-first, commit-once) calls this RPC after
-- the user confirms their PIN, so abandonment at any earlier step leaves
-- nothing in the cloud.
--
-- Coexists with public.start_onboarding(...) from 0004 — that two-step path
-- and its companion resume branch in AuthService.createNewOwner remain in
-- place until the new wizard ships and stabilises. Deletion is a follow-up
-- migration.
--
-- Apply after 0017_distinguish_missing_inventory_from_insufficient.sql.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.complete_onboarding(
  p_business_id    uuid,
  p_warehouse_id   uuid,
  p_owner_name     text,
  p_business_name  text,
  p_business_type  text,
  p_business_phone text,
  p_business_email text,
  p_location       jsonb,   -- {name, street, city, state, country}
  p_settings       jsonb    -- {currency, timezone, tax_reg_number}
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

  -- Reject ownership mismatch on retry: if a prior attempt already created
  -- this business under a different auth user, fail loud rather than silently
  -- stealing the row. (ON CONFLICT DO UPDATE below would otherwise overwrite.)
  IF EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = p_business_id AND owner_id IS NOT NULL AND owner_id <> v_uid
  ) THEN
    RAISE EXCEPTION 'complete_onboarding: business % is owned by a different user', p_business_id;
  END IF;

  -- 1. businesses — insert with onboarding_complete = true from the start.
  --    Idempotent on (id) so a retry after a transient network failure
  --    succeeds (the client retries with the same p_business_id).
  INSERT INTO public.businesses (id, owner_id, onboarding_complete, name, type, phone, email)
    VALUES (p_business_id, v_uid, true, p_business_name, p_business_type, p_business_phone, p_business_email)
  ON CONFLICT (id) DO UPDATE
    SET name                = EXCLUDED.name,
        type                = EXCLUDED.type,
        phone               = EXCLUDED.phone,
        email               = EXCLUDED.email,
        onboarding_complete = true;

  -- 2. profiles — id = auth.uid() pins the row to this user. Idempotent on
  --    (id) so the same auth user retrying is a no-op update.
  INSERT INTO public.profiles (id, business_id, name, role, role_tier)
    VALUES (v_uid, p_business_id, p_owner_name, 'ceo', 5)
  ON CONFLICT (id) DO UPDATE
    SET business_id = EXCLUDED.business_id,
        name        = EXCLUDED.name,
        role        = EXCLUDED.role,
        role_tier   = EXCLUDED.role_tier;

  -- 3. warehouses — combine the structured location parts the same way the
  --    legacy LocationDetailsScreen did ("street, city/state, country") so
  --    downstream code that reads warehouses.location keeps working.
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

  -- 4. settings — currency + timezone always; tax registration number only if
  --    the user provided one. UNIQUE (business_id, key) makes the upsert key
  --    well-defined for retries.
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
END;
$$;

REVOKE ALL    ON FUNCTION public.complete_onboarding(uuid, uuid, text, text, text, text, text, jsonb, jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.complete_onboarding(uuid, uuid, text, text, text, text, text, jsonb, jsonb) TO authenticated;
