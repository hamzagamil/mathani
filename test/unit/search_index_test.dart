// Search matching and counts on the real corpus (specs/003-fix-search-result-details).
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/data/quran_repository.dart';
import 'package:mathani/features/search/arabic_normalizer.dart';
import 'package:mathani/features/search/search_index.dart';

import '../support/harness.dart';

void main() {
  testWidgets('matching rule (contracts/search-matching.md)', (tester) async {
    late QuranRepository quran;
    late SearchIndex index;
    await tester.runAsync(() async {
      quran = (await openTestReader()).quran;
      final watch = Stopwatch()..start();
      index = await SearchIndex.load(quran);
      // ignore: avoid_print
      print('SearchIndex.load: ${watch.elapsedMilliseconds} ms');
    });

    /// Normalised forms of the highlighted words of every hit.
    Future<Set<String>> highlighted(SearchResults r) async {
      final out = <String>{};
      await tester.runAsync(() async {
        for (final h in r.hits) {
          for (final w in await quran.wordsOf(h.ayah.ref)) {
            if (h.matchedWordIds.contains(w.id)) out.add(normalizeArabic(w.text));
          }
        }
      });
      return out;
    }

    SearchResults timed(String q) {
      final watch = Stopwatch()..start();
      final r = index.search(q);
      expect(watch.elapsedMilliseconds, lessThan(100), reason: '«$q» took too long');
      return r;
    }

    final min = timed('من');
    final minWords = await highlighted(min);
    expect(minWords, containsAll(['من', 'فمن', 'ومن']));
    expect(minWords.any((w) => w.startsWith('منهم')), isTrue);
    expect(minWords.where((w) => w.contains('مومنين')), isEmpty);

    final allah = await highlighted(timed('الله'));
    expect(allah, containsAll(['الله', 'والله', 'بالله', 'اللهم']));

    expect(await highlighted(timed('لله')), isNot(contains('الله')));
    final lahu = await highlighted(timed('له'));
    expect(lahu, isNot(contains('الله')));
    expect(lahu, isNot(contains('لله')));

    final rahm = timed('رحم');
    expect(rahm.hits.map((h) => h.ayah.ref), contains(const AyahRef(1, 1)));
    expect(await highlighted(rahm), contains('الرحمن'));

    for (final q in ['المتقين', 'متقين']) {
      expect(timed(q).hits.map((h) => h.ayah.ref), contains(const AyahRef(2, 2)), reason: q);
    }

    final ikhlas = timed('قل هو الله احد');
    expect(ikhlas.hits.map((h) => h.ayah.ref), [const AyahRef(112, 1)]);

    // «ال» finds words that start with it, also after attached prefixes («والده») and after «لل».
    // Highlights are checked in Uthmani spelling, which can drop the alef («وَٰلِدَهُۥ»), so only
    // check words spelled the same in both.
    expect(await highlighted(timed('ال')), containsAll(['الحمد', 'والارض', 'للمتقين']));

    // Regression counts, ayat / occurrences (contract).
    void counts(String q, int ayat, int occurrences, {int tolerance = 0}) {
      final r = timed(q);
      // ignore: avoid_print
      print('COUNT «$q»: ${r.ayahCount} / ${r.occurrences}');
      expect(r.ayahCount, inInclusiveRange(ayat - tolerance, ayat + tolerance), reason: q);
      expect(r.occurrences, inInclusiveRange(occurrences - tolerance, occurrences + tolerance),
          reason: q);
    }

    counts('من', 2582, 4075);
    counts('يا ايها الذين امنوا', 89, 89);
    counts('الرحمن الرحيم', 6, 6);
    counts('المتقين', 43, 43);
    counts('الله', 1737, 2547, tolerance: 15);
  });

  testWidgets('counts: ayat equal rows, occurrences equal the matches per row', (tester) async {
    final index = (await tester.runAsync(() async => SearchIndex.load((await openTestReader()).quran)))!;

    for (final q in ['الله', 'من', 'الرحمن الرحيم', 'ذلك', 'الصلاة']) {
      final r = index.search(q);
      expect(r.hits, isNotEmpty, reason: q);
      expect(r.ayahCount, r.hits.length, reason: q);
      expect(r.occurrences, r.hits.fold<int>(0, (s, h) => s + h.occurrences), reason: q);
      expect(r.occurrences, greaterThanOrEqualTo(r.ayahCount), reason: q);
      for (final h in r.hits) {
        expect(h.occurrences, greaterThanOrEqualTo(1), reason: '$q ${h.ayah.ref}');
        expect(h.matchedWordIds, isNotEmpty, reason: '$q ${h.ayah.ref}');
        for (final id in h.matchedWordIds) {
          expect(id, inInclusiveRange(h.ayah.firstWordId, h.ayah.lastWordId), reason: '$q ${h.ayah.ref}');
        }
      }
    }
  });
}
