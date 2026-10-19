# Budget Tracking (Cashew)

Personal finance, expense tracking, and budget management application.

## Language

**Transaction**:
A recorded financial event representing an inflow (income), outflow (expense), transfer between wallets, or debt/credit entry.
_Avoid_: Purchase, record, entry, log

**Wallet**:
A financial container (such as cash, bank account, credit card, or investment fund) holding a balance in a specific currency.
_Avoid_: Account, bank, bucket, pot

**Category**:
A classification with an associated icon and color used to group transactions for budgeting and analytics.
_Avoid_: Tag, label, folder, group

**Budget**:
A spending limit set across selected categories over a designated time cycle (e.g., weekly, monthly, annual).
_Avoid_: Limit, ceiling, quota, allowance

**Objective**:
A targeted savings milestone tracking progress toward a specific accumulated monetary sum.
_Avoid_: Goal, target, piggy bank

**Associated Title**:
A merchant or payee identifier pattern that automatically maps transactions to designated categories or wallets.
_Avoid_: Payee rule, auto-tagger, merchant matcher

**Subscription**:
A recurring transaction with scheduled billing intervals and renewal reminders.
_Avoid_: Recurring bill, repeating charge, standing order

**Drift Schema**:
The versioned relational SQLite database schema and migration steps managed through Drift in `budget/lib/database/`.
_Avoid_: DB model, raw SQL schema, migration table
