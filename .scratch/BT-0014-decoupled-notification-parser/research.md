# Feasibility Research: Decoupled Bank Notification Parser via External Automation

**Task Reference:** BT-0014  
**GitHub Issue:** [#37](https://github.com/kidomarcostelo/budget-tracking/issues/37)  
**Status:** Pending Research (To be conducted by research model)  

---

## 1. Research Questions to Investigate

1. **Android IPC Mechanisms & OS Constraints:**
   - How do background execution restrictions (Android 12/13/14/15, Doze mode, background activity launch restrictions) impact Automate calling Cashew's App Link (`https://cashewapp.web.app/addTransaction` / `addTransactionRoute`)?
   - Can/should Cashew register a native headless `BroadcastReceiver` (`com.budget.tracker_app.ACTION_ADD_TRANSACTION`) to receive transaction payloads directly into Drift SQLite without waking the Flutter UI?

2. **UX & Integration with Non-Blocking Queue ([#33](https://github.com/kidomarcostelo/budget-tracking/issues/33)):**
   - How can external intents integrate with the pending queue in #33 (e.g. passing `pending=true` so transactions are staged for review)?
   - How to prevent disruptive screen focus theft when a transaction occurs while the user is using another app?

3. **Trade-off Analysis: Direct IPC (App Links/Intents) vs Standardized Notification Bridge:**
   - Option A: Automate directly calls Cashew API (Intent/App Link).
   - Option B: Automate posts a standardized local notification (`CashewTx: {...}`), and Cashew listens to that single notification.
   - Comparative evaluation across battery consumption, user permission friction (`BIND_NOTIFICATION_LISTENER_SERVICE`), and reliability.

4. **Deduplication Safeguards:**
   - Interaction with `DedupeLedger` (`budget/lib/struct/dedupeLedger.dart`) if both built-in notification scanning and Automate flows are running.

5. **Community Distribution:**
   - Feasibility and ease of sharing Automate `.flo` flows or Tasker XML profiles with users for local banks (e.g. Maya, GCash, BDO, BPI, UnionBank).

---

## 2. Research Findings & Analysis

*(To be filled in by the assigned research agent/model)*

---

## 3. Recommended Architecture & Data Contract

*(To be filled in by the assigned research agent/model)*
