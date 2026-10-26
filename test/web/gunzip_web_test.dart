@Tags(['web'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/platform/gunzip.dart';

/// The browser's gunzip (specs/008 T013): whole buffers and streams split at any point.
void main() {
  // `gzip -9` of 'بسم الله الرحمن الرحيم ' × 50.
  final gz = Uint8List.fromList([
    31, 139, 8, 0, 188, 60, 223, 106, 2, 255, 187, 177, 226, 198, 230, 155, 173, 10, 55, 150, //
    223, 108, 1, 194, 118, 48, 227, 198, 198, 27, 107, 111, 182, 222, 108, 67, 112, 186, 64, 74,
    70, 85, 142, 170, 28, 85, 57, 170, 114, 84, 229, 168, 202, 81, 149, 35, 88, 37, 0, 164, 43,
    20, 22, 52, 8, 0, 0,
  ]);
  final text = 'بسم الله الرحمن الرحيم ' * 50;

  test('gunzip inflates a whole buffer', () async {
    expect(utf8.decode(await gunzip(gz)), text);
  });

  test('gunzipStream inflates chunks split anywhere', () async {
    final chunks = [for (var i = 0; i < gz.length; i += 7) gz.sublist(i, i + 7 > gz.length ? gz.length : i + 7)];
    final out = await gunzipStream(Stream.fromIterable(chunks)).expand((c) => c).toList();
    expect(utf8.decode(out), text);
  });

  test('gunzipStream reports bad input as a FormatException', () async {
    await expectLater(gunzipStream(Stream.value([1, 2, 3, 4])).toList(), throwsFormatException);
  });
}
