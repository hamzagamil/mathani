# Feature Specification: Print-Like Mushaf Page

**Feature Branch**: `002-print-like-mushaf-page`

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description: "I want to make the page view paper like. Now the text is not normal
and it aligns to the edges which is correct but on different screen sizes it leaves lots of
spaces. See attached the difference between us and another app which shows print-like page"

**Scope of this spec**: How a page looks in the Mushaf layout of feature
[001-quran-mushaf-reader](../001-quran-mushaf-reader/spec.md) (its FR-003). The line breaks, page
breaks and text of the 604 pages do not change. The flowing layout is not affected.

**Problem today** (from the attached screenshots, page 3 on the same phone):
- **Mathani**: each line reaches both edges, but only by widening the spaces between words. On many
  lines, the gaps are several times wider than a normal space. Words look scattered, and the line
  reads as a row of separate words rather than continuous script.
- **Reference app**: each line also reaches both edges, but the words sit at normal print spacing.
  The line is filled by lengthening letter joins and by larger lettering, as in the printed
  Madinah Mushaf. The text block looks the same as the printed page, and the space left over on a
  tall screen goes to the margins above and below it, not into the lines.

## Clarifications

### Session 2026-10-22

- Q: How close to print? Print-like lettering from one Mushaf font, or an exact replica of each
  printed page? → A: Both. Print-like lettering is built in and is the default. An exact replica
  of every printed page is an optional download (FR-014 to FR-021). The owner asked for the
  download size to be estimated; see *Download size estimate*.
- Q: Should the page view change too? → A: Yes. A full-screen paper page with the surah and juz at
  the top and the page number at the bottom, controls shown on tap, and a page edge and subtle
  paper texture (FR-008 to FR-013).

### Session 2026-10-23

- Owner decision: **bundle the printed lettering in the app** instead of an optional download, and
  drop the download host. The printed lettering is the default; the built-in lettering stays as a
  setting. FR-014 to FR-021 and SC-007, SC-008 and SC-010 are revised below. The owner accepts the
  larger app (about 128 MB more).
- Finding: the King Fahd Complex V2 (1421 AH) edition has the same 604 pages and words per page as
  the built-in layout, but 3,585 words (4.3%) sit on a different line, and 36 pages place a surah
  title at the foot of the previous page. The printed lettering therefore uses that edition's own
  line breaks (FR-017 revised); pages, and so the ayah on screen, never change.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read lines that look like the printed Mushaf (Priority: P1)

A reader opens any page in the Mushaf layout. Each line runs edge to edge like a printed line.
Words sit at normal spacing, and the line is filled the way a calligrapher fills it: letter joins
are lengthened and no gaps are left between words. The page reads like the printed Mushaf they
know, not like spaced-out text.

**Why this priority**: This is the defect the reader sees on every page. Looking like the printed
Mushaf is the main reason to choose the Mushaf layout. It works for everyone straight after
install, with no download.

**Independent Test**: Open pages 3, 50, 300 and 604 on the reference phone with no replica pack
installed. Put each one next to the same page of the printed Madinah Mushaf or the reference app.
Every full line spans the text width, and no gap between words is visibly wider than a normal
space.

**Acceptance Scenarios**:

1. **Given** any page with full ayah lines, **When** it is shown, **Then** every full line starts
   and ends at the edges of the text block, and the gaps between its words stay within the limit
   in FR-002.
2. **Given** a line with few long words and a line with many short words on the same page,
   **When** the page is shown, **Then** both reach both edges and their word spacing looks the
   same.
3. **Given** a centred line (the end of a surah, pages 1–2, or any line the printed Mushaf
   centres), **When** it is shown, **Then** it stays centred at normal spacing and is not
   stretched to the edges.
4. **Given** a page shown in print style, **When** the reader copies, shares or searches an ayah
   from it, **Then** the text matches the authoritative source exactly, with nothing added or
   left out. Lengthened joins are visual only.

---

### User Story 2 - The same page on every screen size (Priority: P2)

A reader on a small phone, a tall phone or a large phone sees the same page. It has the same
proportions, the same density of words on each line and comfortably large text. When the screen
has a different shape from a printed page, the extra space becomes even margins around the text
block. It never becomes wider gaps between words or lines.

**Why this priority**: The defect gets worse on some screen shapes. Without this story, fixing
the lines on one phone can still leave other phones looking spaced out.

**Independent Test**: Show page 3 on the three reference screen sizes in the Assumptions section.
On each, check that the text block has the same proportions, is centred, and that the word
spacing meets FR-002.

**Acceptance Scenarios**:

1. **Given** a screen taller in proportion than a printed page, **When** a page is shown, **Then**
   the text keeps its printed proportions and fills the width, and the extra height becomes equal
   margins above and below it.
2. **Given** a screen wider in proportion than a printed page, **When** a page is shown, **Then**
   all 15 lines fit without scrolling, and the extra width becomes equal margins on both sides.
3. **Given** the same page on two different phones, **When** it is shown on each, **Then** its
   line breaks, word order and markers are identical. Only its size and margins differ.

---

### User Story 3 - A full-screen paper page (Priority: P3)

A reader sees the page as a sheet of the Mushaf rather than as text on an app screen. The page
fills the screen. The surah name and juz sit along its top edge and the page number along its
bottom edge, as in print. The sheet has a soft page edge and a faint paper texture. The app's bars
and controls stay out of the way until the reader taps the page, and a second tap hides them
again.

**Why this priority**: It completes the print look and gives the text more room. Stories 1 and 2
fix the defect on their own, so this story can ship after them.

**Independent Test**: Open the reader, check the page details and paper look against the
reference screenshot, then tap to show and hide the controls and reach the index, search,
bookmarks and settings from them.

**Acceptance Scenarios**:

1. **Given** the reader is reading, **When** no controls are shown, **Then** the page fills the
   screen within the safe areas, with the surah name and juz at the top of the page and the page
   number at the bottom.
2. **Given** controls are hidden, **When** the reader taps the page once, **Then** the controls
   (navigation, bookmark, search, settings, layout switch) appear within 100 ms. **When** they tap
   again, **Then** the controls hide.
3. **Given** controls are shown, **When** the reader turns the page, **Then** the controls hide.
4. **Given** the reader long-presses an ayah, **When** controls are hidden or shown, **Then** ayah
   selection works as in feature 001 and does not toggle the controls.
5. **Given** night theme, **When** a page is shown, **Then** the paper texture, page edge and print
   look appear in night colours, with the same spacing, proportions and markers.
6. **Given** a screen reader is on, **When** the reader opens the Mushaf, **Then** the controls
   stay reachable without needing the tap gesture.

---

### User Story 4 - Download an exact replica of the printed Mushaf (Priority: P4)

> **Revised 2026-10-23**: the printed lettering is bundled with the app and is the default; there
> is no download. The reader can switch to the built-in lettering in Settings. FR-014 to FR-021
> below describe the current behaviour; the original story is kept as a record.

A reader who wants the Mushaf exactly as printed, letter for letter, downloads the "printed
Mushaf" pack from Settings. Before downloading, they see its size. After it finishes, every page
in the Mushaf layout shows the lettering of the printed page. They can switch back to the built-in
lettering or delete the pack at any time.

**Why this priority**: It gives the most faithful page, but it is an optional extra on top of
Stories 1 to 3, and most readers get a print-like page without it.

**Independent Test**: On a fresh install, read a page offline with no pack. Download the pack on
Wi-Fi, check pages 1, 3, 300 and 604 against the printed Mushaf, go offline and read again, then
delete the pack and confirm the built-in lettering returns and the storage is freed.

**Acceptance Scenarios**:

1. **Given** the pack is not installed, **When** the reader opens its setting, **Then** they see
   what it is, its download size and the storage it will use before anything downloads.
2. **Given** the download is running, **When** the reader keeps reading, **Then** reading is not
   interrupted, progress is shown in Settings, and the built-in lettering stays in use until the
   whole pack is ready and checked.
3. **Given** the download stops (no network, app closed, low storage), **When** the reader comes
   back, **Then** they can resume it, and no partly downloaded page is ever shown.
4. **Given** the pack is installed, **When** the reader opens any page, even offline, **Then** it
   shows the printed lettering with the same line breaks, page breaks and markers as the built-in
   layout.
5. **Given** the pack is installed, **When** the reader switches to built-in lettering or deletes
   the pack, **Then** the page changes immediately, the reader stays on the same ayah, and
   deleting frees the storage.
6. **Given** the reader is on mobile data, **When** they start the download, **Then** they are told
   it is on mobile data and asked to confirm.

---

### Edge Cases

- **Lines that are naturally wider than the text block** (the few longest lines of the
  Mushaf): they fit without being visibly smaller than the lines around them. See FR-004.
- **Lines with only one or two words**: they are filled without one stretched gap, or are
  centred when the printed Mushaf centres them.
- **Ayah-end markers, sajdah and hizb-quarter markers**: they keep their print position and size.
  Markers are never stretched, and gaps next to a marker follow the same spacing limit.
- **Surah headers and basmala lines**: they keep their framed, centred form and are not
  justified.
- **Pages 1 and 2** (Al-Fatiha and the start of Al-Baqarah): their special centred layout is
  kept.
- **Very small screens** (the smallest supported phone): the text may be smaller, but the spacing
  limit in FR-002 still holds. Spacing is never traded for size.
- **Long-press to select an ayah** and the ayah highlight: they still cover exactly the words of
  the ayah, including lengthened joins, with no gaps or overlaps. This holds with either
  lettering.
- **Switching to the flowing layout and back**: the reader stays at the same ayah, as in feature
  001. The flowing layout keeps its own bars and does not use the tap-to-show controls.
- **First launch**: the reader may not know that tapping shows the controls. The controls are
  shown on first open and hide on the first page turn, with a short hint.
- **Display cut-outs and rounded corners**: the page details at the top and bottom stay inside the
  safe areas.
- **Replica pack, low storage**: the app checks free space before downloading and says how much is
  needed instead of failing part-way.
- **Replica pack, damaged or incomplete files**: the app falls back to the built-in lettering for
  the whole Mushaf and offers to repair the pack. It never shows a broken page.
- **Replica pack after an app update**: an installed pack keeps working. If a new pack version is
  needed, the reader is told and the old one is used until they update it.
- **Replica pack and search, copy and share**: unchanged. They always use the authoritative text,
  never the replica lettering.
- **Replica pack, a page whose printed lines differ from the built-in layout**: this must not
  happen. See FR-017.

## Requirements *(mandatory)*

### Functional Requirements

**Lines (built-in lettering)**

- **FR-001**: In the Mushaf layout, every ayah line that the printed Madinah Mushaf justifies MUST
  start and end at the edges of the text block.
- **FR-002**: Lines MUST be filled mainly by lengthening letter joins (kashida) and by text size,
  as in the printed Mushaf, not by widening word gaps. Every gap between two words on any page
  MUST be at most 1.5 times the normal word space of the Quran text at that size.
- **FR-003**: Lines that the printed Mushaf centres (surah ends, pages 1–2, and other centred
  lines) MUST stay centred at normal word spacing.
- **FR-004**: Every justified line MUST be shown at 95% or more of the text size of the other
  lines on its page.
- **FR-005**: Lengthening and spacing MUST be visual only. The text that is copied, shared,
  searched or read by a screen reader MUST be identical to the authoritative source (feature 001
  FR-002). No character may be added, removed or substituted.
- **FR-006**: Line breaks, page breaks, the order of words and the position of every marker MUST
  stay exactly as in feature 001.
- **FR-007**: The built-in lettering MUST be the default, MUST be included in the app and MUST
  work offline from first install.

**Page view**

- **FR-008**: The text block MUST keep the proportions of the printed Mushaf page on every screen
  size. It MUST be centred, fill the available width or height (whichever runs out first), and turn
  any remaining space into equal margins. The space between words and between lines MUST NOT grow
  to fill a screen.
- **FR-009**: In the Mushaf layout, the page MUST fill the screen within the safe areas. The surah
  name and juz MUST appear along the top edge of the page and the page number along the bottom
  edge, as in print. This meets feature 001 FR-008 (surah, juz and page always visible).
- **FR-010**: The app's bars, system bars and controls MUST be hidden while reading and MUST appear
  when the reader taps the page. A second tap or a page turn MUST hide them. Long-press stays
  reserved for ayah selection. When a screen reader is on, the controls MUST stay reachable
  without the tap gesture.
- **FR-011**: The page MUST look like a paper sheet: a soft page edge and a subtle paper texture
  in the day theme, and a matching dark sheet in the night theme. The texture MUST NOT lower the
  contrast of the Quran text below the WCAG AA level for body text.
- **FR-012**: Text in the Mushaf layout MUST be at least as large as it is today on each reference
  screen size.
- **FR-013**: The print look and paper sheet MUST apply in both day and night themes.

**Exact replica (printed lettering, bundled; revised 2026-10-23)**

- **FR-014**: The app MUST include the lettering of the printed Madinah Mushaf (the King Fahd
  Complex page fonts) and show every page in it, letter for letter. It is the default lettering.
- **FR-015**: *(Withdrawn: there is no download.)*
- **FR-016**: Every word MUST have its printed glyph; this is checked when the app is built, and a
  page whose font is still loading shows blank paper, never another lettering's text.
- **FR-017**: The printed lettering MUST use the same 604 pages and the same words on each page as
  the built-in layout, so switching lettering never changes the page or ayah on screen. Within a
  page it uses the printed edition's own line breaks and surah-title placement.
- **FR-018**: The printed lettering MUST work fully offline from first install.
- **FR-019**: Users MUST be able to switch between the printed and built-in lettering in Settings.
  The choice MUST persist across restarts.
- **FR-020**: *(Withdrawn: the app makes no network requests.)*
- **FR-021**: With the printed lettering, ayah selection, highlighting, bookmarks, search, copy and
  share MUST behave exactly as with the built-in lettering.

**Unchanged**

- **FR-022**: Page turning, ayah selection, highlighting, bookmarks, go-to and returning to the
  last position MUST work as in feature 001. Ayah highlights MUST cover lengthened joins.
- **FR-023**: Everything except the optional pack MUST work fully offline from first install, as
  in feature 001 FR-026.

### Key Entities

- **Mushaf Page** (feature 001): one of 604 pages, 15 line slots. Unchanged in content.
- **Line**: a justified or centred line of words and markers on a page. It gains a way to be
  filled: how much each letter join is lengthened, within the spacing limit.
- **Text Block**: the area of the screen holding the 15 lines. It has print proportions and is
  centred with margins.
- **Replica Pack**: the optional download of printed-page lettering for all 604 pages. It has a
  version, a download size, an installed size, a state (not installed, downloading, paused,
  installed, damaged) and a checksum.
- **Reader Preferences** (feature 001): gain the chosen lettering (built-in or replica).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On all 604 pages and all three reference screen sizes, every justified line spans the
  text block edge to edge (within 1% of its width).
- **SC-002**: On all 604 pages and all three reference screen sizes, no gap between words is wider
  than 1.5 times a normal word space with the built-in lettering. Today, many lines exceed this.
- **SC-003**: The copied text of every ayah matches the authoritative source in 100% of ayat, with
  either lettering (the integrity check of feature 001 SC-003 still passes).
- **SC-004**: On each reference screen size, the text block keeps print proportions within 2%, and
  its margins are equal on opposite sides within 2 points.
- **SC-005**: In a side-by-side review of 10 pages chosen across the Quran, at least 4 of 5
  readers familiar with the printed Madinah Mushaf say the built-in page "looks like the printed
  page". With the replica pack, all 5 say it does.
- **SC-006**: Page turning stays at 60 fps and cold start to a readable page stays at 2 seconds or
  less on the reference phones, with either lettering (feature 001 SC-001 and SC-002).
- **SC-007**: The paper look adds no more than 0.5 MB to the store download. The bundled printed
  lettering adds about 128 MB (owner decision 2026-10-23; exceeds the constitution's 30 MB, see
  plan › Complexity Tracking).
- **SC-008**: With the printed lettering, all 604 pages have the same words as the built-in layout,
  every word has a glyph, and every full line spans the text block (checked automatically).
- **SC-009**: Readers can show and hide the controls with one tap, and in usability testing at
  least 9 of 10 first-time readers find the index and search within 30 seconds.
- **SC-010**: *(Withdrawn with the download.)*

## Download size estimate

Measured on 2026-10-22 from the public copies of the King Fahd Complex page lettering files that
the reference app uses. They are the best-known source for an exact replica. The size grows with
how much each page's lettering is compressed on the device:

| Replica option | Download | On the device |
| --- | --- | --- |
| Current print (1421 AH), plain colours, matches the reference app | **about 93 MB** (604 pages, 40–221 KB each, 158 KB average) | 93 MB if kept compressed; about 210 MB if expanded |
| The same print with tajweed colours | about 48 MB | about 48 MB compressed |
| Older print (1405 AH) | about 46 MB | about 46 MB compressed |

- The recommended pack is the first row, since it is the print the reference app shows. Expect
  **about 95 MB to download and 95–210 MB on the device**, depending on a storage trade-off for
  the plan to make.
- The tajweed row is smaller but adds colouring, which is out of scope. The 1405 AH print is a
  different edition whose line breaks differ from the built-in layout on some pages, so it would
  break FR-017.
- The app itself stays at about 12 MB (Android) and 20 MB (iOS), as estimated in feature 001. Only
  readers who choose the pack download the extra.
- The plan MUST confirm these figures with the actual files and licence, and SHOULD look at ways to
  make the pack smaller (for example, sharing lettering across pages).

## Assumptions

- The reference app's page in the screenshot shows the target: normal word spacing, lines filled
  by lengthened joins, print proportions, and spare space as margins.
- Reference screen sizes: a small phone (iPhone SE, 2nd gen), a mid-range Android phone (Galaxy
  A15) and a large, tall phone (6.7-inch class iPhone or Android).
- The 1.5× word-space limit and 5% size limit are initial values chosen to match print. They may
  be tuned in the plan after measuring real pages, as long as gaps stay visibly normal.
- The cream "Mushaf paper" day colour and the night theme from feature 001 FR-016 stay, as the
  base colours of the paper sheet.
- The text source and built-in font from feature 001 stay unless the plan finds that FR-002 needs
  a font with better letter-join lengthening. The font licence dependency (feature 001, D1) still
  applies.
- **New dependency (D3)**: redistributing the printed-page lettering requires permission from the
  King Fahd Complex, the same body as D1. The replica pack cannot ship without it. Stories 1 to 3
  do not depend on it.
- **New dependency (D4)**: the pack needs a place to download from. The plan picks it (for example,
  the app's own release storage), subject to D3.
- Feature 001 ships with no network requests. The pack adds the app's first one, only when the
  reader asks. No data is collected, so the store privacy answers stay "no data collected". The
  plan MUST recheck them.
- Phones in portrait only, as in feature 001.

## Out of Scope

- The flowing layout and its text size.
- Changes to the Quran text, line breaks or page breaks.
- Tablet and landscape layouts.
- Decorative page borders and ornaments beyond the page edge, texture and surah headers.
- Tajweed colouring, including the tajweed replica pack.
- Other prints or narrations as packs.
