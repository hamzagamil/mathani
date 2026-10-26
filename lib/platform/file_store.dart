// Files the app writes itself, on every platform (specs/008 contracts/web-platform.md ›
// FileStore, research R7): recordings and downloads (specs/004, 006) and the recognition model
// (specs/007). dart:io directories on phones, the Origin Private File System in browsers. Paths
// are relative to a root and always '/'-separated.
export 'file_store_io.dart' if (dart.library.js_interop) 'file_store_web.dart' show fileStore;

/// Where a file lives: the app's cache directory (the OS may clear it) or its support directory.
enum StoreRoot { cache, support }

/// One file in the store.
class StoreFile {
  const StoreFile(this.root, this.path);

  final StoreRoot root;

  /// Relative to [root], '/'-separated, e.g. `recitations/husary/067/001.mp3`.
  final String path;

  /// The file a download is written to before it is checked and renamed.
  StoreFile get part => StoreFile(root, '$path.part');

  /// The directory holding this file, relative to [root].
  String get dir => path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';

  @override
  bool operator ==(Object other) => other is StoreFile && other.root == root && other.path == path;

  @override
  int get hashCode => Object.hash(root, path);

  @override
  String toString() => '${root.name}:$path';
}

/// A file or directory found by [FileStore.list]; [path] is relative to the root.
typedef StoreEntry = ({String path, int bytes, DateTime modified, bool isDir});

/// The disk or the browser's storage quota is full.
class NoSpaceException implements Exception {
  const NoSpaceException();

  @override
  String toString() => 'NoSpaceException';
}

abstract class FileStore {
  /// Size in bytes, or null when the file does not exist.
  Future<int?> length(StoreFile file);

  /// Appends [chunks] to [file], creating it and its directories. Throws [NoSpaceException] when
  /// storage is full; what was written stays, for the caller to delete.
  Future<void> append(StoreFile file, Stream<List<int>> chunks);

  /// Copies [from] over [to], creating [to]'s directories.
  Future<void> copy(StoreFile from, StoreFile to);

  /// Replaces [to] with [from] (the `.part` → final step).
  Future<void> rename(StoreFile from, StoreFile to);

  /// Deletes [file]; false when it was not there or could not be deleted.
  Future<bool> delete(StoreFile file);

  /// Deletes [dir] and everything in it; nothing happens when it does not exist.
  Future<void> deleteDir(StoreRoot root, String dir);

  /// Entries under [dir] (directly, or at any depth when [recursive]); empty when [dir] does not
  /// exist.
  Future<List<StoreEntry>> list(StoreRoot root, String dir, {bool recursive = false});

  /// The file's bytes, in chunks.
  Stream<List<int>> read(StoreFile file);

  /// Marks [file] as just used, for the recent-recitations trim. Browsers cannot set a file's
  /// time, so there the trim goes by when a file was written.
  Future<void> touch(StoreFile file);

  /// A URI the audio player can play: `file://` on phones, a `blob:` URL in browsers. Pass it to
  /// [release] when it is no longer played.
  Future<Uri> playableUri(StoreFile file);
  void release(Uri uri);

  /// Where the speech engine finds [dir]: an absolute path on phones, the OPFS path
  /// (`<root>/<dir>`) in browsers.
  Future<String> locate(StoreRoot root, String dir);

  /// Free bytes for downloads.
  Future<int> freeBytes();

  /// Keeps [dir] safe: out of iCloud backups on iOS, and in browsers asks once for persistent
  /// storage, so the browser does not clear it under storage pressure (specs/008 FR-014).
  Future<void> protect(StoreRoot root, String dir);
}
