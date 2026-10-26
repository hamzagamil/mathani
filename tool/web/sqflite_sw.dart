// The SQLite shared worker for the web app (specs/008 research R4), compiled against the app's
// own package versions so it matches web/sqlite3.wasm (the sqlite3 3.7.0 release):
//   dart compile js -O2 -o web/sqflite_sw.js tool/web/sqflite_sw.dart
// `dart run sqflite_common_ffi_web:setup` does the same through webdev, which fails on Windows
// ("cannot find .\bin\dart"), and it would also replace sqlite3.wasm with an older release.
// ignore: implementation_imports
import 'package:sqflite_common_ffi_web/src/sw/shared_worker.dart';

void main(List<String> args) => mainSharedWorker(args);
