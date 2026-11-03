# Research: Mutashabihat (Similar Ayat)

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-11-03

The spec has no open questions (Clarifications, 2026-11-03). This file records the design choices
and why they were made.

## R1. The content file: one Markdown file, shipped as it is

**Decision**: The owner edits `assets/mutashabihat/mutashabihat.md`. The app bundles this exact
file and reads it at startup. Each group is a `## ` heading listing its ayat, followed by the
explanation. The format is in [contracts/content-file.md](./contracts/content-file.md).

```markdown
## 2:35 7:19 | آدم وزوجه في الجنة
في البقرة «وَكُلَا مِنْهَا رَغَدًا» وفي الأعراف «فَكُلَا» بلا «رَغَدًا» ...

الفقرة الثانية ...
```

**Rationale**:
- Arabic paragraphs are typed as they should appear. No quoting, escaping or `\n`.
- One file is both what the owner edits and what ships. Nothing is generated, so the two can never
  disagree.
- The file reads well in any editor and on GitHub, and git keeps its history (spec Assumptions:
  "One owner").
- Parsing it takes about 60 lines of plain Dart. No new package (Principle IV).
- The text after `|` is a note for the owner only, to find groups later. The app does not show it.

**Alternatives considered**:
- *JSON*: every explanation would be one escaped string. Easy to break, hard to read.
- *YAML*: readable, but needs the `yaml` package at runtime.
- *A new table in `quran.db`*: needs a database rebuild, a new `quran.version` and a reinstall of
  the database on every phone for each wording fix. It also ties the owner's edits to the Quran
  data pipeline.
- *A source file plus a generated asset*: two files to keep in step for no gain at this size.

## R2. The check before a release

**Decision**: The parser and the checks live in one plain-Dart file,
`lib/features/mutashabihat/mutashabihat_content.dart`. It imports only `lib/data/models.dart`,
which has no Flutter imports. It is used three ways:

1. **In the app**: groups with errors are skipped, so a bad edit can never crash the reader
   (FR-019).
2. **`dart run tool/check_mutashabihat.dart`**: prints every problem with its line number and
   group, and exits with code 1 if there is one. It runs:
   - in `ci.yml`, next to `verify_quran.dart`;
   - in `ios-release.yml` before `flutter build ipa`;
   - in `tool/web_deploy.mjs` `prepare()`, which stops the deploy if it fails;
   - in the `docs/release.md` checklist, before the Android `flutter build appbundle`.
3. **`test/unit/mutashabihat_content_test.dart`**: tests the parser rules and checks that the
   shipped file has no errors, so `flutter test` fails on a bad edit.

The number of ayat in each surah comes from a constant list of 114 numbers in the same file, so
the tool works without opening `quran.db`. A test checks the list against `quran.db` (through the
existing `openTestReader` harness).

**Rationale**: FR-016 asks that no release can be built while the check fails. Android and web
are built on the owner's machine and iOS in CI, so the check has to sit in each of those paths.
`flutter test` alone would not cover the local builds.

**Alternatives considered**: a `build_runner` step (a new dependency and a slower build); a check
only in CI (local Android and web builds would skip it).

## R3. Loading the content

**Decision**: `main.dart` loads and parses the file in parallel with the two databases:
`(QuranRepository.open(), UserRepository.open(), loadMutashabihat()).wait`. On the web the
databases open one after the other, and `loadMutashabihat()` runs in parallel with both. The
result is a `Mutashabihat` object held by `ReaderController` as `similar`. If the file is missing
or cannot be read, `load()` returns an empty object and the reader works as before (FR-019).

**Rationale**:
- The colour has to be there on the first page shown. Loading after the first frame would make
  the colour appear a moment after the page.
- Reading and parsing a file this size takes a few milliseconds. The database opens take longer,
  so cold start does not change. Quickstart Q1 measures it.
- Size guide: about 1 KB per group. 1,000 groups is about 1 MB of text and should parse in under
  15 ms on the Galaxy A15. If the file grows past 1 MB, measure again, and if needed load only the
  list of linked ayat first.

**Alternatives considered**: loading on the first long-press (no colour until then; fails SC-003);
an isolate (more than this needs).

## R4. The mutashabih colour

**Decision**: A new derived token `SemanticColors.similar`, written like `recited` and `hint`
("Derived for specs/010, not yet in the brand guide"):

| Theme | Value | Contrast with page | Notes |
| --- | --- | --- | --- |
| Day | `#7A4E12` (deep gold-brown) | ≈ 6.0:1 on `#F2EADD` | Warm, so it stands apart from the navy text `#183159`. Darker and more saturated than `accentInk` `#755728`. |
| Night | `#E2B866` (bright gold) | ≈ 9.3:1 on `#0E1A2E` | More saturated than the cream text `#EDE4D3`. |

A unit test (`test/unit/similar_colour_test.dart`, like `recited_colour_test.dart`) requires:
- at least 4.5:1 contrast with the page in both themes;
- a clear hue difference from `ink`, `accentInk`, `hint` and `mistake`.

The owner checks the values on real phones in quickstart Q2 and may adjust them. The test keeps
any new value within the rules.

The colour is a text colour. Selection, the jump highlight and the recitation highlight are drawn
behind the words, so a coloured ayah keeps its colour while highlighted (spec US2 scenario 3).

**Not during memorization**: while a memorization session is active, no ayah is coloured, on any
page. The session already tints the end mark of the expected ayah (`accentInk`), hinted words
(`hint`) and mistakes (`mistake`), and a fourth colour on the same words would blur those
signals. Hidden words are not drawn at all, so FR-003 holds either way.

**Alternatives considered**:
- *Reusing `accentInk`*: would be confused with the surah names and the memorization expected
  mark.
- *Teal*: too close to the navy text in the day theme, and it is the memorization hint colour.
- *A dot or margin mark*: not what the owner asked for. It could be added later for colour-blind
  readers if needed. Screen readers get FR-004.

## R5. Drawing the colour on the page

**Mushaf page** (`mushaf_page_renderer.dart`):
- **Input**: `MushafPageRenderer` gets `similar: Mutashabihat?` (null during memorization).
  `RenderMushafPage.update` relays out when the object is not `identical`. That happens only at
  startup and when a session starts or ends.
- **Colour at layout**: word painters are built with the `similar` colour for words of linked
  ayat, ayah-end marks included (US2 scenario 1). They do not use the per-word `saveLayer` tint
  that memorization uses: a layer per word on a page full of linked ayat could cost frames
  (Principle III).
- **Cache keys**: `_wordPainters` is keyed by word id, and a word's ayah never changes, so that
  key is enough. `_stretchedPainters` is keyed by display string, and the same string can appear
  in a linked and an unlinked ayah. Its key becomes `(linked, string)`.
- **Margin marks** (rub', sajdah) stay `accentInk`.

**Flowing layout** (`flowing_view.dart`): the ayah's `TextSpan` gets
`style: TextStyle(color: colors.similar)` when the ayah is linked and no session is active. The
existing background colour for selection, jump and recitation is kept.

**Alternatives considered**: the `saveLayer` tint (simpler, but slower with many linked words);
a separate paint pass over linked words (draws every linked word twice).

## R6. The overlay

**Decision**: `showSimilarSheet(context, ref)` in `lib/features/mutashabihat/similar_sheet.dart`:
- **Sheet**: `showModalBottomSheet` with `isScrollControlled: true`, `showDragHandle: true` and
  `useSafeArea: true`, taking 92% of the available height. Back, swipe down and the close button
  all close it (FR-010). The long-press selection is cleared on close, as the actions sheet
  already does.
- **Layout**: a header (title «المتشابه», the group switcher when there is more than one group,
  close button), then a `Column` with `Expanded(flex: 2)` for the ayat and `Expanded(flex: 1)`
  for the explanation, split by a divider. Each part is its own `ListView` /
  `SingleChildScrollView`, so they scroll independently (FR-008), including at the largest text
  sizes.
- **Ayat**: the pressed ayah comes first, with a «هذه الآية» label and a `selected` background.
  The rest follow in Mushaf order (FR-006). Each is a card with `flowingAyahText` in
  `flowingTextStyle` at the reader's `flowFontSize`, and the reference «البقرة ٣٥» in `caption`
  style. Words come from `quran.wordsOf`, the same text as the flowing layout. The ayat are drawn
  in normal ink, not the mutashabih colour: here every ayah is linked.
- **Tapping another ayah**: pops the sheet and calls `reader.jumpTo(ref)`. Both layouts already
  follow `jumpSerial` and show the 1.5 s highlight (FR-009). Tapping the pressed ayah does
  nothing.
- **Explanation**: `TypeScale.body` text in `ink`, right to left. Paragraphs are split on blank
  lines and separated by `Space.s3` (FR-007).
- **Several groups** (FR-011): a row of `ChoiceChip`s «١» «٢» … above the content, in file
  order. Choosing one swaps both parts. With one group the row is not shown.

**Rationale**: the bottom sheet is how the app already shows ayah actions, the reciter list and
the memorization range. Back, drag and safe areas behave the same on iOS, Android and web.

**Alternatives considered**: a full-screen route (loses the "overlay over the page" feel and the
swipe down); `DraggableScrollableSheet` (its resizing would break the fixed 2:1 split).

## R7. The action in the long-press sheet

**Decision**: `_AyahActionsSheet` adds a `ListTile` «عرض المتشابه» / "Show similar ayat" when
`reader.similar.isLinked(ayah)`. It goes first, before play, because it is the reason the ayah is
coloured. The icon is Lucide `git-compare`, added to `MathaniIcons` with its code point from
lucide-static 1.48.0. Release builds tree-shake the font, so one glyph adds about 1 KB.

Long-press and right-click (web, specs/008 FR-009) already open this sheet in both layouts. The
memorization range already has no actions. Nothing else changes.

## R8. Screen readers (FR-004)

- **Flowing layout**: a linked ayah's span is split in two. The words keep their text. The end
  marker becomes its own child span with `semanticsLabel` «الآية ٣٥، لها متشابه» / "Ayah 35, has
  similar ayat". The visible text does not change, and unlinked ayat are not touched.
- **Mushaf page**: the page is one semantics node with a page label. When the page has linked
  ayat, the label adds «فيها متشابه: الآيات ٣٥، ٣٦» / "Similar ayat on this page: 35, 36".
  Screen-reader users who want to open the overlay use the flowing layout, which has per-ayah
  focus and actions.
- **Overlay**: the pressed ayah's card is announced with «هذه الآية». Each other card is a
  button: "<reference>, open in the Mushaf".

## R9. Web

- The asset is fetched once and cached by the existing service worker under `assets/`. After the
  first visit it works offline (FR-013), like the page fonts.
- `asset-hashes.json` already covers every file under `assets/`. When the file changes, readers
  get the new copy on their next visit after a deploy.
- Opening the actions with a right-click is already supported.

## R10. Size and performance

- **Size**:
  - Starting content: a few KB.
  - Expected later: up to about 1 MB of text. Store packages compress it to well under that.
  - Code: about 15 KB. One icon glyph.
  - Anything over 1 MB of growth is called out in review (Principle IV).
- **Performance**:
  - No work at startup beyond the parallel load (R3).
  - Colour costs nothing per frame (R5).
  - The overlay builds at most one group's ayat. The largest groups are expected to be about 20
    ayat, laid out in a lazy `ListView`.
  - SC-001 (overlay within 1 s, tap feedback within 100 ms) is checked in quickstart Q3.
