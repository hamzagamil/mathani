import '../../data/models.dart';
import '../../data/quran_repository.dart';
import 'arabic_normalizer.dart';

/// One matching ayah: its reference, the ids of the words the query matched, and how many times
/// it matched.
class SearchHit {
  const SearchHit(this.ayah, this.matchedWordIds, this.occurrences);
  final Ayah ayah;
  final Set<int> matchedWordIds;
  final int occurrences; // ≥ 1
}

class SearchResults {
  const SearchResults(this.query, this.hits, this.occurrences);
  static const empty = SearchResults('', [], 0);

  final String query; // normalised
  final List<SearchHit> hits; // Mushaf order
  final int occurrences; // total matches: the sum of each hit's occurrences, never overlapping

  int get ayahCount => hits.length;
}

/// Attached prefixes, longest first: (و|ف)? (ب|ك|ل)? (ال)?, with ل + ال written لل.
const _prefixes = [
  'وال', 'فال', 'بال', 'كال', 'ولل', 'فلل', 'وب', 'وك', 'ول', 'فب', 'فك', 'فل', 'ال', 'لل', //
  'و', 'ف', 'ب', 'ك', 'ل',
];

/// The name of Allah keeps its letters: «والله» → «الله», never «له».
final _allahWord = RegExp(r'^([وفب]?)(?:الله|اللهم)$|^([وف]?)لله$');

/// The forms a searchable word can be matched as: the word itself first, then the word without
/// each attached prefix that leaves at least 2 letters (contracts/search-matching.md).
List<String> searchStems(String word) {
  final allah = _allahWord.firstMatch(word);
  if (allah != null) {
    final prefix = allah.group(1) ?? allah.group(2)!;
    return prefix.isEmpty ? [word] : [word, word.substring(prefix.length)];
  }
  final stems = [word];
  void add(String s) {
    if (!stems.contains(s)) stems.add(s);
  }

  for (final p in _prefixes) {
    if (word.length < p.length + 2 || !word.startsWith(p)) continue;
    final rest = word.substring(p.length);
    add(rest);
    if (p.endsWith('لل')) add('ال$rest'); // «للمتقين» also matches «المتقين»
  }
  return stems;
}

/// In-memory search over the normalised imla'i text of all 6,236 ayahs, no index
/// (specs/003-fix-search-result-details/contracts/search-matching.md).
///
/// Each ayah's search text is split into searchable words, each tied to the Uthmani word it came
/// from (one Uthmani word can give two: «يَٰٓأَيُّهَا» → «يا ايها»). A match starts at the
/// beginning of a word, after any attached prefixes: every query word but the last must equal a
/// stem, and the last must begin one, so «رحم» finds «الرحمن» but «من» does not find «المؤمنين».
class SearchIndex {
  SearchIndex._(this._ayahs, this._words);

  final List<Ayah> _ayahs;

  /// Per ayah, its searchable words in order: the Uthmani word id and the word's stems.
  final List<List<(int, List<String>)>> _words;

  /// Loads the corpus and builds the stems on first use (≤ 150 ms + about 80 ms).
  static Future<SearchIndex> load(QuranRepository quran) async {
    final corpus = await quran.searchCorpus();
    return SearchIndex._(corpus.ayahs, [
      for (var i = 0; i < corpus.texts.length; i++) _searchableWords(corpus, i),
    ]);
  }

  static List<(int, List<String>)> _searchableWords(SearchCorpus corpus, int index) {
    final ayah = corpus.ayahs[index];
    final text = corpus.texts[index];
    return [
      for (var id = ayah.firstWordId; id <= ayah.lastWordId; id++)
        for (final w in text
            .substring(corpus.offsetOfWord(id),
                id < ayah.lastWordId ? corpus.offsetOfWord(id + 1) : text.length)
            .split(' '))
          if (w.isNotEmpty) (id, searchStems(w)),
    ];
  }

  SearchResults search(String query) {
    final q = normalizeArabic(query);
    if (q.isEmpty) return SearchResults.empty;
    final terms = q.split(' ');
    final last = terms.length - 1;
    final hits = <SearchHit>[];
    var occurrences = 0;
    for (var i = 0; i < _words.length; i++) {
      final words = _words[i];
      final matched = <int>{};
      var count = 0;
      for (var start = 0; start + terms.length <= words.length; start++) {
        var ok = true;
        for (var k = 0; ok && k < terms.length; k++) {
          final stems = words[start + k].$2;
          ok = k == last ? stems.any((s) => s.startsWith(terms[k])) : stems.contains(terms[k]);
        }
        if (!ok) continue;
        count++;
        for (var k = 0; k < terms.length; k++) {
          matched.add(words[start + k].$1);
        }
      }
      if (count == 0) continue;
      occurrences += count;
      hits.add(SearchHit(_ayahs[i], matched, count));
    }
    return SearchResults(q, hits, occurrences);
  }
}
