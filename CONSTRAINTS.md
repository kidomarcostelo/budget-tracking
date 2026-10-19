# Constraints

Quality bar contract for `budget-tracking`. These constraints are non-negotiable rules that all human and AI contributors must satisfy before merging changes.

---

## 1. Static Analysis & Code Cleanliness

- **Zero Tolerance on Analysis Errors/Warnings:** `flutter analyze` in `budget/` must exit with return code `0` (no errors, no warnings).
- **Format Integrity:** All Dart code must conform to `dart format`. Check with `dart format --output=none --set-exit-if-changed .` inside `budget/`.
- **Suppression Ban:** Adding `// ignore:` or `// ignore_for_file:` is strictly prohibited unless an unfixable compiler/library bug occurs. Any suppression must include an explanatory comment with issue link.

---

## 2. Database & Data Safety Invariants

- **Immutable Migration History:** Never edit past schema version functions in `budget/lib/database/schema_versions.dart` or files in `budget/drift_schemas/`.
- **Atomic Schema Evolution:** Every schema change must:
  1. Increment the database schema version.
  2. Implement an explicit step-by-step forward migration.
  3. Regenerate `tables.g.dart` using `dart run build_runner build --delete-conflicting-outputs`.
- **Data Preservation:** User data must never be wiped or truncated during migrations. Destructive operations (dropping columns/tables) require backwards-compatible deprecation.

---

## 3. Test Suite Integrity

- **No Silencing Failing Tests:** Never comment out, delete, or add `@Skip` annotations to failing tests to achieve a passing state. Fix the root cause in the implementation or test setup.
- **Regression Tests for Bugs:** Every non-trivial bug fix must include a test asserting the bug scenario and proving the fix.

---

## 4. Security & Sensitive Data

- **No Hardcoded Secrets:** Never commit API keys, Firebase service account keys, OAuth client secrets, or user tokens.
- **Offline Safety:** Core features must function without external network access or mandatory sign-ins.

---

## 5. Verification Checklist

Before completing any task or opening a pull request, run:
```bash
cd budget
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```
All commands must pass without failures.
