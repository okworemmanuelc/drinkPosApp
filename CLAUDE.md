# Project context — Reebaplus POS

Reebaplus is an offline-first POS for a drinks distributor. Flutter
client (Drift local DB) + Supabase backend (Postgres + RLS + RPCs).
Multi-tenant: every tenant table is scoped by `business_id`. Writes
are queued locally and pushed by a sync service; pulls are
incremental via per-row `last_updated_at` cursors, with one full
snapshot on first boot. The product is in active development —
see the redesign plan in `~/.claude/.../memory/redesign_plan.md`
for the multi-phase rewrite this codebase is mid-way through.

This file is the **Tier 1 entry point**. Read it every session.
Anything detailed lives in [`/docs`](docs/) — see [§10](#10-where-to-find-more)
for the map.

---

Behavioral guidelines to reduce common LLM coding
mistakes. Merge with project-specific instructions
as needed.

Tradeoff: These guidelines bias toward caution
over speed. For trivial tasks, use judgment.

## 1. Think Before Coding
Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them.
- If a simpler approach exists, say so.
- If something is unclear, stop. Name what's confusing.

## 2. Simplicity First
Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No “flexibility” that wasn't requested.
- No error handling for impossible scenarios.
- If 200 lines could be 50, rewrite it.

## 3. Surgical Changes
Touch only what you must. Clean up only your own mess.

- Don't “improve” adjacent code or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice dead code, mention it — don't delete it.

## 4. Goal-Driven Execution
Define success criteria. Loop until verified.

Transform tasks into verifiable goals:
- “Add validation” → “Write tests, then make them pass”
- “Fix the bug” → “Reproduce it in a test, then fix”
- “Refactor X” → “Ensure tests pass before and after”

## 5. Sync invariants

Every write to a synced table (anything in `_syncedTenantTables` in
[lib/core/database/app_database.dart](lib/core/database/app_database.dart))
must reach the cloud. The contract is:

- All writes go through a DAO method that calls `enqueueUpsert` /
  `enqueueDelete` on `SyncDao` (or enqueues a `domain:<rpc>` envelope
  for atomic multi-table actions). Writes via `db.into(...)`,
  `db.update(...)`, `db.delete(...)` *outside* a DAO are leaks — the
  cloud never sees them.
- Two legitimate exceptions, both narrow:
  1. `_restoreTableData` in `supabase_sync_service.dart` (incoming pull
     and realtime).
  2. `_applyDomainResponse` in `supabase_sync_service.dart` (server's
     authoritative response after a domain RPC succeeds — the server
     already has the truth; pushing it back would be a no-op round
     trip).
- Soft-delete (`is_deleted=true`) goes through `enqueueUpsert`. Only
  use `enqueueDelete` for hard tombstones the cloud needs to forget;
  it also clears any pending upsert for the same row.
- Domain envelopes (`domain:pos_record_sale`, `domain:pos_inventory_delta`,
  `domain:pos_create_product`) skip enqueue-time coalescing — each is an
  independent atomic transaction. Their payloads sit at `$.p_<arg>` and
  are dispatched via `_pushDomainItems`, not the per-table batched upsert
  path.
- Stream providers for synced tables live in
  [lib/core/providers/stream_providers.dart](lib/core/providers/stream_providers.dart).
  When a screen reads a synced table, prefer the existing provider over a
  one-shot `db.select(...).get()` so realtime events propagate without a
  manual refresh.

## 6. Cautious with Dependencies

Adding a Dart package is a long-term commitment. Before pulling one in:

- Search the codebase for an existing utility that does the job.
- Prefer the standard library / Flutter SDK / packages already in
  `pubspec.yaml` over new ones.
- If you must add one, surface it explicitly in the PR description with
  a one-line justification — don't bury it in `pubspec.yaml`.
- Never add a package that overlaps with one already present (two HTTP
  clients, two state managers, etc).

## 7. Append-only ledgers

Four tables are append-only. Their core columns are immutable once
written — `_ledgerTables` in [app_database.dart](lib/core/database/app_database.dart)
lists exactly which columns:

- `stock_transactions` — every inventory delta with provenance.
- `wallet_transactions` — every credit/debit on a customer wallet.
- `payment_transactions` — every money movement (sales, purchases, expenses, deliveries).
- `activity_logs` — every operationally significant action.

Rules:

- Never `UPDATE` an immutable column. Corrections happen by writing a
  new opposite-sign row, not by mutating history.
- Never `DELETE` from a ledger. Soft-delete doesn't apply here either.
- `created_at` is the truth; don't backdate or rewrite it.

If you find yourself wanting to update a ledger row, you're in the
wrong table — write a new row that compensates.

## 8. Cache tables are server-authoritative

Three tables are local materializations of ledger state, not user input:

- `inventory` — current on-hand per (product, warehouse).
- `customer_crate_balances` — crates out by customer.
- `manufacturer_crate_balances` — crates out by manufacturer.

These are **not** in `_syncedTenantTables`. The only legitimate local
writers are `_restoreTableData` (pull/realtime) and
`_applyDomainResponse` (every `pos_*_v2` RPC returns the canonical
post-state). Never write them from a DAO, a screen, or an ad-hoc
script — you'll create drift the next domain RPC will silently
overwrite.

## 9. Conventions

Definitions for `kobo`, UUIDv7, Unix-seconds timestamps, the role set,
and idempotency keys live in [UBIQUITOUS_LANGUAGE.md](UBIQUITOUS_LANGUAGE.md).
Read it once; don't restate those facts here.

## 10. Where to find more

`/docs/` will contain the Tier 2 docs as they get written. The map (some
of these are stubs at the time of writing — check before assuming):

- [docs/schema.md](docs/schema.md) — table groupings, sync classification, triggers, invariants. Companion to the generated column-level dump.
- [docs/schema.generated.md](docs/schema.generated.md) — generated from cloud `information_schema`. Look here for column-exact detail.
- [docs/sync-architecture.md](docs/sync-architecture.md) — `sync_queue` mechanics, domain envelopes, coalescing, outbox flush, restore/apply paths.
- [docs/auth-and-tenancy.md](docs/auth-and-tenancy.md) — session bootstrap, `businessIdResolver`, `users` ↔ `business_members`, RLS model.
- [docs/domain-rpcs.md](docs/domain-rpcs.md) — when-to-use guide for `pos_*_v2` / `domain:*` RPCs.
- [docs/rpcs.generated.md](docs/rpcs.generated.md) — generated catalog of RPC signatures, args, returns, idempotency.
- [docs/migrations.md](docs/migrations.md) — one-line history per migration.
- [docs/testing.md](docs/testing.md) — Tier 1/2/3 test conventions, mid-flight rollback test rule, how to run.
- [docs/agent-guide.md](docs/agent-guide.md) — orientation doc for AI agents and new humans.
- [docs/features/](docs/features/) — per-feature scratchpads (plan, decisions, open-questions). Shipped features move to `docs/features/archive/`.
- [UBIQUITOUS_LANGUAGE.md](UBIQUITOUS_LANGUAGE.md) — glossary of domain terms.

Also useful in the existing tree:

- [supabase/rls_snapshot.md](supabase/rls_snapshot.md) — RLS policy snapshot.
- [test/integration/README.md](test/integration/README.md) — integration-test conventions.

## 11. Out of scope right now

Don't design or document for these — they're explicitly deferred:

- Multi-CEO / multi-owner per business. Today: one CEO per business.
- Periodic staff re-verification. Today: one-time verification on first sign-in.
- Real-time identity changes (renaming a user across all their sessions live). Today: name resolves at session boundary.
- Cross-business user identity (one user, many businesses) beyond what `business_members` already supports passively.

If a task drifts into these, stop and confirm scope before proceeding.
