// "Set khatma place here" in the long-press sheet (specs/014 FR-017, Story 2 scenarios 6 and 7).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/features/khatma/khatma_models.dart';
import 'package:mathani/features/reader/ayah_actions.dart';
import 'package:mathani/features/reader/reader_screen.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';
import '../support/khatma_support.dart';

void main() {
  late ReaderController reader;
  late KhatmaController khatma;

  Future<void> open(WidgetTester tester, {KhatmaPlan? start}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    khatma = await openTestKhatma(tester, reader, start: start);
    setPhone(tester);
    await tester.pumpWidget(MathaniApp(controller: reader, khatma: khatma));
    await settleKhatma(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    khatma.dispose();
    await tester.pump(const Duration(seconds: 2));
  }

  AyahRef refOf(int id) => reader.quran.ayahById(id).ref;

  Future<void> setPlace(WidgetTester tester, AyahRef ref, {required String counts}) async {
    showAyahActions(tester.element(find.byType(ReaderScreen)), ref);
    await settleKhatma(tester, 2);
    await tester.tap(find.text('Set khatma place here'));
    await settleKhatma(tester, 2);
    expect(find.textContaining(counts), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await settleKhatma(tester);
  }

  testWidgets('not offered without a khatma', (tester) async {
    await open(tester);
    showAyahActions(tester.element(find.byType(ReaderScreen)), const AyahRef(2, 255));
    await settleKhatma(tester, 2);
    expect(find.text('Set khatma place here'), findsNothing);
    await close(tester);
  });

  testWidgets('Juz 10, then Juz 5', (tester) async {
    await open(tester, start: const MarksPlan(8));
    await setPlace(tester, refOf(khatma.index.juzStarts[9] + 3),
        counts: 'Wirds that become read: 9. Wirds that become not read: 0.');
    expect(khatma.currentWird!.number, 10);
    expect(khatma.wirdsRead, 9);
    expect(find.text('The khatma continues from here.'), findsOneWidget);

    await setPlace(tester, refOf(khatma.index.juzStarts[4]),
        counts: 'Wirds that become read: 0. Wirds that become not read: 5.');
    expect(khatma.currentWird!.number, 5);
    expect(khatma.wirdsRead, 4);
    await close(tester);
  });
}
