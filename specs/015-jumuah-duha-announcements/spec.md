# Feature Specification: Jumu'ah Alerts, Duha Reminder and Announcements

**Feature Branch**: `015-jumuah-duha-announcements` (not created yet)

**Created**: 2026-11-20

**Status**: Draft

## Clarifications

### Session 2026-11-20

- Q: Is the Jumu'ah reminder off until turned on, or on by default? → A: On for readers who have
  the Dhuhr alert on (FR-005).
- Q: When does the Duha reminder fire: start of Duha or the best time? → A: The best time, halfway
  between Sunrise and Dhuhr (FR-008).

**Input**: User description: "I want to add a special text for Jumaa prayer to notify the user 20
mins before prayer. Jumaa prayer notification for prayer and the 20 mins pre-prayer should say
(Jumaa) instead of Dhuhr prayer. Add an option to enable notifications for Duha prayer. (This needs
a research on when the notification should fire.) Enable the admin to send custom notifications
from Google FCM (later on, the notifications should be sent to segments instead of all users as a
setting from the admin)."

**Scope of this spec**: Three additions to the prayer alerts from feature 009, plus a new channel
for messages from the Mathani team.

1. **Jumu'ah**: on Fridays the Dhuhr alert is named Jumu'ah, and the reader can get a reminder 20
   minutes before it, also named Jumu'ah.
2. **Duha**: an optional reminder for the Duha prayer, at a time based on the research summarised
   in this spec.
3. **Announcements**: the Mathani team (the admin) can write a message in Google's push
   notification console and send it to every installed copy of the app.
4. **Later, not in this spec**: sending announcements to chosen groups of readers instead of
   everyone.

Feature 009 listed "reminders before prayer time" and "Jumu'ah-specific reminders" as out of
scope. This spec brings in only the Jumu'ah reminder. Reminders before other prayers stay out of
scope.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Friday alerts say Jumu'ah (Priority: P1)

On Friday, the alert at Dhuhr time says it is time for Jumu'ah prayer, not Dhuhr prayer. The
reader does not change any setting for this.

**Why this priority**: It is a text change to an alert that already exists. It is the smallest
part of this spec, and readers notice a Friday alert that says Dhuhr.

**Independent Test**: Turn on the Dhuhr alert. Set the phone to a Friday shortly before Dhuhr and
check the alert's text. Repeat on a Thursday and check it still says Dhuhr.

**Acceptance Scenarios**:

1. **Given** the Dhuhr alert is on and it is Friday at the place, **When** Dhuhr time comes,
   **Then** the alert's title names Jumu'ah prayer ("Time for Jumu'ah prayer" / "حان وقت صلاة
   الجمعة"). The body and the athan sound stay the same as on other days.
2. **Given** the Dhuhr alert is on and it is not Friday at the place, **When** Dhuhr time comes,
   **Then** the alert names Dhuhr, as it does today.
3. **Given** the Dhuhr alert is off, **When** Friday Dhuhr comes, **Then** no Jumu'ah alert is
   shown.
4. **Given** the reader opens Prayer Times on a Friday, **When** they look at the schedule,
   **Then** the midday prayer is labelled Jumu'ah, with the same time Dhuhr would have.

---

### User Story 2 - A reminder 20 minutes before Jumu'ah (Priority: P1)

The reader turns on a Jumu'ah reminder. Every Friday, 20 minutes before Dhuhr time, they get a
reminder that names Jumu'ah, so they have time to get ready and go to the mosque.

**Why this priority**: This is the main new behaviour the reader asked for. Going to Jumu'ah early
is encouraged, and the reminder gives time to prepare.

**Independent Test**: Turn on the Jumu'ah reminder for a known place. On a Friday, check that the
reminder arrives 20 minutes before Dhuhr time and names Jumu'ah. Check no reminder arrives on
other days.

**Acceptance Scenarios**:

1. **Given** a new install or an update from an earlier version, **When** the reader opens the
   Alerts settings, **Then** they see a Jumu'ah reminder setting, separate from the five prayers,
   that says it comes 20 minutes before Jumu'ah. It is on if the Dhuhr alert is on, and off if
   the Dhuhr alert is off.
7. **Given** the reader has never changed the Jumu'ah reminder and the Dhuhr alert is off,
   **When** they turn on the Dhuhr alert, **Then** the Jumu'ah reminder turns on too. **Given**
   the reader has changed the Jumu'ah reminder themselves, **When** they turn the Dhuhr alert on
   or off, **Then** the Jumu'ah reminder stays as they set it.
2. **Given** the Jumu'ah reminder is on, **When** it is Friday and 20 minutes remain until Dhuhr
   time, **Then** one reminder arrives with a title that names Jumu'ah ("Jumu'ah prayer in 20
   minutes" / "صلاة الجمعة بعد ٢٠ دقيقة") and a short gentle tone, not an athan.
3. **Given** the Jumu'ah reminder is on, **When** it is not Friday, **Then** no reminder arrives.
4. **Given** the reader has added minutes to Dhuhr to match their mosque, **When** Friday comes,
   **Then** the reminder comes 20 minutes before the adjusted time.
5. **Given** the Jumu'ah reminder is on, **When** the reader turns it off, **Then** only that
   reminder stops. The Dhuhr alert is unchanged.
6. **Given** the reader taps the reminder, **When** the app opens, **Then** it shows Prayer Times
   for that place.

---

### User Story 3 - A Duha reminder (Priority: P2)

The reader turns on a daily reminder for the Duha prayer. It arrives at the time described below
and is labelled Duha.

**Why this priority**: Duha is a voluntary prayer and the reminder is optional. It follows the same
pattern as the Qiyam reminder from feature 009.

**When the reminder fires (research summary)**:

- **Start of Duha**: Duha begins once the sun has risen "the height of a spear" above the horizon,
  after the short period after sunrise in which prayer is disliked. Scholars put this at about 12
  to 15 minutes after sunrise (for example Ibn Baz: "about a quarter of an hour"). Egypt's Dar
  al-Ifta and many prayer calendars use 20 minutes, which also covers the shorter estimates.
- **End of Duha**: Duha ends shortly before the sun reaches its highest point, a few minutes (often
  given as 5 to 10) before Dhuhr.
- **Best time**: the hadith "صلاة الأوابين حين ترمض الفصال" (Sahih Muslim 748), "the prayer of
  those who turn to Allah is when the young camels feel the heat of the sun". Scholars explain this
  as about a quarter of the daytime having passed, which is roughly halfway between sunrise and
  Dhuhr.
- **Reminder time**: the reminder fires at the best time, halfway between Sunrise and Dhuhr. For
  example, with Sunrise at 06:10 and Dhuhr at 11:50, it fires at 09:00.

**Independent Test**: Turn on the Duha reminder for a known place and date. Check that the shown
time matches the rule above, wait for the reminder, then turn it off and check prayer alerts are
unchanged.

**Acceptance Scenarios**:

1. **Given** a new install or an update, **When** the reader opens the Alerts settings, **Then**
   Duha is off and is separate from the five prayers, like Qiyam.
2. **Given** the reader turns on Duha, **When** they look at it, **Then** they see today's reminder
   time and one line explaining it (for example "Halfway between sunrise and Dhuhr, the best time
   for Duha").
3. **Given** Duha is on, **When** the time comes, **Then** one reminder labelled Duha arrives with
   a short gentle tone, not an athan.
4. **Given** Duha is on, **When** the reader turns it off, **Then** only the Duha reminder stops.
5. **Given** Duha is on and the reader has adjusted Sunrise or Dhuhr by some minutes, **When** the
   reminder time is worked out, **Then** it uses the adjusted times.
6. **Given** Duha is on, **When** it is Friday, **Then** the Duha reminder still arrives as on
   other days.

---

### User Story 4 - The Mathani team sends an announcement (Priority: P2)

The admin writes a title and a message in Google's push notification console and sends it. Readers
who have the app installed and allow notifications get it on their phone, even when the app is
closed.

**Why this priority**: It lets the team tell readers about new features, Ramadan or Khatma events
and important fixes without a new release. It needs a new service and store privacy updates, so it
is more work than Stories 1 to 3.

**Independent Test**: Install the app on one iPhone and one Android phone and allow notifications.
Send a test message from the console to everyone. Check it arrives on both phones with the app
open, in the background and fully closed. Turn announcements off in the app, send again and check
nothing arrives.

**Acceptance Scenarios**:

1. **Given** the app is installed and notifications are allowed, **When** the admin sends a message
   to all readers, **Then** it arrives as a phone notification with the admin's title and text,
   whether the app is open, in the background or closed.
2. **Given** the app is open when an announcement arrives, **When** it arrives, **Then** the reader
   still sees it, without it interrupting reading or recitation.
3. **Given** the admin adds a Mathani link (from feature 014) to the message, **When** the reader
   taps the notification, **Then** the app opens at that link's destination. **Given** there is no
   link, **When** the reader taps it, **Then** the app opens as normal.
4. **Given** the reader opens Settings, **When** they look for notifications, **Then** they find an
   "Announcements from Mathani" setting, on by default, with one line saying what it is for.
5. **Given** the reader turns announcements off, **When** the admin sends a message, **Then** the
   reader does not get it. Prayer alerts and reminders are unaffected.
6. **Given** announcements are a separate kind of notification, **When** the reader opens the
   phone's notification settings for Mathani, **Then** they can silence announcements without
   silencing prayer alerts (where the phone supports separate kinds).
7. **Given** the reader has never allowed notifications, **When** the app starts, **Then** it does
   not ask for permission just for announcements. Announcements reach the reader once they allow
   notifications, for example when they turn on a prayer alert or the Announcements setting.

---

### Edge Cases

- **Friday by the place's clock**: "Friday" means Friday at the place whose times are used, not
  where the phone thinks it is. A reader with a fixed city in another time zone gets the Jumu'ah
  label on that city's Friday.
- **Dhuhr unavailable**: If Dhuhr cannot be worked out for the place and day, there is no Jumu'ah
  alert and no Jumu'ah reminder that day. The same applies to Duha if Sunrise or Dhuhr is
  unavailable.
- **Already past**: If the reader turns on the Jumu'ah reminder less than 20 minutes before Friday
  Dhuhr, or turns on Duha after today's reminder time, nothing fires late. The next one is
  scheduled.
- **Not obliged to attend**: Travellers, women and others not obliged to attend Jumu'ah still see
  the Jumu'ah name on Friday. They can turn the reminder off. There is no setting to keep the
  Dhuhr name on Fridays.
- **Phone limits on scheduled alerts**: Adding Duha and the weekly Jumu'ah reminder means more
  scheduled alerts. Nearer alerts MUST NOT be dropped to make room for later ones, and prayer
  alerts come before reminders when space runs out.
- **Several places**: Reminders follow the current place, like prayer alerts in feature 009.
- **Old messages**: If a phone was off or offline for a long time, an announcement older than the
  time the admin allowed in the console is not shown when it reconnects.
- **Text direction**: An announcement written in Arabic shows right-to-left and in English
  left-to-right, whatever the app's language.
- **Uninstall and reinstall**: A reinstalled app receives announcements again without any action
  from the reader beyond allowing notifications.
- **Web app**: The web app from feature 008 does not receive announcements and has no Jumu'ah
  reminder or Duha reminder, as it has no prayer alerts. The Jumu'ah label on the schedule does
  appear there.

## Requirements *(mandatory)*

### Functional Requirements

**Jumu'ah**

- **FR-001**: On Fridays at the current place, the Dhuhr alert MUST name Jumu'ah instead of Dhuhr
  in its title. Its time, body and sound MUST stay the same as on other days.
- **FR-002**: On Fridays, the schedule in Prayer Times MUST label the midday prayer Jumu'ah. The
  time MUST stay the Dhuhr time, including any adjustment.
- **FR-003**: The app MUST offer a Jumu'ah reminder setting, separate from the five prayer alerts.
- **FR-004**: When the Jumu'ah reminder is on, one reminder MUST arrive each Friday exactly 20
  minutes before Dhuhr time (adjusted Dhuhr if the reader adjusted it), with a title that names
  Jumu'ah, and a short gentle tone, not an athan.
- **FR-005**: The Jumu'ah reminder MUST start out matching the Dhuhr alert: on if the Dhuhr alert
  is on, off if it is off, including for readers updating from an earlier version. Until the
  reader changes the Jumu'ah reminder themselves, it MUST follow the Dhuhr alert when that is
  turned on or off. Once the reader changes it, the two MUST be independent: turning either on or
  off MUST NOT change the other.
- **FR-006**: The 20-minute lead MUST be fixed in this release. It is not a reader setting.

**Duha**

- **FR-007**: The app MUST offer a Duha reminder, off at first, separate from the five prayers.
- **FR-008**: The Duha reminder MUST fire halfway between the place's (adjusted) Sunrise and
  Dhuhr for that day, rounded to the nearest minute.
- **FR-009**: When Duha is on, the Alerts settings MUST show today's reminder time and a one-line
  explanation of the rule.
- **FR-010**: The Duha reminder MUST be labelled Duha and play a short gentle tone, not an athan.

**Announcements**

- **FR-011**: The admin MUST be able to send a notification with a title and a message to every
  installed copy of the app on iOS and Android, from Google's push notification console, without a
  new app release.
- **FR-012**: An announcement MUST be shown when the app is open, in the background or closed.
- **FR-013**: An announcement MAY carry a Mathani link. Tapping the notification MUST open that
  link's destination in the app if present, and otherwise open the app.
- **FR-014**: Settings MUST include an "Announcements from Mathani" setting, on by default. When
  off, the reader MUST NOT receive announcements.
- **FR-015**: Announcements MUST be a separate notification kind from prayer alerts and reminders,
  so the reader can silence one without the other in the phone's settings where the phone allows
  it.
- **FR-016**: The app MUST NOT ask for notification permission at start-up for announcements
  alone.
- **FR-017**: Receiving announcements MUST NOT require an account and MUST NOT send the reader's
  location, reading activity or any personal information to the push service. The only identifier
  is the anonymous delivery address the push service needs to reach the phone.
- **FR-018**: Store privacy disclosures (Apple App Privacy details and Google Play Data safety)
  MUST be updated for the push service before release.
- **FR-019**: Sending to chosen groups of readers is out of scope. Every announcement in this
  release goes to everyone who has announcements on.

**All parts**

- **FR-020**: All new text MUST be in Arabic and English, and the new settings MUST work
  right-to-left and left-to-right, in light and dark mode, with large text and with screen readers.
- **FR-021**: New alerts and reminders MUST work on iOS 15.0+ and Android 7.0 (API 24)+, the same
  versions as feature 009.
- **FR-022**: Readers updating from an earlier version MUST keep all their existing alert settings
  unchanged.

### Key Entities

- **Jumu'ah reminder setting**: on or off, applies to the current place, fires 20 minutes before
  Friday Dhuhr. Also records whether the reader has changed it themselves, which decides whether
  it still follows the Dhuhr alert.
- **Duha reminder setting**: on or off, applies to the current place. Its daily time is halfway
  between that day's Sunrise and Dhuhr.
- **Announcement**: written by the admin. A title, a message, an optional Mathani link, and how long
  it stays valid if the phone cannot be reached. Not stored by the app after it is shown.
- **Announcements setting**: on or off for the whole app, not per place.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On every Friday tested across at least 3 places in different time zones, 100% of
  Dhuhr alerts name Jumu'ah, and on all other days 100% name Dhuhr.
- **SC-002**: The Jumu'ah reminder arrives within 1 minute of 20 minutes before Dhuhr time in at
  least 95% of test Fridays on both iOS and Android, with the phone locked.
- **SC-003**: The Duha reminder time shown in the app matches a hand calculation of the midpoint
  between Sunrise and Dhuhr to the minute for at least 3 places and 3 dates, and arrives within 1 minute of that time.
- **SC-004**: An announcement sent to everyone reaches at least 95% of test phones that are online
  and have announcements on within 5 minutes, on both iOS and Android.
- **SC-005**: With announcements turned off, no test phone shows an announcement.
- **SC-006**: A reader can find and turn on the Jumu'ah reminder or the Duha reminder in under 30
  seconds from the reader screen.
- **SC-007**: Cold start time and the store download size stay within the constitution's budgets.
  Any download growth over 1 MB from the push service is called out in review.

## Assumptions

- **Admin**: "The admin" is the Mathani team. They send announcements from Google's own push
  notification console. No admin page is built inside Mathani or its existing online editor for
  this release.
- **Language of announcements**: The admin writes each message in the language they choose. If
  they want Arabic and English versions, they send two messages and use the console's built-in
  choice of audience by phone language. The app does not translate.
- **Segments later**: Sending to groups chosen by the admin (for example by language, country,
  app version, or reader interests) is a later feature. This spec only needs to avoid making that
  harder, for example by keeping the "everyone" audience separate from any future groups.
- **Jumu'ah time**: The Jumu'ah alert and reminder use the Dhuhr time. Mosques where the khutbah
  starts at a different time are covered by the existing Dhuhr adjustment.
- **Reminder text**: Proposed titles are "Jumu'ah prayer in 20 minutes" / "صلاة الجمعة بعد ٢٠
  دقيقة" and "Time for Duha prayer" / "حان وقت صلاة الضحى". Final wording is settled in planning,
  in the same style as the alert text from feature 009.
- **Gentle tone**: The Jumu'ah and Duha reminders use the same short gentle tone as the Qiyam
  reminder.
- **Privacy**: Adding a push service is a change from feature 009's "no accounts, analytics or ads"
  rule only in that the phone gets an anonymous delivery address. No accounts, analytics or ads are
  added.
- **Dependency**: Announcements need Google's push service on both platforms, and Apple's push
  service on iOS. Its size and start-up cost must be justified in the plan under the constitution's
  Lean by Default principle.
- **Out of scope**: Reminders before prayers other than Jumu'ah, a choice of minutes for the
  Jumu'ah reminder, a Duha end-of-time warning, announcements in the web app, an in-app list of past
  announcements, images in announcements, and scheduled or repeating announcements set up in the
  app.
