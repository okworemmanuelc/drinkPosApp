# PROJECT CONTEXT MAP

## 1. Project Identity
BrewFlow POS is a comprehensive Point of Sale and inventory management application designed for a drinks/beverage wholesale and retail business. It enables cashiers and managers to handle sales (carts and checkouts), manage inventory (including crate deposits and stock levels), track customer debts and payments, record expenses, and log deliveries in a fast, offline-first manner. The application is currently in an active prototyping/development phase prioritizing local in-memory state.

## 2. Tech Stack
- **Language**: Dart (Flutter SDK >=3.10.7)
- **Framework**: Flutter
- **UI & Icons**: `flutter/material.dart`, `cupertino_icons` (^1.0.8), `font_awesome_flutter` (^10.12.0)
- **State Management**: Built-in Flutter primitives (`StatefulWidget`, `ValueListenableBuilder`, `ValueNotifier`) with in-memory static variables for data persistence.
- **Hardware Integration & Utilities**:
  - `print_bluetooth_thermal` (^1.1.9) and `esc_pos_utils_plus` (^2.0.3) for receipt printing
  - `barcode_widget` (^2.0.4) for barcode scanning/display
  - `screenshot` (^3.0.0) and `share_plus` (^10.1.3) for sharing receipts
  - `permission_handler` (^11.3.1) for hardware permissions
  - `path_provider` (^2.1.5) for local file system access
  - `intl` (^0.20.2) for formatting

*Note*: State is managed entirely in-memory using static lists (e.g., `kInventoryItems`) due to a strict constraint to avoid complex databases during this phase.

## 3. Folder & File Structure
```
/lib
  /core
    /theme        - App-wide color tokens (colors.dart), ThemeData definitions (app_theme.dart), and ThemeMode state (theme_notifier.dart).
    /utils        - Helpers like currency_input_formatter.dart, number_format.dart, responsive.dart (layout scaling).
  /features
    /customers    - UI and in-memory mock models/services for customer management (debts, ledger, crate balances).
    /deliveries   - UI and data logic for receiving stock deliveries and updating inventory.
    /expenses     - UI and models for tracking business expenses.
    /inventory    - Core stock management, empty crate tracking, supplier definitions, and inventory logs. Contains the main in-memory "database" (inventory_data.dart).
    /orders       - Order history and receipt viewing.
    /payments     - Ledger for customer payments (offsets debts).
    /pos          - Point of Sale (Home screen grid, Cart, Checkout, Receipt generation, Bluetooth printing).
  /shared
    /models       - Global shared models (if any).
    /services     - Global services.
    /widgets      - Reusable UI segments like AppDrawer (navigation hub) and ActivityLogScreen.
  main.dart       - App entry point, wires up dependencies and routes.
```

## 4. Architecture Overview

### Layers
1. **Presentation (UI)**: Flutter `StatelessWidget` and `StatefulWidget`. Feature screens are modularized in `/lib/features/<feature>/screens/`.
2. **State/Data**: Local in-memory static lists, e.g., `kInventoryItems`, `kCustomers`, `kProducts`.
3. **Services**: Stateless classes in `/services/` folders handle business logic, mutating the global lists and sometimes calling other services to log activity.

### Data Flow (Standard Action)
```
[User Action in UI] → [StatefulWidget calls setState / local UI update] 
                    → [Service call to mutate global static list] 
                    → [Activity logged in kActivityLogs] 
                    → [UI rebuilt based on new global state]
```

### Boundaries
- **UI → Data**: Direct mutation of static variables defined in `data` folders.
- **Navigation**: Mediated primarily by `AppDrawer` with proxy widgets breaking circular dependencies.

## 5. Core Conventions
- **State**: Strictly uses `StatefulWidget` and `setState` for local UI state. Global state relies on static global lists (e.g., `kSuppliers`) mutating in memory.
- **Routing**: No named routing or GoRouter. `AppDrawer` orchestrates navigation using `Navigator.push` with materialized proxy widgets to circumvent circular imports. `pos_home_screen` is effectively the root.
- **Styling**: Relies on `theme_notifier` (`ValueNotifier<ThemeMode>`) and manually references colors (e.g., `_isDark ? dSurface : lSurface`) dynamically in `build` methods.
- **Formatting**: Currency and numbers use `intl` utilities found in `core/utils/number_format.dart` and `currency_input_formatter.dart` (adds commas and ensures 2 decimal places).
- **Activity Logging**: Most state-mutating actions (checkout, receive delivery) must append a log entry to `kActivityLogs` or `kInventoryLogs`.

## 6. Dependency Graph (Critical Paths)
- `lib/main.dart` → depends on `AppDrawer` and proxy functions → wires up navigation.
- `AppDrawer` → depends on dynamically injected closures from `main.dart` — reason: avoids circular imports when screens import `AppDrawer`.
- `pos_home_screen.dart` → depends on `inventory_data.dart` and `products_data.dart` — reason: Pos HomeScreen filters global stock lists.
- `checkout_page.dart` → depends on `receipt_builder.dart` and customer data — reason: finalizing a sale updates customer ledger and constructs receipt representation.

## 7. Environment & Configuration
- No `.env` files or external API configurations exist in this phase.
- Configuration is primarily in `pubspec.yaml` (Flutter dependencies).
- Visual configuration is housed under `core/theme/colors.dart`.

## 8. Danger Zones
- **In-Memory Volatility**: Data is lost on hot restarts or app closures.
- **Circular Imports**: Features often need to navigate, and importing `AppDrawer` while `AppDrawer` imports feature screens creates circular dependencies. Do not import screens directly into `AppDrawer`; rely on proxy injection.
- **State Triggers**: Because global variables aren't reactive (`ChangeNotifier` is rarely used for data), navigating "back" might display stale data unless screens use `.then((_) => setState(() {}))` to refresh on pop.
- **Checkout Payment Logic**: Dynamic checkout logic heavily intertwines walk-in vs registered customer debt handling. Modifying this requires extreme care.

## 9. Glossary
- **Crate**: Refers to a glass bottle container deposit system (crucial in beverage POS). Empty crates represent financial value and physical stock.
- **Ledger/Credit Sale**: When a customer buys on credit, the remaining balance is tracked in their ledger.
- **POS**: Point of Sale.
- **Wholesale/Retail**: Toggleable pricing tiers altering the `price` utilized during checkout.
