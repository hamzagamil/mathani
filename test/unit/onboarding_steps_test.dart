import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/onboarding/onboarding_steps.dart';

/// The step sequence (specs/005-app-onboarding/data-model.md › Step sequence).
void main() {
  List<OnboardingStep> steps({
    bool flowing = false,
    bool hasReciters = true,
    bool hasPlayer = true,
    bool replay = false,
  }) =>
      onboardingSteps(
          flowing: flowing, hasReciters: hasReciters, hasPlayer: hasPlayer, replay: replay);

  test('Mushaf layout with recitations: setup, gestures, buttons', () {
    expect(steps(), const [
      OnboardingStep.language,
      OnboardingStep.theme,
      OnboardingStep.layout,
      OnboardingStep.reciter,
      OnboardingStep.turnPages,
      OnboardingStep.controls,
      OnboardingStep.ayahActions,
      OnboardingStep.surahIndex,
      OnboardingStep.search,
      OnboardingStep.player,
      OnboardingStep.settings,
    ]);
  });

  test('the flowing layout adds text size right after the layout', () {
    final s = steps(flowing: true);
    expect(s.indexOf(OnboardingStep.textSize), s.indexOf(OnboardingStep.layout) + 1);
    expect(steps().contains(OnboardingStep.textSize), isFalse);
  });

  test('no catalogue drops the reciter; no recitations drops the player', () {
    expect(steps(hasReciters: false).contains(OnboardingStep.reciter), isFalse);
    expect(steps(hasPlayer: false).contains(OnboardingStep.player), isFalse);
  });

  test('a replay is the tour only, starting at turning pages', () {
    final s = steps(replay: true);
    expect(s.first, OnboardingStep.turnPages);
    expect(s.where((x) => x.kind == StepKind.setup), isEmpty);
  });

  test('progress counts setup steps and tour stops separately', () {
    final mushaf = steps();
    expect(progressOf(mushaf, OnboardingStep.language), (1, 4));
    expect(progressOf(mushaf, OnboardingStep.reciter), (4, 4));
    expect(progressOf(steps(flowing: true), OnboardingStep.textSize), (4, 5));
    expect(progressOf(mushaf, OnboardingStep.turnPages), (1, 7));
    expect(progressOf(mushaf, OnboardingStep.ayahActions), (3, 7));
    expect(progressOf(mushaf, OnboardingStep.surahIndex), (4, 7));
    expect(progressOf(mushaf, OnboardingStep.settings), (7, 7));
    expect(progressOf(steps(replay: true), OnboardingStep.turnPages), (1, 7));
  });

  test('kinds', () {
    expect(OnboardingStep.textSize.kind, StepKind.setup);
    expect(OnboardingStep.controls.kind, StepKind.gesture);
    expect(OnboardingStep.player.kind, StepKind.button);
  });
}
