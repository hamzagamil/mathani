// A memorization session through the real reading screen (specs/006 T032, T034, T051): the range
// sheet, hidden words, reveals, a hint, a mistake, the score and Done; and live passes (specs/007
// T018, T023). The recogniser is scripted.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/memorization/memorization_controller.dart';
import 'package:mathani/features/memorization/result_screen.dart';
import 'package:mathani/features/memorization/speech_recogniser.dart';
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

  Future<void> pumpApp(WidgetTester tester, {int passesToAgree = livePassesToAgree}) async {
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
      passesToAgree: passesToAgree,
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

    // Words appear as they are recited: after «قل هو», only those two are shown.
    final ayah1 = [for (final w in words[0]) w.wordId];
    recogniser.say('قل هو');
    await settle(tester, 3);
    expect(hiddenOnPage(tester, ayah1), ayah1.skip(2).toSet());
    expect(memorization.expected, const AyahRef(112, 1));

    // The rest of ayah 1: revealed, and ayah 2 is expected.
    recogniser.say('الله احد');
    await settle(tester, 3);
    expect(memorization.expected, const AyahRef(112, 2));
    expect(hiddenOnPage(tester, [for (final w in words[0]) w.wordId]), isEmpty);
    expect(find.text('الآية ٢ من ٤'), findsOneWidget);

    // A word added in ayah 2: a mistake, and the reader carries on.
    recogniser.say('الله الكبير الصمد');
    await settle(tester, 3);
    expect(memorization.hasMistake(const AyahRef(112, 2)), isTrue);
    expect(find.text('خطأ — تابع من الكلمة'), findsOneWidget);
    // Matching stops at a mistake; the reader carries on from the word (Q1). The words before it
    // are shown and the word to say again is the first one still hidden.
    expect(memorization.expected, const AyahRef(112, 2));
    expect(hiddenOnPage(tester, [for (final w in words[1]) w.wordId]), {words[1][1].wordId});
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

  group('live passes', () {
    late List<List<int>> ids; // word ids of Al-Ikhlas, ayah by ayah

    Future<void> start(WidgetTester tester, {int passesToAgree = livePassesToAgree}) async {
      await pumpApp(tester, passesToAgree: passesToAgree);
      reader.jumpToPage(604);
      await settle(tester);
      await tapToolbar(tester, MathaniIcons.memorize);
      await settle(tester);
      await tester.tap(find.text('ابدأ'));
      await settle(tester, 10);
      final words = (await tester.runAsync(() => reader.quran.memorizationWords(112, 1, 4)))!;
      ids = [for (final a in words) [for (final w in a) w.wordId]];
    }

    /// Stops listening, so no silence timer is left behind.
    Future<void> stop(WidgetTester tester) async {
      memorization.pause();
      await settle(tester, 2);
    }

    testWidgets('words appear while reciting, the last one held back, and the anchor follows',
        (tester) async {
      await start(tester);
      final h = recogniser.say('قل هو الله', hearing: Hearing.live);
      await settle(tester, 2);
      expect([for (final id in ids[0]) memorization.isHidden(id)], [false, false, true, true]);
      expect(recogniser.commits.last, (h.pass, h.words[1].startSample), reason: 'start of هو');

      // The next pass starts on «هو», heard again, and completes the ayah.
      final next = recogniser.say('هو الله احد الله', hearing: Hearing.live);
      await settle(tester, 2);
      expect(next.windowStart, h.words[1].startSample);
      expect(memorization.expected, const AyahRef(112, 2));
      expect(ids[0].where(memorization.isHidden), isEmpty);
      expect(memorization.hasMistake(const AyahRef(112, 1)), isFalse);
      expect(recogniser.commits.last, (next.pass, next.words[2].startSample), reason: 'start of احد');
      await stop(tester);
    });

    testWidgets('a mistake two passes find is signalled once, and nothing after it shows',
        (tester) async {
      await start(tester);
      recogniser.say('قل هو الله احد الله الصمد');
      await settle(tester, 2);
      final serial = memorization.mistakeSerial;
      // One pass only suspects it; the next pass, hearing it again, confirms it.
      var h = recogniser.say('لم ينم ولم يولد ولم', hearing: Hearing.live);
      await settle(tester, 2);
      expect(memorization.hasMistake(const AyahRef(112, 3)), isFalse);
      h = recogniser.say('لم ينم ولم يولد ولم يكن', hearing: Hearing.live, start: h.windowStart);
      await settle(tester, 2);
      expect(memorization.hasMistake(const AyahRef(112, 3)), isTrue);
      expect(memorization.mistakeSerial, serial + 1);
      expect(recogniser.commits.last, (h.pass, h.endSample), reason: 'everything heard is used');
      expect([for (final id in ids[2]) memorization.isHidden(id)], [false, true, true, true]);

      // The closing pause pass hears the same words: no second signal.
      recogniser.say('لم ينم ولم يولد', start: h.windowStart);
      await settle(tester, 2);
      expect(memorization.mistakeSerial, serial + 1);
      expect([for (final id in ids[2]) memorization.isHidden(id)], [false, true, true, true]);
      await stop(tester);
    });

    testWidgets('the last word is used when nothing was heard after it for a while', (tester) async {
      await start(tester);
      // «احد» ended 0.5 s before the end of the pass: finished, so not held back.
      final h = recogniser.say('قل هو الله احد', hearing: Hearing.live);
      final finished = Heard(h.pass + 1, Hearing.live,
          [...h.words.take(3), HeardWord('احد', h.words[3].startSample, h.words[3].startSample)],
          h.windowStart, h.words[3].startSample + 8000);
      expect(finished.endSample - finished.words.last.endSample, greaterThanOrEqualTo(wordEndGap * micSampleRate));
      await settle(tester, 2);
      expect(memorization.isHidden(ids[0][3]), isTrue, reason: 'still speaking: held back');
      recogniser.emit(finished);
      await settle(tester, 2);
      expect(memorization.expected, const AyahRef(112, 2), reason: 'ayah 1 complete before a pause');
      await stop(tester);
    });

    testWidgets('a pass that matches nothing leaves the anchor where it was', (tester) async {
      await start(tester);
      final h = recogniser.say('ققق ققق', hearing: Hearing.live);
      await settle(tester, 2);
      expect(recogniser.commits.last, (h.pass, h.windowStart));
      expect(ids[0].where(memorization.isHidden), hasLength(4));
      await stop(tester);
    });

    testWidgets('a word shown stays shown when the reader goes back', (tester) async {
      await start(tester);
      recogniser.say('قل هو الله', hearing: Hearing.live);
      await settle(tester, 2);
      recogniser.say('قل هو قل هو', hearing: Hearing.live, start: 0);
      await settle(tester, 2);
      expect([for (final id in ids[0]) memorization.isHidden(id)], [false, false, true, true]);
      await stop(tester);
    });

    testWidgets('Next word during a pass: the hinted word counts once, the next stays expected',
        (tester) async {
      await start(tester);
      final h = recogniser.say('قل هو الله', hearing: Hearing.live);
      await settle(tester, 2);
      await tester.tap(find.byTooltip('الكلمة التالية'));
      await settle(tester, 2);
      expect(memorization.isHinted(ids[0][2]), isTrue);
      recogniser.say('هو الله احد', hearing: Hearing.live, start: h.words[1].startSample);
      await settle(tester, 2);
      expect(memorization.isHinted(ids[0][2]), isTrue);
      expect(memorization.isHidden(ids[0][3]), isTrue, reason: 'احد was the held-back word');
      expect(memorization.expected, const AyahRef(112, 1));
      await stop(tester);
    });

    testWidgets('pause changes state at once, and a late live pass reveals nothing', (tester) async {
      await start(tester);
      memorization.pause();
      expect(memorization.phase, MemorizationPhase.paused, reason: 'synchronously');
      recogniser.say('قل هو الله احد', hearing: Hearing.live);
      await settle(tester, 2);
      expect(ids[0].where(memorization.isHidden), hasLength(4));
      await stop(tester);
    });

    testWidgets('with two passes to agree, a word is used once two passes heard it', (tester) async {
      await start(tester, passesToAgree: 2);
      recogniser.say('قل هو الله', hearing: Hearing.live);
      await settle(tester, 2);
      expect(ids[0].where(memorization.isHidden), hasLength(4), reason: 'nothing to agree with yet');
      recogniser.say('قل هو الله احد', hearing: Hearing.live, start: 0);
      await settle(tester, 2);
      expect([for (final id in ids[0]) memorization.isHidden(id)], [false, false, false, true],
          reason: 'both passes heard قل هو الله; احد is held back and heard once');
      await stop(tester);
    });
  });
}
