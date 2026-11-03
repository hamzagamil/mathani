import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mutashabihat_content.dart';

const mutashabihatAsset = 'assets/mutashabihat/mutashabihat.md';

/// Reads the owner's content file (specs/010 research R3). A missing or unreadable file gives no
/// content, and the reader works as before (FR-019); groups with errors are left out.
Future<Mutashabihat> loadMutashabihat({AssetBundle? bundle}) async {
  try {
    return parseMutashabihat(await (bundle ?? rootBundle).loadString(mutashabihatAsset)).$1;
  } catch (e) {
    debugPrint('Mutashabihat content not loaded: $e');
    return Mutashabihat.empty;
  }
}
