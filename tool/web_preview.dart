// DEVELOPMENT PREVIEW ONLY: runs Mathani in a desktop browser.
//   flutter run -d chrome -t tool/web_preview.dart
//
// The app targets Android and iOS. sqflite has no web backend, so this entry point swaps in the
// WebAssembly SQLite from sqflite_common_ffi_web (a dev dependency, never part of the mobile
// apps) and needs web/sqlite3.wasm matching the locked sqlite3 package version.
// The browser is not a supported platform: performance, gestures and text rendering differ from
// phones, so verify anything that matters on a device (quickstart.md).
// ignore_for_file: avoid_print
import 'package:flutter/widgets.dart';
import 'package:mathani/main.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
  try {
    await runMathani();
    print('[preview] app started');
  } catch (e, s) {
    // A failed startup otherwise leaves a white page with no message.
    print('[preview] STARTUP FAILED: $e\n$s');
    runApp(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('Preview failed to start:\n$e')),
    ));
  }
}
