// Releases carry the latest content published from the Mutashabihat editor (specs/011 Story 5,
// FR-018). Exits 1, leaving the file unchanged, when the content can't be fetched or checked.
//
// Usage:
//   dart run tool/pull_mutashabihat.dart                 write it to assets/mutashabihat/mutashabihat.md
//   dart run tool/pull_mutashabihat.dart --check <file>  fail if <file> is older than what is published
//   … --base https://<preview>.mthani-web.pages.dev      another deployment
//
// Before the editor has published anything (404), the bundled file stays as it is.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mathani/features/mutashabihat/mutashabihat_content.dart';

const _asset = 'assets/mutashabihat/mutashabihat.md';

Never _fail(String message) {
  stderr.writeln('pull_mutashabihat: $message');
  exit(1);
}

Future<void> main(List<String> args) async {
  String? option(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final base = Uri.parse(option('--base') ?? 'https://get.mthani.app');
  final check = option('--check');

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final HttpClientResponse response;
  final List<int> bytes;
  try {
    response = await (await client.getUrl(base.resolve('/api/mutashabihat'))).close();
    bytes = await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
  } catch (e) {
    _fail('cannot reach the published Mutashabihat content at $base ($e)');
  } finally {
    client.close();
  }

  final version = int.tryParse(response.headers.value('x-content-version') ?? '');
  final notPublished = response.statusCode == 404 ||
      // A deployment from before specs/011 answers with the web app's page.
      (response.statusCode == 200 && version == null &&
          (response.headers.contentType?.mimeType ?? '') == 'text/html');
  if (notPublished) {
    stdout.writeln('mutashabihat.md: nothing published from the editor yet; the bundled file stays');
    return;
  }
  if (response.statusCode != 200 || version == null) {
    _fail('unexpected answer ${response.statusCode} from $base/api/mutashabihat');
  }

  if (check != null) {
    final file = File(check);
    if (!file.existsSync()) _fail('missing $check');
    final bundled = parseMutashabihat(file.readAsStringSync()).$1.version;
    if (bundled < version) {
      _fail('bundled content v$bundled is older than published v$version: '
          'run dart run tool/pull_mutashabihat.dart and build again');
    }
    stdout.writeln('mutashabihat.md: bundled v$bundled, published v$version, OK');
    return;
  }

  if (response.headers.value('x-content-format') != '1') {
    _fail('published v$version uses format ${response.headers.value('x-content-format')}, '
        'which this app does not read');
  }
  if (sha256.convert(bytes).toString() != response.headers.value('x-content-sha256')) {
    _fail('the download does not match its checksum');
  }
  final text = utf8.decode(bytes);
  final (content, problems) = parseMutashabihat(text);
  final errors = problems.where((p) => p.isError).toList();
  if (errors.isNotEmpty || content.version != version || content.groups.isEmpty) {
    _fail('published v$version does not pass the checks: ${errors.map((p) => p.message).join('; ')}');
  }
  File(_asset).writeAsStringSync(text);
  stdout.writeln('mutashabihat.md: v$version, ${content.groups.length} groups');
}
