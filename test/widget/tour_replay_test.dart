// Settings › See the tour again (specs/005-app-onboarding, User Story 4; FR-021, FR-022).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/onboarding/button_tour.dart';
import 'package:mathani/features/onboarding/onboarding_controller.dart';
import 'package:mathani/features/onboarding/onboarding_screen.dart';
import 'package:mathani/features/onboarding/onboarding_steps.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/features/settings/settings_screen.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

void main() {
  late ReaderController reader;
  late RecitationController recitation;
  late OnboardingController onboarding;

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// An onboarded reader on page 200, with Settings open.
  Future<void> pumpInSettings(WidgetTester tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar));
    (recitation, _, _) = openTestRecitation(reader);
    onboarding = OnboardingController(reader: reader, recitation: recitation);
    tester.view.physicalSize = const Size(780, 1690);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
        MathaniApp(controller: reader, recitation: recitation, onboarding: onboarding));
    await settle(tester);
    reader.jumpTo(reader.quran.firstAyahOnPage(200).ref, highlight: false);
    await settle(tester);
    expect(reader.page, 200);
    await tapToolbar(tester, MathaniIcons.settings);
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  Future<void> finish(WidgetTester tester) async {
    await recitation.stop();
    await tester.pumpWidget(const SizedBox());
    onboarding.dispose();
    recitation.dispose();
    await tester.runAsync(() async {
      reader.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> openTour(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('شاهد الجولة التعريفية مرة أخرى'), 200);
    await tester.tap(find.text('شاهد الجولة التعريفية مرة أخرى'));
    await settle(tester);
  }

  testWidgets('the tour only, then the hints at the same page; Done leaves everything as it was',
      (tester) async {
    await pumpInSettings(tester);
    final before = reader.preferences;
    final bookmarks = reader.user.bookmarks.length;
    await openTour(tester);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(onboarding.step, OnboardingStep.turnPages);
    expect(find.text('١ من ٧'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('التالي'));
      await settle(tester);
    }
    expect(find.byType(ButtonTour), findsOneWidget);
    expect(reader.page, 200);
    while (onboarding.step != null) {
      onboarding.next();
    }
    await settle(tester);
    expect(find.byType(ButtonTour), findsNothing);
    expect(reader.page, 200);
    expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page!.round() + 1, 200);
    expect(reader.preferences.onboardingDone, isTrue);
    expect(reader.preferences.theme, before.theme);
    expect(reader.preferences.layout, before.layout);
    expect(reader.preferences.reciter, before.reciter);
    expect(reader.user.bookmarks.length, bookmarks);
    await finish(tester);
  });

  testWidgets('Skip on the first stop ends on the same page', (tester) async {
    await pumpInSettings(tester);
    await openTour(tester);
    await tester.tap(find.text('تخطَّ'));
    await settle(tester);
    expect(onboarding.step, isNull);
    expect(reader.page, 200);
    await finish(tester);
  });

  testWidgets('system back on the first stop ends the replay', (tester) async {
    await pumpInSettings(tester);
    await openTour(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(onboarding.step, isNull);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(reader.page, 200);
    await finish(tester);
  });

  testWidgets('a recitation keeps playing through the tour', (tester) async {
    await pumpInSettings(tester);
    await recitation.playFrom(const AyahRef(67, 1));
    await settle(tester);
    final item = recitation.session!.item;
    final status = recitation.session!.status;
    await openTour(tester);
    while (onboarding.step != null) {
      onboarding.next();
      await settle(tester, 2);
    }
    expect(recitation.session?.item, item);
    expect(recitation.session?.status, status);
    await finish(tester);
  });
}
