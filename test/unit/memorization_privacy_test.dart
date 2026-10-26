import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The reader's voice never leaves the device and is never written (specs/006 FR-019, research
/// R16, T033): only asr_model.dart, which never sees audio, may use the network or write files in
/// lib/features/memorization/.
void main() {
  test('memorization code other than the model download has no network or file writes', () {
    final banned = [
      'HttpClient',
      'path_provider',
      'writeAsBytes',
      'writeAsString',
      'openWrite',
      'File(',
      'package:http/',
      'Socket',
    ];
    final files = Directory('lib/features/memorization')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('asr_model.dart'))
        // The browser's speech worker reads the saved model; it has its own check below.
        .where((f) => !f.path.endsWith('web_worker_main.dart'));
    expect(files, isNotEmpty);
    for (final f in files) {
      final source = f.readAsStringSync();
      for (final word in banned) {
        expect(source.contains(word), isFalse, reason: '${f.path} uses $word');
      }
    }
  });

  // specs/008 T053, FR-024, SC-007: in browsers, recognition runs in a worker that only reads the
  // model the app saved, keeps it in memory, and sends nothing but `loaded`, `error` and `heard`
  // messages to the page.
  test('the browser speech worker has no network, no saved writes, and only page messages', () {
    final source = File('lib/features/memorization/web_worker_main.dart').readAsStringSync();
    for (final word in ['fetch(', 'XMLHttpRequest', 'WebSocket', 'sendBeacon', 'http://', 'https://',
        'createWritable', 'importScripts', 'package:http/']) {
      expect(source.contains(word), isFalse, reason: 'the speech worker uses $word');
    }
    final types = RegExp(r"'type': '(\w+)'").allMatches(source).map((m) => m.group(1)).toSet();
    expect(types, {'loaded', 'error', 'heard'});
    final bootstrap = File('web/speech/speech_worker.js').readAsStringSync();
    for (final word in ['fetch(', 'XMLHttpRequest', 'WebSocket', 'http://', 'https://']) {
      expect(bootstrap.contains(word), isFalse, reason: 'speech_worker.js uses $word');
    }
  });
}
