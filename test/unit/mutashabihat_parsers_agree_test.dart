// The app and the server parse content the same way (specs/011 research R3): the server checks
// what the editor publishes, and the app checks it again on download.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/mutashabihat/mutashabihat_content.dart';

String? _node() {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0 ? 'node' : null;
  } catch (_) {
    return null;
  }
}

void main() {
  final node = _node();
  final bad = File('${Directory.systemTemp.createTempSync('agree').path}/bad.md')
    ..writeAsStringSync('<!-- version: 4 -->\n## 2:35 7;19\nشرح\n\n## 2:35 2:300 115:1\nشرح\n\n'
        '## 3:7\nشرح\n\n## 3:7 39:23\n\n## ٢:٣٥ 2:35, 7:19 | ملاحظة\n\n\nأول\nثان\n\n\n\nثالث\n');

  for (final path in [
    'assets/mutashabihat/mutashabihat.md',
    'test/fixtures/mutashabihat/quickstart.md',
    bad.path,
  ]) {
    test('Dart and JavaScript agree on ${path.split(RegExp(r'[/\\]')).last}', () {
      final result = Process.runSync(node!, ['tool/mutashabihat/parse_cli.mjs', path], stdoutEncoding: utf8);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final js = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final (dart, problems) = parseMutashabihat(File(path).readAsStringSync());

      expect(js['version'], dart.version);
      expect([for (final g in js['groups'] as List) g['ayat']],
          [for (final g in dart.groups) g.ayat.map((r) => '${r.surah}:${r.ayah}').join(' ')]);
      expect([for (final g in js['groups'] as List) g['explanation']], [for (final g in dart.groups) g.explanation]);
      expect([for (final g in js['groups'] as List) g['line']], [for (final g in dart.groups) g.line]);
      expect([for (final p in js['problems'] as List) p['message']], [for (final p in problems) p.message]);
    }, skip: node == null ? 'node is not on the PATH' : false);
  }
}
