# Code Review: Pull Request #49 (BT-0018)

- **Target / PR:** Pull Request [#49](https://github.com/kidomarcostelo/budget-tracking/pull/49) — `fix(notifications): prefer most specific wallet name match for Google Pay (BT-0018)`
- **Branch:** `fix/BT-0018-googlepay-wallet-resolution-specificity` → `main`
- **Head Commit:** [`5d5a4590`](https://github.com/kidomarcostelo/budget-tracking/commit/5d5a45906672e42ed7e33293ddbc822e67ca4184)
- **Fixed Point:** `origin/main` ([`7c4e22cc`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget))
- **Originating Spec:** [`.scratch/BT-0018-googlepay-wallet-resolution-specificity/task.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0018-googlepay-wallet-resolution-specificity/task.md) & [`.scratch/BT-0018-googlepay-wallet-resolution-specificity/pr-body.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/.scratch/BT-0018-googlepay-wallet-resolution-specificity/pr-body.md)
- **Review Date:** 2026-11-16
- **Review Type:** Two-Axis Code Review (Standards & Spec)

---

## Executive Summary

| Axis | Findings Count | Worst Issue | Status |
|:-----|:--------------:|:------------|:-------|
| **Standards** | 3 (1 hard violation, 2 baseline smells) | Commits use GitHub noreply email address instead of `kidomarcostelo@gmail.com` as documented in `AGENTS.md` (caused by GitHub GH007 email privacy check). | Needs Attention |
| **Spec** | 1 (1 minor textual note, 0 functional gaps) | PR description paraphrased acceptance criteria sentence rather than quoting verbatim. Zero functional or scope issues. | Pass |

---

## 1. Standards Axis

### (a) Documented Standards Violations

1. **Hard Violation: Commit Author Email**
   - **Standard:** [`AGENTS.md`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/AGENTS.md) (*Commit Author & Email* — `"Always ensure Git commits use the author email kidomarcostelo@gmail.com (git config user.email "kidomarcostelo@gmail.com"). Do not commit using another email address."`)
   - **Location:** Commits `ea2cf35b` and `5d5a4590`.
   - **Violation:** Commits are authored using `111844659+kidomarcostelo@users.noreply.github.com`.
   - **Context & Remediation:** This was driven by GitHub remote rejection `GH007 (push declined due to email privacy restrictions)` when pushing `kidomarcostelo@gmail.com`. Either `AGENTS.md` should be formally updated across `main` to document the authorized noreply email address, or GitHub account email privacy protection should be unblocked.

---

### (b) Baseline Code Smells (Judgement Calls)

1. **Duplicated Code — Longest Contained Wallet Name Matching**
   - **Smell:** Duplicated Code (*Refactoring* ch.3)
   - **Location:** [`budget/lib/struct/googlePayParser.dart:212-231`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/struct/googlePayParser.dart#L212-L231) vs [`budget/lib/struct/sharedReceiptProcessor.dart:122-136`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/struct/sharedReceiptProcessor.dart#L122-L136)
   - **Observation:** The loop searching `allWallets` for the longest contained matching name is duplicated verbatim across `GooglePayParser` and `SharedReceiptProcessor`:
     ```dart
     for (final wallet in allWallets) {
       final nameLower = wallet.name.trim().toLowerCase();
       if (nameLower.isEmpty) continue;
       if (cardNameLower.contains(nameLower) && nameLower.length > bestLength) {
         bestMatch = wallet;
         bestLength = nameLower.length;
       }
     }
     ```
   - **Recommendation:** Extract a shared helper method (e.g., `resolveWalletByLongestContainedName(String text)` or a method on `FinanceDatabase`) to eliminate duplication.

2. **Feature Envy — In-Memory Wallet Entity Filtering**
   - **Smell:** Feature Envy (*Refactoring* ch.3; relates to `AGENTS.md` *Database Seams*)
   - **Location:** [`budget/lib/struct/googlePayParser.dart:215-231`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/struct/googlePayParser.dart#L215-L231) & [`budget/lib/struct/sharedReceiptProcessor.dart:123-136`](file:///C:/Users/kidpr/Documents/.repository/budget-tracking/budget/lib/struct/sharedReceiptProcessor.dart#L123-L136)
   - **Observation:** Both parsers pull the full list of wallets via `database.getAllWallets()` and perform in-memory substring matching on wallet records.
   - **Recommendation:** Place wallet resolution methods directly on `FinanceDatabase` in `tables.dart` alongside `getRelatingWallet`.

---

## 2. Spec Axis

### (a) Requirements Missing or Partial

1. **Minor / Textual Acceptance Criterion Quote:**
   - **Spec Quote:** `task.md` L217: `"- [ ] PR description states: \"Fix: resolveWallet preferred first-token-wins over longest-name match; replaced with contained-name scan sorted by name length DESC\""`
   - **Finding:** The PR description clearly explains this logic in the Summary section but paraphrases rather than copying the exact verbatim phrase from the acceptance checklist.
   - **Functional Status:** All functional requirements are met. All 5 regression test cases in `google_pay_wallet_resolve_test.dart` and existing notification/receipt parser test suites pass cleanly.

---

### (b) Scope Creep (Unasked-for Behaviour)

- **None:**
  - Changes in `budget/lib/struct/googlePayParser.dart` directly implement Steps 1 & 2 (`task.md` L90–153).
  - Changes in `budget/lib/struct/sharedReceiptProcessor.dart` implement Step 3 cross-cutting alignment (`task.md` L155–184).
  - Task files in `.scratch/BT-0018-googlepay-wallet-resolution-specificity/` conform to project issue tracking standards.

---

### (c) Requirements Implemented Incorrectly

- **None:**
  - `_resolveByLongestContainedName` in `googlePayParser.dart` (L211–230) mirrors the spec's reference implementation (`task.md` L97–116) verbatim, guaranteeing case-insensitive matching and length-descending preference.
  - Resolution precedence in `resolveWallet` (L185–194) correctly preserves `cardLast4` priority, exact/LIKE `getRelatingWallet` match, followed by `_resolveByLongestContainedName`, and defaults to `selectedWalletPk`.
  - `SharedReceiptProcessor.resolveWalletByName` (L123–135) correctly mirrors the longest-match replacement specified in `task.md` L168–181.

---

## 3. Summary & Recommended Action Plan

- **Standards Axis:** 3 findings (1 hard violation on commit author email due to GitHub privacy restrictions; 2 baseline smells on duplicated wallet matching logic).
- **Spec Axis:** 1 finding (0 functional gaps, 1 minor textual paraphrasing note). Clean pass.
