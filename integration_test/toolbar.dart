import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Taps a reader toolbar button. In the Mushaf layout the controls hide while reading
/// (specs/002-print-like-mushaf-page), so the page is tapped first to bring them back.
Future<void> tapToolbar(WidgetTester tester, IconData icon) async {
  final button = find.byIcon(icon);
  if (button.hitTestable().evaluate().isEmpty) {
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
  }
  await tester.tap(button);
}
