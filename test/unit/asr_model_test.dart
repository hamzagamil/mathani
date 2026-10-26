import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/memorization/asr_model.dart';
import 'package:mathani/platform/device.dart';
import 'package:mathani/platform/file_store_io.dart';

/// Records the folders kept out of backups.
class _FakeDevice extends DeviceChannel {
  final excluded = <String>[];

  @override
  Future<void> excludeFromBackup(String path) async => excluded.add(path);
}

/// The model download (specs/006 T033, contracts/memorization-engine.md › AsrModel; specs/007
/// T010, T034) against a localhost server: states, `Range` resume, hash checks, the packed model
/// and its unpack, delete, version change and the clean-up after updating.
void main() {
  late HttpServer server;
  late Directory support;
  final served = <String, Uint8List>{};
  final ranges = <String?>[];
  var ignoreRange = false;
  late _FakeDevice device;

  Uint8List bytes(int n, int seed) => Uint8List.fromList([for (var i = 0; i < n; i++) (i * seed) & 0xFF]);

  final contents = {'a.onnx': bytes(70000, 7), 'b.onnx': bytes(30000, 13), 'tokens.txt': bytes(500, 3)};
  final plainFiles = [
    for (final MapEntry(key: name, value: b) in contents.entries)
      AsrFile(name, b.length, sha256.convert(b).toString()),
  ];

  // A packed file, as the Khatma model is shipped: model.onnx.gz unpacks to model.onnx.
  final unpacked = bytes(40000, 11);
  final packedBytes = Uint8List.fromList(gzip.encode(unpacked));
  AsrFile packedFile({String? unpackedSha}) => AsrFile(
        'model.onnx.gz',
        packedBytes.length,
        sha256.convert(packedBytes).toString(),
        unpackedBytes: unpacked.length,
        unpackedSha256: unpackedSha ?? sha256.convert(unpacked).toString(),
      );

  setUp(() async {
    served
      ..clear()
      ..addAll(contents)
      ..['model.onnx.gz'] = packedBytes;
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

  AsrModel model({String version = 'v1', List<AsrFile>? files}) => AsrModel(
        device: device,
        version: version,
        files: files ?? plainFiles,
        base: Uri.parse('http://127.0.0.1:${server.port}/release/'),
        store: IoFileStore(supportRoot: () async => support, device: device),
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
    for (final f in plainFiles) {
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

  group('packed file', () {
    test('downloads, unpacks, checks and keeps only the unpacked file', () async {
      final f = packedFile();
      final m = model(files: [f, plainFiles.last]);
      expect(m.totalBytes, packedBytes.length + 500);
      expect(m.diskBytes, unpacked.length + 500);
      expect(m.requiredBytes, packedBytes.length + 500 + unpacked.length);
      await m.download();
      expect(m.state, AsrModelState.ready);
      expect(m.downloadedBytes, m.totalBytes);
      expect(File('${m.modelDir}/model.onnx').readAsBytesSync(), unpacked);
      expect(File('${m.modelDir}/model.onnx.gz').existsSync(), isFalse);
      expect(File('${m.modelDir}/model.onnx.part').existsSync(), isFalse);
    });

    test('an unpack that does not match is deleted and reported damaged', () async {
      final m = model(files: [packedFile(unpackedSha: '0' * 64)]);
      await expectLater(m.download(), throwsA(isA<AsrModelException>()
          .having((e) => e.error, 'error', AsrModelError.damaged)));
      expect(File('${support.path}/asr/v1/model.onnx').existsSync(), isFalse);
      expect(File('${support.path}/asr/v1/model.onnx.part').existsSync(), isFalse);
      expect(m.state, isNot(AsrModelState.ready));
    });

    test('a downloaded .gz left by a closed app is unpacked without fetching it again', () async {
      final dir = Directory('${support.path}/asr/v1')..createSync(recursive: true);
      File('${dir.path}/model.onnx.gz').writeAsBytesSync(packedBytes);
      final m = model(files: [packedFile()]);
      await m.refresh();
      expect(m.state, AsrModelState.partial);
      expect(m.downloadedBytes, packedBytes.length);
      await m.download();
      expect(m.state, AsrModelState.ready);
      expect(ranges, isEmpty);
      expect(File('${dir.path}/model.onnx').readAsBytesSync(), unpacked);
    });

    test('a .gz that is not gzip is deleted and reported damaged', () async {
      final dir = Directory('${support.path}/asr/v1')..createSync(recursive: true);
      final junk = bytes(packedBytes.length, 5);
      File('${dir.path}/model.onnx.gz').writeAsBytesSync(junk);
      final m = model(files: [
        AsrFile('model.onnx.gz', junk.length, sha256.convert(junk).toString(),
            unpackedBytes: unpacked.length, unpackedSha256: sha256.convert(unpacked).toString()),
      ]);
      await expectLater(m.download(), throwsA(isA<AsrModelException>()
          .having((e) => e.error, 'error', AsrModelError.damaged)));
      expect(File('${dir.path}/model.onnx.gz').existsSync(), isFalse);
    });
  });

  group('removeOtherVersions', () {
    test('deletes every other version and keeps the current one', () async {
      File('${support.path}/asr/asr-tarteel-tiny-v1/encoder.int8.onnx')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      File('${support.path}/asr/asr-khatma-v1/tokens.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync('t');
      await AsrModel.removeOtherVersions(store: IoFileStore(supportRoot: () async => support));
      expect(Directory('${support.path}/asr/asr-tarteel-tiny-v1').existsSync(), isFalse);
      expect(File('${support.path}/asr/asr-khatma-v1/tokens.txt').existsSync(), isTrue);
    });

    test('completes when there is no model folder', () async {
      await AsrModel.removeOtherVersions(store: IoFileStore(supportRoot: () async => support));
      expect(Directory('${support.path}/asr').existsSync(), isFalse);
    });

    test('never throws, even without a support directory', () async {
      await AsrModel.removeOtherVersions(
          store: IoFileStore(supportRoot: () async => throw const FileSystemException('none')));
    });
  });
}
