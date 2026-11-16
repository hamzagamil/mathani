// The division rules on a small made-up Mushaf (specs/014 contracts/wird-division.md, rules 1 to
// 7), so each rule is seen apart from the real data.
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/khatma/khatma_division.dart';
import 'package:mathani/features/khatma/khatma_models.dart';

/// Page 1 with 4 ayat and 603 pages of 10 ayat (6,034 ayat), a quarter start every 25 ayat from
/// ayah 1 (240 quarters), and a surah start every 50 ayat from ayah 1.
QuranIndex synthetic() {
  final pages = <int>[for (var i = 0; i < 4; i++) 1];
  for (var p = 2; p <= 604; p++) {
    for (var i = 0; i < 10; i++) {
      pages.add(p);
    }
  }
  return QuranIndex(
    ayahPages: pages,
    quarterStarts: [for (var q = 0; q < 240; q++) 1 + q * 25],
    surahStarts: [for (var s = 0; s < 114; s++) 1 + s * 50],
  );
}

void expectCover(QuranIndex index, int start, List<WirdRange> wirds) {
  expect(wirds.first.firstAyah, start);
  for (var i = 1; i < wirds.length; i++) {
    expect(wirds[i].firstAyah, wirds[i - 1].lastAyah + 1);
  }
  for (final w in wirds) {
    expect(w.firstAyah, lessThanOrEqualTo(w.lastAyah));
  }
  expect(wirds.last.lastAyah, index.ayahCount);
}

void main() {
  final index = synthetic();

  test('rule 1: every ayah from the start point to the end, once, in order', () {
    for (final plan in [const MarksPlan(8), const SevenPlan(), const DaysPlan(30)]) {
      for (final start in [1, 2, 100, 3000, index.ayahCount]) {
        expectCover(index, start, divide(index, start, plan));
      }
    }
  });

  test('rule 2: by marks, a new wird at every q-th quarter start', () {
    for (final q in KhatmaPlan.markAmounts) {
      final wirds = divide(index, 1, MarksPlan(q));
      expect(wirds, hasLength((240 / q).ceil()));
      for (var k = 1; k < wirds.length; k++) {
        expect(wirds[k].firstAyah, index.quarterStarts[k * q]);
      }
    }
  });

  test('rule 3: seven days begin at surahs 1, 5, 10, 17, 26, 37 and 50', () {
    final wirds = divide(index, 1, const SevenPlan());
    expect([for (final w in wirds) w.firstAyah],
        [for (final s in [1, 5, 10, 17, 26, 37, 50]) index.surahStarts[s - 1]]);
  });

  test('rule 4: custom days spread whole pages evenly', () {
    final wirds = divide(index, 1, const DaysPlan(7));
    expect(wirds, hasLength(7));
    final sizes = [for (final w in wirds) index.pagesOf(w)];
    expect(sizes.reduce((a, b) => a + b), 604);
    expect(sizes.reduce((a, b) => a > b ? a : b) - sizes.reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(1));
    for (final w in wirds) {
      expect(w.lastAyah, index.lastAyahOn(index.pageOf(w.lastAyah)), reason: 'ends on a page end');
    }
    // More days than pages: one page a day.
    expect(divide(index, index.firstAyahOn(600), const DaysPlan(40)), hasLength(5));
  });

  test('rule 5: pages a day and a finish date become days', () {
    expect(daysForPagesPerDay(index, 1, 50), 13);
    expect(daysForPagesPerDay(index, 1, 604), 1);
    expect(daysForPagesPerDay(index, 1, 1), 604);
    final start = CalendarDay.parse('2026-03-01');
    expect(daysUntil(start, CalendarDay.parse('2026-03-30')), 30);
    expect(daysUntil(start, start), 1);
    expect(daysUntil(start, CalendarDay.parse('2026-02-28')), isNull);
  });

  test('rule 6: a start point off a boundary makes a shorter first wird', () {
    final start = index.quarterStarts[8] + 3; // inside Juz 2
    final wirds = divide(index, start, const MarksPlan(8));
    expect(wirds.first.firstAyah, start);
    expect(wirds.first.lastAyah, index.quarterStarts[16] - 1);
    // With days, the first wird starts in the middle of its first page.
    final days = divide(index, 105, const DaysPlan(10));
    expect(days.first.firstAyah, 105);
    expect(index.pageOf(days.first.firstAyah), index.pageOf(105));
  });

  test('rule 7: a wird counts every page it touches', () {
    expect(index.pagesOf(WirdRange(index.firstAyahOn(42), index.lastAyahOn(62))), 21);
    expect(index.pagesOf(WirdRange(index.lastAyahOn(42), index.firstAyahOn(43))), 2);
  });

  test('preview: days, the pages a day and the finish date', () {
    final p = preview(index, 1, const DaysPlan(29), CalendarDay.parse('2026-03-01'));
    expect(p.wirds, 29);
    expect(p.fewestPages, 20);
    expect(p.mostPages, 21);
    expect(p.finishDate, CalendarDay.parse('2026-03-29'));
  });

  test('the same inputs always give the same wirds', () {
    expect(divide(index, 77, const DaysPlan(100)), divide(index, 77, const DaysPlan(100)));
  });
}
