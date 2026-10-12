import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/quran_repository.dart';
import 'data/user_repository.dart';
import 'features/settings/about_section.dart';
import 'shared/reader_state.dart';

Future<void> main() => runMathani();

/// Opens the databases and starts the app. Shared with the browser preview (tool/web_preview.dart).
Future<void> runMathani() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAssetLicences(); // lazy: the files are read only when the licences page opens
  // Both databases open in parallel; no network and no background work at startup. The browser
  // preview shares one in-memory file system between them, so it opens them one at a time.
  final (quran, user) = kIsWeb
      ? (await QuranRepository.open(), await UserRepository.open())
      : await (QuranRepository.open(), UserRepository.open()).wait;
  final (anchor, preferences) = await user.loadStartup();
  final controller = ReaderController(
    quran: quran,
    user: user,
    anchor: anchor,
    preferences: preferences,
  );
  runApp(MathaniApp(controller: controller));
}
