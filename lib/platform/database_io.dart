import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

/// Phones use sqflite's own factory.
Future<void> initDatabases() async {}

/// Separate files: both databases open at once (constitution III).
const parallelDatabaseOpen = true;

/// The path of database file [name] in the app's databases directory.
Future<String> databasePath(String name) async => '${await getDatabasesPath()}/$name';

/// Copies the bundled Quran database on first launch, or when the bundled build changed
/// ([bundledVersion] is `assets/db/quran.version`); returns its path.
Future<String> installQuranDb(String bundledVersion) async {
  final dir = await getDatabasesPath();
  final path = '$dir/quran.db';
  final versionFile = File('$dir/quran.version');
  final installedVersion = versionFile.existsSync() ? versionFile.readAsStringSync().trim() : null;

  if (installedVersion != bundledVersion || !File(path).existsSync()) {
    await Directory(dir).create(recursive: true);
    final data = await rootBundle.load('assets/db/quran.db');
    await File(path).writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await versionFile.writeAsString(bundledVersion, flush: true);
  }
  return path;
}
