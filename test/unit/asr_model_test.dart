import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/memorization/asr_model.dart';
import 'package:mathani/shared/device_channel.dart';

/// Records the folders kept out of backups.
class _FakeDevice extends DeviceChannel {
  final excluded = <String>[];

  @override
  Future<void> excludeFromBackup(String path) async => excluded.add(path);
}

/// The model download (specs/006 T033, contracts/memorization-engine.md › AsrModel) against a
/// localhost server: states, `Range` resume, hash checks, delete and version change.
void main() {
  late HttpServer server;
  late Directory support;
  final served = <String, Uint8List>{};
  final ranges = <String?>[];
  var ignoreRange = false;
  late _FakeDevice device;

  Uint8List bytes(int n, int seed) => Uint8List.fromList([for (var i = 0; i < n; i++) (i * seed) & 0xFF]);

  final contents = {'a.onnx': bytes(70000, 7), 'b.onnx': bytes(30000, 13), 'tokens.txt': bytes(500, 3)};
  final files = [
    for (final MapEntry(key: name, value: b) in contents.entries)
      (name: name, bytes: b.length, sha256: sha256.convert(b).toString()),
  ];

  setUp(() async {
    served
      ..clear()
      ..addAll(contents);
    ranges.clear();
    ignoreRange = false;
    device = _FakeDevice();
    support = Directory.systemTemp.createTempSync('mathani_asr');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = served[request.uri.pathSegments.last];
      final range = request.headers.value(HttpHeaders.rangeHeader);
      ranges.add(range);
      final r = request.response;
      if (body == null) {
        r.statusCode = HttpStatus.notFound;
      } else if (range != null && !ignoreRange) {
        final from = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        r
          ..statusCode = HttpStatus.partialContent
          ..headers.set(HttpHeaders.contentRangeHeader, 'bytes $from-${body.length - 1}/${body.length}')
          ..add(body.sublist(from));
      } else {
        r.add(body);
      }
      await r.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    support.deleteSync(recursive: true);
  });

  AsrModel model({String version = 'v1'}) => AsrModel(
        device: device,
        version: version,
        files: files,
        base: Uri.parse('http://127.0.0.1:${server.port}/release/'),
        supportRoot: () async => support,
      );

  test('absent, then downloading, then ready with every file in place', () async {
    final m = model();
    await m.refresh();
    expect(m.state, AsrModelState.absent);
    expect(m.totalBytes, 100500);
    final states = <AsrModelState>[];
    m.addListener(() => states.add(m.state));
    await m.download();
    expect(states, contains(AsrModelState.downloading));
    expect(m.state, AsrModelState.ready);
    expect(m.downloadedBytes, m.totalBytes);
    expect(m.modelDir, '${support.path}/asr/v1');
    for (final f in files) {
      expect(File('${m.modelDir}/${f.name}').readAsBytesSync(), contents[f.name]);
    }
    expect(ranges, [null, null, null]);
    expect(device.excluded, ['${support.path}/asr']);
  });

  test('resumes a partial file with Range', () async {
    final dir = Directory('${support.path}/asr/v1')..createSync(recursive: true);
    File('${dir.path}/a.onnx.part').writeAsBytesSync(contents['a.onnx']!.sublist(0, 25000));
    final m = model();
    await m.refresh();
    expect(m.state, AsrModelState.partial);
    expect(m.downloadedBytes, 25000);
    await m.download();
    expect(m.state, AsrModelState.ready);
    expect(ranges.first, 'bytes=25000-');
    expect(File('${dir.path}/a.onnx').readAsBytesSync(), contents['a.onnx']);
  });

  test('a server that ignores Range sends the whole file, which replaces the part', () async {
    final dir = Directory('${support.path}/asr/v1')..createSync(recursive: true);
    File('${dir.path}/a.onnx.part').writeAsBytesSync(contents['a.onnx']!.sublist(0, 25000));
    ignoreRange = true;
    final m = model();
    await m.download();
    expect(m.state, AsrModelState.ready);
    expect(File('${dir.path}/a.onnx').readAsBytesSync(), contents['a.onnx']);
  });

  test('a hash mismatch deletes the part and fails; the verified files stay', () async {
    served['b.onnx'] = bytes(30000, 17); // same length, other bytes
    final m = model();
    await expectLater(m.download(), throwsA(isA<AsrModelException>()
        .having((e) => e.error, 'error', AsrModelError.damaged)));
    final dir = '${support.path}/asr/v1';
    expect(File('$dir/b.onnx.part').existsSync(), isFalse);
    expect(File('$dir/b.onnx').existsSync(), isFalse);
    expect(File('$dir/a.onnx').existsSync(), isTrue);
    expect(m.state, AsrModelState.partial);
  });

  test('a missing file fails the download', () async {
    served.remove('tokens.txt');
    final m = model();
    await expectLater(m.download(), throwsA(isA<AsrModelException>()
        .having((e) => e.error, 'error', AsrModelError.failed)));
    expect(m.state, AsrModelState.partial);
  });

  test('delete frees the files at once', () async {
    final m = model();
    await m.download();
    await m.delete();
    expect(m.state, AsrModelState.absent);
    expect(m.downloadedBytes, 0);
    expect(Directory('${support.path}/asr').existsSync(), isFalse);
  });

  test('a new version is not ready, and its download removes the old one', () async {
    await model().download();
    final next = model(version: 'v2');
    await next.refresh();
    expect(next.state, AsrModelState.absent);
    await next.download();
    expect(next.state, AsrModelState.ready);
    expect(Directory('${support.path}/asr/v1').existsSync(), isFalse);
  });
}
