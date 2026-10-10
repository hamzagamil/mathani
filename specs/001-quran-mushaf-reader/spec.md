# Feature Specification: Quran Mushaf Reader (Uthmani Script)

**Feature Branch**: `001-quran-mushaf-reader`

**Created**: 2026-10-10

**Status**: Draft

**Input**: User description: "أريد أن أصمم تطبيق جديد للقرآن الكريم. اسم التطبيق (مثاني - Matahni). سيتم
تطويره أولا ليكون فيه القرآن الكريم قراءة بالخط العثماني مع إضافات لاحقة لقراءات كبار القراء المصريين
مع مزامنة القراءة مع الآيات المتلوة. أيضا سيكون فيه بشكل أساسي بعد ذلك جزءا لبعض التدبر على متشابه
آيات القرآن ومقارنة مواضعه وفك إشكالاته. ويمكن إضافة اتجاه القبلة ومواقيت الصلاة في ما بعد. وأيضا
يمكن أن نفعل التذكير بالورد اليومي للتلاوة عن طريق Google FCM. اسم التطبيق على المتجر سيكون: مثاني:
تلاوة وتدبر المتشابه. البراند موجود في المحادثات العادية على كلود."

**Scope of this spec**: The first release of Mathani (مثاني): reading the complete Quran in
Uthmani script. Later capabilities named in the input (recitations with ayah sync, Mutashabihat
study, Qibla and prayer times, daily wird reminder) are separate features. See *Out of Scope*.

## Clarifications

### Session 2026-10-10

- Q: Reading layout: page-faithful 604-page Mushaf, flowing resizable text, or both? → A: Both,
  with a one-tap toggle. The Mushaf layout is the default (FR-003).
- Q: Interface language for the first release? → A: Arabic and English, following the device
  language with an in-app override (FR-025).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read the Mushaf in Uthmani script (Priority: P1)

A reader opens Mathani and sees the Quran in Uthmani script on a calm, paper-like page. They turn
pages in the same direction as a printed Arabic Mushaf. Each surah opens with its header and the
basmala. Ayah-end markers show the ayah number in Eastern Arabic numerals. The current surah,
juz and page number are always visible. When they close the app and come back, it reopens on the
page they were reading.

**Why this priority**: Reading the Quran is the core of the app and the base that recitation sync
and Mutashabihat study will build on. On its own it is a publishable, useful Mushaf app.

**Independent Test**: Install on a phone with networking disabled, open the app, read and turn
pages through several surahs, close and reopen. The full Quran must be readable and the position
restored.

**Acceptance Scenarios**:

1. **Given** a fresh install with no network connection, **When** the user opens the app, **Then**
   the Mushaf opens on Surah Al-Fatiha and every page of the Quran is readable.
2. **Given** the user is on a page, **When** they swipe in the Mushaf's page-turn direction,
   **Then** the next page appears immediately, without a visible loading state.
3. **Given** a page where a new surah begins, **When** it is displayed, **Then** it shows a surah
   header with the surah name, then the basmala. Surah At-Tawbah has no basmala, and in Al-Fatiha
   the basmala is shown as ayah 1.
4. **Given** the user is reading page N, **When** they close the app (or the system ends it) and
   reopen it, **Then** the app opens on page N.
5. **Given** any page, **When** it is displayed, **Then** the current surah name, juz number and
   page number are visible without extra taps.

---

### User Story 2 - Navigate to any surah, juz or page (Priority: P1)

From the reading screen, the reader opens an index with tabs for Surahs (السور), Ajza' (الأجزاء)
and Bookmarks (المحفوظات). They pick a surah, a juz or a hizb quarter, or type a page number or a
surah and ayah, and go straight there.

**Why this priority**: Without navigation a 600-page Mushaf is unusable. This is required for the
first release.

**Independent Test**: From the reading screen, reach Surah Al-Kahf, Juz 30, page 300 and Al-Baqarah
2:255, each in at most 3 taps or entries.

**Acceptance Scenarios**:

1. **Given** the Surahs index, **When** the user views it, **Then** all 114 surahs are listed in
   Mushaf order with number, name, ayah count, revelation type (Makki/Madani) and starting page.
2. **Given** the Ajza' index, **When** the user taps a juz or one of its hizb quarters, **Then** the
   Mushaf opens on the page where it begins.
3. **Given** the go-to control, **When** the user enters a valid page number or a surah and ayah,
   **Then** the Mushaf opens on that page and briefly highlights the requested ayah.
4. **Given** the go-to control, **When** the user enters an invalid page or ayah number, **Then**
   the app shows the valid range and does not navigate.

---

### User Story 3 - Bookmarks and reading progress (Priority: P2)

The reader marks places they want to return to, such as the end of today's wird or a favourite
ayah. They see all their bookmarks in the Bookmarks tab, open any of them, and remove ones they no
longer need.

**Why this priority**: Useful for daily reading habits and needed later by the daily wird
reminder, but reading and navigation work without it.

**Independent Test**: Bookmark three different places, restart the app, confirm all three are
listed with surah, ayah and page, open one, then delete one.

**Acceptance Scenarios**:

1. **Given** a displayed page or a selected ayah, **When** the user adds a bookmark, **Then** it is
   saved with surah, ayah, page and the date added, and the page shows a bookmark indicator.
2. **Given** saved bookmarks, **When** the user opens the Bookmarks tab, **Then** they are listed
   newest first, and tapping one opens that location.
3. **Given** a saved bookmark, **When** the user removes it, **Then** it disappears from the list
   and from the page indicator.

---

### User Story 4 - Comfortable reading (Priority: P2)

The reader adjusts the experience to their conditions. They can switch between the printed-Mushaf
page layout and a flowing layout with larger text, use a night theme for reading in the dark, keep
the screen from turning off while they read, and use the interface in Arabic or English.

**Why this priority**: Long reading sessions, often at night or by older readers, depend on these.
They improve the core story but are not needed to prove it.

**Independent Test**: Switch to night theme, change text size, enable keep-screen-on, restart the
app. All settings persist and the Mushaf remains readable.

**Acceptance Scenarios**:

1. **Given** the device is in dark mode and the app is set to follow the system, **When** the user
   opens the Mushaf, **Then** it shows in the night theme. The user can also choose day or night
   manually.
2. **Given** the flowing layout, **When** the user changes the Quran text size, **Then** the text
   resizes within the supported range and the diacritics do not collide or overlap.
3. **Given** keep-screen-on is enabled, **When** the user stays on a page without touching it,
   **Then** the screen does not dim or lock while the Mushaf is open.
4. **Given** the user is reading an ayah in the Mushaf layout, **When** they switch to the flowing
   layout and back, **Then** the same ayah stays in view each time.
5. **Given** the device language is English, **When** the user opens the app, **Then** the
   interface is in English (left-to-right) and the Quran text is unchanged. **When** the user
   switches the app language to Arabic in settings, **Then** the interface becomes Arabic
   (right-to-left) right away.

---

### User Story 5 - Copy or share an ayah (Priority: P3)

The reader long-presses an ayah to select it, then copies it or shares it to another app. The text
includes its reference, for example «سورة البقرة: ٢٥٥».

**Why this priority**: Commonly expected, low effort, and builds the ayah selection that recitation
and Mutashabihat features will reuse. Not essential for reading.

**Independent Test**: Long-press an ayah, share it to a messaging app, and confirm the received text
matches the Mushaf exactly and includes the reference.

**Acceptance Scenarios**:

1. **Given** a displayed page, **When** the user long-presses an ayah, **Then** that ayah is
   highlighted and actions appear for copy, share and bookmark.
2. **Given** a selected ayah, **When** the user copies or shares it, **Then** the text is the exact
   Uthmani text of the ayah followed by the surah name and ayah number.

---

### User Story 6 - Search the Quran text (Priority: P3)

The reader types a word or phrase in Arabic with or without diacritics and sees every matching
ayah with its surah and ayah number. Tapping a result opens it in the Mushaf.

**Why this priority**: Valuable on its own, and the base for finding similar ayat in the later
Mutashabihat feature. The app is still complete without it.

**Independent Test**: Search «الرحمن الرحيم» typed without diacritics and confirm results cover the
expected ayat, then open one in the Mushaf.

**Acceptance Scenarios**:

1. **Given** the search screen, **When** the user types a query without diacritics, **Then**
   matching ayat are found regardless of diacritics, hamza and alef forms, and the Uthmani-specific
   spellings.
2. **Given** search results, **When** the user views them, **Then** each shows the ayah text with
   the match highlighted, the surah name, ayah number and the total match count.
3. **Given** a search result, **When** the user taps it, **Then** the Mushaf opens on that page
   with the ayah highlighted.
4. **Given** a query with no matches, **When** the search completes, **Then** a clear "no results"
   message is shown.

---

### Edge Cases

- **First launch with no network**: the full Mushaf must still be readable. No content may require
  a download.
- **Surah boundaries**: a surah that starts in the middle of a page; At-Tawbah with no basmala;
  Al-Fatiha whose basmala is ayah 1.
- **Juz and hizb boundaries in the middle of a page**: the marker appears at the correct ayah, and
  index navigation lands on the page that contains it.
- **Sajdah ayat**: the 15 sajdah positions are marked as in the printed Mushaf.
- **Large system font or maximum text size**: the reading screen stays usable. Diacritics must
  never overlap or clip, and the interface must not overflow.
- **Small screens and display cut-outs**: the page fits within safe areas, with no text hidden
  behind notches or system bars.
- **Duplicate bookmark**: bookmarking the same ayah twice does not create a duplicate.
- **App ended by the system mid-reading**: the last position is still restored. It is saved as
  the user reads, not only when they leave the app.
- **Low device storage**: the app works without needing extra storage after install.
- **Screen reader enabled**: the reader can find their way through the index, controls and
  settings with labels in the interface language.
- **Switching language or layout mid-reading**: the reader stays at the same ayah, and direction
  icons (back, forward) mirror to match the interface direction. Page-turn direction inside the
  Mushaf stays the same in both languages (FR-004).
- **Device language neither Arabic nor English**: the interface falls back to English.
- **Small screens in Mushaf layout**: the page fits without horizontal scrolling. Text is smaller
  but never below what the screen needs to show the full page; readers who need larger text use
  the flowing layout.

## Requirements *(mandatory)*

### Functional Requirements

**Quran text and display**

- **FR-001**: The app MUST display the complete Quran (114 surahs, 6,236 ayat) in Uthmani script,
  narration of Hafs 'an 'Asim, matching the Madinah Mushaf published by the King Fahd Complex.
- **FR-002**: The Quran text MUST come from an authoritative, licensed source and be reproduced
  verbatim. No letter, diacritic or pause mark may be altered, dropped or substituted.
- **FR-003**: The app MUST offer two reading layouts, and users MUST be able to switch between them
  from the reading screen in one tap:
  - **Mushaf layout (default)**: page-faithful to the printed 604-page Madinah Mushaf, with the same
    lines per page, line breaks and page breaks. Text size is fixed to fit the screen.
  - **Flowing layout**: continuous text whose size the user can adjust (FR-017). It is still
    divided by surah and shows the page number of the printed Mushaf the reader is in.

  Switching layouts MUST keep the reader at the same ayah. The chosen layout MUST persist across
  restarts.
- **FR-004**: Page turning MUST follow the printed Arabic Mushaf convention: the next page lies to
  the left, and the reader swipes from left to right to move forward.
- **FR-005**: Each ayah MUST end with an ayah-end marker that shows its number in Eastern Arabic
  numerals (١٢٣).
- **FR-006**: Each surah start MUST show a surah header with its name, followed by the basmala.
  At-Tawbah has no basmala, and in Al-Fatiha the basmala is ayah 1.
- **FR-007**: Juz, hizb and quarter-hizb starts and the 15 sajdah positions MUST be marked at the
  correct ayat.
- **FR-008**: The reading screen MUST show the current surah name, juz number and page number at
  all times.

**Navigation**

- **FR-009**: Users MUST be able to open an index with three tabs: Surahs, Ajza' and Bookmarks.
- **FR-010**: The Surahs index MUST list all 114 surahs with number, name, ayah count, Makki/Madani
  type and starting page.
- **FR-011**: The Ajza' index MUST list all 30 ajza' with their hizb quarters (240 in total), each
  showing its opening words and starting page.
- **FR-012**: Users MUST be able to go directly to a page number or to a surah and ayah. Invalid
  input MUST show the valid range and not navigate.
- **FR-013**: The app MUST save the reading position continuously and reopen at that position on
  next launch.

**Bookmarks**

- **FR-014**: Users MUST be able to add a bookmark for the current page or a selected ayah, saved
  with surah, ayah, page and date added.
- **FR-015**: Users MUST be able to list bookmarks newest first, open one, and delete one. Adding
  the same ayah twice MUST NOT create a duplicate.

**Reading comfort**

- **FR-016**: The app MUST provide a day theme (cream "Mushaf paper" background) and a night theme,
  selectable as follow system, always day or always night.
- **FR-017**: In the flowing layout, users MUST be able to adjust the Quran text size from 18 to 34
  points. Line spacing MUST scale with the size so diacritics never
  collide.
- **FR-018**: Users MUST be able to enable keep-screen-on while the Mushaf is open.
- **FR-019**: All preferences MUST persist across restarts.

**Ayah actions and search**

- **FR-020**: A long press on an ayah MUST select it and offer copy, share and bookmark.
- **FR-021**: Copied or shared text MUST be the exact Uthmani text of the ayah followed by its
  reference: «سورة <name>: <ayah number>» in Arabic, or "Surah <name> <surah>:<ayah>" in
  English.
- **FR-022**: Users MUST be able to search the Quran text in Arabic. Matching MUST ignore
  diacritics, hamza and alef variants and the Uthmani-specific spellings. Results MUST show the
  ayah with the match highlighted, the surah and ayah number and the total count, and open the
  ayah in the Mushaf when tapped.

**Product, brand and platform**

- **FR-023**: The app MUST be named «مثاني» (Arabic) / "Mathani" (Latin) and published on both the
  Apple App Store and Google Play under the listing name «مثاني: تلاوة وتدبر المتشابه».
- **FR-024**: The visual identity (logo usage, app icon, colors, typography, iconography and tone of
  voice) MUST follow the Mathani brand guide (مثاني — دليل الهوية).
- **FR-025**: The interface MUST be available in Arabic (right-to-left) and English (left-to-right).
  - The language MUST follow the device language by default: Arabic for Arabic devices, English for
    all others. Users MUST be able to override it in settings.
  - The Quran text, ayah-end markers and Eastern Arabic ayah numbers inside the Mushaf MUST stay
    the same in both languages.
  - In English, surah names MUST show the transliterated name (for example, "Al-Baqarah") alongside
    the Arabic name.
  - The reference in shared ayat (FR-021) MUST follow the interface language.
  - Both App Store and Google Play listings MUST be provided in Arabic and English.
- **FR-026**: The full Mushaf, navigation, bookmarks, settings and search MUST work completely
  offline from first launch, without any download after installing.
- **FR-027**: The app MUST NOT require an account or sign-in, and MUST NOT collect personal data in
  this release. Bookmarks, reading position and preferences stay on the device.
- **FR-028**: Sections not yet built (recitations, Mutashabihat, prayer tools) MUST NOT appear as
  empty or "coming soon" entries.
- **FR-029**: All screens MUST meet the constitution's mobile requirements: phone portrait layout,
  safe areas, minimum touch targets, and screen-reader labels in the interface language.

### Key Entities

- **Surah**: one of 114 chapters. It has a number, an Arabic name, an ayah count, Makki/Madani type
  and a starting page.
- **Ayah**: a verse identified by surah and ayah number. It holds the exact Uthmani text and
  belongs to a page, a juz, a hizb quarter and possibly a sajdah position.
- **Mushaf Page**: one page of the Madinah Mushaf (604 total) and the ayat or ayah parts on it, in
  order.
- **Juz / Hizb Quarter**: the standard reading divisions (30 ajza', 60 ahzab, 240 quarters), each
  with a starting ayah and page.
- **Bookmark**: a saved location set by the user. It holds surah, ayah, page and date added.
- **Reading Position**: the last location the user read, saved automatically.
- **Reader Preferences**: reading layout (Mushaf or flowing), theme mode, Quran text size (flowing
  layout), keep-screen-on and interface language (follow device, Arabic or English).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the reference mid-range phone, the Mushaf is readable within 2 seconds of tapping
  the app icon from a cold start.
- **SC-002**: Page turns show the next page with no visible loading state or blank frame. This must
  hold for 100% of turns in a test reading all 604 pages.
- **SC-003**: An automated check against the authoritative source finds 0 differences across all
  6,236 ayat.
- **SC-004**: From the reading screen, any surah, juz, hizb quarter, page or surah-and-ayah can be
  reached in 3 taps or entries or fewer.
- **SC-005**: Reopening the app returns to the last page read in 100% of trials, including after
  the system force-quits the app.
- **SC-006**: Search results for any query appear within 1 second on the reference phone.
- **SC-007**: With network disabled from first launch, 100% of features in this release work.
- **SC-008**: The store download is 30 MB or less on each platform.
- **SC-009**: In a test with at least 10 readers, at least 9 can find a named ayah and bookmark it
  on their first try, with no help.
- **SC-010**: Switching between the Mushaf and flowing layouts, or between Arabic and English,
  keeps the same ayah in view in 100% of trials and takes effect within 1 second.
- **SC-011**: The app is accepted on first submission to both the App Store and Google Play, or any
  rejection is fixed within one resubmission.

## Assumptions

- The Mushaf edition is the Madinah Mushaf (King Fahd Complex), narration of Hafs 'an 'Asim. This
  is the most widely used edition in Egypt and the Arab world. Other narrations (qira'at) are out of
  scope.
- The Latin name is spelled **Mathani**, as the brand guide specifies. The guide marks "Matahni"
  in the request and on the old identity board as a typo.
- The brand guide at claude.ai (design system «مثاني — دليل الهوية») is the source of truth for
  visual design: navy `#183159`, gold `#BA9757`, cream `#F2EADD`, IBM Plex Sans Arabic for the
  interface, an Uthmani font for Quran text, and a derived night theme.
- A licence that permits redistribution in a free app will be obtained for the Quran text and any
  Mushaf font (for example, from the King Fahd Complex).
- Readers mainly use phones in portrait. Tablet and landscape layouts are not designed for this
  release (per the constitution).
- The brand guide defines Arabic (RTL) screens only. The English interface uses the same tokens,
  components and tone, mirrored left-to-right. The English interface font is chosen in the plan
  to pair with IBM Plex Sans Arabic.
- The English store listing name is a product decision for the owner before submission. A
  suggestion is "Mathani: Quran & Mutashabihat".
- The app is free with no ads in this release. Monetisation is not considered.
- No accounts and no cloud sync: all user data stays on the device. If a user deletes the app,
  their bookmarks and position are lost. This is acceptable for the first release.
- Minimum supported versions: **iOS 15.0+** and **Android 7.0 (API 24)+**, targeting Android API
  36 (see research R11).

## Out of Scope (Future Features)

These come from the same request and will each get their own specification. In this release they
MUST NOT appear in the app.

1. **Recitations with ayah sync**: audio by major Egyptian reciters (for example, Sheikh Mahmoud
   Khalil Al-Husary), with the recited ayah highlighted as it plays. This is the next feature.
2. **Mutashabihat study (تدبر المتشابه)**: comparing similar ayat side by side, highlighting the
   differing words, and explaining the differences. This is the app's core differentiator, as its
   store name shows.
3. **Qibla direction and prayer times.**
4. **Daily wird reminder**: a reminder at a time the user picks. Push via Google FCM was mentioned;
   a reminder scheduled on the device may meet the need without any server. This will be decided
   in that feature's spec.
5. Tafsir, translations, accounts and cloud sync, and tablet or landscape layouts.
