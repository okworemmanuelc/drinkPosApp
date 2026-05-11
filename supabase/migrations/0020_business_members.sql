-- =============================================================================
-- 0020_business_members.sql — Per-business membership join table.
--
-- Splits per-business state (role, role_tier, warehouse_id, PIN, biometric_enabled,
-- verification status) off the global `users` identity into a `business_members`
-- join keyed on (business_id, user_id). Enables a single user to belong to
-- multiple businesses; gives every membership an independent verification
-- record with a 7-day grace window.
--
-- This migration is additive: the legacy columns on `users` are left intact.
-- Phase 5 of the staff-onboarding rollout drops them, after the client has
-- migrated all reads to `business_members`.
--
-- Backfill — grandfather clause: every existing non-deleted `users` row gets
-- one paired membership with verification_status='approved' and
-- verification_due_at=NULL. Verification applies only to staff onboarded
-- AFTER this rollout. Documenting this here so a future operator does not
-- mistake the absence of due dates on legacy rows for a backfill bug.
--
-- Idempotent: every CREATE / ALTER is guarded; backfill is INSERT … ON
-- CONFLICT DO NOTHING.
--
-- Apply after 0019_add_users_to_pull_snapshot.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Table.
--    PIN columns mirror the local Drift shape and are cloud-replicated so that
--    a staff member sees the same PIN on every device for a given membership.
--    The hash is opaque PBKDF2 output; cloud-syncing it adds no meaningful
--    surface beyond the auth credentials already kept by Supabase.
--    `verification_extensions_used` caps how many times a rejection may push
--    out the due date (max 2; review_verification enforces).
--    `created_by` FK is intentionally NOT cascading — if the inviter is later
--    removed, the membership stays for audit. Same logic as invites.created_by.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.business_members (
  id                            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id                   uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id                       uuid NOT NULL REFERENCES public.users(id)      ON DELETE CASCADE,
  role                          text NOT NULL CHECK (role IN ('admin','staff','ceo','manager')),
  role_tier                     int  NOT NULL DEFAULT 1 CHECK (role_tier IN (1,4,5)),
  warehouse_id                  uuid REFERENCES public.warehouses(id),
  pin_hash                      text,
  pin_salt                      text,
  pin_iterations                int,
  biometric_enabled             boolean NOT NULL DEFAULT false,
  status                        text NOT NULL DEFAULT 'active'
                                CHECK (status IN ('active','suspended','removed')),
  verification_status           text NOT NULL DEFAULT 'not_started'
                                CHECK (verification_status IN ('not_started','pending_review','approved','rejected')),
  verification_due_at           timestamptz,
  verification_extensions_used  int  NOT NULL DEFAULT 0 CHECK (verification_extensions_used >= 0 AND verification_extensions_used <= 2),
  joined_at                     timestamptz NOT NULL DEFAULT now(),
  created_by                    uuid REFERENCES public.users(id),
  removed_at                    timestamptz,
  removed_by                    uuid REFERENCES public.users(id),
  is_deleted                    boolean NOT NULL DEFAULT false,
  created_at                    timestamptz NOT NULL DEFAULT now(),
  last_updated_at               timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, user_id)
);

-- Standard sync indexes — incremental pull keys on (business_id, last_updated_at);
-- soft-delete filter keys on (business_id, is_deleted).
CREATE INDEX IF NOT EXISTS idx_business_members_business_lua
  ON public.business_members (business_id, last_updated_at);
CREATE INDEX IF NOT EXISTS idx_business_members_business_deleted
  ON public.business_members (business_id, is_deleted);
CREATE INDEX IF NOT EXISTS idx_business_members_user
  ON public.business_members (user_id);

-- -----------------------------------------------------------------------------
-- 2. RLS — enable + force, then mirror the standard four-policy tenant guard
--    used everywhere else (see 0002_rls.sql §3).
-- -----------------------------------------------------------------------------

ALTER TABLE public.business_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_members FORCE  ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_select ON public.business_members;
DROP POLICY IF EXISTS tenant_insert ON public.business_members;
DROP POLICY IF EXISTS tenant_update ON public.business_members;
DROP POLICY IF EXISTS tenant_delete ON public.business_members;

CREATE POLICY tenant_select ON public.business_members
  FOR SELECT TO authenticated
  USING (business_id = public.business_id());

CREATE POLICY tenant_insert ON public.business_members
  FOR INSERT TO authenticated
  WITH CHECK (business_id = public.business_id());

CREATE POLICY tenant_update ON public.business_members
  FOR UPDATE TO authenticated
  USING (business_id = public.business_id())
  WITH CHECK (business_id = public.business_id());

CREATE POLICY tenant_delete ON public.business_members
  FOR DELETE TO authenticated
  USING (business_id = public.business_id());

-- -----------------------------------------------------------------------------
-- 3. Grants — default privileges (0003_grants.sql §2) already cover newly
--    created tables, but explicit GRANTs guarantee correctness regardless
--    of the order migrations run in fresh environments.
-- -----------------------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE, DELETE ON public.business_members TO authenticated;
GRANT ALL                            ON public.business_members TO service_role;

-- -----------------------------------------------------------------------------
-- 4. Backfill (grandfather).
--    One membership per non-deleted user. PIN columns copied as NULL in
--    cloud (PIN columns on `public.users` were dropped historically — they
--    only existed locally in Drift). The local v5→v6 Drift migration copies
--    each device's local PIN into its corresponding membership row, so the
--    PIN survives the move and starts syncing on the next push.
--    ON CONFLICT DO NOTHING makes the migration safely re-runnable.
-- -----------------------------------------------------------------------------

INSERT INTO public.business_members (
  business_id, user_id, role, role_tier, warehouse_id,
  status, verification_status, verification_due_at,
  joined_at, created_at, last_updated_at
)
SELECT
  u.business_id,
  u.id,
  u.role,
  u.role_tier,
  u.warehouse_id,
  'active',
  'approved',         -- grandfather: every existing user is auto-verified
  NULL,               -- no due date for grandfathered members
  u.created_at,
  u.created_at,
  now()
FROM public.users u
WHERE u.is_deleted = false
ON CONFLICT (business_id, user_id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 5. Extend pos_pull_snapshot.
--    Mirror 0019_add_users_to_pull_snapshot.sql exactly — same body, just
--    add 'business_members' to v_tenant_tables. Function body is byte-
--    identical to 0019 except for that single array entry.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.pos_pull_snapshot(
  p_business_id uuid,
  p_since       timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_caller_business uuid;
  v_result          jsonb := '{}'::jsonb;
  v_table           text;
  v_rows            jsonb;
  v_query           text;
  v_tenant_tables   text[] := ARRAY[
    'profiles','users','business_members','warehouses','manufacturers','crate_groups',
    'categories','products','inventory','customers','suppliers',
    'orders','order_items','purchases','purchase_items',
    'expenses','expense_categories',
    'customer_crate_balances','delivery_receipts','drivers',
    'stock_transfers','stock_adjustments','activity_logs',
    'notifications','stock_transactions',
    'customer_wallets','wallet_transactions',
    'saved_carts','pending_crate_returns','invites',
    'manufacturer_crate_balances','crate_ledger',
    'price_lists','payment_transactions','sessions','settings'
  ];
BEGIN
  v_caller_business := public.business_id();
  IF v_caller_business IS NULL THEN
    RAISE EXCEPTION 'no_business_for_caller'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF v_caller_business <> p_business_id THEN
    RAISE EXCEPTION 'tenant_mismatch'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(b)), '[]'::jsonb)
    INTO v_rows
    FROM public.businesses b
    WHERE b.id = p_business_id
      AND (p_since IS NULL OR b.last_updated_at > p_since);
  v_result := v_result || jsonb_build_object('businesses', v_rows);

  FOREACH v_table IN ARRAY v_tenant_tables LOOP
    v_query := format(
      'SELECT COALESCE(jsonb_agg(to_jsonb(t)), ''[]''::jsonb)
         FROM public.%I t
         WHERE t.business_id = $1
           AND ($2::timestamptz IS NULL OR t.last_updated_at > $2)',
      v_table
    );
    EXECUTE v_query INTO v_rows USING p_business_id, p_since;
    v_result := v_result || jsonb_build_object(v_table, v_rows);
  END LOOP;

  SELECT COALESCE(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
    INTO v_rows
    FROM public.system_config s
    WHERE (p_since IS NULL OR s.last_updated_at > p_since);
  v_result := v_result || jsonb_build_object('system_config', v_rows);

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.pos_pull_snapshot(uuid, timestamptz) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_pull_snapshot(uuid, timestamptz)
  TO authenticated;

-- =============================================================================
-- Verification (paste into the SQL editor while signed in as a regular user):
--
--   1. Backfill produced exactly one membership per user:
--      SELECT (SELECT count(*) FROM public.users WHERE is_deleted = false) AS users,
--             (SELECT count(*) FROM public.business_members)               AS members;
--      -- expect users == members
--
--   2. Every backfilled membership is verified:
--      SELECT verification_status, count(*) FROM public.business_members
--      GROUP BY verification_status;
--      -- expect a single row: approved | <count>
--
--   3. Snapshot includes the new table:
--      SELECT jsonb_object_keys(public.pos_pull_snapshot(public.business_id(), NULL))
--      WHERE jsonb_object_keys = 'business_members';
--      -- expect 1 row
-- =============================================================================
