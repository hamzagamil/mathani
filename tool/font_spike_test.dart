// Early check of the Quran font against the bundled text (task T018, research R3).
//   flutter test tool/font_spike_test.dart [--dart-define=FONT=assets/fonts/X.ttf]
//
// 1. Coverage: every code point used by the Quran text (and the ayah-end sign) must have a
//    glyph in the font's cmap. Missing glyphs fail the test.
// 2. Visual: renders pages 1, 2, 50, 187, 255 and 604 to build/font_spike/page_N.png for a human
//    check that ayah-end markers show Eastern Arabic numerals and diacritics do not overlap.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/shared/quran_text.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'src/sources.dart' show outputDb;

const _fontPath = String.fromEnvironment('FONT', defaultValue: 'assets/fonts/AmiriQuran-Regular.ttf');
const _pages = [1, 2, 50, 187, 255, 604];

void main() {
  final fontBytes = File(_fontPath).readAsBytesSync();
  final db = sql.sqlite3.open(outputDb, mode: sql.OpenMode.readOnly);
  final dbFont = db.select("SELECT value FROM meta WHERE key = 'font'").first['value'] as String;

  test('font has a glyph for every code point in the Quran text', () {
    final covered = _cmapCodePoints(ByteData.sublistView(fontBytes));
    final missing = <int, String>{};
    for (final r in db.select('SELECT surah, ayah, text_uthmani, is_ayah_end FROM words')) {
      var text = r['text_uthmani'] as String;
      if (r['is_ayah_end'] == 1) text = ayahEndGlyphs(text, dbFont);
      for (final c in text.runes) {
        if (c != 0x20 && !covered.contains(c)) missing.putIfAbsent(c, () => '${r['surah']}:${r['ayah']}');
      }
    }
    for (final e in missing.entries) {
      // ignore: avoid_print
      print('MISSING U+${e.key.toRadixString(16).toUpperCase().padLeft(4, '0')} (first in ${e.value})');
    }
    // ignore: avoid_print
    print('Coverage: ${covered.length} code points in $_fontPath; missing: ${missing.length}');
    expect(missing, isEmpty);
  });

  testWidgets('render sample pages for visual review', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('QuranText')..addFont(Future.value(ByteData.sublistView(fontBytes)));
      await loader.load();
    });
    Directory('build/font_spike').createSync(recursive: true);
    tester.view.physicalSize = const Size(720, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    for (final page in _pages) {
      final lines = db.select('SELECT type, first_word_id, last_word_id, surah FROM mushaf_lines '
          'WHERE page = ? ORDER BY line', [page]);
      String textOf(sql.Row l) {
        if (l['type'] == 'surah_name') return 'سُورَةُ ${l['surah']}';
        if (l['type'] == 'basmallah') return 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
        return [
          for (final w in db.select('SELECT text_uthmani, is_ayah_end FROM words WHERE id BETWEEN ? AND ?',
              [l['first_word_id'], l['last_word_id']]))
            w['is_ayah_end'] == 1
                ? ayahEndGlyphs(w['text_uthmani'] as String, dbFont)
                : w['text_uthmani'] as String,
        ].join(' ');
      }

      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFFF2EADD),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (final l in lines)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          textOf(l),
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: 'QuranText',
                            fontSize: 22,
                            height: 2.0,
                            color: Color(0xFF183159),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      )));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('build/font_spike/page_$page.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  });

  tearDownAll(db.close);
}

/// Code points mapped to a non-zero glyph by the font's Unicode cmap (formats 4 and 12).
Set<int> _cmapCodePoints(ByteData f) {
  final numTables = f.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + i * 16;
    final tag = String.fromCharCodes([for (var k = 0; k < 4; k++) f.getUint8(rec + k)]);
    if (tag == 'cmap') cmap = f.getUint32(rec + 8);
  }
  if (cmap < 0) throw StateError('font has no cmap table');

  final result = <int>{};
  final subtables = f.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final platform = f.getUint16(cmap + 4 + i * 8);
    final encoding = f.getUint16(cmap + 6 + i * 8);
    final offset = cmap + f.getUint32(cmap + 8 + i * 8);
    final unicode = platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
    if (!unicode) continue;
    final format = f.getUint16(offset);
    if (format == 4) {
      final segX2 = f.getUint16(offset + 6);
      final ends = offset + 14;
      final starts = ends + segX2 + 2;
      final deltas = starts + segX2;
      final ranges = deltas + segX2;
      for (var s = 0; s < segX2 ~/ 2; s++) {
        final end = f.getUint16(ends + s * 2);
        final start = f.getUint16(starts + s * 2);
        final delta = f.getInt16(deltas + s * 2);
        final rangeOffset = f.getUint16(ranges + s * 2);
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          int glyph;
          if (rangeOffset == 0) {
            glyph = (c + delta) & 0xFFFF;
          } else {
            final at = ranges + s * 2 + rangeOffset + (c - start) * 2;
            glyph = f.getUint16(at);
            if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
          }
          if (glyph != 0) result.add(c);
        }
      }
    } else if (format == 12) {
      final groups = f.getUint32(offset + 12);
      for (var g = 0; g < groups; g++) {
        final at = offset + 16 + g * 12;
        final start = f.getUint32(at), end = f.getUint32(at + 4), glyph = f.getUint32(at + 8);
        for (var c = start; c <= end; c++) {
          if (glyph + (c - start) != 0) result.add(c);
        }
      }
    }
  }
  return result;
}
