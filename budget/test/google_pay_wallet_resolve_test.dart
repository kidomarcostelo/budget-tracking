// Regression test: GooglePayParser.resolveWallet wallet resolution specificity
//
// BUG:
//   When a Google Pay notification contains card name "UnionBank Visa Platinum",
//   and the user has both a "UnionBank" wallet and a "UnionBank Visa Platinum" wallet,
//   resolveWallet must prefer "UnionBank Visa Platinum" (the most specific match).
//
//   The current token-split fallback does NOT guarantee this:
//     - getRelatingWallet("UnionBank Visa Platinum") works when EXACT wallet exists ✓
//     - BUT: when card name has no exact wallet (e.g. "UnionBank Visa Platinum" → misspelled
//       or casing mismatch), tokens ["UnionBank", "Visa", "Platinum"] are iterated.
//       "UnionBank" token finds "UnionBank" wallet immediately → returns before checking
//       if "UnionBank Visa Platinum" is a better match.
//
// ROOT CAUSE:
//   resolveWallet's token-split fallback (googlePayParser.dart L188–194) calls
//   getRelatingWallet(token) for each token in left-to-right order. The first token
//   to hit ANY wallet match (via LIKE %token%) is returned. This ignores:
//     1. Whether a longer wallet name contains the FULL cardName as a prefix.
//     2. Whether multiple tokens together form a more specific wallet match.
//   The result is first-token-wins, which is biased toward shorter/earlier tokens.
//
// FIX DIRECTION:
//   After the full-name and last-4 passes, instead of iterating tokens left-to-right
//   and returning on first hit, collect ALL wallets whose names are contained in the
//   full cardName string, then return the one with the LONGEST name match.
//   This "longest contained name" strategy is already partially used in
//   sharedReceiptProcessor.resolveWalletByName (L123–129) but without longest-first ordering.
//
// TIGHT FEEDBACK LOOP COMMAND (run from budget/):
//   flutter test test/google_pay_wallet_resolve_test.dart
import 'package:budget/database/tables.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/defaultPreferences.dart';
import 'package:budget/struct/googlePayParser.dart';
import 'package:budget/struct/settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
  });

  group('resolveWallet – wallet specificity regression', () {
    late FinanceDatabase testDb;

    setUp(() async {
      testDb = FinanceDatabase(NativeDatabase.memory());
      database = testDb;
      final defaults = await getDefaultPreferences();
      appStateSettings.clear();
      appStateSettings.addAll(defaults);
      appStateSettings['selectedWalletPk'] = '-1';
    });

    tearDown(() async {
      await testDb.close();
    });

    Future<void> seedWallet(
        {required String pk, required String name, required int order}) async {
      await testDb.createOrUpdateWallet(TransactionWallet(
        walletPk: pk,
        name: name,
        colour: null,
        dateCreated: DateTime(2026, 1, 1),
        order: order,
        currency: 'PHP',
        decimals: 2,
      ));
    }

    // ── Case 1: Exact wallet exists – must always work ────────────────────
    test(
      'full card name has an exact wallet match – resolves correctly',
      () async {
        await seedWallet(pk: 'ub', name: 'UnionBank', order: 0);
        await seedWallet(pk: 'ubvp', name: 'UnionBank Visa Platinum', order: 1);

        final result = GooglePayParser.parse(
          '7-Eleven',
          'P500.00 with UnionBank Visa Platinum **1234',
        );
        expect(result?.cardName, equals('UnionBank Visa Platinum'));

        final wallet = await GooglePayParser.resolveWallet(result!);
        expect(wallet?.name, equals('UnionBank Visa Platinum'));
      },
    );

    // ── Case 2 (PRIMARY BUG): Card name case/spacing mismatch → token-split ──
    // When getRelatingWallet(cardName) exact match fails (e.g. user named their
    // wallet "Unionbank Visa Platinum" with lowercase 'b'), the token-split fires.
    // Token "Unionbank" matches "UnionBank" (via case-insensitive LIKE) → wrong.
    test(
      '[BUG] card name casing mismatch triggers token-split; '
      '"Unionbank" token wins over "Unionbank Visa Platinum" wallet',
      () async {
        // User's wallet has lowercase "nk" — common typo/style
        await seedWallet(pk: 'ub', name: 'UnionBank', order: 0);
        await seedWallet(pk: 'ubvp', name: 'Unionbank Visa Platinum', order: 1);

        // Notification card: "UnionBank Visa Platinum" (official casing)
        final result = GooglePayParser.parse(
          '7-Eleven',
          'P500.00 with UnionBank Visa Platinum **1234',
        );
        expect(result?.cardName, equals('UnionBank Visa Platinum'));

        final wallet = await GooglePayParser.resolveWallet(result!);

        // BEFORE FIX:
        //   getRelatingWallet("UnionBank Visa Platinum") — exact miss (case diff)
        //   → case-insensitive pass: "UnionBank Visa Platinum".lower() == "unionbank visa platinum"
        //     matches "Unionbank Visa Platinum".lower() == "unionbank visa platinum" ← PASS! Actually passes.
        //   So this may work. The real failure is below.
        //
        // This test documents that case-insensitive match protects the full-name path.
        expect(wallet?.name, equals('Unionbank Visa Platinum'));
      },
    );

    // ── Case 3 (DEFINITIVE BUG): Partial-name wallet vs token collision ────
    // User has "UnionBank" wallet AND "UnionBank Visa" wallet.
    // Card name: "UnionBank Visa Platinum" (no exact match for "UnionBank Visa Platinum").
    // Token "UnionBank" fires first → picks "UnionBank" over "UnionBank Visa".
    // After fix: should pick "UnionBank Visa" (longest contained name).
    test(
      '[BUG] when no exact wallet match exists, token-split picks first token match '
      'instead of the longest-name partial match — "UnionBank" wins over "UnionBank Visa"',
      () async {
        await seedWallet(pk: 'ub', name: 'UnionBank', order: 0);
        await seedWallet(pk: 'ubv', name: 'UnionBank Visa', order: 1);
        // No "UnionBank Visa Platinum" wallet — closest is "UnionBank Visa"

        final result = GooglePayParser.parse(
          '7-Eleven',
          'P500.00 with UnionBank Visa Platinum **1234',
        );
        expect(result?.cardName, equals('UnionBank Visa Platinum'));

        final wallet = await GooglePayParser.resolveWallet(result!);

        // BEFORE FIX:
        //   getRelatingWallet("UnionBank Visa Platinum") → null (no exact/LIKE match)
        //   tokens: ["UnionBank", "Visa", "Platinum"]
        //   getRelatingWallet("UnionBank") → "UnionBank" (exact) → RETURNS "UnionBank"
        //   "UnionBank Visa" is never reached.
        //
        // AFTER FIX (longest-contained-name strategy):
        //   Collect all wallets whose names are substrings of "UnionBank Visa Platinum":
        //     "UnionBank" ∈ "UnionBank Visa Platinum" ✓
        //     "UnionBank Visa" ∈ "UnionBank Visa Platinum" ✓
        //   Sort by name length DESC: ["UnionBank Visa" (14), "UnionBank" (9)]
        //   Return "UnionBank Visa" (longest match).
        expect(
          wallet?.name,
          equals('UnionBank Visa'),
          reason:
              'resolveWallet should prefer "UnionBank Visa" (14 chars, longer match) '
              'over "UnionBank" (9 chars) when both are contained in "UnionBank Visa Platinum".',
        );
      },
    );

    // ── Case 4: Last-4 digits priority (must not regress) ─────────────────
    test(
      'cardLast4 lookup takes highest priority over name matching',
      () async {
        await seedWallet(pk: 'ub', name: 'UnionBank', order: 0);
        await seedWallet(pk: 'ubvp', name: 'UnionBank Visa Platinum', order: 1);
        // Add a wallet whose name IS the last-4 digits (simulates named-by-account)
        await seedWallet(pk: 'card-1234', name: '1234', order: 5);

        final result = GooglePayParser.parse(
          '7-Eleven',
          'P500.00 with UnionBank Visa Platinum **1234',
        );
        expect(result?.cardLast4, equals('1234'));

        final wallet = await GooglePayParser.resolveWallet(result!);
        // cardLast4 "1234" → exact match on wallet "1234" → returned first
        expect(wallet?.name, equals('1234'));
      },
    );

    // ── Case 5: Fallback to default wallet (must not regress) ─────────────
    test(
      'falls back to selectedWalletPk when no name match found',
      () async {
        await seedWallet(pk: 'cash', name: 'Cash', order: 0);
        appStateSettings['selectedWalletPk'] = 'cash';

        final result = GooglePayParser.parse(
          'Grab',
          'P99.00 with Mastercard •••• 0001',
        );
        expect(result?.cardName, equals('Mastercard'));

        final wallet = await GooglePayParser.resolveWallet(result!);
        // "Mastercard" has no matching wallet; fallback to selected wallet "Cash"
        expect(wallet?.name, equals('Cash'));
      },
    );
  });
}
