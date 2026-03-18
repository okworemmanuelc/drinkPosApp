# Ribaplus POS - Project Overview

Ribaplus POS is a modern Flutter-based Point of Sale application designed specifically for drinks distributors. It features offline-first capabilities with local SQLite storage and seamless cloud synchronization.

## 🛠 Tech Stack

-   **Frontend**: Flutter (v3.10.7+)
-   **Local Database**: [Drift](https://drift.simonbinder.eu/) (SQLite)
-   **Remote Backend**: [Supabase](https://supabase.com/) (Auth, PostgreSQL, Real-time Sync)
-   **Authentication**: Removed. All auth screens (`lib/features/auth/screens/`) and widgets (`lib/features/auth/widgets/`) are deleted. `AuthService` is now a stub that returns a hardcoded CEO user. App boots directly into `MainLayout`.
-   **Printing**: ESC/POS Bluetooth Thermal Printing

## 📂 Project Structure

The project follows a feature-driven architecture for scalability and maintainability.

```text
lib/
├── core/               # App-wide configurations
│   ├── database/       # Drift database definition (app_database.dart, daos.dart)
│   └── theme/          # Premium UI tokens and AppTheme
├── features/           # Modular feature implementations
│   ├── auth/           # DELETED — all auth screens and widgets removed
│   ├── inventory/      # Product management, Stock tracking
│   ├── pos/            # Checkout, Cart, Sales interface
│   ├── orders/         # Order history and status management
│   ├── customers/      # Customer profiles and wallet balances
│   └── ...             # Expenses, Staff, Deliveries, Warehouse
├── shared/             # Reusable services and widgets
│   ├── services/       # AuthService, SupabaseSyncService, ActivityLogService
│   └── widgets/        # Generic UI components
└── main.dart           # App entry and initialization logic
```

## 🔐 Key Patterns

-   **Sync Strategy**: Uses `SupabaseSyncService` combined with a `SyncQueue` table in Drift to handle offline operations and reliable background synchronization.
-   **Role-Based Access**: Multi-tier user roles (Staff=1, Manager=4, CEO=5) managed via `UserData` and enforced in local screens. Role restrictions on forms are deferred until auth is restored.
-   **Financials**: All currency amounts (Retail price, Selling price, Wallet balance) are stored and manipulated as **Kobo (integers)** to avoid floating-point errors.
-   **Crate Management**: Specialized logic for tracking empty crate stocks and deposits, grouped by `CrateGroups`.
-   **Add Product Form**: `lib/features/inventory/widgets/add_product_sheet.dart` — collects name, retail price, unit, color, crate size (Big/Medium/Small), manufacturer (autocomplete from existing products), supplier (autocomplete from DB). Selling price and cost price are NOT on this form — added later in product detail screen.
-   **Products schema**: `supplierId` (nullable FK → Suppliers) added in schema v14. `crateSize` stores 'big'|'medium'|'small'. No bulk/distributor price fields on add form. Schema is now **v15** (indexes added on `Products.categoryId` and `Products.name`).
-   **Customer Wallet System**: Balance is **COMPUTED** as SUM of credits minus SUM of debits from `wallet_transactions`. Never store mutable balance as a single column to prevent drift and enable auditability.
-   **Stock totals**: Same principle as wallet balances — `totalStock` is always computed via `SUM(inventory.quantity)` in a SQL join, never cached as a column on Products. Do NOT add a `cachedStock` column.
-   **Duplicate product names**: `CatalogDao.findByName(String name)` checks for an existing non-deleted product before insert. Always call this before `insertProduct()` in any form that adds products.
-   **POS product loading**: Products are loaded once in `initState` via `_subscribeToProducts(categoryId)` and stored in `_allProducts`. The `_buildGrid()` method reads `_allProducts` directly — no `StreamBuilder` in `build()`. When the user taps a category chip, `_subscribeToProducts` is called again with the new categoryId to re-subscribe the stream.
-   **Debounced search**: The POS search field uses a 300ms `Timer` (`_searchDebounce`) — cancel the old timer on each keystroke and only call `setState` after the user stops typing. Import `dart:async` for `Timer`.
-   **InventoryDao.watchProductsByCategory(int? categoryId)**: Category-filtered product stream. Pass `null` for all categories. Use this instead of `watchAllProductDatasWithStock()` on the POS screen.
-   **orderService global**: Use the top-level `orderService` instance from `shared/services/order_service.dart`. Do NOT call `database.orderService` — that property does not exist on AppDatabase.
-   **CustomerDetailScreen**: Accepts `Customer? customer` via constructor. Uses `addPostFrameCallback` to defer heavy widget tree and DB stream subscriptions until after the first frame commits (shows a spinner on first frame). Subscribes to `customersDao.watchWalletBalance(id)` and `customersDao.watchWalletHistory(id)` in the post-frame callback. All subscriptions cancelled in `dispose()`. Orders section shows empty state (no per-customer order query yet).
-   **No mock data**: All mock/fake data has been removed from `CustomerDetailScreen`. Data must come from the DB only. Do NOT re-introduce mock lists/objects.

## 🎨 UI/UX Patterns

-   **Sheet Modals**: Major forms (like "Add Customer") must use `DraggableScrollableSheet` with `initialChildSize: 0.9` and `maxChildSize: 0.9` to provide a premium feel and ample typing space.
-   **Keyboard Awareness**: Buttons and critical inputs in sheets must be shifted above the keyboard using `MediaQuery.of(context).viewInsets.bottom` (often applied as padding to the bottom button's container) to ensure the "Save" button remains visible during typing.
-   **Responsiveness**: Always use `context.getRSize()` and `context.getRFontSize()` from `lib/core/utils/responsive.dart` for dimensions to support various phone sizes.
-   **Drift stream rule**: NEVER call `watch()` streams inside `build()` methods or `StreamBuilder` — they create new subscriptions on every rebuild, causing infinite rebuild loops. Instead, subscribe once in `initState`, store results in a state variable, and read that variable in `build()`.
-   **One-shot vs reactive queries**: Use `get()` for one-time reads (e.g. loading form data). Use `watch()` only in `initState` with `.listen()`. Never use `watchSomething().first` — it opens a reactive stream that never closes and can deadlock DB writes. Use a dedicated `getAll...()` method with `select(...).get()` instead.
-   **CatalogDao**: has `getAllSuppliers()` — one-shot `get()` query for loading supplier list in forms without keeping a stream open.
-   **Heavy screen pattern**: For screens with large widget trees (500+ widgets), use `addPostFrameCallback` in `initState` to defer both the full widget tree and stream subscriptions until after the first frame. Set `_contentReady = false` initially; show a bare `CircularProgressIndicator` until the callback fires and sets `_contentReady = true`. This prevents ANR on slow devices.
-   **Navigator.push pattern**: Always use `PageRouteBuilder` with `opaque: true` and `transitionDuration: Duration.zero` instead of `MaterialPageRoute`. The slide transition in `MaterialPageRoute` renders old and new routes simultaneously, which overwhelms the main thread when the underlying `MainLayout` is heavy. Example:
    ```dart
    Navigator.push(context, PageRouteBuilder(
      opaque: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => const SomeDetailScreen(),
    ));
    ```

## 🚀 Development Guidelines

1.  **UI/UX**: Prioritize premium aesthetics. Use `AppTheme.dark()` and `AppTheme.light()`. Avoid generic colors; use theme-defined palettes.
2.  **Linting**: Follow `analysis_options.yaml`. Ensure all code passes `flutter analyze`.
3.  **State Management**: Extensive use of `ValueNotifier` and `StatefulWidget` patterns for local state; `Drift` for persistent state.
4.  **Database Updates**: When modifying `app_database.dart`, run `dart run build_runner build` to regenerate the G-files.
5.  **Database Stability**: When watching single entities for profile screens, prefer `watchSingleOrNull()` over `watchSingle()` to prevent app crashes when data is still loading or temporarily unavailable.
6.  **MainLayout — no IndexedStack**: `main_layout.dart` uses a `_buildScreen(index)` switch instead of `IndexedStack`. Only the ACTIVE screen is in the widget tree at any time. Do NOT reintroduce `IndexedStack` — keeping all 12 screens alive simultaneously saturates the Dart event loop with stream callbacks and causes ANR when any new route is pushed. Trade-off: screens do not remember scroll position across tab switches (acceptable since data reloads from DB).
7.  **MainLayout — pending orders stream**: The pending-orders badge count is driven by a single `StreamSubscription<List<Order>>` stored in `_pendingOrdersSub` (initiated in `initState`, cancelled in `dispose`). Do NOT move it back into `build()` as a `StreamBuilder` — this creates a new Drift watcher on every bottom-nav rebuild.

## 📦 Assets
-   **Images**: Stored in `assets/images/`, including branding (Ribaplus logo) and decorative backgrounds.


---

## Workflow Rules

### 1. Always Plan Before Coding
- For any complex task, write a step-by-step plan first and wait for approval before writing code
- Use the format: "Here's my plan: [steps]... Should I proceed?"

### 2. Check Your Own Work
- After making changes, always run `flutter analyze` to verify no errors
- Run `dart run build_runner build --delete-conflicting-outputs` after any schema changes

### 3. Update This File
- If you make a mistake or discover a new project convention, update CLAUDE.md immediately so it's remembered permanently

### 4. Small Focused Changes
- Make one change at a time, verify it works, then move to the next
- Never refactor unrelated code while fixing a bug

### 5. Communication Style
- Always use simple, beginner-friendly terms when explaining changes to the user (the USER is still learning and prefers simplified code explanations over jargon).

### 5. Auth is Removed — Do Not Re-introduce
- `lib/features/auth/` is fully deleted. Do not import anything from it.
- `AuthService` (`lib/shared/services/auth_service.dart`) is a stub — only import `flutter/widgets.dart` and `app_database.dart`. Do not add back `supabase_flutter`, `google_sign_in`, `shared_preferences`, `crypto`, or `drift` imports unless auth is being re-implemented intentionally.