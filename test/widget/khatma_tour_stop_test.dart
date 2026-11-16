// The tour has one stop on the Khatma button, in the first run and in the replay (specs/014
// FR-043, research R12).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/features/onboarding/onboarding_controller.dart';
import 'package:mathani/features/onboarding/onboarding_steps.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';
import '../support/khatma_support.dart';

void main() {
  test('the stop comes after memorization and before Settings, in both tours', () {
    for (final replay in [false, true]) {
      final steps = onboardingSteps(
          hasReciters: true, hasPlayer: true, hasMemorize: true, hasKhatma: true, replay: replay);
      final at = steps.indexOf(OnboardingStep.khatma);
      expect(at, steps.indexOf(OnboardingStep.memorize) + 1);
      expect(steps[at + 1], OnboardingStep.settings);
      expect(OnboardingStep.khatma.kind, StepKind.button);
    }
    expect(onboardingSteps(hasReciters: false, hasPlayer: false, replay: true),
        isNot(contains(OnboardingStep.khatma)));
  });

  testWidgets('the hint points at the Khatma button', (tester) async {
    late ReaderController reader;
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader(onboarded: false);
    });
    final KhatmaController khatma = await openTestKhatma(tester, reader);
    final onboarding = OnboardingController(reader: reader, hasKhatma: true);
    setPhone(tester);
    const device = MethodChannel('app.mathani/device');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        device, (call) async => call.method == 'networkState' ? 'unmetered' : null);
    addTearDown(() => messenger.setMockMethodCallHandler(device, null));
    await tester.pumpWidget(MathaniApp(controller: reader, onboarding: onboarding, khatma: khatma));
    await settleKhatma(tester);
    for (var i = 0; i < 30 && onboarding.step != OnboardingStep.khatma; i++) {
      onboarding.next();
      await settleKhatma(tester, 1);
    }
    expect(onboarding.step, OnboardingStep.khatma);
    await settleKhatma(tester, 2);
    expect(find.text("Plan a khatma, read each day's wird, and keep your place."), findsOneWidget);
    expect(onboarding.step, OnboardingStep.khatma, reason: 'the button was found');
    await tester.pumpWidget(const SizedBox());
    khatma.dispose();
    await tester.pump(const Duration(seconds: 2));
  });
}
