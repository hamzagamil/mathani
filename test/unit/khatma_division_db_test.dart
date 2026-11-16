// The division on the bundled Mushaf data (specs/014 contracts/wird-division.md › What the tests
// must show): SC-003 and SC-004 over every plan and start page, and the examples exactly.
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/khatma/khatma_division.dart';
import 'package:mathani/features/khatma/khatma_models.dart';

import '../support/quran_index.dart';

void main() {
  late QuranIndex index;
  late List<Ayah> ayahs;

  setUpAll(() async {
    final loaded = await loadBundledIndex();
    index = loaded.index;
    ayahs = loaded.ayahs;
  });

  AyahRef ref(int id) => ayahs[id - 1].ref;
  int id(int surah, int ayah) => ayahs.firstWhere((a) => a.surah == surah && a.ayah == ayah).id;

  /// Rule 1: no gap and no overlap from [start] to the last ayah.
  void expectCover(int start, List<WirdRange> wirds, String why) {
    expect(wirds.first.firstAyah, start, reason: why);
    for (var i = 1; i < wirds.length; i++) {
      if (wirds[i].firstAyah != wirds[i - 1].lastAyah + 1) fail('gap or overlap: $why, wird $i');
    }
    for (final w in wirds) {
      if (w.firstAyah > w.lastAyah) fail('empty wird: $why');
    }
    expect(wirds.last.lastAyah, 6236, reason: why);
  }

  final sevenStarts = {1, 5, 10, 17, 26, 37, 50};

  test('the Mushaf facts the division relies on (research R2)', () {
    expect(index.ayahCount, 6236);
    expect(index.quarterStarts, hasLength(240));
    expect(index.juzStarts, hasLength(30));
    for (var p = 1; p <= 604; p++) {
      expect(index.pageOf(index.firstAyahOn(p)), p, reason: 'an ayah starts on page $p');
    }
  });

  test('SC-003 and SC-004: marks and seven days from the first ayah of every page', () {
    final quarterSet = index.quarterStarts.toSet();
    for (var page = 1; page <= 604; page++) {
      final start = index.firstAyahOn(page);
      for (final q in KhatmaPlan.markAmounts) {
        final wirds = divide(index, start, MarksPlan(q));
        expectCover(start, wirds, 'marks($q) from page $page');
        for (final w in wirds.skip(1)) {
          if (!quarterSet.contains(w.firstAyah)) fail('marks($q) from page $page off a mark');
          final k = index.quarterStarts.indexOf(w.firstAyah);
          if (k % q != 0) fail('marks($q) from page $page: quarter ${k + 1} is not a boundary');
        }
      }
      final seven = divide(index, start, const SevenPlan());
      expectCover(start, seven, 'seven from page $page');
      for (final w in seven.skip(1)) {
        if (!sevenStarts.contains(ref(w.firstAyah).surah) || ref(w.firstAyah).ayah != 1) {
          fail('seven from page $page: a wird starts at ${ref(w.firstAyah)}');
        }
      }
    }
  });

  void expectEvenDays(int start, int n) {
    final wirds = divide(index, start, DaysPlan(n));
    expectCover(start, wirds, 'days($n) from ${ref(start)}');
    var fewest = 999, most = 0;
    for (final w in wirds) {
      final pages = index.pagesOf(w);
      if (pages < fewest) fewest = pages;
      if (pages > most) most = pages;
      if (w.lastAyah != index.lastAyahOn(index.pageOf(w.lastAyah))) {
        fail('days($n) from ${ref(start)}: a wird does not end on a page end');
      }
    }
    if (most - fewest > 1) fail('days($n) from ${ref(start)}: sizes $fewest to $most');
  }

  test('SC-003 and SC-004: every number of days from six start pages', () {
    for (final page in [1, 2, 50, 302, 603, 604]) {
      for (var n = 1; n <= 604; n++) {
        expectEvenDays(index.firstAyahOn(page), n);
      }
    }
  });

  test('SC-003 and SC-004: common numbers of days from every page', () {
    for (var page = 1; page <= 604; page++) {
      for (final n in [1, 2, 7, 29, 30, 100, 365, 604]) {
        expectEvenDays(index.firstAyahOn(page), n);
      }
    }
  });

  test('a start point in the middle of a page', () {
    for (final start in [id(2, 100), id(3, 93), id(18, 75), id(114, 6)]) {
      for (final plan in [const MarksPlan(8), const SevenPlan(), const DaysPlan(30)]) {
        expectCover(start, divide(index, start, plan), '$plan from ${ref(start)}');
      }
      expectEvenDays(start, 29);
    }
  });

  group('the examples of the contract', () {
    test('a juz a day from the beginning', () {
      final wirds = divide(index, 1, const MarksPlan(8));
      expect(wirds, hasLength(30));
      expect([ref(wirds[0].firstAyah), ref(wirds[0].lastAyah)],
          [const AyahRef(1, 1), const AyahRef(2, 141)]);
      expect([index.pageOf(wirds[0].firstAyah), index.pageOf(wirds[0].lastAyah)], [1, 21]);
      expect([ref(wirds[2].firstAyah), ref(wirds[2].lastAyah)],
          [const AyahRef(2, 253), const AyahRef(3, 92)]);
      expect([index.pageOf(wirds[2].firstAyah), index.pageOf(wirds[2].lastAyah)], [42, 62]);
      expect(index.pageOf(wirds[3].firstAyah), 62, reason: 'Juz 4 starts in the middle of 62');
      expect([ref(wirds[29].firstAyah), ref(wirds[29].lastAyah)],
          [const AyahRef(78, 1), const AyahRef(114, 6)]);
      expect([index.pageOf(wirds[29].firstAyah), index.pageOf(wirds[29].lastAyah)], [582, 604]);
    });

    test('a juz a day from Juz 16', () {
      expect(ref(index.juzStarts[15]), const AyahRef(18, 75));
      expect(divide(index, index.juzStarts[15], const MarksPlan(8)), hasLength(15));
    });

    test('a juz a day from page 250', () {
      final wirds = divide(index, index.firstAyahOn(250), const MarksPlan(8));
      expect(wirds, hasLength(18));
      expect(ref(wirds.first.lastAyah), const AyahRef(14, 52));
    });

    test('seven days', () {
      final wirds = divide(index, 1, const SevenPlan());
      expect([for (final w in wirds) index.pagesOf(w)], [106, 102, 74, 85, 79, 72, 87]);
      expect(index.pageOf(wirds[0].lastAyah), 106);
      expect(index.pageOf(wirds[1].firstAyah), 106);
    });

    test('29 and 30 days', () {
      for (final n in [29, 30]) {
        final wirds = divide(index, 1, DaysPlan(n));
        expect(wirds, hasLength(n));
        expect({for (final w in wirds) index.pagesOf(w)}, {20, 21});
      }
    });

    test('50 pages a day', () {
      final days = daysForPagesPerDay(index, 1, 50);
      expect(days, 13);
      expect({for (final w in divide(index, 1, DaysPlan(days))) index.pagesOf(w)}, {46, 47});
    });

    test('604 days, and 40 days from page 600', () {
      final wirds = divide(index, 1, const DaysPlan(604));
      expect(wirds, hasLength(604));
      expect({for (final w in wirds) index.pagesOf(w)}, {1});
      expect(divide(index, index.firstAyahOn(600), const DaysPlan(40)), hasLength(5));
    });
  });

  test('wird names', () {
    final juz = divide(index, 1, const MarksPlan(8));
    expect(wirdName(index, juz[2], 3), isA<JuzName>().having((n) => n.juz, 'juz', 3));
    final hizb = divide(index, 1, const MarksPlan(4));
    expect(wirdName(index, hizb[4], 5), isA<HizbName>().having((n) => n.hizb, 'hizb', 5));
    final quarter = divide(index, 1, const MarksPlan(1));
    expect(wirdName(index, quarter[5], 6),
        isA<QuarterName>().having((n) => (n.hizb, n.quarter), 'hizb, quarter', (2, 2)));
    final days = divide(index, 1, const DaysPlan(29));
    expect(wirdName(index, days[11], 12), isA<NumberName>());
  });

  test('604 wirds are made quickly', () {
    final watch = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      divide(index, 1, const DaysPlan(604));
    }
    // 5 ms on the reference phone (contract); a desktop test machine is far faster.
    expect(watch.elapsedMilliseconds / 20, lessThan(5));
  });
}
