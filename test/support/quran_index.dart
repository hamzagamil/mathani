import 'dart:io';

import 'package:mathani/data/models.dart';
import 'package:mathani/features/khatma/khatma_division.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The khatma's index of the bundled quran.db, read directly through SQLite FFI, for plain unit
/// tests that need the real Mushaf data (specs/014 SC-003, SC-004).
Future<({QuranIndex index, List<Ayah> ayahs})> loadBundledIndex() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(File('assets/db/quran.db').absolute.path,
      options: OpenDatabaseOptions(readOnly: true));
  try {
    final ayahs = [
      for (final r in await db.rawQuery(
          'SELECT id, surah, ayah, page, juz, hizb_quarter, sajdah, first_word_id, last_word_id '
          'FROM ayahs ORDER BY id'))
        Ayah(
          id: r['id'] as int,
          surah: r['surah'] as int,
          ayah: r['ayah'] as int,
          page: r['page'] as int,
          juz: r['juz'] as int,
          hizbQuarter: r['hizb_quarter'] as int,
          sajdah: (r['sajdah'] as int) == 1,
          firstWordId: r['first_word_id'] as int,
          lastWordId: r['last_word_id'] as int,
        ),
    ];
    final divisions = [
      for (final r in await db.query('divisions', orderBy: 'kind, number'))
        Division(
          kind: r['kind'] == 'juz' ? DivisionKind.juz : DivisionKind.hizbQuarter,
          number: r['number'] as int,
          start: AyahRef(r['start_surah'] as int, r['start_ayah'] as int),
          startPage: r['start_page'] as int,
          openingWords: r['opening_words'] as String,
        ),
    ];
    return (index: QuranIndex.fromAyahs(ayahs, divisions), ayahs: ayahs);
  } finally {
    await db.close();
  }
}
