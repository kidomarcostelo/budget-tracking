# Multi-Currency Handling and Historical Rate Isolation

Each wallet maintains its own native currency, and transactions record amounts in that wallet's currency.

When transactions are converted to the primary global currency for budget totals and reporting, they preserve the exchange rate active at transaction creation time rather than dynamically recalculating against live exchange rates. This ensures historical monthly budgets and past financial reports remain stable and immune to foreign exchange market fluctuations over time.
