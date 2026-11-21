import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The privacy boundary of usage statistics (specs/016 FR-004, research R5): one file talks to the
/// analytics library, and only the allowed-events list talks to the sink.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => (path: f.path.replaceAll(r'\', '/'), text: f.readAsStringSync()))
      .toList();

  test('only usage_firebase.dart imports the analytics library', () {
    final users = [
      for (final f in files)
        if (f.text.contains('package:firebase_analytics/')) f.path,
    ];
    expect(users, ['lib/platform/usage_firebase.dart']);
  });

  test('only the allowed-events list calls the sink', () {
    final callers = [
      for (final f in files)
        if (RegExp(r'sink\.(screen|event)\(').hasMatch(f.text)) f.path,
    ];
    expect(callers, ['lib/features/analytics/usage.dart']);
  });
}
