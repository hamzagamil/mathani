// The order of the onboarding (specs/005-app-onboarding/data-model.md › Step sequence). Pure Dart:
// no Flutter imports, so it is unit tested without a device.

/// One screen of the onboarding: a preference to set, a gesture to show, or a button to point at.
enum OnboardingStep {
  language,
  theme,
  reciter,
  turnPages,
  controls,
  ayahActions,
  similarAyat,
  surahIndex,
  search,
  player,
  memorize,
  settings;

  StepKind get kind => switch (this) {
        language || theme || reciter => StepKind.setup,
        turnPages || controls || ayahActions || similarAyat => StepKind.gesture,
        surahIndex || search || player || memorize || settings => StepKind.button,
      };
}

/// Setup steps set preferences; gesture stops are illustrated screens; button stops are hints over
/// the real reading screen (FR-017).
enum StepKind { setup, gesture, button }

/// The steps to show, in order. The reciter only with a catalogue, the player hint only with
/// recitations, the memorization hint only with it (specs/006 T049), the coloured ayat only with
/// Mutashabihat content (specs/010), and no setup steps in a replay (FR-006, FR-014, FR-022). The
/// reading layout and the flowing text size are chosen in Settings only.
List<OnboardingStep> onboardingSteps({
  required bool hasReciters,
  required bool hasPlayer,
  bool hasMemorize = false,
  bool hasSimilar = false,
  required bool replay,
}) =>
    [
      if (!replay) ...[
        OnboardingStep.language,
        OnboardingStep.theme,
        if (hasReciters) OnboardingStep.reciter,
      ],
      OnboardingStep.turnPages,
      OnboardingStep.controls,
      OnboardingStep.ayahActions,
      if (hasSimilar) OnboardingStep.similarAyat,
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
