## Summary

When a Google Pay payment notification arrives with a multi-token card name such as `"UnionBank Visa Platinum"`, and the user has multiple matching wallets (e.g., generic `"UnionBank"` and specific `"UnionBank Visa"` or `"UnionBank Visa Platinum"`), `resolveWallet` in `GooglePayParser` was matching the generic `"UnionBank"` wallet due to a first-token-wins loop (`for (final token in tokens)`).

This PR fixes the wallet resolution order:
1. Exact or LIKE match via `database.getRelatingWallet(result.cardName!)` is attempted first.
2. Contained-name matching via `_resolveByLongestContainedName` scans all wallets and prefers the wallet whose name is the longest substring of `cardName` (e.g. `"UnionBank Visa"` [14 chars] is preferred over `"UnionBank"` [9 chars] for card `"UnionBank Visa Platinum"`).
3. The same longest-match preference is applied to `SharedReceiptProcessor.resolveWalletByName` to ensure consistent resolution behavior across notification and receipt scanning.

## Changes

- **`budget/lib/struct/googlePayParser.dart`**:
  - Added `_resolveByLongestContainedName(String cardName)` to pick the longest matching wallet contained within the card name string.
  - Replaced the token-split loop in `resolveWallet` with `_resolveByLongestContainedName`.
- **`budget/lib/struct/sharedReceiptProcessor.dart`**:
  - Updated `resolveWalletByName` contained-name scan to track and return the longest matching wallet name instead of the first encountered match.
- **`budget/test/google_pay_wallet_resolve_test.dart`**:
  - Added 5 regression tests covering exact match, casing mismatch, partial name specificity (`UnionBank Visa` vs `UnionBank`), `cardLast4` priority, and fallback to `selectedWalletPk`.
- **`budget/test/shared_receipt_processor_test.dart`**:
  - Added unit test asserting `resolveWalletByName` selects the longest matching wallet.

## Verification

All tests pass cleanly:
- `flutter test test/google_pay_wallet_resolve_test.dart` (5/5 passed)
- `flutter test test/shared_receipt_processor_test.dart` (6/6 passed)
- `flutter test test/google_pay_parser_test.dart` (10/10 passed)
- `flutter test test/google_pay_flow_widget_test.dart` (10/10 passed)
- `flutter test test/notification_dispatcher_test.dart` (18/18 passed)
- `flutter analyze`: No issues found
- `dart format --output=none --set-exit-if-changed .`: Formatted 282 files (0 changed)

## Type of Change
- Two-way door: algorithmic improvement to wallet resolution precedence, non-breaking and backwards-compatible with existing wallet names and preferences.
