import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/onboarding/onboarding_controller.dart';
import 'package:mathani/features/onboarding/onboarding_steps.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

/// OnboardingController (specs/005-app-onboarding/contracts/onboarding-flow.md).
void main() {
  late ReaderController reader;
  late RecitationController recitation;
  late FakeAudioEngine engine;
  late OnboardingController c;

  /// Lets unawaited database writes finish (they need real async).
  Future<void> flush(WidgetTester tester) =>
      tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));

  void onboardingTest(String name, Future<void> Function(WidgetTester tester) body,
      {bool onboarded = false, Object? skip}) {
    testWidgets(name, skip: skip != null, (tester) async {
      reader = (await tester.runAsync(() => openTestReader(onboarded: onboarded)))!;
      (recitation, engine, _) = openTestRecitation(reader);
      c = OnboardingController(reader: reader, recitation: recitation, hasMemorize: true);
      await body(tester);
      c.dispose();
      await recitation.stop();
      recitation.dispose();
      await tester.runAsync(() async {
        reader.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(seconds: 2));
    });
  }

  void walkTo(OnboardingStep step) {
    if (step == OnboardingStep.textSize) {
      reader.updatePreferences(reader.preferences.copyWith(layout: ReadingLayout.flowing));
    }
    expect(c.steps, contains(step));
    while (c.step != step) {
      c.next();
    }
  }

  onboardingTest('a first run starts at the language step', (tester) async {
    expect(c.step, OnboardingStep.language);
    expect(c.phase, OnboardingPhase.setup);
    expect(c.progress, (1, 4));
  });

  onboardingTest('once done, the onboarding does not start', (tester) async {
    expect(c.step, isNull);
    expect(c.phase, OnboardingPhase.none);
  }, onboarded: true);

  onboardingTest('next and back walk the steps; back on the first step is left to the system',
      (tester) async {
    c.back();
    expect(c.step, OnboardingStep.language);
    c.next();
    expect(c.step, OnboardingStep.theme);
    c.next();
    c.next();
    expect(c.step, OnboardingStep.reciter);
    c.next();
    expect(c.step, OnboardingStep.turnPages);
    expect(c.phase, OnboardingPhase.gestures);
    expect(c.progress, (1, 8)); // 3 gestures and 5 buttons, Memorize among them (specs/006)
    c.back();
    expect(c.step, OnboardingStep.reciter);
  });

  for (final step in OnboardingStep.values) {
    onboardingTest('skip from ${step.name} ends it and remembers it', (tester) async {
      walkTo(step);
      c.skip();
      expect(c.step, isNull);
      expect(reader.preferences.onboardingDone, isTrue);
      await flush(tester);
      final (_, saved) = (await tester.runAsync(reader.user.loadStartup))!;
      expect(saved.onboardingDone, isTrue);
    });
  }

  onboardingTest('done on the last stop ends it and remembers it', (tester) async {
    walkTo(OnboardingStep.settings);
    expect(c.holdsReader, isTrue);
    c.next();
    expect(c.step, isNull);
    expect(c.holdsReader, isFalse);
    expect(reader.preferences.onboardingDone, isTrue);
  });

  onboardingTest('choices made before skipping are kept', (tester) async {
    reader.updatePreferences(reader.preferences.copyWith(theme: ThemePref.night));
    c.next();
    c.skip();
    expect(reader.preferences.theme, ThemePref.night);
    expect(reader.preferences.onboardingDone, isTrue);
  });

  onboardingTest('closed midway: the next launch starts again at the language step, with the '
      'choices kept (FR-003)', (tester) async {
    reader.updatePreferences(reader.preferences.copyWith(theme: ThemePref.night));
    walkTo(OnboardingStep.layout);
    await flush(tester);
    final (anchor, saved) = (await tester.runAsync(reader.user.loadStartup))!;
    final relaunched = ReaderController(
        quran: reader.quran, user: reader.user, anchor: anchor, preferences: saved);
    final again = OnboardingController(reader: relaunched);
    expect(again.step, OnboardingStep.language);
    expect(relaunched.preferences.theme, ThemePref.night);
    again.dispose();
    relaunched.dispose();
  });

  onboardingTest('the layout step adds text size after it for flowing, and removes it for Mushaf',
      (tester) async {
    walkTo(OnboardingStep.layout);
    reader.updatePreferences(reader.preferences.copyWith(layout: ReadingLayout.flowing));
    expect(c.step, OnboardingStep.layout);
    expect(c.progress, (3, 5));
    c.next();
    expect(c.step, OnboardingStep.textSize);
    c.back();
    reader.updatePreferences(reader.preferences.copyWith(layout: ReadingLayout.mushaf));
    expect(c.step, OnboardingStep.layout);
    c.next();
    expect(c.step, OnboardingStep.reciter);
  });

  onboardingTest('a replay is the tour only and never touches onboardingDone', (tester) async {
    c.startReplay();
    expect(c.replay, isTrue);
    expect(c.step, OnboardingStep.turnPages);
    expect(c.steps.where((s) => s.kind == StepKind.setup), isEmpty);
    walkTo(OnboardingStep.settings);
    c.done();
    expect(c.step, isNull);
    expect(c.replay, isFalse);
    expect(reader.preferences.onboardingDone, isTrue);
  }, onboarded: true);

  onboardingTest('back on the first replay stop ends the replay', (tester) async {
    c.startReplay();
    c.back();
    expect(c.step, isNull);
  }, onboarded: true);

  onboardingTest('a replay does not start while onboarding', (tester) async {
    c.startReplay();
    expect(c.replay, isFalse);
    expect(c.step, OnboardingStep.language);
  });

  onboardingTest('only button stops hold the reader', (tester) async {
    for (final step in List.of(c.steps)) {
      walkTo(step);
      expect(c.holdsReader, step.kind == StepKind.button, reason: step.name);
    }
  });

  for (final leave in ['next', 'back', 'skip', 'done']) {
    onboardingTest('leaving the reciter step by $leave stops the sample', (tester) async {
      walkTo(OnboardingStep.reciter);
      await recitation.previewReciter(reader.quran.reciters.first);
      expect(recitation.preview, isNotNull);
      switch (leave) {
        case 'next':
          c.next();
        case 'back':
          c.back();
        case 'skip':
          c.skip();
        case 'done':
          c.done();
      }
      await tester.pump();
      expect(recitation.preview, isNull);
      expect(engine.playing, isFalse);
    });
  }
}
