# Feature Specification: Two-Page Spread on Foldable Phones

**Feature Branch**: `012-foldable-two-page`

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "I want the app to start supporting iPhone Duo. When Folded, one page
view. When Open, two pages view"

**Scope of this spec**: The Mushaf (page) layout on a foldable phone. Folded, the phone shows one
page, exactly as today. Open, it shows two facing pages side by side, like a printed Mushaf
lying open. The flowing layout, and every other screen, keep their current design. They must
still work on the open screen. They do not get a new wide design.

Apple released the iPhone Duo in September 2026. It has a 5.4-inch outer screen with a
phone shape. Inside is a 7.6-inch screen, about 10:7, that is wider than it is tall when the phone
is open. On that inner screen iOS does not keep an app in portrait, so the app's portrait lock
no longer holds there. Android book-style foldables, such as the Galaxy Z Fold, have the same
folded and open shapes. Under constitution principle I they get the same behaviour.

This is the "tablet or landscape support" that constitution principle II requires a spec to opt into.
Specs 001, 002 and 005 listed tablet and landscape layouts as out of scope. This spec adds the
two-page spread only. It does not add a general tablet design.

## Clarifications

### Session 2026-11-04

- Q: Should a wide browser window (for example a desktop) also show two pages, or only the phone
  apps? → A: The same size rule applies in browsers. A wide window shows two pages, and a narrow
  one shows one (FR-016).
- Q: Should there be a setting to keep one page on the open phone? → A: Yes. A setting, on by
  default (FR-017).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read two facing pages on the open phone (Priority: P1)

A reader opens their foldable phone in the Mushaf layout. Two pages appear side by side, like an
open printed Mushaf. The odd page is on the right and the even page is on the left. Pages 1 and 2
(Al-Fātiḥa and the opening of Al-Baqara) face each other as in print. The page edges meet in the
middle, where a printed Mushaf is bound. Swiping from left to right turns to the next two pages.
Swiping from right to left turns back.

**Why this priority**: This is the request. Without it the open screen shows one page, stretched
across or lost in empty space, and the large screen is wasted.

**Independent Test**: On an open foldable (or a simulator of one), open the Mushaf at page 50 and
check that pages 49 (right) and 50 (left) show side by side. Swipe forward and check 51 and 52.
Go to page 1 and check that pages 1 and 2 show. Go to page 604 and check that pages 603 and 604
show.

**Acceptance Scenarios**:

1. **Given** the phone is open in the Mushaf layout, **When** the reader is on page 50, **Then**
   page 49 shows on the right and page 50 on the left, both whole and the same size.
2. **Given** pages 49–50 are shown, **When** the reader swipes from left to right, **Then** pages
   51–52 show. **When** they swipe from right to left from 49–50, **Then** pages 47–48 show.
3. **Given** the reader is on the first two pages, **When** they look at them, **Then** page 1
   is on the right and page 2 on the left. There is no blank page before page 1 or after page 604.
4. **Given** any two pages are shown, **When** the reader looks at the middle, **Then** the two
   page edges show the binding shade where the pages meet, and the outer edges have none.
5. **Given** any two pages are shown, **When** the reader looks at each page, **Then** each has
   its own surah, juz and page number details, hizb marks and sajdah marks, as on a single page.

---

### User Story 2 - Fold and unfold without losing the place (Priority: P1)

The reader is reading on the open phone and folds it, for example to keep reading with one
hand. The page they were reading is the page shown on the outer screen. Later they unfold the
phone, and the two pages that hold that page appear. They never land on a different page.

**Why this priority**: A foldable phone is folded and unfolded many times while reading. Losing
the place each time would make the two-page spread worse than no support.

**Independent Test**: Open at page 77, fold, and check that page 77 shows. Unfold and check that
pages 77–78 show. Long-press an ayah on page 78, close the actions, fold, and check that page 78
shows.

**Acceptance Scenarios**:

1. **Given** the phone is folded on page 120, **When** the reader opens it, **Then** pages 119–120
   show.
2. **Given** pages 119–120 are shown and the reader has not touched either, **When** they fold the
   phone, **Then** page 119 shows (the right-hand page, where reading starts).
3. **Given** pages 119–120 are shown and the reader's place is on page 120 (an ayah there is
   selected, was just jumped to, or is being recited), **When** they fold the phone, **Then**
   page 120 shows.
4. **Given** the reader folds or unfolds the phone, **When** the screen settles, **Then** the
   reader's saved position is the same as before, and the app reopens there next time.

---

### User Story 3 - Everything that works on one page works on two (Priority: P1)

On the two-page spread, the reader does everything they do on one page, on either page:
long-press an ayah for its actions, see a selected or highlighted ayah, follow a recitation,
memorize with hidden words and marks, see mutashabihat in their colour, open «عرض المتشابه»,
bookmark, and show or hide the controls with a tap.

**Why this priority**: Without these, the spread would only be for looking at pages. The reader
would have to fold the phone to do anything else.

**Independent Test**: On the open phone, long-press an ayah on the left page and check that its
actions open for that ayah. Start a recitation that crosses from the right page to the left page
and on to the next two pages. Check that the recited ayah is followed without turning while it
stays on the shown two pages, and that the spread turns when it moves on to page 3 of the
sequence.

**Acceptance Scenarios**:

1. **Given** two pages are shown, **When** the reader long-presses an ayah on either page,
   **Then** the actions for that ayah open, and the ayah shows as selected on its page.
2. **Given** a recitation reaches the last ayah of the right page, **When** it moves on to the
   left page, **Then** the pages do not turn and the recited ayah is marked on the left page.
   **When** it moves past the left page, **Then** the next two pages show.
3. **Given** a memorization session covers both shown pages, **When** the reader recites, **Then**
   hidden words, hints and mistakes show on both pages as they do on one.
4. **Given** the reader jumps to an ayah from the index, search or a bookmark, **When** the two
   pages that hold it show, **Then** the ayah is highlighted on its page.
5. **Given** two pages are shown, **When** the reader taps either page, **Then** the controls show
   or hide, as on one page.
6. **Given** two pages are shown, **When** the reader looks at the header, **Then** it shows both
   page numbers (for example «صفحة ٤٩–٥٠»), and the surah and juz of the reader's place.
7. **Given** two pages are shown, **When** the reader taps the bookmark button, **Then** the
   reader's page (FR-010) is bookmarked. The button shows as filled when either shown page has a
   bookmark, and tapping it then removes the bookmarks on both.
8. **Given** two pages are shown, **When** the reader taps Listen or Memorize, **Then** it starts
   from the reader's place on the spread, or from the right-hand page when no ayah is selected.

---

### User Story 4 - Regular phones and the folded phone see no change (Priority: P1)

Readers on regular phones, and readers on a folded foldable phone, see the same single page they
see today. It has the same size, the same margins and the same page turns.

**Why this priority**: Almost all readers use regular phones. The feature must not cost them
anything.

**Independent Test**: Compare the Mushaf on the reference phones of specs/001 and specs/002
before and after the feature. The pages, text size and page turns are identical.

**Acceptance Scenarios**:

1. **Given** a regular phone held upright, **When** the reader opens the Mushaf, **Then** one page
   shows, with the same text size and margins as before this feature.
2. **Given** the open foldable phone shares the screen with another app (side by side), **When**
   the reader's part of the screen is too narrow for two pages, **Then** one page shows.

---

### Edge Cases

- The reader unfolds the phone partly (a "tent" or "laptop" pose): the app follows the screen
  area it is given. If two pages fit, two show. Otherwise one shows.
- The phone opens or folds during a page-turn swipe: the swipe is cancelled, and the reader's
  place is kept as in User Story 2.
- The phone opens or folds while the ayah actions, the similar-ayat overlay, a sheet or the
  onboarding hints are open: they stay open and keep working. The pages behind them switch
  between one and two.
- The reader switches to the flowing layout on the open phone: the flowing text fills the screen
  as it does today. When they switch back, the two pages that
  hold their place show.
- A page fails to load (a browser with no connection, specs/008): that page shows its retry
  message. The other page of the spread shows normally.
- Screen readers: each page is announced on its own, as today. The right page comes first, then
  the left page.
- The keyboard on the web and on Android foldables with a keyboard (FR-016): the arrow and page
  keys turn two pages at a time.
- The app is open on the outer screen with the system text size at its largest: one page, as
  today.

## Requirements *(mandatory)*

### Functional Requirements

**When two pages show**

- **FR-001**: In the Mushaf layout, with the setting of FR-017 on, the app MUST show two facing
  pages when both fit side by side with each page's text at least 70% of the size one page would
  have on the same screen, and no smaller than a minimum readable size set in the plan.
  Otherwise it MUST show one page. The decision MUST depend only on the size of the whole screen
  (the browser window on the web), never on the phone model. It MUST NOT change when the system
  bars, the recitation bar or the memorization bar appear or go.
- **FR-002**: The decision MUST be made again whenever the reading area changes size: when the
  phone folds or opens, when the screen is shared with another app, and when a browser window is
  resized (FR-016).
- **FR-003**: When one page shows, it MUST look and behave exactly as before this feature.

**The two-page spread**

- **FR-004**: The spreads MUST be pages 1–2, 3–4, … 603–604: the odd page on the right and the even
  page on the left, as in the printed Madinah Mushaf. There MUST be no blank page.
- **FR-005**: Both pages MUST be the same size and MUST each keep the proportions, text size rules
  and page details of specs/002 (surah, juz and page number, hizb and sajdah marks).
- **FR-006**: Where the two pages meet, each page MUST show the binding shade of specs/002 on its
  inner edge. The outer edges MUST have none.
- **FR-007**: Swiping MUST turn two pages at a time, in the Mushaf's direction (feature 001 FR-004):
  from left to right goes forward. Jumps from the index, search, bookmarks, the go-to sheet and a
  followed recitation MUST show the spread that holds the target page.
- **FR-008**: Everything that works on a single page MUST work on either page of the spread:
  long-press and right-click actions, selection, the jump highlight, recitation marking and
  following, memorization marks, mutashabihat colouring and «عرض المتشابه», and tap to show or hide
  the controls.
- **FR-009**: A recitation or memorization session MUST NOT turn the pages while its current ayah
  is on either shown page. It MUST turn to the next spread when the ayah moves past the left page.

**The reader's place**

- **FR-010**: The reader's place MUST be one page, as today. When two pages show, the place is the
  right-hand page. It is the left-hand page only when the selected ayah, the jumped-to ayah or the
  ayah being recited is on the left page.
- **FR-011**: Opening the phone MUST show the spread that holds the reader's page. Folding it MUST
  show the reader's page. The saved reading position MUST NOT change because the phone opened or
  folded.

**Controls**

- **FR-012**: The header MUST show both page numbers when two pages show (e.g. «صفحة ٤٩–٥٠» /
  "Pages 49–50"). The surah and juz MUST follow the reader's place, as today.
- **FR-013**: The bookmark button MUST show as filled when either shown page has a bookmark.
  Tapping it MUST bookmark the reader's page when neither has one, and MUST remove the bookmarks
  on both pages when one has.
- **FR-014**: Listen and Memorize MUST start from the reader's place, as they do on one page.
- **FR-015**: The controls, sheets and other screens MUST keep working on the open screen and MUST
  respect its safe areas. They keep their current phone design. No new wide design is required.

**Scope**

- **FR-016**: The web app (specs/008) MUST follow the same rule (FR-001, FR-002): a browser window
  wide enough for two pages shows two, a narrower one shows one, and resizing the window switches
  between them while keeping the reader's place (FR-011).
- **FR-017**: Settings MUST have a switch, «عرض صفحتين عند الاتساع» / "Two pages when there is
  room", on by default. When it is off, the Mushaf layout always shows one page. The switch MUST
  be saved with the other reading preferences, and changing it MUST keep the reader's place.
  The switch MUST appear only while the reading area is wide enough for two pages, so readers on
  regular phones and folded phones never see a setting that does nothing for them.

### Key Entities

- **Spread**: two facing pages shown together, identified by its odd (right-hand) page. There are
  302 spreads.
- **Two-page preference**: the FR-017 switch, on by default, saved with the reading preferences.
- **Reader's page**: the one page that holds the reader's place (FR-010). It is saved and restored
  as today, and it decides which spread shows on the open phone and which page shows on the
  folded phone.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On an open iPhone Duo and an open Galaxy Z Fold (or their simulators), every one of
  the 302 spreads shows the correct two pages, odd on the right, with no blank or repeated page.
- **SC-002**: In 20 folds and 20 opens at random pages, the reader's page is on screen after each
  change, every time, within 1 second of the screen settling.
- **SC-003**: The text on each page of the spread is at least 90% of the size of the single page
  on the same phone's folded screen.
- **SC-004**: Turning to the next or previous spread shows both pages complete, with no blank frame
  (the same bar as feature 001 SC-002).
- **SC-005**: On the reference phones of specs/001 and specs/002, the single page is pixel-identical
  to before this feature, and page-turn speed and memory use are unchanged.
- **SC-006**: Every acceptance scenario of User Story 3 passes on both pages of a spread, with
  VoiceOver and TalkBack on and off.
- **SC-007**: In a desktop browser, resizing the window across the two-page width switches
  between one and two pages, with the reader's page on screen after each switch.

## Assumptions

- Minimum supported versions stay iOS 15.0 and Android 7.0 (API 24). The iPhone Duo runs iOS 27,
  and apps fill its inner screen only when built with the iOS 27 tools. The app's builds must use
  them. On older iOS and Android versions the feature only applies where the reading area is
  wide enough, which on regular phones it never is.
- The app stays an iPhone app on iOS. iPad support is out of scope. On Android the same size rule
  applies to every device. An Android tablet held sideways, which recent Android versions no
  longer keep in portrait, also gets two pages. This follows from FR-001 and is accepted.
- The app stays portrait-locked on regular phones and on folded phones. On the open phone and on
  other large screens, the app turns with the device, so an open Galaxy Z Fold held sideways
  also shows two pages. The iPhone Duo's inner screen ignores the lock anyway.
- The flowing layout and the other screens are not redesigned for the open screen (FR-015).
- The single page's binding shade stays as it is today (right edge on odd pages). In the spread,
  the shade follows FR-006 so that the edges meet in the middle.
- The onboarding illustrations keep showing one page.
- Page turns on the spread use the same swipe and animation as single pages. A page-curl effect is
  not part of this feature.
