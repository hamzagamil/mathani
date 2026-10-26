import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'device.dart';
import 'file_store.dart';

FileStore fileStore() => _store;
final _store = OpfsFileStore();

/// [FileStore] over the browser's Origin Private File System (specs/008 research R7). Each root
/// is a top-level OPFS directory.
class OpfsFileStore implements FileStore {
  /// Chunk size for reading files back.
  static const readChunk = 1 << 20;

  Future<_Dir>? _origin;

  Future<_Dir> _rootDir(StoreRoot root) async {
    final origin = await (_origin ??= _navigator.storage.getDirectory().toDart);
    return origin.getDirectoryHandle(root.name, _create(true)).toDart;
  }

  /// The directory [dir] under [root]; null when [create] is false and it does not exist.
  Future<_Dir?> _dir(StoreRoot root, String dir, {bool create = false}) async {
    var d = await _rootDir(root);
    for (final name in dir.split('/').where((s) => s.isNotEmpty)) {
      try {
        d = await d.getDirectoryHandle(name, _create(create)).toDart;
      } on Object {
        if (create) rethrow;
        return null;
      }
    }
    return d;
  }

  Future<_FileHandle?> _file(StoreFile file, {bool create = false}) async {
    final d = await _dir(file.root, file.dir, create: create);
    if (d == null) return null;
    try {
      return await d.getFileHandle(_name(file.path), _create(create)).toDart;
    } on Object {
      if (create) rethrow;
      return null;
    }
  }

  static String _name(String path) => path.substring(path.lastIndexOf('/') + 1);

  @override
  Future<int?> length(StoreFile file) async {
    final h = await _file(file);
    if (h == null) return null;
    return (await h.getFile().toDart).size;
  }

  @override
  Future<void> append(StoreFile file, Stream<List<int>> chunks) async {
    final h = await _file(file, create: true);
    final writable = await _guard(() => h!.createWritable(_keep()).toDart);
    try {
      await _guard(() async {
        await writable.seek((await h!.getFile().toDart).size).toDart;
        await for (final chunk in chunks) {
          final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
          await writable.write(bytes.toJS).toDart;
        }
      });
    } finally {
      try {
        await writable.close().toDart;
      } on Object {
        // Already closed by a failed write.
      }
    }
  }

  @override
  Future<void> copy(StoreFile from, StoreFile to) async {
    await delete(to);
    await append(to, read(from));
  }

  @override
  Future<void> rename(StoreFile from, StoreFile to) async {
    final h = await _file(from);
    if (h == null) throw StateError('rename: $from does not exist');
    if (from.dir == to.dir && h.has('move')) {
      await delete(to);
      await h.move(_name(to.path).toJS).toDart;
      return;
    }
    await copy(from, to);
    await delete(from);
  }

  @override
  Future<bool> delete(StoreFile file) async {
    final d = await _dir(file.root, file.dir);
    if (d == null) return false;
    try {
      await d.removeEntry(_name(file.path)).toDart;
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> deleteDir(StoreRoot root, String dir) async {
    final parentPath = dir.contains('/') ? dir.substring(0, dir.lastIndexOf('/')) : '';
    final parent = await _dir(root, parentPath);
    if (parent == null) return;
    try {
      await parent.removeEntry(_name(dir), _recursive()).toDart;
    } on Object {
      // Not there.
    }
  }

  @override
  Future<List<StoreEntry>> list(StoreRoot root, String dir, {bool recursive = false}) async {
    final entries = <StoreEntry>[];
    final d = await _dir(root, dir);
    if (d == null) return entries;
    Future<void> walk(_Dir d, String prefix) async {
      final it = d.values();
      while (true) {
        final step = await it.next().toDart;
        if (step.done) break;
        final handle = step.value;
        final path = prefix.isEmpty ? handle.name : '$prefix/${handle.name}';
        if (handle.kind == 'directory') {
          entries.add((path: path, bytes: 0, modified: DateTime(0), isDir: true));
          if (recursive) await walk(handle as _Dir, path);
        } else {
          final f = await (handle as _FileHandle).getFile().toDart;
          entries.add((
            path: path,
            bytes: f.size,
            modified: DateTime.fromMillisecondsSinceEpoch(f.lastModified),
            isDir: false,
          ));
        }
      }
    }

    try {
      await walk(d, dir);
    } on Object {
      // Cleared while listing: use what was found.
    }
    return entries;
  }

  @override
  Stream<List<int>> read(StoreFile file) async* {
    final h = await _file(file);
    if (h == null) throw StateError('read: $file does not exist');
    final f = await h.getFile().toDart;
    for (var at = 0; at < f.size; at += readChunk) {
      final end = at + readChunk < f.size ? at + readChunk : f.size;
      yield (await f.slice(at, end).arrayBuffer().toDart).toDart.asUint8List();
    }
  }

  @override
  Future<void> touch(StoreFile file) async {}

  @override
  Future<Uri> playableUri(StoreFile file) async {
    final h = await _file(file);
    if (h == null) throw StateError('playableUri: $file does not exist');
    return Uri.parse(_URL.createObjectURL(await h.getFile().toDart));
  }

  @override
  void release(Uri uri) {
    if (uri.scheme == 'blob') _URL.revokeObjectURL(uri.toString());
  }

  @override
  Future<String> locate(StoreRoot root, String dir) async => '${root.name}/$dir';

  @override
  Future<int> freeBytes() async {
    final e = await _navigator.storage.estimate().toDart;
    final free = (e.quota ?? 0) - (e.usage ?? 0);
    return free < 0 ? 0 : free.toInt();
  }

  @override
  Future<void> protect(StoreRoot root, String dir) => const DeviceChannel().keepBrowserData();

  /// Turns a full quota into [NoSpaceException].
  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on Object catch (e) {
      if (e.toString().contains('QuotaExceeded')) throw const NoSpaceException();
      rethrow;
    }
  }
}

// --- Browser API ---------------------------------------------------------------------------

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external _Storage get storage;
}

extension type _Storage._(JSObject _) implements JSObject {
  external JSPromise<_Dir> getDirectory();
  external JSPromise<_Estimate> estimate();
}

extension type _Estimate._(JSObject _) implements JSObject {
  external double? get quota;
  external double? get usage;
}

extension type _Handle._(JSObject _) implements JSObject {
  external String get kind;
  external String get name;
}

extension type _Dir._(JSObject _) implements _Handle {
  external JSPromise<_Dir> getDirectoryHandle(String name, JSObject options);
  external JSPromise<_FileHandle> getFileHandle(String name, JSObject options);
  external JSPromise<JSAny?> removeEntry(String name, [JSObject options]);
  external _AsyncIterator values();
}

extension type _FileHandle._(JSObject _) implements _Handle {
  external JSPromise<_File> getFile();
  external JSPromise<_Writable> createWritable(JSObject options);
  external JSPromise<JSAny?> move(JSString name);
}

extension type _Writable._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> seek(int position);
  external JSPromise<JSAny?> write(JSUint8Array data);
  external JSPromise<JSAny?> close();
}

extension type _File._(JSObject _) implements JSObject {
  external int get size;
  external int get lastModified;
  external _File slice(int start, int end);
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type _AsyncIterator._(JSObject _) implements JSObject {
  external JSPromise<_IteratorStep> next();
}

extension type _IteratorStep._(JSObject _) implements JSObject {
  external bool get done;
  external _Handle get value;
}

@JS('URL')
extension type _URL._(JSObject _) implements JSObject {
  external static String createObjectURL(_File file);
  external static void revokeObjectURL(String url);
}

JSObject _create(bool create) => {'create': create}.jsify()! as JSObject;
JSObject _keep() => {'keepExistingData': true}.jsify()! as JSObject;
JSObject _recursive() => {'recursive': true}.jsify()! as JSObject;
