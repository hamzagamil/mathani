// Builds assets/db/quran.db from licensed sources (tool/README.md).
// Schema: specs/001-quran-mushaf-reader/contracts/quran-db.md. The Quran text is copied
// verbatim from the sources; nothing here may alter a letter, diacritic or mark (FR-002).
//
// Usage: dart run tool/build_quran_db.dart [--dev] [--record] [--font=amiri-quran|kfgqpc-hafs]
//   --dev     use the Tanzil-derived stand-ins from tool/make_dev_sources.dart (not for release)
//   --record  record checksums of newly downloaded sources in tool/sources.lock.json
import 'dart:io';

import 'package:mathani/features/search/arabic_normalizer.dart';
import 'package:sqlite3/sqlite3.dart';

import 'src/sources.dart';

void main(List<String> args) {
  final dev = args.contains('--dev');
  final font = args
          .firstWhere((a) => a.startsWith('--font='), orElse: () => '--font=amiri-quran')
          .split('=')
          .last;
  checkSources(
    [uthmaniXml, metadataXml, if (!dev) ...[qulLayoutDb, qulScriptDb, qulImlaeiDb]],
    record: args.contains('--record'),
  );
  final qulDir = dev ? devDir : sourcesDir;
  for (final f in [qulLayoutDb, qulScriptDb, qulImlaeiDb]) {
    if (!File('$qulDir/$f').existsSync()) {
      _fail('Missing $qulDir/$f${dev ? ': run tool/make_dev_sources.dart first' : ''}.');
    }
  }

  final meta = TanzilMetadata.load('$sourcesDir/$metadataXml');

  // --- Words (verbatim) -------------------------------------------------------------------
  final script = sqlite3.open('$qulDir/$qulScriptDb', mode: OpenMode.readOnly);
  final wordRows = script.select('SELECT word_index, surah, ayah, text FROM words ORDER BY word_index');
  final imlaeiDb = sqlite3.open('$qulDir/$qulImlaeiDb', mode: OpenMode.readOnly);
  final imlaei = {
    for (final r in imlaeiDb.select('SELECT word_index, surah, ayah, text FROM words'))
      r['word_index'] as int: r,
  };
  if (imlaei.length != wordRows.length) {
    _fail('Word counts differ: script ${wordRows.length}, imla\'i ${imlaei.length}.');
  }

  final words = <_Word>[];
  for (final r in wordRows) {
    final id = r['word_index'] as int;
    if (id != words.length + 1) _fail('Word ids are not contiguous at $id.');
    final s = r['surah'] as int, a = r['ayah'] as int;
    final im = imlaei[id];
    if (im == null || im['surah'] != s || im['ayah'] != a) {
      _fail('Word $id: imla\'i script disagrees on surah:ayah.');
    }
    final position = words.isNotEmpty && words.last.surah == s && words.last.ayah == a
        ? words.last.position + 1
        : 1;
    final text = r['text'] as String;
    words.add(_Word(id, s, a, position, text, im['text'] as String, isAyahEndToken(text)));
  }

  // --- Ayahs ------------------------------------------------------------------------------
  final ayahs = <_Ayah>[];
  for (final w in words) {
    if (ayahs.isEmpty || ayahs.last.surah != w.surah || ayahs.last.ayah != w.ayah) {
      ayahs.add(_Ayah(ayahs.length + 1, w.surah, w.ayah, w.id));
    }
    ayahs.last.lastWordId = w.id;
  }
  if (ayahs.length != 6236) _fail('Expected 6236 ayahs, found ${ayahs.length}.');
  final ayahIndex = {for (final a in ayahs) '${a.surah}:${a.ayah}': a};
  for (final s in meta.suras) {
    if (ayahIndex['${s.index}:${s.ayas}'] == null || ayahIndex['${s.index}:${s.ayas + 1}'] != null) {
      _fail('Surah ${s.index}: ayah count differs from Tanzil (${s.ayas}).');
    }
  }

  // --- Layout lines; page of every word ------------------------------------------------------
  final layout = sqlite3.open('$qulDir/$qulLayoutDb', mode: OpenMode.readOnly);
  final lines = layout.select('SELECT page_number, line_number, line_type, is_centered, '
      'first_word_id, last_word_id, surah_number FROM pages ORDER BY page_number, line_number');
  final wordPage = List<int>.filled(words.length + 1, 0);
  for (final l in lines) {
    final first = _int(l['first_word_id']), last = _int(l['last_word_id']);
    if (l['line_type'] == 'ayah' && first != null && last != null) {
      for (var id = first; id <= last; id++) {
        wordPage[id] = l['page_number'] as int;
      }
    }
  }
  for (final a in ayahs) {
    a.page = wordPage[a.firstWordId];
    if (a.page == 0) _fail('Ayah ${a.surah}:${a.ayah} is on no Mushaf line.');
  }

  // Cross-check page starts with Tanzil's Madinah Mushaf page table (warnings only: the line
  // layout is authoritative for this app).
  var pageMismatches = 0;
  for (final p in meta.pages) {
    if (ayahIndex['${p.sura}:${p.aya}']!.page != p.index) pageMismatches++;
  }

  // --- Juz, hizb quarter, sajdah ------------------------------------------------------------
  void assignStarts(List<TanzilRef> starts, void Function(_Ayah, int) set) {
    var k = 0;
    for (final a in ayahs) {
      while (k + 1 < starts.length &&
          (starts[k + 1].sura < a.surah ||
              (starts[k + 1].sura == a.surah && starts[k + 1].aya <= a.ayah))) {
        k++;
      }
      set(a, starts[k].index);
    }
  }

  assignStarts(meta.juzs, (a, n) => a.juz = n);
  assignStarts(meta.quarters, (a, n) => a.quarter = n);
  for (final s in meta.sajdas) {
    ayahIndex['${s.sura}:${s.aya}']!.sajdah = true;
  }

  // --- Search text and word offsets (research R7) -------------------------------------------
  final searchText = <int, String>{};
  for (final a in ayahs) {
    final buf = StringBuffer();
    for (var id = a.firstWordId; id <= a.lastWordId; id++) {
      final w = words[id - 1];
      if (w.isAyahEnd) {
        w.searchOffset = buf.length;
        continue;
      }
      final n = normalizeArabic(w.imlaei);
      if (n.isNotEmpty && buf.isNotEmpty) buf.write(' ');
      w.searchOffset = buf.length;
      buf.write(n);
    }
    searchText[a.id] = buf.toString();
  }

  // --- Write the database --------------------------------------------------------------------
  final out = File(outputDb);
  out.parent.createSync(recursive: true);
  if (out.existsSync()) out.deleteSync();
  final db = sqlite3.open(outputDb);
  db.execute(_schema);
  db.execute('BEGIN');

  final metaRows = {
    'schema_version': '1.0',
    'built_at': DateTime.now().toUtc().toIso8601String(),
    'font': font,
    'dev_layout': '$dev',
    'max_line_width_em': '0', // set by tool/measure_line_widths_test.dart
    'source_tanzil_uthmani_sha256': sha256Of('$sourcesDir/$uthmaniXml'),
    'source_tanzil_metadata_sha256': sha256Of('$sourcesDir/$metadataXml'),
    'source_qul_layout_sha256': sha256Of('$qulDir/$qulLayoutDb'),
    'source_qul_script_sha256': sha256Of('$qulDir/$qulScriptDb'),
    'source_qul_imlaei_sha256': sha256Of('$qulDir/$qulImlaeiDb'),
    'attribution_tanzil': 'Tanzil Project — https://tanzil.net',
    'attribution_qul': 'Quranic Universal Library (QUL) — https://qul.tarteel.ai',
    'attribution_kfgqpc': 'King Fahd Glorious Quran Printing Complex',
  };
  final insMeta = db.prepare('INSERT INTO meta VALUES (?, ?)');
  metaRows.forEach((k, v) => insMeta.execute([k, v]));

  final insSurah = db.prepare('INSERT INTO surahs VALUES (?, ?, ?, ?, ?, ?)');
  for (final s in meta.suras) {
    insSurah.execute([
      s.index, s.name, s.tname, s.ayas, s.type == 'Meccan' ? 'makki' : 'madani',
      ayahIndex['${s.index}:1']!.page,
    ]);
  }

  final insAyah = db.prepare('INSERT INTO ayahs VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  for (final a in ayahs) {
    insAyah.execute([
      a.id, a.surah, a.ayah, a.page, a.juz, a.quarter, a.sajdah ? 1 : 0,
      a.firstWordId, a.lastWordId, searchText[a.id],
    ]);
  }

  final insWord = db.prepare('INSERT INTO words VALUES (?, ?, ?, ?, ?, ?, ?)');
  for (final w in words) {
    insWord.execute([w.id, w.surah, w.ayah, w.position, w.text, w.isAyahEnd ? 1 : 0, w.searchOffset]);
  }

  final insLine = db.prepare('INSERT INTO mushaf_lines VALUES (?, ?, ?, ?, ?, ?, ?)');
  for (final l in lines) {
    final type = l['line_type'] as String;
    insLine.execute([
      l['page_number'], l['line_number'], type, _int(l['is_centered']) == 1 ? 1 : 0,
      type == 'ayah' ? _int(l['first_word_id']) : null,
      type == 'ayah' ? _int(l['last_word_id']) : null,
      type == 'ayah' ? null : _int(l['surah_number']),
    ]);
  }

  final insDiv = db.prepare('INSERT INTO divisions VALUES (?, ?, ?, ?, ?, ?)');
  String opening(_Ayah a) => [
        for (var id = a.firstWordId; id <= a.lastWordId; id++)
          if (!words[id - 1].isAyahEnd) words[id - 1].text,
      ].take(4).join(' ');
  for (final (kind, refs) in [('juz', meta.juzs), ('hizb_quarter', meta.quarters)]) {
    for (final r in refs) {
      final a = ayahIndex['${r.sura}:${r.aya}']!;
      insDiv.execute([kind, r.index, r.sura, r.aya, a.page, opening(a)]);
    }
  }

  db.execute('COMMIT');
  for (final s in [insMeta, insSurah, insAyah, insWord, insLine, insDiv]) {
    s.close();
  }
  db.execute('VACUUM');
  db.close();
  for (final d in [script, imlaeiDb, layout]) {
    d.close();
  }
  File(outputVersion).writeAsStringSync('${sha256Of(outputDb)}\n');

  stdout.writeln('Wrote $outputDb: ${ayahs.length} ayahs, ${words.length} words, '
      '${lines.length} lines${dev ? ' (DEV LAYOUT — not for release)' : ''}.');
  if (pageMismatches > 0) {
    stdout.writeln('WARNING: $pageMismatches page starts differ from Tanzil\'s page table.');
  }
  stdout.writeln('Next: flutter test tool/measure_line_widths_test.dart, then '
      'dart run tool/verify_quran.dart${dev ? '' : ' --release'}');
}

class _Word {
  _Word(this.id, this.surah, this.ayah, this.position, this.text, this.imlaei, this.isAyahEnd);
  final int id, surah, ayah, position;
  final String text, imlaei;
  final bool isAyahEnd;
  int searchOffset = 0;
}

class _Ayah {
  _Ayah(this.id, this.surah, this.ayah, this.firstWordId);
  final int id, surah, ayah, firstWordId;
  late int lastWordId;
  int page = 0, juz = 0, quarter = 0;
  bool sajdah = false;
}

int? _int(Object? v) => v == null ? null : (v is int ? v : int.tryParse('$v'));

Never _fail(String message) {
  stderr.writeln('ERROR: $message');
  exit(1);
}

const _schema = '''
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE surahs (
  number INTEGER PRIMARY KEY, name_ar TEXT NOT NULL, name_translit TEXT NOT NULL,
  ayah_count INTEGER NOT NULL,
  revelation TEXT NOT NULL CHECK (revelation IN ('makki','madani')),
  start_page INTEGER NOT NULL);
CREATE TABLE ayahs (
  id INTEGER PRIMARY KEY, surah INTEGER NOT NULL REFERENCES surahs(number),
  ayah INTEGER NOT NULL, page INTEGER NOT NULL, juz INTEGER NOT NULL,
  hizb_quarter INTEGER NOT NULL, sajdah INTEGER NOT NULL DEFAULT 0,
  first_word_id INTEGER NOT NULL, last_word_id INTEGER NOT NULL, search_text TEXT NOT NULL,
  UNIQUE (surah, ayah));
CREATE INDEX ayahs_page ON ayahs(page);
CREATE TABLE words (
  id INTEGER PRIMARY KEY, surah INTEGER NOT NULL, ayah INTEGER NOT NULL,
  position INTEGER NOT NULL, text_uthmani TEXT NOT NULL,
  is_ayah_end INTEGER NOT NULL DEFAULT 0, search_offset INTEGER NOT NULL);
CREATE TABLE mushaf_lines (
  page INTEGER NOT NULL, line INTEGER NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('ayah','surah_name','basmallah')),
  centered INTEGER NOT NULL, first_word_id INTEGER, last_word_id INTEGER, surah INTEGER,
  PRIMARY KEY (page, line)) WITHOUT ROWID;
CREATE TABLE divisions (
  kind TEXT NOT NULL CHECK (kind IN ('juz','hizb_quarter')), number INTEGER NOT NULL,
  start_surah INTEGER NOT NULL, start_ayah INTEGER NOT NULL, start_page INTEGER NOT NULL,
  opening_words TEXT NOT NULL, PRIMARY KEY (kind, number)) WITHOUT ROWID;
''';
