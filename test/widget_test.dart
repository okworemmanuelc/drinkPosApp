// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:drink_pos_app/main.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BrewFlowApp());

    // Verify that the app bar title is displayed
    expect(find.text('BrewFlow POS'), findsOneWidget);

    // Verify that the floating action button is present
    expect(find.text('View Cart'), findsOneWidget);
  });
}
