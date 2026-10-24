// Hints over the real reading screen (specs/005-app-onboarding/contracts/onboarding-ui.md ›
// ButtonTour; FR-017, FR-017a, FR-018).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/index/index_screen.dart';
import 'package:mathani/features/onboarding/button_tour.dart';
import 'package:mathani/features/onboarding/onboarding_controller.dart';
import 'package:mathani/features/onboarding/onboarding_screen.dart';
import 'package:mathani/features/onboarding/onboarding_steps.dart';
import 'package:mathani/features/recitation/recitation_bar.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
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

  /// A first run, walked to the first button hint.
  Future<void> pumpAtHints(WidgetTester tester,
      {ReadingLayout layout = ReadingLayout.mushaf}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader(onboarded: false);
    });
    reader.updatePreferences(
        reader.preferences.copyWith(language: LanguagePref.ar, layout: layout));
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
    while (onboarding.phase != OnboardingPhase.buttons) {
      onboarding.next();
    }
    await settle(tester);
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

  /// The hole the scrim leaves around the current control.
  Rect? hole(WidgetTester tester) {
    final paint = tester.widgetList<CustomPaint>(find.descendant(
        of: find.byType(ButtonTour), matching: find.byType(CustomPaint)));
    for (final p in paint) {
      final painter = p.painter;
      if (painter != null && painter.runtimeType.toString() == '_ScrimPainter') {
        return (painter as dynamic).hole as Rect?;
      }
    }
    return null;
  }

  int visiblePage(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!.page!.round() + 1;

  testWidgets('each hint leaves a hole around the real control', (tester) async {
    await pumpAtHints(tester);
    expect(onboarding.step, OnboardingStep.surahIndex);
    for (final (step, tooltip) in [
      (OnboardingStep.surahIndex, 'افتح الفهرس'),
      (OnboardingStep.search, 'ابحث في القرآن الكريم'),
      (OnboardingStep.player, 'استمع'),
      (OnboardingStep.settings, 'افتح الإعدادات'),
    ]) {
      expect(onboarding.step, step);
      final control = tester.getRect(find.byTooltip(tooltip));
      expect(hole(tester), control.inflate(holeInflate), reason: step.name);
      expect(find.textContaining('من ٧'), findsOneWidget);
      if (step != OnboardingStep.settings) {
        await tester.tap(find.text('التالي'));
        await settle(tester, 3);
      }
    }
    await finish(tester);
  });

  testWidgets('taps are absorbed: the control does not open and the page does not turn',
      (tester) async {
    await pumpAtHints(tester);
    await tester.tapAt(tester.getCenter(find.byTooltip('افتح الفهرس')));
    await settle(tester, 3);
    expect(find.byType(IndexScreen), findsNothing);
    expect(onboarding.step, OnboardingStep.surahIndex);
    await tester.dragFrom(const Offset(195, 400), const Offset(300, 0));
    await settle(tester, 3);
    expect(reader.page, 1);
    expect(visiblePage(tester), 1);
    await finish(tester);
  });

  testWidgets('the controls stay shown in the Mushaf layout while hints show', (tester) async {
    await pumpAtHints(tester);
    final slide = tester.widget<AnimatedSlide>(find
        .ancestor(of: find.byTooltip('افتح الفهرس'), matching: find.byType(AnimatedSlide))
        .first);
    expect(slide.offset, Offset.zero);
    await finish(tester);
  });

  testWidgets('a jump during the hints waits until they end', (tester) async {
    await pumpAtHints(tester);
    reader.jumpTo(const AyahRef(2, 255), highlight: false);
    await settle(tester);
    expect(visiblePage(tester), 1, reason: 'held');
    while (onboarding.step != null) {
      onboarding.next();
    }
    await settle(tester);
    expect(visiblePage(tester), 42);
    expect(find.byType(ButtonTour), findsNothing);
    await finish(tester);
  });

  testWidgets('during a recitation, the player hint points at the recitation bar',
      (tester) async {
    await pumpAtHints(tester);
    await recitation.playFrom(const AyahRef(67, 1));
    await settle(tester);
    onboarding.next();
    onboarding.next();
    await settle(tester);
    expect(onboarding.step, OnboardingStep.player);
    expect(hole(tester), tester.getRect(find.byType(RecitationBar)).inflate(holeInflate));
    await finish(tester);
  });

  testWidgets('Done ends the tour on the reader, remembered, with no hint afterwards',
      (tester) async {
    await pumpAtHints(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('التالي'));
      await settle(tester, 3);
    }
    expect(onboarding.step, OnboardingStep.settings);
    await tester.tap(find.text('تم'));
    await settle(tester);
    expect(onboarding.step, isNull);
    expect(reader.preferences.onboardingDone, isTrue);
    expect(find.byType(ButtonTour), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await settle(tester);
    expect(reader.page, 2);
    expect(find.byType(SnackBar), findsNothing, reason: 'the old controls hint is gone (FR-018)');
    await finish(tester);
  });

  testWidgets('back on the first hint returns to the last gesture stop', (tester) async {
    await pumpAtHints(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(onboarding.step, OnboardingStep.ayahActions);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the flowing layout gets the same hints', (tester) async {
    await pumpAtHints(tester, layout: ReadingLayout.flowing);
    expect(hole(tester), tester.getRect(find.byTooltip('افتح الفهرس')).inflate(holeInflate));
    await finish(tester);
  });
}
