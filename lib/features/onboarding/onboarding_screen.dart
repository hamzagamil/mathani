// The onboarding's preference steps and gesture stops (specs/005-app-onboarding/contracts/
// onboarding-ui.md › OnboardingScreen). The button hints are laid over the reader: button_tour.dart.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import 'onboarding_controller.dart';
import 'onboarding_steps.dart';
import 'setup_steps.dart';
import 'tour_illustration.dart';

/// Moving from one step to the next.
const stepTransition = Duration(milliseconds: 250);

/// The progress line of [onboarding]'s step: «الخطوة ٢ من ٤» for setup, «٢ من ٧» for the tour.
String progressText(OnboardingController onboarding, AppLocalizations l10n, Locale locale) {
  final (index, total) = onboarding.progress;
  final i = formatNumber(index, locale);
  final n = formatNumber(total, locale);
  return onboarding.step?.kind == StepKind.setup
      ? l10n.onboardingStep(i, n)
      : l10n.tourProgress(i, n);
}

/// Skip, Back and Next, as on every onboarding screen and hint (FR-019). Skip comes first, so
/// it is first in traversal order; when the three don't fit on one row, Skip takes its own.
class OnboardingButtons extends StatelessWidget {
  const OnboardingButtons({super.key, required this.onboarding});

  final OnboardingController onboarding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final first = onboarding.step == onboarding.steps.first;
    final last = onboarding.step == onboarding.steps.last;
    const minimum = Size(48, 48);
    // Full width, so Skip sits at the start and Back/Next at the end.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: Space.s2,
        children: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: minimum, foregroundColor: colors.accentInk),
            onPressed: onboarding.skip,
            child: Text(l10n.onboardingSkip),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!first) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: minimum,
                    foregroundColor: colors.ink,
                    side: BorderSide(color: colors.line),
                  ),
                  onPressed: onboarding.back,
                  icon: const Icon(MathaniIcons.back, size: 18),
                  label: Text(l10n.onboardingBack),
                ),
                const SizedBox(width: Space.s2),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: minimum,
                  backgroundColor: colors.accent,
                  foregroundColor: colors.onAccent,
                ),
                onPressed: onboarding.next,
                icon: Icon(last ? MathaniIcons.check : MathaniIcons.forward, size: 18),
                iconAlignment: IconAlignment.end,
                label: Text(last ? l10n.tourDone : l10n.onboardingNext),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the reader while the onboarding is on a setup step or a gesture stop.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PageController? _pages;
  OnboardingStep? _shown;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  /// The steps this screen pages through: all but the button hints.
  static List<OnboardingStep> _ownSteps(OnboardingController o) =>
      [for (final s in o.steps) if (s.kind != StepKind.button) s];

  void _follow(OnboardingController onboarding, List<OnboardingStep> steps) {
    final step = onboarding.step;
    if (step == null || step == _shown || !steps.contains(step)) return;
    final first = _shown == null;
    _shown = step;
    final target = steps.indexOf(step);
    if (first) return; // the controller was created on this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pages = _pages;
      if (!mounted || pages == null || !pages.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        pages.jumpToPage(target);
      } else {
        pages.animateToPage(target, duration: stepTransition, curve: Curves.easeOut);
      }
      // Screen readers hear the new step's title (FR-024).
      final l10n = AppLocalizations.of(context);
      SemanticsService.sendAnnouncement(
          View.of(context), _title(step, l10n), Directionality.of(context));
    });
  }

  static String _title(OnboardingStep step, AppLocalizations l10n) => switch (step) {
        OnboardingStep.language => l10n.onboardingLanguageTitle,
        OnboardingStep.theme => l10n.onboardingThemeTitle,
        OnboardingStep.layout => l10n.onboardingLayoutTitle,
        OnboardingStep.textSize => l10n.onboardingTextSizeTitle,
        OnboardingStep.reciter => l10n.onboardingReciterTitle,
        OnboardingStep.turnPages => l10n.tourTurnPagesTitle,
        OnboardingStep.controls => l10n.tourControlsTitle,
        OnboardingStep.ayahActions => l10n.tourAyahTitle,
        OnboardingStep.surahIndex => l10n.tourIndexTitle,
        OnboardingStep.search => l10n.tourSearchTitle,
        OnboardingStep.player => l10n.tourPlayerTitle,
        OnboardingStep.settings => l10n.tourSettingsTitle,
      };

  @override
  Widget build(BuildContext context) {
    final onboarding = OnboardingScope.of(context);
    final colors = MathaniColors.of(context);
    final steps = _ownSteps(onboarding);
    _follow(onboarding, steps);
    final current = _shown;
    // Between the last gesture stop and the reader, nothing to show for a frame.
    if (current == null) return Scaffold(backgroundColor: colors.surface);
    final pages = _pages ??= PageController(initialPage: steps.indexOf(current));
    final atFirst = current == onboarding.steps.first;

    return PopScope(
      // The first step of a first run leaves the app, as back does on the app's first screen
      // (FR-025); elsewhere back is the previous step.
      canPop: atFirst && !onboarding.replay,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onboarding.back();
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: pages,
                  // Steps change only with the buttons or back, never with a swipe meant for the
                  // illustration.
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: steps.length,
                  itemBuilder: (context, i) => _StepPage(
                    key: ValueKey(steps[i]),
                    step: steps[i],
                    title: _title(steps[i], AppLocalizations.of(context)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s4, Space.s3),
                child: OnboardingButtons(onboarding: onboarding),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One step: the progress, the title, then the step's choices or gesture illustration. Long
/// content scrolls inside; the buttons below stay put.
class _StepPage extends StatelessWidget {
  const _StepPage({super.key, required this.step, required this.title});

  final OnboardingStep step;
  final String title;

  @override
  Widget build(BuildContext context) {
    final onboarding = OnboardingScope.of(context);
    final reader = ReaderScope.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    final mushaf = reader.layout == ReadingLayout.mushaf;
    final (index, total) = progressOf(onboarding.steps, step);
    final i = formatNumber(index, locale);
    final n = formatNumber(total, locale);

    final body = switch (step) {
      OnboardingStep.language => const LanguageStep(),
      OnboardingStep.theme => const ThemeStep(),
      OnboardingStep.layout => const LayoutStep(),
      OnboardingStep.textSize => const TextSizeStep(),
      OnboardingStep.reciter => const ReciterStep(),
      _ => _GestureStop(
          step: step,
          text: switch (step) {
            OnboardingStep.turnPages =>
              mushaf ? l10n.tourTurnPagesMushaf : l10n.tourTurnPagesFlowing,
            OnboardingStep.controls => mushaf ? l10n.tourControlsMushaf : l10n.tourControlsFlowing,
            _ => l10n.tourAyahBody,
          },
          layout: reader.layout,
        ),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.s4, Space.s6, Space.s4, Space.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (step == OnboardingStep.language) ...[
            const OnboardingWelcome(),
            const SizedBox(height: Space.s4),
          ],
          Text(
            step.kind == StepKind.setup ? l10n.onboardingStep(i, n) : l10n.tourProgress(i, n),
            style: TypeScale.caption.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: Space.s1),
          Semantics(
            header: true,
            child: Text(title, style: TypeScale.titleLg.copyWith(color: colors.ink)),
          ),
          const SizedBox(height: Space.s4),
          body,
        ],
      ),
    );
  }
}

class _GestureStop extends StatelessWidget {
  const _GestureStop({required this.step, required this.text, required this.layout});

  final OnboardingStep step;
  final String text;
  final ReadingLayout layout;

  @override
  Widget build(BuildContext context) {
    final colors = MathaniColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text, style: TypeScale.body.copyWith(color: colors.ink)),
        const SizedBox(height: Space.s6),
        TourIllustration(layout: layout, gesture: step),
      ],
    );
  }
}
