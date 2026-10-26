import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Platform code stays behind the seams in lib/platform (specs/008 T023, contracts/web-platform.md):
/// phone-only libraries in `*_io.dart` and the FFI recogniser, browser-only libraries in
/// `*_web.dart` and the speech worker. Anything else would break the web build or the phone build.
void main() {
  final ioOnly = RegExp(r'''^import '(dart:io|dart:ffi|dart:isolate|package:path_provider/[^']*)'|^import 'package:sherpa_onnx/''');
  final webOnly = RegExp(r'''^import '(dart:js_interop[^']*|package:web/[^']*|package:sqflite_common_ffi_web/[^']*)';''');
  bool ioAllowed(String path) =>
      RegExp(r'lib/platform/\w+_io\.dart$').hasMatch(path) ||
      path.endsWith('lib/features/memorization/sherpa_recogniser.dart');
  bool webAllowed(String path) =>
      RegExp(r'lib/platform/\w+_web\.dart$').hasMatch(path) ||
      path.endsWith('lib/features/memorization/web_worker_main.dart');

  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('phone-only imports are only in *_io.dart and the FFI recogniser', () {
    final offenders = [
      for (final f in files)
        for (final line in f.readAsLinesSync())
          if (ioOnly.hasMatch(line) && !ioAllowed(f.path.replaceAll(r'\', '/'))) '${f.path}: $line',
    ];
    expect(offenders, isEmpty);
  });

  test('browser-only imports are only in *_web.dart and the speech worker', () {
    final offenders = [
      for (final f in files)
        for (final line in f.readAsLinesSync())
          if (webOnly.hasMatch(line) && !webAllowed(f.path.replaceAll(r'\', '/'))) '${f.path}: $line',
    ];
    expect(offenders, isEmpty);
  });
}
