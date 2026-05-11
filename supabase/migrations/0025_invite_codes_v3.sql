-- =============================================================================
-- 0025_invite_codes_v3.sql — 8-char codes + regeneration tracking.
--
-- The rev 3 redesign drops email/SMS dispatch entirely and standardises on a
-- single 8-character code shared by the admin via WhatsApp / SMS / Email /
-- in-person. Two schema changes:
--
--   1. Regeneration provenance — when an admin generates a fresh code for
--      an unredeemed invite, the new row points back at the revoked old
--      row via `regenerated_from`. Lets the audit trail trace any code
--      back to its first issuance and identify "this admin re-issued the
--      code three times before it was used."
--
--   2. One-time cleanup — rev 2 (in production briefly) shipped 6-character
--      human_codes. Rev 3 standardises on 8 characters. Any pending invites
--      issued with 6-char codes during the rev 2 window are revoked here so
--      no admin/staff is left holding a code the new validator won't accept.
--      Admins must re-issue any pending invites after this migration runs.
--
-- The partial unique index `uq_invites_pending_human_code` from 0021 is
-- kept as-is; TEXT columns accept any length, so a 6→8 character change
-- needs no index rework. (Earlier draft of this migration recreated it
-- defensively; dropped — it's a no-op write.)
--
-- Idempotent. Apply after 0024_business_members_signup_fields.sql.
-- =============================================================================

-- 1. Regeneration tracking columns.
ALTER TABLE public.invites
  ADD COLUMN IF NOT EXISTS regenerated_from uuid REFERENCES public.invites(id),
  ADD COLUMN IF NOT EXISTS regenerated_at   timestamptz;

CREATE INDEX IF NOT EXISTS idx_invites_regenerated_from
  ON public.invites (regenerated_from)
  WHERE regenerated_from IS NOT NULL;

-- 2. One-time cleanup of rev 2's 6-char pending invites.
--    Safe to re-run: only matches rows that are still pending AND have a
--    6-char human_code. Once revoked, the WHERE clause excludes them on
--    subsequent runs.
UPDATE public.invites
   SET status = 'revoked',
       last_updated_at = now()
 WHERE status = 'pending'
   AND human_code IS NOT NULL
   AND length(human_code) = 6;

-- =============================================================================
-- Verification:
--
--   1. Columns landed:
--      SELECT column_name FROM information_schema.columns
--      WHERE table_schema='public' AND table_name='invites'
--        AND column_name IN ('regenerated_from','regenerated_at');
--      -- expect 2 rows
--
--   2. No 6-char pending codes survive:
--      SELECT count(*) FROM public.invites
--      WHERE status='pending' AND length(human_code)=6;
--      -- expect 0
--
--   3. Index landed:
--      SELECT indexname FROM pg_indexes
--      WHERE schemaname='public' AND tablename='invites'
--        AND indexname='idx_invites_regenerated_from';
--      -- expect 1 row
-- =============================================================================
