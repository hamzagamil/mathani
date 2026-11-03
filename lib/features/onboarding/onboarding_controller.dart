// Where the reader is in the onboarding (specs/005-app-onboarding/contracts/onboarding-flow.md).
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../shared/reader_state.dart';
import '../recitation/recitation_controller.dart';
import 'onboarding_steps.dart';

enum OnboardingPhase { none, setup, gestures, buttons }

/// The step on screen, from the step list (data-model › Step sequence). Preferences are set by the
/// steps themselves, through the same calls as Settings; this controller writes only
/// `onboardingDone`, and only when a first run is finished or skipped (FR-002, FR-003).
class OnboardingController extends ChangeNotifier {
  OnboardingController({required this.reader, this.recitation, this.hasMemorize = false})
      : _step = reader.preferences.onboardingDone ? null : OnboardingStep.language {
    // Readers who finished the onboarding before the coloured ayat existed see that one stop
    // once (specs/010).
    if (_step == null && hasSimilar && !reader.preferences.similarIntroSeen) {
      _replay = true;
      _only = const [OnboardingStep.similarAyat];
      _step = OnboardingStep.similarAyat;
    }
    _steps = _computeSteps();
  }

  final ReaderController reader;
  final RecitationController? recitation;

  /// Memorization exists (specs/006): its button gets a hint.
  final bool hasMemorize;

  OnboardingStep? _step;
  bool _replay = false;

  /// A replay of these stops only, instead of the whole tour.
  List<OnboardingStep>? _only;
  late List<OnboardingStep> _steps;

  /// Null: not onboarding.
  OnboardingStep? get step => _step;
  bool get replay => _replay;
  List<OnboardingStep> get steps => _steps;

  /// Mutashabihat content is loaded: the tour explains the coloured ayat (specs/010).
  bool get hasSimilar => reader.similar.groups.isNotEmpty;

  OnboardingPhase get phase => switch (_step?.kind) {
        null => OnboardingPhase.none,
        StepKind.setup => OnboardingPhase.setup,
        StepKind.gesture => OnboardingPhase.gestures,
        StepKind.button => OnboardingPhase.buttons,
      };

  /// While button hints show, the reading views hold page jumps (FR-017a).
  bool get holdsReader => phase == OnboardingPhase.buttons;

  /// Position within the setup steps, or within the tour stops.
  (int, int) get progress {
    final s = _step;
    return s == null ? (0, 0) : progressOf(_steps, s);
  }

  List<OnboardingStep> _computeSteps() =>
      _only ??
      onboardingSteps(
        hasReciters: recitation != null && reader.quran.reciters.isNotEmpty,
        hasPlayer: recitation != null,
        hasMemorize: hasMemorize,
        hasSimilar: hasSimilar,
        replay: _replay,
      );

  void _go(OnboardingStep step) {
    if (_step == OnboardingStep.reciter && step != OnboardingStep.reciter) _stopSample();
    _step = step;
    notifyListeners();
  }

  void next() {
    final s = _step;
    if (s == null) return;
    final i = _steps.indexOf(s);
    if (i + 1 >= _steps.length) {
      done();
    } else {
      _go(_steps[i + 1]);
    }
  }

  /// The first setup step is left to the system back (leaving the app, FR-025); the first stop
  /// of a replay ends it.
  void back() {
    final s = _step;
    if (s == null) return;
    final i = _steps.indexOf(s);
    if (i > 0) {
      _go(_steps[i - 1]);
    } else if (_replay) {
      skip();
    }
  }

  /// Ends the onboarding at once, keeping every choice made (FR-020).
  void skip() => _finish();

  void done() => _finish();

  void _finish() {
    if (_step == null) return;
    _stopSample();
    final sawSimilar = _steps.contains(OnboardingStep.similarAyat);
    if (!_replay || sawSimilar) {
      reader.updatePreferences(reader.preferences.copyWith(
        onboardingDone: _replay ? null : true,
        similarIntroSeen: sawSimilar ? true : null,
      ));
    }
    _step = null;
    _replay = false;
    _only = null;
    _steps = _computeSteps();
    notifyListeners();
  }

  /// Settings › See the tour again: the tour stops only (FR-022).
  void startReplay() {
    if (_step != null) return;
    _replay = true;
    _steps = _computeSteps();
    _step = _steps.first;
    notifyListeners();
  }

  void _stopSample() {
    final r = recitation;
    if (r != null) unawaited(r.stopPreview());
  }

}

/// Provides the [OnboardingController] and rebuilds dependents on change.
class OnboardingScope extends InheritedNotifier<OnboardingController> {
  const OnboardingScope({super.key, required OnboardingController controller, required super.child})
      : super(notifier: controller);

  static OnboardingController of(BuildContext context) => maybeOf(context)!;

  /// Null where no onboarding is provided (most reader tests).
  static OnboardingController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnboardingScope>()?.notifier;

  /// Access without subscribing to changes (event handlers).
  static OnboardingController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OnboardingScope>()?.notifier;

  /// Whether page jumps wait (button hints showing). Subscribes, so a view rebuilds and applies
  /// the latest jump when the hints end.
  static bool holdsReaderOf(BuildContext context) => maybeOf(context)?.holdsReader ?? false;
}
