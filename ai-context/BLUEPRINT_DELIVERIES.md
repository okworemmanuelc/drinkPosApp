# FEATURE BLUEPRINT: Deliveries

## What It Does
The Deliveries feature manages incoming stock from suppliers. When a delivery truck arrives (e.g., from Nigerian Breweries), the application needs to log the arrival of full products and update the physical inventory accordingly. It also acts as an audit log for stock increases.

## Entry Points
- UI elements: `AppDrawer` "Deliveries" navigation item.
- Routes / URLs: `deliveries` route in `app_drawer.dart`.
- Files: `deliveries_screen.dart`, `receive_delivery_sheet.dart`.

## File Map
- `lib/features/deliveries/screens/deliveries_screen.dart`: List of historic deliveries received.
- `lib/features/deliveries/widgets/receive_delivery_sheet.dart`: Form where a user specifies which products arrived and in what quantities.
- `lib/features/deliveries/data/models/delivery.dart`: The underlying data configuration.
- `lib/features/deliveries/data/services/delivery_service.dart`: Executes the stock update.

## Data Flow
  1. User opens `receive_delivery_sheet.dart`.
  2. Selects Supplier and Products received. Specifies quantities.
  3. On submit, `DeliveryService` processes the form.
  4. `kInventoryItems` stock attributes are incremented for every product in the delivery.
  5. A log is written to `kDeliveries` and `kInventoryLogs`.
  6. The `deliveries_screen.dart` rebuilds.

## State
- Global State Mutated: `kDeliveries`, `kInventoryItems`, `kInventoryLogs`.

## API Contracts / Data Models
Models:
- `Delivery`: `id`, `supplierId`, `date`, `items` (List of Product ID + Quantities).

## Dependencies
- Inventory Feature: Directly mutates the stock integers within the inventory model.
- Requires `Supplier` definitions to exist.

## How To...
- **Add driver details to a delivery** → Extend the `Delivery` model and the `receive_delivery_sheet.dart` form.
- **Undo a delivery** → No built-in undo; requires manual negative adjustments in Inventory.

## Gotchas
- **Crate Returns vs Full Deliveries**: A delivery often involves yielding empty crates back to the supplier. Watch for logic that automatically decrements `kCrateStocks` when a delivery is logged (if the business model enforces a 1-to-1 swap).

## Last Updated
- Date: 2026-03-08
- Summary: Initial blueprint creation.
- Triggered By: Task to produce AI Orientation context maps.
