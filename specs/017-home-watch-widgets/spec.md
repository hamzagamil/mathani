# Feature Specification: Home Screen and Watch Widgets

**Feature Branch**: `017-home-watch-widgets` (not created yet)

**Created**: 2026-11-22

**Status**: Draft

**Input**: User description: "I want the app to have widgets for iphone and watch. Research for
android widgets for phones and watches as I dont have much info about them"

**Scope of this spec**: Mathani already knows three things a reader wants to see without opening
the app: when the next prayer is (specs/009), what today's wird is (specs/014), and where they
stopped reading (specs/001). This feature puts them on the surfaces outside the app:

1. **Phone home screen**: widgets on iPhone and Android phones.
2. **Phone lock screen**: small widgets on the iPhone lock screen, and on Android phones whose
   system offers lock screen widgets.
3. **Watch face and watch glance views**: complications on the watch face and cards in the watch's
   glance view (Smart Stack on Apple Watch, widgets/tiles on Wear OS watches).

Tapping a widget opens the right place in the app. Widgets only show what the app already holds;
they add no new data, no account and no network request of their own.

The platform research that the user asked for (what Android phones, Wear OS watches, iPhone and
Apple Watch allow, and on which OS versions) is in [research-platforms.md](research-platforms.md).
specs/009 listed home screen widgets as out of scope; this feature delivers them.

## Clarifications

### Session 2026-11-22

- Q: What should a tap on the watch complication or card do, given that both watch platforms
  need a Mathani part installed on the watch? → A: Open a small Mathani screen on the watch that
  shows today's prayer times only (User Story 4, FR-021).
- Q: Should Wear OS ship in the same release as Apple Watch? → A: Yes, Apple Watch and Wear OS
  together, as constitution Principle I requires (FR-024).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the next prayer on my home screen (Priority: P1)

The reader adds a Mathani prayer widget to their phone's home screen. It shows the next prayer,
its time and how long until it starts, for the place set in Prayer Times. A larger size shows all
of today's times with the next one marked. The widget moves on to the following prayer by itself
when a prayer time passes, without the app being opened.

**Why this priority**: Prayer times are checked several times a day. A glance at the home screen
is the most-used shortcut a Quran and prayer app can offer, and it is the most requested kind of
widget in this category.

**Independent Test**: Set a place in Prayer Times, add the widget in each size on an iPhone and an
Android phone, close the app, and watch the widget across a prayer time. Compare the times to the
Prayer Times screen.

**Acceptance Scenarios**:

1. **Given** a place is set in Prayer Times, **When** the reader adds the prayer widget, **Then**
   it shows the next prayer's name, its time and the time left, the same as the Prayer Times
   screen.
2. **Given** the widget shows a prayer, **When** that prayer's time passes while the app is
   closed, **Then** within one minute the widget shows the following prayer.
3. **Given** the last prayer of the day has passed, **When** the reader looks at the widget,
   **Then** it shows tomorrow's Fajr.
4. **Given** no place is set yet, **When** the reader adds the widget, **Then** it says that a
   place is needed, and tapping it opens Prayer Times at the place setup.
5. **Given** the reader changes the place or the calculation method in the app, **When** they go
   back to the home screen, **Then** the widget shows the new times.
6. **Given** any prayer widget, **When** the reader taps it, **Then** the app opens on Prayer
   Times.

---

### User Story 2 - Continue reading or open today's wird in one tap (Priority: P1)

The reader adds a Quran widget. If they have a personal khatma, it shows today's wird (where it
starts and ends) and how far the khatma is. If not, it shows where they last stopped reading
(surah, page, juz). One tap opens the Mushaf at that page.

**Why this priority**: Reading the Quran is what Mathani is for. A widget that turns "open the
app, find my place" into one tap supports the daily reading habit that specs/014 is built around.

**Independent Test**: Read to a page, leave the app, add the widget, and check it shows that page
and opens it. Then start a khatma and check the widget switches to the wird and its progress.

**Acceptance Scenarios**:

1. **Given** the reader has no active khatma and has read before, **When** they look at the Quran
   widget, **Then** it shows the surah, page and juz where they stopped, and a tap opens the Mushaf
   at that page.
2. **Given** an active personal khatma with a wird waiting, **When** they look at the widget,
   **Then** it shows the wird's start and end and the khatma's progress, and a tap opens the
   Mushaf at the khatma place (the same as "Read" on the Khatma screen).
3. **Given** today's wird is read, **When** they look at the widget, **Then** it says today's wird
   is done and shows the progress; a tap opens the Khatma screen.
4. **Given** the reader has never opened the Mushaf, **When** they add the widget, **Then** it
   offers to start reading and a tap opens the first page.
5. **Given** the reader reads on in the app, **When** they return to the home screen, **Then** the
   widget shows the new place.

---

### User Story 3 - Glance at the lock screen (Priority: P2)

On the lock screen, the reader sees the next prayer and the time left, or their khatma progress,
in a small widget that suits the lock screen's style.

**Why this priority**: The lock screen is seen more often than the home screen, but it only takes
small, simple widgets, and on Android it is only on some phones. It builds on Stories 1 and 2.

**Independent Test**: Add each lock screen widget on an iPhone (iOS 16 or later), lock the phone,
and check it across a prayer time and after reading.

**Acceptance Scenarios**:

1. **Given** an iPhone on iOS 16 or later, **When** the reader edits the lock screen, **Then**
   they can add the next-prayer widget and the khatma progress widget.
2. **Given** a lock screen widget, **When** the phone is locked, **Then** it shows only prayer
   names, times and progress; it never shows bookmark notes or group khatma names.
3. **Given** the reader taps a lock screen widget, **When** the phone unlocks, **Then** the app
   opens on the same screen the home screen widget opens.
4. **Given** an Android phone whose system offers lock screen widgets, **When** the reader adds
   the Mathani widget there, **Then** it behaves as on the home screen. On phones without this,
   nothing is offered and nothing breaks.

---

### User Story 4 - See the next prayer on my watch (Priority: P2)

The reader who wears an Apple Watch or a Wear OS watch adds Mathani to the watch face. A
complication shows the next prayer and the time left. A larger card in the watch's glance view
shows today's times. It keeps working through the day even when the phone is not nearby.

**Why this priority**: The user asked for watch widgets. A watch is where people look for the
time, so the next prayer fits there well. It ranks below the phone widgets because fewer readers
own a watch and it needs more work on each platform.

**Independent Test**: With a place set on the phone, add the complication and the card on an
Apple Watch and a Wear OS watch. Put the phone out of range and check the watch moves on to the
next prayer at the right time.

**Acceptance Scenarios**:

1. **Given** a place is set on the phone, **When** the reader adds the Mathani complication to a
   watch face, **Then** it shows the next prayer and the time left, the same as the phone.
2. **Given** the watch has received today's schedule, **When** the phone is out of range or off,
   **Then** the watch still moves on to each next prayer on time for at least the rest of the day
   and the next 6 days.
3. **Given** the reader changes the place or method on the phone, **When** the watch is next in
   range, **Then** the watch shows the new times within 15 minutes.
4. **Given** no place is set on the phone, **When** the complication is added, **Then** it shows a
   neutral Mathani mark and the card says to set a place in Mathani on the phone.
5. **Given** the larger card, **When** the reader looks at it, **Then** it shows today's five
   prayers with the next one marked.
6. **Given** the complication or the card, **When** the reader taps it, **Then** a small Mathani
   screen opens on the watch with today's five prayer times, the next one marked, and the place
   name. It has no other screens or settings; changes are made on the phone.
7. **Given** that watch screen, **When** no place is set on the phone or the watch has no times for
   today, **Then** it says to open Mathani on the phone.

---

### User Story 5 - Khatma progress on my watch (Priority: P3)

The reader with a personal khatma sees on the watch whether today's wird is done and how far the
khatma is.

**Why this priority**: Useful as a daily nudge, but reading happens on the phone, so it is less
important than the prayer complication.

**Independent Test**: With an active khatma, add the khatma complication, read the wird on the
phone, and check the watch shows it as done.

**Acceptance Scenarios**:

1. **Given** an active personal khatma, **When** the reader adds the khatma complication, **Then**
   it shows the khatma's progress and whether today's wird is waiting or done.
2. **Given** the reader finishes today's wird on the phone, **When** the watch is next in range,
   **Then** the complication shows the wird as done within 15 minutes.
3. **Given** no active khatma, **When** the complication is on the face, **Then** it shows a
   neutral Mathani mark rather than an empty or broken view.

---

### Edge Cases

- **App not opened for days**: prayer widgets still move from prayer to prayer and day to day,
  because the app gives them a schedule several days ahead. When that schedule runs out, the widget
  says "Open Mathani to update" rather than showing old times as if they were correct.
- **Time zone change or travel**: when the phone's time zone changes and the place follows the
  device location, the widget shows the old place's times until the app updates them, and labels
  the place it is showing, so the reader is never misled about which city the times are for.
- **Clock change (daylight saving)**: times stay correct across the change.
- **Language and direction**: widgets follow the app's language (Arabic or English) and numerals
  setting, and Arabic widgets lay out right to left.
- **Dark mode, tinted and clear home screens**: widgets stay readable in light and dark mode and in
  the tinted or clear styles that iOS 18 and Android themed icons apply.
- **Large text**: with system font scaling at its largest, the text either fits or the widget
  shows less (for example the next prayer only), never clipped text.
- **Screen readers**: VoiceOver and TalkBack read each widget as one clear sentence, for example
  "Asr at 3:12 PM, in 1 hour 5 minutes".
- **App deleted, reinstalled or data cleared**: widgets left on the home screen show the "set
  up" state, never another reader's data or a crash.
- **Khatma ended or paused**: the Quran widget goes back to "continue reading", and the khatma
  watch complication shows the neutral mark.
- **Group khatma**: widgets show only the personal khatma. Group khatma names and parts are never
  shown on a widget, because widgets can show on a lock screen and a watch that others can see.
- **Web app**: the web app (specs/008) has no widgets; nothing in this feature changes it.
- **Watch not paired or app not installed on the watch**: the phone app works the same; nothing
  asks the reader to install a watch part.
- **Battery saver and Doze**: under battery saver the system may update widgets less often. The
  prayer widget's next-prayer change still happens on time because it comes from the schedule
  already given, not from a fresh update.

## Requirements *(mandatory)*

### Functional Requirements

**Common to all widgets**

- **FR-001**: Widgets MUST show only data the app already holds on the device: the prayer
  schedule for the reader's place, the personal khatma's wird and progress, and the last reading
  place.
- **FR-002**: Widgets MUST NOT make network requests, need an account, or ask for any permission
  the app does not already have.
- **FR-003**: Widgets MUST NOT show bookmark notes, group khatma names or any text another person
  typed.
- **FR-004**: Every widget MUST open a specific screen in the app when tapped: Prayer Times for
  prayer widgets, the Mushaf at the right page for reading widgets, the Khatma screen when the wird
  is done.
- **FR-005**: Widgets MUST follow the app's language, numerals and direction settings, and MUST
  update within one minute of the reader changing them in the app.
- **FR-006**: Widgets MUST be readable in light mode, dark mode and the system's tinted styles, and
  with the largest system text size, and MUST give screen readers one complete sentence.
- **FR-007**: Each widget MUST have a clear "not set up" state with one line telling the reader
  what to do, and tapping it MUST open the screen where that is done.
- **FR-008**: Widgets MUST NOT show stale times as current. When a widget has no valid schedule
  for the present moment, it MUST say "Open Mathani to update".
- **FR-009**: Widgets MUST NOT cause any background work beyond what the system needs to redraw
  them, and MUST NOT keep the app running in the background.

**Phone home screen**

- **FR-010**: The app MUST offer a prayer widget on iPhone and Android in a small size (next
  prayer, time and time left) and a medium size (all of today's times, next one marked).
- **FR-011**: The prayer widget MUST move on to the following prayer at each prayer time without
  the app being opened, for at least 7 days after the app last ran.
- **FR-012**: The app MUST offer a Quran widget on iPhone and Android in a small size (last place,
  or today's wird) and a medium size (also showing khatma progress when a khatma is active).
- **FR-013**: The Quran widget MUST show today's wird when a personal khatma is active and a wird
  is waiting, "today's wird is done" when it is read, and the last reading place otherwise.
- **FR-014**: The widgets MUST appear in each phone's widget picker with a name, a short
  description and a preview in Arabic and English.

**Phone lock screen**

- **FR-015**: On iPhones with iOS 16 or later, the app MUST offer lock screen widgets for the next
  prayer and for khatma progress.
- **FR-016**: On Android phones whose system offers lock screen widgets, the Mathani widgets MUST
  either work there as on the home screen or be kept off the lock screen; they MUST NOT appear
  broken there.

**Watch**

- **FR-017**: On Apple Watch and Wear OS watches, the app MUST offer a watch face complication for
  the next prayer and a larger glance card for today's times.
- **FR-018**: The watch MUST hold at least 7 days of prayer times once it has received them, so
  that it keeps showing the right next prayer with the phone out of range.
- **FR-019**: Changes made on the phone (place, method, language, khatma progress) MUST reach the
  watch within 15 minutes of the watch next being in range.
- **FR-020**: The app MUST offer a khatma complication on both watch platforms showing progress
  and whether today's wird is waiting or done.
- **FR-021**: A tap on any watch complication or card MUST open a small Mathani screen on the
  watch showing today's prayer times, the next one marked, and the place name. The watch part
  MUST NOT offer other screens, settings or audio; everything else stays on the phone.

**Platforms and versions**

- **FR-022**: Phone widgets MUST work on iOS 15.0+ (home screen) and iOS 16.0+ (lock screen), and
  on Android 7.0 (API 24)+, the app's current minimums. Newer looks (tinted, clear) MUST be used
  where the OS has them.
- **FR-023**: Watch widgets MUST state their minimum versions in the plan; the target is the
  oldest watchOS and Wear OS versions that still receive updates and allow complications plus a
  glance card (see research-platforms.md).
- **FR-024**: Apple Watch and Wear OS support MUST ship in the same release, with the same
  complications, card and watch screen on both (constitution Principle I). Neither watch part may
  ship while the other is missing or known to be broken.

### Key Entities

- **Widget snapshot**: what the app hands to widgets each time something changes: the place name,
  prayer times for the coming days, the calculation method's name, the personal khatma's wird
  (start, end), progress and whether today's wird is read, the last reading place, the language
  and numerals setting, and when the snapshot was made. It holds nothing typed by other people.
- **Watch copy**: the part of the widget snapshot sent to the watch (prayer times for at least 7
  days, place name, khatma progress), kept on the watch until a newer one arrives.
- **Widget kind**: prayer (small, medium, lock screen, watch complication, watch card), Quran
  (small, medium), khatma progress (lock screen, watch complication). Each has a "not set up"
  state and a tap destination.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On both phone platforms, the prayer widget shows the same next prayer and time as the
  Prayer Times screen in 100% of checks, including across midnight and a daylight saving change.
- **SC-002**: With the app closed, the prayer widget changes to the following prayer within 1
  minute of each prayer time in at least 99% of transitions over a 7-day test.
- **SC-003**: A reader goes from the home screen to reading today's wird in 1 tap, compared with at
  least 3 taps today.
- **SC-004**: With the phone out of range, the watch shows the correct next prayer for 7 days.
- **SC-005**: Phone changes reach the watch within 15 minutes of reconnecting in 95% of checks.
- **SC-006**: Widgets add no measurable battery drain: over 24 hours with each widget placed, the
  app's battery share reported by the system rises by less than 1 percentage point.
- **SC-007**: Within 60 days of release, at least 15% of monthly active phone readers have at
  least one Mathani widget placed (measured with the anonymous usage statistics of specs/016).
- **SC-008**: Every widget passes a VoiceOver and TalkBack check and a largest-text check with no
  clipped text.
- **SC-009**: The store download grows by no more than 1 MB per phone platform for the phone
  widgets (the watch part is downloaded only to watches).

## Assumptions

- **Content**: the widgets cover prayer times, the personal khatma and continue reading, because
  these are what Mathani already computes and what readers check daily. An "ayah of the day"
  widget, a Hijri date, Qibla, and audio controls are out of scope for this feature.
- **No interactive buttons in v1**: widgets open the app on tap; marking a wird as read or playing
  a recitation from a widget is out of scope. The tap opens the right screen instead.
- **Prayer times are computed on the phone** and handed to widgets and the watch as a schedule.
  The watch does not compute times or use its own location.
- **Data stays on the device**: phone to watch transfer uses the platform's own private link
  between paired devices. No Mathani server is involved, consistent with specs/009 and specs/014.
- **Reference devices**: the phone reference devices from earlier specs (iPhone SE 2nd gen, Galaxy
  A15). Watch reference devices are named in the plan.
- **Minimum OS versions**: phones keep iOS 15.0 and Android 7.0 (API 24). Lock screen widgets on
  iPhone need iOS 16; tinted styles need iOS 18; these are shown only where available.
- **Analytics**: whether a widget is placed is counted with the existing anonymous usage
  statistics (specs/016), with no new identifiers.
- **Dependencies**: specs/009 (prayer times), specs/014 (personal khatma), specs/001 (last reading
  place) and specs/016 (anonymous usage statistics).
