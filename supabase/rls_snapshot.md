# Supabase RLS Snapshot

> Snapshot taken 2026-04-27. Raw `pg_policies` output preserved at the bottom.

## Approach

**All tenant tables use the same pattern:** policies call a SQL helper
`get_user_business_id()` and compare the row's `business_id` (or `id`, for the
`businesses` table) against its return value:

- `qual` (read/update/delete filter): `business_id = get_user_business_id()`
- `with_check` (insert/update gate): `business_id = get_user_business_id()`

**Resolved 2026-04-27** — `get_user_business_id()` is the `auth.uid()` →
`profiles` join path:

```sql
CREATE OR REPLACE FUNCTION public.get_user_business_id()
 RETURNS bigint
 LANGUAGE sql
 STABLE
AS $function$
    SELECT business_id FROM profiles WHERE id = auth.uid();
$function$
```

So every tenant insert/select effectively asserts:
*the row's `business_id` equals the `business_id` on the `profiles` row whose
`id` matches the current `auth.uid()`*. **JWT claims are not used.**

## Per-table coverage

Every tenant table below has **all four** of {SELECT (via the `ALL` policy),
INSERT, UPDATE, DELETE} present. No table is missing a verb. There is some
redundancy: each table has both an `ALL` policy and per-verb policies; RLS
combines permissive policies with OR, so this is harmless but noisy.

Tables with full tenant-scoped coverage (`business_id = get_user_business_id()`):

`activity_logs`, `categories`, `crate_groups`, `customer_crate_balances`,
`customer_wallets`, `customers`, `delivery_receipts`, `drivers`,
`expense_categories`, `expenses`, `inventory`, `invites`, `manufacturers`,
`notifications`, `order_items`, `orders`, `payment_transactions`,
`pending_crate_returns`, `price_lists`, `products`, `purchase_items`,
`purchases`, `saved_carts`, `sessions`, `settings`, `stock_adjustments`,
`stock_transactions`, `stock_transfers`, `suppliers`, `users`,
`wallet_transactions`, `warehouses`.

Special-cased tables:

| Table | Policy | Notes |
|---|---|---|
| `businesses` | SELECT `(id = get_user_business_id())`; INSERT `with_check = true` | Anyone authenticated can insert (needed for onboarding); only owners can SELECT |
| `profiles` | SELECT/INSERT/UPDATE all keyed on `auth.uid() = id` | User-owned, not business-scoped |

## JWT claim

Not used by RLS. The in-app JWT decoder is informational only (confirms a
session is active), not a root-cause signal.

## Likely failure modes (given this snapshot)

Since policies are uniform, all verbs are covered, and the helper joins
`profiles` by `auth.uid()`, silent insert failures on `customers` (the
original report) reduce to one of:

1. **No `profiles` row for the current `auth.uid()`.** Sign-in succeeded but
   profile creation didn't, or was rolled back. `get_user_business_id()`
   returns NULL → every insert/select fails RLS.
2. **`profiles` row exists but its `business_id` is NULL.** Onboarding
   created the profile before linking it to a business. Same NULL outcome.
3. **App enqueues rows with a `business_id` that doesn't match the
   profile's.** Stale device state after a re-onboard / business switch.
   The Sync Issues failed-items list will surface this as `RLS rejection`.
4. **App enqueues rows with `business_id = NULL`.** Caught by the
   `pushPending` guard and marked `missing_business_id` — already visible.

### Probes (run while signed in as the affected user)

```sql
-- What the helper resolves to for this session:
SELECT get_user_business_id();

-- The profiles row backing the helper:
SELECT id, business_id FROM profiles WHERE id = auth.uid();
```

If `get_user_business_id()` returns NULL, the fix is server-side data
(repair the profile row), not a code change here.

## Raw export

| schemaname | tablename               | policyname                                | cmd    | qual                                   | with_check                             |
| ---------- | ----------------------- | ----------------------------------------- | ------ | -------------------------------------- | -------------------------------------- |
| public     | activity_logs           | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | activity_logs           | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | activity_logs           | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | activity_logs           | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | businesses              | Users can insert businesses               | INSERT | null                                   | true                                   |
| public     | businesses              | Users can view their own business         | SELECT | (id = get_user_business_id())          | null                                   |
| public     | categories              | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | categories              | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | categories              | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | categories              | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | crate_groups            | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | crate_groups            | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | crate_groups            | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | crate_groups            | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | customer_crate_balances | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | customer_crate_balances | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | customer_crate_balances | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | customer_crate_balances | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | customer_wallets        | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | customer_wallets        | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | customer_wallets        | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | customer_wallets        | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | customers               | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | customers               | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | customers               | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | customers               | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | delivery_receipts       | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | delivery_receipts       | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | delivery_receipts       | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | delivery_receipts       | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | drivers                 | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | drivers                 | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | drivers                 | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | drivers                 | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | expense_categories      | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | expense_categories      | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | expense_categories      | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | expense_categories      | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | expenses                | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | expenses                | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | expenses                | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | expenses                | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | inventory               | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | inventory               | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | inventory               | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | inventory               | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | invites                 | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | invites                 | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | invites                 | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | invites                 | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | manufacturers           | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | manufacturers           | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | manufacturers           | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | manufacturers           | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | notifications           | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | notifications           | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | notifications           | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | notifications           | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | order_items             | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | order_items             | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | order_items             | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | order_items             | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | orders                  | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | orders                  | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | orders                  | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | orders                  | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | payment_transactions    | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | payment_transactions    | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | payment_transactions    | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | payment_transactions    | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | pending_crate_returns   | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | pending_crate_returns   | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | pending_crate_returns   | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | pending_crate_returns   | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | price_lists             | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | price_lists             | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | price_lists             | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | price_lists             | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | products                | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | products                | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | products                | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | products                | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | profiles                | Users can insert their own profile        | INSERT | null                                   | (auth.uid() = id)                      |
| public     | profiles                | Users can view their own profile          | SELECT | (auth.uid() = id)                      | null                                   |
| public     | profiles                | Users can update their own profile        | UPDATE | (auth.uid() = id)                      | null                                   |
| public     | purchase_items          | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | purchase_items          | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | purchase_items          | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | purchase_items          | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | purchases               | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | purchases               | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | purchases               | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | purchases               | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | saved_carts             | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | saved_carts             | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | saved_carts             | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | saved_carts             | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | sessions                | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | sessions                | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | sessions                | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | sessions                | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | settings                | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | settings                | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | settings                | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | settings                | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | stock_adjustments       | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | stock_adjustments       | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | stock_adjustments       | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | stock_adjustments       | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | stock_transactions      | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | stock_transactions      | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | stock_transactions      | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | stock_transactions      | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | stock_transfers         | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | stock_transfers         | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | stock_transfers         | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | stock_transfers         | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | suppliers               | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | suppliers               | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | suppliers               | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | suppliers               | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | users                   | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | users                   | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | users                   | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | users                   | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | wallet_transactions     | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | wallet_transactions     | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | wallet_transactions     | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | wallet_transactions     | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |
| public     | warehouses              | Users can only access their business data | ALL    | (business_id = get_user_business_id()) | null                                   |
| public     | warehouses              | Users can only delete their business data | DELETE | (business_id = get_user_business_id()) | null                                   |
| public     | warehouses              | Users can only insert their business data | INSERT | null                                   | (business_id = get_user_business_id()) |
| public     | warehouses              | Users can only update their business data | UPDATE | (business_id = get_user_business_id()) | null                                   |

> Run [policies_export.sql](policies_export.sql) in the Supabase SQL editor and
> paste the result below. Group rows by table and mark which CRUD verbs have
> a policy. Then classify each policy's `qual` / `with_check` expression as
> either **auth.uid()-derived** (joins `profiles` to look up `business_id`)
> or **JWT-claim-derived** (reads `auth.jwt() ->> 'business_id'` or
> `auth.jwt() -> 'app_metadata' ->> 'business_id'`).

## Approach summary

- [ ] auth.uid()-derived (slower, flexible)
- [ ] JWT-claim-derived (faster, requires the claim to be present)
- [ ] mixed — list which tables use which

## Per-table coverage

| Table | SELECT | INSERT | UPDATE | DELETE | Notes |
|---|---|---|---|---|---|
| customers |  |  |  |  |  |
| orders |  |  |  |  |  |
| order_items |  |  |  |  |  |
| products |  |  |  |  |  |
| inventory |  |  |  |  |  |
| expenses |  |  |  |  |  |
| manufacturers |  |  |  |  |  |
| suppliers |  |  |  |  |  |
| warehouses |  |  |  |  |  |
| customer_wallets |  |  |  |  |  |
| wallet_transactions |  |  |  |  |  |

## Raw export

```text
-- paste pg_policies output here
```

## If JWT-claim-based and the claim is missing

A Postgres Auth Hook (or a `raw_app_meta_data` write at sign-in) needs to
inject `business_id` into the JWT. Document the chosen fix here once decided
— this repo is intentionally not making that server change yet.
