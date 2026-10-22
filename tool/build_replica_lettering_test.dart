// Builds the printed-lettering data (specs/002-print-like-mushaf-page, User Story 4): the King
// Fahd Complex Madinah Mushaf page fonts, edition V2 (1421 AH), bundled in the app.
// Run after tool/compare_layouts.dart (which writes the glyph codes):
//   flutter test tool/build_replica_lettering_test.dart
//
// Inputs (tool/sources, gitignored):
//   qcf-v2/p1.ttf … p604.ttf   the page fonts, one per page
//   qcf-v2-words.json          word id → [page, line, glyphs] in the V2 edition
// Outputs:
//   assets/qcf/p001.ttf.gz …   the page fonts, gzip-compressed (inflated with dart:io at runtime)
//   quran.db replica_lines     the V2 edition's lines: its own line breaks, and its own placement
//                              of surah titles (36 pages put a title at the foot of the page)
//   quran.db replica_glyphs    the glyphs to draw for each word ('' when the previous word's
//                              glyph already covers it, as in «بَعْدَ مَا»)
//   meta replica_edition, replica_target_em, replica_space_em
//
// Fails unless every word has a glyph, every page keeps its words and line count, and the
// surah titles and basmalas fill exactly the lines left without words.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'src/sources.dart' show outputDb, outputVersion, sha256Of, sourcesDir;

const _probe = 100.0;
const _edition = 'kfgqpc-v2-1421';

/// A line narrower than this share of the target is centred, as in print (surah ends, pages 1-2).
const _centreBelow = 0.85;

void main() {
  test('build printed lettering', () async {
    final db = sqlite3.open(outputDb);
    final source = (jsonDecode(File('$sourcesDir/qcf-v2-words.json').readAsStringSync()) as Map)
        .map((k, v) => MapEntry(int.parse(k as String), v as List));

    final allWords = [for (final r in db.select('SELECT id FROM words ORDER BY id')) r['id'] as int];
    final missing = allWords.where((id) => !source.containsKey(id)).toList();
    expect(missing, isEmpty, reason: 'words without a glyph: ${missing.take(10)}');

    // Our non-ayah lines in Mushaf order: the V2 edition has the same titles and basmalas in the
    // same order, only sometimes on the previous page.
    final ourLines = db.select('SELECT page, line, type, surah FROM mushaf_lines ORDER BY page, line');
    final lineCount = <int, int>{};
    for (final r in ourLines) {
      lineCount[r['page'] as int] = math.max(lineCount[r['page'] as int] ?? 0, r['line'] as int);
    }
    final titles = [
      for (final r in ourLines)
        if (r['type'] != 'ayah') (r['type'] as String, r['surah'] as int?),
    ];

    // V2 lines: page → line → word ids. The source places a few ayah-end markers on a
    // neighbouring line; in print the number always follows the ayah's last word, so a marker
    // takes its word's line.
    final ayahEnds = {for (final r in db.select('SELECT id FROM words WHERE is_ayah_end = 1')) r['id'] as int};
    final v2 = <int, Map<int, List<int>>>{};
    var fixedMarkers = 0;
    for (final id in allWords) {
      final e = source[id]!;
      final before = source[id - 1];
      if (ayahEnds.contains(id) && before != null && before[0] == e[0] && before[1] != e[1]) {
        e[1] = before[1];
        fixedMarkers++;
      }
      (v2.putIfAbsent(e[0] as int, () => {})[e[1] as int] ??= []).add(id);
    }
    print('ayah-end markers moved to their word\'s line: $fixedMarkers');

    final rows = <List<Object?>>[];
    var nextTitle = 0;
    for (var page = 1; page <= 604; page++) {
      final lines = v2[page]!;
      expect(lines.keys.reduce(math.max), lessThanOrEqualTo(lineCount[page]!), reason: 'page $page');
      for (var line = 1; line <= lineCount[page]!; line++) {
        final ids = lines[line];
        if (ids == null) {
          expect(nextTitle, lessThan(titles.length), reason: 'page $page line $line: no title left');
          final (type, surah) = titles[nextTitle++];
          rows.add([page, line, type, 1, null, null, surah]);
        } else {
          ids.sort();
          expect(ids.last - ids.first + 1, ids.length, reason: 'page $page line $line not contiguous');
          rows.add([page, line, 'ayah', 0, ids.first, ids.last, null]);
        }
      }
    }
    expect(nextTitle, titles.length, reason: 'titles left over');

    // Measure every line in its page font, to size the lettering and centre short lines.
    var target = 0.0;
    final spaces = <double>[];
    final natural = <(int, int), double>{};
    final lineWords = <(int, int), (double, int)>{}; // (glyph widths, gaps)
    // Register every page font first: measuring right after registering a font can fall back to
    // another page's font while the engine catches up, which made some lines look 40% wider.
    for (var page = 1; page <= 604; page++) {
      final family = 'qcf_p${page.toString().padLeft(3, '0')}';
      final bytes = File('$sourcesDir/qcf-v2/p$page.ttf').readAsBytesSync();
      await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      File('assets/qcf/p${page.toString().padLeft(3, '0')}.ttf.gz')
        ..createSync(recursive: true)
        ..writeAsBytesSync(GZipCodec(level: 9).encode(bytes));
    }
    for (var page = 1; page <= 604; page++) {
      final family = 'qcf_p${page.toString().padLeft(3, '0')}';
      double width(String s) {
        final p = TextPainter(
          text: TextSpan(text: s, style: TextStyle(fontFamily: family, fontSize: _probe)),
          textDirection: TextDirection.rtl,
        )..layout();
        final w = p.width;
        p.dispose();
        return w;
      }

      final pageSpace = width(' ');
      spaces.add(pageSpace);
      for (final row in rows.where((r) => r[0] == page && r[2] == 'ayah')) {
        final glyphs = [
          for (var id = row[4]! as int; id <= (row[5]! as int); id++)
            if ((source[id]![2] as String).isNotEmpty) source[id]![2] as String,
        ];
        final words = glyphs.fold<double>(0, (s, g) => s + width(g));
        if (words > 18 * _probe) {
          print('WIDE $page:${row[1]} ${(words / _probe).toStringAsFixed(1)} em: '
              '${glyphs.map((g) => '${g.runes.map((c) => c.toRadixString(16)).join('+')}=${(width(g) / _probe).toStringAsFixed(2)}').join(' ')}');
        }
        final gaps = glyphs.length - 1;
        lineWords[(page, row[1]! as int)] = (words, gaps);
      }
    }
    // A few page fonts have a much wider space glyph, so gaps use the median space.
    final space = (spaces..sort())[spaces.length ~/ 2];
    for (final MapEntry(key: at, value: (words, gaps)) in lineWords.entries) {
      natural[at] = words + gaps * space;
      // Fill to the widest line with its gaps at half a space, shrunk by the 5% a line may lose.
      target = math.max(target, (words + gaps * space * 0.5) * 0.95);
    }
    final sorted = natural.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    String at(double q) => (sorted[((sorted.length - 1) * q).round()].value / _probe).toStringAsFixed(2);
    print('line widths (em): p5 ${at(.05)}, p50 ${at(.5)}, p95 ${at(.95)}, p99 ${at(.99)}, '
        'widest ${sorted.reversed.take(5).map((e) => '${e.key.$1}:${e.key.$2}=${(e.value / _probe).toStringAsFixed(1)}').join(' ')}');
    for (final row in rows.where((r) => r[2] == 'ayah')) {
      final w = natural[(row[0]! as int, row[1]! as int)]!;
      if (w < target * _centreBelow) row[3] = 1;
    }

    db.execute('DROP TABLE IF EXISTS replica_lines');
    db.execute('DROP TABLE IF EXISTS replica_glyphs');
    db.execute('''CREATE TABLE replica_lines (
      page INTEGER NOT NULL, line INTEGER NOT NULL,
      type TEXT NOT NULL CHECK (type IN ('ayah','surah_name','basmallah')),
      centered INTEGER NOT NULL, first_word_id INTEGER, last_word_id INTEGER, surah INTEGER,
      PRIMARY KEY (page, line)) WITHOUT ROWID''');
    db.execute('CREATE TABLE replica_glyphs (word_id INTEGER PRIMARY KEY, glyphs TEXT NOT NULL)');
    db.execute('BEGIN');
    final insLine = db.prepare('INSERT INTO replica_lines VALUES (?, ?, ?, ?, ?, ?, ?)');
    for (final r in rows) {
      insLine.execute(r);
    }
    final insGlyph = db.prepare('INSERT INTO replica_glyphs VALUES (?, ?)');
    for (final id in allWords) {
      insGlyph.execute([id, source[id]![2]]);
    }
    db.execute('COMMIT');
    for (final (k, v) in [
      ('replica_edition', _edition),
      ('replica_target_em', (target / _probe).toStringAsFixed(4)),
      ('replica_space_em', (space / _probe).toStringAsFixed(4)),
    ]) {
      db.execute('INSERT OR REPLACE INTO meta VALUES (?, ?)', [k, v]);
    }
    db.execute('VACUUM');
    db.close();
    File(outputVersion).writeAsStringSync('${sha256Of(outputDb)}\n');

    final centred = rows.where((r) => r[2] == 'ayah' && r[3] == 1).length;
    final assetBytes = Directory('assets/qcf').listSync().whereType<File>().fold<int>(0, (s, f) => s + f.lengthSync());
    print('replica_target_em = ${(target / _probe).toStringAsFixed(4)}, '
        'replica_space_em = ${(space / _probe).toStringAsFixed(4)}, '
        '${rows.length} lines ($centred ayah lines centred), '
        'assets/qcf ${(assetBytes / 1048576).toStringAsFixed(1)} MB');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
