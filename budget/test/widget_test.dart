import 'package:budget/functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('String extension tests', () {
    test('capitalizeFirst capitalizes the first character', () {
      expect('cashew'.capitalizeFirst, 'Cashew');
      expect(''.capitalizeFirst, '');
    });

    test('capitalizeFirstofEach capitalizes each word', () {
      expect('hello world'.capitalizeFirstofEach, 'Hello World');
    });
  });

  testWidgets('Smoke test renders basic widget tree',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Cashew'),
        ),
      ),
    );

    expect(find.text('Cashew'), findsOneWidget);
  });
}
