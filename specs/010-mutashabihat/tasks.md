---

description: "Tasks for Mutashabihat (Similar Ayat)"
---

# Tasks: Mutashabihat (Similar Ayat)

**Input**: Design documents from `specs/010-mutashabihat/`. Read these before starting a phase:
- [plan.md](./plan.md)
- [spec.md](./spec.md)
- [research.md](./research.md)
- [data-model.md](./data-model.md)
- [contracts/content-file.md](./contracts/content-file.md)
- [contracts/mutashabihat-ui.md](./contracts/mutashabihat-ui.md)
- [quickstart.md](./quickstart.md)

**Prerequisites**: plan.md and spec.md (required).

**Tests**: plan.md (Technical Context › Testing) lists the automated tests, so test tasks are
included. They cover:
- the parser and checks;
- the ayah-count table against `quran.db`;
- the colour rules;
- the renderer colouring;
- the actions sheet;
- the overlay.

Device checks are in [quickstart.md](./quickstart.md).

**Organization**: Tasks are grouped by user story so each story can be built and tested on its
own. The two P1 stories are both needed for the first useful release.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on unfinished tasks).
- **[Story]**: US1–US4 from spec.md.

## Path Conventions

Single Flutter project:
- **Dart**: `lib/`, tests in `test/` and `integration_test/`.
- **Tools**: `tool/`.
- **CI**: `.github/workflows/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: The asset folder and the starting content file.

- [X] T001 Create `assets/mutashabihat/mutashabihat.md` with a `#` title line and an Arabic guide
  to the format before the first group: heading syntax `## <surah:ayah> <surah:ayah> … [| note]`,
  blank line = new paragraph, the note after `|` is not shown in the app, and run
  `dart run tool/check_mutashabihat.dart` before a release. Follow
  [contracts/content-file.md](./contracts/content-file.md). Add no groups: the owner writes the
  real content.
- [X] T002 Add `- assets/mutashabihat/` to the `flutter: assets:` list in `pubspec.yaml`, with a
  one-line comment `# Mutashabihat content written by the owner (specs/010).`
- [X] T003 [P] Create `test/fixtures/mutashabihat/quickstart.md` with the quickstart test groups,
  each with one or two short Arabic placeholder paragraphs marked «نص تجريبي»:
  - `## 2:35 7:19` (two paragraphs);
  - `## 2:58 7:161`;
  - `## 2:35 20:117 20:120`;
  - `## 2:282 2:283`;
  - one Ar-Rahman refrain group of every «فَبِأَيِّ ءَالَآءِ رَبِّكُمَا تُكَذِّبَانِ» ayah: 55:13, 16, 18, 21, 23,
    25, 28, 30, 32, 34, 36, 38, 40, 42, 45, 47, 49, 51, 53, 55, 57, 59, 61, 63, 65, 67, 69, 71,
    73, 75, 77.

  Tests use this file, and it is copied over the asset for the device checks only.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Parse the content and make it available to the reader. Every story needs this.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T004 Create `lib/features/mutashabihat/mutashabihat_content.dart`. It is plain Dart: import
  only `../../data/models.dart`, nothing from Flutter (research R2). It contains:
  - `const List<int> ayahCounts`: 114 entries, index = surah − 1, the Hafs counts (7, 286, 200,
    …, 6).
  - `class MutashabihGroup` with fields:
    - `final List<AyahRef> ayat`: "2 or more, all distinct, all real ayat", sorted in Mushaf order;
    - `final String explanation`: "Not empty after trimming";
    - `final int line`: the 1-based line of the `##` heading.
  - `class Mutashabihat`:
    - holds `final List<MutashabihGroup> groups` and a private `Map<AyahRef, List<int>>` index
      built in the constructor;
    - `bool isLinked(AyahRef)`;
    - `List<MutashabihGroup> groupsOf(AyahRef)`, in file order;
    - `List<AyahRef> linkedOnPage(Iterable<AyahRef>)`, distinct and in order;
    - `static const empty`.
  - `enum ContentProblemKind`: `badReference`, `noSuchAyah`, `tooFewAyat`, `emptyExplanation`,
    `duplicateAyah`.
  - `class ContentProblem`: `line`, `kind`, `heading`, `message`, and
    `bool get isError => kind != ContentProblemKind.duplicateAyah`.
  - `(Mutashabihat, List<ContentProblem>) parseMutashabihat(String text)`.

  Parser rules, from [contracts/content-file.md](./contracts/content-file.md):
  - A group starts at a line beginning `## `. `###` and deeper are explanation text. Text before
    the first group is ignored.
  - References are split on spaces, `,` and `،`.
  - Arabic-Indic digits are converted to Western digits.
  - The note after the first `|` is dropped.
  - A token that is not `S:A` is `badReference`.
  - A surah outside 1..114 or an ayah outside 1..`ayahCounts[S-1]` is `noSuchAyah`. The message
    names the surah's ayah count.
  - A repeated reference is `duplicateAyah`: a warning, and the duplicate is dropped.
  - Fewer than 2 distinct valid ayat is `tooFewAyat`.
  - An explanation empty after trimming is `emptyExplanation`.
  - In the explanation, leading and trailing blank lines are trimmed, runs of blank lines collapse
    to one, and lines are otherwise kept as written.
  - A group with any error is left out of the returned `Mutashabihat`.
  - Messages follow the contract format, e.g.
    `line 12 (## 2:35 2:300): 2:300 is not an ayah (Al-Baqarah has 286)`. Use English surah
    names from a small const list in the same file, or just the number if that adds too much.
- [X] T005 [P] Create `test/unit/mutashabihat_content_test.dart` covering each rule in T004:
  - Western and Arabic-Indic digits;
  - comma, `،` and space separators;
  - the note after `|`;
  - `###` lines kept as text;
  - preamble ignored;
  - each problem kind and its message;
  - duplicate kept once;
  - a group with an error is skipped while the others load;
  - Mushaf ordering of `ayat`;
  - paragraphs kept;
  - `groupsOf` file order;
  - `linkedOnPage`;
  - `Mutashabihat.empty`.

  Also parse `test/fixtures/mutashabihat/quickstart.md` and expect 5 groups and no problems.
- [X] T006 [P] Add a test in `test/unit/mutashabihat_content_test.dart` (in its own `group`) that
  opens the real database with `openTestReader()` from `test/support/harness.dart` and checks
  `ayahCounts[i] == reader.quran.surahList[i].ayahCount` for all 114 surahs.
- [X] T007 Create `lib/features/mutashabihat/mutashabihat_loader.dart` with
  `Future<Mutashabihat> loadMutashabihat({AssetBundle? bundle})`:
  - read `assets/mutashabihat/mutashabihat.md` with `(bundle ?? rootBundle).loadString`;
  - return `parseMutashabihat(text).$1`;
  - on any exception return `Mutashabihat.empty` and `debugPrint` the error (FR-019).
  - Do not log problems in release builds.
- [X] T008 Add `this.similar = Mutashabihat.empty` as an optional named constructor parameter and
  `final Mutashabihat similar;` field to `ReaderController` in `lib/shared/reader_state.dart`, with
  a doc comment `/// Linked ayat and their explanations (specs/010).`
- [X] T009 In `lib/main.dart` `runMathani()`, load the content in parallel with the databases
  (research R3):
  - on phones, `(QuranRepository.open(), UserRepository.open(), loadMutashabihat()).wait`;
  - on the web, start `final similar = loadMutashabihat();` before the sequential opens and await
    it after them;
  - pass `similar:` to `ReaderController`;
  - update the comment above it to mention the content file.
- [X] T010 Add an optional `Mutashabihat? similar` parameter to `openTestReader` in
  `test/support/harness.dart` and pass it to `ReaderController`, so widget tests can inject
  fixture content.

**Checkpoint**: `flutter test test/unit/mutashabihat_content_test.dart` passes. The app starts
as before (no linked ayat yet).

---

## Phase 3: User Story 1 - See the similar ayat and why they are similar (Priority: P1) 🎯 MVP

**Goal**: Long-press a linked ayah, choose «عرض المتشابه», and see the ayah, its similar ayat and
the explanation in an overlay (FR-005 to FR-010, FR-012, FR-013).

**Independent Test**: With the fixture content injected:
- long-press 7:19 and open «عرض المتشابه»;
- check 7:19 is first with «هذه الآية», then 2:35, and the explanation is in the bottom third;
- tap 2:35 and check the Mushaf jumps there;
- check an unlinked ayah has no such action.

### Tests for User Story 1

- [X] T011 [P] [US1] Create `test/widget/similar_sheet_test.dart`. Use `openTestReader(similar:
  parseMutashabihat(<fixture>).$1)` and the `pumpApp` pattern of
  `test/widget/ayah_actions_test.dart`. Tests:
  - **Order**: `showSimilarSheet` for 7:19 shows the 7:19 card first with `similarThisAyah`, then
    2:35.
  - **Explanation**: it shows both paragraphs.
  - **Split**: the ayat area is about twice the explanation's height (flex 2:1).
  - **Scrolling**: for the 31-ayah group, scrolling the ayat list reaches 55:77 while the
    explanation's scroll offset stays 0.
  - **Jump**: tapping the 2:35 card pops the sheet, `reader.highlighted == AyahRef(2, 35)`, and
    `reader.page` is 2:35's page.
  - **Pressed card**: tapping the pressed ayah's card does nothing.
  - **Closing**: the ✕ button closes the sheet and `reader.selected` is null afterwards.
  - **Long ayah**: 2:282 is fully reachable by scrolling.
  - **Text scaling**: at `textScaler: TextScaler.linear(2)` there are no overflow errors.
- [X] T012 [P] [US1] Add tests to `test/widget/ayah_actions_test.dart`, with fixture content
  injected through `openTestReader(similar: …)`:
  - long-pressing a linked ayah (7:19) in both the Mushaf and flowing layouts shows `showSimilar`
    as the first `ListTile`, and tapping it opens the overlay;
  - long-pressing an unlinked ayah (7:18) shows no `showSimilar`.

### Implementation for User Story 1

- [X] T013 [P] [US1] Add the strings from [contracts/mutashabihat-ui.md](./contracts/mutashabihat-ui.md)
  (Strings table) to `lib/app/l10n/app_ar.arb` and `lib/app/l10n/app_en.arb`:
  - plain strings: `showSimilar`, `similarTitle`, `similarThisAyah`, `similarClose`;
  - with placeholders: `similarGroup(n)`, `similarOpenAyah(ref)`, `similarAyahSemantics(n)`,
    `similarOnPage(list)`, all `String`, with `@` descriptions.

  Then run `flutter gen-l10n` to regenerate `lib/app/l10n/app_localizations*.dart`.
- [X] T014 [P] [US1] Add `static const similar = IconData(0x…, fontFamily: _family); //
  git-compare` to `lib/shared/mathani_icons.dart`. Take the code point for `git-compare` from
  lucide-static 1.48.0 (`font/info.json`), and check the glyph exists in
  `assets/fonts/Lucide.ttf`. If it does not, use `layers` and note it in the comment.
- [X] T015 [US1] Create `lib/features/mutashabihat/similar_sheet.dart` with
  `Future<void> showSimilarSheet(BuildContext context, AyahRef ref)`, per research R6 and the
  contract's Overlay section.
  - **Sheet**: `showModalBottomSheet(isScrollControlled: true, useSafeArea: true,
    showDragHandle: true)`. The child is a `FractionallySizedBox(heightFactor: 0.92)` on
    `surfaceRaised`.
  - **Selection**: `reader.select(ref)` before opening and `reader.select(null)` after it closes.
  - **Header**: an `Text(l10n.similarTitle)` heading with `Semantics(header: true)`, and an
    `IconButton(MathaniIcons.close, tooltip: l10n.similarClose)` at least 48 dp.
  - **Body**: a `Column` with `Expanded(flex: 2)` holding a `ListView.builder` of ayah cards,
    then a `Divider(color: colors.line)`, then `Expanded(flex: 1)` holding a
    `SingleChildScrollView` with the explanation.
  - **Group**: show `similar.groupsOf(ref).first`. US4 adds switching.
  - **Card order**: the pressed ayah first, then the group's other ayat in Mushaf order.
  - **Card text**: load words with `reader.quran.wordsOf`, render with
    `flowingAyahText(words, quran.font)` in
    `flowingTextStyle(colors, reader.preferences.flowFontSize.toDouble())`, `TextDirection.rtl`.
  - **Card reference**: «<surah nameAr> <formatNumber(ayah)>» (English: `nameTranslit`) in
    `TypeScale.caption` / `inkMuted`.
  - **Pressed card**: background `colors.selected`, label `similarThisAyah`, not tappable.
  - **Other cards**: `colors.surface`, wrapped in `InkWell` with
    `Semantics(button: true, label: l10n.similarOpenAyah(reference))`. A tap does
    `Navigator.pop` then `reader.jumpTo(other)`.
  - **Explanation**: split on blank lines into paragraphs, each a `Text` in `TypeScale.body` /
    `ink`, `TextDirection.rtl`, `Space.s3` between them and `Space.s4` side padding.
  - **Esc**: closes the sheet on the web (`Shortcuts`/`CallbackShortcuts` with
    `LogicalKeyboardKey.escape`, if the modal route does not already handle it).
- [X] T016 [US1] In `lib/features/reader/ayah_actions.dart` `_AyahActionsSheet.build`, add a first
  `ListTile` when `reader.similar.isLinked(ayah)`:
  - `leading: Icon(MathaniIcons.similar)`, `title: Text(l10n.showSimilar)`;
  - `onTap`: `Navigator.of(context).pop()` then `showSimilarSheet(screen, ayah)`.

  Update the doc comment of `showAyahActions` to list the new action (specs/010). The selection
  is cleared by `showAyahActions` when its sheet closes, and set again by `showSimilarSheet`.
  Check there is no flicker in the T012 test.

**Checkpoint**: US1 works with injected content. T011 and T012 pass.

---

## Phase 4: User Story 2 - Know where a mutashabih is while reading (Priority: P1)

**Goal**: Linked ayat are drawn in the `similar` colour in both layouts and both themes. There is
no colour during memorization, and screen readers announce linked ayat (FR-001 to FR-004).

**Independent Test**: With fixture content, open 2:35's page in the Mushaf and flowing layouts,
in day and night themes. Only linked ayat are coloured. Starting a memorization session removes
the colour.

### Tests for User Story 2

- [X] T017 [P] [US2] Create `test/unit/similar_colour_test.dart`, modelled on
  `test/unit/recited_colour_test.dart`:
  - `SemanticColors.similar` has at least 4.5:1 contrast with `SemanticColors.surface` in day and
    night;
  - its hue differs by at least 25° from `ink`, `accentInk`, `hint` and `mistake` in each theme,
    or for the near-neutral `ink`, its saturation differs by at least 0.25 (HSL).
- [X] T018 [P] [US2] Add tests to `test/widget/mushaf_typesetting_test.dart`, with fixture content
  injected:
  - on 2:35's page, the `RenderMushafPage` word painters for 2:35's words, including its
    ayah-end word, use `palette.similar`;
  - 2:34's words use `palette.ink`;
  - with `similar: null` (memorization), no word uses `palette.similar`;
  - add a `@visibleForTesting Color colorOfWord(int wordId)` on `RenderMushafPage` if needed.
- [X] T019 [P] [US2] Add a flowing-layout test, in `test/widget/mushaf_typesetting_test.dart` or a
  new `test/widget/similar_flowing_test.dart`:
  - 2:35's `TextSpan` has `color == colors.similar` and 2:34's does not;
  - the semantics tree contains `similarAyahSemantics` for 2:35;
  - right-click / long-press on 2:36 (just after a split span) still resolves to 2:36, which
    checks the text-offset bookkeeping.

### Implementation for User Story 2

- [X] T020 [P] [US2] In `lib/app/theme/tokens.dart`, add after `mistake`:
  - the comment `// Derived for specs/010 (not yet in the brand guide): text of an ayah that has
    similar ayat. Warm, so it reads apart from the navy and cream text; contrast checked in
    test/unit/similar_colour_test.dart.`
  - `static const similar = ThemedColor(Color(0xFF7A4E12), Color(0xFFE2B866));`
- [X] T021 [US2] In `lib/app/theme/app_theme.dart`, add `required this.similar` /
  `final Color similar; // an ayah with similar ayat (specs/010)` to `MathaniColors`, and set it
  from `SemanticColors.similar.of(b)`, alongside `hint` and `mistake`. Update `copyWith`/`lerp`
  if the class has them.
- [X] T022 [US2] In `lib/features/reader/mushaf_page_renderer.dart`:
  - **Palette**: add `this.similar = const Color(0x00000000)` to `MushafPalette`, including `==`
    and `hashCode`.
  - **Config**: add `final Mutashabihat? similar;` to `MushafPageRenderer`, passed to the render
    object. In `RenderMushafPage.update`, add `!identical(old.similar, next.similar)` to the
    relayout condition, so painters are disposed and rebuilt.
  - **Layout**: in `performLayout`, build a second `TextStyle` with
    `color: _config.palette.similar`. Choose it per word when
    `_config.similar?.isLinked(w.ref) ?? false` for `_wordPainters.putIfAbsent(w.id, …)`.
  - **Stretched painters**: change the `_stretchedPainters` key from `String` to
    `(bool, String)` (linked, display string), and pass the matching style wherever stretched
    painters are created.
  - **No layers**: do not use `saveLayer` for this colour (research R5). Margin marks stay
    `accentInk`.
- [X] T023 [US2] In `lib/features/reader/mushaf_view.dart`:
  - pass `similar: colors.similar` to `MushafPalette`;
  - pass `similar: memorization != null && memorization.active ? null : reader.similar` to
    `MushafPageRenderer`;
  - extend the page `Semantics` label: when
    `reader.similar.linkedOnPage(<refs of the page's words>)` is not empty and no session is
    active, append `'. ' + l10n.similarOnPage(<ayah numbers joined by '، ' or ', ', each through
    formatNumber>)`. Take the refs from `page.lines` words.
- [X] T024 [US2] In `lib/features/reader/flowing_view.dart`, in the non-memorization branch where
  the ayah `TextSpan` is built, when `reader.similar.isLinked(ayah.ref)` and no session is active:
  - **Spans**: build a `TextSpan` with `style: TextStyle(color: colors.similar, backgroundColor:
    background)` and two children: the words text, and the end-marker text with
    `semanticsLabel: l10n.similarAyahSemantics(formatNumber(ayah.ayah, locale))`.
  - **Same text**: the concatenated text must equal `flowingAyahText(words, quran.font)`, so
    `length += s.length` and the right-click offset mapping stay correct.
  - **Recognizer**: keep the long-press recognizer on both children, or on the parent if
    supported.
  - **Unlinked ayat**: unchanged.

**Checkpoint**: US1 and US2 together form the first useful release, with fixture or real content.
T017–T019 pass.

---

## Phase 5: User Story 3 - Owner links ayat and writes the explanation (Priority: P2)

**Goal**: The owner edits `assets/mutashabihat/mutashabihat.md`, and a check stops any release
with a bad reference, a group of fewer than two ayat, or an empty explanation (FR-014 to FR-017).

**Independent Test**: Add `## 2:35 2:300` to the file:
- `dart run tool/check_mutashabihat.dart` exits 1 naming the line and `2:300`;
- `flutter test` fails;
- `node --use-system-ca tool/web_deploy.mjs --dry-run` stops in `prepare()`.

Remove the line and all three pass.

### Tests for User Story 3

- [X] T025 [P] [US3] Add a test to `test/unit/mutashabihat_content_test.dart`: read
  `assets/mutashabihat/mutashabihat.md` from disk (`File`), parse it, and
  `expect(problems.where((p) => p.isError), isEmpty)`, so a bad edit fails `flutter test`.

### Implementation for User Story 3

- [X] T026 [US3] Create `tool/check_mutashabihat.dart` (`dart run`, no Flutter). It:
  - imports `package:mathani/features/mutashabihat/mutashabihat_content.dart`;
  - reads `assets/mutashabihat/mutashabihat.md` relative to the repository root, or a path given
    as the first argument;
  - prints each problem's `message`, prefixed `error:` or `warning:`;
  - prints `mutashabihat.md: N groups, M linked ayat, OK` when there are no errors;
  - exits with code 1 if any error.

  Add a short entry to `tool/README.md`.
- [X] T027 [P] [US3] In `.github/workflows/ci.yml`, in the analyze/test job after "Verify Quran
  text", add a step `- name: Check Mutashabihat content` /
  `run: dart run tool/check_mutashabihat.dart`.
- [X] T028 [P] [US3] In `.github/workflows/ios-release.yml`, add the same step after
  `flutter pub get` and before "Build signed .ipa".
- [X] T029 [P] [US3] In `tool/web_deploy.mjs` `prepare()`, run
  `execSync('dart run tool/check_mutashabihat.dart', { cwd: repo, stdio: 'inherit' })` inside a
  try/catch that calls `fail('Mutashabihat content has errors: fix assets/mutashabihat/mutashabihat.md')`.
- [X] T030 [P] [US3] In `docs/release.md`:
  - add to "Release builds", before the Android command:
    `dart run tool/check_mutashabihat.dart   # must print OK (specs/010)`;
  - add a "Release checklist" item: `` `dart run tool/check_mutashabihat.dart` prints OK, and
    `assets/mutashabihat/mutashabihat.md` holds only the owner's real groups (no quickstart
    fixtures). ``

**Checkpoint**: The gate works in CI, the iOS release and the web deploy. The owner can add
groups.

---

## Phase 6: User Story 4 - An ayah in more than one group (Priority: P3)

**Goal**: When an ayah is in several groups, the overlay lets the reader switch between them
(FR-011).

**Independent Test**: With fixture content:
- the overlay on 2:35 shows chips «١» «٢», and each shows its own ayat and explanation;
- the overlay on 20:117 shows no chips.

### Tests for User Story 4

- [X] T031 [P] [US4] Add tests to `test/widget/similar_sheet_test.dart`:
  - on 2:35, two `ChoiceChip`s; the first group shows 7:19 and its explanation;
  - selecting the second shows 20:117 and 20:120, the second explanation, and both scroll
    positions back at 0;
  - on 20:117, no `ChoiceChip`.

### Implementation for User Story 4

- [X] T032 [US4] In `lib/features/mutashabihat/similar_sheet.dart`, make the sheet body a
  `StatefulWidget` holding the selected group index.
  - When `groupsOf(ref).length > 1`, show a `Wrap` of `ChoiceChip`s under the header, labelled
    `formatNumber(i + 1)`, with `Semantics` label `l10n.similarGroup(...)`.
  - Choosing a chip swaps both parts and resets their scroll positions: give each part a
    `ScrollController` and `jumpTo(0)`, or key the parts by group index.

**Checkpoint**: All four stories work.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Device checks, performance, size and records.

- [X] T033 Run `flutter analyze` and `flutter test --exclude-tags golden`. Then check whether the
  golden test (`test/widget/mushaf_page_renderer_golden_test.dart`) still matches. With an empty
  content file the goldens must not change. If they do, find out why before updating them.
- [ ] T034 Copy `test/fixtures/mutashabihat/quickstart.md` over
  `assets/mutashabihat/mutashabihat.md` locally (do not commit). Run
  [quickstart.md](./quickstart.md) Q1–Q4, Q6 and Q7 on the Galaxy A15, the iPhone SE (2nd gen)
  and a desktop browser. Record results and the cold-start numbers in
  `specs/010-mutashabihat/validation/device-checks.md`. The owner confirms or adjusts the colour
  values in Q2 step 2; if adjusted, update `lib/app/theme/tokens.dart` and re-run T017. Restore
  the real content file afterwards.
- [ ] T035 Run the CI size check (quickstart Q8) and add the size delta to the next row of the
  release log in `docs/release.md`.
- [ ] T036 [P] Owner: time adding one real group (quickstart Q5, SC-005) and note it in
  `specs/010-mutashabihat/validation/device-checks.md`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: needs T001–T003. Blocks all stories.
- **US1 (Phase 3)** and **US2 (Phase 4)**: need Phase 2. They are independent of each other.
- **US3 (Phase 5)**: needs Phase 2 only (it uses the parser from T004). It can run in parallel
  with US1 and US2.
- **US4 (Phase 6)**: needs US1 (T015, the sheet).
- **Polish (Phase 7)**: needs all stories.

### Within Phases

- T004 before T005, T006, T007. T007 and T008 before T009. T008 before T010.
- US1: T013 and T014 before T015. T015 before T016.
- US2: T020 before T021. T021 before T022–T024. T022 before T023.
- US3: T026 before T027–T030.

### Parallel Opportunities

- Phase 1: T003 alongside T001 and T002.
- Phase 2: T005 and T006 alongside T007 and T008.
- After Phase 2, US1, US2 and US3 can be built side by side. They touch different files:
  - US1: `similar_sheet.dart`, `ayah_actions.dart`, arb, icons;
  - US2: tokens, theme, renderer, the two views;
  - US3: tool, workflows, docs.
- Tests within each story ([P]) can be written together.

---

## Parallel Example: User Story 2

```text
Task: "T017 Create test/unit/similar_colour_test.dart"
Task: "T018 Renderer colour tests in test/widget/mushaf_typesetting_test.dart"
Task: "T019 Flowing colour and semantics test in test/widget/similar_flowing_test.dart"
Task: "T020 Add SemanticColors.similar in lib/app/theme/tokens.dart"
```

## Parallel Example: User Story 3

```text
Task: "T027 Add the check to .github/workflows/ci.yml"
Task: "T028 Add the check to .github/workflows/ios-release.yml"
Task: "T029 Run the check in tool/web_deploy.mjs prepare()"
Task: "T030 Add the check to docs/release.md"
```

---

## Implementation Strategy

### MVP First (US1 + US2, both P1)

1. Phase 1 and Phase 2.
2. US1: the action and the overlay. Validate with injected fixture content.
3. US2: the colour. Readers can now find and open mutashabihat.
4. **Stop and validate** with quickstart Q2–Q3 on one phone.

### Incremental Delivery

1. Setup, Foundational, US1 and US2: the first useful release, once the owner has written
   content.
2. US3: the release gate. Required before any release that ships owner content (FR-016).
3. US4: switching between groups. Until then the overlay shows the ayah's first group.
4. Polish: device, performance and size checks before merge (constitution workflow).

---

## Notes

- **No placeholder content in releases**: never ship placeholder or fixture groups in
  `assets/mutashabihat/mutashabihat.md`. T030 adds a checklist item for this.
- **Existing behaviour**: do not change selection, jump or recitation highlighting, or the
  memorization session. The colour sits on top of them as described in research R4–R5.
- **Commits**: commit after each task or logical group. Commit messages carry no AI
  attribution lines (project rule).
