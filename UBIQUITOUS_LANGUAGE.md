# Ubiquitous Language

Domain glossary for Reebaplus POS. Terms an AI agent (or new dev) is
likely to either guess wrong or fail to map to a code identifier.
Keep entries to one or two lines. If a term doesn't survive that
budget, it doesn't belong here.

Companion to [CLAUDE.md](CLAUDE.md). When in doubt, this file
disambiguates the word; CLAUDE.md states the rules.

## Tenancy & identity

- **Business** — a tenant. Every operational record is scoped by `business_id`. One business = one POS instance from the operator's view.
- **`business_id`** — UUID tenant key. Carried on every tenant row and validated by RLS via `get_user_business_id()` (auth.uid → users → business_id).
- **`business_members`** — the join table between `users` and `businesses` introduced in migration 0020. Pre-0020 the relation was implicit on `users`; post-0020 a user may have multiple memberships (one active at a time today, multi-tenant later).
- **CEO** — the business owner, role `'ceo'`. Currently one per business by convention; **not enforced at the database level** (no partial unique index on `role='ceo'` in migration 0020). Created at onboarding; cannot be invited.
- **Role tier** — one of `'admin' | 'staff' | 'ceo' | 'manager'`. Anything outside this set is rejected by the local `CHECK` and the cloud RPC.
- **`businessIdResolver`** — the Riverpod provider every screen and DAO call uses to learn the current business. Single source of truth at runtime; never read `business_id` from a stale local row.
- **Invite** — a pending `business_members` row. Accepted via `accept_invite` RPC, which seeds the user, the membership, and the activity log atomically.
- **Verification status** — `'not_started' | 'pending_review' | 'approved' | 'rejected'` on a membership (CHECK constraint in migration 0020). New staff onboarded after 0020 start at `'not_started'`; pre-0020 users were grandfathered to `'approved'`.
- **PIN (hashed)** — device-unlock secret stored per `business_members` row. The hash is opaque, so it replicates to cloud safely; the plaintext PIN never leaves the device that set it.

## Sync mechanics

- **Synced table** — a tenant table in `_syncedTenantTables`. Every write must flow through `SyncDao`. Listed in [lib/core/database/app_database.dart](lib/core/database/app_database.dart).
- **Cache table** — `inventory`, `customer_crate_balances`, `manufacturer_crate_balances`. Local materializations of ledger state. Never written from a DAO; only `_restoreTableData` (pull) and `_applyDomainResponse` (domain RPC echo) may touch them.
- **Ledger (append-only)** — `stock_transactions`, `wallet_transactions`, `payment_transactions`, `activity_logs`. Core columns are immutable once written. Corrections happen via a new opposite-sign row, never an `UPDATE`.
- **`sync_queue`** — the local outbox. Holds `action_type = '<table>:upsert' | '<table>:delete' | 'domain:<rpc>'` envelopes. Drained by the push flush; per-table envelopes coalesce on `(action_type, id)`, domain envelopes do not.
- **Domain envelope / Domain RPC** — an atomic multi-table operation dispatched to the server as a single call (e.g. `domain:pos_record_sale`). The server applies all writes in one transaction and returns the canonical post-state, which `_applyDomainResponse` writes back locally without re-enqueueing.
- **Generic upsert** — the default path: `enqueueUpsert('table', row)` writes locally and queues a row-level upsert. Use this for plain CRUD. Use a domain envelope when multiple tables must change atomically.
- **`enqueueUpsert` / `enqueueDelete`** — the only sanctioned write entry points. `enqueueDelete` is for hard tombstones (cloud must forget). Soft-deletes (`is_deleted = true`) use `enqueueUpsert`.
- **Tombstone** — a hard delete on the cloud. Rare. Most "deletes" are soft (the row stays with `is_deleted = true`) so other devices can converge.
- **Soft delete** — `is_deleted = true` flag on a row. Applies only to tables in `_softDeletableTables`. Convergent across devices; the row is hidden in queries but still pulled.
- **`_restoreTableData`** — the pull/realtime ingress path in `supabase_sync_service.dart`. Writes directly to local tables without going through `SyncDao`. One of two legitimate exceptions to §5.
- **`_applyDomainResponse`** — the post-RPC echo path in `supabase_sync_service.dart`. Writes the server's authoritative response to local tables (including cache tables) without re-queueing. The other legitimate exception.
- **`last_updated_at` cursor** — per-table, per-business high-water mark. Incremental pulls fetch rows newer than the cursor. Bumped by a server-side trigger on every write.
- **Snapshot pull** — full-table fetch run on first boot or after a destructive reset. After the snapshot lands, future pulls are incremental.
- **Coalescing** — at enqueue time, a new per-table upsert for `(table, id)` overwrites a pending one. Domain envelopes are exempt — each is independent.
- **LWW (last-write-wins)** — the conflict-resolution stance for synced rows. Cloud-side `last_updated_at` wins; older local writes are clobbered by a newer pull. Cache tables don't use LWW because they're server-authoritative.
- **Idempotency key** — every domain RPC takes one. A replay returns the cached response without re-applying writes. Generated client-side per logical operation, not per retry.

## POS domain

- **Crate** — returnable empty bottle container. Tracked separately from product stock because crates circulate independently of the drinks inside them.
- **Crate group** — a SKU-level grouping for crates (e.g. "33cl glass crate"). Products reference a crate group, not individual crates.
- **`crate_ledger`** — append-only log of crate movements between business, customer, and manufacturer. Source of truth; `customer_crate_balances` and `manufacturer_crate_balances` are materializations.
- **Pending crate return** — a customer-acknowledged-but-not-yet-counted crate return. Resolved by `approve_crate_return` which writes the ledger row and updates balances.
- **Customer wallet** — a customer's running credit/debit balance with the business. One per (business, customer). Balance is derived from `wallet_transactions`, not stored.
- **Stock transaction** — append-only entry in `stock_transactions`. Every inventory movement (sale, purchase, transfer, adjustment) writes one with `quantity_delta` and a `movement_type` discriminator.
- **Activity log** — append-only operational audit trail. Written by domain RPCs, not by ad-hoc code. Immutable once written.
- **Saved cart** — a partially-built sale persisted before checkout. Survives app restarts.
- **Delivery receipt** — proof-of-delivery record linking an order to a driver and timestamp. Created at dispatch, finalized at delivery.

## Conventions

- **Kobo** — integer subunit, 1 NGN = 100 kobo. Money is always `*_kobo` columns. No floats, no decimals, ever.
- **`signed_amount_kobo`** — same magnitude as `amount_kobo` but with sign (`+` credit, `-` debit). Both columns appear on ledger tables for query convenience.
- **UUIDv7** — time-ordered UUID generated client-side. Sortable. Application code (e.g. `BusinessMembers.id.clientDefault`) issues v7s; SQLite-side backfill IDs are v4 because SQLite has no v7 helper.
- **Unix seconds** — timestamps are integer seconds since epoch. Not milliseconds, not ISO strings. Schema-wide.
- **`pos_*_v2` RPC** — the current generation of domain RPCs. The unsuffixed and `_v1` variants are deprecated; prefer `_v2` for any new call site.
- **RLS** — Postgres Row-Level Security. Every tenant table has a policy routing through `get_user_business_id()`. See [supabase/rls_snapshot.md](supabase/rls_snapshot.md).
