-- =============================================================================
-- 0003_grants.sql — Table/sequence privileges for the standard Supabase roles.
--
-- Why this exists: 0001_initial.sql drops and recreates the public schema,
-- which wipes Supabase's bootstrap default privileges. Without table-level
-- GRANTs, Postgres rejects every client query with 42501 ("permission denied")
-- *before* RLS is evaluated — even when the RLS policy would allow the row.
--
-- RLS is the real access filter; these grants only let the role reach the
-- table so the policy can run.
--
-- Idempotent: GRANT is repeatable, ALTER DEFAULT PRIVILEGES is keyed on
-- (role, schema, object-type) and replaces prior matching grants.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Existing tables — authenticated does CRUD; RLS scopes to the tenant.
--    anon gets nothing on tables (no public read paths in this app).
--    service_role gets ALL (it bypasses RLS but still needs object grants).
-- -----------------------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES    IN SCHEMA public TO authenticated;
GRANT USAGE,  SELECT                  ON ALL SEQUENCES IN SCHEMA public TO authenticated;

GRANT ALL ON ALL TABLES    IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- -----------------------------------------------------------------------------
-- 2. Default privileges — any table/sequence/function created later in
--    public by the postgres role automatically picks these up. Without this,
--    the next migration would silently re-introduce 42501.
-- -----------------------------------------------------------------------------

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES    TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE,  SELECT                 ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES    TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON FUNCTIONS TO service_role;
