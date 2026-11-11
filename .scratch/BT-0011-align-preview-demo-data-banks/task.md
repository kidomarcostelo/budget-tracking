# Task: Align preview demo data with user banks (UnionBank, MariBank, GoTyme, Maya)

**ID:** BT-0011  
**Issue Reference:** [#27](https://github.com/kidomarcostelo/budget-tracking/issues/27)  
**Status:** In Review  
**Assignee / Agent:** kidomarcostelo / AI Assistant  

---

## 1. Objective & Scope
- **Problem Statement:** The built-in preview demo data generator in `budget/lib/database/generatePreviewData.dart` creates generic placeholder wallets ("Bank" in USD, "Euros", "Bitcoin") and USD/EUR-denominated transactions.
- **Expected Behavior:** Demo data generation seeds realistic Philippine banking institutions (**UnionBank**, **MariBank**, **GoTyme**, **Maya**) with **PHP** currency, representative budgets/objectives in Philippine Peso scale, verified real-world transaction patterns (Grab, Shopee, 7-Eleven, Mercury Drug, Meralco, salary crediting, inter-bank InstaPay transfers), default account owner name "Kid Omar Costelo", and reliable teardown via `deletePreviewData()`.

---

## 2. Invariants & Constraints
- Consult [`CONSTRAINTS.md`](../../CONSTRAINTS.md) and [`GLOSSARY.md`](../../GLOSSARY.md).
- All preview transactions must have `methodAdded: MethodAdded.preview` so `deletePreviewData()` cleanly purges them.
- All wallets, budgets, and objectives created for preview must be cleanly deleted in `deletePreviewData()` (`"10"`, `"11"`, `"12"` wallets, `"10"`, `"11"` budgets/objectives) and primary wallet `"0"` restored to default.
- Zero analysis errors (`flutter analyze`) and strict code formatting (`dart format`).

---

## 3. Plan & Implementation Steps
- [x] Step 1: Update wallet configurations in `generatePreviewData.dart` to UnionBank (`0`), MariBank (`10`), GoTyme (`11`), and Maya (`12`) with brand colors and `currency: "php"`.
- [x] Step 2: Update `deletePreviewData()` to cleanly remove all 4 wallets (`"10"`, `"11"`, `"12"`) and reset `accountOwnerName` and preview demo flag.
- [x] Step 3: Configure settings in `generatePreviewData()`: `accountOwnerName = "Kid Omar Costelo"`.
- [x] Step 4: Scale budgets and objectives to typical PHP amounts (₱25k/₱35k budgets, ₱50k emergency fund, ₱20k category limits).
- [x] Step 5: Replace generic transactions with Philippine bank fixture samples (7-Eleven, Starbucks, Grab, Shopee, Mercury Drug, Meralco, Converge, Netflix subscription, monthly salary, and inter-bank InstaPay transfers).
- [x] Step 6: Add automated unit/integration tests in `budget/test/preview_data_test.dart` for `generatePreviewData()` and `deletePreviewData()` verifying seed integrity and clean teardown.

---

## 4. Verification & Testing
- [x] Unit / Integration test for preview data generation and teardown (`budget/test/preview_data_test.dart`).
- [x] Static analysis passes: `flutter analyze` (0 issues).
- [x] Code formatted: `dart format --output=none --set-exit-if-changed .` (100% compliant).
- [x] Test suite passes: `flutter test` (156 / 156 tests passing).
