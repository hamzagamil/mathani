import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/data/quran_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ayah clips of a reciter recorded one surah per file (specs/006 T011, research R18): the clips
/// of a surah are contiguous, the first starts at `range_start`, the last ends at the file length,
/// and `recordingBytes` gives the clip lengths.
void main() {
  // Two surahs of a QUL surah-file reciter: (surah, file bytes, range_start, sizes).
  const fixture = [
    (1, 812345, 4180, [101234, 98765, 87654, 120000, 99999, 150000, 150513]),
    (112, 260000, 417, [64000, 63000, 66000, 66583]),
  ];

  late QuranRepository quran;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = Directory.systemTemp.createTempSync('mathani_clip');
    await databaseFactory.setDatabasesPath(dir.path);
    File('assets/db/quran.db').copySync('${dir.path}/quran.db');
    File('assets/db/quran.version').copySync('${dir.path}/quran.version');

    final db = await databaseFactory.openDatabase('${dir.path}/quran.db');
    await db.insert('reciters', {
      'id': 'fixture_surah', 'name_ar': 'قارئ', 'name_en': 'Reciter',
      'short_ar': 'قارئ', 'short_en': 'Reciter', 'style': 'murattal',
      'base_url': 'https://audio.example/', 'mirror_url': null, 'bitrate_kbps': 64,
      'sort': 999, 'source': 'qul_surah', 'file_pattern': '{sss}.mp3', 'basmala_in_ayah1': 1,
    });
    for (final (surah, _, start, sizes) in fixture) {
      final packed = Uint8List(sizes.length * 3);
      for (var i = 0; i < sizes.length; i++) {
        packed
          ..[i * 3] = sizes[i] & 0xFF
          ..[i * 3 + 1] = (sizes[i] >> 8) & 0xFF
          ..[i * 3 + 2] = (sizes[i] >> 16) & 0xFF;
      }
      await db.insert('recitation_sizes',
          {'reciter': 'fixture_surah', 'surah': surah, 'sizes': packed, 'range_start': start});
    }
    await db.close();
    TestWidgetsFlutterBinding.ensureInitialized();
    quran = await QuranRepository.open();
  });

  test('the fixture reciter reads as a surah-file reciter', () {
    final r = quran.reciter('fixture_surah')!;
    expect(r.source, RecitationSource.qulSurah);
    expect(r.basmalaInAyah1, isTrue);
  });

  test('clips are contiguous from range_start to the end of the file', () async {
    for (final (surah, fileBytes, start, sizes) in fixture) {
      expect(await quran.recordingBytes('fixture_surah', surah), sizes);
      expect(await quran.surahFileBytes('fixture_surah', surah), fileBytes);
      var expected = start;
      for (var a = 1; a <= sizes.length; a++) {
        final clip = (await quran.clipRange('fixture_surah', surah, a))!;
        expect(clip.$1, expected, reason: '$surah:$a starts where the previous clip ended');
        expect(clip.$2 - clip.$1, sizes[a - 1], reason: '$surah:$a length');
        expected = clip.$2;
      }
      expect(expected, fileBytes, reason: 'surah $surah: the last clip ends at the file length');
      expect(await quran.clipRange('fixture_surah', surah, 0), isNull);
      expect(await quran.clipRange('fixture_surah', surah, sizes.length + 1), isNull);
    }
  });

  test('the download size counts no separate basmala when it is in ayah 1', () async {
    expect(await quran.surahDownloadBytes('fixture_surah', 112), 64000 + 63000 + 66000 + 66583);
  });
}
