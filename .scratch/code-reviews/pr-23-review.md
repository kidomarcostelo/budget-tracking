# Code Review Report: PR #23 (Final Implementation)

**Target Branch:** `feat/uncertain-match-review` against `main`  
**Pull Request:** [#23](https://github.com/kidomarcostelo/budget-tracking/pull/23) (`feat(notifications): add uncertain match classification and review route (Slice S4)`)  
**Tracking Issue:** [#7](https://github.com/kidomarcostelo/budget-tracking/issues/7) (Task: [`BT-0003`](../BT-0003-extend-auto-transactions-google-pay/task.md))  
**Commits Reviewed:**
- `f8f4467b` fix(dedupe): resolve SQLite update bug, merchant corroboration false positives, and loose parameter clump
- `635770de` fix(notifications): address review findings for uncertain match classification and dispatch
- `178689c2` fix(notifications): harden merchant heuristics, candidate matching, and review routing
- `c2176012` feat(notifications): add uncertain match classification and review route (Slice S4)
- `9961cf3d` docs(tasks): update BT-0003 task spec with merged PR 20 status and S4 roadmap
**Review Timestamp:** 2026-11-03T16:38:00+08:00

---

## Standards

### (a) Documented Standards Violations
**None detected.** All previous violations from prior review passes have been resolved:
- **Localization (`AGENTS.md: Localization`):** Hardcoded fallback English string literals in `PossibleDuplicateBanner` were eliminated. Translation keys (`possible-duplicate-detected`, `possible-duplicate-description`, and `similar-transaction-found`) are fully defined in `translations.csv` and compiled across all 48 `generated/*.json` locale files.
- **Theming & Decomposition (`AGENTS.md`):** Dynamic colors use `getColor(context, 'warningOrange')` and theme color palettes. Banner UI is modularized in `budget/lib/widgets/possibleDuplicateBanner.dart`.
- **Database Seams (`AGENTS.md: Database Seams`):** SQLite persistence uses Drift DAO operations (`updateDedupeEntryStatus`, `insertDedupeEntry`) without raw queries.
- **Commit Trailers (`AGENTS.md: Boundaries`):** No `Co-authored-by` trailers present in commit logs.

---

### (b) Baseline Smells (Judgement Calls)

1. **Data Clump**
   - **`budget/lib/struct/dedupeLedger.dart:962-976`**:
     ```dart
     Future<DedupeCheckResult> _resolvePaymentMatch({
       required List<DedupeEntryRecord> candidates,
       required DedupeMerchantContext currentContext,
       required String eventKey,
       required String? packageName,
       ...
       required String? title,
       required String? rawContent,
       required String source,
       required DateTime now,
       required DateTime? eventTime,
     })
     ```
     13 loose parameters are forwarded across `checkAndRecordNotification` and `checkAndRecordPayment`. Fields like `title`, `rawContent`, `source`, and `packageName` duplicate information already packaged in `currentContext`, while the remaining arguments mirror `DedupeEntryRecord` attributes.  
     *Remedy:* Pass an event parameter bundle or construct a draft `DedupeEntryRecord` before delegating to `_resolvePaymentMatch`.

2. **Duplicated Code**
   - **`budget/lib/struct/dedupeLedger.dart:679-696`**:
     ```dart
     for (final existing in entries.reversed) {
       if (existing.packageName == packageName && existing.notificationId == notificationId) {
         if (now.difference(existing.dateTimeCreated).abs() <= window) return existing;
       }
     }
     for (final existing in uncertainEntries.reversed) {
       // identical loop body repeated
     }
     ```
     Exact matching iteration is duplicated identically across `entries` and `uncertainEntries`.  
     *Remedy:* Concatenate sequences (`[...entries.reversed, ...uncertainEntries.reversed]`) or extract a shared matching predicate helper.

3. **Middle Man / Parameter Redundancy**
   - **`budget/lib/struct/dedupeLedger.dart:416-428`**:
     `hasCorroboratingMerchant({first, second, entry1, entry2})` accepts four optional parameters simulating method overloading, converting entries to contexts on the fly before forwarding to `hasCorroboratingContext`.  
     *Remedy:* Provide distinct methods (e.g. `hasCorroboratingContext` and `hasCorroboratingEntries`) rather than optional 4-parameter dispatch.

---

## Spec

### (a) Requirements Missing or Partial

1. **Structured explainability reasons not persisted or surfaced in review UI**
   - **Spec:** `"Persist structured reasons rather than one opaque score — amountExactMinorUnits... titleSimilarity... bankReferenceMatched — which also makes thresholds tunable"` (BT-0002 `research.md:61-63`) and `"The review region is only usable if the reviewer can see *why* a pair scored where it did"` (`research.md:61`).
   - **Diff:** While commit `635770de` added `matchReasons: List<String>` on `DedupeCheckResult`, `DedupeEntryRecord` and the Drift schema `DedupeEntries` (`dedupeLedger.dart:10-45, 579-600`) do not persist these match reasons. Furthermore, `PossibleDuplicateBanner` (`possibleDuplicateBanner.dart:25-44`) does not receive or render match factors, displaying only static copy with amount and title. The reviewer cannot see *why* the match was considered uncertain.

2. **NFKC Unicode normalization omitted**
   - **Spec:** `"Jaro–Winkler ≥ 0.90 after NFKC + full case folding + aggregator-prefix strip raises confidence"` (BT-0002 `research.md:18, 43`).
   - **Diff:** `cleanMerchant` and `jaroWinklerSimilarity` (`dedupeLedger.dart:267-272, 330-334`) apply `.toLowerCase()` and strip aggregator prefixes, but omit Unicode NFKC normalization, leaving fullwidth/halfwidth forms and compatibility ligatures unnormalized prior to fuzzy matching.

---

### (b) Behaviour in Diff Not Asked For (Scope Creep)

1. **App Links URL review route interception**
   - **Spec:** `"Expected behavior: on Android, a Google Pay payment notification (and the bank notification for the same payment, when both exist) produces at most one prefilled Transaction."` (BT-0003 `task.md:16-18`) and `"Out of scope: iOS, Gmail ingestion (#2, #3), Triage UI (#4, #5)"` (GitHub Issue #7).
   - **Diff:** `budget/lib/widgets/util/appLinks.dart:184-218` modifies general App Links / external URL intent dispatch (`processAddTransactionFromParams`) to intercept external URL intents and push review routes with `PossibleDuplicateBanner`. External URL scheme shortcuts fall outside the Android payment notification deduplication scope.

---

### (c) Requirements Implemented Wrongly

1. **Review promotion uses fragile in-memory matched PK lookup**
   - **Spec:** `"Uncertain matches go to review instead of being auto-created."` (GitHub Issue #7; BT-0003 `task.md:18`).
   - **Diff:** On saving an uncertain transaction, `addTransactionPage.dart:572-578` calls `confirmUncertainEntryForMatchedPk(widget.possibleDuplicateEntry!.entryPk)`. In `dedupeLedger.dart:644-658`, this executes `uncertainEntries.lastIndexWhere((e) => e.matchedEntryPk == matchedEntryPk)`. This only checks ephemeral in-memory state (failing if uncertain entries were not loaded into memory), and if multiple uncertain events matched the same candidate, `lastIndexWhere` promotes only the newest entry while stranding earlier ones. The review page should track and promote the uncertain entry by its own primary key.

---

## Summary

Standards found **0 documented violations** and **3 baseline smell heuristics** (worst: 13-parameter data clump in `_resolvePaymentMatch`); Spec found **4 findings** (worst: review promotion uses fragile in-memory matched PK lookup that risks stranding uncertain records).
