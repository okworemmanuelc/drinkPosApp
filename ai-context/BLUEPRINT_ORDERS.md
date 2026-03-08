# FEATURE BLUEPRINT: Orders

## What It Does
The Orders feature is a read-only historical ledger that lists all past sales and transactions generated through the POS checkout. It provides an overview of daily sales volume and offers a way to view old receipts.

## Entry Points
- UI elements: `AppDrawer` "Orders" navigation item.
- Routes / URLs: `orders` route in `app_drawer.dart`.
- Files: `orders_screen.dart`.

## File Map
- `lib/features/orders/screens/orders_screen.dart`: Displays the history of transactions.

## Data Flow
  1. Navigating to Orders fetches the global list containing sales (often mixed with or separate from `kActivityLogs` or a `kOrders` list).
  2. UI displays them sorted by date.
  3. User can tap an order to view the generated receipt.

## State
- Global State read: `kOrders` or `kInventoryLogs` (depending on how sales are stored).
- This feature is primarily read-only.

## API Contracts / Data Models
Models:
- `Order` or `SaleLog`: Contains timestamps, total amounts, list of items, customer info, and payment type.

## Dependencies
- Exclusively depends on the POS module to generate the data that appears here.

## How To...
- **Add a filter to orders** → Implement a date-picker or status toggle in `orders_screen.dart`.
- **Reprint a receipt** → Fetch the `Order` data, construct it via `receipt_builder.dart`, and send it to the printing utility.

## Gotchas
- **No Edit Functionality**: Historic orders cannot be edited or voided in the current prototype. Reversing an order requires careful manual ledger adjustments.

## Last Updated
- Date: 2026-03-08
- Summary: Initial blueprint creation.
- Triggered By: Task to produce AI Orientation context maps.
