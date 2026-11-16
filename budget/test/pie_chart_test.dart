import 'dart:math';
import 'dart:ui';
import 'package:budget/database/tables.dart';
import 'package:budget/widgets/pieChart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TransactionCategory createTestCategory({
    required String pk,
    required String name,
    String? colour,
  }) {
    return TransactionCategory(
      categoryPk: pk,
      name: name,
      colour: colour ?? '0xffff0000',
      dateCreated: DateTime(2025, 1, 1),
      order: 0,
      income: false,
    );
  }

  group('getSpendingHeatmapColor', () {
    test('returns coral red when totalCount is 0 or 1', () {
      final color0 = getSpendingHeatmapColor(0, 0);
      final color1 = getSpendingHeatmapColor(0, 1);
      final colorLargeIndex = getSpendingHeatmapColor(5, 1);

      expect(color0, equals(const Color(0xFFFF6B6B)));
      expect(color1, equals(const Color(0xFFFF6B6B)));
      expect(colorLargeIndex, equals(const Color(0xFFFF6B6B)));
    });

    test('generates 2-step gradient from hue 0 to hue 165', () {
      final colorFirst = getSpendingHeatmapColor(0, 2);
      final colorLast = getSpendingHeatmapColor(1, 2);

      final hsvFirst = HSVColor.fromColor(colorFirst);
      final hsvLast = HSVColor.fromColor(colorLast);

      expect(hsvFirst.hue, closeTo(0.0, 0.001));
      expect(hsvLast.hue, closeTo(165.0, 0.001));
    });

    test('generates strictly monotonically increasing hues across rank', () {
      const int count = 6;
      final hues = <double>[];

      for (int i = 0; i < count; i++) {
        final color = getSpendingHeatmapColor(i, count);
        final hsv = HSVColor.fromColor(color);
        hues.add(hsv.hue);
      }

      expect(hues.first, closeTo(0.0, 0.001));
      expect(hues.last, closeTo(165.0, 0.001));

      for (int i = 1; i < count; i++) {
        expect(hues[i], greaterThan(hues[i - 1]));
      }
    });

    test('clamps index within bounds [0, totalCount - 1]', () {
      const int count = 4;
      final colorNegative = getSpendingHeatmapColor(-2, count);
      final colorZero = getSpendingHeatmapColor(0, count);
      final colorOverflow = getSpendingHeatmapColor(99, count);
      final colorLast = getSpendingHeatmapColor(3, count);

      expect(colorNegative, equals(colorZero));
      expect(colorOverflow, equals(colorLast));
    });
  });

  group('resolveCalloutCollisions', () {
    test('handles empty list gracefully', () {
      final list = <CalloutCandidate>[];
      expect(
          () => resolveCalloutCollisions(list, 10, 200, 28), returnsNormally);
      expect(list, isEmpty);
    });

    test('clamps single candidate within minY and maxY', () {
      final candidateTop = CalloutCandidate(
        index: 0,
        categoryName: 'Test',
        percent: 50.0,
        color: Colors.red,
        midAngleRad: 0.0,
        slicePoint: const Offset(100, 5),
        isRight: true,
      );

      resolveCalloutCollisions([candidateTop], 20, 200, 28);
      expect(candidateTop.targetY, equals(20.0));

      final candidateBottom = CalloutCandidate(
        index: 0,
        categoryName: 'Test',
        percent: 50.0,
        color: Colors.red,
        midAngleRad: 0.0,
        slicePoint: const Offset(100, 250),
        isRight: true,
      );
      resolveCalloutCollisions([candidateBottom], 20, 200, 28);
      expect(candidateBottom.targetY, equals(200.0));
    });

    test('resolves overlapping candidates by maintaining minimum spacing', () {
      final c1 = CalloutCandidate(
        index: 0,
        categoryName: 'Cat 1',
        percent: 40.0,
        color: Colors.red,
        midAngleRad: 0.0,
        slicePoint: const Offset(100, 50),
        isRight: true,
      );
      final c2 = CalloutCandidate(
        index: 1,
        categoryName: 'Cat 2',
        percent: 30.0,
        color: Colors.orange,
        midAngleRad: 0.1,
        slicePoint: const Offset(100, 52),
        isRight: true,
      );
      final c3 = CalloutCandidate(
        index: 2,
        categoryName: 'Cat 3',
        percent: 20.0,
        color: Colors.yellow,
        midAngleRad: 0.2,
        slicePoint: const Offset(100, 55),
        isRight: true,
      );

      const double minSpacing = 28.0;
      resolveCalloutCollisions([c1, c2, c3], 10, 300, minSpacing);

      expect(c2.targetY - c1.targetY, greaterThanOrEqualTo(minSpacing - 0.001));
      expect(c3.targetY - c2.targetY, greaterThanOrEqualTo(minSpacing - 0.001));
      expect(c1.targetY, greaterThanOrEqualTo(10.0));
      expect(c3.targetY, lessThanOrEqualTo(300.0));
    });

    test('preserves relative order between candidates', () {
      final candidates = List.generate(
        5,
        (i) => CalloutCandidate(
          index: i,
          categoryName: 'Cat $i',
          percent: 20.0,
          color: Colors.blue,
          midAngleRad: i * 0.1,
          slicePoint: Offset(100, 40.0 + i * 2.0),
          isRight: false,
        ),
      );

      resolveCalloutCollisions(candidates, 10, 300, 25.0);

      for (int i = 1; i < candidates.length; i++) {
        expect(candidates[i].targetY, greaterThan(candidates[i - 1].targetY));
      }
    });
  });

  group('PieChartCalloutPainter', () {
    test('suppresses callouts for slices with percent < 1.0%', () {
      final catBig = createTestCategory(pk: 'cat-1', name: 'Rent');
      final catSmall = createTestCategory(pk: 'cat-2', name: 'Coffee');
      final catTiny = createTestCategory(pk: 'cat-3', name: 'Gum');

      // Total spent = 1000
      // Rent: 900 (90%) -> callout
      // Coffee: 95 (9.5%) -> callout
      // Gum: 5 (0.5%) -> suppressed (< 1%)
      final data = [
        CategoryWithTotal(category: catBig, total: 900),
        CategoryWithTotal(category: catSmall, total: 95),
        CategoryWithTotal(category: catTiny, total: 5),
      ];

      final painter = PieChartCalloutPainter(
        data: data,
        totalSpent: 1000,
        touchedIndex: -1,
        pieRadius: 66,
        textColor: Colors.black,
        subtextColor: Colors.grey,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(320, 220);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('shouldRepaint returns true when properties change', () {
      final cat = createTestCategory(pk: 'cat-1', name: 'Rent');
      final data = [CategoryWithTotal(category: cat, total: 100)];

      final painter1 = PieChartCalloutPainter(
        data: data,
        totalSpent: 100,
        touchedIndex: -1,
        pieRadius: 66,
        textColor: Colors.black,
        subtextColor: Colors.grey,
      );

      final painter2 = PieChartCalloutPainter(
        data: data,
        totalSpent: 100,
        touchedIndex: 0,
        pieRadius: 66,
        textColor: Colors.black,
        subtextColor: Colors.grey,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });
  });

  group('PieChartWrapper Widget', () {
    testWidgets('renders empty placeholder when data is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PieChartWrapper(
              data: const [],
              totalSpent: 0,
              setSelectedCategory: (pk, cat) {},
              pieChartDisplayStateKey: GlobalKey(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(PieChartDisplay), findsNothing);
    });

    testWidgets('renders PieChartDisplay when non-zero categories exist',
        (WidgetTester tester) async {
      final cat = createTestCategory(pk: 'cat-1', name: 'Groceries');
      final data = [CategoryWithTotal(category: cat, total: 500)];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PieChartWrapper(
              data: data,
              totalSpent: 500,
              setSelectedCategory: (pk, cat) {},
              pieChartDisplayStateKey: GlobalKey(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(PieChartDisplay), findsOneWidget);
    });
  });
}
