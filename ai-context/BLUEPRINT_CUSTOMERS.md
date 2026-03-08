# FEATURE BLUEPRINT: Customers

## What It Does
The Customers feature manages the list of registered individuals or businesses that interact with the application. It tracks their contact details, current ledger balance (debts or prepaid credits), and empty crate balances. It allows adding new customers and viewing a detailed profile containing order history, payment history, and current balances.

## Entry Points
- UI elements: `AppDrawer` "Customers" navigation item. Tapping a customer opens `CustomerDetailScreen`.
- Routes / URLs: `customers` route in `app_drawer.dart`.
- Files: `customers_screen.dart`, `customer_detail_screen.dart`, `add_customer_sheet.dart`.

## File Map
- `lib/features/customers/screens/customers_screen.dart`: List view of all customers and their outstanding balances.
- `lib/features/customers/screens/customer_detail_screen.dart`: Deep dive into a single customer's transactions, orders, and crate debts.
- `lib/features/customers/widgets/add_customer_sheet.dart`: Bottom sheet form for creating a new `Customer`.
- `lib/features/customers/data/models/customer.dart`: `Customer` data class.

## Data Flow
  1. User navigates to Customers.
  2. Reads from `CustomerService.getCustomers()` which typically returns a static list from memory (e.g., `kCustomers`).
  3. User adds a Customer via `Add Customer Sheet`.
  4. The object is appended to `kCustomers`.
  5. UI updates using `setState()`.

## State
- Global State read/owned: `kCustomers` list.
- Tightly coupled with the `Payments` and `Orders` state, as resolving a debt updates the specific `Customer`'s `outstandingBalance`.

## API Contracts / Data Models
Models:
- `Customer`: `id`, `name`, `phone`, `address`, `outstandingBalance`, `emptyCratesOwed`.

## Dependencies
- POS: Consumes `Customer` data when completing a credit or partial sale to register debt.
- Payments: Payments screen reduces the `outstandingBalance` of customers.

## How To...
- **Add a customer field** → Edit the `Customer` model and `add_customer_sheet.dart`.
- **Change how debt is displayed** → Edit the balance color logic in `customers_screen.dart` (e.g., green for prepaid, red for debt).

## Gotchas
- **Ledger Ambiguity**: An `outstandingBalance` < 0 might mean they overpaid (credit), or vice versa, depending on the math convention used in `checkout_page.dart`. Check the checkout logic closely if modifying balances.
- **Data Persistence**: Because everything is in-memory, test data must be populated on launch.

## Last Updated
- Date: 2026-03-08
- Summary: Initial blueprint creation.
- Triggered By: Task to produce AI Orientation context maps.
