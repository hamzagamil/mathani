@Tags(['web'])
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/platform/database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// The Quran database in the browser (specs/008 T013, research R4): written once, then only when
/// the bundled version changes, so a return visit opens it at once (SC-002).
void main() {
  // The page's shared worker is not served to tests; the same store without the worker.
  setUpAll(() => databaseFactory = databaseFactoryFfiWebNoWebWorker);

  Future<int> bundledSize() async => (await rootBundle.load('assets/db/quran.db')).lengthInBytes;

  test('first install writes the database, then the same version leaves it alone', () async {
    final path = await installQuranDb('test-1');
    expect((await databaseFactory.readDatabaseBytes(path)).length, await bundledSize());

    // Mark the installed copy: a rewrite would replace the mark.
    await databaseFactory.writeDatabaseBytes(path, Uint8List.fromList([1, 2, 3]));
    await installQuranDb('test-1');
    expect(await databaseFactory.readDatabaseBytes(path), [1, 2, 3]);
  });

  test('a new version rewrites it', () async {
    final path = await installQuranDb('test-2');
    await databaseFactory.writeDatabaseBytes(path, Uint8List.fromList([1, 2, 3]));
    await installQuranDb('test-3');
    expect((await databaseFactory.readDatabaseBytes(path)).length, await bundledSize());
  });

  test('the installed database opens and answers', () async {
    final db = await openReadOnlyDatabase(await installQuranDb('test-4'));
    expect((await db.rawQuery('SELECT COUNT(*) AS n FROM ayahs')).single['n'], 6236);
    await db.close();
  });
}
