import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/harness.dart';

/// The mistake alert preference (specs/006 T008, FR-015): vibration by default, every value
/// persists, and an unknown stored value reads as vibration.
void main() {
  testWidgets('mistake signal defaults to vibrate, persists, and falls back', (tester) async {
    final reader = (await tester.runAsync(openTestReader))!;
    final user = reader.user;
    expect(reader.preferences.mistakeSignal, MistakeSignal.vibrate);

    for (final signal in MistakeSignal.values) {
      final (_, prefs) = (await tester.runAsync(() async {
        await user.savePreferences(reader.preferences.copyWith(mistakeSignal: signal));
        return user.loadStartup();
      }))!;
      expect(prefs.mistakeSignal, signal);
    }

    final (_, prefs) = (await tester.runAsync(() async {
      final db = await openDatabase('${await getDatabasesPath()}/user.db');
      await db.insert('preferences', {'key': 'mistake_signal', 'value': 'flash'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      return user.loadStartup();
    }))!;
    expect(prefs.mistakeSignal, MistakeSignal.vibrate);
  });
}
