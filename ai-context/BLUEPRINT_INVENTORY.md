# FEATURE BLUEPRINT: Inventory

## What It Does
The Inventory feature handles the management of physical stock, including full products (bottles, cans, kegs) and empty crates (which are valuable assets). It allows tracking current stock, viewing supplier information, adjusting physical stock levels, and viewing the history of inventory activities (logs).

## Entry Points
- UI elements: `AppDrawer` "Inventory" navigation item.
- Routes / URLs: `inventory` route in `app_drawer.dart`.
- Files: `inventory_screen.dart`.

## File Map
- `lib/features/inventory/screens/inventory_screen.dart`: Main dashboard holding Stock, Crates, and Suppliers tabs.
- `lib/features/inventory/data/inventory_data.dart`: The core in-memory "database" holding `kInventoryItems`, `kSuppliers`, `kCrateStocks`, and `kInventoryLogs`.
- `lib/features/inventory/data/models/...`: Defines `InventoryItem`, `Supplier`, `CrateStock`, `CrateGroup`, `InventoryLog`.
- `lib/features/inventory/widgets/...`: Contains specific UI segments like `update_stock_sheet.dart` or `crate_group_card.dart`.

## Data Flow
  1. User opens Inventory screen.
  2. Data is read directly from `kInventoryItems`, `kCrateStocks`, `kSuppliers`.
  3. User taps a product to update stock (triggering `update_stock_sheet.dart`).
  4. User submits the stock adjustment form.
  5. The form's save action mutates the target item in `kInventoryItems`.
  6. An `InventoryLog` is appended to `kInventoryLogs` representing the adjustment.
  7. The `setState()` in the main screen rebuilds the UI to reflect changes.

## State
- Global State read/owned: `kInventoryItems`, `kCrateStocks`, `kSuppliers`, `kInventoryLogs`.
- Modifies: The aforementioned static lists.
- Data lives in: JVM Memory only (lost on restart).

## API Contracts / Data Models
No external API calls.
Models:
- `InventoryItem`: `id`, `productName`, `stock`, `lowStockThreshold`.
- `CrateStock`: `group`, `available`.
- `Supplier`: `id`, `name`, `crateGroup`.

## Dependencies
- POS Feature: POS consumes `kInventoryItems` to generate the storefront. Changing inventory structure breaks POS.
- Deliveries Feature: Deliveries automatically inject logs into `kInventoryLogs` and add to `kInventoryItems.stock`.

## How To...
- **Add a new stock item** → Edit `kInventoryItems` in `inventory_data.dart` directly or build an add-product form.
- **Change what constitutes "Low Stock"** → Edit the `lowStockThreshold` field logic in the `InventoryItem` model.
- **Change how crates are grouped** → Edit the `CrateGroup` enum and related `Supplier` mappings.

## Gotchas
- **Hardcoded Mappings**: `inventory_data.dart` uses hardcoded strings (`'s1'`, `'s2'`) for IDs that tie inventory to suppliers. Be careful not to break relational mapping since there are no foreign keys checking this safely.
- **Stock Depletion**: If stock goes below 0, it generally isn't constrained strictly by POS unless checked. POS checks `stock > 0` conditionally.

## Last Updated
- Date: 2026-03-08
- Summary: Initial blueprint creation.
- Triggered By: Task to produce AI Orientation context maps.
