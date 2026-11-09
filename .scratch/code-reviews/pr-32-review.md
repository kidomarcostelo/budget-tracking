# Code Review: PR #32

- **Target PR:** [#32](https://github.com/kidomarcostelo/budget-tracking/pull/32) (`fix/app-links-test-ci-hang` → `main`)
- **Commit:** `11ef3ca0 fix(test): resolve fakeAsync timeout and unmounted context in appLinks route tests`
- **Originating Spec:** PR #32 description (CI Quality Gate timeout / test stall fix)
- **Review Date:** 2026-11-09T15:34:30+08:00

---

## Standards

### Documented Standards Violations
None. The diff strictly complies with all documented repo standards:
- **`CONSTRAINTS.md` (Static Analysis & Code Cleanliness)**: Passes `flutter analyze` with 0 warnings/errors and conforms to `dart format`.
- **`CONSTRAINTS.md` (Suppression Ban & Test Integrity)**: No `// ignore:` directives or `@Skip` annotations added; fixes root cause rather than silencing tests.
- **`AGENTS.md` (Commit Author & Trailers)**: Authored by `kidomarcostelo@gmail.com` with conventional commit formatting and no `Co-authored-by` trailers.
- **`AGENTS.md` & `GLOSSARY.md` (Database Seams & Domain Vocabulary)**: Table seeding in tests uses standard Drift companions (`WalletsCompanion`, `CategoriesCompanion`) without raw SQL.

---

### Baseline Smells (Judgement Calls)

1. **Duplicated Code** — `budget/test/app_links_route_test.dart` (lines 197–237, 242–266, 272–290)
```dart
await tester.runAsync(() async {
  await tester.pumpWidget(buildTestApp(allWallets: allWallets));
  await tester.pumpAndSettle();
  final context = navigatorKey.currentContext!;
  await processAddTransactionRouteFromParams(context, { ... });
  await Future.delayed(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
  ...
  await popToHome(tester);
});
```
*Judgement Call*: The execution pattern (`runAsync`, widget pumping, context retrieval, 100ms delay, `pumpAndSettle`, and `popToHome`) is duplicated identically across all three route widget tests.
*Fix*: Extract a test helper (e.g. `testRouteParams(tester, params, assertion)`) or push `popToHome` cleanup into `tearDown`.

2. **Uncoordinated Asynchrony (Unawaited Delay)** — `budget/lib/widgets/util/appLinks.dart` (lines 344–363)
```dart
  // Add a delay so the keyboard can focus
  Future.delayed(const Duration(milliseconds: 50), () {
    pushRoute(
      context,
      AddTransactionPage(...),
    );
  });
```
*Judgement Call*: Dropping `await` on `Future.delayed` makes the delay fire-and-forget. Consequently, `processAddTransactionRouteFromParams` returns before the route is pushed, forcing tests to introduce arbitrary real-time delays (`Future.delayed(const Duration(milliseconds: 100))`) to observe navigation.
*Fix*: Await the delay but fire `pushRoute` without awaiting page dismissal (`await Future.delayed(const Duration(milliseconds: 50)); pushRoute(...);`).

---

## Spec

### (a) Missing or partial requirements

- **Spec:** `"provided popToHome teardown"`
  **Finding:** `popToHome(tester)` is implemented as a standalone helper invoked at the end of each test method body (`app_links_route_test.dart:236, 265, 289`), rather than inside a Flutter test `tearDown()` callback or `try/finally` block. If an assertion fails mid-test, `popToHome` does not run, leaving the route stack uncleared for subsequent tests.

---

### (b) Behaviour in the diff that wasn't asked for (scope creep)

- **Spec:** `"- Removed blocking await from pushRoute calls in budget/lib/widgets/util/appLinks.dart."`
  **Finding:** In `processAddTransactionRouteFromParams` (`appLinks.dart:344`), `await` was removed from `Future.delayed(...)` itself (`Future.delayed(const Duration(milliseconds: 50), () { pushRoute(...); });`). The spec only requested removing the blocking `await` on `pushRoute`, not making the delay timer fire-and-forget.

---

### (c) Requirements that look implemented but where the implementation looks wrong

- **Spec:** `"- Removed blocking await from pushRoute calls in budget/lib/widgets/util/appLinks.dart."`
  **Finding:** By dropping `await` on `Future.delayed` in `processAddTransactionRouteFromParams` (`appLinks.dart:344`), `await processAddTransactionRouteFromParams(context, params)` now completes immediately before the 50ms delay has elapsed and before `pushRoute` is executed. This detaches route creation from the method's lifecycle and forced the test suite to insert arbitrary real-time delays (`await Future.delayed(const Duration(milliseconds: 100))`) inside `tester.runAsync`. The intended fix was to await `Future.delayed` and invoke `pushRoute` without awaiting its route-pop completion.

---

## Summary

- **Standards:** 0 hard violations, 2 baseline smells (Worst: fire-and-forget `Future.delayed` in `appLinks.dart` causing uncoordinated asynchrony).
- **Spec:** 3 findings (Worst: dropping `await` on `Future.delayed` detaches route dispatch lifecycle from `processAddTransactionRouteFromParams`, forcing arbitrary real-time sleeps in tests).
