// The Khatma screen (specs/014 Story 1, Story 4; contracts/khatma-ui-and-reminders.md › Screens).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/features/khatma/khatma_models.dart';
import 'package:mathani/features/khatma/khatma_screen.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';
import '../support/khatma_support.dart';

void main() {
  late ReaderController reader;
  late KhatmaController khatma;
  late DateTime now;

  Future<void> open(WidgetTester tester, {KhatmaPlan? start}) async {
    now = DateTime(2026, 3, 1, 9);
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    khatma = await openTestKhatma(tester, reader, now: () => now, start: start);
    setPhone(tester);
    await tester.pumpWidget(MathaniApp(controller: reader, khatma: khatma));
    await settleKhatma(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    khatma.dispose();
    await tester.pump(const Duration(seconds: 1));
    await settleKhatma(tester, 1);
  }

  Future<void> openScreen(WidgetTester tester) async {
    await tapToolbar(tester, MathaniIcons.khatma);
    await settleKhatma(tester);
    expect(find.byType(KhatmaScreen), findsOneWidget);
  }

  testWidgets('no khatma: one line and Start, nothing else to set up (Story 1, 1)',
      (tester) async {
    await open(tester);
    await openScreen(tester);
    expect(find.textContaining('Plan a complete reading'), findsOneWidget);
    expect(find.text('Start a khatma'), findsOneWidget);
    expect(find.text('Finished khatmas'), findsNothing);
    await close(tester);
  });

  testWidgets('a juz a day: 30 days before Start, then the wird card (Story 1, 2 and 5)',
      (tester) async {
    await open(tester);
    await openScreen(tester);
    await tester.tap(find.text('Start a khatma'));
    await settleKhatma(tester);
    expect(find.text('A juz a day'), findsOneWidget);
    expect(find.textContaining('30 days ·'), findsOneWidget, reason: 'the summary line');
    expect(find.textContaining('Mar 30, 2026'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start a khatma').last);
    await settleKhatma(tester);
    expect(khatma.wirds, hasLength(30));
    expect(find.textContaining('Wird 1 of 30'), findsOneWidget);
    expect(find.text('Al-Faatiha 1 to Al-Baqara 141'), findsOneWidget);
    expect(find.textContaining('Pages 1 to 21'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Read opens the Mushaf at the place; Done from the screen (Story 2, 9)',
      (tester) async {
    await open(tester, start: const MarksPlan(8));
    reader.jumpToPage(300);
    await settleKhatma(tester);
    await openScreen(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Done'));
    await settleKhatma(tester);
    expect(find.text("Today's wird is done"), findsWidgets);
    expect(khatma.currentWird!.number, 2);
    await tester.tap(find.text('Read now'));
    await settleKhatma(tester);
    expect(find.byType(KhatmaScreen), findsNothing);
    expect(reader.page, 22);
    await close(tester);
  });

  testWidgets('a start date three days ahead shows when it starts', (tester) async {
    await open(tester);
    await tester.runAsync(() => khatma.start(const MarksPlan(8),
        startAyah: 1, startDate: CalendarDay.of(now).addDays(3)));
    await openScreen(tester);
    expect(find.text('Starts on Mar 4, 2026'), findsOneWidget);
    await close(tester);
  });

  testWidgets('progress after missed days, two in a day, pause and end (Story 4)',
      (tester) async {
    await open(tester, start: const MarksPlan(8));
    // Wirds 1 to 3 read on earlier days, today is the sixth day.
    for (var d = 0; d < 3; d++) {
      now = DateTime(2026, 3, 1 + d, 9);
      await tester.runAsync(khatma.markRead);
    }
    now = DateTime(2026, 3, 6, 9);
    await openScreen(tester);
    expect(find.text('Wirds read: 3 of 30'), findsOneWidget);
    expect(find.textContaining('Expected finish Apr 1, 2026, 2 days after the planned date'),
        findsOneWidget);
    await tester.runAsync(khatma.markRead);
    await tester.runAsync(khatma.markRead);
    await settleKhatma(tester);
    expect(find.text('Wirds read: 5 of 30'), findsOneWidget);
    expect(find.textContaining('Expected finish Mar 31, 2026, 1 day after'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Pause'), 200);
    await tester.tap(find.text('Pause'));
    await settleKhatma(tester);
    expect(find.text('Paused since Mar 6, 2026'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('End khatma'), 200);
    await tester.tap(find.text('End khatma'));
    await settleKhatma(tester);
    expect(find.textContaining('bookmarks and reading position are kept'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'End khatma'));
    await settleKhatma(tester);
    expect(khatma.khatma, isNull);
    expect(find.text('Start a khatma'), findsOneWidget);
    await close(tester);
  });

  testWidgets('change plan opens the sheet from the place, with no start fields',
      (tester) async {
    await open(tester, start: const MarksPlan(8));
    await openScreen(tester);
    await tester.scrollUntilVisible(find.text('Change plan'), 200);
    await tester.tap(find.text('Change plan'));
    await settleKhatma(tester);
    expect(find.text('From page 1'), findsOneWidget);
    expect(find.text('Start from'), findsNothing);
    await close(tester);
  });
}
