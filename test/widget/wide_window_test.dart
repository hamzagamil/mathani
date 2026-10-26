import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';

/// The centred phone column on wide browser windows (specs/008 T025, FR-012, research R13).
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFF5F0E6)),
      builder: (context, child) => PhoneColumn(child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => const SizedBox(height: 200, child: Text('sheet')),
              ),
              child: Text('width ${MediaQuery.sizeOf(context).width.round()}'),
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('a wide window shows the app in a centred 480 px column', (tester) async {
    await pumpAt(tester, const Size(1440, 900));
    expect(find.text('width ${phoneColumnWidth.round()}'), findsOneWidget,
        reason: 'screens are told the screen is the column');
    final scaffold = tester.getRect(find.byType(Scaffold));
    expect(scaffold.width, phoneColumnWidth);
    expect(scaffold.center.dx, 720);
    final box = tester.widget<ColoredBox>(
        find.ancestor(of: find.byType(Center).first, matching: find.byType(ColoredBox)).first);
    expect(box.color, const Color(0xFFF5F0E6), reason: 'the theme background around it');
  });

  testWidgets('sheets open inside the column', (tester) async {
    await pumpAt(tester, const Size(1440, 900));
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.left, greaterThanOrEqualTo(720 - phoneColumnWidth / 2));
    expect(sheet.right, lessThanOrEqualTo(720 + phoneColumnWidth / 2));
  });

  testWidgets('a phone-width window is left as it is', (tester) async {
    await pumpAt(tester, const Size(400, 800));
    expect(find.text('width 400'), findsOneWidget);
    expect(tester.getRect(find.byType(Scaffold)).width, 400);
  });
}
