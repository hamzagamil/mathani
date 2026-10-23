// The recitation bar, the Listen button and the page inset (specs/004
// contracts/recitation-ui.md › Reader toolbar, Recitation bar), with a fake player and fetcher.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/recitation/ayah_fetcher.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/features/recitation/recited_item.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

void main() {
  late ReaderController reader;
  late RecitationController recitation;
  late FakeAudioEngine engine;
  late FakeFetcher fetcher;

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> pumpApp(WidgetTester tester, {LanguagePref language = LanguagePref.ar}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
      await reader.quran.basmalaPageOf(2, printed: true);
      await reader.quran.basmalaPageOf(2, printed: false);
    });
    reader.updatePreferences(reader.preferences.copyWith(language: language));
    (recitation, engine, fetcher) = openTestRecitation(reader);
    tester.view.physicalSize = const Size(780, 1690);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MathaniApp(controller: reader, recitation: recitation));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await recitation.stop();
    await settle(tester, 2);
    await tester.pumpWidget(const SizedBox());
    recitation.dispose();
    await tester.pump(const Duration(seconds: 2));
  }

  Finder listen() => find.byTooltip('استمع');

  testWidgets('Listen starts at the page and docks the bar; ✕ closes it', (tester) async {
    await pumpApp(tester);
    expect(find.byIcon(MathaniIcons.close), findsNothing, reason: 'no bar without a session');
    final pageHeight = tester.getSize(find.byType(PageView)).height;

    await tester.tap(listen());
    await settle(tester);
    final s = recitation.session!;
    expect(s.item.ref, reader.quran.ayahsStartingOnPage(reader.page).first.ref);
    expect(s.status, RecitationStatus.playing);
    expect(listen(), findsNothing, reason: 'the bar takes the Listen button\'s place');
    expect(find.byTooltip('الآية التالية'), findsOneWidget);
    expect(find.bySemanticsLabel('مشغّل التلاوة'), findsOneWidget);

    // The page sits above the bar: never covered.
    final docked = tester.getSize(find.byType(PageView)).height;
    expect(docked, lessThan(pageHeight));
    expect(tester.getRect(find.byType(PageView)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byTooltip('الآية التالية')).top));

    // Touch targets ≥ 48 dp.
    for (final tip in ['الآية السابقة', 'إيقاف مؤقت', 'الآية التالية', 'إيقاف وإغلاق']) {
      final size = tester.getSize(find.byTooltip(tip));
      expect(size.width, greaterThanOrEqualTo(48), reason: tip);
      expect(size.height, greaterThanOrEqualTo(48), reason: tip);
    }

    await tester.tap(find.byTooltip('إيقاف وإغلاق'));
    await settle(tester);
    expect(recitation.session, isNull);
    expect(find.byIcon(MathaniIcons.close), findsNothing);
    expect(tester.getSize(find.byType(PageView)).height, pageHeight);
    await finish(tester);
  });

  testWidgets('the item text names the surah and ayah, and the basmala', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(() => recitation.playFrom(const AyahRef(67, 12)));
    await settle(tester);
    expect(find.text('سورة الملك · ١٢'), findsOneWidget);
    await tester.runAsync(() => recitation.playFrom(const AyahRef(67, 1)));
    await settle(tester);
    expect(find.text('سورة الملك · البسملة'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('English names the ayah with surah:ayah', (tester) async {
    await pumpApp(tester, language: LanguagePref.en);
    await tester.runAsync(() => recitation.playFrom(const AyahRef(67, 12)));
    await settle(tester);
    expect(find.text('Al-Mulk · 67:12'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a swipe shows "Back to recitation"; tapping it returns and follows again',
      (tester) async {
    await pumpApp(tester);
    await tester.runAsync(() => recitation.playFrom(const AyahRef(67, 1)));
    await settle(tester);
    final recitedPage = reader.page;
    expect(find.text('العودة إلى التلاوة'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await settle(tester);
    expect(reader.page, isNot(recitedPage));
    expect(recitation.session!.following, isFalse);
    expect(find.text('العودة إلى التلاوة'), findsOneWidget);

    await tester.tap(find.text('العودة إلى التلاوة'));
    await settle(tester);
    expect(reader.page, recitedPage);
    expect(recitation.session!.following, isTrue);
    expect(find.text('العودة إلى التلاوة'), findsNothing);
    await finish(tester);
  });

  testWidgets('offline: the error row with Retry, and the ayah is not skipped', (tester) async {
    await pumpApp(tester);
    fetcher.failing[const RecitedItem.ayah(67, 5)] = FetchError.offline;
    await tester.runAsync(() => recitation.playFrom(const AyahRef(67, 5)));
    await settle(tester);
    expect(find.text('لا يوجد اتصال. نزّل السورة للاستماع دون إنترنت.'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(recitation.session!.item, const RecitedItem.ayah(67, 5));

    fetcher.failing.clear();
    await tester.tap(find.text('إعادة المحاولة'));
    await settle(tester);
    expect(recitation.session!.status, RecitationStatus.playing);
    expect(find.text('إعادة المحاولة'), findsNothing);
    await finish(tester);
  });

  testWidgets('a follow page turn keeps the controls; a swipe still hides them', (tester) async {
    await pumpApp(tester);
    final lastOn50 = reader.quran.ayahsStartingOnPage(50).last.ref;
    reader.jumpTo(lastOn50);
    await settle(tester);
    // Controls are shown after a tap.
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await settle(tester, 2);
    bool controlsShown() => find.byIcon(MathaniIcons.index).hitTestable().evaluate().isNotEmpty;
    if (!controlsShown()) {
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await settle(tester, 2);
    }
    expect(controlsShown(), isTrue);

    await tester.runAsync(() => recitation.playFrom(lastOn50));
    await settle(tester);
    engine.finishCurrent(); // the next ayah starts on page 51: a follow page turn
    await settle(tester);
    expect(reader.page, 51);
    expect(controlsShown(), isTrue, reason: 'following does not hide the controls');

    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await settle(tester);
    expect(controlsShown(), isFalse, reason: 'a swipe still hides them (spec 002)');
    await finish(tester);
  });
}
