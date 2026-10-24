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
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('asr_model.dart'));
    expect(files, isNotEmpty);
    for (final f in files) {
      final source = f.readAsStringSync();
      for (final word in banned) {
        expect(source.contains(word), isFalse, reason: '${f.path} uses $word');
      }
    }
  });
}
