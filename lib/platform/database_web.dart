import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'gunzip.dart';

/// SQLite in a shared worker, so every tab writes user.db through one connection (research R4).
/// Where a browser has no SharedWorker (Chrome on Android), the package uses a dedicated worker.
Future<void> initDatabases() async => databaseFactory = databaseFactoryFfiWeb;

/// One SQLite instance serves every database in the browser: they open one at a time.
const parallelDatabaseOpen = false;

/// The path of database file [name]. The browser's databases directory is `/`, and the file
/// system there takes `//name` as `/`: every file would be the same one.
Future<String> databasePath(String name) async {
  final dir = await getDatabasesPath();
  return dir.endsWith('/') ? '$dir$name' : '$dir/$name';
}

/// Writes the bundled Quran database into the browser's SQLite store only when [bundledVersion]
/// differs from the installed one, so a return visit opens it at once (SC-002). The deploy serves
/// it gzip-compressed (tool/web_deploy.mjs); `flutter run` serves only the plain asset.
Future<String> installQuranDb(String bundledVersion) async {
  final path = await databasePath('quran.db');
  final versionPath = await databasePath('quran.version');
  String? installed;
  try {
    installed = utf8.decode(await databaseFactory.readDatabaseBytes(versionPath)).trim();
  } on Object {
    installed = null; // first visit
  }
  if (installed != bundledVersion) {
    await databaseFactory.writeDatabaseBytes(path, await _bundledQuranDb());
    // After the database, so an interrupted write is redone on the next visit.
    await databaseFactory.writeDatabaseBytes(versionPath, utf8.encode(bundledVersion));
  }
  return path;
}

Future<Uint8List> _bundledQuranDb() async {
  final gz = await http.get(Uri.base.resolve('assets/assets/db/quran.db.gz'));
  if (gz.statusCode == 200) return gunzip(gz.bodyBytes);
  final data = await rootBundle.load('assets/db/quran.db');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
