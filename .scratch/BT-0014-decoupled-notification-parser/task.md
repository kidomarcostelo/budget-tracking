# Task: Research Feasibility of Decoupled Bank Notification Parser (Automate / Tasker & Cashew API)

**ID:** BT-14  
**Issue Reference:** [#37](https://github.com/kidomarcostelo/budget-tracking/issues/37)  
**Status:** Ready for Research (Queued for Research Agent / Higher Model)  
**Assignee:** TBD  

---

## 1. Objective & Scope

- **Problem Statement:**  
  Cashew's built-in notification parsing relies on simple substring delimiters (`autoTransactionsPageEmail.dart`) or hardcoded regular expressions (`googlePayParser.dart`). This makes supporting diverse and constantly changing bank notifications (GCash, Maya, BDO, BPI, UnionBank, etc.) high-maintenance, fragile, and bound to app release cycles.
- **Expected Outcome:**  
  A higher model will conduct the technical feasibility study investigating decoupling bank notification capture and parsing to external automation engines (LlamaLab Automate, Tasker, MacroDroid), comparing direct IPC (App Links / Android Intents) against an intermediate standardized notification bridge.

---

## 2. Invariants & Constraints

- **Local-First Privacy ([ADR 0001](../../docs/adr/0001-local-first-drift-sqlite.md)):** All parsing and IPC must remain 100% on-device. No external cloud parsing or relay servers.
- **Deduplication Ledger ([`DedupeLedger`](../../budget/lib/struct/dedupeLedger.dart)):** External automation ingestion must respect or cooperate with Cashew's payment deduplication ledger to prevent double recording.
- **Non-blocking UX:** Avoid unexpected foreground activity hijacking when transactions occur while the user is active in other apps.
- **Canonical Vocabulary ([`GLOSSARY.md`](../../GLOSSARY.md)):** Use canonical terms (`Transaction`, `Wallet`, `Category`, `Budget`).

---

## 3. Plan & Scope of Research (To be executed by Research Agent)

- [x] Create GitHub issue [#37](https://github.com/kidomarcostelo/budget-tracking/issues/37) as a research brief.
- [ ] **Phase 1: Architecture & IPC Evaluation:** Investigate Android background execution constraints (Android 12-15) for App Links vs headless `BroadcastReceiver` vs notification listener bridge.
- [ ] **Phase 2: UX & Pending Queue Integration:** Map integration with the pending transaction queue ([#33](https://github.com/kidomarcostelo/budget-tracking/issues/33)) and non-blocking notification flows.
- [ ] **Phase 3: Prototype Flow Design:** Design sample Automate `.flo` flow definition and test matrix for representative bank notification structures.
- [ ] **Phase 4: Synthesis & Recommendation:** Compile findings and publish feasibility report to [#37](https://github.com/kidomarcostelo/budget-tracking/issues/37) and `research.md`.
