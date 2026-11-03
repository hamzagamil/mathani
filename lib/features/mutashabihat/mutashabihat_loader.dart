import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../platform/file_store.dart';
import 'mutashabihat_content.dart';

const mutashabihatAsset = 'assets/mutashabihat/mutashabihat.md';

/// The last complete, checked download (specs/011 data-model.md › App).
const downloadedContent = StoreFile(StoreRoot.support, 'mutashabihat/content.md');
const downloadedMeta = StoreFile(StoreRoot.support, 'mutashabihat/meta.json');

/// The content to start with: the bundled file (specs/010 research R3) or the last download
/// (specs/011), whichever is the newer version; the bundled one on a tie. A missing or unreadable
/// file gives no content, and the reader works as before (FR-019); groups with errors are left out.
Future<Mutashabihat> loadMutashabihat({AssetBundle? bundle, FileStore? store}) async {
  final (bundled, downloaded) = await (_bundled(bundle ?? rootBundle), _downloaded(store ?? fileStore())).wait;
  return downloaded != null && downloaded.version > bundled.version ? downloaded : bundled;
}

Future<Mutashabihat> _bundled(AssetBundle bundle) async {
  try {
    return parseMutashabihat(await bundle.loadString(mutashabihatAsset)).$1;
  } catch (e) {
    debugPrint('Mutashabihat content not loaded: $e');
    return Mutashabihat.empty;
  }
}

/// The downloaded copy, or null. A copy that no longer parses cleanly is deleted.
Future<Mutashabihat?> _downloaded(FileStore store) async {
  try {
    if (await store.length(downloadedContent) == null) return null;
    final (content, problems) = parseMutashabihat(await utf8.decoder.bind(store.read(downloadedContent)).join());
    if (content.groups.isNotEmpty && problems.every((p) => !p.isError)) return content;
    await store.delete(downloadedContent);
    await store.delete(downloadedMeta);
  } catch (e) {
    debugPrint('Downloaded Mutashabihat content not used: $e');
  }
  return null;
}
