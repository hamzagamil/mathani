import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/harness.dart';

/// The two-pages preference (specs/012 T004, FR-017): on by default, persists, and a missing or
/// unknown stored value reads as on.
void main() {
  testWidgets('two pages defaults to on, persists, and falls back', (tester) async {
    final reader = (await tester.runAsync(openTestReader))!;
    final user = reader.user;
    expect(reader.preferences.twoPages, isTrue);

    for (final on in [false, true, false]) {
      final (_, prefs) = (await tester.runAsync(() async {
        await user.savePreferences(reader.preferences.copyWith(twoPages: on));
        return user.loadStartup();
      }))!;
      expect(prefs.twoPages, on);
    }

    Future<bool> stored(String? value) async {
      final (_, prefs) = (await tester.runAsync(() async {
        final db = await openDatabase('${await getDatabasesPath()}/user.db');
        if (value == null) {
          await db.delete('preferences', where: 'key = ?', whereArgs: ['two_pages']);
        } else {
          await db.insert('preferences', {'key': 'two_pages', 'value': value},
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        return user.loadStartup();
      }))!;
      return prefs.twoPages;
    }

    expect(await stored(null), isTrue, reason: 'readers updating from before specs/012');
    expect(await stored('maybe'), isTrue);
    expect(await stored('false'), isFalse);
  });
}
