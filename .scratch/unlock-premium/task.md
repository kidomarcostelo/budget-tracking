# Task: Unlock Premium Features and Decouple Google Play Store Billing

**Issue Reference:** [#1](https://github.com/kidomarcostelo/budget-tracking/issues/1)  
**Status:** Ready For Agent  
**Assignee / Agent:** kidomarcostelo / AI Assistant  

---

## 1. Objective & Scope
- **Problem Statement:** Cashew upstream gates multiple budgets, multiple objectives, past budget history, and themes behind Google Play / Apple in-app purchases.
- **Expected Behavior:** All premium features are unlocked out-of-the-box for all users with zero paywall popups, and the app is decoupled from upstream Google Play Billing.

---

## 2. Invariants & Constraints
- Consult [`CONSTRAINTS.md`](../../CONSTRAINTS.md) and [`GLOSSARY.md`](../../GLOSSARY.md).
- Do not break existing user databases or local settings migrations.
- Ensure `flutter analyze` passes with 0 warnings.
- Keep the app completely offline-first.

---

## 3. Plan & Implementation Steps
- [ ] **Step 1: Set default unlock state**
  - Set default `"purchaseID": "lifetime_unlocked"` in `budget/lib/struct/defaultPreferences.dart`.
  - In `budget/lib/pages/premiumPage.dart`, update `hidePremiumPopup()` to return `true`.
- [ ] **Step 2: Neutralize paywall popups**
  - Update `premiumPopupBudgets`, `premiumPopupObjectives`, `premiumPopupPastBudgets`, and `premiumPopupAddTransaction` to return `true` immediately without pushing routes.
- [ ] **Step 3: Decouple Google Play Billing**
  - Disable Play Store purchase stream listeners in `budget/lib/pages/premiumPage.dart`.
  - Display lifetime unlocked status in the Premium settings view.
- [ ] **Step 4: Verification**
  - Verify `flutter analyze` and format check.

---

## 4. Verification & Testing
- [ ] Unit tests pass
- [ ] Static analysis passes: `flutter analyze`
- [ ] Code formatted: `dart format --output=none --set-exit-if-changed .`
- [ ] Manual check: verify budget and objective creation has no popup
