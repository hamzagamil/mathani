import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/quran_repository.dart';

import '../support/harness.dart';

/// The packed `recitation_sizes` table (specs/006 T009, research R4) returns exactly the sizes
/// feature 004 stored row by row, so existing downloads stay valid (FR-006).
void main() {
  /// The 004 manifests when the sources are present (a maintainer's machine), otherwise the
  /// committed sample of surahs 1, 67 and 114.
  Map<String, Map<String, int>> expectedSizes() {
    Map<String, int> files(Map<dynamic, dynamic> m) => m.cast<String, int>();
    final full = {
      for (final id in ['husary', 'minshawy'])
        if (File('tool/sources/recitations/$id.json').existsSync())
          id: files((jsonDecode(File('tool/sources/recitations/$id.json').readAsStringSync())
              as Map)['files'] as Map),
    };
    if (full.length == 2) return full;
    final sample = jsonDecode(File('test/fixtures/recitation_sizes_004.json').readAsStringSync())
        as Map<String, dynamic>;
    return {for (final e in sample.entries) e.key: files(e.value as Map)};
  }

  testWidgets('packed sizes match the 004 catalogue for husary and minshawy', (tester) async {
    final quran = (await tester.runAsync(openTestReader))!.quran;
    final expected = expectedSizes();
    for (final MapEntry(key: id, value: files) in expected.entries) {
      final surahs = {for (final k in files.keys) int.parse(k.split(':').first)};
      for (final s in surahs) {
        final bytes = (await tester.runAsync(() => quran.recordingBytes(id, s)))!;
        expect(bytes, [
          for (var a = 1; a <= bytes.length; a++) files['$s:$a'],
        ], reason: '$id surah $s');
        expect(bytes, hasLength(quran.surahList[s - 1].ayahCount));
        expect((await tester.runAsync(() => quran.clipRange(id, s, 1))), isNull,
            reason: 'one file per ayah has no clip range');
      }
    }
  });

  test('unpackSizes reads 3-byte little-endian integers', () {
    expect(unpackSizes(Uint8List.fromList([0x01, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0x34, 0x12, 0x00])),
        [1, 0xFFFFFF, 0x1234]);
    expect(unpackSizes(Uint8List(0)), isEmpty);
  });
}
