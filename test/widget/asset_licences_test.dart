import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/settings/about_section.dart';

/// Every bundled licence text loads and is listed, including the memorization runtime and model
/// (specs/006 T055).
void main() {
  testWidgets('the asset licences are registered with their texts', (tester) async {
    registerAssetLicences();
    final entries = (await tester.runAsync(() => LicenseRegistry.licenses.toList()))!;
    final byPackage = {
      for (final e in entries)
        for (final p in e.packages) p: e.paragraphs.map((x) => x.text).join('\n'),
    };
    for (final (package, words) in const [
      ('ONNX Runtime', 'MIT License'),
      ('Tarteel Whisper tiny (Quran)', 'Apache License'),
      ('Silero VAD', 'MIT License'),
      ('Lucide icons', ''),
    ]) {
      expect(byPackage, contains(package));
      expect(byPackage[package], contains(words));
    }
    expect(byPackage['Tarteel Whisper tiny (Quran)'], contains('Changes:'));
  });
}
