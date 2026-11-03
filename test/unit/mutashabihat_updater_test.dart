// specs/011 research R5, contracts/content-api.md: the app takes a published version only when it
// is newer, complete and checked, keeps it on the device, and asks at most every 6 hours.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mathani/features/mutashabihat/mutashabihat_loader.dart';
import 'package:mathani/features/mutashabihat/mutashabihat_updater.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';
import '../support/memory_file_store.dart';

void main() {
  final fixture = File('test/fixtures/mutashabihat/quickstart.md').readAsStringSync();
  List<int> body(int version, [String text = '']) =>
      utf8.encode('<!-- version: $version -->\n${text.isEmpty ? fixture : text}');

  http.Response published(int version, {List<int>? bytes, String format = '1', String? sha}) {
    final b = bytes ?? body(version);
    return http.Response.bytes(b, 200, headers: {
      'etag': '"v$version"',
      'x-content-version': '$version',
      'x-content-format': format,
      'x-content-sha256': sha ?? sha256.convert(b).toString(),
    });
  }

  late ReaderController reader;
  late MemoryFileStore store;
  late List<http.Request> requests;
  var now = DateTime(2026, 11, 3, 12);

  MutashabihatUpdater updater(http.Response Function(http.Request) answer) => MutashabihatUpdater(
        reader: reader,
        store: store,
        now: () => now,
        base: Uri.parse('https://get.mthani.app'),
        client: MockClient((r) async {
          requests.add(r);
          return answer(r);
        }),
      );

  Future<void> setUpReader(WidgetTester tester) async {
    reader = (await tester.runAsync(openTestReader))!;
    store = MemoryFileStore();
    requests = [];
    now = DateTime(2026, 11, 3, 12);
    addTearDown(() => tester.runAsync(() async {
          reader.didChangeAppLifecycleState(AppLifecycleState.paused);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }));
  }

  Map<String, dynamic> meta() => jsonDecode(utf8.decode(store.bytesOf(downloadedMeta))) as Map<String, dynamic>;

  testWidgets('a newer, checked version is saved and used at once', (tester) async {
    await setUpReader(tester);
    await tester.runAsync(() => updater((_) => published(5)).check());
    expect(reader.similar.version, 5);
    expect(reader.similar.groups, hasLength(5));
    expect(store.exists(downloadedContent), isTrue);
    expect(store.exists(downloadedContent.part), isFalse);
    expect(meta()['version'], 5);
    expect(requests.single.url.toString(), 'https://get.mthani.app/api/mutashabihat');
    expect(requests.single.headers.containsKey('if-none-match'), isFalse, reason: 'nothing downloaded yet');
    expect(requests.single.headers.keys.where((k) => k != 'if-none-match'), isEmpty,
        reason: 'no identifying headers (FR-017)');
  });

  testWidgets('304: keeps the content, remembers the check, and waits 6 hours', (tester) async {
    await setUpReader(tester);
    await tester.runAsync(() => updater((_) => published(5)).check());
    now = now.add(const Duration(hours: 7));
    final u = updater((_) => http.Response('', 304));
    await tester.runAsync(u.check);
    expect(requests.last.headers['if-none-match'], '"v5"');
    expect(reader.similar.version, 5);
    expect(meta()['checkedAt'], now.millisecondsSinceEpoch);
    expect(meta()['version'], 5, reason: 'a 304 keeps what was downloaded');

    final asked = requests.length;
    now = now.add(const Duration(hours: 5));
    await tester.runAsync(u.check);
    expect(requests.length, asked, reason: 'within 6 hours: no request');
  });

  testWidgets('anything wrong keeps the current content and writes no file', (tester) async {
    await setUpReader(tester);
    final cases = {
      'wrong SHA-256': published(5, sha: 'a' * 64),
      'a newer format': published(5, format: '2'),
      'damaged text': published(5, bytes: body(5, '## 2:35 2:300\nشرح')),
      'header and file disagree': published(6, bytes: body(5)),
    };
    for (final MapEntry(key: name, value: response) in cases.entries) {
      store = MemoryFileStore();
      await tester.runAsync(() => updater((_) => response).check());
      expect(reader.similar.version, 0, reason: name);
      expect(store.exists(downloadedContent), isFalse, reason: name);
    }
    // Not newer than what the reader has.
    store = MemoryFileStore();
    await tester.runAsync(() => updater((_) => published(5)).check());
    expect(reader.similar.version, 5);
    store = MemoryFileStore();
    await tester.runAsync(() => updater((_) => published(4)).check());
    expect(reader.similar.version, 5);
    expect(store.exists(downloadedContent), isFalse);
  });

  testWidgets('no connection or a server error: tried again on the next resume', (tester) async {
    await setUpReader(tester);
    await tester.runAsync(() => updater((_) => throw const SocketException('offline')).check());
    expect(store.exists(downloadedMeta), isFalse, reason: 'checkedAt unchanged');
    await tester.runAsync(() => updater((_) => http.Response('{"error":"unavailable"}', 503)).check());
    expect(store.exists(downloadedMeta), isFalse);
    await tester.runAsync(() => updater((_) => published(2)).check());
    expect(reader.similar.version, 2);
  });

  testWidgets('the loader picks the newer of the bundled and the downloaded copy', (tester) async {
    await setUpReader(tester);
    final bundled = _Bundle('<!-- version: 3 -->\n$fixture');
    Future<int> start() async => (await tester.runAsync(() => loadMutashabihat(bundle: bundled, store: store)))!.version;

    expect(await start(), 3, reason: 'nothing downloaded');
    store.put(downloadedContent, body(5));
    expect(await start(), 5, reason: 'the download is newer');
    store.put(downloadedContent, body(2));
    expect(await start(), 3, reason: 'a newer app release wins');
    store.put(downloadedContent, body(3));
    expect(await start(), 3, reason: 'a tie: the bundled copy');
    store.put(downloadedContent, body(9, '## 2:35 2:300\nشرح'));
    store.put(downloadedMeta, utf8.encode('{}'));
    expect(await start(), 3, reason: 'a damaged download is ignored');
    expect(store.exists(downloadedContent), isFalse, reason: '…and deleted');
    expect(store.exists(downloadedMeta), isFalse);
  });
}

class _Bundle extends CachingAssetBundle {
  _Bundle(this.text);
  final String text;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(utf8.encode(text));
}
