# Feature Specification: Prayer Times and Athan

**Feature Branch**: `009-prayer-times` (work so far is on `008-web-app`)

**Created**: 2026-10-29

**Rewritten**: 2026-11-02. This version replaces the first draft completely. The first draft is in
git history. The plan, research, data model, contracts, tasks and quickstart in this folder were
written for the first draft and must be regenerated from this one.

**Status**: Draft

**Input**: User description: "Introduce prayer times with multiple locations, calculation methods
and mazaheb. Detect location automatically, allow manual changes, and if possible use approximate
IP location when GPS is unavailable. Offer multiple athan recitations, optional Qiyam
notifications, and full athan or first takbirat playback."

**Scope of this spec**: Prayer times (مواقيت الصلاة) inside Mathani, with athan alerts. The Mushaf
stays the home screen. Prayer Times is a separate screen the reader opens when they want it.

1. **Schedule**: today's five prayers and sunrise for the reader's place, the next prayer and a
   countdown. Calculated on the phone, so it works offline.
2. **Place**: found from the phone's approximate location, picked by searching for a city, or
   suggested from the internet connection. The reader can save several places.
3. **Calculation**: the common official methods, the Asr setting that differs between the
   madhahib, and small per-prayer adjustments to match a local mosque.
4. **Alerts**: an alert at each prayer the reader turns on, with a choice of athan recitations.
   The alert plays the opening takbirat. The full athan is an option.
5. **Qiyam**: an optional reminder in the last third of the night.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See today's prayer times where I am (Priority: P1)

The reader opens Prayer Times for the first time. The app offers two ways to set their place: use
the phone's location, or search for a city. Once a place is set, they see today's times, which
prayer is next and how long until it starts. Next time, the schedule opens straight away, even
without internet.

**Why this priority**: Correct times for the right place are the whole feature. Everything else
builds on this.

**Independent Test**: Start with no saved place. Set a place once by location and once by city
search, and check the times against an independent reference for that city. Turn off internet,
reopen and check the schedule still shows.

**Acceptance Scenarios**:

1. **Given** no place is set, **When** the reader opens Prayer Times, **Then** they see "Use my
   location" and "Search for a city", with one line on why location is used. No permission is
   requested until they tap "Use my location".
2. **Given** the reader taps "Use my location" and allows it, **When** the place is found,
   **Then** the screen shows the place name, today's date, and the times of Fajr, Sunrise, Dhuhr,
   Asr, Maghrib and Isha.
3. **Given** a schedule is showing, **When** the reader looks at it, **Then** the next prayer is
   highlighted with a countdown. Sunrise is shown but marked as not a prayer.
4. **Given** the reader refuses location or it cannot be found, **When** the screen updates,
   **Then** it says so in one line and city search stays available. The app does not ask for
   location again by itself.
5. **Given** location is unavailable and the phone is online, **When** the reader opens city
   search, **Then** the app suggests a city based on their internet connection, labelled as an
   estimate. Nothing is set until the reader taps the suggestion or picks another city.
6. **Given** the reader types a city name in Arabic or English, **When** results appear, **Then**
   each shows its region and country so that same-named cities can be told apart.
7. **Given** a place is set and the phone is offline, **When** the reader opens Prayer Times,
   **Then** the schedule for today shows normally.
8. **Given** a schedule is showing, **When** the reader moves to the next or previous day,
   **Then** that day's times show.

---

### User Story 2 - Use the calculation my community follows (Priority: P1)

The reader chooses the calculation method used in their country, the Asr setting of their
madhhab, and, if needed, adds a few minutes to a prayer so the app matches their local mosque.

**Why this priority**: The reader will not trust the times, or turn on alerts, if they differ from
what their community follows.

**Independent Test**: For one place, change the method, the Asr setting and one adjustment. Check
each change against a reference and check it is kept after the app restarts.

**Acceptance Scenarios**:

1. **Given** a new place, **When** its schedule first appears, **Then** a method suited to its
   country is already selected and its name is visible on the schedule.
2. **Given** a schedule, **When** the reader opens calculation settings, **Then** they can choose
   any listed method and see the schedule update.
3. **Given** calculation settings, **When** the reader looks at the Asr setting, **Then** they
   see two choices: "Standard (Shafi'i, Maliki, Hanbali)" and "Hanafi", with a note that this
   changes Asr only.
4. **Given** the mosque near the reader calls Isha 5 minutes after the app's time, **When** the
   reader adds +5 minutes to Isha, **Then** Isha moves by 5 minutes, the schedule marks it as
   adjusted, and its alert moves with it.
5. **Given** a place far enough north or south that some times cannot be worked out normally,
   **When** its schedule shows, **Then** the affected times are calculated with a named
   high-latitude rule and marked as such. The reader can pick a different rule. A time that still
   cannot be worked out shows as unavailable and has no alert.

---

### User Story 3 - Keep the right place when I travel or save places (Priority: P2)

The reader chooses between "My location", which follows them when they travel, and a fixed city.
They can also save other places, such as home or family abroad, and look at their times.

**Why this priority**: Travellers would otherwise get alerts for the wrong city. Saved places are
useful but the feature works without them.

**Independent Test**: Use "My location", then simulate opening the app in a city in another time
zone. Check the schedule and alerts switch. Save three places in different time zones, switch
between them and restart the app.

**Acceptance Scenarios**:

1. **Given** "My location" is the current place, **When** the reader opens the app in a different
   city, **Then** the place, schedule and alerts update to the new city and a short message says
   so.
2. **Given** a fixed city is the current place, **When** the reader travels, **Then** nothing
   changes until they change it themselves.
3. **Given** saved places, **When** the reader views one that is not current, **Then** they see
   its times in its own time zone. Alerts keep following the current place until the reader taps
   "Use this place".
4. **Given** the current place is deleted, **When** the reader confirms, **Then** they choose
   another place or turn alerts off. No alert remains for the deleted place.
5. **Given** each saved place, **When** the reader changes its calculation settings, **Then** the
   change applies to that place only.

---

### User Story 4 - Get an athan alert at prayer time (Priority: P2)

The reader turns on alerts for the prayers they want and picks a recitation. At prayer time the
phone shows an alert and plays the opening takbirat, even when it is locked or the app is closed.

**Why this priority**: This is what turns a timetable into daily help.

**Independent Test**: Turn on two prayers, preview two recitations, lock the phone and wait for
each alert. Change the place and check that old alerts do not fire. Restart the phone and check
alerts still come.

**Acceptance Scenarios**:

1. **Given** alerts are off for every prayer, **When** the reader turns on Fajr, **Then** the app
   asks for notification permission at that moment if it does not have it yet.
2. **Given** the reader refused notifications, **When** they look at alert settings, **Then**
   their choices are kept, the screen says alerts are blocked, and it explains how to allow them.
3. **Given** the sound list, **When** the reader taps preview on a recitation, **Then** it plays
   with a Stop button. Starting another preview stops the first.
4. **Given** Dhuhr is on and the phone is locked, **When** Dhuhr starts, **Then** an alert names
   the prayer and the place and plays the chosen recitation's opening takbirat.
5. **Given** alerts are set, **When** the reader changes the place, a setting or a recitation,
   **Then** later alerts use the new choice. No alert fires twice and no old alert fires.
6. **Given** the reader does not open the app for 7 days, **When** each turned-on prayer starts,
   **Then** its alert still fires, including after the phone has restarted.
7. **Given** the phone was off at prayer time, **When** it turns on later, **Then** the missed
   alert does not fire late.
8. **Given** the reader taps an alert, **When** the app opens, **Then** it shows Prayer Times.

---

### User Story 5 - Hear the full athan (Priority: P3)

The reader can choose to hear the complete athan instead of only the opening takbirat.

**Why this priority**: Requested, but the alert in Story 4 is useful without it, and phones limit
how long an alert sound can play.

**Independent Test**: Choose full athan. Check it plays in full with the app open, with the phone
locked on Android, and after tapping the alert on iPhone. Start Quran recitation and wait for an
athan.

**Acceptance Scenarios**:

1. **Given** the reader chooses full athan, **When** they look at the setting, **Then** it says
   what happens on their device. On Android: the full athan plays even when the phone is locked.
   On iPhone: the alert plays the opening takbirat and the full athan plays when the alert is
   tapped or the app is open.
2. **Given** the app is open at prayer time, **When** the prayer starts, **Then** the full athan
   plays on both platforms.
3. **Given** the athan is playing, **When** the reader taps Stop in the app or in the
   notification, **Then** it stops immediately.
4. **Given** Quran recitation is playing in the app, **When** the app starts an athan, **Then**
   recitation pauses first and resumes only when the reader presses play.

---

### User Story 6 - Get a Qiyam reminder (Priority: P3)

The reader can turn on a nightly reminder for Qiyam al-Layl at the start of the last third of the
night.

**Why this priority**: Voluntary and off by default. It reuses Stories 1 and 4.

**Independent Test**: Turn on Qiyam for a known place and date, compare the shown time with the
last-third calculation, wait for the reminder, then turn it off and check prayer alerts are
unchanged.

**Acceptance Scenarios**:

1. **Given** a new install, **When** the reader opens alert settings, **Then** Qiyam is off and
   is separate from the five prayers.
2. **Given** the reader turns on Qiyam, **When** they look at it, **Then** they see tonight's
   reminder time and a note that it is the start of the last third of the night, from Maghrib to
   Fajr.
3. **Given** Qiyam is on, **When** the time comes, **Then** one reminder labelled Qiyam plays a
   short gentle tone, not an athan.
4. **Given** Qiyam is on, **When** the reader turns it off, **Then** only the Qiyam reminder
   stops.

---

### Edge Cases

- **Wrong estimate**: The internet-based suggestion can be wrong (VPN, mobile network). It is only
  a suggestion and never replaces a place by itself.
- **Search problems**: No results, ambiguous names or no internet each get a clear message and a
  retry. The current place is unchanged.
- **Time zones and clock changes**: A place's times always use that place's time zone, including
  daylight-saving days. If the phone's time zone differs from the place, the screen says which
  time zone the times are in. Changing the phone's clock or time zone updates the countdown and
  alerts.
- **Midnight**: After Isha, the next prayer is tomorrow's Fajr.
- **Far north or south**: Covered in Story 2, scenario 5. Qiyam is skipped on a night with no
  valid Maghrib or Fajr, and the screen says why.
- **Phone settings that block alerts**: If the phone is muted, in do-not-disturb, saving battery,
  or blocking exact alarms, alerts may be silent or late. Where the app can detect this, it says
  so and explains how to fix it. It never promises sound the phone will block.
- **No sound file yet**: If a chosen recitation is not on the phone yet, alerts use the simple
  tone until it is, and the setting says so.
- **Removing the last place**: Prayer Times returns to the first-time screen and all alerts stop.

## Requirements *(mandatory)*

### Functional Requirements

**Schedule**

- **FR-001**: Prayer Times MUST show Fajr, Sunrise, Dhuhr, Asr, Maghrib and Isha for the selected
  day, highlight the next of the five prayers, and show a countdown to it. Sunrise MUST be marked
  as not a prayer and MUST NOT have an alert.
- **FR-002**: The schedule MUST show the place name, the date, the calculation method and the Asr
  setting. Times changed by an adjustment or a high-latitude rule MUST be marked.
- **FR-003**: Times MUST be in the place's own time zone, correct on daylight-saving days.
- **FR-004**: Times MUST be calculated on the phone and MUST be available offline for every saved
  place.
- **FR-005**: The reader MUST be able to move to the next and previous days.

**Place**

- **FR-006**: "Use my location" MUST ask for location permission only when tapped, and only for
  approximate (city-level) location. The app MUST NOT ask for precise or background location.
- **FR-007**: The reader MUST be able to search for a city in Arabic or English, with region and
  country shown for each result, whether or not location permission was given.
- **FR-008**: When location is unavailable and the phone is online, city search MUST offer a city
  estimated from the internet connection, labelled as an estimate, used only if the reader taps
  it.
- **FR-009**: "My location" MUST update when the app is opened or brought back to the screen, and
  MUST NOT track location at any other time. A fixed city MUST NOT change unless the reader
  changes it.
- **FR-010**: The reader MUST be able to save, rename, view and delete several places. Exactly one
  place is current, and alerts follow it. Viewing another place MUST NOT change the current place.

**Calculation**

- **FR-011**: The reader MUST be able to choose at least these methods: Muslim World League,
  Egyptian General Authority of Survey, Umm al-Qura (Makkah), University of Islamic Sciences
  (Karachi), ISNA (North America), Dubai, Kuwait, Qatar, Singapore, Turkey (Diyanet) and
  Moonsighting Committee. Each method MUST follow its published conventions, including seasonal
  rules such as Umm al-Qura's longer Isha in Ramadan.
- **FR-012**: A new place MUST start with the method commonly used in its country, which the
  reader can change.
- **FR-013**: The Asr setting MUST offer "Standard (Shafi'i, Maliki, Hanbali)" and "Hanafi", and
  explain that it changes Asr only.
- **FR-014**: Where normal calculation fails because of latitude, a high-latitude rule MUST be
  applied and named, with at least two rules to choose from. A time that still cannot be
  calculated MUST show as unavailable and MUST NOT have an alert.
- **FR-015**: The reader MUST be able to adjust each of the five prayers by up to 30 minutes
  earlier or later.
- **FR-016**: Method, Asr setting, high-latitude rule and adjustments MUST be saved per place.
  Changes MUST update the schedule and future alerts straight away.

**Alerts**

- **FR-017**: The reader MUST be able to turn alerts on or off for each of the five prayers. All
  MUST be off at first.
- **FR-018**: Notification permission MUST be requested only when the reader turns on an alert.
  If it is refused, choices MUST be kept and the screen MUST say alerts are blocked and how to
  allow them.
- **FR-019**: The sound choices MUST include at least two athan recitations, a simple tone, and
  silent. Each MUST have a preview with Stop. Only one preview MUST play at a time. One choice
  applies to all five prayers.
- **FR-020**: An alert MUST name the prayer and the place, play the chosen sound (the opening
  takbirat for a recitation), and open Prayer Times when tapped.
- **FR-021**: Alerts MUST fire with the app closed and the phone locked, and after the phone
  restarts, for at least 7 days without the app being opened.
- **FR-022**: After any change to place, settings or sound, every later alert MUST use the new
  choice. No alert MUST fire twice, for an old setting, or after it was missed.
- **FR-023**: Sounds used by alerts MUST be on the phone before they are relied on. Until a chosen
  recitation is available, alerts MUST use the simple tone and the setting MUST say so.

**Full athan**

- **FR-024**: The reader MUST be able to choose full athan instead of the opening takbirat. With
  the app open, the full athan MUST play on both platforms. On Android it MUST also play with the
  phone locked or the app closed. On iPhone, the alert MUST play the opening takbirat and the full
  athan MUST play when the alert is tapped. The setting MUST state the behaviour for the reader's
  device.
- **FR-025**: Whenever the app plays an athan, Stop MUST be available in the app and in the
  notification.
- **FR-026**: Before the app plays an athan, Quran recitation MUST pause. It MUST NOT resume by
  itself. A short alert sound played by the phone's own notification system may briefly overlap
  recitation.

**Qiyam**

- **FR-027**: Qiyam MUST be a separate reminder, off at first, at the start of the last third of
  the night between Maghrib and the next Fajr for the current place. Its next time MUST be shown.
  It MUST use a short tone, not an athan. Turning it on or off MUST NOT change prayer alerts.

**Web**

- **FR-028**: In the web app, schedule, places, calculation settings, city search, the
  internet-based estimate and previews MUST work. Alerts MUST work only while the page is open
  and the browser allows them. The settings MUST say this and point to the mobile apps.

**Privacy**

- **FR-029**: Location MUST be used only to set a place. The app MUST keep only the city-level
  position of saved places, no movement history. Positions MUST be sent off the phone only to look
  up a place name and time zone. The reader MUST be able to delete all saved places.
- **FR-030**: The feature MUST NOT add accounts, analytics or ads.

**Quality**

- **FR-031**: Prayer Times MUST be reachable within two taps from the reader. Nothing from this
  feature MUST run before the Mushaf appears, and the app MUST NOT ask for any permission at
  startup.
- **FR-032**: The feature MUST work in Arabic and English, right-to-left and left-to-right, light
  and dark themes, large text, VoiceOver and TalkBack, with touch targets of at least 44×44 pt on
  iPhone and 48×48 dp on Android. It targets iOS 15.0+ and Android 7.0 (API 24)+.

### Key Entities *(include if feature involves data)*

- **Place**: name, city, region, country, city-level position, time zone, how it was set
  (location, search or estimate), calculation settings. One place is current, or the current
  place is "My location".
- **Calculation settings**: method, Asr setting, high-latitude rule, per-prayer adjustments.
  Belong to one place.
- **Day schedule**: one place's six times for one date, each marked normal, adjusted or
  unavailable, plus that night's Qiyam time.
- **Alert settings**: prayers turned on, chosen sound, opening or full athan, Qiyam on or off.
  Shared by all places.
- **Athan recitation**: name, reciter, opening takbirat clip, full recording, source and licence.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new reader sees their schedule within 30 seconds with "Use my location", and
  within 60 seconds with city search.
- **SC-002**: For 10 cities, each listed method and both Asr settings, including daylight-saving
  days and a high-latitude city in summer, every shown time is within 1 minute of an independent
  reference using the same settings.
- **SC-003**: On one iPhone and one Android phone, locked, at least 19 of 20 alerts per phone fire
  within 1 minute of the shown time, using the chosen sound.
- **SC-004**: After 10 changes to place, settings and sound, no alert fires twice or for an old
  setting. Alerts still fire after a phone restart and on day 7 without opening the app.
- **SC-005**: Three places in three time zones keep their settings, and the current place stays
  correct, across 10 restarts, switches and deletions.
- **SC-006**: In 5 nights for different places, the Qiyam time is within 1 minute of the
  last-third calculation.
- **SC-007**: Cold start stays at or under 2 seconds on the reference phones, taps respond within
  100 ms, and the schedule scrolls at 60 fps. Store download growth is reported, and any growth
  over 1 MB is explained.
- **SC-008**: Every story can be completed with VoiceOver and with TalkBack, in Arabic and in
  English.

## Assumptions

- **One current place**: Alerts follow one place. Alerts for several places at once, cloud sync
  and background location tracking are out of scope.
- **Opening takbirat**: The opening takbirat means the first four "Allahu akbar", ending before
  the shahada. Each recitation needs a clip cut at that point.
- **iPhone limit**: iPhone plays at most 30 seconds of sound for an alert, and only the app can
  play longer audio. This is why Story 5 behaves differently on iPhone. It is a platform limit,
  recorded as an accepted parity gap under constitution Principle I.
- **Recordings**: At least two athan recordings that Mathani may redistribute are needed. On
  2026-11-02, one candidate (Al-Husary) has been reviewed and its rights are not yet confirmed.
  This blocks FR-019, not Stories 1 to 3.
- **Mosque timetables**: Calculated times may differ from a local mosque. Per-prayer adjustments
  are the remedy. Iqama times are out of scope.
- **City-level location only**: City-level position (about 1 km) is enough for prayer times; a
  1 km shift changes times by a few seconds. Because no precise position is kept, saved places are
  not treated as sensitive data under the constitution's secure-storage rule. If this reading is
  rejected, saved places need secure storage on phones and the web needs its own exception.
- **Online lookups**: City search, the internet-based estimate and updating "My location" need an
  internet connection, through Mathani's existing web host. Calculation does not.
- **Web**: The web app from feature 008 is included with the limits in FR-028.
- **Out of scope**: Qibla direction, Hijri calendar, home-screen widgets, reminders before prayer
  time, Jumu'ah-specific reminders, imsak and suhoor times, and per-prayer recitation choices.
