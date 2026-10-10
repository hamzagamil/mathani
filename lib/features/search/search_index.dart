import '../../data/models.dart';
import '../../data/quran_repository.dart';
import 'arabic_normalizer.dart';

/// One matching ayah: its reference and the ids of the words the query matched.
class SearchHit {
  const SearchHit(this.ayah, this.matchedWordIds);
  final Ayah ayah;
  final Set<int> matchedWordIds;
}

class SearchResults {
  const SearchResults(this.query, this.hits, this.occurrences);
  static const empty = SearchResults('', [], 0);

  final String query; // normalised
  final List<SearchHit> hits; // Mushaf order
  final int occurrences; // total matches, possibly several per ayah
}

/// In-memory search over the normalised imla'i text of all 6,236 ayahs (research R7): a
/// substring scan, no index. Match ranges map back to Uthmani words through each word's offset
/// into its ayah's search text, so results can highlight the matched words.
class SearchIndex {
  SearchIndex._(this._corpus);

  final SearchCorpus _corpus;

  /// Loads the corpus on first use (≤ 150 ms; contracts/quran-db.md).
  static Future<SearchIndex> load(QuranRepository quran) async =>
      SearchIndex._(await quran.searchCorpus());

  SearchResults search(String query) {
    final q = normalizeArabic(query);
    if (q.isEmpty) return SearchResults.empty;
    final hits = <SearchHit>[];
    var occurrences = 0;
    for (var i = 0; i < _corpus.texts.length; i++) {
      final text = _corpus.texts[i];
      var at = text.indexOf(q);
      if (at < 0) continue;
      final ayah = _corpus.ayahs[i];
      final matched = <int>{};
      while (at >= 0) {
        occurrences++;
        _addWordsInRange(ayah, at, at + q.length, text.length, matched);
        at = text.indexOf(q, at + 1);
      }
      hits.add(SearchHit(ayah, matched));
    }
    return SearchResults(q, hits, occurrences);
  }

  /// Adds the ids of [ayah]'s words whose search-text range overlaps [start, end).
  void _addWordsInRange(Ayah ayah, int start, int end, int textLength, Set<int> out) {
    for (var id = ayah.firstWordId; id <= ayah.lastWordId; id++) {
      final wordStart = _corpus.offsetOfWord(id);
      final wordEnd = id < ayah.lastWordId ? _corpus.offsetOfWord(id + 1) : textLength;
      if (wordStart < end && wordEnd > start && wordEnd > wordStart) out.add(id);
    }
  }
}
