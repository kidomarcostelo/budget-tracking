# Task: Colocate Test Suites with Library Subsystem Structure

**ID:** BT-8  
**Issue Reference:** [#14](https://github.com/kidomarcostelo/budget-tracking/issues/14)  
**Status:** Ready For Agent  
**Assignee / Agent:** kidomarcostelo / AI Assistant  

---

## 1. Objective & Scope
- **Problem Statement:** Test files are currently placed in a flat directory directly under `budget/test/` (e.g., `receipt_parser_test.dart`, `shared_receipt_processor_test.dart`, `share_intent_ocr_test.dart`, `premium_unlock_test.dart`, `widget_test.dart`). As the codebase grows, lack of colocation makes it harder to discover, maintain, and navigate tests corresponding to specific library subsystems.
- **Expected Behavior:** Tests are organized to cleanly mirror `budget/lib/` subsystems (e.g. `budget/test/struct/`, `budget/test/pages/`, `budget/test/widgets/`), establishing an intuitive colocation convention across the repository.

---

## 2. Invariants & Constraints
- Consult [`CONSTRAINTS.md`](../../CONSTRAINTS.md) and [`GLOSSARY.md`](../../GLOSSARY.md).
- Do not silence, skip, or delete any test assertions during restructuring.
- All test runs (`flutter test`) in CI and local environments must continue discovering and executing all tests across all subdirectories.
- Zero analysis warnings (`flutter analyze`) and strict formatting compliance (`dart format`).

---

## 3. Plan & Implementation Steps
- [ ] **Step 1: Define Target Colocation Hierarchy**
  - Map current flat tests to their respective subsystem directories:
    - `budget/test/receipt_parser_test.dart` → `budget/test/struct/receipt_parser_test.dart`
    - `budget/test/shared_receipt_processor_test.dart` → `budget/test/struct/shared_receipt_processor_test.dart`
    - `budget/test/share_intent_ocr_test.dart` → `budget/test/struct/share_intent_ocr_test.dart`
    - `budget/test/premium_unlock_test.dart` → `budget/test/pages/premium_page_test.dart`
    - `budget/test/widget_test.dart` → `budget/test/functions_test.dart` (or `budget/test/widgets/widget_smoke_test.dart`)
- [ ] **Step 2: Migrate & Move Test Files**
  - Relocate files to target subdirectories under `budget/test/`.
  - Fix any relative imports or file references.
- [ ] **Step 3: Tooling & CI Verification**
  - Ensure `.github/workflows/ci.yml` runs `flutter test` across all nested test folders.
  - Verify `flutter test` and `flutter analyze` exit with 0 errors.
- [ ] **Step 4: Update Architecture & Agent Guidelines**
  - Document the test colocation and folder structure rules in `docs/architecture.md` and `CONSTRAINTS.md`.

---

## 4. Verification & Testing
- [ ] All relocated tests run and pass: `flutter test`
- [ ] Static analysis passes: `flutter analyze`
- [ ] Code formatted: `dart format --output=none --set-exit-if-changed .`
- [ ] GitHub Actions CI Quality Gate passes
