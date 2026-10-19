# Local-First SQLite Architecture with Drift

All application data (wallets, transactions, budgets, objectives) is stored primarily in a local SQLite database managed by Drift (`budget/lib/database/tables.dart`).

Cloud synchronization (Google Drive, Firebase) acts strictly as a secondary backup and transfer mechanism; the local Drift database is the single source of truth. All core features must work offline without requiring internet access or remote authentication. Schema changes must always include explicit forward migrations and snapshot generation.
