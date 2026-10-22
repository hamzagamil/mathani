// DEVELOPMENT PREVIEW ONLY: runs Mathani in a desktop browser.
//   flutter run -d chrome -t tool/web_preview.dart
//
// The app targets Android and iOS. sqflite has no web backend, so this entry point swaps in the
// WebAssembly SQLite from sqflite_common_ffi_web (a dev dependency, never part of the mobile
// apps) and needs web/sqlite3.wasm matching the locked sqlite3 package version.
// The browser is not a supported platform: performance, gestures and text rendering differ from
// phones, so verify anything that matters on a device (quickstart.md).
// ignore_for_file: avoid_print
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:mathani/features/reader/printed_fonts.dart';
import 'package:mathani/main.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
  // dart:io's gzip is not available in browsers: inflate the page fonts with DecompressionStream.
  PrintedFonts.inflate = _browserGunzip;
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

Future<List<int>> _browserGunzip(Uint8List gz) async {
  final stream = _Response(gz.toJS).body.pipeThrough(_DecompressionStream('gzip'));
  final buffer = await _Response(stream).arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

@JS('Response')
extension type _Response._(JSObject _) implements JSObject {
  external factory _Response(JSAny body);
  external _ReadableStream get body;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type _ReadableStream._(JSObject _) implements JSObject {
  external _ReadableStream pipeThrough(JSObject transform);
}

@JS('DecompressionStream')
extension type _DecompressionStream._(JSObject _) implements JSObject {
  external factory _DecompressionStream(String format);
}
