// The khatma controller with the real reader and repositories (specs/014 research R3, R4,
// data-model.md › State changes): following page turns, reading on, Undo, setting the place,
// changing the plan, pausing, ending and finishing.
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/features/khatma/khatma_models.dart';
import 'package:mathani/features/khatma/khatma_repository.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  late ReaderController reader;
  late KhatmaController khatma;
  late DateTime now;
  var memorizing = false;

  /// Lets the controller's database work finish. A fixed wait alone was flaky on busy CI
  /// machines: sqflite runs one operation at a time, so a query queued after each step of the
  /// controller's chain returns only once that step's writes are done.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await reader.user.database.rawQuery('SELECT 1');
      }
    });
    await tester.pump();
  }

  Future<void> open(WidgetTester tester, {KhatmaPlan plan = const MarksPlan(8)}) async {
    now = DateTime(2026, 3, 1, 9);
    memorizing = false;
    reader = (await tester.runAsync(openTestReader))!;
    khatma = KhatmaController(
      repository: KhatmaRepository.of(reader.user),
      reader: reader,
      isMemorizing: () => memorizing,
      clock: () => now,
      keepBrowserData: () async {},
    );
    await tester.runAsync(khatma.load);
    await tester.runAsync(() => khatma.start(plan,
        startAyah: 1, startDate: CalendarDay.of(now)));
    reader.jumpToPage(1);
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    khatma.dispose();
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
  }

  /// Turns page by page, as a swipe does.
  Future<void> turnTo(WidgetTester tester, int page) async {
    final step = page > reader.page ? 1 : -1;
    while (reader.page != page) {
      reader.onMushafPageShown(reader.page + step);
      await settle(tester);
    }
  }

  int id(int surah, int ayah) => reader.quran.ayahAt(AyahRef(surah, ayah)).id;

  testWidgets('a juz a day: the current wird, its end mark and its pages left', (tester) async {
    await open(tester);
    final w = khatma.currentWird!;
    expect(w.number, 1);
    expect(khatma.wirds, hasLength(30));
    expect(khatma.endMarksOn(21), {reader.quran.ayahAt(const AyahRef(2, 141)).lastWordId});
    expect(khatma.endMarksOn(20), isEmpty);
    expect(khatma.pagesLeft(1), 21);
    expect(khatma.pagesLeft(21), 1);
    expect(khatma.pagesLeft(22), isNull);
    expect(khatma.readingsEndingOn(21, 21), hasLength(1));
    expect(khatma.readingsEndingOn(19, 20), isEmpty);
    await close(tester);
  });

  testWidgets('the place follows page turns and ignores jumps (P1, P3)', (tester) async {
    await open(tester);
    await turnTo(tester, 3);
    expect(khatma.khatma!.placePage, 3);
    reader.jumpToPage(440); // the index
    await settle(tester);
    reader.onMushafPageShown(441);
    await settle(tester);
    expect(khatma.khatma!.placePage, 3);
    // Saved after the delay.
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    final saved = (await tester.runAsync(khatma.repository.loadOpen))!;
    expect(saved.khatma.placePage, 3);
    await close(tester);
  });

  testWidgets('reading on past the end marks the wird; Undo puts it back (P7, FR-016)',
      (tester) async {
    await open(tester);
    await turnTo(tester, 21);
    reader.onMushafPageShown(22);
    await settle(tester);
    expect(khatma.currentWird!.number, 2);
    expect(khatma.wirds.first.readOn, CalendarDay.of(now));
    expect(khatma.khatma!.placePage, 22);
    expect(khatma.events.value?.byReadingOn, isTrue);
    expect(khatma.todayRead, isTrue);
    await tester.runAsync(khatma.undo);
    expect(khatma.currentWird!.number, 1);
    expect(khatma.khatma!.placePage, 21, reason: 'the place is the wird\'s last page');
    await close(tester);
  });

  testWidgets('Done moves to the next wird', (tester) async {
    await open(tester);
    await tester.runAsync(khatma.markRead);
    expect(khatma.currentWird!.number, 2);
    expect(khatma.khatma!.placePage, 22);
    expect(khatma.events.value?.kind, KhatmaEventKind.wirdDone);
    expect(khatma.events.value?.byReadingOn, isFalse);
    await close(tester);
  });

  testWidgets('a recitation or memorization never moves or marks (P6, P9)', (tester) async {
    await open(tester);
    await turnTo(tester, 21);
    memorizing = true;
    reader.onMushafPageShown(22);
    await settle(tester);
    expect(khatma.currentWird!.number, 1);
    expect(khatma.endMarksOn(21), isEmpty);
    memorizing = false;
    reader.jumpToPage(22); // a recitation following the page
    await settle(tester);
    expect(khatma.currentWird!.number, 1);
    await close(tester);
  });

  testWidgets('set the place in Juz 10, then in Juz 5 (FR-017)', (tester) async {
    await open(tester);
    final juz10 = khatma.index.juzStarts[9] + 5;
    expect(khatma.countChangesFor(juz10), (read: 9, unread: 0));
    await tester.runAsync(() => khatma.setPlaceAt(juz10));
    expect(khatma.currentWird!.number, 10);
    expect(khatma.wirdsRead, 9);
    expect(khatma.khatma!.placePage, khatma.index.pageOf(juz10));
    final juz5 = khatma.index.juzStarts[4];
    expect(khatma.countChangesFor(juz5), (read: 0, unread: 5));
    await tester.runAsync(() => khatma.setPlaceAt(juz5));
    expect(khatma.currentWird!.number, 5);
    expect(khatma.wirdsRead, 4);
    await close(tester);
  });

  testWidgets('change plan keeps what was read and the part before the place (FR-030)',
      (tester) async {
    await open(tester);
    await tester.runAsync(khatma.markRead);
    await turnTo(tester, 22);
    await turnTo(tester, 30);
    expect(khatma.khatma!.placePage, 30);
    await tester.runAsync(() => khatma.changePlan(const DaysPlan(10)));
    final wirds = khatma.wirds;
    expect(wirds[0].isRead, isTrue);
    expect(wirds[1].isRead, isTrue, reason: 'pages 22 to 29 stay as a read wird');
    expect(khatma.index.pageOf(wirds[1].lastAyah), 29);
    expect(wirds[2].firstAyah, khatma.index.firstAyahOn(30));
    expect(wirds.length, 12);
    expect(wirds.map((w) => w.number), List.generate(12, (i) => i + 1));
    expect(khatma.khatma!.plan, const DaysPlan(10));
    expect(khatma.khatma!.wirdCount, 12);
    await close(tester);
  });

  testWidgets('pause and resume move the planned finish (FR-031)', (tester) async {
    await open(tester);
    final planned = khatma.khatma!.plannedFinish;
    await tester.runAsync(khatma.pause);
    expect(khatma.isPaused, isTrue);
    expect(khatma.readings, isEmpty);
    now = now.add(const Duration(days: 3));
    await tester.runAsync(khatma.resume);
    expect(khatma.isActive, isTrue);
    expect(khatma.khatma!.plannedFinish, planned.addDays(3));
    await close(tester);
  });

  testWidgets('ending keeps bookmarks and the reading position (FR-032)', (tester) async {
    await open(tester);
    await tester.runAsync(() => reader.user.addBookmark(const AyahRef(2, 255), 42));
    await tester.runAsync(khatma.end);
    expect(khatma.khatma, isNull);
    expect(khatma.record, isEmpty);
    expect(reader.user.bookmarks, hasLength(1));
    await close(tester);
  });

  testWidgets('a one-day khatma finishes, Undo brings it back (FR-034)', (tester) async {
    await open(tester, plan: const DaysPlan(1));
    await tester.runAsync(khatma.markRead);
    expect(khatma.khatma, isNull);
    expect(khatma.events.value?.kind, KhatmaEventKind.finished);
    expect(khatma.record.single.days, 1);
    await tester.runAsync(khatma.undo);
    expect(khatma.khatma, isNotNull);
    expect(khatma.record, isEmpty);
    expect(khatma.wirds.single.isRead, isFalse);
    await tester.runAsync(khatma.markRead);
    final record = khatma.record.single;
    await tester.runAsync(() => khatma.deleteRecord(record.id));
    expect(khatma.record, isEmpty);
    await close(tester);
  });

  testWidgets('a second khatma is refused while one is in progress (FR-005)', (tester) async {
    await open(tester);
    Object? error;
    await tester.runAsync(() async {
      try {
        await khatma.start(const SevenPlan(), startAyah: id(1, 1), startDate: CalendarDay.of(now));
      } catch (e) {
        error = e;
      }
    });
    expect(error, isA<KhatmaInProgress>());
    await close(tester);
  });
}
