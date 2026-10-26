import 'dart:io';

import 'package:mathani/platform/file_store.dart';
import 'package:mathani/platform/file_store_io.dart';

/// An [IoFileStore] over `<dir>/cache` and `<dir>/support`, for tests that check real files
/// (specs/008 T015).
class TempStore {
  TempStore(this.dir)
      : store = IoFileStore(
          cacheRoot: () async => Directory('${dir.path}/cache'),
          supportRoot: () async => Directory('${dir.path}/support'),
        );

  final Directory dir;
  final IoFileStore store;

  /// The file on disk behind [f].
  File file(StoreFile f) => File('${dir.path}/${f.root.name}/${f.path}');
}
