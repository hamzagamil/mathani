import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/recitation/ayah_fetcher.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/features/recitation/recited_item.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

/// RecitationController (specs/004 contracts/recitation-playback.md), with a fake player and
/// fetcher and the real Quran data.
void main() {
  late ReaderController reader;
  late RecitationController c;
  late FakeAudioEngine engine;
  late FakeFetcher fetcher;

  Future<void> setUpReader(WidgetTester tester) async {
    reader = (await tester.runAsync(openTestReader))!;
    // Warm the basmala page caches (database reads need real async).
    await tester.runAsync(() async {
      await reader.quran.basmalaPageOf(2, printed: false);
      await reader.quran.basmalaPageOf(2, printed: true);
    });
    (c, engine, fetcher) = openTestRecitation(reader);
  }

  /// Each test ends the session and disposes the controller, so no timer outlives it.
  void recitationTest(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      await setUpReader(tester);
      await body(tester);
      await c.stop();
      c.dispose();
      // Save the position now, in real async (as when the app goes to the background), which
      // cancels the 500 ms save timer; then let the 1.5 s jump highlight run out.
      await tester.runAsync(() async {
        reader.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(seconds: 2));
    });
  }

  RecitedItem ayah(int s, int a) => RecitedItem.ayah(s, a);
  RecitationSession session() => c.session!;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  group('starting', () {
    recitationTest('a page starts at the first ayah that begins on it', (tester) async {
      final quran = reader.quran;
      c.playFromPage(50);
      await settle(tester);
      expect(session().item.ref, quran.ayahsStartingOnPage(50).first.ref);
      expect(session().status, RecitationStatus.playing);
      expect(engine.playing, isTrue);

      // Every page starts at the first ayah that begins on it (or, if none begins there, the
      // ayah continuing onto it).
      for (final p in [2, 3, 49, 50, 300, 604]) {
        await c.stop();
        c.playFromPage(p);
        await settle(tester);
        final starting = quran.ayahsStartingOnPage(p);
        expect(session().item.ref,
            starting.isNotEmpty ? starting.first.ref : quran.firstAyahOnPage(p).ref);
      }
    });

    recitationTest('ayah 1 of a surah starts at its basmala; Al-Fatiha and At-Tawbah do not',
        (tester) async {
      c.playFrom(const AyahRef(2, 1));
      await settle(tester);
      expect(session().item, const RecitedItem.basmala(2));
      c.playFrom(const AyahRef(9, 1));
      await settle(tester);
      expect(session().item, ayah(9, 1));
      c.playFrom(const AyahRef(1, 1));
      await settle(tester);
      expect(session().item, ayah(1, 1));
    });
  });

  group('never skips (FR-007, FR-020)', () {
    recitationTest('loading → playing when the file resolves', (tester) async {
      fetcher.holding.add(const RecitedItem.basmala(67));
      c.playFrom(const AyahRef(67, 1));
      await settle(tester);
      expect(session().status, RecitationStatus.loading);
      expect(c.recited, const RecitedItem.basmala(67)); // highlighted while loading
      expect(engine.playing, isFalse);
      fetcher.release(const RecitedItem.basmala(67));
      await settle(tester);
      expect(session().status, RecitationStatus.playing);
      expect(engine.currentItem, const RecitedItem.basmala(67));
      expect(engine.playing, isTrue);
    });

    recitationTest('waits on an unresolved next ayah, then plays it', (tester) async {
      fetcher.holding.addAll([ayah(67, 2), ayah(67, 3), ayah(67, 4)]);
      c.playFrom(const AyahRef(67, 2));
      fetcher.release(ayah(67, 2));
      await settle(tester);
      expect(session().status, RecitationStatus.playing);
      expect(engine.window, [ayah(67, 2)]);
      engine.finishCurrent(); // 67:3 is not ready
      await settle(tester);
      expect(session().item, ayah(67, 3));
      expect(session().status, RecitationStatus.loading);
      fetcher.release(ayah(67, 3));
      await settle(tester);
      expect(session().item, ayah(67, 3));
      expect(session().status, RecitationStatus.playing);
      expect(engine.currentItem, ayah(67, 3));
    });

    recitationTest('a failing ayah stops on it with an error, and retry loads the same ayah',
        (tester) async {
      fetcher.failing[ayah(67, 5)] = FetchError.fetchFailed;
      c.playFrom(const AyahRef(67, 5));
      await settle(tester);
      expect(session().status, RecitationStatus.error);
      expect(session().error, FetchError.fetchFailed);
      expect(session().item, ayah(67, 5));
      fetcher.failing.clear();
      fetcher.resolved.clear();
      c.retry();
      await settle(tester);
      expect(fetcher.resolvedItems.first, ayah(67, 5));
      expect(session().status, RecitationStatus.playing);
    });

    recitationTest('a lookahead failure at the end of the window shows an error, not a wait',
        (tester) async {
      fetcher.failing[ayah(67, 7)] = FetchError.fetchFailed;
      c.playFrom(const AyahRef(67, 6));
      await settle(tester);
      engine.finishCurrent();
      await settle(tester);
      expect(session().item, ayah(67, 7));
      expect(session().status, RecitationStatus.error);
    });

    recitationTest('loading longer than 15 s is an error', (tester) async {
      fetcher.holdAll = true;
      c.playFrom(const AyahRef(67, 8));
      await tester.pump(loadingTimeout + const Duration(seconds: 1));
      await settle(tester);
      expect(session().status, RecitationStatus.error);
      expect(session().error, FetchError.fetchFailed);
    });

    recitationTest('offline and not downloaded: the offline error', (tester) async {
      fetcher.failing[ayah(68, 1)] = FetchError.offline;
      c.playFrom(const AyahRef(68, 1));
      fetcher.failing[const RecitedItem.basmala(68)] = FetchError.offline;
      c.playFrom(const AyahRef(68, 1));
      await settle(tester);
      expect(session().status, RecitationStatus.error);
      expect(session().error, FetchError.offline);
    });
  });

  group('offline (US4)', () {
    recitationTest('reaching a surah that is not downloaded stops at its basmala, with no skip',
        (tester) async {
      // Al-Mulk plays (downloaded); Al-Qalam is offline and not downloaded.
      fetcher.failing[const RecitedItem.basmala(68)] = FetchError.offline;
      fetcher.failing[ayah(68, 1)] = FetchError.offline;
      c.playFrom(const AyahRef(67, 30));
      await settle(tester);
      expect(session().status, RecitationStatus.playing);
      engine.finishCurrent();
      await settle(tester);
      expect(session().item, const RecitedItem.basmala(68));
      expect(session().status, RecitationStatus.error);
      expect(session().error, FetchError.offline);
      expect(fetcher.resolvedItems, isNot(contains(ayah(68, 2))));
    });
  });

  group('controls', () {
    recitationTest('next ×3 within 300 ms loads only the last', (tester) async {
      c.playFrom(const AyahRef(67, 10));
      await settle(tester);
      fetcher.resolved.clear();
      c.next();
      c.next();
      c.next();
      expect(session().item, ayah(67, 13)); // on screen at once
      await tester.pump(skipMergeWindow + const Duration(milliseconds: 10));
      await settle(tester);
      expect(fetcher.resolvedItems.first, ayah(67, 13));
      expect(fetcher.resolvedItems, isNot(contains(ayah(67, 11))));
      expect(fetcher.resolvedItems, isNot(contains(ayah(67, 12))));
      expect(session().status, RecitationStatus.playing);
    });

    recitationTest('previous works while paused and stays paused', (tester) async {
      c.playFrom(const AyahRef(67, 10));
      await settle(tester);
      c.pause();
      expect(session().status, RecitationStatus.paused);
      c.previous();
      await tester.pump(skipMergeWindow + const Duration(milliseconds: 10));
      await settle(tester);
      expect(session().item, ayah(67, 9));
      expect(session().status, RecitationStatus.paused);
      expect(engine.playing, isFalse);
      c.resume();
      await settle(tester);
      expect(session().status, RecitationStatus.playing);
    });

    recitationTest('stop ends the session; the end of the Quran ends it after 3 s', (tester) async {
      c.playFrom(const AyahRef(67, 1));
      await settle(tester);
      await c.stop();
      expect(c.session, isNull);
      expect(c.recited, isNull);
      expect(engine.stops, 1);

      c.playFrom(const AyahRef(114, 6));
      await settle(tester);
      engine.finishCurrent();
      await settle(tester);
      expect(session().status, RecitationStatus.ended);
      expect(c.recited, isNull);
      await tester.pump(endedBannerDuration + const Duration(milliseconds: 10));
      await settle(tester);
      expect(c.session, isNull);
    });

    recitationTest('a system pause shows as paused', (tester) async {
      c.playFrom(const AyahRef(67, 1));
      await settle(tester);
      engine.pausedBySystem();
      await settle(tester);
      expect(session().status, RecitationStatus.paused);
    });
  });

  group('choosing a reciter (US2)', () {
    recitationTest('switching mid-ayah saves it and restarts the same ayah in the new voice',
        (tester) async {
      c.playFrom(const AyahRef(67, 5));
      await settle(tester);
      expect(session().reciter.id, 'husary');
      fetcher.resolved.clear();
      await tester.runAsync(() => c.setReciter('minshawy'));
      await settle(tester);
      expect(reader.preferences.reciter, 'minshawy');
      expect(session().reciter.id, 'minshawy');
      expect(session().item, ayah(67, 5));
      expect(fetcher.resolved.first, ('minshawy', ayah(67, 5)));
      expect(engine.window.first, ayah(67, 5), reason: 'the window is rebuilt from that ayah');
      expect(session().status, RecitationStatus.playing);
    });

    recitationTest('offline and not downloaded for the new reciter: keep the previous one',
        (tester) async {
      c.playFrom(const AyahRef(67, 5));
      await settle(tester);
      fetcher.offlineReciters.add('minshawy');
      await tester.runAsync(() => c.setReciter('minshawy'));
      await settle(tester);
      expect(session().reciter.id, 'husary');
      expect(reader.preferences.reciter, 'husary');
      expect(c.notice, isA<RecitationNotice>());
      expect(c.takeNotice()!.reciter.id, 'minshawy');
      expect(session().item, ayah(67, 5));
      expect(session().status, RecitationStatus.playing);
    });

    recitationTest('a new recitation uses the saved reciter', (tester) async {
      await tester.runAsync(() => c.setReciter('minshawy'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      c.playFrom(const AyahRef(2, 255));
      await settle(tester);
      expect(session().reciter.id, 'minshawy');
      expect(fetcher.resolved.first.$1, 'minshawy');
    });
  });

  group('following (FR-012 to FR-014)', () {
    recitationTest('the Mushaf follows the recited ayah across pages', (tester) async {
      final quran = reader.quran;
      final lastOn50 = quran.ayahsStartingOnPage(50).last;
      c.playFrom(lastOn50.ref);
      await settle(tester);
      expect(reader.page, 50);
      engine.finishCurrent(); // the next ayah starts on page 51
      await settle(tester);
      expect(reader.page, quran.pageOf(session().item.ref));
      expect(reader.page, 51);
      expect(session().following, isTrue);
    });

    recitationTest('a swipe, a reader scroll or a jump from elsewhere stops following',
        (tester) async {
      c.playFrom(const AyahRef(67, 1));
      await settle(tester);
      expect(session().following, isTrue);
      reader.onMushafPageShown(reader.page + 2); // a swipe: jumpSerial unchanged
      expect(session().following, isFalse);
      expect(session().status, RecitationStatus.playing);

      c.returnToRecitation();
      await settle(tester);
      expect(session().following, isTrue);
      expect(reader.page, reader.quran.pageOf(const AyahRef(67, 1)));

      c.onReaderScroll();
      expect(session().following, isFalse);
      c.returnToRecitation();
      await settle(tester);

      reader.jumpTo(const AyahRef(2, 255)); // the index, search or go-to
      expect(session().following, isFalse);
    });

    recitationTest('the follow jump\'s own page change does not stop following', (tester) async {
      final lastOn50 = reader.quran.ayahsStartingOnPage(50).last;
      c.playFrom(lastOn50.ref);
      await settle(tester);
      engine.finishCurrent();
      await settle(tester);
      reader.onMushafPageShown(51); // the page view settles where the follow jump put it
      expect(session().following, isTrue);
    });

    recitationTest('theme and language keep following; a layout switch re-follows', (tester) async {
      c.playFrom(const AyahRef(67, 3));
      await settle(tester);
      // Preference writes reach the database: real async, outside the fake clock.
      Future<void> update(ReaderPreferences p) async {
        reader.updatePreferences(p);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      }

      await update(reader.preferences.copyWith(theme: ThemePref.night));
      await update(reader.preferences.copyWith(language: LanguagePref.en));
      expect(session().following, isTrue);
      await update(reader.preferences.copyWith(layout: ReadingLayout.flowing));
      await settle(tester);
      expect(session().following, isTrue);
      expect(reader.anchor, const AyahRef(67, 3));
    });

    recitationTest('printed lettering: the basmala is followed to the page that holds it',
        (tester) async {
      final quran = reader.quran;
      if (!quran.hasPrintedLettering) return; // the bundled database has it
      // In the printed edition 18 surah titles sit at the foot of the previous page, but every
      // basmala line is on the page of its ayah 1 (checked here against the data).
      for (var s = 2; s <= 114; s++) {
        if (s == 9) continue;
        final page = (await tester.runAsync(() => quran.basmalaPageOf(s, printed: true)))!;
        expect(page, quran.pageOf(AyahRef(s, 1)), reason: 'surah $s');
      }
      // Surah 4: its title is on page 76, its basmala and ayah 1 on page 77.
      c.playFrom(const AyahRef(4, 1));
      await settle(tester);
      expect(session().item, const RecitedItem.basmala(4));
      expect(reader.page, quran.pageOf(const AyahRef(4, 1)));
      reader.onMushafPageShown(reader.page);
      expect(session().following, isTrue);
      engine.finishCurrent();
      await settle(tester);
      expect(session().item, ayah(4, 1));
      expect(session().following, isTrue);
    });

    recitationTest('coming back from the background shows the recited page, still following',
        (tester) async {
      c.playFrom(const AyahRef(67, 1));
      await settle(tester);
      // Moved on in the background while the reader was elsewhere (no follow events seen).
      reader.jumpToPage(3);
      c.returnToRecitation();
      await settle(tester);
      reader.jumpToPage(3);
      expect(session().following, isFalse);
      c.returnToRecitation();
      await settle(tester);
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle(tester);
      expect(reader.page, reader.quran.pageOf(const AyahRef(67, 1)));
      expect(session().following, isTrue);
    });
  });
}
