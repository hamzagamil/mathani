import 'dart:async';
import 'dart:typed_data';

import 'package:mathani/platform/file_store.dart';

/// A [FileStore] in memory (specs/008 T008), for tests that need no real files, or a full disk.
class MemoryFileStore implements FileStore {
  final _files = <StoreFile, ({Uint8List bytes, DateTime modified})>{};

  /// Free bytes reported to downloads.
  int free = 1 << 40;

  /// After this many more bytes are appended, [append] throws [NoSpaceException].
  int? failWithNoSpaceAfter;

  /// Directories asked to be protected, as `root:dir`.
  final protected = <String>[];

  bool exists(StoreFile f) => _files.containsKey(f);

  Uint8List bytesOf(StoreFile f) => _files[f]!.bytes;

  void put(StoreFile f, List<int> bytes, {DateTime? modified}) =>
      _files[f] = (bytes: Uint8List.fromList(bytes), modified: modified ?? DateTime.now());

  @override
  Future<int?> length(StoreFile file) async => _files[file]?.bytes.length;

  @override
  Future<void> append(StoreFile file, Stream<List<int>> chunks) async {
    final out = BytesBuilder(copy: false)..add(_files[file]?.bytes ?? Uint8List(0));
    try {
      await for (final chunk in chunks) {
        final limit = failWithNoSpaceAfter;
        if (limit != null) {
          if (chunk.length > limit) throw const NoSpaceException();
          failWithNoSpaceAfter = limit - chunk.length;
        }
        out.add(chunk);
      }
    } finally {
      put(file, out.takeBytes());
    }
  }

  @override
  Future<void> copy(StoreFile from, StoreFile to) async => put(to, bytesOf(from));

  @override
  Future<void> rename(StoreFile from, StoreFile to) async => _files[to] = _files.remove(from)!;

  @override
  Future<bool> delete(StoreFile file) async => _files.remove(file) != null;

  @override
  Future<void> deleteDir(StoreRoot root, String dir) async =>
      _files.removeWhere((f, _) => f.root == root && f.path.startsWith('$dir/'));

  @override
  Future<List<StoreEntry>> list(StoreRoot root, String dir, {bool recursive = false}) async {
    final entries = <String, StoreEntry>{};
    for (final MapEntry(key: f, value: v) in _files.entries) {
      if (f.root != root || !f.path.startsWith('$dir/')) continue;
      final rest = f.path.substring(dir.length + 1).split('/');
      for (var depth = 1; depth <= rest.length; depth++) {
        if (!recursive && depth > 1) break;
        final path = '$dir/${rest.take(depth).join('/')}';
        final isDir = depth < rest.length;
        entries[path] = (
          path: path,
          bytes: isDir ? 0 : v.bytes.length,
          modified: isDir ? DateTime(0) : v.modified,
          isDir: isDir,
        );
      }
    }
    return entries.values.toList();
  }

  @override
  Stream<List<int>> read(StoreFile file) => Stream.value(bytesOf(file));

  @override
  Future<void> touch(StoreFile file) async => put(file, bytesOf(file));

  @override
  Future<Uri> playableUri(StoreFile file) async => Uri.parse('memory:$file');

  @override
  void release(Uri uri) {}

  @override
  Future<String> locate(StoreRoot root, String dir) async => '${root.name}/$dir';

  @override
  Future<int> freeBytes() async => free;

  @override
  Future<void> protect(StoreRoot root, String dir) async => protected.add('${root.name}:$dir');
}
