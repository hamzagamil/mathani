import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/settings/about_section.dart';

/// Every bundled licence text loads and is listed, including the memorization runtime and model
/// (specs/006 T055, specs/007 T037).
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
      ('Khatma FastConformer (NVIDIA FastConformer-Hybrid PCD Large, ar)', 'CC BY 4.0'),
      ('Silero VAD', 'MIT License'),
      ('Lucide icons', ''),
    ]) {
      expect(byPackage, contains(package));
      expect(byPackage[package], contains(words));
    }
    final khatma = byPackage['Khatma FastConformer (NVIDIA FastConformer-Hybrid PCD Large, ar)'];
    expect(khatma, contains('Changes made by Mathani'), reason: 'CC BY 4.0: changes are stated');
    expect(khatma, contains('MIT License'), reason: "Tilawa's export");
    expect(byPackage.keys.where((p) => p.contains('Whisper')), isEmpty);
  });
}
