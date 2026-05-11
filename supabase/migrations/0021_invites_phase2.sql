-- =============================================================================
-- 0021_invites_phase2.sql — Invites schema additions for staff onboarding v2.
--
-- Adds:
--   • phone TEXT — captured at invite time so the SMS sender (Termii, Phase 1.5)
--     has a destination. Nullable column, modal-layer validation enforces
--     "required" for new invites; legacy rows keep NULL.
--   • human_code TEXT — six-character, unambiguous-alphabet code (no 0/O/1/I)
--     for in-person reading: "Tell them to enter K7M-3PX in the app." Distinct
--     from the existing 8-char `code` (kept for backward compat) and from the
--     URL `token` (long random, never read aloud).
--   • last_resend_requested_at TIMESTAMPTZ — backs the per-token rate limit
--     on the `request-resend` Edge Function (Phase 2; column added now to
--     land with the rest of the invites schema).
--   • token_hash TEXT — defensive ADD IF NOT EXISTS. The column has been in
--     production since the first invite Edge Function landed but was never
--     captured in a committed migration; this normalises the schema for
--     fresh environments.
--
-- Backfill: existing invites carry an empty string for `invitee_name` because
-- the Edge Function used to pass `""` to satisfy the NOT NULL constraint
-- (the real name was collected later in the redeem step). New invites carry
-- the real name. Normalise legacy empties to "Unknown" so the column reads
-- meaningfully going forward.
--
-- Idempotent: every ALTER uses IF [NOT] EXISTS; the partial unique index is
-- IF NOT EXISTS; the backfill is conditional.
--
-- Apply after 0020_business_members.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. New columns.
-- -----------------------------------------------------------------------------

ALTER TABLE public.invites
  ADD COLUMN IF NOT EXISTS phone                    text,
  ADD COLUMN IF NOT EXISTS human_code               text,
  ADD COLUMN IF NOT EXISTS last_resend_requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS token_hash               text;

-- -----------------------------------------------------------------------------
-- 2. Partial unique index on human_code.
--    Mirrors uq_invites_pending_code (0001_initial.sql line 185): the value
--    only needs to be unique while the invite is pending. Once accepted,
--    expired, or revoked, the same human_code may be reissued. Keeps the
--    keyspace usable across years of operation.
-- -----------------------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS uq_invites_pending_human_code
  ON public.invites (human_code)
  WHERE status = 'pending' AND human_code IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3. Backfill invitee_name empties.
--    The column is already NOT NULL (0001_initial.sql line 174); this just
--    normalises the empty-string sentinel inserted by the legacy issue path
--    so downstream UI can render the value without special-casing.
-- -----------------------------------------------------------------------------

UPDATE public.invites
   SET invitee_name = 'Unknown'
 WHERE invitee_name IS NULL OR length(trim(invitee_name)) = 0;

-- =============================================================================
-- Verification:
--
--   1. Columns landed:
--      SELECT column_name FROM information_schema.columns
--      WHERE table_schema='public' AND table_name='invites'
--        AND column_name IN ('phone','human_code','last_resend_requested_at','token_hash');
--      -- expect 4 rows
--
--   2. Partial index landed:
--      SELECT indexdef FROM pg_indexes
--      WHERE schemaname='public' AND tablename='invites'
--        AND indexname='uq_invites_pending_human_code';
--      -- expect 1 row
--
--   3. No legacy empties remain:
--      SELECT count(*) FROM public.invites
--      WHERE invitee_name IS NULL OR length(trim(invitee_name)) = 0;
--      -- expect 0
-- =============================================================================
