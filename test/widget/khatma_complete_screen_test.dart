// Finishing a personal khatma and its record (specs/014 Story 8).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/features/khatma/khatma_complete_screen.dart';
import 'package:mathani/features/khatma/khatma_models.dart';
import 'package:mathani/features/khatma/khatma_screen.dart';
import 'package:mathani/features/khatma/plan_sheet.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';
import '../support/khatma_support.dart';

void main() {
  testWidgets('complete, Undo, the record, a new khatma with the same plan, delete',
      (tester) async {
    late ReaderController reader;
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    final khatma = await openTestKhatma(tester, reader, start: const DaysPlan(1));
    setPhone(tester);
    await tester.pumpWidget(MathaniApp(controller: reader, khatma: khatma));
    await settleKhatma(tester);
    await tapToolbar(tester, MathaniIcons.khatma);
    await settleKhatma(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Done'));
    await settleKhatma(tester);
    expect(find.byType(KhatmaCompleteScreen), findsOneWidget);
    expect(find.text('The khatma is complete'), findsOneWidget);
    expect(find.textContaining('Mar 1, 2026 to Mar 1, 2026 · 1 day'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settleKhatma(tester);
    expect(find.byType(KhatmaCompleteScreen), findsNothing);
    expect(khatma.khatma, isNotNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Done'));
    await settleKhatma(tester);
    await tester.tap(find.text('Close'));
    await settleKhatma(tester);
    expect(find.byType(KhatmaScreen), findsOneWidget);
    expect(find.text('1 khatma finished'), findsOneWidget);

    // Start a new khatma: the previous plan is selected.
    await tester.tap(find.widgetWithText(FilledButton, 'Start a new khatma'));
    await settleKhatma(tester);
    final sheet = tester.widget<PlanSheet>(find.byType(PlanSheet));
    expect(sheet.initial, const DaysPlan(1));
    Navigator.of(tester.element(find.byType(PlanSheet))).pop();
    await settleKhatma(tester);

    await tester.tap(find.byIcon(MathaniIcons.delete));
    await settleKhatma(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await settleKhatma(tester);
    expect(khatma.record, isEmpty);
    expect(find.text('Finished khatmas'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    khatma.dispose();
    await tester.pump(const Duration(seconds: 2));
  });
}
