# Stats Page added as a dedicated bottom nav tab at slot 3

A new Stats Page was added as a first-class bottom nav destination (slot 3), shifting the existing "More" to slot 4, making a 5-tab nav bar.

The Stats Page hosts the enhanced pie chart + Category Spending Legend in a full-screen, period-aware context. Making it a nav tab (rather than a route pushed from the home card) gives it equal discoverability with Transactions and Budgets, reflects that analytics is a primary use case, and matches the reference design. The 5-tab bar is a deliberate deviation from the prior 4-tab layout; it was preferred over replacing or hiding an existing tab because all existing tabs retain their purpose.

The Stats Page uses its own independent period setting (`cycleSettingsExtension: "StatsPieChart"`) so its time window is decoupled from the home page pie chart's period.
