# Feature Specification: Fix Search Result Details

**Feature Branch**: `003-fix-search-result-details`

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description: "Also I want you to check for a bug in the displayed results details
when the user searches for a word"

**Scope of this spec**: The search results screen of feature
[001-quran-mushaf-reader](../001-quran-mushaf-reader/spec.md) (its FR-022): what each result row
shows, how matches are highlighted, and what the result count means. How search is opened, how
fast it is and how text is normalised do not change, except where FR-007 says.

## Clarifications

### Session 2026-10-22

- Q: Should a query match only whole words, or also inside longer words as today? → A: Whole
  words by default, with attached prefixes allowed and the query allowed to be the beginning of a
  longer word. «من» no longer matches inside «المؤمنين», «الله» still finds «والله» and «بالله»,
  and «رحم» still finds «رحمة» and «الرحمن» (FR-007).

## Findings (checked on 2026-10-22)

The search screen was tested with the real Quran data.

1. **Result rows show the wrong ayah (confirmed).** When the reader changes the query, rows that
   were already on screen keep the ayah text of the *previous* search, while the title above them
   shows the *new* result.
   - **Reproduce**: search «الرحمن الرحيم», then change the query to «قل هو الله احد». The only
     result is titled «سورة الإخلاص، الآية ١», but its text is «بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ
     ٱلرَّحِيمِ» (Al-Fatiha 1:1).
   - The highlight is then also wrong, because it marks the new result's words in the old ayah's
     text.
   - Tapping the row opens the ayah in the title, not the text the reader saw.
   - It happens on almost every search, because the query is usually typed or refined
     letter by letter. Rows that scroll into view later are correct, so it is easy to miss.
2. **The count does not match the list.** The count shows the number of *matches*, but the list
   shows one row per *ayah*. For «الله», the screen says 2,557 results but lists 1,746 ayat. For
   «من», it says 5,137 and lists 2,959. The label word «نتيجة» (result) suggests rows, so readers
   cannot reconcile the two.
3. **Matches inside other words.** A query matches anywhere inside a word. For «لله», all 1,746
   ayat containing «الله» are found too (2,708 matches in total), and «من» matches inside words such
   as «المؤمنين». The whole word is highlighted, so a reader cannot see that only part of it
   matched. Decided: matches start at the beginning of a word, after any attached prefixes
   (FR-007).
4. **Overlapping matches are counted twice.** Matches that overlap inside a word are counted as
   separate occurrences, which inflates the count.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every result shows its own ayah (Priority: P1)

A reader types a word, refines it, or replaces it with another. Every row in the list always
shows the text of the ayah named in its title, with the matched words highlighted. Tapping the
row opens that same ayah.

**Why this priority**: Showing the wrong ayah under a reference misleads readers about what the
Quran says where. It is the most serious defect, and it appears on almost every search.

**Independent Test**: Search «الرحمن الرحيم», then change it to «قل هو الله احد». The single row
shows Al-Ikhlas 112:1 with «قُلْ هُوَ ٱللَّهُ أَحَدٌ» highlighted. Repeat with ten query changes of
different lengths and check every visible row each time.

**Acceptance Scenarios**:

1. **Given** results are shown, **When** the reader changes the query, **Then** every row shows
   the text of the ayah in its own title. No text from an earlier search remains.
2. **Given** the reader types a query letter by letter, **When** each new list appears, **Then**
   every visible row matches its title and its highlight is on words of that ayah.
3. **Given** a row, **When** the reader taps it, **Then** the Mushaf opens on the ayah whose text
   and title the row showed.
4. **Given** results for a query, **When** the reader clears the query and types a new one,
   **Then** the new list is correct from its first row.
5. **Given** an ayah's text is still loading, **When** the row appears, **Then** it shows a
   placeholder, never another ayah's text.

---

### User Story 2 - A count readers can trust (Priority: P2)

A reader searches for a word and sees how many ayat contain it and how many times it occurs. Both
numbers agree with the list.

**Why this priority**: The count is how readers judge how common a word is, which matters for
study and for the later Mutashabihat feature. A number that disagrees with the list undermines
trust in the results.

**Independent Test**: Search «الله», «من» and «الرحمن الرحيم». The number of ayat in the summary
equals the rows in the list, and the number of occurrences equals the highlighted matches summed
across all rows.

**Acceptance Scenarios**:

1. **Given** a query with matches, **When** results appear, **Then** the summary states both the
   number of ayat and the number of occurrences, for example «٢٥٥٧ موضعًا في ١٧٤٦ آية» /
   "2,557 occurrences in 1,746 ayat".
2. **Given** a query whose occurrences equal its ayat, **When** results appear, **Then** the
   summary states the ayat once, without repeating the same number.
3. **Given** the summary, **When** a screen reader reads it, **Then** it announces both numbers
   with correct Arabic and English plural forms.

---

### User Story 3 - Highlights show exactly what matched (Priority: P3)

A reader can see at a glance which words in each ayah matched the query, and nothing else is
highlighted.

**Why this priority**: It completes the fix. Once Stories 1 and 2 are in place, this story makes
the highlight agree with the matching rule chosen in FR-007.

**Independent Test**: Search a one-word query and a multi-word phrase, and check that only the
matched words are highlighted in a sample of 20 rows, following the rule in FR-007.

**Acceptance Scenarios**:

1. **Given** a phrase query («يا ايها الذين امنوا»), **When** results appear, **Then** each row
   highlights the whole phrase and no other words.
2. **Given** an ayah in which the query appears several times, **When** its row is shown,
   **Then** every occurrence is highlighted.
3. **Given** the query «من», **When** results appear, **Then** «من», «ومن», «فمن» and «منهم» are
   found and highlighted, and «المؤمنين» is not.
4. **Given** the query «الله», **When** results appear, **Then** «والله», «بالله» and «فالله» are
   found as well as «الله».
5. **Given** the query «رحم», **When** results appear, **Then** «رحمة», «الرحمن» and «برحمته» are
   found.
6. **Given** the query «لله», **When** results appear, **Then** «لله» and «ولله» are found, and
   «الله» is not.

---

### Edge Cases

- **Typing quickly**: results from an older query must never replace the results of a newer one,
  and no row may mix the two.
- **Clearing the query**: the list empties completely. The next search does not reuse any old
  row content.
- **Very common words** («من», «الله», over 1,700 rows): rows stay correct while scrolling fast in
  both directions.
- **Very long ayat** (for example, 2:282): the row shows the whole ayah with the match
  highlighted. No row is cut off in a way that hides the match.
- **A match that starts or ends at a word edge**: only the words it covers are highlighted.
- **A match across two words** (a phrase): both words are highlighted, and the space between them
  is not counted as a separate match.
- **Language switch while results are shown**: titles and the summary switch language, and each
  row still shows its own ayah.
- **No results**: the "no results" message replaces the summary and list, as today.
- **Ayah markers**: ayah-end markers are never highlighted or counted.
- **Words whose first letter looks like a prefix**: a short query can match a word whose first
  letters are part of the root, not a prefix (for example, «لم» also finds «كلم»). This is accepted:
  telling the two apart needs word analysis, which is out of scope.
- **Article joined to «ل»**: «ل» + «ال» is written «لل» (for example, «للمتقين»). The query
  «المتقين» finds «للمتقين», and the query «متقين» finds both.
- **A query that is itself a prefix** (for example, «و» or «ال» alone): it matches words that
  start with those letters. It does not match every word that has that prefix attached.

## Requirements *(mandatory)*

### Functional Requirements

**Correct rows (bug 1)**

- **FR-001**: Every result row MUST show the text of exactly the ayah named in its title, at all
  times, including after the query changes, is refined, is cleared or is replaced.
- **FR-002**: The highlight in a row MUST be drawn on that row's own ayah text only.
- **FR-003**: Tapping a row MUST open the ayah whose title and text the row shows, highlighted as
  in feature 001.
- **FR-004**: While a row's text is loading, it MUST show a neutral placeholder, never another
  ayah's text.
- **FR-005**: Results from an older query MUST never be shown after the reader has typed a newer
  query.

**Count (bugs 2 and 4)**

- **FR-006**: The summary MUST state the number of matching ayat, which MUST equal the number of
  rows, and the number of occurrences, which MUST equal the total of highlighted matches across
  all rows. Overlapping matches MUST NOT be counted twice. When the two numbers are equal, the
  summary MUST state it once.

**Matching rule (bug 3)**

- **FR-007**: A query MUST match from the beginning of a word, never from the middle of one:
  - A word MAY carry attached prefixes before the match: an optional «و» or «ف», then an optional
    «ب», «ك» or «ل», then an optional article «ال». «ل» + «ال» is written «لل». A query that
    starts with «ال» also matches after these prefixes.
  - The query MAY end before the word ends, so it also finds longer forms of the word («رحم» finds
    «رحمة»).
  - In a phrase of several words, every word except the last MUST match a whole word (prefixes
    allowed). The last word follows the two rules above.
  - Matching stays insensitive to diacritics, hamza and alef forms and Uthmani spellings, as in
    feature 001 FR-022.
  - The highlight covers each matched word in full. Occurrences are counted once per matched word
    (or phrase).

**Unchanged**

- **FR-008**: Normalisation (diacritics, hamza and alef forms, Uthmani spellings), the 1-second
  response time (feature 001 SC-006), result order (Mushaf order) and the "no results" message
  MUST stay as in feature 001.
- **FR-009**: The result title MUST stay as «سورة {name}، الآية {number}» / "Surah {name}, ayah
  {number}", with numbers in the interface's numerals.

### Key Entities

- **Search Result** (one row): an ayah reference (surah, ayah), its text, and the words matched
  in it. The text shown and the reference MUST always belong to the same ayah.
- **Search Summary**: the number of matching ayat and the number of occurrences for one query.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In an automated test of at least 50 consecutive query changes (typed, refined,
  cleared and replaced), 100% of visible rows show the text of the ayah in their title after every
  change. Today, the first change already fails.
- **SC-002**: For a fixed set of 40 queries (common words, rare words and phrases), the ayat
  count in the summary equals the number of rows, and the occurrence count equals the highlighted
  matches.
- **SC-003**: In 100% of tested taps, the Mushaf opens on the ayah the tapped row showed.
- **SC-004**: Search results still appear within 1 second on the reference phones (feature 001
  SC-006), and the list scrolls at 60 fps through the longest result list.
- **SC-005**: In a review of 20 queries, a reader can tell from every row which words matched,
  with no highlighted word outside the match rule in FR-007.
- **SC-006**: All the examples in User Story 3 (scenarios 3–6) and the edge cases pass as
  automated tests. «من» returns fewer ayat than today's 2,959, and none of them only because of a
  word like «المؤمنين».

## Assumptions

- The bug the owner reported is finding 1 (rows showing the wrong ayah), the only one that shows a
  result's details incorrectly. Findings 2–4 were found while checking and are fixed in the same
  feature, since they also affect the result details.
- The summary wording «{occurrences} موضعًا في {ayat} آية» / "{occurrences} occurrences in {ayat}
  ayat" is a default. The final Arabic wording follows the brand's tone of voice, with correct
  plural forms for every number.
- Search keeps its current scope: the Arabic Quran text only, no translations or tafsir.
- The fix needs automated tests for changing the query, which the current search test does not
  cover. That gap is why bug 1 was missed.

## Out of Scope

- Search filters (by surah, juz or page), sorting other than Mushaf order, and search history.
- Searching by root or word form (for example, finding «يعلمون» from «علم»).
- Changes to how the matched ayah is highlighted in the Mushaf after opening it.
