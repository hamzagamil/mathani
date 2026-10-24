# Feature Specification: Onboarding

**Feature Branch**: `005-app-onboarding`

**Created**: 2026-10-24

**Status**: Draft

**Input**: User description: "I want to add an onboarding that walks user through the app and teaches
him about options. It should also helps him set his/her own prefrences before starting and he can
skip the onboarding."

**Scope of this spec**: A short first-run experience for new readers. It has two parts. First, the
reader sets their preferences: language, theme, reading layout (with text size for the flowing
layout) and reciter. Second, a tour shows how to use the app. Illustrated screens teach the
gestures (turning pages, tapping the page for the controls, long-pressing an ayah); then the Mushaf
opens and hints over the real screen point at the buttons (index and bookmarks, search, recitation
player, Settings). The reader can skip at any moment. They can open the tour again later from
Settings. Readers who already use Mathani see the full onboarding once after updating, with their
current preferences selected. Today the only first-run help is the one-time hint "Tap the page to
show controls" (feature 002); this feature replaces it.

## Clarifications

### Session 2026-10-24

- Q: Which tour style? → A: A mix. Illustrated screens for gestures (swipe, tap, long-press), shown
  before the Mushaf opens; hints over the real reading screen for buttons (index, search, player,
  Settings) (FR-014, FR-017).
- Q: Do readers updating from 1.3.0 or earlier see the onboarding? → A: Yes, the full onboarding,
  once, with their current preferences selected and their reading position kept (FR-001, FR-005,
  FR-007).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Set my preferences before I start reading (Priority: P1)

A reader opens Mathani for the first time. Before the Mushaf appears, a few short screens ask how
they want to read. They choose the app language, the theme (follow the device, day or night) and
the reading layout (the printed Mushaf page or flowing text, with a text size for flowing text).
They choose a reciter and can hear a short sample of each. Each choice takes effect on the spot, so
they see what they picked. When they finish, the Mushaf opens set up the way they chose.

**Why this priority**: The request asks for this directly. A reader who starts with the wrong
language, a bright screen at night or the wrong layout may never find Settings, and may leave.

**Independent Test**: On a fresh install, open the app. Choose English, Night, Flowing with a larger
text size, and El-Minshawi. Finish. The reader opens in English, at night, in the flowing layout
at that size. Play any ayah and hear El-Minshawi. Settings shows the same choices.

**Acceptance Scenarios**:

1. **Given** a fresh install, **When** the reader opens the app, **Then** the onboarding starts
   before the Mushaf, without any network connection needed.
2. **Given** the language step, **When** the reader picks Arabic or English, **Then** the rest of
   the onboarding is shown in that language and its direction (right to left for Arabic) at once.
3. **Given** each preference step, **When** the reader opens it, **Then** the app's current default
   is already selected, so continuing without changing it keeps the default.
4. **Given** the theme or layout step, **When** the reader changes the choice, **Then** a preview on
   the same screen shows the result at once.
5. **Given** the reader chose the flowing layout, **When** they continue, **Then** they can set the
   text size, with a preview of an ayah at that size. If they chose the Mushaf layout, this step
   does not appear.
6. **Given** the reciter step with a connection, **When** the reader taps a reciter's sample,
   **Then** a short recitation plays in that voice; tapping it again stops it. Without a
   connection, the sample is unavailable, a short note says so, and the reader can still choose.
7. **Given** the reader went back to an earlier step, **When** they change a choice there, **Then**
   the later steps keep the choices already made.
8. **Given** the reader finishes, **When** the Mushaf opens, **Then** every choice is in effect and
   is shown the same way in Settings.

---

### User Story 2 - Skip the onboarding (Priority: P1)

A reader who knows Quran apps, or who just wants to start reading, skips the onboarding. One tap
takes them straight to the Mushaf. The onboarding does not come back on its own.

**Why this priority**: The request names it. Forcing every reader through every step would slow
down the readers who need it least, and each extra step loses some of them.

**Independent Test**: On a fresh install, tap Skip on the first screen. The Mushaf opens on page 1
with the default settings. Close and reopen the app: the Mushaf opens directly. Repeat, choosing
Night on the theme step before skipping: the Mushaf opens at night.

**Acceptance Scenarios**:

1. **Given** any onboarding screen, **When** the reader looks at it, **Then** a Skip action is
   visible and reachable with one hand.
2. **Given** the reader taps Skip, **When** the onboarding closes, **Then** the Mushaf opens at once
   with no confirmation, and the defaults apply for anything the reader did not choose.
3. **Given** the reader made some choices before skipping, **When** the Mushaf opens, **Then** those
   choices are kept.
4. **Given** the reader finished or skipped the onboarding, **When** they open the app again, **Then**
   the onboarding does not appear, and the app opens where they stopped reading.
5. **Given** the reader skipped during the preference steps, **When** they reach the Mushaf, **Then**
   the tour is skipped too.

---

### User Story 3 - Learn how to use the app (Priority: P2)

After setting preferences, the reader gets a short tour of what Mathani can do and how. First,
illustrated screens show the gestures: how to turn pages, tap the page to show or hide the
controls, and long-press an ayah to play from it, bookmark, copy or share it. Then the Mushaf opens
with its controls showing, and hints over the real screen point at each button in turn: the index
of surahs, juz and bookmarks; search; the recitation player and downloading surahs for offline
listening; and Settings for more options. Each stop is short: one idea and one or two sentences.
The reader moves through it at their own pace and can leave it at any stop.

**Why this priority**: Several of Mathani's most useful actions are hidden behind gestures, such as
tapping the page for the controls or long-pressing an ayah. Readers who do not find them think the
app cannot do them. Stories 1 and 2 are still useful without the tour.

**Independent Test**: Give a fresh install to someone who has never used Mathani. They finish the
onboarding, put the phone away, and are then asked, without help, to show the controls, turn to
the next page, play from the third ayah on the page, bookmark it, find it in the bookmarks and
search for a word. They succeed at each.

**Acceptance Scenarios**:

1. **Given** the reader finished the preference steps, **When** the tour starts, **Then** it covers,
   in order: turning pages, showing the controls, the ayah actions (play, bookmark, copy, share), the
   index and bookmarks, search, the recitation player and downloads, and Settings.
2. **Given** a tour stop, **When** the reader looks at it, **Then** it shows the stop's number and
   the total (for example, 3 of 7), with next, back and skip.
3. **Given** a gesture stop, **When** the reader views it, **Then** an illustration or short
   animation shows the gesture in a way the reader can follow without reading the text, and the
   text says it for screen reader users.
4. **Given** the reader chose the flowing layout, **When** a gesture stop shows the reading screen,
   **Then** it shows the flowing layout, not the Mushaf page, and the same for the Mushaf layout.
5. **Given** the last gesture stop, **When** the reader taps next, **Then** the Mushaf opens with its
   controls showing, and the first button hint points at the real index button.
6. **Given** a button hint, **When** the reader views it, **Then** the real control is highlighted
   and the rest of the screen is dimmed; tapping next moves to the next hint and does not open the
   control or turn the page.
7. **Given** the last button hint, **When** the reader taps the final action, **Then** the hints go
   away, the reader is left on the reading screen, and the one-time "Tap the page to show
   controls" hint does not appear.
8. **Given** any tour stop, **When** the reader skips, **Then** the tour ends at once and the reader
   is on the reading screen.

---

### User Story 4 - See the tour again later (Priority: P3)

A reader who skipped the onboarding, or who has forgotten something, opens Settings and starts the
tour again. The gesture screens come first, then the button hints on their reading screen, at the
page they were reading. Their reading position and preferences do not change.

**Why this priority**: It gives readers who skipped a way back. It is small, and everything else
works without it.

**Independent Test**: Skip the onboarding. Read to page 200. Open Settings and choose to see the
tour. Go through it and finish. The reader is on page 200 with the same preferences and bookmarks.

**Acceptance Scenarios**:

1. **Given** Settings, **When** the reader looks at it, **Then** it has an action to see the tour
   again.
2. **Given** the reader starts the tour from Settings, **When** it opens, **Then** it shows the tour
   stops only, not the preference steps, because the same choices are already on the Settings
   screen.
3. **Given** the gesture stops end, **When** the button hints start, **Then** they appear on the
   reading screen at the page the reader was on.
4. **Given** the reader finishes or skips the tour from Settings, **When** it closes, **Then** they
   are on the reading screen at the same page, and their bookmarks and preferences are unchanged.

---

### Edge Cases

- **Closed during the onboarding**: The reader closes the app or the system ends it partway through.
  Choices already made are kept. The next launch opens the onboarding again, at the first step,
  with those choices selected, until the reader finishes or skips it.
- **Language changed mid-way**: The reader picks a language, then goes back and picks another. The
  onboarding switches language and direction at once and keeps the reader on the same step.
- **Device language neither Arabic nor English**: The language step preselects the app's existing
  fallback for the "follow the device" choice, and names it, so the reader understands what they
  will get.
- **Sample playing when leaving the step**: A reciter sample stops when the reader leaves the
  reciter step, skips, or the app goes to the background. It never keeps playing in the Mushaf.
- **Slow or absent connection**: No step waits for the network. A sample that cannot load within a
  few seconds stops trying and shows the note from Story 1, scenario 6.
- **Large system font, screen reader, dark mode**: Every step stays readable and usable at the
  largest system font size, with VoiceOver or TalkBack, and in dark mode before the reader has
  chosen a theme. Text never clips; long text scrolls within the step.
- **Back navigation**: The platform's back gesture or button goes to the previous step. On the first
  step it follows the platform's normal behaviour (on Android, leaving the app), and the
  onboarding is not marked as done.
- **Tour opened from Settings while a recitation plays**: The recitation keeps playing. The button
  hints include the player as it is showing; the tour does not change what is being recited, and
  the Mushaf does not turn pages under a hint (any page turn waits until the hints are gone).
- **Readers updating from 1.3.0 or earlier**: They see the full onboarding once, on the first launch
  after the update. Each preference step shows their current choice, so continuing changes
  nothing. When it ends, finished or skipped, the reader is on the page where they stopped
  reading, with all bookmarks and downloads kept.
- **Updating reader whose stored choice is no longer offered**: For example, a reciter removed in
  a later version. The step preselects the app's default, as Settings already does.
- **Controls hidden during the button hints**: The controls stay visible for as long as the hints
  are showing, even in the Mushaf layout, where they usually hide.

## Requirements *(mandatory)*

### Functional Requirements

**First run and completion**

- **FR-001**: The app MUST show the onboarding, before the reader sees the Mushaf, on its first
  launch after a fresh install and on its first launch after updating from a version without
  onboarding (1.3.0 or earlier).
- **FR-002**: The app MUST remember that the onboarding was finished or skipped, and MUST NOT show
  it again on its own after that.
- **FR-003**: If the app is closed before the onboarding is finished or skipped, the next launch
  MUST show it again from the first step, with the choices already made selected.
- **FR-004**: The onboarding MUST work fully with no network connection, except for reciter
  samples.
- **FR-005**: On finishing or skipping the first-run onboarding, the reader MUST be on the reading
  screen, in the layout they chose (or the default): on page 1 after a fresh install, or on the
  page where they stopped reading after an update. Bookmarks and downloads MUST be kept.

**Preference steps**

- **FR-006**: The onboarding MUST let the reader choose, in this order: the app language (follow the
  device, Arabic, English), the theme (follow the device, day, night), the reading layout (Mushaf,
  flowing) and, when the layout is flowing, the text size, and the reciter (Al-Husary,
  El-Minshawi).
- **FR-007**: Each preference step MUST open with the current value selected: the app's default on
  a fresh install, and the reader's saved choice after an update.
- **FR-008**: Each choice MUST take effect as soon as it is made, and MUST be saved as soon as it is
  made, exactly as if it were changed in Settings.
- **FR-009**: The theme, layout and text size steps MUST show a preview of the result on the same
  screen.
- **FR-010**: The reciter step MUST offer a short sample for each reciter when a connection is
  available, which the reader can start and stop. Without a connection it MUST say that samples
  need a connection and MUST still allow choosing.
- **FR-011**: A reciter sample MUST stop when the reader leaves the step, skips, finishes, or the
  app goes to the background.
- **FR-012**: The preference steps MUST NOT include options the Settings screen does not offer, and
  any choice made in them MUST show the same way in Settings afterwards.
- **FR-013**: Keep-screen-on, printed lettering and downloads MUST NOT be onboarding steps; the tour
  MUST mention that these and other options are in Settings.

**Tour**

- **FR-014**: The tour MUST cover, one idea per stop: turning pages; tapping the page to show and
  hide the controls; long-pressing an ayah for play, bookmark, copy and share; the index of surahs,
  juz and bookmarks; search; the recitation player and downloading surahs for offline listening;
  and Settings.
- **FR-015**: Each tour stop MUST show its position and the total number of stops, and offer next,
  back and skip.
- **FR-016**: The tour MUST show the reading layout the reader chose.
- **FR-017**: The tour MUST teach gestures (turning pages, tapping the page for the controls,
  long-pressing an ayah) with illustrated screens before the reading screen appears, and buttons
  (index and bookmarks, search, recitation player and downloads, Settings) with hints over the
  real reading screen, each highlighting the real control.
- **FR-017a**: While button hints are showing, the reading controls MUST stay visible, the page MUST
  NOT turn, and the next action MUST NOT trigger the highlighted control.
- **FR-018**: Once the reader finishes or skips the tour, the one-time "Tap the page to show
  controls" hint from feature 002 MUST NOT appear.

**Skip**

- **FR-019**: Every onboarding screen, preference steps and tour alike, MUST offer Skip, visible
  without scrolling and reachable with one hand.
- **FR-020**: Skip MUST end the whole onboarding in one tap, without a confirmation, and MUST keep
  any choices already made.

**Replay from Settings**

- **FR-021**: Settings MUST offer an action to see the tour again.
- **FR-022**: The tour opened from Settings MUST show only the tour stops, with the button hints on
  the reading screen at the reader's current page. It MUST end on the reading screen at that page
  when finished or skipped, without changing the reading position, bookmarks, preferences or an
  ongoing recitation.

**Platform, accessibility and performance**

- **FR-023**: The onboarding MUST be available in Arabic and English, follow the direction of the
  chosen language, and use the app's existing look in day and night themes.
- **FR-024**: Every step MUST be usable with VoiceOver and TalkBack, at the largest system font
  size, and in portrait on phones; touch targets MUST be at least 44×44 pt (iOS) and 48×48 dp
  (Android).
- **FR-025**: Back navigation MUST follow each platform's convention: back goes to the previous
  step; on the first step it does what back does on the app's first screen.
- **FR-026**: The first onboarding screen MUST meet the app's cold-start budget (interactive within
  2 seconds on the reference device), and moving between steps MUST respond within 100 ms of the
  tap.
- **FR-027**: The feature MUST work on iOS 15.0+ and Android 7.0 (API 24)+, as feature 001.

### Key Entities

- **Onboarding status**: Whether the reader has finished or skipped the first-run onboarding. Kept
  on the device with the other preferences. Decides whether the onboarding shows at launch. A
  reader updating from a version without it has no status yet, so they see the onboarding once.
- **Reader preferences** (existing, from features 001 and 004): language, theme, layout, flowing
  text size and reciter. The onboarding sets them; it adds no new reading preference. It stores
  only its own status (above).
- **Tour stop**: One idea taught in the tour, with its title, a short explanation, and the picture
  or real control it points to. The set of stops is fixed in the app.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new reader can go through the whole onboarding, preferences and tour, in under 2
  minutes, and through the preference steps alone in under 45 seconds.
- **SC-002**: A reader can leave the onboarding from any screen with exactly one tap.
- **SC-003**: In 100% of test runs, every preference chosen in the onboarding is in effect on the
  first Mushaf page and matches Settings, including after the app is restarted.
- **SC-004**: After the onboarding is finished or skipped, it appears 0 times on later launches
  unless the reader opens it from Settings.
- **SC-005**: In a usability test with at least 5 first-time readers who finished the onboarding,
  at least 4 of 5 can, without help, show the controls, play from a chosen ayah, bookmark an ayah
  and find it again, and search for a word.
- **SC-006**: Time from tapping the app icon to the first onboarding screen being usable is no
  longer than the app's current cold start to the Mushaf (2 seconds on the reference device).
- **SC-007**: With the network off from the first launch, every onboarding step except the reciter
  samples works, and the reader reaches the Mushaf.
- **SC-008**: The feature adds less than 1 MB to the store download.
- **SC-009**: In 100% of update test runs from 1.3.0, the onboarding appears once, and afterwards
  the reading position, bookmarks, downloads and preferences are the same as before the update
  (unless the reader changed a preference during the onboarding).

## Assumptions

- The preference steps cover only the choices most readers want to make before they start:
  language, theme, layout (with text size for flowing) and reciter. Keep-screen-on, printed
  lettering and downloads stay in Settings, which the tour points to.
- Default values are the ones the app already uses on a fresh install. The onboarding adds no new
  reading preference and changes no default; it stores only whether it was done.
- The Mushaf opens on page 1 after a fresh-install onboarding, as it does on a fresh install today;
  after an update it opens where the reader stopped.
- The button hints point at controls that already exist on the reading screen. Downloads have no
  button of their own, so the player hint mentions that surahs can be downloaded from the Surahs
  index or the player.
- Reciter samples are a few seconds of an existing ayah recording (for example, Al-Fatiha, ayah 1),
  streamed like any recitation. Like any streamed ayah, the file is kept only in the existing
  recent-recitations cache; nothing else is downloaded or stored for the onboarding.
- Skipping does not ask "Are you sure?". The tour is always available again from Settings, so
  skipping by mistake costs nothing.
- The onboarding sends no data anywhere and adds no analytics. SC-001 and SC-005 are measured in
  usability tests, not in the app.
- The onboarding is phone-only, portrait, like the rest of the app (constitution, Principle II).
- Pictures and animations are small vector drawings or real screens of the app, in line with
  Principle IV.

## Out of Scope

- An account, sign-in or cloud sync of preferences.
- Asking for notification or other permissions during the onboarding. Recitations need none today;
  a later feature that does (such as the daily wird reminder) asks in context.
- "What's new" screens after later updates. Readers updating from 1.3.0 see the onboarding once;
  after that, updates show nothing.
- Onboarding for features not yet built, such as Mutashabihat study, Qibla and prayer times, or the
  daily wird reminder. Their own specs add tour stops when they ship.
- Tablet and landscape layouts.
