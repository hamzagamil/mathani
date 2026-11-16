// The plan sheet shows the days, the daily pages and the finish date before Start (specs/014
// FR-002, Story 1 scenarios 2 to 4).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/features/khatma/khatma_models.dart';
import 'package:mathani/features/khatma/plan_sheet.dart';
import 'package:mathani/features/reader/reader_screen.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';
import '../support/khatma_support.dart';

void main() {
  late ReaderController reader;
  late KhatmaController khatma;
  PlanChoice? chosen;

  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    khatma = await openTestKhatma(tester, reader);
    setPhone(tester);
    await tester.pumpWidget(MathaniApp(controller: reader, khatma: khatma));
    await settleKhatma(tester);
    chosen = null;
    showPlanSheet(tester.element(find.byType(ReaderScreen)),
            controller: khatma, currentPage: 250)
        .then((c) => chosen = c);
    await settleKhatma(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    khatma.dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tapOption(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 120, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text(text));
    await settleKhatma(tester, 2);
  }

  testWidgets('each daily amount shows its days; a juz a day is 30', (tester) async {
    await open(tester);
    expect(find.text('30 days'), findsOneWidget); // beside "A juz a day"
    expect(find.text('60 days'), findsOneWidget); // a hizb
    expect(find.text('240 days'), findsOneWidget); // a quarter
    expect(find.textContaining('30 days · 20 to 23 pages a day · ends Mar 30, 2026'), findsOneWidget);
    await close(tester);
  });

  testWidgets('29 days: 20 or 21 pages a day', (tester) async {
    await open(tester);
    await tapOption(tester, 'Number of days');
    await tester.enterText(find.byType(TextField), '29');
    await settleKhatma(tester, 2);
    expect(find.textContaining('29 days · 20 to 21 pages a day · ends Mar 29, 2026'), findsOneWidget);
    await close(tester);
  });

  testWidgets('50 pages a day: 13 days of 46 or 47 pages', (tester) async {
    await open(tester);
    await tapOption(tester, 'Pages a day');
    await tester.enterText(find.byType(TextField), '50');
    await settleKhatma(tester, 2);
    expect(find.textContaining('13 days · 46 to 47 pages a day'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0');
    await settleKhatma(tester, 2);
    expect(find.text('Enter a number from 1 to 604.'), findsOneWidget);
    await close(tester);
  });

  testWidgets('from Juz 16: 15 days, for that part only (Story 1, 4)', (tester) async {
    await open(tester);
    await tapOption(tester, 'A juz');
    // The drop-down starts on Juz 1; choose Juz 16.
    await tester.tap(find.text('Juz 1').last);
    await settleKhatma(tester, 2);
    await tester.scrollUntilVisible(find.text('Juz 16'), 60,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Juz 16').last);
    await settleKhatma(tester, 2);
    expect(find.textContaining('15 days ·'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start a khatma'));
    await settleKhatma(tester, 2);
    expect(chosen?.plan, const MarksPlan(8));
    expect(chosen?.startAyah, khatma.index.juzStarts[15]);
    await close(tester);
  });

  testWidgets('from this page, starting on a later date', (tester) async {
    await open(tester);
    await tapOption(tester, 'This page (250)');
    expect(find.textContaining('18 days ·'), findsOneWidget);
    await close(tester);
  });
}
