// A memorization session through the real reading screen (specs/006 T032, T034, T051): the range
// sheet, hidden words, reveals, a hint, a mistake, the score and Done. The recogniser is scripted.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/memorization/memorization_controller.dart';
import 'package:mathani/features/memorization/result_screen.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_memorization.dart';
import '../support/harness.dart';

void main() {
  late ReaderController reader;
  late MemorizationController memorization;
  late FakeSpeechRecogniser recogniser;
  late FakeMicSource mic;

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar));
    recogniser = FakeSpeechRecogniser();
    mic = FakeMicSource();
    memorization = MemorizationController(
      reader: reader,
      model: ReadyAsrModel(),
      recogniser: () => recogniser,
      mic: () => mic,
    );
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MathaniApp(controller: reader, memorization: memorization));
    await settle(tester);
  }

  /// The range's word ids that the Mushaf page draws as hidden.
  Set<int> hiddenOnPage(WidgetTester tester, Iterable<int> ids) {
    final page = tester.widgetList<MushafPageRenderer>(find.byType(MushafPageRenderer))
        .firstWhere((p) => p.page.number == reader.page);
    final marks = page.marks;
    if (marks == null) return {};
    return {for (final id in ids) if (marks.hidden(id)) id};
  }

  testWidgets('Al-Ikhlas: hidden, revealed ayah by ayah, a hint and a mistake, then the score',
      (tester) async {
    await pumpApp(tester);
    reader.jumpToPage(604);
    await settle(tester);

    // The toolbar's Memorize button opens the range sheet on the page's first surah.
    await tapToolbar(tester, MathaniIcons.memorize);
    await settle(tester);
    expect(find.text('اختبر حفظك'), findsOneWidget);
    expect(find.text('٤ آيات · الصفحة ٦٠٤'), findsOneWidget);
    await tester.tap(find.text('ابدأ'));
    await settle(tester, 10);

    expect(memorization.phase, MemorizationPhase.listening);
    expect(memorization.range, const MemorizationRange(112, 1, 4));
    expect(mic.starts, 1);
    expect(recogniser.loadedFrom, '/model');
    expect(find.text('الآية ١ من ٤'), findsOneWidget);
    expect(find.text('يستمع'), findsOneWidget);
    expect(find.byTooltip('استمع'), findsNothing, reason: 'Listen is hidden during a session');

    final words = (await tester.runAsync(() => reader.quran.memorizationWords(112, 1, 4)))!;
    final all = [for (final a in words) for (final w in a) w.wordId];
    expect(hiddenOnPage(tester, all), all.toSet(), reason: 'every word of the range is hidden');

    // Ayah 1 recited: revealed, and ayah 2 is expected.
    recogniser.say('قل هو الله احد');
    await settle(tester, 3);
    expect(memorization.expected, const AyahRef(112, 2));
    expect(hiddenOnPage(tester, [for (final w in words[0]) w.wordId]), isEmpty);
    expect(find.text('الآية ٢ من ٤'), findsOneWidget);

    // A word added in ayah 2: a mistake, and the reader carries on.
    recogniser.say('الله الكبير الصمد');
    await settle(tester, 3);
    expect(memorization.hasMistake(const AyahRef(112, 2)), isTrue);
    expect(find.text('خطأ — تابع من الكلمة'), findsOneWidget);
    // Matching stops at a mistake; the reader carries on from the word (Q1).
    expect(memorization.expected, const AyahRef(112, 2));
    recogniser.say('الصمد');
    await settle(tester, 3);
    expect(memorization.expected, const AyahRef(112, 3));

    // «الكلمة التالية» shows the first word of ayah 3 in the hint colour.
    await tester.tap(find.byTooltip('الكلمة التالية'));
    await settle(tester, 2);
    expect(memorization.isHinted(words[2].first.wordId), isTrue);
    recogniser.say('يلد ولم يولد');
    await settle(tester, 3);

    // The last ayah ends the session and opens the result.
    recogniser.say('ولم يكن له كفوا احد');
    await settle(tester, 3);
    await tester.pump(endFlushWait);
    await settle(tester, 6);
    expect(memorization.phase, MemorizationPhase.ended);
    expect(find.byType(ResultScreen), findsOneWidget);
    // (1 + 0.5 + 0.25 + 1) / 4 × 100 = 68.75 → 69
    expect(memorization.result!.score, 69);
    expect(find.text('٦٩'), findsOneWidget);
    expect(find.text('دون خطأ ٢ · صُحّحت ١ · بتلميح ١ · أُظهرت ٠ · لم تُبلغ ٠'), findsOneWidget);

    // Done: back to reading at the session's last page, with the text shown again.
    await tester.tap(find.text('تم'));
    await settle(tester);
    expect(find.byType(ResultScreen), findsNothing);
    expect(memorization.phase, isNull);
    expect(reader.page, 604);
    expect(hiddenOnPage(tester, all), isEmpty);
    expect(find.byTooltip('الحفظ'), findsOneWidget);
  });

  testWidgets('End mid-range: the ayah being recited counts as not reached', (tester) async {
    await pumpApp(tester);
    reader.jumpToPage(604);
    await settle(tester);
    await tapToolbar(tester, MathaniIcons.memorize);
    await settle(tester);
    await tester.tap(find.text('ابدأ'));
    await settle(tester, 10);

    recogniser.say('قل هو الله احد');
    await settle(tester, 3);
    recogniser.say('الله'); // ayah 2 started, not finished
    await settle(tester, 3);
    await tester.tap(find.text('إنهاء'));
    await tester.pump(endFlushWait);
    await settle(tester, 6);

    expect(mic.listening, isFalse, reason: 'the microphone stops at once');
    expect(memorization.result!.reached, 1);
    expect(memorization.result!.score, 100);
    expect(find.text('لم تكتمل'), findsOneWidget, reason: 'ayah 2 was started');
    expect(find.text('لم تُبلغ'), findsNWidgets(2), reason: 'ayat 3 and 4');
  });

  testWidgets('without the microphone the session does not start', (tester) async {
    await pumpApp(tester);
    mic.permitted = false;
    reader.jumpToPage(604);
    await settle(tester);
    await tapToolbar(tester, MathaniIcons.memorize);
    await settle(tester);
    await tester.tap(find.text('ابدأ'));
    await settle(tester);
    // The explainer comes first; Continue asks the system, which refuses.
    expect(find.text('الميكروفون للمتابعة فقط'), findsOneWidget);
    await tester.tap(find.text('متابعة'));
    await settle(tester);
    expect(memorization.phase, isNull);
    expect(find.text('لا يمكن بدء الحفظ دون الميكروفون.'), findsOneWidget);
    expect(mic.starts, 0);
  });
}
