import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/shared/mathani_icons.dart';

import '../support/harness.dart';

/// The recitation icons (specs/004 T003) must exist in the bundled Lucide font: a codepoint the
/// font lacks draws the same "missing glyph" box as any other unused codepoint.
void main() {
  testWidgets('recitation icons are glyphs of the bundled Lucide font', (tester) async {
    await loadAppFonts();

    Future<Uint8List> draw(int codepoint) async {
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(codepoint),
          style: const TextStyle(fontFamily: 'Lucide', fontSize: 48, color: Color(0xFF000000)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), Offset.zero);
      final image = await recorder.endRecording().toImage(64, 64);
      final bytes = await image.toByteData();
      return bytes!.buffer.asUint8List();
    }

    await tester.runAsync(() async {
      final missing = await draw(0xf8ff); // private-use codepoint Lucide does not define
      for (final icon in [
        MathaniIcons.play,
        MathaniIcons.pause,
        MathaniIcons.previous,
        MathaniIcons.next,
        MathaniIcons.download,
        MathaniIcons.downloaded,
        MathaniIcons.more,
        MathaniIcons.recitation,
      ]) {
        final drawn = await draw(icon.codePoint);
        expect(listEquals(drawn, missing), isFalse,
            reason: 'U+${icon.codePoint.toRadixString(16)} is not in Lucide.ttf');
        expect(icon.matchTextDirection, isFalse, reason: 'media icons never mirror');
      }
    });
  });
}
