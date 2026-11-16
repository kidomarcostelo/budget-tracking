# Code Reviews

This directory contains persistent, two-axis code review records for pull requests in `budget-tracking`.

## Review Methodology

Code reviews in this repository evaluate incoming pull requests along two strictly separated axes to prevent one axis from masking the other:

1. **Standards Axis**: Evaluates conformance against repository quality constraints ([`CONSTRAINTS.md`](../../CONSTRAINTS.md)), agent development guide ([`AGENTS.md`](../../AGENTS.md)), domain vocabulary ([`GLOSSARY.md`](../../GLOSSARY.md)), architecture guides ([`docs/architecture.md`](../architecture.md)), and Fowler refactoring smell baselines.
2. **Spec Axis**: Evaluates implementation against the originating GitHub issue specification and local scratchpad task specification ([`docs/agents/issue-tracker.md`](../agents/issue-tracker.md)), reporting missing requirements, scope creep, and improper implementations.

## Review Index

| PR | Issue / Task | Title | Review Date | Status | Record |
|:---|:-------------|:------|:------------|:-------|:-------|
| [#22](https://github.com/kidomarcostelo/budget-tracking/pull/22) | [#21](https://github.com/kidomarcostelo/budget-tracking/issues/21) / BT-0010 | feat(android): isolate debug build with applicationIdSuffix and Cashew Dev label | 2026-11-02 | Remediated | [PR-22-debug-app-isolation.md](PR-22-debug-app-isolation.md) |
| #40 / #41 | #7 / BT-0016 | feat(notifications): add background keep-alive service and battery optimization prompt | 2026-11-16 | Under Review | [PR-40-background-headless-listener.md](PR-40-background-headless-listener.md) |
| [#48](https://github.com/kidomarcostelo/budget-tracking/pull/48) | [#40](https://github.com/kidomarcostelo/budget-tracking/issues/40) / BT-0017 | feat(analytics): add enhanced pie chart, category spending legend, and dedicated stats page | 2026-11-16 | Under Review | [PR-48-enhanced-piechart-and-stats-page.md](PR-48-enhanced-piechart-and-stats-page.md) |
| [#49](https://github.com/kidomarcostelo/budget-tracking/pull/49) | BT-0018 | fix(notifications): prefer most specific wallet name match for Google Pay | 2026-11-16 | Complete | [PR-49-googlepay-wallet-resolution-specificity.md](PR-49-googlepay-wallet-resolution-specificity.md) |
