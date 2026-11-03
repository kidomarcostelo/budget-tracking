# Code Review Report: PR #23

**Target Branch:** `feat/uncertain-match-review` against `main`  
**Pull Request:** [#23](https://github.com/kidomarcostelo/budget-tracking/pull/23) (`feat(notifications): add uncertain match classification and review route (Slice S4)`)  
**Tracking Issue:** [#7](https://github.com/kidomarcostelo/budget-tracking/issues/7) (Task: [`BT-3`](../BT-3-extend-auto-transactions-google-pay/task.md))  
**Commits Reviewed:**
- `178689c2` fix(notifications): harden merchant heuristics, candidate matching, and review routing
- `c2176012` feat(notifications): add uncertain match classification and review route (Slice S4)
- `9961cf3d` docs(tasks): update BT-3 task spec with merged PR 20 status and S4 roadmap

---

## Standards

### (a) Documented Standards Violations

1. **Hardcoded Fallback Strings in Build Logic**
   - **Citation:** `AGENTS.md` — *Localization: All user-facing text must use localized strings via app_localizations or existing localization delegates.*
   - **Location:** `budget/lib/widgets/possibleDuplicateBanner.dart:20-48`
   - **Violation (Hard):** The widget embeds raw English string literals directly in Dart build logic as fallback values (`'Possible duplicate detected'`, `'A similar transaction was recorded recently. Please review details before saving.'`, `'Similar transaction found'`) when `.tr()` returns the raw translation key. Furthermore, translations were only added directly to `en.json` and `fil.json`, bypassing `translations.csv` and leaving other supported locales incomplete.

---

### (b) Baseline Smells (Judgement Calls)

1. **Duplicated Code**
   - **`budget/lib/struct/notificationDispatcher.dart:381-393, 401-414, 428-440`**:
     Dynamic reflection fallback is duplicated 3 times across `customQueueHandler`, `onGooglePayTransaction`, and `handler`:
     ```dart
     try {
       await (fn as dynamic)(
         ...,
         isPossibleDuplicate: dedupeResult.isUncertainMatch,
         possibleDuplicateEntry: dedupeResult.matchedEntry,
       );
     } catch (e) {
       if (e is NoSuchMethodError) {
         await fn(...);
       } else {
         rethrow;
       }
     }
     ```
     *Remedy:* Update the `TransactionQueueHandler` typedef to include optional named parameters, eliminating reflection and error trapping.
   - **`budget/lib/struct/dedupeLedger.dart:561-638 & 683-756`**:
     Candidate iteration, merchant corroboration loop, suppression recording, and uncertain fallback logic in `checkAndRecordNotification` and `checkAndRecordPayment` share duplicate control flow and structure.
     *Remedy:* Extract candidate resolution and entry creation into a shared helper method on `DedupeLedger`.

2. **Data Clumps**
   - **`budget/lib/struct/dedupeLedger.dart:231-240`**:
     ```dart
     static bool hasCorroboratingMerchant({
       String? title1,
       String? content1,
       String? title2,
       String? content2,
       String? source1,
       String? source2,
       String? package1,
       String? package2,
     })
     ```
     Eight parameters travel together as two mirrored 4-tuples `(title, content, source, package)`.
     *Remedy:* Bundle into a comparison context object or pass existing `DedupeEntryRecord` instances directly.

3. **Primitive Obsession / Type Subversion**
   - **`budget/lib/struct/notificationDispatcher.dart:382, 403, 429`**:
     Casting handlers to `dynamic` and catching runtime `NoSuchMethodError` subverts Dart's static typing instead of updating `TransactionQueueHandler` and callback function signatures.
   - **`budget/lib/struct/dedupeLedger.dart:305-321`**:
     Hardcoded regional merchant keywords (`'shell gas'`, `'gotyme'`, `'starbucks'`, `'jollibee'`, `'maribank'`) embedded directly in heuristic logic rather than relying on generalized merchant extractors or configuration dictionaries.

---

## Spec

### (a) Requirements Missing or Partial

1. **Structured explainability reasons**
   - *Spec:* `"Persist structured reasons rather than one opaque score — amountExactMinorUnits... titleSimilarity... bankReferenceMatched — which also makes thresholds tunable"` (BT-2 `research.md:61-63`).
   - *Diff:* `DedupeLedger` hardcodes a single opaque string (`matchReason = 'uncertain_merchant'` in `dedupeLedger.dart:632, 750`). No structured reasons, deltas, or match factors are stored or displayed to explain to the user *why* a duplicate was suspected.

2. **Jaro-Winkler title similarity & NFKC folding**
   - *Spec:* `"Normalized merchant title similarity... Jaro–Winkler ≥ 0.90 after NFKC + full case folding + aggregator-prefix strip raises confidence"` (BT-2 `research.md:18`).
   - *Diff:* Jaro-Winkler metric and NFKC folding are absent. `hasCorroboratingMerchant` (`dedupeLedger.dart:247-283`) falls back to exact equality or raw `.contains()` substring checks.

### (b) Behaviour in Diff Not Asked For (Scope Creep)

1. **Hardcoded regional merchant whitelist**
   - *Spec:* `"Samples must preserve reference format while masking digits... Not verified from primary sources: local acquirer descriptor conventions"` (BT-2 `research.md:80-85`).
   - *Diff:* `dedupeLedger.dart:305-316` embeds hardcoded local Philippine brands (`'maribank'`, `'gotyme'`, `'maya'`, `'jollibee'`) directly into core deduplication logic.

2. **App Links review route interception**
   - *Spec:* `"Expected behavior: on Android, a Google Pay payment notification (and the bank notification for the same payment, when both exist) produces at most one prefilled Transaction."` (BT-3 `task.md:16-18`).
   - *Diff:* `appLinks.dart:184-218` modifies App Links URL handling to intercept and push review routes for external URL intents.

### (c) Requirements Implemented Wrongly

1. **Uncertain entries pollute candidate ledger and cause false suppression**
   - *Spec:* `"Uncertain matches go to review instead of being auto-created."` (BT-3 `task.md:18`).
   - *Diff:* `_recordUncertainEntry` (`dedupeLedger.dart:386`) adds unconfirmed uncertain records to active `entries`. A subsequent notification corroborating that uncertain record gets marked as a confirmed duplicate (`isDuplicate: true`, lines 585-608) and silently dropped, even if the user dismissed the original banner.

2. **Typed dispatchers silently discard review route**
   - *Spec:* `"Uncertain matches go to review instead of being auto-created."` (BT-3 `task.md:18`).
   - *Diff:* `typedef TransactionQueueHandler` and `onGooglePayTransaction` (`notificationDispatcher.dart:11-15, 43`) lack review parameters. Lines 381-414 use dynamic calls; typed handlers throw `NoSuchMethodError` and fall back to parameterless calls, silently dropping `isPossibleDuplicate` and `possibleDuplicateEntry`.

---

## Summary

Standards found **1 documented violation** and **3 baseline smell heuristics** (worst: dynamic reflection fallback subverting Dart static typing across dispatch handlers); Spec found **6 findings** (worst: uncertain entries added to active candidate ledger, causing subsequent corroborated events to be falsely suppressed as confirmed duplicates).
