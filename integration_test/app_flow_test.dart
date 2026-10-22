// End-to-end on a real device or emulator (task T063): quickstart scenarios 1, 2, 4, 5, 6, 7, 10.
//   flutter test integration_test/app_flow_test.dart -d <device>
// Run with networking disabled to prove scenario 1 (offline from first launch).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/data/quran_repository.dart';
import 'package:mathani/data/user_repository.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import 'toolbar.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ReaderController reader;

  Future<void> launch(WidgetTester tester) async {
    final (quran, user) = await (QuranRepository.open(), UserRepository.open()).wait;
    final (anchor, prefs) = await user.loadStartup();
    reader = ReaderController(quran: quran, user: user, anchor: anchor, preferences: prefs);
    await tester.pumpWidget(MathaniApp(controller: reader));
    await tester.pumpAndSettle();
  }

  testWidgets('1–2: opens offline and turns pages right-to-left', (tester) async {
    await launch(tester);
    reader.jumpTo(const AyahRef(1, 1), highlight: false);
    await tester.pumpAndSettle();
    expect(reader.page, 1);
    for (var p = 2; p <= 5; p++) {
      await tester.drag(find.byType(PageView), const Offset(300, 0)); // left → right = next
      await tester.pumpAndSettle();
      expect(reader.page, p);
    }
  });

  testWidgets('4: reading position survives an app pause and restart', (tester) async {
    await launch(tester);
    reader.jumpTo(const AyahRef(18, 1), highlight: false);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    final (anchor, _) = await (await UserRepository.open()).loadStartup();
    expect(anchor, const AyahRef(18, 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('5: navigation to a juz in 3 taps', (tester) async {
    await launch(tester);
    await tapToolbar(tester, MathaniIcons.index);
    await tester.pumpAndSettle();
    await tester.tap(find.text(reader.preferences.language == LanguagePref.ar ? 'الأجزاء' : 'Ajza\''));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell).first); // Juz 1 header
    await tester.pumpAndSettle();
    expect(reader.page, 1);
  });

  testWidgets('6: bookmark the page and see it in the index', (tester) async {
    await launch(tester);
    reader.jumpTo(const AyahRef(36, 1), highlight: false);
    await tester.pumpAndSettle();
    await tapToolbar(tester, MathaniIcons.bookmark);
    await tester.pumpAndSettle();
    expect(reader.user.bookmarksOnPage(reader.page), isNotEmpty);
  });

  testWidgets('7 and 10: layout toggle keeps the ayah; language switch is live', (tester) async {
    await launch(tester);
    const target = AyahRef(3, 92);
    reader.jumpTo(target, highlight: false);
    await tester.pumpAndSettle();
    await tapToolbar(tester, MathaniIcons.flowing);
    await tester.pumpAndSettle();
    expect(reader.anchor, target);
    await tapToolbar(tester, MathaniIcons.mushaf);
    await tester.pumpAndSettle();
    expect(reader.anchor, target);

    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.en));
    await tester.pumpAndSettle();
    expect(find.textContaining('Juz'), findsOneWidget);
    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar));
    await tester.pumpAndSettle();
    expect(find.textContaining('الجزء'), findsOneWidget);
  });
}
