---

description: "Task list for fixing search result details"
---

# Tasks: Fix Search Result Details

**Input**: Design documents from `specs/003-fix-search-result-details/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Included. The spec requires automated tests (SC-001, SC-002, SC-006), and research S5
explains that the bug survived because the query-change path had no test.

**Organization**: Tasks are grouped by user story so each story can be built, tested and shipped
on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

## Path Conventions

Single Flutter project at the repository root: `lib/`, `test/`. Search code lives in
`lib/features/search/`; strings in `lib/app/l10n/`.

## Shared test conventions

Tests that need the real Quran data use `openTestReader()` from `test/support/harness.dart`
inside `testWidgets`, wrapping database work in `tester.runAsync(...)`, as
`test/widget/search_test.dart` does. Rendering tests also call `loadAppFonts()`. Pump with the
existing `settle(tester)` pattern (80 ms real delay + 250 ms pump, 6 rounds) so the 200 ms
debounce and the per-row word queries complete.

---

## Phase 1: Setup

**Purpose**: Confirm the starting point.

- [X] T001 Run `flutter analyze` and `flutter test test/widget/search_test.dart test/unit/arabic_normalizer_test.dart` from the repository root and confirm both pass before any change (baseline).

---

## Phase 2: Foundational

No foundational work: every story changes existing files in `lib/features/search/` and needs no
new shared infrastructure. User stories can start after Phase 1.

---

## Phase 3: User Story 1 - Every result shows its own ayah (Priority: P1) 🎯 MVP

**Goal**: Each result row always shows the text of the ayah in its title, with its own highlight,
and tapping it opens that ayah (spec FR-001 to FR-005).

**Independent Test**: Search «الرحمن الرحيم», then replace it with «قل هو الله احد». The single
row is titled «سورة الإخلاص، الآية ١» and shows «قُلْ هُوَ ٱللَّهُ أَحَدٌ», not the basmala.

### Tests for User Story 1

> Write these first and confirm they FAIL on the current code.

- [X] T002 [US1] In `test/widget/search_test.dart`, add a `testWidgets` "rows follow the query" that opens Search in the Arabic interface and runs a sequence of at least 50 query changes made with `tester.enterText` on the search `TextField`: typing «الرحمن» one letter at a time, replacing it with «قل هو الله احد», refining «الله» → «الله ال», clearing with the clear button (`MathaniIcons.clear`) and typing «من», and similar changes. After each change and `settle`, for every visible result row: read its title `Text` (format `bookmarkTitle`: «سورة {name}، الآية {n}») and its `RichText` body, look up the expected Uthmani words with `reader.quran.wordsOf(AyahRef(surah, ayah))` (skip `isAyahEnd` words), and assert the body's plain text equals those words joined as the row builds them (`'${w.text} '` each). To find rows reliably, first add `key: ValueKey('search-row-${ayah.id}')` in T004 and locate rows with `find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('search-row-'))`; until T004 lands, the test is expected to fail. Include the exact reproduction: «الرحمن الرحيم» then «قل هو الله احد» → one row whose title is «سورة الإخلاص، الآية ١» and whose body contains «قُلْ».
- [X] T003 [US1] In `test/widget/search_test.dart`, add a `testWidgets` "tap opens the shown ayah": search «الرحمن الرحيم», then «قل هو الله احد», tap the only row, `settle`, and assert `reader.anchor == const AyahRef(112, 1)`. Also assert that results from an older query are never shown: enter «الرحمن», then immediately (before `settle`) enter «قل هو الله احد», `settle`, and assert the only visible title is «سورة الإخلاص، الآية ١» (FR-005).

### Implementation for User Story 1

- [X] T004 [US1] In `lib/features/search/search_screen.dart`, give each result row an identity tied to its ayah: in `ListView.builder`'s `itemBuilder`, build `_ResultRow(key: ValueKey('search-row-${_results.hits[i].ayah.id}'), hit: _results.hits[i])` (research S1). Keep `_ResultRow`'s constructor accepting `super.key`.
- [X] T005 [US1] In `lib/features/search/search_screen.dart`, make `_ResultRowState` safe against late replies: remember the `AyahRef` the words were requested for, and in the `wordsOf(...).then` callback only `setState` if `mounted` and that ref still equals `widget.hit.ayah.ref`. While `_words` is null, keep the existing neutral `SizedBox(height: 38)` placeholder, never another ayah's text (FR-004).
- [X] T006 [US1] Run `flutter test test/widget/search_test.dart` and confirm T002 and T003 now pass, along with the existing search test.

**Checkpoint**: The wrong-ayah bug is fixed and covered. This can ship on its own.

---

## Phase 4: User Story 2 - A count readers can trust (Priority: P2)

**Goal**: The summary states the number of ayat (equal to the rows) and the number of
occurrences, with no overlap double-counting and correct plurals (spec FR-006,
[contracts/search-screen.md](./contracts/search-screen.md)).

**Independent Test**: Search «الله»: the summary reads «… موضعًا في … آية», and the number of ayat
equals the rows. Search «الرحمن الرحيم»: the summary reads «٦ آيات» only.

### Tests for User Story 2

- [X] T007 [P] [US2] Create `test/unit/search_index_test.dart` with a `testWidgets` group "counts" that loads `SearchIndex.load(reader.quran)` inside `tester.runAsync` and, for the queries «الله», «من», «الرحمن الرحيم», «ذلك» and «الصلاة», asserts the data-model invariants: `results.ayahCount == results.hits.length`; `results.occurrences == results.hits.fold(0, (s, h) => s + h.occurrences)`; `results.occurrences >= results.ayahCount`; every `hit.occurrences >= 1`; every id in `hit.matchedWordIds` is within `hit.ayah.firstWordId..hit.ayah.lastWordId`.
- [X] T008 [P] [US2] In `test/widget/search_test.dart`, add a `testWidgets` "summary" that searches in Arabic and checks the summary text: «الرحمن الرحيم» shows «٦ آيات»; «الله» shows text matching `RegExp(r'^[٠-٩]+ (موضعًا|موضع|مواضع) في [٠-٩]+ (آية|آيات)$')` (the noun form depends on the last two digits; research S4). Then switch to English (`LanguagePref.en`) and check «الرحمن الرحيم» shows "6 ayat" and «الله» matches `RegExp(r'^[\d,]+ occurrences in [\d,]+ ayat$')`. Check "No results." / «لا توجد نتائج.» for «زززز» is unchanged.

### Implementation for User Story 2

- [X] T009 [US2] In `lib/features/search/search_index.dart`, extend `SearchHit` with `final int occurrences` ("matches in this ayah; ≥ 1; one per starting searchable word") and add to `SearchResults` a getter `int get ayahCount => hits.length`. In the current substring scan, count non-overlapping matches only: advance with `text.indexOf(q, at + q.length)` instead of `at + 1`, and pass each ayah's match count to `SearchHit`. Keep `SearchResults.occurrences` as the sum of `hit.occurrences`.
- [X] T010 [P] [US2] In `lib/app/l10n/app_ar.arb`, remove `searchResultCount` and add:
  - `"searchAyatCount": "{ayat, plural, =1{آية واحدة} =2{آيتان} few{{ayatShown} آيات} many{{ayatShown} آية} other{{ayatShown} آية}}"`
  - `"searchSummary": "{occurrences, plural, =1{موضع واحد} =2{موضعان} few{{occurrencesShown} مواضع} many{{occurrencesShown} موضعًا} other{{occurrencesShown} موضع}} في {ayat, plural, =1{آية واحدة} =2{آيتين} few{{ayatShown} آيات} many{{ayatShown} آية} other{{ayatShown} آية}}"`

  (after «في» the dual is genitive, «آيتين»; plural table in research S4).
- [X] T011 [P] [US2] In `lib/app/l10n/app_en.arb`, remove `searchResultCount` and its `@searchResultCount` metadata and add `"searchAyatCount": "{ayat, plural, =1{1 ayah} other{{ayatShown} ayat}}"` and `"searchSummary": "{occurrences, plural, =1{1 occurrence} other{{occurrencesShown} occurrences}} in {ayat, plural, =1{1 ayah} other{{ayatShown} ayat}}"`, with `@searchAyatCount` placeholders `ayat` (int), `ayatShown` (String) and `@searchSummary` placeholders `occurrences` (int), `occurrencesShown` (String), `ayat` (int), `ayatShown` (String). Regenerate with `flutter gen-l10n`.
- [X] T012 [US2] In `lib/features/search/search_screen.dart`, replace the `searchResultCount` call with: `searchNoResults` when `hits` is empty; `l10n.searchAyatCount(ayahCount, formatNumber(ayahCount, locale))` when `occurrences == ayahCount`; otherwise `l10n.searchSummary(occurrences, formatNumber(occurrences, locale), ayahCount, formatNumber(ayahCount, locale))`. Keep the `Semantics(liveRegion: true)` wrapper and the caption style.
- [X] T013 [US2] Run `flutter test test/unit/search_index_test.dart test/widget/search_test.dart` and confirm T007 and T008 pass.

**Checkpoint**: Stories 1 and 2 work. The summary agrees with the list.

---

## Phase 5: User Story 3 - Highlights show exactly what matched (Priority: P3)

**Goal**: Replace the substring scan with the matching rule in
[contracts/search-matching.md](./contracts/search-matching.md): matches start at a word's
beginning after optional attached prefixes, may end inside the last word, and only matched words
are highlighted (spec FR-007).

**Independent Test**: «من» finds «فمن» and «منهم» but not «المؤمنين»; «لله» does not find «الله»;
«يا ايها الذين امنوا» gives 89 ayat.

### Tests for User Story 3

- [X] T014 [P] [US3] Create `test/unit/search_stems_test.dart` (pure `test`, no database) for a top-level function `List<String> searchStems(String word)` exported from `lib/features/search/search_index.dart`. Assert, from the contract: `searchStems('والله')` contains «الله» and not «له»; `searchStems('الله')` is exactly [«الله»]; `searchStems('لله')` is exactly [«لله»]; `searchStems('ولله')` contains «لله» and not «له»; `searchStems('بالله')` contains «الله»; `searchStems('للمتقين')` contains «المتقين» and «متقين»; `searchStems('المؤمنين')` (normalised «المومنين») contains «مومنين» and nothing starting with «من»; `searchStems('لا')` is exactly [«لا»] (2-letter minimum); `searchStems('برحمته')` contains «رحمته»; `searchStems('ولهم')` contains «لهم».
- [X] T015 [US3] In `test/unit/search_index_test.dart`, add a group "matching rule" over the real corpus with every example of the contract table: «من» finds an ayah containing «فمن» and one containing «منهم» and does not highlight any word whose normalised form is «المومنين»; «الله» finds ayat with «والله», «بالله» and «اللهم»; «لله» highlights no word whose normalised form is «الله»; «له» highlights no «الله» or «لله»; «رحم» highlights «الرحمن» in 1:1; «المتقين» and «متقين» both find 2:2 («للمتقين»); «يا ايها الذين امنوا» has `ayahCount == 89`; «قل هو الله احد» has exactly one hit, 112:1; «ال» finds words starting with «ال». Add the regression counts (ayat / occurrences): «من» 2,582 / 4,075; «يا ايها الذين امنوا» 89 / 89; «الرحمن الرحيم» 6 / 6; «المتقين» 43 / 43; and «الله» within ±15 of 1,737 / 2,547. If the first correct run differs only on «الله» or «من», record the new numbers in the contract (see T020). Also assert each query returns in under 100 ms (`Stopwatch`) after the index is loaded.

### Implementation for User Story 3

- [X] T016 [US3] In `lib/features/search/search_index.dart`, add the top-level `List<String> searchStems(String word)` implementing the contract's stem rules exactly: the word itself; for each prefix in the order `وال فال بال كال ولل فلل وب وك ول فب فك فل ال لل و ف ب ك ل` that the word starts with and that leaves at least 2 letters, the remainder; for a prefix ending in «لل», also «ال» + remainder; and the Allah rule: if the word is «الله» or «اللهم» optionally preceded by «و», «ف» or «ب», or is «لله», «ولله» or «فلله», strip only the leading «و», «ف» or «ب» (giving «الله» or «اللهم») and nothing else. Return distinct values with the word itself first.
- [X] T017 [US3] In `lib/features/search/search_index.dart`, build searchable words in `SearchIndex.load`: for each ayah, walk its word ids in order, take each word's search range from `SearchCorpus.offsetOfWord` (the last word ends at the text length), split that substring on spaces, and for every non-empty token store its Uthmani `wordId` and `searchStems(token)`. Ayah-end words yield no tokens. Keep this in private lists on `SearchIndex` (one list of `(int wordId, List<String> stems)` per ayah); do not change `SearchCorpus` or `quran.db`.
- [X] T018 [US3] In `lib/features/search/search_index.dart`, replace the substring scan in `search`: normalise the query with `normalizeArabic`, split on spaces into tokens; for each ayah and each start index *i*, the match succeeds when for every *k < n−1* some stem of token *i+k* equals token *k*, and some stem of token *i+n−1* starts with the last token. Each successful *i* adds 1 to `hit.occurrences` and adds the word ids of tokens *i…i+n−1* to `matchedWordIds`. Keep hits in Mushaf order and keep returning `SearchResults.empty` for an empty normalised query. Remove `_addWordsInRange`, which is no longer used. Update the class doc comment to describe the new rule and link to the contract.
- [X] T019 [US3] Run `flutter test test/unit/search_stems_test.dart test/unit/search_index_test.dart test/widget/search_test.dart` and confirm all pass, including T007's invariants under the new rule.

**Checkpoint**: All three stories work. Matching, counts and highlights follow the contract.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T020 [P] Update the regression-count table in `specs/003-fix-search-result-details/contracts/search-matching.md` with the counts measured by T015 (replace the ≈ values for «الله»), and in `specs/003-fix-search-result-details/contracts/search-screen.md` replace the example numbers in the summary row with the measured «الله» counts.
- [X] T021 [P] Update the doc comment of `SearchScreen` in `lib/features/search/search_screen.dart` to say results show the number of ayat and occurrences, and confirm no reference to `searchResultCount` remains anywhere in `lib/` or `test/`.
- [ ] T022 Measure stem building time: in `test/unit/search_index_test.dart`, time `SearchIndex.load` and print it; if it exceeds 150 ms in profile on the reference Android phone (quickstart performance gate), note it in `specs/003-fix-search-result-details/plan.md` Risks R3 for follow-up.
- [X] T023 Run `flutter analyze` and the full `flutter test` suite; fix any failures introduced by this feature.
- [ ] T024 Run the manual scenarios 1–6 in `specs/003-fix-search-result-details/quickstart.md` on one Android and one iOS device or emulator (Constitution Principle I), in Arabic and English.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: empty.
- **User Story 1 (Phase 3)**: after Phase 1.
- **User Story 2 (Phase 4)**: after Phase 1. Independent of US1 in behaviour, but T008 and T012
  touch `search_screen.dart` and `search_test.dart`, so run after US1 when working alone.
- **User Story 3 (Phase 5)**: after US2, because T018 rewrites the scan that T009 extends and
  T015 extends the test file T007 creates.
- **Polish (Phase 6)**: after the stories you ship.

### Within Each Story

- Tests first, and confirm they fail.
- `search_index.dart` before `search_screen.dart` (US2: T009 before T012).
- Story checkpoint run (T006, T013, T019) before the next story.

### Parallel Opportunities

- US2: T007 and T008 (different test files); T010 and T011 (different `.arb` files).
- US3: T014 (pure stem test) alongside T015.
- Polish: T020 and T021.

---

## Parallel Example: User Story 2

```bash
Task: "Create counts tests in test/unit/search_index_test.dart"           # T007
Task: "Add summary widget test in test/widget/search_test.dart"           # T008
Task: "Arabic summary strings in lib/app/l10n/app_ar.arb"                # T010
Task: "English summary strings in lib/app/l10n/app_en.arb"               # T011
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. T001 baseline.
2. T002–T006: the wrong-ayah fix with tests.
3. **Stop and validate**: quickstart scenario 1 on a device. This alone fixes the reported bug
   and can ship in a patch release.

### Incremental Delivery

1. US1 → patch release (the reported bug).
2. US2 → the summary agrees with the list.
3. US3 → the new matching rule, with its regression counts.
4. Polish → docs, performance check, device run.

---

## Notes

- 24 tasks: Setup 1, US1 5, US2 7, US3 6, Polish 5.
- No database, dependency or build-tool changes (plan).
- Commit after each story checkpoint.
