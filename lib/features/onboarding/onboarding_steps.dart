// The order of the onboarding (specs/005-app-onboarding/data-model.md › Step sequence). Pure Dart:
// no Flutter imports, so it is unit tested without a device.

/// One screen of the onboarding: a preference to set, a gesture to show, or a button to point at.
enum OnboardingStep {
  language,
  theme,
  layout,
  textSize,
  reciter,
  turnPages,
  controls,
  ayahActions,
  surahIndex,
  search,
  player,
  memorize,
  settings;

  StepKind get kind => switch (this) {
        language || theme || layout || textSize || reciter => StepKind.setup,
        turnPages || controls || ayahActions => StepKind.gesture,
        surahIndex || search || player || memorize || settings => StepKind.button,
      };
}

/// Setup steps set preferences; gesture stops are illustrated screens; button stops are hints over
/// the real reading screen (FR-017).
enum StepKind { setup, gesture, button }

/// The steps to show, in order. Text size only for the flowing layout, the reciter only with a
/// catalogue, the player hint only with recitations, the memorization hint only with it
/// (specs/006 T049), and no setup steps in a replay (FR-006, FR-014, FR-022).
List<OnboardingStep> onboardingSteps({
  required bool flowing,
  required bool hasReciters,
  required bool hasPlayer,
  bool hasMemorize = false,
  required bool replay,
}) =>
    [
      if (!replay) ...[
        OnboardingStep.language,
        OnboardingStep.theme,
        OnboardingStep.layout,
        if (flowing) OnboardingStep.textSize,
        if (hasReciters) OnboardingStep.reciter,
      ],
      OnboardingStep.turnPages,
      OnboardingStep.controls,
      OnboardingStep.ayahActions,
      OnboardingStep.surahIndex,
      OnboardingStep.search,
      if (hasPlayer) OnboardingStep.player,
      if (hasMemorize) OnboardingStep.memorize,
      OnboardingStep.settings,
    ];

/// The 1-based position of [step] and the total, counted within its group: the setup steps, or
/// the tour stops (gesture and button together) (FR-015).
(int index, int total) progressOf(List<OnboardingStep> steps, OnboardingStep step) {
  final setup = step.kind == StepKind.setup;
  final group = [for (final s in steps) if ((s.kind == StepKind.setup) == setup) s];
  return (group.indexOf(step) + 1, group.length);
}
