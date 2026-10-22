# Research: Fix Search Result Details

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-22

All measurements below were taken on 2026-10-22 with the real `quran.db`, in a throwaway test on
the development machine (debug mode, so release builds on a phone are expected to be similar or
faster).

## S1. Why result rows show the wrong ayah (FR-001 to FR-004)

**Finding**: `_ResultRowState` in `lib/features/search/search_screen.dart` loads the row's Uthmani
words once, in `initState`. `ListView.builder` builds rows by position and has no keys, so when a
new query produces a new list, Flutter keeps the existing `State` for row *i* and only swaps its
`widget`. The title and highlight come from the new `widget.hit`, but `_words` still holds the
previous ayah. There is no `didUpdateWidget`.

Reproduced: «الرحمن الرحيم», then «قل هو الله احد». The single row is titled 112:1 and shows the
words of 1:1.

**Decision**: give each row `key: ValueKey(hit.ayah.id)`. A row for a different ayah gets a new
`State`, which loads its own words. The `_words` future is also tied to the ayah it was requested
for, so a late reply for an old ayah is dropped (FR-004).

**Rationale**: one line fixes the cause. Rows for the same ayah across queries keep their loaded
words, which is correct and saves a query. Rows that are new show the existing neutral placeholder
until their words load.

**Alternatives considered**:
- `didUpdateWidget` that reloads when the ayah changes. Works, but repeats what keys already do.
- Loading all words for the result list up front. Up to 2,600 queries for common words, slower
  first paint. Rejected.
- Putting the Uthmani words into the in-memory corpus so rows build synchronously. About 1.5 MB
  more memory for all 77k words, for a placeholder that shows for a few milliseconds. Rejected
  for now (Principle V).

## S2. Stale results while typing (FR-005)

**Finding**: the 200 ms debounce cancels earlier timers, and results are applied only if the
field still holds the query they were computed for (`_query.text == text`). Searching is
synchronous after the index loads, so results cannot arrive out of order. Clearing the field sets
an empty result directly, and a pending timer for the old text is discarded by the same check.

**Decision**: keep the current mechanism. Add widget tests that change, refine, clear and replace
the query (spec SC-001) so a future change cannot break it silently.

## S3. The matching rule (FR-007)

**Decision**: match on **searchable words**, the ayah's normalised search text split on spaces,
using **stems**.

1. **Searchable words.** Split each ayah's search text on spaces. Each searchable word belongs to
   the Uthmani word whose search range contains it (from the existing word offsets). This
   matters: one Uthmani word, «يَٰٓأَيُّهَا», has the search form «يا ايها», two searchable words.
   Matching on Uthmani words found **0** ayat for «يا ايها الذين امنوا»; matching on
   searchable words finds **89**, the known count.
2. **Stems.** For each searchable word, precompute the set of forms it can be matched as: the
   word itself, plus the word with each valid attached prefix removed. Prefixes, longest first:
   - `(و|ف)? (ب|ك|ل)? (ال)?`, with «ل» + «ال» written «لل».
   - For a word that starts with «لل» (as in «للمتقين»), also add «ال» + the rest («المتقين»),
     so a query with the article still finds it.
   - A prefix is removed only if at least **2 letters remain** («لا» does not yield «ا»).
   - **The name of Allah is never split**: «الله», «اللهم», «لله», «ولله», «فلله», «بالله» and so on
     keep the letters of the name. Stripping the article from «الله» would yield «له», so a search
     for «له» (for him) would return about 1,700 unrelated ayat. Only a leading «و», «ف» or «ب» is
     removed where it leaves «الله» or «اللهم» («والله» → «الله»). «لله» stays as it is, so the
     query «الله» does not find «لله». This is accepted, and «لله» is its own query.
3. **Matching.** Split the normalised query on spaces into tokens *t₀…tₙ₋₁*. A match starts at
   searchable word *i* when, for every *k*:
   - for *k < n−1*, a stem of word *i+k* **equals** *tₖ*;
   - for the last token, a stem of word *i+n−1* **starts with** *tₙ₋₁*.
4. **Occurrences** are counted once per starting word *i*. Matches start on different words, so
   they cannot overlap (FR-006). **Matched word ids** are the Uthmani word ids of searchable
   words *i…i+n−1*.

**Measured with the rule** (prototype, before the Allah rule for «لله»):

| Query | Today (ayat / count) | New rule (ayat / occurrences) | Note |
| --- | --- | --- | --- |
| «من» | 2,959 / 5,137 | 2,582 / 4,075 | «المؤمنين» no longer matches |
| «الله» | 1,746 / 2,557 | 1,737 / 2,547 | includes «والله», «بالله» |
| «لله» | 1,827 / 2,708 | 146 / 150 | «الله» no longer matches |
| «رحم» | — | 178 / 181 | includes «الرحمن», «برحمته» |
| «يا ايها الذين امنوا» | — | 89 / 89 | the known count |
| «الرحمن الرحيم» | 6 / 6 | 6 / 6 | unchanged |
| «المتقين» and «متقين» | — | 43 / 43 each | «للمتقين» found by both |

**Performance**: precomputing stems for 77,800 searchable words (113,000 stems) took **80 ms**,
once, when search first opens. Each query took **2–9 ms**, well within the 1-second budget
(SC-004). The existing corpus load (≤ 150 ms) plus 80 ms stays under a quarter of a second, and
it happens only once per app session.

**Rationale**: works on the existing search text and word offsets, so nothing changes in
`quran.db` or the build tool. Stems turn the prefix rule into simple equality and starts-with
checks, which keeps each query fast and the rule easy to test.

**Alternatives considered**:
- **Keep the substring scan and accept a match only at a stem boundary.** Close, but it cannot
  allow prefixes on the second and later words of a phrase. Rejected.
- **Precompute stems at build time in `quran.db`.** Faster first search, but it needs a schema
  change and a rebuild, and adds about 1 MB to the download. 80 ms once does not justify it.
  Rejected (Principle IV).
- **Morphological analysis (roots, patterns).** Would remove the «لم» → «كلم» false positives,
  but needs a morphology database (several MB) and is out of scope in the spec. Rejected.

**Known limits** (accepted in the spec):
- A word whose first letters look like a prefix can match a shorter query: «لم» finds «كلم».
- The Uthmani spelling «ياايها» was never split by the search forms. A query for the joined form
  «ياايها» finds nothing, today and with the new rule.

## S4. The result summary (FR-006)

**Decision**: replace `searchResultCount` with two ICU messages:
- `searchSummary(occurrences, ayat)`, used when the two numbers differ. Arabic: «{occurrences
  phrase} في {ayat phrase}». English: "{occurrences} occurrences in {ayat} ayat".
- `searchAyatCount(ayat)`, used when they are equal: «٦ آيات» / "6 ayat".

Arabic counted nouns follow the full plural categories (one, two, few, many, other):

| Number | موضع | آية |
| --- | --- | --- |
| 1 | موضع واحد | آية واحدة |
| 2 | موضعان | آيتان |
| few: last two digits 3–10 (3, 105) | {n} مواضع | {n} آيات |
| many: last two digits 11–99 (11, 2,547) | {n} موضعًا | {n} آية |
| other: last two digits 00–02 (100, 1,002) | {n} موضع | {n} آية |

English: "1 occurrence", "{n} occurrences"; "1 ayah", "{n} ayat" (the brand's transliteration).

Numbers use `formatNumber` as today, so they follow the interface numerals. The summary keeps
`Semantics(liveRegion: true)` so screen readers announce it.

**Rationale**: these are the standard Arabic counted-noun forms, and `gen-l10n` supports all six
Arabic plural categories. Two simple messages are easier to translate and test than one message
with a nested condition.

## S5. Testing approach

**Decision**:
- **Unit tests** (`test/unit/search_index_test.dart`) run the real corpus through `SearchIndex`.
  They cover every example in the spec (User Story 3, edge cases), the counts table in S3 as
  regression values, «ayat = rows», and «occurrences = matched starts».
- **Widget tests** (`test/widget/search_test.dart`, extended) cover 50 consecutive query changes,
  checking each visible row's text against its title (SC-001); tapping a row opens the shown ayah
  (SC-003); the summary in both languages.
- Stem rules get small pure unit tests that do not need the database.

**Rationale**: the bug survived because the existing test entered one query on an empty screen.
These tests target exactly the query-change path.
