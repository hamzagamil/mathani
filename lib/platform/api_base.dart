import 'package:flutter/foundation.dart';

/// Where the app's own API lives (specs/009 prayer places, specs/011 Mutashabihat content): the
/// page's origin in browsers, get.mthani.app on phones. `--dart-define=MATHANI_API_BASE=…` points a
/// run at a preview; only HTTPS, or plain HTTP to localhost.
Uri apiBase() {
  const override = String.fromEnvironment('MATHANI_API_BASE');
  final uri = override.isNotEmpty
      ? Uri.parse(override)
      : Uri.parse(kIsWeb ? Uri.base.origin : 'https://get.mthani.app');
  if (uri.scheme != 'https' &&
      !(uri.scheme == 'http' && ['localhost', '127.0.0.1'].contains(uri.host))) {
    throw ArgumentError('The API must use HTTPS');
  }
  return uri;
}
