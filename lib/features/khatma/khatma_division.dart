// Dividing the Quran into wirds (specs/014 contracts/wird-division.md, research R2). Plain Dart:
// no Flutter imports and no queries, so SC-003 and SC-004 are unit tests over every plan and start.
import '../../data/models.dart';
import 'khatma_models.dart';

/// What the division needs of the Mushaf, from the ayah index the app already holds in memory:
/// each ayah's page, the 240 quarter starts and the 114 surah starts, all as ayah ids.
class QuranIndex {
  QuranIndex({
    required List<int> ayahPages,
    required List<int> quarterStarts,
    required List<int> surahStarts,
    List<int>? juzStarts,
    List<int>? ayahEndWords,
  })  : _pages = ayahPages,
        quarterStarts = List.unmodifiable(quarterStarts),
        surahStarts = List.unmodifiable(surahStarts),
        juzStarts = List.unmodifiable(
            juzStarts ?? [for (var i = 0; i < quarterStarts.length; i += 8) quarterStarts[i]]),
        _endWords = ayahEndWords {
    _pageFirst = List<int>.filled(pageCount + 2, 0);
    for (var id = ayahCount; id >= 1; id--) {
      _pageFirst[_pages[id - 1]] = id;
    }
  }

  /// From the app's ayah list (in Mushaf order) and divisions.
  factory QuranIndex.fromAyahs(List<Ayah> ayahs, List<Division> divisions) {
    final quarters = [
      for (final d in divisions)
        if (d.kind == DivisionKind.hizbQuarter) d,
    ]..sort((a, b) => a.number.compareTo(b.number));
    final juz = [
      for (final d in divisions)
        if (d.kind == DivisionKind.juz) d,
    ]..sort((a, b) => a.number.compareTo(b.number));
    final idOf = <AyahRef, int>{for (final a in ayahs) a.ref: a.id};
    final surahStarts = <int>[];
    for (final a in ayahs) {
      if (a.ayah == 1) surahStarts.add(a.id);
    }
    return QuranIndex(
      ayahPages: [for (final a in ayahs) a.page],
      quarterStarts: [for (final q in quarters) idOf[q.start]!],
      surahStarts: surahStarts,
      juzStarts: juz.isEmpty ? null : [for (final j in juz) idOf[j.start]!],
      ayahEndWords: [for (final a in ayahs) a.lastWordId],
    );
  }

  static const pageCount = 604;

  final List<int> _pages;
  final List<int>? _endWords;
  late final List<int> _pageFirst;

  /// Ayah ids of the starts of quarters 1 to 240.
  final List<int> quarterStarts;

  /// Ayah ids of the first ayah of surahs 1 to 114.
  final List<int> surahStarts;

  /// Ayah ids of the starts of juz 1 to 30.
  final List<int> juzStarts;

  int get ayahCount => _pages.length;

  /// The page on which ayah [id] starts. No ayah continues onto the next page (research R2).
  int pageOf(int id) => _pages[id - 1];

  /// The first ayah that starts on [page]. Every page has one (research R2).
  int firstAyahOn(int page) => _pageFirst[page];

  /// The last ayah on [page].
  int lastAyahOn(int page) => page >= pageCount ? ayahCount : _pageFirst[page + 1] - 1;

  /// The word id of ayah [id]'s end marker, when the index was built with words.
  int? endWordOf(int id) => _endWords?[id - 1];

  /// The number of pages a wird touches: its last page minus its first page, plus one (rule 7).
  int pagesOf(WirdRange r) => pageOf(r.lastAyah) - pageOf(r.firstAyah) + 1;
}

/// Wirds from [startAyah] to the end of the Quran, one per day, by [plan] (rules 1 to 6).
List<WirdRange> divide(QuranIndex index, int startAyah, KhatmaPlan plan) {
  RangeError.checkValueInInterval(startAyah, 1, index.ayahCount, 'startAyah');
  return switch (plan) {
    MarksPlan(:final quarters) => _byBoundaries(index, startAyah, [
        for (var k = quarters; k < index.quarterStarts.length; k += quarters)
          index.quarterStarts[k],
      ]),
    SevenPlan() => _byBoundaries(index, startAyah, [
        for (final s in const [5, 10, 17, 26, 37, 50]) index.surahStarts[s - 1],
      ]),
    DaysPlan(:final days) => _byPages(index, startAyah, days),
  };
}

/// A new wird begins at every boundary after [startAyah] (rules 2 and 3).
List<WirdRange> _byBoundaries(QuranIndex index, int startAyah, List<int> boundaries) {
  final result = <WirdRange>[];
  var first = startAyah;
  for (final b in boundaries) {
    if (b <= first) continue;
    result.add(WirdRange(first, b - 1));
    first = b;
  }
  result.add(WirdRange(first, index.ayahCount));
  return result;
}

/// Whole pages spread evenly over [days] (rule 4): wird k covers pages ⌊(k−1)·p/m⌋ to
/// ⌊k·p/m⌋ − 1 from the start point's page, with m the smaller of [days] and p.
List<WirdRange> _byPages(QuranIndex index, int startAyah, int days) {
  final startPage = index.pageOf(startAyah);
  final p = QuranIndex.pageCount - startPage + 1;
  final m = days < p ? days : p;
  final result = <WirdRange>[];
  for (var k = 1; k <= m; k++) {
    final fromPage = startPage + (k - 1) * p ~/ m;
    final toPage = startPage + k * p ~/ m - 1;
    result.add(WirdRange(
      k == 1 ? startAyah : index.firstAyahOn(fromPage),
      index.lastAyahOn(toPage),
    ));
  }
  return result;
}

/// The number of days for "[pagesPerDay] pages a day" from [startAyah] (rule 5).
int daysForPagesPerDay(QuranIndex index, int startAyah, int pagesPerDay) {
  final p = QuranIndex.pageCount - index.pageOf(startAyah) + 1;
  final days = (p + pagesPerDay - 1) ~/ pagesPerDay;
  return days < 1 ? 1 : days;
}

/// The number of days for a plan that finishes on [finish], started on [start] (rule 5). Null
/// when [finish] is before [start].
int? daysUntil(CalendarDay start, CalendarDay finish) {
  final days = finish.daysSince(start) + 1;
  if (days < 1) return null;
  return days > KhatmaPlan.maxDays ? KhatmaPlan.maxDays : days;
}

/// What the plan sheet shows before the reader confirms (FR-002).
class WirdPreview {
  const WirdPreview({
    required this.wirds,
    required this.fewestPages,
    required this.mostPages,
    required this.finishDate,
  });

  final int wirds;
  final int fewestPages;
  final int mostPages;
  final CalendarDay finishDate;
}

WirdPreview preview(QuranIndex index, int startAyah, KhatmaPlan plan, CalendarDay startDate) =>
    previewOf(index, divide(index, startAyah, plan), startDate);

WirdPreview previewOf(QuranIndex index, List<WirdRange> wirds, CalendarDay startDate) {
  var fewest = 1 << 30, most = 0;
  for (final w in wirds) {
    final pages = index.pagesOf(w);
    if (pages < fewest) fewest = pages;
    if (pages > most) most = pages;
  }
  return WirdPreview(
    wirds: wirds.length,
    fewestPages: fewest,
    mostPages: most,
    finishDate: startDate.addDays(wirds.length - 1),
  );
}

/// How a wird is named: by a Mushaf mark when it is exactly one, otherwise by its number
/// (data-model.md › Values worked out).
sealed class WirdName {
  const WirdName();
}

class JuzName extends WirdName {
  const JuzName(this.juz);
  final int juz;
}

class HizbName extends WirdName {
  const HizbName(this.hizb);
  final int hizb;
}

/// Quarter [quarter] (1 to 4) of hizb [hizb].
class QuarterName extends WirdName {
  const QuarterName(this.hizb, this.quarter);
  final int hizb;
  final int quarter;
}

class NumberName extends WirdName {
  const NumberName(this.number);
  final int number;
}

/// The name of wird [number] covering [range].
WirdName wirdName(QuranIndex index, WirdRange range, int number) {
  int? exactly(List<int> starts) {
    for (var i = 0; i < starts.length; i++) {
      final end = i + 1 < starts.length ? starts[i + 1] - 1 : index.ayahCount;
      if (starts[i] == range.firstAyah && end == range.lastAyah) return i + 1;
    }
    return null;
  }

  final juz = exactly(index.juzStarts);
  if (juz != null) return JuzName(juz);
  final hizb = exactly([
    for (var i = 0; i < index.quarterStarts.length; i += 4) index.quarterStarts[i],
  ]);
  if (hizb != null) return HizbName(hizb);
  final quarter = exactly(index.quarterStarts);
  if (quarter != null) return QuarterName((quarter + 3) ~/ 4, (quarter - 1) % 4 + 1);
  return NumberName(number);
}
