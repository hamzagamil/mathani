import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/quran_repository.dart';
import 'data/user_repository.dart';
import 'shared/reader_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Both databases open in parallel; no network and no background work at startup.
  final (quran, user) = await (QuranRepository.open(), UserRepository.open()).wait;
  final (anchor, preferences) = await user.loadStartup();
  final controller = ReaderController(
    quran: quran,
    user: user,
    anchor: anchor,
    preferences: preferences,
  );
  runApp(MathaniApp(controller: controller));
}
