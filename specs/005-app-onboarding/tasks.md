---

description: "Task list for the onboarding"
---

# Tasks: Onboarding

**Input**: Design documents from `specs/005-app-onboarding/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Included. The plan and quickstart list the unit and widget tests. The rules "shown once,
never again" (SC-004) and "updating readers keep everything" (SC-009) can only be held by
automated checks.

**Organization**: Tasks are grouped by user story (US1–US4 in the spec).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US4)

## Path Conventions

Single Flutter project at the repository root: `lib/`, `test/`, `integration_test/`. New code
lives in `lib/features/onboarding/`.

## Shared conventions

- **Tests**:
  - Tests that need the real Quran data use `openTestReader()` and `loadAppFonts()` from
    `test/support/harness.dart` inside `testWidgets`, wrapping database work in
    `tester.runAsync(...)`.
  - Onboarding tests call `openTestReader(onboarded: false)` (T004).
  - Recitation previews use the fake `AudioEngine` in `test/support/fake_recitation.dart` and
    `test/support/fake_audio_server.dart`.
  - Network state is faked on the `app.mathani/device` channel with
    `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler`.
- **Named constants**, each defined in one place:

  | Constant | Value | Defined in |
  | --- | --- | --- |
  | `stepTransition` | 250 ms | `onboarding_screen.dart` |
  | `sampleStartTimeout` | 5 s | `recitation_controller.dart` |
  | `gestureLoop` | 2.4 s | `tour_illustration.dart` |
  | `scrimOpacity` | 0.55 | `button_tour.dart` |
  | `holeInflate` | 8 dp | `button_tour.dart` |
  | `holeStroke` | 2 dp | `button_tour.dart` |

- **Preferences are written only through `ReaderController.updatePreferences`**, or
  `RecitationController.setReciter` for the reciter, exactly as Settings does (FR-008, FR-012).
  `OnboardingController` writes only `onboardingDone`.
- **Strings**: every user-visible string comes from `AppLocalizations`. Keys and wording are in
  [onboarding-ui › Strings](./contracts/onboarding-ui.md#strings-app_ararb--app_enarb).
- **Style**: match the surrounding code. Doc comments reference the spec or contract (for
  example `(FR-017a)`), and colours come from `MathaniColors` with spacing from `Space`.

---

## Phase 1: Setup

**Purpose**: The feature folder and strings that every story uses.

- [X] T001 Create `lib/features/onboarding/` with empty library files named in plan.md › Source
  Code: `onboarding_steps.dart`, `onboarding_controller.dart`, `onboarding_screen.dart`,
  `setup_steps.dart`, `tour_illustration.dart`, `button_tour.dart`. Each starts with a one-line
  header comment pointing at its contract section, as the files in `lib/features/recitation/`
  do.
- [X] T002 Add all 37 new keys from
  [onboarding-ui › Strings](./contracts/onboarding-ui.md#strings-app_ararb--app_enarb) to
  `lib/app/l10n/app_en.arb` (with `@key` descriptions; `{language}`, `{index}`, `{total}` as
  placeholders, `index` and `total` typed `String` so numerals come from `formatNumber`) and
  `lib/app/l10n/app_ar.arb`. Remove `controlsHint` and `@controlsHint` from both. Run
  `flutter gen-l10n` and commit the regenerated `lib/app/l10n/app_localizations*.dart`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The stored flag, the step sequence, the controller, the app shell and the onboarding
screen frame. Every story builds on these.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Preference (data-model › Preference `onboarding_done`)

- [X] T003 In `lib/data/models.dart`, change `ReaderPreferences`:
  - add `final bool onboardingDone;`, with a doc comment ("The first-run onboarding was finished
    or skipped (specs/005, FR-002)."), default `false`, and `copyWith(onboardingDone:)`;
  - remove `controlsHintShown` (field, constructor parameter, `copyWith` parameter, doc comment).

  In `lib/data/user_repository.dart`:
  - `_parsePreferences` reads `onboarding_done` as `switch (p['onboarding_done']) { 'true' =>
    true, _ => d.onboardingDone }`;
  - `savePreferences` writes `'onboarding_done': '${p.onboardingDone}'` and no longer writes
    `controls_hint_shown`;
  - add a comment that stale `controls_hint_shown` rows are ignored (research R2).

  **No schema change**: `_schemaVersion` stays 1.
- [X] T004 In `test/support/harness.dart`, change `openTestReader` to
  `openTestReader({bool onboarded = true})`. When `onboarded`, call
  `user.savePreferences(prefs.copyWith(onboardingDone: true))` and use those preferences for the
  `ReaderController`. Update `integration_test/app_flow_test.dart`,
  `integration_test/paging_perf_test.dart` and `integration_test/store_screenshots_test.dart` to
  build their `ReaderController` with `prefs.copyWith(onboardingDone: true)` (research R8).
- [X] T005 Remove the one-time controls hint (research R2). This covers:
  - in `lib/features/reader/reader_screen.dart` › `_setControls`: the
    `!reader.preferences.controlsHintShown` block (its `showSnackBar` and `updatePreferences`).
    Keep `if (show) ScaffoldMessenger.of(context).hideCurrentSnackBar();`. It also clears snack
    bars such as "Bookmark added" that sit over the toolbar. Reword its comment to
    `// Snack bars sit over the toolbar; clear them when the controls come back.`;
  - in `test/widget/reader_page_view_test.dart`: the `_hint` constant and the two hint
    expectations (lines asserting `find.text(_hint)` and `controlsHintShown`).

  The test's other expectations stay as they are.

### Steps and controller (data-model › Step sequence, contracts/onboarding-flow.md)

- [X] T006 [P] Write `test/unit/onboarding_steps_test.dart`. It covers:
  - `steps(flowing: false, hasReciters: true, hasPlayer: true, replay: false)` is exactly
    `[language, theme, layout, reciter, turnPages, controls, ayahActions, surahIndex, search, player,
    settings]`;
  - `flowing: true` inserts `textSize` after `layout`;
  - `hasReciters: false` drops `reciter`, and `hasPlayer: false` drops `player`;
  - `replay: true` starts at `turnPages`;
  - `progressOf` gives setup steps "Step i of n" counting setup steps only (4 for Mushaf, 5 for
    flowing), and tour stops "i of 7".
- [X] T007 [P] Implement `lib/features/onboarding/onboarding_steps.dart` (pure Dart, no Flutter
  import):
  - `enum OnboardingStep { language, theme, layout, textSize, reciter, turnPages, controls,
    ayahActions, surahIndex, search, player, settings }` with a `kind` getter (`setup` · `gesture` ·
    `button`);
  - `List<OnboardingStep> onboardingSteps({required bool flowing, required bool hasReciters,
    required bool hasPlayer, required bool replay})`, as the data-model formula;
  - `(int index, int total) progressOf(List<OnboardingStep> steps, OnboardingStep step)`, with a
    1-based index within the step's group (setup, or gesture + button together).

  T006 passes.
- [X] T008 Write `test/unit/onboarding_controller_test.dart` with a real `ReaderController` from
  `openTestReader(onboarded: false)` and a real `RecitationController` built with
  `FakeAudioEngine` and `FakeFetcher` from `test/support/fake_recitation.dart`. It covers:
  - a fresh controller starts at `language`, and with `onboardingDone: true` at null;
  - `next()` and `back()` walk the list; `back()` on `language` is a no-op;
  - `skip()` from every step, and `done()`, set `onboardingDone` to true in `reader.preferences`
    and in `user.db` (reload with `loadStartup()`), and set `step` to null;
  - other preferences changed before `skip()` are kept;
  - closing midway: change the theme to night and move to `layout`, then build a new
    `ReaderController` and `OnboardingController` from `loadStartup()` without calling `skip()`.
    The new controller starts at `language`, with `ThemePref.night` kept (FR-003);
  - changing the layout to flowing while on `layout` keeps `layout` as the current step and makes
    `textSize` the next one; changing it back to Mushaf makes `reciter` the next one
    (data-model › Validation);
  - with a sample started on `reciter`, leaving it by `next`, `back`, `skip` or `done` leaves
    `recitation.preview == null` and the engine stopped. This case passes once T018 is done;
    until then mark it `skip: 'needs T018'`;
  - `startReplay()` when `step == null` sets `replay`, starts at `turnPages`, and `done()` leaves
    `onboardingDone` unchanged; `back()` on `turnPages` in a replay equals `skip()`;
  - `holdsReader` is true only on button steps.
- [X] T009 Implement `lib/features/onboarding/onboarding_controller.dart`:
  - `OnboardingPhase { none, setup, gestures, buttons }`;
  - `OnboardingController extends ChangeNotifier`, with the API in
    [onboarding-flow › OnboardingController](./contracts/onboarding-flow.md#onboardingcontroller);
  - it listens to `reader` to recompute `steps` (removing the listener in `dispose`);
  - `hasReciters` is `recitation != null && reader.quran.reciters.isNotEmpty`, and `hasPlayer`
    is `recitation != null`;
  - `OnboardingScope extends InheritedNotifier<OnboardingController>` with `of`, `maybeOf`,
    `read` and `static bool holdsReaderOf(BuildContext)`. `holdsReaderOf` subscribes and returns
    false without a scope.

  `stopPreview()` is called through `recitation?.stopPreview()`. Until T018 adds it, add a no-op
  `Future<void> stopPreview() async {}` to `RecitationController` so this compiles. T008 passes.

### App shell (contracts/onboarding-flow.md › App shell)

- [X] T010 In `lib/app/app.dart`:
  - add `final OnboardingController? onboarding;` to `MathaniApp`;
  - wrap the `MaterialApp` in `OnboardingScope` (inside `ReaderScope` and `RecitationScope`)
    when it is non-null;
  - replace `home: const ReaderScreen()` with `home: const _Home()`. `_Home` returns
    `OnboardingScreen` when `OnboardingScope.maybeOf(context)?.phase` is `setup` or `gestures`,
    otherwise `ReaderScreen`.

  In `lib/main.dart` › `runMathani()`, build
  `OnboardingController(reader: controller, recitation: recitation)` after `recitation` and pass
  it to `MathaniApp`. Add nothing else before `runApp`.

### Onboarding screen frame (contracts/onboarding-ui.md › OnboardingScreen)

- [X] T011 Implement `OnboardingScreen` in `lib/features/onboarding/onboarding_screen.dart`:
  - a `Scaffold` on `colors.surface` in a `SafeArea`;
  - a `PageView` with `NeverScrollableScrollPhysics`, whose pages are the setup and gesture
    steps of `onboarding.steps`. Each page is a `SingleChildScrollView` with the progress line
    (`onboardingStep` for setup steps, `tourProgress` for gesture stops, numbers through
    `formatNumber`), the title (`TypeScale.titleLg`) and a body slot;
  - the page index is kept in sync with `onboarding.step`, using `animateToPage` over
    `stepTransition` with `Curves.easeOut`, or `jumpToPage` when
    `MediaQuery.disableAnimationsOf(context)`;
  - after each step change, screen-reader focus moves to the title (a `Semantics` title with
    `SemanticsService.sendAnnouncement` or a focus node; whichever passes T012's semantics
    check);
  - the bottom bar is a `Wrap` that keeps one row when it fits: Skip (`TextButton`,
    `onboardingSkip`) at the start, then Back (`OutlinedButton` with `MathaniIcons.back`, hidden
    on the first step) and Next (`FilledButton` with `MathaniIcons.forward`). It is always
    visible, outside the scroll view, and every button is at least 48 dp tall;
  - `PopScope(canPop: onboarding.step == onboarding.steps.first && !onboarding.replay)`, where
    `onPopInvokedWithResult` calls `onboarding.back()`.

  The setup step bodies are placeholders (`SizedBox`) until US1, and the gesture step bodies
  until US3.
- [X] T012 Write `test/widget/onboarding_screen_test.dart` (frame part). It uses
  `openTestReader(onboarded: false)` and `MathaniApp(controller:, onboarding:)`, and covers:
  - the onboarding shows instead of the reader;
  - the progress reads «الخطوة ١ من ٤» in Arabic and "Step 1 of 4" in English;
  - Next and Back move between steps; Back is hidden on step 1;
  - Skip is hit-testable on every step at 320×568;
  - the system back (`tester.binding.handlePopRoute()`) on step 2 returns to step 1;
  - a `MathaniApp` with `onboarding` null shows `ReaderScreen` directly.

**Checkpoint**: Fresh installs open on a navigable (empty) onboarding, and existing tests pass
with `flutter test`.

---

## Phase 3: User Story 1 - Set my preferences before I start reading (Priority: P1) 🎯 MVP

**Goal**: The reader picks language, theme, layout (and text size), and reciter with live
previews and samples, and the reader opens set up that way.

**Independent Test**: On a fresh install, choose English, Night, Flowing at a larger size, and
El-Minshawi, then finish. The reader is in English, at night, flowing at that size, and plays
El-Minshawi. Settings shows the same (quickstart Q-2).

### Tests for User Story 1

- [X] T013 [P] [US1] Write `test/unit/reciter_preview_test.dart`, using the fake engine and fake
  audio server. It covers:
  - `previewReciter(husary)` goes `loading` → `playing` and plays exactly
    `RecitedItem.ayah(1, 1)`;
  - `WindowCompleted` clears `preview`;
  - no `RecitationSession` is created, `onFirstPlay` is not called, `followSerial` and
    `reader.jumpSerial` are unchanged, and `recited` stays null;
  - a second `previewReciter(minshawy)` replaces the first, and the engine is stopped in between;
  - a `FetchException(offline)` sets `unavailable`;
  - no `ItemStarted` within `sampleStartTimeout` (`fakeAsync`) sets `unavailable` and stops the
    engine;
  - `stopPreview()` clears it;
  - `didChangeAppLifecycleState(paused)` clears it;
  - while a session exists, `previewReciter` does nothing.
- [X] T014 [P] [US1] Extend `test/widget/onboarding_screen_test.dart` (setup steps). It covers:
  - on the language step, tapping English switches `Directionality` to LTR and the title to
    English in the same step, and tapping العربية switches back;
  - the system card shows the resolved language name;
  - the theme cards change `Theme.of(context).brightness` live, with the
    `TourIllustration` present;
  - choosing Flowing on the layout step makes the next step `textSize`, whose slider is bounded
    18–34 and changes `reader.preferences.flowFontSize`; the Al-Fatiha sample's font size
    follows it;
  - the reciter step lists both reciters, preselects `reciterOrDefault(prefs.reciter)`, and
    tapping El-Minshawi saves `reciter = minshawy`;
  - with the device channel answering `none`, the offline note (`sampleOffline`) shows and the
    sample buttons are disabled;
  - each step opens with the current value selected (pre-seed `theme: night` and check the
    Night card is checked).

### Implementation for User Story 1

- [X] T015 [P] [US1] Implement the static miniature in
  `lib/features/onboarding/tour_illustration.dart`:
  - `TourIllustration({required ReadingLayout layout, OnboardingStep? gesture})`, where
    `gesture == null` is the static preview used on the theme and layout steps;
  - a `CustomPaint` in a `RepaintBoundary`, about 160×240 dp, centred, scaling down on short
    screens;
  - **Mushaf**: a `surfaceRaised` sheet with a `line`-coloured frame and 15 justified bars in
    `ink` at 35% alpha;
  - **flowing**: ragged bars with small `accent` circles as ayah markers;
  - colours from `MathaniColors.of(context)` only;
  - wrapped in `ExcludeSemantics` (research R3).

  The animated `gesture` variants come in T027.
- [X] T016 [P] [US1] Implement the language, theme and layout steps in
  `lib/features/onboarding/setup_steps.dart` as widgets taking no arguments, reading the
  `ReaderScope`. They share a private `_ChoiceCard` widget: an `InkWell` card on
  `surfaceRaised`, radius `md`, at least 56 dp tall, with an optional leading icon, title and
  subtitle, and a trailing check on selection, wrapped in
  `Semantics(inMutuallyExclusiveGroup: true, checked:, button: true)`.
  - **LanguageStep**: the bilingual welcome line (`onboardingWelcome` in both scripts, by looking
    up both `AppLocalizations` via `lookupAppLocalizations`), the title `onboardingLanguageTitle`,
    and cards:
    - system: `onboardingSystemLanguage`, with the name from
      `MathaniApp.resolveLocale(LanguagePref.system, PlatformDispatcher.instance.locales)` shown
      as «العربية» or "English";
    - العربية;
    - English.
  - **ThemeStep**: a `TourIllustration(layout: prefs.layout)`, then cards for
    `themeSystem`/`themeDay`/`themeNight` with the existing icons.
  - **LayoutStep**: a `TourIllustration(layout: prefs.layout)`, then the mushaf and flowing cards
    with `onboardingLayoutMushafHint` and `onboardingLayoutFlowingHint`.
  - Taps call `reader.updatePreferences(reader.preferences.copyWith(…))`, deriving from the
    current preferences as `SettingsScreen.set` does.
- [X] T017 [US1] Add **TextSizeStep** to `lib/features/onboarding/setup_steps.dart`. It has the
  same `Slider` as Settings (`min`/`max`/`divisions` from `ReaderPreferences.minFlowFontSize` and
  `maxFlowFontSize`, with the value label through `formatNumber`), then a `surfaceRaised` card
  with Al-Fatiha 1–3.
  - The words are loaded once in `initState` with `reader.quran.flowingPage(1)` (the same call
    `FlowingView` uses), keeping the first three `(Ayah, List<Word>)` entries: Al-Fatiha 1–3.
  - The card's fixed height is `fontSize * 2 * 3` until loaded, so nothing jumps.
  - The text uses the flowing layout's `TextStyle`: `fontFamily: TypeScale.quranFamily`,
    `height: TypeScale.quranLineHeight`, `color: colors.ink`, at the chosen size. It is built
    inline in `flowing_view.dart` (around `final style = TextStyle(`); extract it to a small
    shared function there, `TextStyle flowingTextStyle(MathaniColors colors, double fontSize)`,
    and use it in both places (constitution V). Ayah-end markers use `ayahEndGlyphs` from
    `lib/shared/quran_text.dart`, as in `FlowingView`.
- [X] T018 [US1] In `lib/features/recitation/recitation_controller.dart`, add the preview
  ([onboarding-flow › RecitationController](./contracts/onboarding-flow.md#recitationcontroller-libfeaturesrecitationrecitation_controllerdart),
  data-model › ReciterPreview), replacing T009's no-op:
  - `enum PreviewStatus { loading, playing, unavailable }`, and `class ReciterPreview { final
    String reciterId; PreviewStatus status; }`;
  - `const sampleStartTimeout = Duration(seconds: 5);`;
  - `previewReciter(Reciter r)` returns at once if `_session != null`. It stops any current
    preview, sets `loading`, resolves `RecitedItem.ayah(1, 1)` with `fetcher.resolve`, calls
    `_player.setWindow([(item, file)])` and `play()`, and starts a `sampleStartTimeout` timer
    that sets `unavailable` and stops the engine if no `ItemStarted` arrives. A preview
    generation counter drops stale async results, like `_generation`;
  - `stopPreview()` cancels the timer, stops the engine if a preview owns it, and sets `preview`
    to null;
  - `_onEngineEvent`: when `_session == null && _preview != null`, handle `ItemStarted` →
    `playing`, `WindowCompleted` → null, and `EngineFailed` → `unavailable`;
  - `didChangeAppLifecycleState`: on `paused` or `hidden`, `stopPreview()`;
  - `onFirstPlay` is **not** called, and no session, follow jump or highlight is created.

  T013 passes. Remove the `skip:` from T008's sample case; it passes too.
- [X] T019 [US1] Add **ReciterStep** to `lib/features/onboarding/setup_steps.dart`:
  - on open, read `const DeviceChannel().networkState()` once, and keep `offline` in state;
  - show the title `onboardingReciterTitle`, then one card per `reader.quran.reciters`:
    - the name as `r.name(arabic:)`, with the subtitle `murattal` (or `'${r.nameAr} ·
      ${l10n.murattal}'` in English, as in the reciter sheet);
    - selected is `reader.quran.reciterOrDefault(prefs.reciter)?.id`;
    - a trailing 48 dp round `IconButton` for the sample: `MathaniIcons.play`, a spinner while
      `loading`, `MathaniIcons.pause` while `playing`. Its tooltip and semantics are
      `'${l10n.playSample}, ${name}'` or `stopSample`, and it is disabled when offline;
  - tapping a card calls `RecitationScope.maybeOf(context)?.setReciter(r.id)`, or
    `updatePreferences(reciter:)` without recitations (the same rule as `reciter_sheet.dart` ›
    `_choose`). Make `_choose` a top-level `chooseReciter(...)` in `reciter_sheet.dart` and call
    it from both places;
  - below the cards: `onboardingReciterHint`, and when `offline` or any card's preview is
    `unavailable`, the `sampleOffline` note with `MathaniIcons.info` in `inkMuted`.
- [X] T020 [US1] Wire the setup step bodies into `OnboardingScreen`
  (`lib/features/onboarding/onboarding_screen.dart`): `language` → LanguageStep, `theme` →
  ThemeStep, `layout` → LayoutStep, `textSize` → TextSizeStep, `reciter` → ReciterStep. Check
  that changing the language rebuilds in place: the `PageController` and current step are kept,
  because `OnboardingScreen` is the same element under `MaterialApp`. T014 passes.

**Checkpoint**: The setup steps work end to end. With the tour still empty, Next from the reciter
step reaches the (placeholder) gesture stops. Q-1, Q-2, Q-3, Q-6, Q-7 and Q-8 can be run.

---

## Phase 4: User Story 2 - Skip the onboarding (Priority: P1)

**Goal**: One tap from any screen reaches the reader, keeping any choices. The onboarding never
returns on its own. Readers updating from 1.3.0 see it once.

**Independent Test**: On a fresh install, Skip on the first screen opens page 1 with the
defaults, and reopening goes straight to the reader. Choosing Night before skipping keeps Night
(quickstart Q-4, Q-5, Q-10).

**Depends on**: Phase 2 (`skip()` and the bottom bar). The reciter-related checks use US1's
ReciterStep.

### Tests for User Story 2

- [X] T021 [P] [US2] Extend `test/widget/onboarding_screen_test.dart` (skip). It covers:
  - Skip on step 1 shows `ReaderScreen` within one `pump`, on page 1, with defaults;
  - for each setup step, a fresh app reaching that step and tapping Skip lands on the reader;
  - Skip after choosing Night keeps `ThemePref.night`;
  - Skip on the reciter step while a fake preview plays leaves `preview == null`;
  - after Skip, a new `MathaniApp` built over the same `user.db` (reload with `loadStartup()`)
    shows the reader, not the onboarding.
- [X] T022 [P] [US2] Write `test/unit/onboarding_update_test.dart` for readers updating from
  1.3.0 (SC-009):
  - seed a fresh `user.db` as 1.3.0 would leave it: rows for `theme=night`, `reciter=minshawy`,
    `controls_hint_shown=true`, a `reading_state` anchor of 67:1 (page 562), and one bookmark,
    with no `onboarding_done` row;
  - `loadStartup()` gives `onboardingDone == false` with the seeded preferences;
  - a controller starts at `language`;
  - after `skip()`, the anchor, bookmark and preferences are unchanged and `onboardingDone` is
    true;
  - the stale `controls_hint_shown` row doesn't break parsing.

### Implementation for User Story 2

- [X] T023 [US2] In `lib/features/onboarding/onboarding_screen.dart`, make Skip end the
  onboarding in one tap: `onboarding.skip()` with no dialog. Because `_Home` swaps to
  `ReaderScreen`, the reader opens at `reader.anchor`, which is page 1 on a fresh install and the
  saved page after an update. Make sure the Skip button is the first focusable element of the
  bottom bar in traversal order, so it is reachable without hunting (FR-019).
- [X] T024 [US2] Add the first-run pass to `integration_test/app_flow_test.dart`. On a fresh
  temporary database without `onboardingDone`, it pumps `MathaniApp(controller:, recitation: null,
  onboarding:)`, expects the language step, taps Skip, and expects the reader on page 1. A
  second pass goes through every step with Next to `Done`, and expects the reader with no
  onboarding on a re-pump.

**Checkpoint**: Skip works everywhere, and updates behave. Q-4, Q-5, Q-9 and Q-10 can be run
(Q-9 needs US3 for the full walk-through).

---

## Phase 5: User Story 3 - Learn how to use the app (Priority: P2)

**Goal**: Animated gesture stops (turn pages, controls, ayah actions) are followed by hints over
the real toolbar (index, search, player, settings).

**Independent Test**: A first-time reader finishes the onboarding and can then, unaided, show
the controls, turn the page, play from the third ayah, bookmark it, find it, and search
(quickstart Q-11, Q-12, Q-18).

### Tests for User Story 3

- [X] T025 [P] [US3] Write `test/widget/button_tour_test.dart` with
  `openTestReader(onboarded: false)`, starting the controller at `surahIndex` (test-only: call
  `next()` until `phase == buttons`). It covers:
  - the scrim's hole rect contains the real index `IconButton`'s rect, inflated by
    `holeInflate`, and the same for search, Listen and settings;
  - tapping inside the hole does not push `IndexScreen`;
  - tapping the page doesn't change `reader.page`;
  - in the Mushaf layout, the toolbar is hit-testable and the controls stay shown while hints are
    up, even after `_setControls(false)` would have hidden them;
  - `reader.jumpTo(AyahRef(2, 255))` during hints leaves the visible `PageView` page unchanged.
    After Done, the page is 42;
  - with a fake recitation session, the player step's hole contains the `RecitationBar`;
  - Done on `settings` sets `onboardingDone` and removes the overlay;
  - system back on `surahIndex` returns to `ayahActions` (the `OnboardingScreen` shows again).
- [X] T026 [P] [US3] Extend `test/widget/onboarding_screen_test.dart` (gesture stops). It covers:
  - after the reciter step, the next three steps show `tourTurnPagesTitle`, `tourControlsTitle`
    and `tourAyahTitle` with "1 of 7" to "3 of 7" progress;
  - the Mushaf layout shows the `tourTurnPagesMushaf` and `tourControlsMushaf` bodies, and
    flowing shows the `…Flowing` bodies;
  - the illustration is excluded from semantics;
  - with `disableAnimations: true`, no `AnimationController` ticks (`tester.hasRunningAnimations`
    is false after a pump).

### Implementation for User Story 3

- [X] T027 [P] [US3] Add the animated `gesture` variants to
  `lib/features/onboarding/tour_illustration.dart` (research R3 table). One
  `AnimationController(duration: gestureLoop)..repeat()` per widget is disposed with it and not
  started when `MediaQuery.disableAnimationsOf(context)`; in that case the illustration draws a
  still frame with an arrow.

  The touch dot is a filled circle in `accent` at 70% alpha, 24 dp, with an expanding ring.

  | Gesture | Mushaf | Flowing |
  | --- | --- | --- |
  | `turnPages` | The dot drags towards the right over the sheet, and the next sheet slides in from the left (the RTL `PageView` direction in `mushaf_view.dart`). | The dot drags upward and the bars scroll up. |
  | `controls` | The dot taps; header and toolbar bars (`bar` colour) slide in, and on the next tap slide out. | The bars stay; the dot taps and nothing hides. |
  | `ayahActions` | The dot holds on line 6, which fills with `selected`; a small sheet rises with `MathaniIcons.play`, `bookmark`, `copy`, `share` drawn with `TextPainter` from the icon font. | The same, on a flowing line. |

- [X] T028 [US3] Wire the gesture stop bodies into `OnboardingScreen`
  (`lib/features/onboarding/onboarding_screen.dart`). Each shows the title, then the body for the
  current layout (`tourTurnPagesMushaf` or `tourTurnPagesFlowing`, `tourControlsMushaf` or
  `tourControlsFlowing`, `tourAyahBody`), then
  `TourIllustration(layout: prefs.layout, gesture: step)`. Next on `ayahActions` advances to
  `surahIndex`, so `_Home` shows the reader. T026 passes.
- [X] T029 [US3] Implement `lib/features/onboarding/button_tour.dart`:
  - `class TourTargets { final index = GlobalKey(); final search = GlobalKey(); final listen =
    GlobalKey(); final settings = GlobalKey(); final player = GlobalKey(); }`;
  - `ButtonTour({required TourTargets targets})` reads `OnboardingScope.of(context)`.
  - **Target**: after layout (a post-frame callback, and again in `didChangeMetrics` /
    `didChangeDependencies`), it reads the current step's key `RenderBox` rect via
    `localToGlobal`. For `player`, it uses `targets.player` while a recitation session exists,
    else `targets.listen`. If the key has no context, it calls `onboarding.next()` (onboarding-ui
    › ButtonTour › Targets).
  - **Scrim**: a `CustomPainter` that fills with black at `scrimOpacity` using
    `Path.combine(PathOperation.difference, …)` around an `RRect` (radius `Radii.sm`) inflated by
    `holeInflate`, and strokes `focusRing` at `holeStroke`. Wrapped in
    `AbsorbPointer`/`GestureDetector(onTap: () {})` so all taps are absorbed.
  - **Card**: `surfaceRaised`, radius `Radii.md`, horizontal margin `Space.s4`, placed above the
    target, or below it when the target's centre is in the top half. It has a small triangle
    notch towards the target's centre x. The whole card is at most half the screen:
    `tourProgress`, the title (`TypeScale.titleSm`) and the body (`TypeScale.body`) sit in a
    scroll area, and the same Skip / Back / Next buttons as the onboarding bottom bar are pinned
    below it, never inside it (FR-019). Next reads `tourDone` on the last step. Extract the bar from T011 into a shared `OnboardingButtons` widget in
    `onboarding_screen.dart` and use it in both places.
  - **Semantics**: the card is a `Semantics(container: true, label: '$progress, $title. $body')`,
    and its title gets focus on each step change.
- [X] T030 [US3] Integrate the tour into `lib/features/reader/reader_screen.dart`:
  - create one `TourTargets` in `_ReaderScreenState`;
  - pass it to `_ReaderToolbar`, which puts `key: targets.index` (and so on) on the index,
    search, Listen and settings `IconButton`s;
  - pass `targets.player` as the `key` of the `RecitationBar` instance;
  - read `final touring = OnboardingScope.maybeOf(context)?.phase == OnboardingPhase.buttons;`.
    In the Mushaf layout, `show = _controlsVisible || _keepControls || touring`. While touring,
    `_setControls(false)` is ignored and `_setImmersive(false)` applies;
  - when touring, wrap the returned `Scaffold` (both layout branches) in
    `Stack([ExcludeSemantics(child: BlockSemantics(child: scaffold)), ButtonTour(targets:
    targets)])`, inside a `PopScope(canPop: false, onPopInvokedWithResult: (_, _) =>
    onboarding.back())`.
- [X] T031 [US3] Hold page jumps during hints:
  - in `lib/features/reader/mushaf_view.dart` › `build`, change
    `if (reader.jumpSerial != _handledJump)` to
    `if (reader.jumpSerial != _handledJump && !OnboardingScope.holdsReaderOf(context))`;
  - make the same change in `lib/features/reader/flowing_view.dart` › `build`;
  - add a one-line comment citing FR-017a and the spec edge case.

  Nothing else changes; the latest jump applies on the rebuild when the hold ends. T025 passes.
- [X] T032 [US3] Make sure finishing the tour on a first run leaves the reader on its page with
  the controls shown and no snack bar, and that `onboardingDone` is written. The behaviour is in
  T009's `done()`. Here, add a widget check to `test/widget/button_tour_test.dart` that no
  `SnackBar` appears after Done and after the first page turn (FR-018).

**Checkpoint**: The full first-run onboarding works. Q-9, Q-11, Q-12, Q-14 and Q-17 can be run.

---

## Phase 6: User Story 4 - See the tour again later (Priority: P3)

**Goal**: Settings › "See the tour again" runs the gesture stops and button hints, ending on the
reader at the same page with nothing changed.

**Independent Test**: Skip the onboarding, read to page 200, replay the tour from Settings, and
finish: still page 200, with the same preferences and bookmarks (quickstart Q-13).

**Depends on**: US3 (the tour it replays).

### Tests for User Story 4

- [X] T033 [P] [US4] Write `test/widget/tour_replay_test.dart` with `openTestReader()` (onboarded).
  It covers:
  - jump to page 200 and open Settings; the row `tourAgainSetting` is present;
  - tapping it pops Settings and shows the `turnPages` stop with "1 of 7", with no setup steps;
  - Next ×3 shows the reader with the index hint, and `reader.page` is 200;
  - Done leaves page 200, `onboardingDone` still true, preferences equal to before (compare
    `savePreferences` output), and bookmarks unchanged;
  - again, with Skip on the first stop: the reader is at page 200;
  - system back on the first replay stop equals Skip;
  - with a fake recitation session playing, the session and its item are unchanged after the
    replay.

### Implementation for User Story 4

- [X] T034 [US4] In `lib/features/settings/settings_screen.dart`, add the "See the tour again"
  `ListTile` (onboarding-ui › Settings row) after `RecitationSettings` and the language section,
  before the About divider:
  - leading `MathaniIcons.info`, title `tourAgainSetting`, subtitle `tourAgainHint` in
    `TypeScale.caption`/`inkMuted`, trailing `MathaniIcons.forward`;
  - `onTap` runs `Navigator.of(context).popUntil((r) => r.isFirst);` then
    `OnboardingScope.read(context).startReplay();`. Read the scope before popping;
  - shown only when `OnboardingScope.maybeOf(context) != null`.

  T033 passes.

**Checkpoint**: All four stories work independently.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Accessibility, performance, size, docs and device validation.

- [X] T035 [P] Write `test/widget/onboarding_a11y_test.dart`. It covers:
  - with `SemanticsHandle`, the choice cards expose `isInMutuallyExclusiveGroup` and `isChecked`;
  - the sample button's label includes the reciter name;
  - under button hints, the only semantics nodes with actions are the card's three buttons;
  - at `textScaler: TextScaler.linear(2.0)` on a 320×568 surface, every setup step, gesture stop
    and hint card lays out without overflow errors, and the bottom bar buttons and the hint
    card's Skip stay hit-testable without scrolling (FR-019, FR-024, Q-16).
- [X] T036 [P] Add a superseded note to
  `specs/002-print-like-mushaf-page/contracts/reader-page-view.md` where it describes the
  one-time controls hint: "Removed in 1.4.0 by specs/005 (the onboarding teaches the tap; research
  R2)." Follow the way specs/004 annotated earlier specs.
- [X] T037 Run `flutter analyze` and `flutter test`; fix every new warning and failure.
- [ ] T038 Run the performance and size gates in [quickstart](./quickstart.md#performance-and-size-gates-principles-iii-and-iv)
  on both reference phones:
  - cold start to the first usable onboarding screen ≤ 2 s (SC-006);
  - gesture animations at 60 fps in a profile build;
  - step changes: in a profile build, the first changed frame after tapping Next lands within
    100 ms, for a setup step, a gesture stop and a hint (FR-026), read from the DevTools
    timeline;
  - `paging_perf_test` unchanged;
  - `tool/size_check.dart` growth well under 1 MB on both stores (SC-008).

  Record the numbers in the PR description.
- [ ] T039 Run device scenarios Q-1 to Q-17 in [quickstart](./quickstart.md#device-scenarios) on
  the Galaxy A15 and the iPhone SE (2nd gen), and Q-1, Q-4 and Q-7 on the API 24 emulator. For
  Q-9 and Q-10, install 1.3.0 from the store tracks first. Fix what fails.
- [ ] T040 Run the usability test Q-18 with 5 first-time readers. Record the completion times
  (SC-001) and task success (SC-005: at least 4 of 5) in the release checklist.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup. It blocks every story.
- **US1 (Phase 3)**: depends on Foundational.
- **US2 (Phase 4)**: depends on Foundational. T021's reciter check needs T018 and T019.
- **US3 (Phase 5)**: depends on Foundational. It is independent of US1 and US2: the tour runs
  even with placeholder setup bodies.
- **US4 (Phase 6)**: depends on US3.
- **Polish (Phase 7)**: depends on the stories being shipped.

### Within each phase

- Tests are written first and fail before the implementation task that names them.
- Foundational: T003 → T004 → T005 (T005's test file needs T004). T006 ∥ T007 → T008 → T009
  → T010 → T011 → T012. T008's sample case is skipped until T018, then unskipped.
- US1: T015 ∥ T016 → T017; T018 → T019; then T020.
- US3: T027 → T028; T029 → T030 → T031 → T032.

### Parallel Opportunities

- T006 and T007 (pure Dart, separate files).
- T013 and T014 (different test files), and T015 and T016 (different files).
- T021 and T022.
- T025, T026 and T027.
- After Foundational, US1 and US3 can proceed in parallel. They touch different files except
  `onboarding_screen.dart` (T020, T028); do those two one at a time.
- T035 and T036.

---

## Parallel Example: Foundational

```text
Task: "T006 Write test/unit/onboarding_steps_test.dart"
Task: "T007 Implement lib/features/onboarding/onboarding_steps.dart"
```

## Parallel Example: User Story 1

```text
Task: "T013 Write test/unit/reciter_preview_test.dart"
Task: "T014 Extend test/widget/onboarding_screen_test.dart (setup steps)"
Task: "T015 Static miniature in lib/features/onboarding/tour_illustration.dart"
Task: "T016 Language, theme and layout steps in lib/features/onboarding/setup_steps.dart"
```

## Parallel Example: User Story 3

```text
Task: "T025 Write test/widget/button_tour_test.dart"
Task: "T026 Extend test/widget/onboarding_screen_test.dart (gesture stops)"
Task: "T027 Gesture variants in lib/features/onboarding/tour_illustration.dart"
```

---

## Implementation Strategy

### MVP First (User Stories 1 and 2, both P1)

1. Phase 1 and Phase 2. The app opens on a navigable onboarding frame, and existing tests are
   green.
2. Phase 3 (US1): the preferences are set before reading.
3. Phase 4 (US2): skip and updates.
4. **STOP and VALIDATE**: Q-1 to Q-8 and Q-10. With US3 not built yet, Next past the reciter step
   shows the placeholder gesture stops. Don't ship like that; either finish US3 or have
   `onboardingSteps` return setup steps only until US3 lands.

### Incremental Delivery

1. Setup + Foundational.
2. US1 + US2 (P1).
3. US3 (P2): the full first-run tour. This is the release candidate.
4. US4 (P3): replay from Settings.
5. Polish: accessibility, performance, size, device and usability runs.

---

## Notes

- [P] tasks touch different files and don't depend on incomplete tasks.
- Commit after each task or logical group. Commit messages carry no AI attribution lines (the
  user's standing preference).
- `user.db` keeps schema version 1. If a task seems to need a migration, stop: the design says it
  doesn't.
- Don't add packages. The plan's Constitution Check rests on zero new dependencies.

## Implementation notes

- **`index` step renamed `surahIndex`**: `index` can't name an enum value in Dart (it clashes
  with `Enum.index`). data-model.md and this file use the new name; `TourTargets.index` (a
  field, not an enum value) keeps its name.
- **T018 was built together with T013, before T008 ran**: T008's sample-stopping cases need the
  real preview, so they were written against it instead of being skipped first.
- **Scrim hidden from screen readers**: T035 found that the hint scrim's tap-absorbing area was
  exposed as an unlabelled button. It is now wrapped in `ExcludeSemantics` (button_tour.dart).
- **T024 is written but not yet run**: integration tests need a device or emulator. Run it with
  the rest of T039.
