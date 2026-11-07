# Code Review Report: PR #29

- **Target PR:** [#29](https://github.com/kidomarcostelo/budget-tracking/pull/29) (`fix/add-transaction-route-prefilled` -> `main`)
- **Commit:** `69b2e945` (`fix(routing): prevent title wizard blocking and support aliases in addTransactionRoute`)
- **Originating Issue:** [#28](https://github.com/kidomarcostelo/budget-tracking/issues/28) / Task `BT-12`
- **Reviewed At:** 2026-11-07 15:50:00 (UTC+8)

---

## Standards

### (a) Documented Standards Violations
1. **Format Integrity & Parser Error (`CONSTRAINTS.md: §1`)** — `budget/test/app_links_route_test.dart:95`
   - **Violation:** In Dart string literals, an unescaped `$` introduces string interpolation. The test contains:
     ```dart
     expect(getAmountFromParams({'amount': ' $45.99 '}), equals(45.99));
     ```
     Because `$45` is not a valid identifier, this fails compilation and causes `dart format` to terminate with exit code 65:
     `line 95, column 48 of test/app_links_route_test.dart: Expected an identifier.`
     This violates `CONSTRAINTS.md: §1` ("Format Integrity: All Dart code must conform to `dart format`") and fails the repository CI Quality Gate. Fix with raw string `r' $45.99 '` or escaped `'\$45.99'`.

### (b) Baseline Smells (Judgement Calls)
1. **Duplicated Code / Data Clumps** — `budget/lib/widgets/util/appLinks.dart:348-356, 371-372, 645`
   Alias resolution and presence checks for `title`/`name` and `note`/`notes` are repeated across three separate sites in `appLinks.dart`:
   ```dart
   final bool hasPrefilledData = (params["title"] != null &&
           params["title"]!.trim().isNotEmpty) ||
       (params["name"] != null && params["name"]!.trim().isNotEmpty) ||
       ...
       (params["note"] != null && params["note"]!.trim().isNotEmpty) ||
       (params["notes"] != null && params["notes"]!.trim().isNotEmpty);
   ...
   selectedTitle: params["title"] ?? params["name"],
   selectedNotes: params["note"] ?? params["notes"],
   ...
   final String? titleForCategory = params["title"] ?? params["name"];
   ```
   *Heuristic:* Data Clump / Duplicated Code. Consider consolidating into small helper getters (e.g. `getTitleFromParams(params)`, `getNotesFromParams(params)`) or sanitizing aliases early upon route dispatch.

2. **Primitive Obsession** — `budget/lib/widgets/util/appLinks.dart:331-341`
   Inline type/income parsing operates directly on map strings inside the main routing handler:
   ```dart
   bool? selectedIncome;
   if (params.containsKey("income")) {
     selectedIncome = params["income"]?.toLowerCase() == "true" ||
         params["income"] == "1";
   } else if (params.containsKey("type")) {
     if (params["type"]?.toLowerCase() == "income") {
       selectedIncome = true;
     } else if (params["type"]?.toLowerCase() == "expense") {
       selectedIncome = false;
     }
   }
   ```
   *Heuristic:* Primitive Obsession. Consider extracting to a helper function `getIncomeTypeFromParams(params)` alongside existing parameter extractors like `getAmountFromParams` and `getDateTimeFromParams`.

---

## Spec

### (a) Requirements Missing or Partial
1. **Conditional `useCategorySelectedIncome`**
   - *Spec line*: `"4. useCategorySelectedIncome: true is passed so category income/expense semantics are preserved."`
   - *Observation*: Rather than unconditionally setting `useCategorySelectedIncome: true`, the diff sets `useCategorySelectedIncome: selectedIncome == null`. When `income` or `type` is present, `useCategorySelectedIncome` evaluates to `false`, which only partially satisfies the requirement.

### (b) Behaviour in the Diff Not Asked For (Scope Creep)
1. **Support for `income` and `type` Parameters** (`budget/lib/widgets/util/appLinks.dart:331-341`):
   - The diff adds logic parsing `income` (`true`/`1`) and `type` (`income`/`expense`), passing `selectedIncome` to `AddTransactionPage`. Neither Issue #28 nor `task.md` requested query-parameter-based income/expense overrides.
2. **Deep Link Query Parameter `startInitialAddTransactionSequence`** (`budget/lib/widgets/util/appLinks.dart:343-347`):
   - Lines 343–347 parse `params["startInitialAddTransactionSequence"]`.
   - *Spec line*: `"1. startInitialAddTransactionSequence: false is passed when prefilled data is present..."`
   - The specification asked for internal bypass logic when prefilled data exists, not exposing an external query parameter to control the wizard.
3. **Amount Currency Sanitization in `getAmountFromParams`** (`budget/lib/widgets/util/appLinks.dart:539-543`):
   - Added regex stripping (`replaceAll(RegExp(r'[^0-9.-]'), '')`) to strip currency symbols and commas. While helpful, this modifies a shared helper across all deep links and was not specified in Issue #28.

### (c) Requirements Look Implemented but Look Wrong
1. **Empty String Fallback in Alias Resolution** (`budget/lib/widgets/util/appLinks.dart:371-372`):
   - *Spec lines*:
     - `"2. selectedNotes accepts both params["note"] and params["notes"]."`
     - `"3. selectedTitle accepts both params["title"] and params["name"]."`
   - *Observation*: The implementation uses simple null-coalescing: `params["title"] ?? params["name"]` and `params["note"] ?? params["notes"]`. If an empty string is passed (e.g., `?note=&notes=Lunch`), the non-null empty string takes precedence over the valid fallback alias (unlike `hasPrefilledData`, which checks `trim().isNotEmpty`).

---

## Summary

- **Standards:** 1 hard violation (Dart syntax/format parser error in test breaking CI), 2 baseline smells (Duplicated Code/Data Clumps, Primitive Obsession). Worst issue: unescaped `$` syntax error on line 95 in `budget/test/app_links_route_test.dart`.
- **Spec:** 1 partial requirement (`useCategorySelectedIncome`), 3 scope creep items (`income`/`type` params, `startInitialAddTransactionSequence` query param, amount regex sanitization), 1 wrong edge-case implementation (empty-string alias precedence). Worst issue: empty string in primary param (`?note=&notes=...`) shadowing valid alias value.
