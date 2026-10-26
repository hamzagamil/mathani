import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/platform/file_store.dart';
import 'package:mathani/platform/file_store_io.dart';

import '../support/temp_store.dart';

/// IoFileStore (specs/008 T009, contracts/web-platform.md › FileStore) over a temp directory.
void main() {
  late Directory temp;
  late TempStore t;
  late IoFileStore store;
  const a = StoreFile(StoreRoot.support, 'recitations/husary/067/001.mp3');
  const b = StoreFile(StoreRoot.support, 'recitations/husary/067/002.mp3');

  setUp(() {
    temp = Directory.systemTemp.createTempSync('mathani_store');
    t = TempStore(temp);
    store = t.store;
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('length is null for a missing file', () async {
    expect(await store.length(a), isNull);
  });

  test('append creates the file and its directories, and a second append resumes it', () async {
    await store.append(a.part, Stream.value([1, 2, 3]));
    await store.append(a.part, Stream.value([4, 5]));
    expect(t.file(a.part).readAsBytesSync(), [1, 2, 3, 4, 5]);
    expect(await store.length(a.part), 5);
  });

  test('rename replaces the target; copy duplicates', () async {
    await store.append(a, Stream.value([9]));
    await store.append(b.part, Stream.value([1, 2]));
    await store.rename(b.part, a);
    expect(t.file(a).readAsBytesSync(), [1, 2]);
    expect(t.file(b.part).existsSync(), isFalse);
    await store.copy(a, const StoreFile(StoreRoot.cache, 'x/y.mp3'));
    expect(await store.length(const StoreFile(StoreRoot.cache, 'x/y.mp3')), 2);
  });

  test('list gives relative paths, sizes and directories, recursively on request', () async {
    await store.append(a, Stream.value([1, 2, 3]));
    await store.append(const StoreFile(StoreRoot.support, 'recitations/husary/basmala.mp3'),
        Stream.value([1]));
    final top = await store.list(StoreRoot.support, 'recitations/husary');
    expect({for (final e in top) e.path: e.isDir}, {
      'recitations/husary/067': true,
      'recitations/husary/basmala.mp3': false,
    });
    final all = await store.list(StoreRoot.support, 'recitations', recursive: true);
    expect(all.singleWhere((e) => e.path == a.path).bytes, 3);
    expect(await store.list(StoreRoot.cache, 'nothing'), isEmpty);
  });

  test('delete and deleteDir', () async {
    await store.append(a, Stream.value([1]));
    expect(await store.delete(a), isTrue);
    expect(await store.delete(a), isFalse);
    await store.append(b, Stream.value([1]));
    await store.deleteDir(StoreRoot.support, 'recitations/husary');
    expect(Directory('${temp.path}/support/recitations/husary').existsSync(), isFalse);
    await store.deleteDir(StoreRoot.support, 'recitations/husary'); // already gone: no error
  });

  test('read streams the bytes back; touch moves the time; playableUri is a file URI', () async {
    await store.append(a, Stream.value([7, 8, 9]));
    expect(await store.read(a).expand((c) => c).toList(), [7, 8, 9]);
    t.file(a).setLastModifiedSync(DateTime(2020));
    await store.touch(a);
    expect(t.file(a).lastModifiedSync().year, greaterThan(2020));
    final uri = await store.playableUri(a);
    expect(uri.scheme, 'file');
    expect(File.fromUri(uri).readAsBytesSync(), [7, 8, 9]);
  });

  test('locate gives the absolute folder', () async {
    expect(await store.locate(StoreRoot.support, 'asr/v1'), '${temp.path}/support/asr/v1');
  });
}
