# FEATURE BLUEPRINT: Payments

## What It Does
The Payments feature tracks incoming cash or bank transfers from registered customers that are meant to offset their outstanding ledger debts. It is distinct from POS sales; it is purely a financial ledger entry for debt reconciliation.

## Entry Points
- UI elements: `AppDrawer` "Payments" navigation item. Customer Detail Screen "Add Payment" action.
- Routes / URLs: `payments` route in `app_drawer.dart`.
- Files: `payments_screen.dart`, `add_payment_sheet.dart`.

## File Map
- `lib/features/payments/screens/payments_screen.dart`: Dashboard of recent payments received.
- `lib/features/payments/widgets/add_payment_sheet.dart`: Form to record a new payment.
- `lib/features/payments/data/models/payment.dart`: The `Payment` object definition.
- `lib/features/payments/data/services/payment_service.dart`: Logic for handling the payment.

## Data Flow
  1. User records a payment via `add_payment_sheet.dart`.
  2. Payload consists of Customer ID, Amount, Method (Cash/Transfer), and Date.
  3. `PaymentService` appends to `kPayments` list.
  4. Core Logic: The `Customer`'s `outstandingBalance` must be decreased by the `Amount` paid.
  5. UI refreshes to show the updated history.

## State
- Global State Mutated: `kPayments`, `kCustomers` (decrements debt).
- Tightly linked to the `Customer` model.

## API Contracts / Data Models
Models:
- `Payment`: `id`, `customerId`, `amount`, `method`, `timestamp`.

## Dependencies
- Customers Feature: Needs active customers to attach payments to.

## How To...
- **Add a new payment method** → Update dropdown selections in `add_payment_sheet.dart` and handle styling in `payments_screen.dart`.
- **Change debt calculus** → Edit the logic fired when `Add Payment` is confirmed (likely in `PaymentService` or a controller).

## Gotchas
- Overpayment checking: Ensure that if a payment exceeds a debt, it handles the arithmetic cleanly (leaving the customer with a negative debt, meaning the shop owes them credit).

## Last Updated
- Date: 2026-03-08
- Summary: Initial blueprint creation.
- Triggered By: Task to produce AI Orientation context maps.
