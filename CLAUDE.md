# Ribaplus POS - Project Overview

Ribaplus POS is a modern Flutter-based Point of Sale application designed specifically for drinks distributors. It features offline-first capabilities with local SQLite storage and seamless cloud synchronization.

## 📝 Summary of Major Recent Updates
- **PIN-based Authentication**: Secure login with role-based navigation and warehouse access control.
- **Crate Management 2.0**: Physical crate stocks moved to `Manufacturers` table; added manual **Empty Crate Return** modal with manager PIN authorisation for short returns.
- **Performance Optimizations**: Implemented `LazyIndexedStack` for main navigation and deferred content rendering for detail screens to eliminate lag.
- **Financial Accuracy**: Transitioned all currency handling to **Kobo (integers)** and all balances/stock totals to **computed values** (SQL SUMs) to prevent data drift.
- **Enhanced Product Details**: Relocated "Update Product" button to scrollable content for better UX flow.
- **Cart Deposit UX**: Cart screen now shows two separate deposit fields — a read-only "Crate Deposit" (auto-computed from glass items) and an editable "Deposit Paid" (manually entered). Totals section is always anchored to the bottom of the screen via `SliverFillRemaining`.
- **First-Run UX Fix**: Awaited the database warmup query (`SELECT 1`) in `main.dart` to ensure `onCreate` migrations (30+ tables) complete before the login screen appears, eliminating the "first-run hang".
- **Premium Splash & Login**: Implemented a custom native splash screen and a high-end **glassmorphism** login UI using `BackdropFilter` and shared branding assets (`auth_bg.png`, high-res logo).

## 🛠 Tech Stack

-   **Frontend**: Flutter (v3.10.7+)
-   **Local Database**: [Drift](https://drift.simonbinder.eu/) (SQLite)
-   **Remote Backend**: [Supabase](https://supabase.com/) (Auth, PostgreSQL, Real-time Sync)
-   **Authentication**: PIN-based login via `LoginScreen`. `AuthService` holds the active `UserData?` as a `ValueNotifier`. `main.dart` switches between `LoginScreen` → `WarehouseAssignmentScreen` → `MainLayout` based on `authService.value`. `WarehouseAssignmentScreen` polls the DB every 5 s; when a `warehouseId` is assigned it calls `authService.setCurrentUser(updatedUser)` to unblock the user.
-   **Printing**: ESC/POS Bluetooth Thermal Printing

## 📂 Project Structure

The project follows a feature-driven architecture for scalability and maintainability.

```text
lib/
├── core/               # App-wide configurations
│   ├── database/       # Drift database definition (app_database.dart, daos.dart)
│   └── theme/          # Premium UI tokens and AppTheme
├── features/           # Modular feature implementations
│   ├── auth/           # LoginScreen (PIN entry), WarehouseAssignmentScreen (unassigned staff waiting screen)
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
-   **Crate Management**: Empty crate stocks and deposits are now tracked on the **`Manufacturers`** table (not `CrateGroups`). `InventoryDao.addEmptyCrates(manufacturerId, qty)` and `deductEmptyCrates(manufacturerId, qty)` operate on `Manufacturers`. `CrateGroups` still holds deposit defaults but is no longer the source of truth for physical crate stock.
-   **Manufacturers table**: New first-class entity (`ManufacturerData`) — columns: `id`, `name`, `emptyCrateStock`, `depositAmountKobo`. Use `InventoryDao.getAllManufacturers()` or `watchAllManufacturers()`. Insert via `InventoryDao.insertManufacturer()`.
-   **Add Product Form**: `lib/features/inventory/widgets/add_product_sheet.dart` — collects name, retail price, unit, color, crate size (Big/Medium/Small), manufacturer (autocomplete from `Manufacturers` table via `CatalogDao.getAllManufacturers()`), supplier (autocomplete from DB). Selling price and cost price are NOT on this form — added later in product detail screen.
-   **Products schema**: `supplierId` (nullable FK → Suppliers), `manufacturerId` (nullable FK → Manufacturers), `monthlyTargetUnits` (int), `emptyCrateValueKobo` (int — per-product crate deposit override; 0 means use CrateGroup default). `crateSize` stores 'big'|'medium'|'small'. Schema is now **v20**. Indexes on `Products.categoryId` and `Products.name` added in v15; `SavedCarts` table added in v20.
-   **`emptyCrateValueKobo` override**: In the cart, if a glass product has `emptyCrateValueKobo > 0`, that value is used as the deposit per bottle instead of the linked CrateGroup's `depositAmountKobo`. This allows per-product deposit customisation.
-   **Customer Wallet System**: Balance is **COMPUTED** as SUM of credits minus SUM of debits from `wallet_transactions`. Never store mutable balance as a single column to prevent drift and enable auditability.
-   **Stock totals**: Same principle as wallet balances — `totalStock` is always computed via `SUM(inventory.quantity)` in a SQL join, never cached as a column on Products. Do NOT add a `cachedStock` column.
-   **Duplicate product names**: `CatalogDao.findByName(String name)` checks for an existing non-deleted product before insert. Always call this before `insertProduct()` in any form that adds products.
-   **`CatalogDao.updateProductDetails()`**: Full product-detail update — accepts name, manufacturer, manufacturerId, buyingPriceKobo, retailPriceKobo, bulkBreakerPriceKobo, distributorPriceKobo, emptyCrateValueKobo, categoryId. Use this from the product detail screen instead of writing individual fields.
-   **`CatalogDao.updateMonthlyTarget()`**: Updates `monthlyTargetUnits` for a product. Separate method to avoid overwriting other fields.
-   **Customer groups**: The customer group key for wholesale pricing is `'wholesaler'` (previously `'bulk_breaker'`). `CatalogDao.getPriceForCustomerGroup()` maps `'wholesaler'` → `distributorPriceKobo`.
-   **Stock depletion on checkout**: `CheckoutPage` calls `inventoryDao.deductStock()` for each cart item after a successful order. Empty crates are auto-tracked — glass crate items trigger `inventoryDao.deductEmptyCrates(manufacturerId, qty)` on the Manufacturers table.
-   **SavedCarts table**: `SavedCartData` (schema v20) — stores named cart snapshots as JSON. Columns: id, name, customerId (nullable FK), cartData (JSON string), createdAt.
-   **Orders screen stream**: `OrdersScreen` subscribes to `orderService.watchAllOrdersWithItems()` once in `initState` and stores results in `_allOrdersWithItems`. Not a `StreamBuilder`.
-   **POS product loading**: Products are loaded once in `initState` via `_subscribeToProducts(categoryId)` and stored in `_allProducts`. The `_buildGrid()` method reads `_allProducts` directly — no `StreamBuilder` in `build()`. When the user taps a category chip, `_subscribeToProducts` is called again with the new categoryId to re-subscribe the stream.
-   **Debounced search**: The POS search field uses a 300ms `Timer` (`_searchDebounce`) — cancel the old timer on each keystroke and only call `setState` after the user stops typing. Import `dart:async` for `Timer`.
-   **InventoryDao.watchProductsByCategory(int? categoryId)**: Category-filtered product stream. Pass `null` for all categories. Use this instead of `watchAllProductDatasWithStock()` on the POS screen.
-   **orderService global**: Use the top-level `orderService` instance from `shared/services/order_service.dart`. Do NOT call `database.orderService` — that property does not exist on AppDatabase.
-   **CustomerDetailScreen**: Accepts `Customer? customer` via constructor. Uses `addPostFrameCallback` to defer heavy widget tree and DB stream subscriptions until after the first frame commits (shows a spinner on first frame). Subscribes to `customersDao.watchWalletBalance(id)` and `customersDao.watchWalletHistory(id)` in the post-frame callback. All subscriptions cancelled in `dispose()`. Orders section shows empty state (no per-customer order query yet).
-   **No mock data**: All mock/fake data has been removed from `CustomerDetailScreen`. Data must come from the DB only. Do NOT re-introduce mock lists/objects.
-   **Staff management**: `_StaffFormSheet._submit()` in `lib/features/staff/screens/staff_screen.dart` performs real DB inserts/updates via `UsersCompanion`. Import `package:drift/drift.dart' show Value` for `Value(...)` wrappers. A non-manager (roleTier < 4) cannot be assigned to a warehouse that has no existing manager — validate before saving by querying the users table and filtering in Dart (`roleTier >= 4`). On success, pop the sheet and show a floating green `SnackBar`: capture `ScaffoldMessenger.of(context)` BEFORE calling `Navigator.pop` to avoid context-after-pop errors.
-   **Warehouse → Staff navigation**: When navigating from a detail screen to a main-layout tab, always call `Navigator.of(context).pop()` first, then `navigationService.setIndex(n)`. Without the pop, the user stays on the detail screen and pressing back goes to the wrong screen.
-   **Login redirect by role**: In `AuthService.setCurrentUser()`, after applying the warehouse lock, staff with `roleTier < 4` are automatically sent to the POS tab (`navigationService.setIndex(1)`). Managers (tier 4) and CEO (tier 5) land wherever the nav index already is.
-   **Activity log role filter**: `ActivityLogScreen._filterLogs()` applies a role-based visibility rule using a `_userTiers` map (userId → roleTier) loaded once in `initState`. CEO (tier ≥ 5) sees all logs. Manager (tier 4) sees logs from performers with tier < 5 (hides CEO logs). Staff (tier < 4) sees logs from performers with tier < 4 (hides manager and CEO logs). Logs with a null `userId` (system/legacy) are visible to all. `ActivityLogService.logAction()` saves `authService.currentUser?.id` as the `staffId` so every action is attributed to the logged-in user.
-   **Empty Crate Return Modal**: `lib/features/orders/widgets/crate_return_modal.dart` allows manual recording of returned crates per group. If the returned count is less than expected from the order, it triggers a `PinDialog` for **Manager Authorisation** (minimum tier 4).
-   **Cart deposit fields**: `cart_screen.dart` shows two distinct deposit rows in the totals section: (1) **"Crate Deposit"** — a read-only styled `Container` (no `GestureDetector`, no pen icon) showing `computedDeposit` (auto-calculated from `crateGroupId` and `emptyCrateValueKobo` on glass items); only visible when `hasGlass` is true. (2) **"Deposit Paid"** — a tappable `GestureDetector` container with a pen icon showing `_crateDeposit`, the manually entered amount. `_showEditCrateDeposit()` opens a sheet to update `_crateDeposit`. Do NOT rename or merge these two fields.
-   **Cart sticky totals layout**: `cart_screen.dart` uses `CustomScrollView(slivers: [SliverToBoxAdapter(child: ListView...), SliverFillRemaining(hasScrollBody: false, child: Column(mainAxisAlignment: MainAxisAlignment.end, ...))])`. This keeps the totals section anchored to the bottom when the item list is short, and lets it scroll naturally when items overflow the viewport. Do NOT revert to `SingleChildScrollView(child: Column([ListView, Container]))` — that places the totals directly under the last item, leaving empty space below.
-   **Asynchronous DB Initialization**: `main.dart` must `await database.customSelect('SELECT 1').get()` before `runApp()`. This triggers the `LazyDatabase` initialization and any `onCreate`/`onUpgrade` logic synchronously at startup. Failing to await this causes subsequent queries (like PIN entry) to block on the background migration isolate, creating a perceived "hang".
-   **Glassmorphism UI Pattern**: For premium "glassy" surfaces, use `BackdropFilter` with `ImageFilter.blur(sigmaX: 10+, sigmaY: 10+)`. Containers should have a translucent white background (`Colors.white.withValues(alpha: 0.1)`) and a thin translucent white border (`0.5-1.0` width). Ensure high-contrast text/indicators (e.g., solid white or primary colors) for accessibility against the blurred backdrop.

## 🎨 UI/UX Patterns

-   **Sheet Modals**: Major forms (like "Add Customer") must use `DraggableScrollableSheet` with `initialChildSize: 0.9` and `maxChildSize: 0.9` to provide a premium feel and ample typing space.
-   **Keyboard Awareness**: Buttons and critical inputs in sheets must be shifted above the keyboard using `MediaQuery.of(context).viewInsets.bottom` (often applied as padding to the bottom button's container) to ensure the "Save" button remains visible during typing.
-   **Responsiveness**: Always use `context.getRSize()` and `context.getRFontSize()` from `lib/core/utils/responsive.dart` for dimensions to support various phone sizes.
-   **Drift stream rule**: NEVER call `watch()` streams inside `build()` methods or `StreamBuilder` — they create new subscriptions on every rebuild, causing infinite rebuild loops. Instead, subscribe once in `initState`, store results in a state variable, and read that variable in `build()`.
-   **One-shot vs reactive queries**: Use `get()` for one-time reads (e.g. loading form data). Use `watch()` only in `initState` with `.listen()`. Never use `watchSomething().first` — it opens a reactive stream that never closes and can deadlock DB writes. Use a dedicated `getAll...()` method with `select(...).get()` instead.
-   **CatalogDao**: has `getAllSuppliers()` and `getAllManufacturers()` — one-shot `get()` queries for loading supplier/manufacturer lists in forms without keeping a stream open.
-   **Heavy screen pattern**: For screens with large widget trees (500+ widgets), use `addPostFrameCallback` in `initState` to defer both the full widget tree and stream subscriptions until after the first frame. Set `_contentReady = false` initially; show a bare `CircularProgressIndicator` until the callback fires and sets `_contentReady = true`. This prevents ANR on slow devices.
-   **Navigator.push pattern**: Always use standard `MaterialPageRoute` for fluid page transitions. Zero-duration `PageRouteBuilder` forces synchronous rendering of complex screens in a single frame, which "hangs" the UI and causes noticeable delay before navigation occurs. For heavy profile/detail screens, pair `MaterialPageRoute` with the deferred content pattern (`addPostFrameCallback` with a `_contentReady` flag) so the screen shell loads instantly during the transition while the heavy widget tree builds afterwards.

## 🚀 Development Guidelines

1.  **UI/UX**: Prioritize premium aesthetics. Use `AppTheme.dark()` and `AppTheme.light()`. Avoid generic colors; use theme-defined palettes.
2.  **Linting**: Follow `analysis_options.yaml`. Ensure all code passes `flutter analyze`.
3.  **State Management**: Extensive use of `ValueNotifier` and `StatefulWidget` patterns for local state; `Drift` for persistent state.
4.  **Database Updates**: When modifying `app_database.dart`, run `dart run build_runner build` to regenerate the G-files.
5.  **Database Stability**: When watching single entities for profile screens, prefer `watchSingleOrNull()` over `watchSingle()` to prevent app crashes when data is still loading or temporarily unavailable.
6.  **Schema Migrations**: Every time `schemaVersion` is bumped, add a matching `if (from < newVersion)` block inside `onUpgrade` in `app_database.dart`. Use `m.createTable(table)` for new tables. For new columns on existing tables use `m.addColumn(table, table.column)`. Never drop tables in `onUpgrade` — that wipes user data. The fallback `for (final table in allTables) { await m.createTable(table).catchError((_) => ...); }` loop at the end of `onUpgrade` safely handles any tables not yet explicitly handled — already-existing tables are silently skipped.
7.  **MainLayout — lazy IndexedStack**: `main_layout.dart` wraps the 12-screen `IndexedStack` in a `_LazyIndexedStack` widget (defined in the same file). It only builds a screen the first time that tab is visited; unvisited tabs hold a `SizedBox.shrink()`. Once built, a screen stays alive forever (same behaviour as a plain `IndexedStack`). This prevents a 12-screen simultaneous build on first login. Do NOT replace `_LazyIndexedStack` with a plain `IndexedStack` or a `_buildScreen` switch.
8.  **MainLayout — pending orders stream**: The pending-orders badge count is driven by a single `StreamSubscription<List<Order>>` stored in `_pendingOrdersSub` (initiated in `initState`, cancelled in `dispose`). Do NOT move it back into `build()` as a `StreamBuilder` — this creates a new Drift watcher on every bottom-nav rebuild.

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

### 6. Android Project Naming
- Explicitly set `rootProject.name = "drink_pos_app"` in `android/settings.gradle.kts` to prevent the IDE or AI tools from creating duplicate root "android" elements.
- Always use the explicit project name when configuring multi-project build settings to avoid naming collisions in the workspace.
- Ensure `org.gradle.java.home` in `android/gradle.properties` points to a valid JDK path (prefer Android Studio's JBR) if the external environment is misconfigured.