# Callout-line labels replace icon badge widgets in all pie charts globally

The existing `PieChartDisplay` renders a `_Badge` widget (category icon inside a colored circle) on each slice. We decided to replace this globally with callout lines — a line extending from the slice to an external label showing category name and percentage.

Icon badges hide behind each other on small slices (the code already hides badges for slices under 5%), and reading them requires knowing which icon maps to which category. Callout lines surface the category name and percentage directly without prior knowledge. The trade-off is that callout lines can overlap on charts with many small slices; this is mitigated by suppressing labels below a 1% threshold and offsetting overlapping labels.

This change applies to all pie charts (home, budget details, stats) because a split style — callouts in some contexts, icons in others — would create an inconsistent mental model when users navigate between screens.
