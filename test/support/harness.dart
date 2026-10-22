import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/quran_repository.dart';
import 'package:mathani/data/user_repository.dart';
import 'package:mathani/features/reader/printed_fonts.dart';
import 'package:mathani/shared/reader_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Loads the bundled fonts so widget tests render real glyphs instead of test boxes.
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await loader.load();
  }

  await load('PlexArabic', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/IBMPlexSansArabic-$w.ttf',
  ]);
  await load('QuranText', ['assets/fonts/AmiriQuran-Regular.ttf']);
  await load('Lucide', ['assets/fonts/Lucide.ttf']);
}

/// Opens the real repositories against the bundled quran.db, using SQLite through FFI and a
/// fresh temporary user database.
Future<ReaderController> openTestReader() async {
  PrintedFonts.reset(); // font loads from a previous test can never finish
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dir = Directory.systemTemp.createTempSync('mathani_test');
  await databaseFactory.setDatabasesPath(dir.path);
  final (quran, user) = await (QuranRepository.open(), UserRepository.open()).wait;
  final (anchor, prefs) = await user.loadStartup();
  return ReaderController(quran: quran, user: user, anchor: anchor, preferences: prefs);
}

/// Taps a reader toolbar button. In the Mushaf layout the controls hide while reading
/// (specs/002-print-like-mushaf-page), so the page is tapped first to bring them back.
Future<void> tapToolbar(WidgetTester tester, IconData icon) async {
  final button = find.byIcon(icon);
  if (button.hitTestable().evaluate().isEmpty) {
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }
  await tester.tap(button);
}
