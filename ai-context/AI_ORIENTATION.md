# AI ORIENTATION - START HERE

## 1. Project Summary
BrewFlow POS is an offline-first Point of Sale and inventory tracking application built in Flutter. It is designed for beverage wholesalers and retailers, specifically managing a complex mix of full products, empties (glass crates), direct sales, credit sales, and customer debts. The current architecture strictly relies on in-memory static variables for state management and local data persistence, avoiding external databases or complex local SQL implementations for now. 

## 2. Architecture Context
**Instruction:** Load `CONTEXT_MAP.md` for full architecture understanding. It details the file layout, tech stack, data flow bounds, and critical dependencies.

## 3. Feature Blueprints
Load these specific files when working on or debugging the corresponding features:
- `BLUEPRINT_POS.md`: The main storefront, cart, checkout logic, and receipt generation.
- `BLUEPRINT_INVENTORY.md`: Physical stock, empty crates, and supplier management.
- `BLUEPRINT_CUSTOMERS.md`: Customer registry, ledger balances, and contact details.
- `BLUEPRINT_ORDERS.md`: Historical transaction logs and past receipts.
- `BLUEPRINT_PAYMENTS.md`: Registering cash/transfer payments to offset customer debt.
- `BLUEPRINT_DELIVERIES.md`: Receiving stock from suppliers and updating global stock sums.
- `BLUEPRINT_EXPENSES.md`: Tracking business spending.

## 4. Start Here for Common Tasks
- **"I need to fix a UI bug in POS checkout"** → Load `BLUEPRINT_POS.md`
- **"I need to adjust how debt is calculated"** → Load `BLUEPRINT_CUSTOMERS.md` and `BLUEPRINT_POS.md`
- **"I need to add a new API endpoint or Database system"** → Load `CONTEXT_MAP.md` §4, §5, §8 (Warning: requires global refactoring)
- **"I need to understand the database schema"** → Load `CONTEXT_MAP.md` §4 and `BLUEPRINT_INVENTORY.md` (Note: `kInventoryItems`, `kProducts`, and static lists *are* the schema)
- **"I need to write a test"** → Load `CONTEXT_MAP.md` §5
- **"I need to add a new dependency"** → Load `CONTEXT_MAP.md` §2
- **"I need to change how crates are processed"** → Load `BLUEPRINT_INVENTORY.md`

## 5. What NOT To Do (Top 5 Mistakes)
1. **Never directly import feature screens into AppDrawer.** This causes circular dependencies. Always rely on the proxy widgets built into `app_drawer.dart` and `main.dart`.
2. **Never assume state is persisted.** If you build data validation assuming standard SQLite logic, it will fail on restart. Understand that data lives in `static List` arrays.
3. **Do not use named routes blindly.** Navigation heavily relies on `Navigator.push` and manual stack popping. Respect the existing routing patterns.
4. **Never allow partial/credit sales without a customer.** The checkout logic assumes walk-in clients pay in full. Attempting to force a credit sale onto null crashes the app or corrupts the pseudo-ledger.
5. **Do not rename `productName` strings casually.** Items map between `kInventoryItems`, `_cart`, and `kProducts` based on exact string-matching of product names.

---

## Maintenance Protocol
**EVERY AI AGENT MUST FOLLOW THESE RULES WITHOUT BEING REMINDED.**

RULE 1 — UPDATE AFTER EVERY SIGNIFICANT CHANGE
At the end of any session where a significant change was made, automatically update the relevant files before closing. A significant change is any of the following:
- A new feature was added or scaffolded
- An existing feature was refactored or renamed
- An API endpoint was added, changed, or removed
- A new dependency was installed
- A database schema or data shape changed
- A new environment variable was introduced
- A danger zone was resolved or a new one discovered
- A naming convention was changed or a new pattern established

Do not wait to be asked. Treat updating `/ai-context/` as part of completing the task — the same way you would run a build or write a test.

RULE 2 — SCOPE UPDATES PRECISELY
Only update the files that are actually affected. Do not rewrite documents that haven't changed. The update targets are:
- New feature added → create `BLUEPRINT_[FEATURE_NAME].md`, update `AI_ORIENTATION.md` to list it
- Existing feature changed → update the relevant `BLUEPRINT_[NAME].md`, specifically the sections that changed (File Map, Data Flow, API Contracts, State, Gotchas)
- Architecture changed → update `CONTEXT_MAP.md` §3, §4, or §6 as needed
- New dependency → update `CONTEXT_MAP.md` §2
- New environment variable → update `CONTEXT_MAP.md` §7
- Bug found or workaround added → update `CONTEXT_MAP.md` §8 (Danger Zones) and the relevant blueprint's Gotchas section

RULE 3 — STAMP EVERY UPDATE
At the bottom of every file you update, append or update a "## Last Updated" section with:
- The date
- A one-line summary of what changed
- The task or feature that triggered the update
This creates a lightweight audit trail without requiring a separate changelog.

RULE 4 — TREAT STALENESS AS A BUG
If you are working on a feature and notice that its blueprint does not match the actual code, stop and update the blueprint before proceeding. A misleading blueprint is worse than no blueprint — it will cause future agents to make confident wrong assumptions.

RULE 5 — NEVER DELETE, ONLY DEPRECATE
If a feature is removed, do not delete its blueprint. Rename it to `BLUEPRINT_[FEATURE_NAME]_DEPRECATED.md` and add a note at the top:
  "DEPRECATED as of [date]. This feature was removed. Kept for historical reference. Do not implement against this blueprint."
This preserves institutional memory and prevents future agents from re-implementing something that was intentionally removed.

---

## Last Updated
- Date: 2026-03-08
- Summary: Initial project orientation documentation generated. Added database schema and testing paths to Start Here section.
- Triggered By: Project contextualization and AI indexing setup.
