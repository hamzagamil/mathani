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
    // Safari before 26 (all of iOS 18 and earlier) cannot write from the page: a worker does.
    if (forceWorkerWrites || !h!.has('createWritable')) return _workerAppend(file, chunks);
    _Writable? writable;
    try {
      writable = await _guard(() => h.createWritable(_keep()).toDart);
      await _guard(() async => writable!.seek((await h.getFile().toDart).size).toDart);
    } on Object {
      // If Safari exposes createWritable but cannot open or seek it for this OPFS file, retry
      // through its worker-only synchronous access handle. The stream has not been consumed yet.
      try {
        await writable?.close().toDart;
      } on Object {
        // The writable may already have been closed by the failed operation.
      }
      await delete(file);
      return _workerAppend(file, chunks);
    }
    try {
      await _guard(() async {
        await for (final chunk in chunks) {
          final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
          await writable!.write(bytes.toJS).toDart;
        }
      });
    } finally {
      try {
        await writable!.close().toDart;
      } on Object {
        // Already closed by a failed write.
      }
    }
  }

  /// Builds that test the worker path in Chrome: `--dart-define=MATHANI_OPFS_WORKER=true`.
  static const forceWorkerWrites = bool.fromEnvironment('MATHANI_OPFS_WORKER');

  _Worker? _writer;
  int _seq = 0;
  int _writes = 0;
  final _replies = <int, Completer<void>>{};

  /// Sends one message to web/opfs_writer.js and waits for its answer, so a failed write stops
  /// the append and memory stays bounded to one chunk in flight.
  Future<void> _ask(Map<String, Object?> message, [JSArrayBuffer? transfer]) {
    final writer = _writer ??= _Worker('opfs_writer.js'.toJS)
      ..onmessage = ((_MessageEvent e) {
        final reply = e.data as JSObject;
        final done = _replies.remove((reply['seq'] as JSNumber).toDartInt);
        if (done == null) return;
        if ((reply['ok'] as JSBoolean).toDart) {
          done.complete();
        } else {
          final error = (reply['error'] as JSString?)?.toDart ?? 'write failed';
          done.completeError(error.contains('Quota') ? const NoSpaceException() : StateError(error));
        }
      }).toJS;
    final seq = ++_seq;
    final done = _replies[seq] = Completer<void>();
    final js = message.jsify()! as JSObject..['seq'] = seq.toJS;
    if (transfer == null) {
      writer.postMessage(js);
    } else {
      js['buffer'] = transfer;
      writer.postMessage(js, [transfer].toJS);
    }
    return done.future;
  }

  Future<void> _workerAppend(StoreFile file, Stream<List<int>> chunks) async {
    final id = ++_writes;
    final dirs = [
      file.root.name,
      ...file.dir.split('/').where((s) => s.isNotEmpty),
    ];
    await _ask({'type': 'open', 'id': id, 'dirs': dirs, 'name': _name(file.path)});
    try {
      await for (final chunk in chunks) {
        // A copy the worker can own: transferring detaches the buffer it came from.
        final bytes = Uint8List.fromList(chunk);
        await _ask({'type': 'write', 'id': id}, bytes.buffer.toJS);
      }
    } finally {
      try {
        await _ask({'type': 'close', 'id': id});
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
    final f = await h.getFile().toDart;
    // Safari may reject audio from a blob URL when the blob has no MIME type. OPFS files
    // created by the app have an empty type, so add the type from the known file extension.
    final type = switch (_name(file.path).split('.').last.toLowerCase()) {
      'mp3' => 'audio/mpeg',
      'png' => 'image/png',
      _ => null,
    };
    final blob = type == null ? f.slice(0, f.size) : f.slice(0, f.size, type);
    return Uri.parse(_URL.createObjectURL(blob));
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
  external _Blob slice(int start, int end, [String contentType]);
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type _Blob._(JSObject _) implements JSObject {
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type _AsyncIterator._(JSObject _) implements JSObject {
  external JSPromise<_IteratorStep> next();
}

extension type _IteratorStep._(JSObject _) implements JSObject {
  external bool get done;
  external _Handle get value;
}

@JS('Worker')
extension type _Worker._(JSObject _) implements JSObject {
  external factory _Worker(JSString url);
  external set onmessage(JSFunction handler);
  external void postMessage(JSAny? message, [JSArray<JSAny?> transfer]);
}

extension type _MessageEvent._(JSObject _) implements JSObject {
  external JSAny? get data;
}

@JS('URL')
extension type _URL._(JSObject _) implements JSObject {
  external static String createObjectURL(_Blob blob);
  external static void revokeObjectURL(String url);
}

JSObject _create(bool create) => {'create': create}.jsify()! as JSObject;
JSObject _keep() => {'keepExistingData': true}.jsify()! as JSObject;
JSObject _recursive() => {'recursive': true}.jsify()! as JSObject;
