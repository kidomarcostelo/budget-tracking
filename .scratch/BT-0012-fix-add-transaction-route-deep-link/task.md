# Task: Fix addTransactionRoute deep link prefilled fields and sequence blocking

**ID:** BT-12  
**Issue Reference:** [#28](https://github.com/kidomarcostelo/budget-tracking/issues/28)  
**Status:** In Progress  
**Assignee / Agent:** AI Assistant  

---

## 1. Objective & Scope
- **Problem Statement:**  
  When invoking the deep link route `/addTransactionRoute` with parameters (e.g. `title=GrabFood&amount=340.00&note=...&wallet=UnionBank&category=Dining`):
  1. `processAddTransactionRouteFromParams` in `appLinks.dart` omits `startInitialAddTransactionSequence: false`. This triggers Cashew's default manual title entry sequence (`SelectTitle`), blocking the screen with an "Enter Title" dialog and keyboard.
  2. The resolved category is not surfaced on the modal until the user manually clicks "Select Category".
  3. The amount displays as 0 behind the modal.
  4. Notes passed via `note` are ignored because only `params["notes"]` is queried.
- **Expected Behavior:**  
  1. When prefilled parameters are supplied, `startInitialAddTransactionSequence: false` is passed to `AddTransactionPage`, bypassing the manual entry modal wizard and presenting all prefilled fields directly on screen.
  2. Both `note` and `notes` are supported for notes.
  3. Both `title` and `name` are supported for title.
  4. `useCategorySelectedIncome: true` is passed to honor category semantics.

---

## 2. Invariants & Constraints
- Consult [`CONSTRAINTS.md`](../../CONSTRAINTS.md) and [`GLOSSARY.md`](../../GLOSSARY.md).
- Follow all boundaries in `AGENTS.md`: commit on a feature branch, push branch, open PR via `gh pr create`, no co-author trailers, and stop for isolated code review.
- Preserve backward compatibility for empty deep link invocations.

---

## 3. Plan & Implementation Steps
- [x] Create branch `fix/add-transaction-route-prefilled`
- [x] Update `processAddTransactionRouteFromParams` in `budget/lib/widgets/util/appLinks.dart`:
  - Determine if prefilled fields exist.
  - Set `startInitialAddTransactionSequence: false` when prefilled fields are present.
  - Set `selectedTitle: params["title"] ?? params["name"]`.
  - Set `selectedNotes: params["note"] ?? params["notes"]`.
  - Pass `useCategorySelectedIncome: true`.
  - Parse amount with sanitization for symbols/commas in `getAmountFromParams`.
  - Support `name` parameter in title-based category association in `getMainAndSubcategoryFromParams`.
- [x] Add unit / widget test in `budget/test/app_links_route_test.dart` verifying `processAddTransactionRouteFromParams` constructs `AddTransactionPage` with prefilled values and sequence disabled.
- [x] Commit, push branch, and open PR with `gh pr create` (PR #29).
- [x] Address code review findings:
  - Fix string interpolation syntax error on raw amount in `app_links_route_test.dart`.
  - Extract parameter resolution helpers (`getTitleFromParams`, `getNotesFromParams`, `getIncomeFromParams`) to resolve smells and empty string shadowing.
  - Pass `useCategorySelectedIncome: true` unconditionally.

---

## 4. Verification & Testing
- [ ] Automated tests pass
- [ ] Static analysis passes
- [ ] Format check passes
