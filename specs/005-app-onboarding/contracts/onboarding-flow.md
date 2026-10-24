# Contract: Onboarding Flow

The state behind the onboarding and where it connects to existing code. Screens and strings are
in [onboarding-ui](./onboarding-ui.md). Types are in [data-model](../data-model.md).

## OnboardingController

`lib/features/onboarding/onboarding_controller.dart`. It is a `ChangeNotifier`, created in
`runMathani()` after `ReaderController` and `RecitationController`, and provided by
`OnboardingScope` (an `InheritedNotifier`, with the same `of`, `maybeOf` and `read` pattern as
`ReaderScope`).

```dart
class OnboardingController extends ChangeNotifier {
  OnboardingController({required ReaderController reader, RecitationController? recitation});

  OnboardingStep? get step;          // null: not onboarding
  bool get replay;
  OnboardingPhase get phase;         // none · setup · gestures · buttons
  bool get holdsReader;              // phase == buttons

  List<OnboardingStep> get steps;    // the current sequence (data-model › Step sequence)
  (int index, int total) get progress;  // within setup, or within the tour

  void next();                       // the last step: same as done()
  void back();                       // the first setup step: no-op; the first replay stop: skip()
  void skip();                       // ends at once, from any step (FR-020)
  void done();
  void startReplay();                // from Settings: starts at turnPages with replay = true
}
```

**Behaviour**

| Call | Effect |
| --- | --- |
| constructor | `step = reader.preferences.onboardingDone ? null : OnboardingStep.language`. It listens to `reader` to recompute `steps` when the layout changes (data-model › Validation). |
| `next()` / `back()` | Moves within `steps` and notifies. When leaving `reciter`, calls `recitation?.stopPreview()`. |
| `skip()` / `done()` | `recitation?.stopPreview()`. On a first run: `reader.updatePreferences(prefs.copyWith(onboardingDone: true))`. Then `step = null`, `replay = false`, and notifies. |
| `startReplay()` | Only when `step == null`: `replay = true`, `step = turnPages`, and notifies. |

**Invariants**
- `onboardingDone` is written only by `skip()` and `done()` on a first run (FR-002, FR-003).
- The controller never writes other preferences. Setup steps write them through the same calls
  as Settings (FR-008, FR-012).
- `holdsReader` is false whenever `step` is null, so a finished tour never holds page jumps.

## App shell (lib/app/app.dart, lib/main.dart)

- `MathaniApp` takes `onboarding` (an `OnboardingController?`; null in tests that don't need it)
  and wraps the app in `OnboardingScope` inside `ReaderScope` and `RecitationScope`.
- `home: const _Home()`. `_Home` returns:
  - `OnboardingScreen` when `phase` is `setup` or `gestures`;
  - `ReaderScreen` otherwise.

  With no `OnboardingScope`, it returns `ReaderScreen`.
- `runMathani()` builds `OnboardingController(reader: controller, recitation: recitation)`. Nothing
  else changes before the first frame.

## Preferences (lib/data/models.dart, lib/data/user_repository.dart)

- `ReaderPreferences`:
  - adds `onboardingDone` (default `false`) and `copyWith(onboardingDone:)`;
  - removes `controlsHintShown`.
- `UserRepository`:
  - `_parsePreferences` reads `onboarding_done`: `'true'` means true, anything else false;
  - `savePreferences` writes it, and no longer writes `controls_hint_shown`.

## ReaderScreen (lib/features/reader/reader_screen.dart)

- Removes the one-time controls hint from `_setControls` (research R2).
- Reads `OnboardingScope.maybeOf(context)`. While `phase == buttons`:
  - the controls count as shown (`show = … || tourActive`), and immersive mode is off;
  - the `Scaffold` is wrapped in a `Stack` with `ButtonTour` on top;
  - `_ReaderToolbar` and the recitation bar take a `TourTargets` (`index`, `search`, `listen`,
    `settings`, `player`) and attach the keys to the matching buttons.
- A `PopScope` sends the system back gesture to `onboarding.back()` while hints show.

## MushafView and FlowingView

Before applying a new `jumpSerial`, both check `OnboardingScope.holdsReaderOf(context)`, which
subscribes to the scope. While it is true, they leave `_handledJump` unchanged and do not jump.
When it turns false, they rebuild and apply the latest jump, so a follow jump from an ongoing
recitation lands once the hints are gone. Nothing else changes in either view.

## RecitationController (lib/features/recitation/recitation_controller.dart)

```dart
ReciterPreview? get preview;             // data-model › ReciterPreview
Future<void> previewReciter(Reciter r);  // no-op while a session exists
Future<void> stopPreview();
```

- **What plays**: `RecitedItem.ayah(1, 1)` through `fetcher.resolve` and `_player.setWindow` with
  one item, then `play()`.
  - `_onEngineEvent`: with no session and a preview, `WindowCompleted` clears the preview, and
    `EngineFailed` sets `unavailable`.
  - A `FetchException(offline)`, any other failure, or no `ItemStarted` within 5 s sets
    `unavailable` and stops the engine.
- **Does not**: create a session, call `onFirstPlay`, change `followSerial`, or touch the reader.
- **Stops**: when `previewReciter` is called again, on `stopPreview()`, and on
  `AppLifecycleState.paused` / `hidden`.
- **Network pre-check**: the reciter step calls `DeviceChannel().networkState()` once when it
  opens. On `none`, the step shows the offline note and disables the sample buttons, without
  calling `previewReciter`.

## Settings (lib/features/settings/settings_screen.dart)

Adds a "See the tour again" row (onboarding-ui › Settings row). Tapping it:

```dart
Navigator.of(context).popUntil((r) => r.isFirst);
OnboardingScope.read(context).startReplay();
```

## Tests and tools (research R8)

- `openTestReader({bool onboarded = true})` stores `onboardingDone` first.
- The integration tests that build `ReaderController` themselves pass
  `prefs.copyWith(onboardingDone: true)`, except the first-run pass in `app_flow_test.dart`.
- The controls-hint expectations in `reader_page_view_test.dart` are removed.
