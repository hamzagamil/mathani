// specs/010: the onboarding explains the coloured ayat, in a first run and once to readers who
// finished the onboarding before the coloured ayat existed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/mutashabihat/mutashabihat_content.dart';
import 'package:mathani/features/onboarding/onboarding_controller.dart';
import 'package:mathani/features/onboarding/onboarding_steps.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  final content = parseMutashabihat('## 2:35 7:19\nشرح').$1;

  test('the stop follows the ayah actions, only with content', () {
    List<OnboardingStep> steps({required bool hasSimilar, bool replay = false}) => onboardingSteps(
        hasReciters: true, hasPlayer: true, hasSimilar: hasSimilar, replay: replay);
    final withIt = steps(hasSimilar: true);
    expect(withIt.indexOf(OnboardingStep.similarAyat),
        withIt.indexOf(OnboardingStep.ayahActions) + 1);
    expect(OnboardingStep.similarAyat.kind, StepKind.gesture);
    expect(steps(hasSimilar: true, replay: true), contains(OnboardingStep.similarAyat));
    expect(steps(hasSimilar: false), isNot(contains(OnboardingStep.similarAyat)));
  });

  Future<ReaderController> open(WidgetTester tester,
      {required bool onboarded, Mutashabihat? similar}) async {
    final reader = (await tester.runAsync(
        () => openTestReader(onboarded: onboarded, similar: similar ?? content)))!;
    addTearDown(() async {
      await tester.runAsync(() async {
        reader.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
    });
    return reader;
  }

  testWidgets('a first run includes the stop and marks it seen', (tester) async {
    final reader = await open(tester, onboarded: false);
    final c = OnboardingController(reader: reader);
    expect(c.steps, contains(OnboardingStep.similarAyat));
    c.skip();
    expect(reader.preferences.onboardingDone, isTrue);
    expect(reader.preferences.similarIntroSeen, isTrue);
    c.dispose();
  });

  testWidgets('a reader who finished the onboarding sees only this stop, once', (tester) async {
    final reader = await open(tester, onboarded: true);
    expect(reader.preferences.similarIntroSeen, isFalse);
    final c = OnboardingController(reader: reader);
    expect(c.step, OnboardingStep.similarAyat);
    expect(c.steps, const [OnboardingStep.similarAyat]);
    expect(c.phase, OnboardingPhase.gestures);
    expect(c.progress, (1, 1));
    c.next(); // the only stop: Done
    expect(c.step, isNull);
    expect(reader.preferences.similarIntroSeen, isTrue);
    expect(reader.preferences.onboardingDone, isTrue);
    c.dispose();

    // Saved: the next launch shows nothing.
    final (_, saved) = (await tester.runAsync(() => reader.user.loadStartup()))!;
    expect(saved.similarIntroSeen, isTrue);
    final again = OnboardingController(
        reader: ReaderController(
            quran: reader.quran, user: reader.user, anchor: reader.anchor, preferences: saved,
            similar: content));
    expect(again.step, isNull);
    again.dispose();

    // A replay from Settings is the whole tour, the stop included.
    final replay = OnboardingController(reader: reader)..startReplay();
    expect(replay.steps.first, OnboardingStep.turnPages);
    expect(replay.steps, contains(OnboardingStep.similarAyat));
    replay.dispose();
  });

  testWidgets('without content there is nothing to explain', (tester) async {
    final reader = await open(tester, onboarded: true, similar: Mutashabihat.empty);
    final c = OnboardingController(reader: reader);
    expect(c.step, isNull);
    c.startReplay();
    expect(c.steps, isNot(contains(OnboardingStep.similarAyat)));
    c.dispose();
  });

  testWidgets('the stop on screen: title, text and Done', (tester) async {
    await tester.runAsync(loadAppFonts);
    final reader = await open(tester, onboarded: true);
    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar));
    final onboarding = OnboardingController(reader: reader);
    tester.view.physicalSize = const Size(780, 1690);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MathaniApp(controller: reader, onboarding: onboarding));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('المتشابه'), findsOneWidget);
    expect(find.textContaining('باللون الأخضر'), findsOneWidget);
    await tester.tap(find.text('تم'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('المتشابه'), findsNothing);
    expect(reader.preferences.similarIntroSeen, isTrue);
    await tester.pumpWidget(const SizedBox());
    onboarding.dispose();
    await tester.runAsync(() async {
      reader.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(seconds: 3));
  });
}
