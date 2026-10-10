// DEVELOPMENT ONLY. Generates stand-ins for the three QUL files from Tanzil text, in QUL's
// documented SQLite format, so the app can be built and tested before the QUL downloads exist.
//
// Page starts follow the Madinah Mushaf (Tanzil metadata), but LINE BREAKS ARE APPROXIMATE:
// words are spread evenly over the lines. A database built from these files is marked
// `dev_layout=true` and `verify_quran.dart --release` rejects it.
//
// Usage: dart run tool/make_dev_sources.dart
import 'dart:io';

import 'package:mathani/features/search/arabic_normalizer.dart';
import 'package:sqlite3/sqlite3.dart';

import 'src/sources.dart';

const _linesPerPage = 15;

void main() {
  checkSources([uthmaniXml, simpleCleanXml, metadataXml]);
  final meta = TanzilMetadata.load('$sourcesDir/$metadataXml');
  final uthmani = loadTanzilText('$sourcesDir/$uthmaniXml');
  final simple = loadTanzilText('$sourcesDir/$simpleCleanXml');
  Directory(devDir).createSync(recursive: true);

  // Words, with an ayah-end token (Eastern Arabic number) closing each ayah, as QUL does.
  final words = <({int id, int sura, int aya, String text, String imlaei})>[];
  final ayahFirstWord = <String, int>{};
  var fallbackAyahs = 0;
  for (var i = 0; i < uthmani.length; i++) {
    final u = uthmani[i];
    final uw = tanzilWords(u.text);
    var sw = simple[i].text.split(' ').where((t) => t.isNotEmpty).toList();
    if (sw.length != uw.length) {
      sw = [for (final w in uw) normalizeArabic(w)];
      fallbackAyahs++;
    }
    ayahFirstWord['${u.sura}:${u.aya}'] = words.length + 1;
    for (var k = 0; k < uw.length; k++) {
      words.add((id: words.length + 1, sura: u.sura, aya: u.aya, text: uw[k], imlaei: sw[k]));
    }
    final end = easternDigits(u.aya);
    words.add((id: words.length + 1, sura: u.sura, aya: u.aya, text: end, imlaei: end));
  }

  _writeWords('$devDir/$qulScriptDb', words.map((w) => (w.id, w.sura, w.aya, w.text)));
  _writeWords('$devDir/$qulImlaeiDb', words.map((w) => (w.id, w.sura, w.aya, w.imlaei)));

  // Layout: page p holds the words from its start ayah up to the next page's start ayah.
  final layout = sqlite3.open('$devDir/$qulLayoutDb');
  layout.execute('DROP TABLE IF EXISTS pages');
  layout.execute('''CREATE TABLE pages (page_number INTEGER, line_number INTEGER,
      line_type TEXT, is_centered INTEGER, first_word_id INTEGER, last_word_id INTEGER,
      surah_number INTEGER)''');
  final insert = layout.prepare('INSERT INTO pages VALUES (?,?,?,?,?,?,?)');
  layout.execute('BEGIN');
  for (var p = 0; p < meta.pages.length; p++) {
    final start = ayahFirstWord['${meta.pages[p].sura}:${meta.pages[p].aya}']!;
    final end = p + 1 < meta.pages.length
        ? ayahFirstWord['${meta.pages[p + 1].sura}:${meta.pages[p + 1].aya}']! - 1
        : words.length;
    final pageWords = words.sublist(start - 1, end);

    // Split into runs per surah; each new surah (ayah 1) gets a name line and, except for
    // surahs 1 and 9, a basmala line.
    final runs = <List<({int id, int sura, int aya, String text, String imlaei})>>[];
    for (final w in pageWords) {
      if (runs.isEmpty || runs.last.last.sura != w.sura) runs.add([]);
      runs.last.add(w);
    }
    var headers = 0;
    for (final r in runs) {
      if (r.first.aya == 1 && words[r.first.id - 1].id == ayahFirstWord['${r.first.sura}:1']) {
        headers += r.first.sura == 1 || r.first.sura == 9 ? 1 : 2;
      }
    }
    final ayahLines = (_linesPerPage - headers).clamp(1, _linesPerPage);
    final totalChars = pageWords.fold<int>(0, (n, w) => n + w.text.length + 1);
    final target = totalChars / ayahLines;

    var line = 0;
    void addLine(String type, int centered, int? first, int? last, int? surah) =>
        insert.execute([p + 1, ++line, type, centered, first, last, surah]);

    for (final run in runs) {
      final startsSurah = run.first.aya == 1 && run.first.id == ayahFirstWord['${run.first.sura}:1'];
      if (startsSurah) {
        addLine('surah_name', 1, null, null, run.first.sura);
        if (run.first.sura != 1 && run.first.sura != 9) {
          addLine('basmallah', 1, null, null, run.first.sura);
        }
      }
      var lineStart = 0;
      var chars = 0;
      for (var k = 0; k < run.length; k++) {
        chars += run[k].text.length + 1;
        final isLast = k == run.length - 1;
        if (chars >= target || isLast) {
          final centered = p < 2 || (isLast && chars < target * 0.6) ? 1 : 0;
          addLine('ayah', centered, run[lineStart].id, run[k].id, null);
          lineStart = k + 1;
          chars = 0;
        }
      }
    }
  }
  layout.execute('COMMIT');
  insert.close();
  layout.close();

  stdout.writeln('Wrote dev sources to $devDir: ${words.length} words, ${meta.pages.length} pages '
      '($fallbackAyahs ayahs used normalised Uthmani for search forms). Line breaks are '
      'APPROXIMATE; development only.');
}

void _writeWords(String path, Iterable<(int, int, int, String)> rows) {
  final db = sqlite3.open(path);
  db.execute('DROP TABLE IF EXISTS words');
  db.execute('CREATE TABLE words (word_index INTEGER PRIMARY KEY, word_key TEXT, surah INTEGER, '
      'ayah INTEGER, text TEXT)');
  final stmt = db.prepare('INSERT INTO words VALUES (?,?,?,?,?)');
  db.execute('BEGIN');
  for (final (id, sura, aya, text) in rows) {
    stmt.execute([id, '$sura:$aya', sura, aya, text]);
  }
  db.execute('COMMIT');
  stmt.close();
  db.close();
}
