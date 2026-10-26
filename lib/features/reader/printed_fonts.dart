import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../platform/gunzip.dart';

/// The King Fahd Complex page fonts bundled with the app, one per Mushaf page
/// (specs/002-print-like-mushaf-page, User Story 4). They ship gzip-compressed in `assets/qcf/`
/// and are inflated and registered the first time their page is shown.
///
/// A registered font cannot be unregistered, so each page font stays in memory for the rest of
/// the session once its page has been shown (about 0.35 MB each).
class PrintedFonts {
  PrintedFonts._();

  static final Map<int, Future<String>> _loading = {};
  static final Set<int> _loaded = {};

  /// The font family of [page]'s font.
  static String familyOf(int page) => 'qcf_p${page.toString().padLeft(3, '0')}';

  /// The bundled, gzip-compressed font file of [page].
  static String assetOf(int page) => 'assets/qcf/p${page.toString().padLeft(3, '0')}.ttf.gz';

  /// Whether [page]'s font is ready to draw with.
  static bool isLoaded(int page) => _loaded.contains(page);

  /// Loads and registers [page]'s font once; completes with its family. A failed load is
  /// forgotten, so the next call tries again.
  static Future<String> load(int page, {AssetBundle? bundle}) => _loading[page] ??= () async {
        try {
          final family = familyOf(page);
          final data = await (bundle ?? rootBundle).load(assetOf(page));
          final bytes = await gunzip(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
          final font = ByteData.sublistView(bytes);
          await (FontLoader(family)..addFont(Future.value(font))).load();
          _loaded.add(page);
          return family;
        } catch (_) {
          _loading.remove(page);
          rethrow;
        }
      }();

  /// Forgets loads in progress. Tests call it between tests, whose loads cannot finish once the
  /// test that started them has ended.
  @visibleForTesting
  static void reset() {
    _loading.clear();
    _loaded.clear();
  }
}
