// A note on each bookmark: kept, edited, cleared, and added to bookmarks saved before schema 4.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/data/user_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<String> freshDir() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dir = Directory.systemTemp.createTempSync('mathani_note');
  await databaseFactory.setDatabasesPath(dir.path);
  return dir.path;
}

void main() {
  test('a note is saved, kept across a restart, edited and cleared', () async {
    await freshDir();
    final user = await UserRepository.open();
    final b = await user.addBookmark(const AyahRef(2, 255), 42);
    expect(b.note, isNull);

    await user.setBookmarkNote(b.id, '  Ayat al-Kursi, read before sleep  ');
    expect(user.bookmarks.single.note, 'Ayat al-Kursi, read before sleep');
    await user.database.close();

    final reopened = await UserRepository.open();
    expect(reopened.bookmarks.single.note, 'Ayat al-Kursi, read before sleep');

    await reopened.setBookmarkNote(b.id, 'x' * (Bookmark.maxNoteLength + 20));
    expect(reopened.bookmarks.single.note, hasLength(Bookmark.maxNoteLength));

    await reopened.setBookmarkNote(b.id, '   ');
    expect(reopened.bookmarks.single.note, isNull);
  });

  test('schema 3 to 4 keeps bookmarks and lets them take a note', () async {
    final dir = await freshDir();
    final v3 = await databaseFactory.openDatabase('$dir/user.db',
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE bookmarks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'surah INTEGER NOT NULL, ayah INTEGER NOT NULL, page INTEGER NOT NULL, '
                'created_at INTEGER NOT NULL, UNIQUE (surah, ayah))');
          },
        ));
    await v3.insert('bookmarks', {'surah': 18, 'ayah': 1, 'page': 293, 'created_at': 1});
    await v3.close();

    final user = await UserRepository.open();
    expect(await user.database.getVersion(), 4);
    final b = user.bookmarks.single;
    expect((b.page, b.note), (293, null));
    await user.setBookmarkNote(b.id, 'Friday');
    expect(user.bookmarks.single.note, 'Friday');
  });
}
