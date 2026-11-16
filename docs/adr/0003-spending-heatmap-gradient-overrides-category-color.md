# Spending Heatmap Gradient overrides category color in all pie charts

The existing pie chart uses each category's user-configured color (`Category.colour`). We decided to globally replace this with a Spending Heatmap Gradient — an HSV hue sweep from red (0°) to teal (180°) ordered largest-to-smallest share — applied to every pie chart in the app (home, budget, stats).

The user-configured category color carries meaning in category icons, budget progress bars, and transaction entries throughout the app. The pie chart's primary job, however, is to communicate *relative size at a glance*. Mapping hue to rank makes the size ordering immediately legible without reading labels, which the icon-badge approach obscured. The trade-off is that the pie chart slice colors no longer match the category's configured color, which may cause momentary confusion when cross-referencing the chart with other UI surfaces that do use the category color.

## Considered Options

- **Keep category color**: consistent across surfaces but visually indistinct for categories with similar configured colors.
- **HSV hue sweep (chosen)**: size hierarchy is instantly readable; color no longer encodes category identity in the chart.
- **User-configurable toggle**: deferred complexity; chosen simplicity wins for now.
