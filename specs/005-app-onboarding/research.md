# Research: Onboarding

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

The spec left no open questions (both were answered on 2026-10-24). This file records the design
decisions the plan rests on.

## R1. Where the onboarding lives, and how the app moves through it (FR-001, FR-005, FR-017)

**Decision**: The whole onboarding is a list of **steps**, worked out by one pure-Dart function
from the reader's state:

```text
language, theme, layout, [textSize if flowing], [reciter if there is a catalogue]   ← setup
turnPages, controls, ayahActions                                                      ← gesture stops
index, search, [player if recitations exist], settings                               ← button hints
```

A small `OnboardingController` (a `ChangeNotifier`, beside `ReaderController` and
`RecitationController`, provided by an `OnboardingScope`) holds the position in that list and
whether it is a replay. The **phase** follows from the kind of the current step: setup, gestures
or buttons. Nothing else holds tour state.

`MaterialApp.home` becomes a tiny `_Home` widget that depends on `OnboardingScope`:

- during setup and gesture stops, it shows `OnboardingScreen`;
- otherwise, it shows `ReaderScreen`. During button hints, `ReaderScreen` lays the hint overlay
  over itself.

Because `_Home` sits inside the root route and reads an `InheritedNotifier`, switching between the
two screens is an ordinary rebuild. There are no route tricks, and the system back gesture works
naturally on both platforms.

**Rationale**:
- One list makes the order, progress numbers ("3 of 7"), back, skip and the conditional steps
  (text size only for flowing, no player without recitations) a single, unit-testable function.
- The setup steps change the real preferences as the reader picks, so the whole app restyles
  live. Language and direction change because `OnboardingScreen` is inside `MaterialApp`,
  whose `locale` and `themeMode` already follow `ReaderController`.

**Alternatives considered**:
- A separate `Navigator` route per step: back and replay would need route bookkeeping, and the
  reader screen under the hints would be a second instance.
- Holding tour state in `ReaderController`: mixes transient UI state into the reading-position
  source of truth (feature 001, research R6).

## R2. Remembering the onboarding; readers updating; closing midway (FR-001–FR-003, SC-004, SC-009)

**Decision**: Add one preference, `onboardingDone` (key `onboarding_done`, `'true'`/`'false'`,
default false), in the existing `preferences` key/value table. **No schema change.**

- **Fresh install**: no row, so false, and the onboarding shows. The anchor is 1:1, so the reader
  lands on page 1 (FR-005).
- **Update from 1.3.0 or earlier**: these readers have preference rows but no `onboarding_done`,
  so they see the onboarding once (clarification Q2). Their saved choices are what each step
  preselects (FR-007). Their anchor, bookmarks and downloads are untouched, so they land where
  they stopped.
- **Closed midway**: each choice is saved the moment it is made (`ReaderController.
  updatePreferences` already writes through). `onboardingDone` is written only on finish or skip,
  so the next launch restarts at step 1 with those choices selected (edge case).
- **Finish or skip**: `onboardingDone = true` in one `updatePreferences` call. From then on,
  `_Home` shows the reader directly.

**The old controls hint goes away.** After this feature, every reader passes through the
onboarding before reaching the reader, and finishing or skipping it suppresses the hint
(FR-018). The hint could therefore never show again, so it is removed (constitution IV, "unused
code removed"). That covers the `controlsHintShown` field, its `controls_hint_shown`
read/write, the snack bar in `ReaderScreen._setControls`, and the `controlsHint` strings.

A stale `controls_hint_shown` row may remain in existing databases. It is never read and
costs a few bytes, so it is not worth a migration.

**Alternatives considered**:
- Distinguishing fresh installs from updates (for example, by the presence of a `reading_state`
  row): not needed. Q2 gives both groups the same onboarding, and the anchor already gives the
  right landing page.
- Persisting the step index to resume midway: the spec asks for a restart at step 1, which is
  simpler.

## R3. Gesture stops: how to show a gesture (Story 3 AS3–AS4, FR-016, FR-017, SC-008)

**Decision**: A `TourIllustration` widget made of a `CustomPaint`:

- a **miniature reading screen** in the chosen layout and theme, drawn as abstract text lines;
- an **animated touch dot**: a filled circle with a ripple, the usual way to depict a touch.

Per stop:

| Stop | Mushaf layout | Flowing layout |
| --- | --- | --- |
| turnPages | A page with 15 justified lines. The dot drags sideways in the same direction as `MushafView`'s right-to-left `PageView` (dragging towards the right brings the next page), and the next sheet slides in. | Ragged lines with ayah markers. The dot drags upward and the lines scroll. |
| controls | The dot taps; a header and toolbar slide in, then out on a second tap. | The header and toolbar stay put; the text explains that in the Mushaf layout a tap shows them. |
| ayahActions | The dot presses and holds on one line. That ayah fills with the `selected` colour and a small sheet rises with four labelled icons: play, bookmark, copy, share (`MathaniIcons`). | Same, on a flowing line. |

- **Colours** come from `MathaniColors`, so day and night are free.
- **Animation**: one `AnimationController` per stop, looping every 2.4 s, inside a
  `RepaintBoundary`. When `MediaQuery.disableAnimations` is set (reduce motion), it shows a
  single still frame with an arrow.
- **Screen readers**: the illustration is wrapped in `ExcludeSemantics`. The stop's text says the
  gesture (AS3).

**Rationale**:
- No image or animation assets, and no dependency. The cost is a few kilobytes of Dart
  (constitution IV, SC-008).
- It follows the theme and layout the reader just chose, which a bitmap or Lottie file could
  not do without one asset per combination.

**Alternatives considered**:
- Lottie or Rive animations: new dependency (about 1 MB with the runtime) plus assets.
- Screenshots: 2 layouts × 2 themes × 2 languages × 3 stops = 24 raster images, and they go
  stale with every UI change.
- Rendering the real `MushafView` at small scale: it brings in page loading and fonts at an odd
  scale, and the gesture would be acted on rather than shown.

## R4. Button hints over the real reading screen (FR-017, FR-017a, Story 3 AS5–AS8)

**Decision**: A custom overlay, `ButtonTour`, with no package. `ReaderScreen` wraps its
`Scaffold` in a `Stack` while the phase is buttons, and gives the toolbar a `TourTargets` set of
`GlobalKey`s: index, search, listen, settings. The recitation bar gets a key too.

- **Target**: the current step's key gives a `Rect` (via `RenderBox.localToGlobal`, read after
  layout in a post-frame callback and again on metrics change). The **player** step targets the
  Listen button, or the recitation bar while a session exists (the bar replaces Listen, as in
  specs/004).
- **Dimming**: a `CustomPainter` fills the screen with `Colors.black` at 55% opacity, with a
  rounded-rect hole 8 dp larger than the target, plus a 2 dp `focusRing` outline.
- **Callout card**: `surfaceRaised`, radius `md`. It sits above the toolbar, in thumb reach, with
  a small notch pointing at the target. It holds the title, body, "4 of 7", and Back, Skip,
  Next/Done.
- **Taps**: the overlay absorbs all pointer events except the card's buttons. Next never
  triggers the control, and the page cannot be turned by hand (FR-017a).
- **Controls stay visible**: `show = _controlsVisible || _keepControls || tourActive`, and
  immersive mode stays off.
- **No page turns under a hint**: `MushafView` and `FlowingView` skip applying a new `jumpSerial`
  while `OnboardingScope.holdsReader(context)` is true. They depend on the scope, so when the hints
  end they rebuild and apply the latest jump. A recitation keeps playing and its follow jump lands
  then (edge case).
- **Screen readers**: the reader screen underneath is wrapped in `ExcludeSemantics` and
  `BlockSemantics`, so VoiceOver and TalkBack only reach the card. The card reads as one group:
  "4 of 7. Index. Surahs, ajza and your bookmarks.", then the buttons. Focus moves to the card
  title on each step.
- **Back**: a `PopScope` maps the system back gesture to the previous step. From the first hint,
  that is the last gesture stop. In a replay, back from the first gesture stop ends the replay.

**Rationale**:
- About 200 lines with no dependency.
- Packages such as `tutorial_coach_mark` and `showcaseview` add a dependency, bring their own
  animation and styling to override, and don't handle the "hold page jumps" or semantics needs
  any better (constitution IV and V).

**Alternatives considered**:
- Hints as tooltips (`Tooltip`/`MenuAnchor`): no dimming, no "n of m", no Back or Skip, and they
  dismiss on any tap.
- Illustrated screens for the buttons too: ruled out by clarification Q1.

## R5. Reciter samples (Story 1 AS6, FR-010, FR-011, edge cases)

**Decision**: Add `previewReciter(Reciter)` and `stopPreview()` to `RecitationController`, and a
`preview` getter: null, or (reciter id, `loading` | `playing` | `unavailable`).

- **What plays**: Al-Fatiha 1:1 (the basmala as ayah 1, about 6 s). It is resolved through the
  existing `AyahFetcher` (download, then recent cache, then network), so a reader who already has
  Al-Fatiha downloaded hears it offline. It plays through the same `AudioEngine` as a
  one-item window, and the sample ends on its own (`WindowCompleted`).
- **What it does not touch**: no `RecitationSession` is created, so there is no recitation bar,
  no highlight and no follow jump. `onFirstPlay` is not called, so there are no lock-screen or
  notification controls for a 6-second sample.
- **Connection**:
  - When the reciter step opens, `DeviceChannel.networkState()` is read once. If it is `none`,
    the sample buttons are disabled and the offline note shows straight away.
  - A sample that fails with `FetchError.offline`, or doesn't start within **5 s**, becomes
    `unavailable` and shows the same note.
  - The reader can always choose a reciter.
- **Stops**: when the step changes away from `reciter`, on skip or finish
  (`OnboardingController` calls `stopPreview()`), when the app pauses
  (`RecitationController.didChangeAppLifecycleState`), and when another sample starts.
- **Guard**: `previewReciter` does nothing while a session exists. It cannot happen on the first
  run, and replays from Settings have no reciter step.

**Rationale**:
- It reuses the fetcher (integrity checks, mirror fallback, cache) and the engine (audio session,
  interruptions). The file lands in the normal 100 MB recent cache, so a first recitation of
  Al-Fatiha starts at once.
- It adds no second player.

**Alternatives considered**:
- A second `just_audio` player for samples: a duplicate audio session and interruption handling,
  and two players could talk over each other.
- Bundled sample clips: about 100 KB per reciter, and it grows with every reciter added.

## R6. Live previews on the setup steps (Story 1 AS2, AS4, AS5, FR-009)

**Decision**:
- **Language**: picking one calls `updatePreferences`. `MaterialApp` re-localizes and flips
  direction, and `OnboardingScreen` keeps its state (same widget, same position in the tree).
- **The "follow the device" option** shows the language it resolves to, using
  `MathaniApp.resolveLocale(LanguagePref.system, PlatformDispatcher.locales)`, for example
  "Device (English)" or «حسب الجهاز (العربية)» (edge case: device language neither Arabic nor
  English).
- **Theme and layout**: the whole screen restyles on selection, and a `TourIllustration`
  miniature (R3, static frame) shows the reading screen in the current theme and layout.
- **Text size** (only when flowing): a slider with the same bounds and steps as Settings (18–34),
  above Al-Fatiha 1–3 set with the flowing layout's own text style. The words are read once from
  `quran.db` when the step opens: 3 rows, under 5 ms, with a fixed-height placeholder until then,
  so the layout doesn't jump.
- **Reciter**: `quran.reciters` as cards, each with its name in the interface language (and the
  Arabic name under the English one, as in the reciter sheet), "Murattal", and a play/stop sample
  button. Picking one goes through the same path as the reciter sheet
  (`recitation.setReciter(id)`, or `updatePreferences` without recitations). The selected card is
  `reciterOrDefault(prefs.reciter)`, which covers a stored reciter that no longer exists (edge
  case).

**Rationale**: Every preview is the real app restyling itself or a miniature drawn from the same
tokens, so it can never disagree with what the reader gets (SC-003).

## R7. Replaying the tour from Settings (Story 4, FR-021, FR-022)

**Decision**: Settings gets a row under the existing options, «شاهد الجولة التعريفية مرة أخرى» /
"See the tour again".

Tapping it calls `Navigator.popUntil(isFirst)`, then `onboarding.replay()`, which starts at
`turnPages` with `replay = true`, so there are no setup steps. `_Home` shows `OnboardingScreen`
for the gesture stops, then the reader with its button hints at `reader.page`.

Finish or skip ends on the reader at the same page. The reader's anchor, bookmarks,
preferences and any recitation are untouched (`ReaderScreen` is rebuilt, and `MushafView`
reopens at `reader.page`). `onboardingDone` stays true.

**Rationale**: The button hints must sit on the real reading screen, so the replay ends there
rather than back in Settings. This was decided in the spec (Story 4, iteration 2).

## R8. Effect on tests and tools

**Decision**: Without changes, every existing widget and integration test would open on the
onboarding.

- `test/support/harness.dart` › `openTestReader({bool onboarded = true})` sets
  `onboardingDone` before building the controller. Existing tests pass unchanged.
- `integration_test/app_flow_test.dart`, `paging_perf_test.dart` and
  `store_screenshots_test.dart` build `ReaderController` themselves. They get
  `prefs.copyWith(onboardingDone: true)`.
- `app_flow_test.dart` gains a first-run pass with a fresh database that goes through the
  onboarding.
- `tool/web_preview.dart` runs `runMathani()` and shows the onboarding on a fresh in-memory
  database, which is the right preview.
- The controls-hint assertions in `test/widget/reader_page_view_test.dart` are removed with the
  hint (R2).
- Store screenshots may add one onboarding frame (the layout step). Optional; it doesn't gate
  the release.

## R9. Performance and size (FR-026, SC-006, SC-008)

**Decision**:
- **Cold start**: unchanged work before the first frame. `loadStartup` already reads every
  preference in one query, and `onboarding_done` is one more row. `OnboardingScreen`'s first
  frame is lighter than the reader's: no page layout and no Quran fonts, only the UI font and
  one `CustomPaint`. It is measured with the existing cold-start check on the Galaxy A15 and
  iPhone SE (2nd gen).
- **Step changes**: `PageView.animateToPage` over 250 ms. The button state changes in the same
  frame as the tap (≤ 100 ms).
- **Hint overlay**: one `CustomPaint`, repainted only on step change.
- **Size**: no dependencies and no assets. The estimate is about 25–40 KB of compiled Dart plus
  37 strings in each language, far under the 1 MB call-out threshold. `tool/size_check.dart`
  confirms it.
