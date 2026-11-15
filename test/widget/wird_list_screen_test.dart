// The list of wirds (specs/014 FR-033, SC-008): lazy, each row with its range, pages and read
// date; a tap opens the wird's first page and does not move the khatma place.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/features/khatma/khatma_models.dart';
import 'package:mathani/features/khatma/wird_list_screen.dart';
import 'package:mathani/features/reader/reader_screen.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';
import '../support/khatma_support.dart';

void main() {
  testWidgets('a page a day: 604 rows built lazily, a tap opens the wird', (tester) async {
    late ReaderController reader;
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    final khatma = await openTestKhatma(tester, reader, start: const DaysPlan(604));
    await tester.runAsync(khatma.markRead);
    setPhone(tester);
    await tester.pumpWidget(MathaniApp(controller: reader, khatma: khatma));
    await settleKhatma(tester);
    Navigator.of(tester.element(find.byType(ReaderScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => const WirdListScreen()));
    await settleKhatma(tester);

    expect(khatma.wirds, hasLength(604));
    expect(find.byType(ListTile).evaluate().length, lessThan(30), reason: 'built lazily');
    expect(find.textContaining('Read Mar 1, 2026'), findsOneWidget);
    expect(find.textContaining('Current'), findsOneWidget);
    expect(find.textContaining('Not read'), findsWidgets);

    final place = khatma.khatma!.placePage;
    await tester.tap(find.textContaining('Wird 5 ·'));
    await settleKhatma(tester);
    expect(find.byType(WirdListScreen), findsNothing);
    expect(reader.page, 5);
    expect(khatma.khatma!.placePage, place);

    await tester.pumpWidget(const SizedBox());
    khatma.dispose();
    await tester.pump(const Duration(seconds: 2));
  });
}
