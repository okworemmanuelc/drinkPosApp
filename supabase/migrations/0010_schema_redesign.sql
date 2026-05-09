-- =============================================================================
-- 0010_schema_redesign.sql — Phase A of the schema/sync redesign.
--
-- Lands two structural changes that don't depend on any new RPCs:
--
--   1. Drop public.crates. The local Drift table has no writers and the
--      sync code already comments it out as "removed — cloud schema has
--      only crate_groups". Cloud table follows.
--
--   2. Add an XOR check on crate_ledger.(reference_order_id,
--      reference_return_id). Other ledgers (stock_transactions,
--      payment_transactions) constrain their typed-FK set to "exactly one";
--      crate_ledger had nothing. Start with `<= 1` (some movements like
--      `adjusted` legitimately reference neither). Tighten to `= 1` later
--      after auditing real data, if appropriate. A pre-check audits
--      existing rows and aborts with a clear error if any violate the
--      constraint, rather than letting ALTER TABLE fail mid-migration.
--
-- DEFERRED — cache-table RLS lockdown.
--   An earlier draft of this migration removed authenticated INSERT/UPDATE/
--   DELETE policies from `inventory`, `customer_crate_balances`, and
--   `manufacturer_crate_balances` on the assumption that domain RPCs (which
--   bypass RLS via SECURITY DEFINER) would be the only writers. That's true
--   *after* Phase C cuts the multi-table call sites over to v2 RPCs. Until
--   then, paths like OrdersDao.markCancelled, CrateReturnApprovalService.
--   approve, and CrateLedgerDao.record* still upsert these tables directly,
--   so dropping the policies broke those flows.
--   The lockdown moves to a later migration that lands once Phase C is
--   complete and `_syncedTenantTables` no longer contains the cache tables.
--   See 0013_restore_cache_rls_policies.sql for the restore that undoes
--   the prematurely-applied lockdown on already-migrated databases.
--
-- Idempotent on re-run: every DROP / ADD is guarded.
-- Apply after 0009_disambiguate_inventory_errors.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Drop public.crates
--    Nothing references crates (verified against 0001 — it has FKs to
--    businesses and products but is not the target of any FK), so CASCADE
--    only sweeps the table's own constraints/indexes/triggers.
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS public.crates CASCADE;

-- -----------------------------------------------------------------------------
-- 2. crate_ledger reference XOR.
--    Pre-audit: count any rows that already violate the new check. If any
--    exist, abort with a sample of offending ids so the operator can clean
--    or null them before re-running. Without this guard, ALTER TABLE would
--    fail with a generic check-constraint message that doesn't point at
--    the bad rows.
-- -----------------------------------------------------------------------------

DO $$
DECLARE
  v_violators int;
  v_sample    text;
BEGIN
  SELECT count(*) INTO v_violators
    FROM public.crate_ledger
   WHERE reference_order_id  IS NOT NULL
     AND reference_return_id IS NOT NULL;

  IF v_violators > 0 THEN
    SELECT string_agg(id::text, ', ') INTO v_sample
      FROM (
        SELECT id FROM public.crate_ledger
         WHERE reference_order_id  IS NOT NULL
           AND reference_return_id IS NOT NULL
         LIMIT 10
      ) s;
    RAISE EXCEPTION
      'crate_ledger has % row(s) with both reference_order_id and reference_return_id set. '
      'XOR constraint cannot be added until these are remediated. Sample ids: %.',
      v_violators, v_sample;
  END IF;
END $$;

ALTER TABLE public.crate_ledger
  DROP CONSTRAINT IF EXISTS crate_ledger_ref_xor;

ALTER TABLE public.crate_ledger
  ADD CONSTRAINT crate_ledger_ref_xor
  CHECK (
    (reference_order_id  IS NOT NULL)::int +
    (reference_return_id IS NOT NULL)::int <= 1
  );

-- Cache-table RLS lockdown originally lived here. See header comment for
-- why it moved.

-- =============================================================================
-- Verification (paste into the SQL editor while signed in as a regular user):
--
--   1. crates is gone:
--      SELECT to_regclass('public.crates');   -- NULL
--
--   2. XOR check is in place:
--      \d+ public.crate_ledger
--      -- expect a CHECK named crate_ledger_ref_xor
--
--      INSERT INTO public.crate_ledger
--        (id, business_id, customer_id, crate_group_id, quantity_delta,
--         movement_type, reference_order_id, reference_return_id)
--      VALUES (gen_random_uuid(), public.business_id(), '<cust uuid>',
--              '<group uuid>', 1, 'adjusted', '<order uuid>', '<return uuid>');
--      -- expect: ERROR  new row violates check constraint "crate_ledger_ref_xor"
--
--   3. Cache tables still readable AND writable by authenticated clients:
--      SELECT count(*) FROM public.inventory;   -- works, returns own tenant's count
--      INSERT INTO public.inventory
--        (id, business_id, product_id, warehouse_id, quantity)
--      VALUES (gen_random_uuid(), public.business_id(),
--              '<product uuid>', '<warehouse uuid>', 0);
--      -- expect: success (lockdown deferred until Phase C complete).
--
-- =============================================================================
