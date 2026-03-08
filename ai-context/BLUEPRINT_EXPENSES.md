# FEATURE BLUEPRINT: Expenses

## What It Does
The Expenses feature tracks outgoing business expenditures (e.g., fuel, wages, shop maintenance, supplier payments). It is a standalone ledger designed to help owners understand where money is going, independent of POS sales income.

## Entry Points
- UI elements: `AppDrawer` "Expenses" navigation item.
- Routes / URLs: `expenses` route in `app_drawer.dart`.
- Files: `expenses_screen.dart`, `add_expense_sheet.dart`.

## File Map
- `lib/features/expenses/screens/expenses_screen.dart`: Shows a list of recorded expenses, usually grouped by date or category.
- `lib/features/expenses/widgets/add_expense_sheet.dart`: Form to record a new expense.
- `lib/features/expenses/data/models/expense.dart`: The `Expense` model.
- `lib/features/expenses/data/services/expense_service.dart`: Service to add or fetch expenses.

## Data Flow
  1. User fills `add_expense_sheet.dart` (Amount, Category, Description, Date).
  2. `ExpenseService` attaches it to `kExpenses`.
  3. Updates UI in `expenses_screen.dart`.

## State
- Global State Mutated: `kExpenses`.

## API Contracts / Data Models
Models:
- `Expense`: `id`, `amount`, `category`, `description`, `date`.

## Dependencies
- Wholly independent. Does not rely on inventory or customers.

## How To...
- **Add a new expense category** → Add options to the dropdown in `add_expense_sheet.dart`.
- **View total expenses** → Ensure `expenses_screen.dart` maps over and reduces the `kExpenses` array into a sum.

## Gotchas
- **Cash vs Bank**: The current schema might not specify *how* the expense was paid (from cash drawer vs bank account). If doing cash reconciliation later, this will be missing data.

## Last Updated
- Date: 2026-03-08
- Summary: Initial blueprint creation.
- Triggered By: Task to produce AI Orientation context maps.
