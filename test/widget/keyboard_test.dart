// specs/008 FR-009, research R12: the reader by keyboard.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

void main() {
  late ReaderController reader;

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<RecitationController> pumpApp(WidgetTester tester,
      {Size size = const Size(720, 1560), double ratio = 2}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar));
    final (recitation, _, _) = openTestRecitation(reader);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MathaniApp(controller: reader, recitation: recitation));
    await settle(tester);
    return recitation;
  }

  testWidgets('arrow and page keys turn pages in the Mushaf direction', (tester) async {
    await pumpApp(tester);
    reader.jumpTo(const AyahRef(2, 1), highlight: false); // page 2
    await settle(tester);
    expect(reader.page, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft); // next page, as in a printed Mushaf
    await settle(tester);
    expect(reader.page, 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(reader.page, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await settle(tester);
    expect(reader.page, 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await settle(tester);
    expect(reader.page, 2);
  });

  testWidgets('the first page stays put on the previous-page key', (tester) async {
    await pumpApp(tester);
    reader.jumpTo(const AyahRef(1, 1), highlight: false);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(reader.page, 1);
  });

  testWidgets('with two facing pages, the keys turn two pages (specs/012)', (tester) async {
    await pumpApp(tester, size: const Size(1440, 900), ratio: 1);
    reader.jumpToPage(50);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(reader.page, 51, reason: 'from 49–50 to 51–52');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(reader.page, 49);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(reader.page, 47);

    reader.jumpToPage(604);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await settle(tester);
    expect(reader.page, 604, reason: 'nothing after 603–604');
    reader.jumpToPage(2);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await settle(tester);
    expect(reader.page, 2, reason: 'nothing before 1–2');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('space pauses and resumes the recitation', (tester) async {
    final recitation = await pumpApp(tester);
    await tester.runAsync(() => recitation.playFrom(const AyahRef(1, 1)));
    await settle(tester);
    expect(recitation.session?.status, RecitationStatus.playing);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(recitation.session?.status, RecitationStatus.paused);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(recitation.session?.status, RecitationStatus.playing);
  });
}
