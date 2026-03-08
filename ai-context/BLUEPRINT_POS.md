# FEATURE BLUEPRINT: Point of Sale (POS)

## What It Does
The Point of Sale feature is the core screen of the application. It allows cashiers to view available inventory (glass crates, cans, kegs), add items to a cart, switch between retail and wholesale pricing, manage cart quantities, select registered customers for credit/ledger sales, and finalize transactions (Checkout). Checking out logs the sale, updates inventory, modifies customer balances, and generates a printable receipt.

## Entry Points
- UI elements: App main entry point. Accessible via `AppDrawer` "Point of Sale" navigation item.
- Routes / URLs: Managed via `Navigator.push` in `app_drawer.dart` → `pos` route (clears stack).
- Files: `pos_home_screen.dart`, `cart_screen.dart`, `checkout_page.dart`.

## File Map
- `lib/features/pos/screens/pos_home_screen.dart`: Main grid showing products. Defines category filters, search, and pricing toggles. Holds `_cart` list.
- `lib/features/pos/screens/cart_screen.dart`: Displays added items. Handles crate deposit toggles and customer selection for credit sales.
- `lib/features/pos/screens/checkout_page.dart`: Finalizes the sale. Calculates totals, handles partial payments vs full credit, and validates walk-in vs registered customer constraints.
- `lib/features/pos/services/receipt_builder.dart`: Generates ESC/POS byte commands for Bluetooth thermal printing.
- `lib/features/pos/data/products_data.dart`: Fallback product pricing and metadata (though it cross-references `kInventoryItems`).

## Data Flow
  1. User adds items to cart in `pos_home_screen.dart`.
  2. User taps "Cart". The `_cart` list is passed to `cart_screen.dart`.
  3. In Cart, user selects a Customer (optional) and toggles crate deposits. Proceeds to Checkout.
  4. In `checkout_page.dart`, user selects payment method (Full Cash, Partial, Credit).
  5. Upon "Complete Sale":
     - `kInventoryLogs` receives a new sale entry.
     - `kInventoryItems` stock is decremented.
     - Customer balance (in `kCustomers`) is updated (debt added if credit/partial, ledger updated if overpaid).
  6. The app navigates back to POS home, refreshing the stock UI.

## State
- Local State: Cart array (`_cart`), `_isWholesale` toggle, `_searchQuery`, `_activeCustomer`. All live in `StatefulWidget`s.
- Global State consumed: `kInventoryItems` (for stock availability), `kCustomers` (for ledger/credit checks).
- Global State mutated: `kInventoryItems`, `kCustomers`, `kActivityLogs`.

## API Contracts / Data Models
No external API calls in this phase.
In-memory structures:
- `Cart Item`: `Map<String, dynamic>` containing name, price, qty, color, icon, category.
- `Checkout Mutation`: Directly edits shared static lists (`kInventoryItems` etc.).

## Dependencies
- Inventory Feature: POS products are derived directly by mapping `kInventoryItems` where `stock > 0`.
- Customer Feature: Needed to authorize Credit/Partial sales. Walk-in customers cannot have pending balances.

## How To...
- **Add a new product category** → Edit `_filters` in `pos_home_screen.dart`.
- **Change the UI grid layout** → Edit `_buildGrid` constraints in `pos_home_screen.dart`.
- **Change checkout validation logic** → Edit `_buildCheckoutActions` or payment handling in `checkout_page.dart`.
- **Modify the receipt** → Edit `receipt_builder.dart` which uses `esc_pos_utils_plus`.

## Gotchas
- **Pricing Tied to Name**: Product mapping relies on matching `productName` strings between `kInventoryItems` and `kProducts`.
- **Walk-in Restrictions**: Code explicitly blocks a transaction if "Partial Payment" or "Credit Sale" is selected without an active `Customer` object attached.
- **State Reset**: Passing local state arrays (`_cart`) by reference between screens requires careful management. `Navigator.pop` uses `.then((_) => setState(() {}))` to force a UI refresh.

## Last Updated
- Date: 2026-03-08
- Summary: Initial blueprint creation.
- Triggered By: Task to produce AI Orientation context maps.
