import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'device.dart';
import 'file_store.dart';

FileStore fileStore() => IoFileStore();

/// [FileStore] over the app's cache and support directories.
class IoFileStore implements FileStore {
  /// The roots default to the app's directories; tests pass temporary ones.
  IoFileStore({
    Future<Directory> Function()? cacheRoot,
    Future<Directory> Function()? supportRoot,
    this.device = const DeviceChannel(),
  })  : _cacheRoot = cacheRoot ?? getApplicationCacheDirectory,
        _supportRoot = supportRoot ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _cacheRoot;
  final Future<Directory> Function() _supportRoot;
  final DeviceChannel device;

  Future<String> _rootPath(StoreRoot root) async =>
      (await (root == StoreRoot.cache ? _cacheRoot : _supportRoot)()).path;

  /// The file on disk, for code that needs a path (the speech isolate, tests).
  Future<File> fileOf(StoreFile file) async => File('${await _rootPath(file.root)}/${file.path}');

  Future<Directory> dirOf(StoreRoot root, String dir) async =>
      Directory(dir.isEmpty ? await _rootPath(root) : '${await _rootPath(root)}/$dir');

  @override
  Future<int?> length(StoreFile file) async {
    try {
      return await (await fileOf(file)).length();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> append(StoreFile file, Stream<List<int>> chunks) async {
    final f = await fileOf(file);
    try {
      await f.parent.create(recursive: true);
      final sink = f.openWrite(mode: FileMode.append);
      try {
        await sink.addStream(chunks);
      } finally {
        await sink.close();
      }
    } on FileSystemException catch (e) {
      if (isNoSpace(e)) throw const NoSpaceException();
      rethrow;
    }
  }

  @override
  Future<void> copy(StoreFile from, StoreFile to) async {
    final target = await fileOf(to);
    try {
      await target.parent.create(recursive: true);
      await (await fileOf(from)).copy(target.path);
    } on FileSystemException catch (e) {
      if (isNoSpace(e)) throw const NoSpaceException();
      rethrow;
    }
  }

  @override
  Future<void> rename(StoreFile from, StoreFile to) async =>
      (await fileOf(from)).rename((await fileOf(to)).path);

  @override
  Future<bool> delete(StoreFile file) async {
    try {
      await (await fileOf(file)).delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<void> deleteDir(StoreRoot root, String dir) async {
    final d = await dirOf(root, dir);
    if (await d.exists()) await d.delete(recursive: true);
  }

  @override
  Future<List<StoreEntry>> list(StoreRoot root, String dir, {bool recursive = false}) async {
    final base = await _rootPath(root);
    final d = await dirOf(root, dir);
    final entries = <StoreEntry>[];
    try {
      if (!await d.exists()) return entries;
      await for (final e in d.list(recursive: recursive)) {
        final path = e.path.substring(base.length + 1).replaceAll(r'\', '/');
        try {
          final s = await e.stat();
          entries.add((path: path, bytes: s.size, modified: s.modified, isDir: e is Directory));
        } on FileSystemException {
          // Deleted meanwhile.
        }
      }
    } on FileSystemException {
      // The directory was cleared (by the reader or the OS) while listing: use what was found.
    }
    return entries;
  }

  @override
  Stream<List<int>> read(StoreFile file) async* {
    yield* (await fileOf(file)).openRead();
  }

  @override
  Future<void> touch(StoreFile file) async {
    try {
      await (await fileOf(file)).setLastModified(DateTime.now());
    } on FileSystemException {
      // Best effort: LRU order only.
    }
  }

  @override
  Future<Uri> playableUri(StoreFile file) async => Uri.file((await fileOf(file)).path);

  @override
  void release(Uri uri) {}

  @override
  Future<String> locate(StoreRoot root, String dir) async => (await dirOf(root, dir)).path;

  @override
  Future<int> freeBytes() => device.freeBytes();

  @override
  Future<void> protect(StoreRoot root, String dir) async {
    final d = await dirOf(root, dir);
    await d.create(recursive: true);
    await device.excludeFromBackup(d.path);
  }

  /// Whether [e] means the disk is full.
  static bool isNoSpace(FileSystemException e) {
    final code = e.osError?.errorCode;
    return code == 28 /* ENOSPC */ || code == 112 /* ERROR_DISK_FULL */;
  }
}
