# Feature Specification: Full-Width Surah Header, Larger Text When Rotated, and Named Similar-Ayah Tabs

**Feature Branch**: `013-page-zoom-similar-labels`

**Created**: 2026-11-11

**Status**: Draft

**Input**: User description: "I want the page of quran to have page little margins that makes the
header text not separated from the main quran text. Also make it zoom and be scrollable if the
screen rotated to allow the user to see larger text. For the mutashabeh, if an aya has multiple
mutashabeh tabs, instead of numbering the tabs 1, 2 add the text of the common text that the ayah
describes"

**Scope of this spec**: Four changes for the reader.

1. **Margins.** No change. A check during planning showed that the page details (surah name and
   juz above the text, page number below it) already sit right next to the Quran text, and the
   text already uses the full width. The owner chose to keep the page as it is (see
   Clarifications). The requirements below keep it that way.
2. **Surah header.** The decorated surah title on a Mushaf page spans the text from side to
   side. Today it stops short of both edges.
3. **Rotation.** On a phone turned sideways, the Mushaf page grows to the width of the screen, so
   the text is larger, and the reader scrolls down through the page.
4. **Similar-ayah tabs.** In the «عرض المتشابه» sheet (specs/010), when an ayah has more than one
   group, each tab shows the wording that the group's ayat share, in place of 1, 2, 3.

Specs 001, 002 and 005 listed landscape layouts as out of scope, and specs/012 kept regular
phones in portrait. This spec is the opt-in that constitution principle II asks for: it adds
landscape for the Mushaf page on phones. It does not add a tablet design.

## Clarifications

### Session 2026-11-11

- Q: (Added by the owner) Should the surah header be wider? → A: Yes. The surah header fills the
  page from side to side: it is as wide as the lines of text (FR-025, FR-026).
- Q: Where should the text on each similar-ayah tab come from? → A: The app works it out: the
  longest run of words shared by every ayah in the group. No editor or content change (FR-016,
  FR-017).
- Q: When the phone is turned sideways, which screens should turn with it? → A: The whole app
  turns. Only the Mushaf page gets a sideways design; every other screen just has to stay usable
  (FR-006, FR-013).
- Q: Which "header text" is separated from the Quran text and should move closer to it? → A: The
  small line above the text on every page (surah name on the right, juz on the left), and the
  page number below the text (FR-001, FR-002).
- Q: On a tall phone the page details already touch the text and the text already uses the full
  width; what is large is the empty paper above and below the page. What should happen to it? →
  A: Leave it as it is. The page keeps the printed page's proportions. FR-001 to FR-004 now
  protect today's layout, and Story 1's only visible change is the surah header.
- Q: (Found during planning) On the published content, wording shared by every ayah of a group
  is often one common word («ٱللَّهِ», «ٱلَّذِينَ», «وَإِذْ») or nothing: 9 of the 32 tabs. Which
  rule gives useful tabs? → A: Wording from the pressed ayah that it shares with at least half
  of the group's other ayat, or, when that is under two words, with at least one of them
  (FR-016). On the published content this gives two or more words on 31 of the 32 tabs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Surah header from side to side, page details kept with the text (Priority: P1)

A reader opens a page where a surah begins. The decorated surah header runs from one edge of
the text to the other, like the lines under it. On every page, the surah name and the juz stay
just above the first line and the page number just below the last line, as today.

**Why this priority**: Every reader sees this page on every use. It is the smallest of the
changes and it does not depend on the others.

**Independent Test**: Open pages with one, two and three surah titles on a short phone and on a
tall phone. Check the header's width, and that the page details and margins are as before.

**Acceptance Scenarios**:

1. **Given** the Mushaf page in portrait on any supported phone, **When** the page shows,
   **Then**, as today, the gap between the surah name and juz and the first line of text is no more than
   half the height of a text line, and the same holds between the last line and the page number.
2. **Given** a phone that is taller than the page needs, **When** the page shows, **Then** the
   spare height is outside the page details (above the surah name and below the page number),
   not between the details and the text.
3. **Given** any supported phone, **When** the page shows, **Then** the text is as wide as the
   screen allows, leaving only the room that the hizb-quarter and sajdah marks need beside it,
   and no text or mark is clipped or under the system bars.
4. **Given** a page with a surah title, **When** the page shows, **Then** the surah header's
   frame starts at the right edge of the text lines and ends at their left edge, it is not
   stretched out of shape, and it does not touch the text above or below it.
5. **Given** the two-page spread of specs/012, **When** it shows, **Then** both pages follow the
   same rules.

---

### User Story 2 - Larger text when the phone is turned sideways (Priority: P2)

A reader finds the text small and turns the phone sideways. The page now fills the width of the
screen, so every line is much larger. The whole page no longer fits, so the reader scrolls down
to read the rest of it. Swiping sideways still turns the page. Turning the phone upright again
shows the whole page as before, at the same place.

**Why this priority**: It gives readers who need larger text a way to get it in the Mushaf layout
without leaving the printed page. It is a larger change than Story 1, and the app works without it.

**Independent Test**: On a phone with rotation allowed, open a page, turn the phone sideways,
read the page from top to bottom by scrolling, turn pages, and turn the phone back.

**Acceptance Scenarios**:

1. **Given** the Mushaf page in portrait, **When** the reader turns the phone sideways, **Then**
   the same page shows with its lines filling the width of the screen (inside the safe areas),
   larger than in portrait, starting at the top of the page.
2. **Given** the sideways page, **When** the reader drags up or down, **Then** the page scrolls
   smoothly and every one of its lines, and its page details, can be brought on screen.
3. **Given** the sideways page, **When** the reader swipes sideways, **Then** the next or
   previous page shows, in the Mushaf's direction, starting at its top.
4. **Given** the sideways page, **When** the reader turns the phone upright, **Then** the whole
   page shows as in portrait, and it is the same page.
5. **Given** the sideways page, **When** the reader long-presses an ayah, taps the page to show
   or hide the controls, or uses any control, **Then** each works as it does in portrait.
6. **Given** a recitation or memorization session on the sideways page, **When** the current ayah
   is outside the part of the page on screen, **Then** the page scrolls to bring it on screen.
7. **Given** the reader opens an ayah from search, a bookmark, the index or the similar-ayah
   sheet while the phone is sideways, **Then** the page shows with that ayah on screen.
8. **Given** the phone's rotation lock is on, **When** the reader turns the phone, **Then**
   nothing changes.
9. **Given** a screen wide enough for two facing pages (specs/012), **When** it is sideways,
   **Then** the two-page spread shows as today, not the scrolling page.

---

### User Story 3 - Similar-ayah tabs named by their shared wording (Priority: P3)

A reader long-presses an ayah that belongs to several similarity groups and opens «عرض المتشابه».
Today the tabs say 1, 2, 3, and the reader must open each one to learn what it is about. Now
each tab shows the wording that the ayat of that group share, so the reader picks the right one
at once.

**Why this priority**: It affects only ayat with more than one group, which is a small share of
the linked ayat. The sheet already works with numbers.

**Independent Test**: Open the sheet for an ayah with two or more groups and compare each tab's
text with the ayat listed under it.

**Acceptance Scenarios**:

1. **Given** an ayah with two or more groups, **When** the sheet opens, **Then** each tab shows
   wording from the pressed ayah that also appears in other ayat of that tab's group (FR-016),
   in the Mushaf's script, and no tab shows only a number.
2. **Given** a group whose shared wording is long, **When** its tab shows, **Then** the tab shows
   the start of the wording, ends with «…», and stays on one line.
3. **Given** a group in which the pressed ayah shares no word with any other ayah, **When** its
   tab shows, **Then** it shows the group's number, as today.
4. **Given** two groups of the same ayah with the same shared wording, **When** the tabs show,
   **Then** each shows the wording followed by its number, so that they differ.
5. **Given** more tabs than fit on one line, **When** the sheet shows, **Then** every tab can
   still be reached and tapped.
6. **Given** a screen reader is on, **When** focus moves to a tab, **Then** it reads the shared
   wording and whether the tab is selected.
7. **Given** an ayah with one group, **When** the sheet opens, **Then** no tabs show, as today.

---

### Edge Cases

- The first two pages of the Mushaf (al-Fatihah and the start of al-Baqarah) have fewer, shorter
  lines in a decorated layout. Story 1 and Story 2 apply to them without clipping.
- A page with a surah title or a basmalah line: both grow with the text when sideways, and the
  surah header still spans the text from side to side.
- A page with two or three surah titles (the short surahs at the end of the Mushaf), and a surah
  title on the first or last line of a page: each header spans the full width without touching
  the page details or the neighbouring lines.
- The surah header font fails to load: the plain frame drawn in its place also spans the full
  width.
- The phone is turned while a sheet, a dialog, the settings, or the onboarding tour is open: the
  screen stays usable and nothing is lost.
- The phone is turned during a page turn or while the page is still loading.
- The phone is turned during a recitation: playback continues without a gap.
- Memorization mode with hidden text on the sideways page: hidden words stay hidden while
  scrolling.
- A sideways phone with a notch or camera cut-out on one side: no text is under it.
- A very large system font size: the tab text grows, and the tabs stay reachable (Story 3,
  scenario 5).
- The shared wording of a group is one very common word (for example «قال»): the tab shows it.
  Scenario 4 of Story 3 covers tabs that would then look the same.
- A group with many ayat (for example 31 in ar-Rahman): the tab shows the wording that the
  pressed ayah shares with at least half of them.
- The same group opened from two of its ayat can show different tab text, since the wording is
  taken from the pressed ayah.
- Content updated online (specs/011) while the app is in use: the tabs follow the content that
  the sheet shows.

## Requirements *(mandatory)*

### Functional Requirements

**Margins (Story 1; today's layout, kept)**

- **FR-001**: On the Mushaf page, the gap between the page details above the text (surah name,
  juz) and the first line MUST stay no more than half a text line. The same limit applies
  between the last line and the page number. This is today's layout and MUST NOT regress.
- **FR-002**: Spare screen height MUST stay outside the page details, never between the details
  and the text. The page keeps the printed page's proportions (specs/002); line spacing does not
  grow to fill a tall screen.
- **FR-003**: The side margins MUST stay only as wide as the hizb-quarter and sajdah marks need,
  with the text as large as the screen allows within that limit and the page's proportions.
- **FR-004**: The page MUST stay inside the safe areas. No text, mark or page detail may be
  clipped or covered by system bars.
- **FR-005**: The same rules MUST apply to each page of the two-page spread (specs/012) and to
  the web app (specs/008).

**Surah header (Story 1)**

- **FR-025**: The surah header on a Mushaf page MUST span the full width of the text: its frame
  starts and ends where the lines of text start and end. This applies in portrait, on the
  sideways page, on each page of the spread, and in the web app.
- **FR-026**: The surah header MUST keep its proportions (never stretched), MUST stay centred on
  its line, and MUST NOT touch or cover the text of the lines above and below it or the page
  details.

**Rotation (Story 2)**

- **FR-006**: On phones, the whole app (every screen, sheet and dialog) MUST follow the device
  when it is turned sideways, in both sideways directions, and MUST respect the system rotation
  lock.
- **FR-007**: In the Mushaf layout on a sideways screen that does not show two pages (specs/012
  FR-001), the page MUST be drawn at the full width of the reading area, with the margins of
  FR-003, keeping the page's proportions, line breaks and page details.
- **FR-008**: The reader MUST be able to scroll that page up and down to reach every line and
  both sets of page details. Scrolling MUST stop at the top and bottom of the page.
- **FR-009**: Swiping sideways MUST turn the page as in portrait. A page reached by turning MUST
  start at its top.
- **FR-010**: Turning the phone MUST keep the reader's page. Sideways shows the top of that page.
  Upright shows the whole page.
- **FR-011**: When the app takes the reader to an ayah (recitation, memorization, search,
  bookmarks, index, similar-ayah sheet), the sideways page MUST scroll so that the ayah is on
  screen.
- **FR-012**: Long-press on an ayah, ayah highlights and similar-ayah colouring, memorization
  hiding, bookmarks, and showing and hiding the controls MUST work on the sideways page as they
  do in portrait.
- **FR-013**: The flowing layout and every other screen, sheet and dialog MUST stay usable when
  the phone is sideways: nothing clipped, nothing under system bars or a camera cut-out, every
  control reachable. They do not get a new design.
- **FR-014**: Turning the phone MUST NOT interrupt a recitation, lose a selection the reader
  can still see, or lose text the reader has typed.
- **FR-015**: Where two facing pages fit (specs/012 FR-001), the spread MUST keep showing as
  today. The web app's behaviour in a wide window MUST NOT change.

**Similar-ayah tabs (Story 3)**

- **FR-016**: When an ayah has two or more groups, each tab in the similar-ayah sheet MUST show
  the group's shared wording for the pressed ayah, written as in the Mushaf: the longest run of
  consecutive words of the pressed ayah that also appears in at least half of the group's other
  ayat. When that run is shorter than two words, the tab MUST show the longest run that appears
  in at least one other ayah of the group.
- **FR-017**: The shared wording MUST come from the Quran text of the group's ayat. It needs no
  new input from the content owner, and it works for every group already published.
- **FR-018**: A tab MUST stay on one line. Wording longer than five words MUST be cut at a word boundary and end with «…».
- **FR-019**: A group with no shared run of words MUST show its number, as today.
- **FR-020**: When two tabs of one ayah would show the same text, each MUST add its number.
- **FR-021**: Tabs MUST stay in content order (specs/010 FR-011), and the first MUST be selected
  when the sheet opens. All tabs MUST be reachable when they do not fit on one line.
- **FR-022**: Screen readers MUST read a tab's shared wording (or its number under FR-019) and
  its selected state. Each tab MUST meet the minimum touch target size.
- **FR-023**: Tab text MUST be right-to-left Quran wording in both the Arabic and the English
  interface.

**All three**

- **FR-024**: The feature MUST work the same on iOS 15.0+ and Android 7.0 (API 24)+. FR-001 to
  FR-005 and FR-016 to FR-023 MUST also work in the web app.

### Key Entities

- **Page details**: the surah name and juz above a Mushaf page's text and the page number below
  it (specs/002).
- **Reading area**: the part of the screen the page may use, inside the safe areas. Its shape
  decides between the whole page (portrait), the scrolling page (sideways) and the two-page
  spread (specs/012).
- **Similarity group**: ayat the content owner linked as similar, with one explanation
  (specs/010). Unchanged by this feature.
- **Shared wording**: for a pressed ayah and one of its groups, the run of consecutive words of
  that ayah chosen by FR-016. It is worked out from the Quran text and is not stored in the
  content file.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the reference phones of specs/001 and specs/002, on all 604 pages, the gap
  between the page details and the text is at most half a text line, and nothing is clipped.
- **SC-002**: On those phones, a portrait page without a surah title is pixel-identical to
  before this feature.
- **SC-010**: On all 114 surah headers, on the reference phones, the header's frame is as wide as
  the text lines to within 1% of their width, and it touches no other text.
- **SC-003**: On a sideways phone, the text is at least 1.7 times its portrait size on the same
  phone.
- **SC-004**: On a sideways phone, a reader can read any page from its first line to its last by
  scrolling only, and scrolling and page turns stay at 60 frames per second on the reference
  phones.
- **SC-005**: In 20 turns of the phone at random pages, the reader's page is on screen after each
  turn, every time, within 1 second.
- **SC-006**: For every ayah with two or more groups in the published content, no two of its tabs
  show the same text, and every tab that is not a number shows wording found in the pressed ayah
  and in at least one other ayah of its group.
- **SC-007**: In the published content, at least 90% of the tabs of multi-group ayat show two or
  more words of wording.
- **SC-008**: Shown the tabs of a multi-group ayah, a reader can say what each group is about
  before opening it, for at least 4 of 5 ayat tried.
- **SC-009**: The similar-ayah sheet opens as fast as before this feature (visible feedback
  within 100 ms).

## Assumptions

- "Side to side" for the surah header means the width of the text lines, not the edges of the
  screen: the header stays inside the page's margins. The flowing layout's surah header is not
  changed.
- "Zoom" in the request means the page growing to the width of the sideways screen. Pinch-to-zoom
  and a zoom control are out of scope. The flowing layout keeps its own text-size setting.
- Upside-down portrait stays off.
- The scrolling page applies wherever the reading area is wider than it is tall and two pages do
  not fit. On large screens the spread of specs/012 wins (FR-015).
- The shared wording is worked out by the app from the Quran text. The note after «|» in the
  content file stays a note for editors and stays hidden, since today's notes are places
  («البقرة ١»), not wording. A label written by the content owner in the editor (specs/011) is
  out of scope. It can be added later if the worked-out wording proves unclear for some groups.
- Matching words ignores vowel marks, pause marks and spelling variants of the same letter, so
  the same word in two ayat counts as the same. The plan sets the exact rule. Pause marks are
  left out of the tab text.
- The explanation, the list of ayat, the colouring of linked ayat and the content file format of
  specs/010 and specs/011 do not change.
- Minimum supported versions stay iOS 15.0 and Android 7.0 (API 24). iPad support stays out of
  scope.
- The onboarding illustrations and the store screenshots keep showing the portrait page. Store
  screenshots are updated only if the new margins change them visibly.
