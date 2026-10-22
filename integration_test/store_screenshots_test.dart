// App Store / Google Play screenshots in Arabic (docs/store/listing_ar.md, screenshot plan).
//   flutter drive --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/store_screenshots_test.dart --dart-define=STORE_SCREENSHOTS=true \
//     -d <simulator>
// Writes build/screenshots/<n>-<name>.png at the device's pixel size; run by
// .github/workflows/store-screenshots.yml on a 6.3" iPhone simulator.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/data/quran_repository.dart';
import 'package:mathani/data/user_repository.dart';
import 'package:mathani/features/reader/ayah_actions.dart';
import 'package:mathani/features/reader/reader_screen.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Only when asked (store-screenshots workflow), not in the regular integration test run.
  const enabled = bool.fromEnvironment('STORE_SCREENSHOTS');

  testWidgets('store screenshots', skip: !enabled, (tester) async {
    final (quran, user) = await (QuranRepository.open(), UserRepository.open()).wait;
    final (anchor, prefs) = await user.loadStartup();
    final reader = ReaderController(quran: quran, user: user, anchor: anchor, preferences: prefs);
    await tester.pumpWidget(MathaniApp(controller: reader));
    await tester.pumpAndSettle();

    Future<void> setPrefs(ReaderPreferences Function(ReaderPreferences p) change) async {
      reader.updatePreferences(change(reader.preferences));
      await tester.pumpAndSettle();
    }

    Future<void> open(AyahRef ref) async {
      reader.jumpTo(ref, highlight: false);
      await tester.pumpAndSettle();
    }

    Future<void> shot(String name) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    Future<void> back() async {
      await tester.tap(find.byIcon(MathaniIcons.back));
      await tester.pumpAndSettle();
    }

    await setPrefs((p) => p.copyWith(
          language: LanguagePref.ar,
          theme: ThemePref.day,
          layout: ReadingLayout.mushaf,
        ));

    // 1. A full Mushaf page (Al-Mulk, page 562), day theme.
    await open(const AyahRef(67, 1));
    await shot('1-mushaf-day');

    // 2. Start of Al-Baqara (page 2), night theme.
    await setPrefs((p) => p.copyWith(theme: ThemePref.night));
    await open(const AyahRef(2, 1));
    await shot('2-mushaf-night');
    await setPrefs((p) => p.copyWith(theme: ThemePref.day));

    // 3. Flowing text.
    await setPrefs((p) => p.copyWith(layout: ReadingLayout.flowing));
    await open(const AyahRef(67, 1));
    await shot('3-flowing');
    await setPrefs((p) => p.copyWith(layout: ReadingLayout.mushaf));

    // 4. Surah index.
    await open(const AyahRef(18, 1));
    await tester.tap(find.byIcon(MathaniIcons.index));
    await tester.pumpAndSettle();
    await shot('4-index');
    await back();

    // 5. Search with highlighted matches.
    await tester.tap(find.byIcon(MathaniIcons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'الصبر');
    await tester.pump(const Duration(milliseconds: 400)); // search debounce
    await tester.pumpAndSettle();
    await shot('5-search');
    await back();

    // 6. Ayah actions: copy, share, bookmark.
    await open(const AyahRef(67, 3));
    // Not awaited: the future completes when the sheet closes.
    showAyahActions(tester.element(find.byType(ReaderScreen)), const AyahRef(67, 3));
    await tester.pumpAndSettle();
    await shot('6-ayah-actions');
  });
}
