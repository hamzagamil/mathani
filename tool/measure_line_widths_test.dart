// Measures the widest Mushaf line in the bundled Quran font and writes it to
// meta.max_line_width_em (research R4). Run after tool/build_quran_db.dart:
//   flutter test tool/measure_line_widths_test.dart
//
// A line's natural width is the sum of its word widths plus one space per gap. The Mushaf
// renderer (lib/features/reader/mushaf_page_renderer.dart) lays lines out with the same rule,
// so dividing the content width by this value gives the largest font size at which every line
// of all 604 pages fits.
//
// It also writes meta.justify_target_em, the width every justified line is filled to
// (specs/002-print-like-mushaf-page, research P2): the widest line with its gaps tightened to
// 0.6 of a space, then shrunk by the 5% a line may lose.
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/shared/quran_text.dart';
import 'package:sqlite3/sqlite3.dart';

import 'src/sources.dart' show outputDb, outputVersion, sha256Of;

const _probeSize = 100.0;

void main() {
  test('measure widest Mushaf line', () async {
    final db = sqlite3.open(outputDb);
    final font = db.select("SELECT value FROM meta WHERE key = 'font'").first['value'] as String;
    final fontFile = font == 'kfgqpc-hafs'
        ? 'assets/fonts/UthmanicHafs.ttf'
        : 'assets/fonts/AmiriQuran-Regular.ttf';
    final loader = FontLoader('QuranText')
      ..addFont(Future.value(ByteData.sublistView(File(fontFile).readAsBytesSync())));
    await loader.load();
    final words = {
      for (final r in db.select('SELECT id, text_uthmani, is_ayah_end FROM words'))
        r['id'] as int: r['is_ayah_end'] == 1
            ? ayahEndGlyphs(r['text_uthmani'] as String, font)
            : r['text_uthmani'] as String,
    };

    double width(String text) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontFamily: 'QuranText', fontSize: _probeSize),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    final cache = <int, double>{};
    final space = width(' ');
    final widths = <double>[];
    var widest = 0.0;
    var target = 0.0;
    var widestAt = '';
    for (final l in db.select("SELECT page, line, first_word_id, last_word_id FROM mushaf_lines "
        "WHERE type = 'ayah'")) {
      final first = l['first_word_id'] as int, last = l['last_word_id'] as int;
      var w = space * (last - first);
      for (var id = first; id <= last; id++) {
        w += cache.putIfAbsent(id, () => width(words[id]!));
      }
      widths.add(w);
      final tightened = (w - space * (last - first) * 0.4) * 0.95;
      if (tightened > target) target = tightened;
      if (w > widest) {
        widest = w;
        widestAt = '${l['page']}:${l['line']}';
      }
    }
    widths.sort();
    // The renderer sizes pages by the 98th-percentile line and shrinks only the wider lines.
    final p98 = widths[(widths.length * 0.98).floor()] / _probeSize;

    final em = widest / _probeSize;
    db.execute("UPDATE meta SET value = ? WHERE key = 'max_line_width_em'", [em.toStringAsFixed(4)]);
    db.execute("INSERT OR REPLACE INTO meta VALUES ('p98_line_width_em', ?)", [p98.toStringAsFixed(4)]);
    db.execute("INSERT OR REPLACE INTO meta VALUES ('space_width_em', ?)",
        [(space / _probeSize).toStringAsFixed(4)]);
    db.execute("INSERT OR REPLACE INTO meta VALUES ('justify_target_em', ?)",
        [(target / _probeSize).toStringAsFixed(4)]);
    db.close();
    File(outputVersion).writeAsStringSync('${sha256Of(outputDb)}\n');

    // ignore: avoid_print
    print('max_line_width_em = ${em.toStringAsFixed(4)} (widest line $widestAt), '
        'p98_line_width_em = ${p98.toStringAsFixed(4)}, '
        'justify_target_em = ${(target / _probeSize).toStringAsFixed(4)}');
    expect(em, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
