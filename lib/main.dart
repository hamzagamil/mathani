import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/quran_repository.dart';
import 'data/user_repository.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/recitation/ayah_fetcher.dart';
import 'features/recitation/media_handler.dart';
import 'features/recitation/recitation_controller.dart';
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
  // Recitations (specs/004): nothing here touches the network, audio or disk before the first
  // frame; the fetcher and player start on the first play.
  final recitation = RecitationController(
    reader: controller,
    fetcher: AyahFetcher(
      recordingSize: (r, s, a) async => (await quran.recordingBytes(r, s))[a - 1],
    ),
  );
  // Lock screen and notification controls start with the first recitation, not at launch.
  recitation.onFirstPlay = () => RecitationMediaHandler.start(recitation);
  // First run, or the first launch after updating from 1.3.0: the onboarding (specs/005).
  final onboarding = OnboardingController(reader: controller, recitation: recitation);
  runApp(MathaniApp(controller: controller, recitation: recitation, onboarding: onboarding));
}
