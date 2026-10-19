import 'package:budget/database/tables.dart';
import 'package:budget/pages/premiumPage.dart';
import 'package:budget/struct/defaultPreferences.dart';
import 'package:budget/struct/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Default Preferences & Lifetime Status', () {
    test('defaultPreferences sets purchaseID to lifetimeUnlockedPurchaseID',
        () async {
      final defaultPrefs = await getDefaultPreferences();
      expect(defaultPrefs['purchaseID'], lifetimeUnlockedPurchaseID);
    });

    test(
      'isLifetimePurchased recognizes lifetimeUnlockedPurchaseID and store ID',
      () {
        appStateSettings['purchaseID'] = lifetimeUnlockedPurchaseID;
        expect(isLifetimePurchased, isTrue);

        if (productIDs['lifetime'] != null) {
          appStateSettings['purchaseID'] = productIDs['lifetime'];
          expect(isLifetimePurchased, isTrue);
        }
      },
    );

    test('hidePremiumPopup always returns true', () {
      expect(hidePremiumPopup(), isTrue);
    });
  });

  group('Paywall Popups Neutralization', () {
    testWidgets(
      'all premium popups return true immediately without blocking',
      (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(home: Container()));
        final BuildContext context = tester.element(find.byType(Container));

        expect(await premiumPopupBudgets(context), isTrue);
        expect(await premiumPopupPastBudgets(context), isTrue);
        expect(await premiumPopupAddTransaction(context), isTrue);
        expect(await premiumPopupPushRoute(context), isTrue);
        expect(
          await premiumPopupObjectives(
            context,
            objectiveType: ObjectiveType.loan,
          ),
          isTrue,
        );
      },
    );
  });

  group('Google Play Billing Decoupling', () {
    test('store and premium popups are disabled by default', () {
      expect(tryStoreEnabled, isFalse);
      expect(premiumPopupEnabled, isFalse);
    });

    testWidgets(
      'initializeStoreAndPurchases returns empty map without store calls',
      (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(home: Container()));
        final BuildContext context = tester.element(find.byType(Container));

        final products = await initializeStoreAndPurchases(
          context: context,
          popRouteWithPurchase: false,
        );
        expect(products, isEmpty);
      },
    );

    testWidgets(
      'Products widget renders ManageSubscription directly',
      (WidgetTester tester) async {
        appStateSettings['purchaseID'] = lifetimeUnlockedPurchaseID;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Products(),
            ),
          ),
        );
        expect(find.byType(ManageSubscription), findsOneWidget);
      },
    );
  });
}
