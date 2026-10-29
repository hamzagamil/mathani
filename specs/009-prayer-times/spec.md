# Feature Specification: Prayer Times and Athan Notifications

**Feature Branch**: Existing branch `008-web-app`; no branch hook is configured. Feature directory numbering is independent of the branch.

**Created**: 2026-10-29

**Status**: Draft

**Input**: User description: "Introduce prayer times with multiple locations, calculation methods and mazaheb. Detect location automatically, allow manual changes, and if possible use approximate IP location when GPS is unavailable. Offer multiple athan recitations, optional Qiyam notifications, and full athan or first takbirat playback."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See prayer times for my location (Priority: P1)

A reader opens Prayer Times and sees today's schedule and the next prayer for their location. They can allow automatic detection, choose a city manually, or explicitly try approximate location through their internet connection when device location is unavailable.

**Why this priority**: A trustworthy schedule for the correct place is the foundation of every reminder.

**Independent Test**: Start without saved preferences and exercise successful detection, denied permission, approximate-location confirmation, and manual selection. Each successful route produces the named location's local schedule.

**Acceptance Scenarios**:

1. **Given** no saved location, **When** the reader opens Prayer Times, **Then** the app explains location use, offers automatic detection and manual selection, and requests location permission only when detection is chosen.
2. **Given** detection succeeds, **When** its location becomes active, **Then** today's Fajr, sunrise, Dhuhr, Asr, Maghrib and Isha appear with the location name, local date, time zone, method and madhhab setting.
3. **Given** permission is denied or detection fails, **When** the reader continues, **Then** manual selection remains available without repeated permission prompts, with optional approximate-location lookup when online.
4. **Given** approximate lookup succeeds, **When** the result appears, **Then** it is labelled approximate and must be confirmed or corrected before use for schedules or reminders.
5. **Given** detection fails, **When** the reader searches for a city, **Then** city, region and country distinguish matches, and selecting one produces its schedule.
6. **Given** a saved location and no connection, **When** Prayer Times opens, **Then** a valid schedule appears or unavailable information is clearly explained without showing stale times as current.

---

### User Story 2 - Manage locations and calculation preferences (Priority: P1)

A reader saves home and travel destinations and chooses each place's calculation method and madhhab. They can inspect another location without changing where notifications apply.

**Why this priority**: Prayer times must remain useful across travel and differing calculation preferences.

**Independent Test**: Save three places in different time zones, choose different methods and madhahib, inspect and activate locations, and reopen the app. Verify persisted preferences and a single active notification location.

**Acceptance Scenarios**:

1. **Given** one saved location, **When** two more are added, **Then** all three remain selectable with their own names, calculation methods and madhhab settings.
2. **Given** multiple saved places, **When** the reader views another place, **Then** notification location remains unchanged until the reader explicitly activates that place.
3. **Given** a location schedule, **When** its method or madhhab changes, **Then** the schedule updates, the choice remains visible, and future active-location reminders use the updated times.
4. **Given** a manually selected active location, **When** the device moves or the app restarts, **Then** the choice is preserved until the reader explicitly changes it or refreshes detection.
5. **Given** an active location, **When** it is removed, **Then** the reader selects a replacement or confirms disabling its reminders; no reminders remain for the deleted place.
6. **Given** different time zones or daylight-saving transitions, **When** schedules are displayed, **Then** dates and times follow each location's time zone rather than the device time zone.

---

### User Story 3 - Choose how I hear the athan (Priority: P2)

A reader enables individual daily prayer notifications, previews different athan recitations, and selects a complete athan or opening takbirat. They can stop playback and change preferences without duplicate reminders.

**Why this priority**: Configurable reminders turn the schedule into daily assistance while respecting personal preferences.

**Independent Test**: With an active location, preview two recitations, select each duration mode, enable and disable individual prayers, and exercise delivery with the app open, backgrounded and locked on each target platform.

**Acceptance Scenarios**:

1. **Given** reminders are disabled, **When** one is enabled, **Then** notification permission is requested in context if necessary and its enabled or blocked status is visible.
2. **Given** the athan catalogue, **When** the reader previews two distinct recitations, **Then** both are named and only one preview plays at a time.
3. **Given** available audio and an enabled prayer, **When** it becomes due, **Then** the notification identifies the prayer and active location and plays the selected full athan or opening takbirat where supported and permitted by system settings.
4. **Given** scheduled reminders, **When** the active location, calculation preferences, recitation or duration changes, **Then** future reminders use the latest settings without obsolete or duplicate alerts.
5. **Given** athan playback, **When** the reader stops it, **Then** playback stops. Quran recitation pauses before an athan starts and requires user action to resume.
6. **Given** a platform or system setting prevents the requested playback, **When** reminders are configured, **Then** the limitation and available alternative are disclosed before enabling; unsupported full playback is not represented as active.
7. **Given** selected audio is unavailable offline, **When** a reminder is configured or delivered, **Then** the app explains availability and uses a previously disclosed available notification sound rather than silently promising the selected recording.

---

### User Story 4 - Receive an optional Qiyam reminder (Priority: P2)

A reader independently enables a nightly reminder for voluntary Qiyam prayer and sees when it will occur.

**Why this priority**: This supports voluntary night worship without unwanted extra alerts.

**Independent Test**: Enable Qiyam for known overnight boundaries, verify the displayed time and one reminder, then disable it and verify daily prayer preferences are unchanged.

**Acceptance Scenarios**:

1. **Given** default preferences, **When** reminders are inspected, **Then** Qiyam is off and independently selectable.
2. **Given** valid Maghrib and following-day Fajr, **When** Qiyam is enabled, **Then** the upcoming reminder is at the start of the last third of that interval, with local date and time visible before activation.
3. **Given** Qiyam is enabled, **When** it becomes due, **Then** one notification labelled Qiyam uses a short reminder sound rather than an obligatory-prayer athan.
4. **Given** Qiyam is enabled, **When** location or calculation settings change, **Then** the upcoming time is recalculated; disabling Qiyam cancels only Qiyam reminders.

### Edge Cases

- Location is disabled, permanently denied, times out or returns unusable coordinates: explain the result and preserve manual selection and any valid saved schedule.
- IP approximation is wrong because of a VPN, proxy or mobile network: require confirmation, allow correction and never silently replace a manual location.
- City search has ambiguous matches, no results or no connection: explain the outcome and allow retry without replacing an existing location.
- Midnight, travel, daylight-saving or clock changes: refresh the next prayer and future reminders without replaying past events.
- High-latitude dates lack ordinary astronomical events: apply and disclose a supported adjustment rule; label unresolvable times unavailable and suppress their reminders. Without valid night boundaries, do not invent a Qiyam time.
- Notification permission is revoked, the device is muted or background delivery is restricted: display effective status and recovery guidance without guaranteeing audible delivery.
- App/device restart or a long absence: preserve preferences and restore future supported reminders without a backlog of missed alerts.
- Audio download or preview fails: show retry and alternatives, preserve the last usable choice and prevent overlapping previews.
- Removing the last location returns Prayer Times to setup and cancels location-dependent reminders.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Prayer Times MUST show the six daily events in Story 1, the next of the five daily prayers, its time and countdown. Sunrise MUST be informational and MUST NOT receive a prayer athan.
- **FR-002**: Each schedule MUST identify location, local date, time zone, method, madhhab and high-latitude adjustment. Approximate, adjusted and unavailable information MUST be clearly identified.
- **FR-003**: Users MUST be able to initiate device location detection with an explanation and in-context permission request. Refusal MUST NOT block manual setup or other app features.
- **FR-004**: Users MUST be able to search for and manually select a city, distinguished by region and country, regardless of location permission, and change it later.
- **FR-005**: When device detection is unavailable and the user is online, the app MUST offer an optional IP-based approximate-location attempt. Before lookup, it MUST disclose that an external location service receives the connection's IP address. Results MUST require confirmation before use; failure MUST return to manual selection. Feasibility and geographic coverage MUST be verified in planning.
- **FR-006**: Users MUST be able to save, name, view, select and remove multiple locations. Exactly one location MUST be active whenever location-dependent reminders are enabled; merely viewing another location MUST NOT activate it.
- **FR-007**: Saved locations and preferences MUST survive restarts. Manual selections MUST remain authoritative until explicitly changed or detection is explicitly refreshed. Continuous travel tracking is outside scope.
- **FR-008**: Calculation choices MUST include at least Muslim World League, Egyptian General Authority of Survey, University of Islamic Sciences Karachi, Umm al-Qura Makkah, and North America (ISNA). A suggested regional default MUST be visible and overridable. Changes MUST update the schedule before future reminders are replaced.
- **FR-009**: Users MUST be able to select Hanafi, Shafi'i, Maliki or Hanbali madhhab labels. The interface MUST explain that this setting controls Asr timing, grouping equivalent timing choices where appropriate, rather than implying support for every ruling of a madhhab. Method and madhhab MUST be stored per location.
- **FR-010**: Schedules MUST consistently use the location's coordinates, local date, time zone, method and madhhab. Daylight-saving and overnight boundaries MUST NOT create missing, duplicated or incorrectly dated events.
- **FR-011**: Where ordinary events are unavailable, the app MUST offer a named high-latitude adjustment, disclose any regional default and allow changes. At minimum, middle-of-night and one-seventh-of-night choices MUST be available when valid night boundaries exist. Unresolvable events MUST remain unavailable and generate no reminder.
- **FR-012**: Users MUST be able to enable or disable notifications independently for Fajr, Dhuhr, Asr, Maghrib and Isha, all initially disabled. Denied permission MUST preserve preferences while showing delivery as blocked.
- **FR-013**: Users MUST be able to select among at least two named, distinct athan recordings and preview or stop each. One selected recitation and duration setting apply to all enabled daily prayer reminders in this release.
- **FR-014**: Full-athan and opening-takbirat modes MUST be offered. Full means the complete selected recording; opening mode ends after its opening four repetitions of "Allahu akbar", before the shahada. A mode MUST only be represented as enabled when the platform and notification state support it. Limitations and available alternatives MUST be disclosed before activation.
- **FR-015**: Supported mobile reminders MUST operate with the app open, backgrounded or the screen locked, subject to system permissions and restrictions. Planning MUST verify both playback modes on iOS and Android before committing to delivery. Any gap requires a documented justification and tracked follow-up under the constitution.
- **FR-016**: Future reminders MUST reflect changes to active location, calculation settings and notification preferences. Obsolete reminders MUST be cancelled. Each enabled event MUST produce at most one alert, and missed events MUST NOT be replayed as a backlog.
- **FR-017**: Users MUST be able to stop athan playback. Athan previews and notifications MUST NOT overlap each other or Quran recitation; Quran recitation MUST pause before athan playback and require user action to resume.
- **FR-018**: Selected audio MUST be available for offline reminders before the app reports offline playback as ready. Missing audio MUST have a visible status and a disclosed available fallback sound; audio failure MUST NOT silently disable the prayer notification.
- **FR-019**: Qiyam MUST be independently configurable, off by default, and scheduled once at the start of the last third of local Maghrib to the following local Fajr. Its upcoming local date and time MUST be shown. It MUST use a distinct label and short reminder sound, without a prayer athan. Invalid boundaries MUST suppress that night's reminder with an explanation.
- **FR-020**: Saved-place schedules MUST remain available without fresh location access. Offline use MUST preserve valid schedules and preferences, clearly explaining unavailable information without showing stale times as current.
- **FR-021**: The feature MUST work on iOS 15.0+ and Android 7.0 (API 24)+ in phone portrait layouts, with Arabic and English, existing themes, font scaling and screen readers. Controls MUST respect safe areas and minimum touch sizes of 44 by 44 pt on iOS and 48 by 48 dp on Android.
- **FR-022**: The supported web app from feature 008 MUST provide schedules, saved locations, calculation preferences and manual selection. Detection and notifications MUST report actual browser capabilities and permissions. Unsupported background delivery or audio modes MUST be explained before activation, with mobile apps offered as an alternative. Parity gaps MUST be documented in the plan with tracked follow-ups.
- **FR-023**: Location MUST be used only for requested detection and prayer schedules. Retention MUST be limited to saved places and the latest confirmed active location, without movement history, and users MUST be able to remove them. Precise location MUST NOT be sent for IP approximation or included in routine diagnostics. Sensitive retained location MUST follow the project's secure-storage requirements.
- **FR-024**: User actions MUST show feedback within 100 ms. Saved content or progress MUST appear immediately during longer work. Schedule refreshes MUST NOT block other app features or regress existing startup and scrolling budgets.

### Key Entities *(include if feature involves data)*

- **Saved Location**: User name, city, region, country, coordinates, time zone, source, confirmation state and calculation preferences.
- **Calculation Preferences**: Method, madhhab and high-latitude rule for one location.
- **Daily Prayer Schedule**: Local date, daily events, availability, adjustments and next-day boundary needed for Qiyam.
- **Reminder Preferences**: Active location, enabled prayers, athan recording, duration mode, independent Qiyam toggle and effective permission/capability state.
- **Athan Recording**: Named recitation with preview, complete recording, opening-takbirat boundary and offline availability.
- **Scheduled Reminder**: Prayer or Qiyam event for the active location and current settings, intended instant and enabled, blocked or cancelled status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At least 90% of representative users reach a confirmed first schedule within two minutes using detection or manual selection, including a denied-permission test group.
- **SC-002**: Across at least 10 cities, all five required methods, both distinct Asr timing conventions, daylight-saving changes and high-latitude examples, every available time agrees within one minute with independently established expected results for identical settings; every unresolvable event is labelled unavailable.
- **SC-003**: Users save and switch among at least three locations in different time zones, with 100% of restart, switching and deletion trials preserving the correct preferences and active reminder location.
- **SC-004**: On each mobile platform under documented system conditions permitting delivery, at least 95% of 30 reminder trials per supported playback mode start within 60 seconds of the displayed prayer time. All trials use the selected recitation and duration, with zero obsolete or duplicate alerts after preferences change.
- **SC-005**: In 100% of valid-boundary Qiyam trials, displayed and scheduled times match the specified last-third boundary within one minute; disabling Qiyam leaves daily prayer choices unchanged.
- **SC-006**: In 100% of denied-permission, failed-detection, unavailable-audio and unsupported-capability trials, users see an accurate status and next action, with no unsupported playback represented as active.
- **SC-007**: At least 90% of representative users select a recitation, distinguish full from opening playback and toggle Qiyam without assistance; Arabic, English and screen-reader tasks are included.
- **SC-008**: On the project's mid-range reference phones, taps show feedback within 100 ms, cold start remains at or below two seconds, and schedule scrolling meets the existing 60 frames-per-second target.

## Assumptions

- Multiple locations means saved places and one active notification location. Simultaneous reminders for multiple places, cloud synchronisation and continuous travel tracking are outside scope.
- Initial method choices are those in FR-008. Custom calculation angles, manual minute offsets and broader jurisprudence preferences are outside this release.
- Qiyam defaults to a reminder at the start of the last third of the Maghrib-to-next-Fajr night, not a sixth obligatory-prayer athan. Custom reminder offsets and separate Qiyam recitations are outside scope.
- "First takbirat" means the opening four takbirs. The recording catalogue must provide identifiable boundaries for both duration modes.
- Calculated times need not match every local mosque timetable; selected conventions and adjustments remain visible.
- The web app in feature 008 is part of intended distribution and its supported-browser range is inherited. Capability gaps must be explicit and tracked. Mobile full-athan feasibility is a planning gate, not assumed proven by this specification.
- Device detection may use approximate access when that is all the user grants. IP lookup is an explicit action, not an undisclosed consequence of denying device permission.
- Searching new places, IP approximation and obtaining audio may require connectivity; saved-place schedules and prepared reminder audio must support offline use.
- Planning must identify licensed recordings, reliable place-search and optional IP-approximation coverage, independently established calculation references and platform playback/delivery constraints. Providers and implementation mechanisms are intentionally left to planning.
- Preferences are per device or browser using the existing settings experience. No new account or analytics requirement is introduced.

### Platform exceptions established during planning (2026-10-29)

These bounded exceptions apply to the affected requirements. Justification and tracked follow-ups are in [follow-ups.md](./follow-ups.md); implementation and device validation remain required.

- **P01 — FR-014/015**: On iOS, automatic background/closed-app reminders use an eligible opening-takbir clip; complete athan playback requires the app to be active or the user to open it and start playback. Full background playback must not be advertised as available.
- **P02 — FR-017**: Stop and guaranteed pausing of Quran apply to app-controlled playback. iOS system-owned notification sounds follow system interruption behaviour and cannot promise application Stop or guaranteed pausing of background Quran. Explain this limitation before enabling those sounds.
- **P03 — FR-015/022**: The web app does not promise precise notifications or custom athan audio while its page is closed or suspended. Schedules, settings and user-started playback remain available; limitations and mobile alternatives must be visible.
- **P04 — FR-015/016**: Automatic reminders cover a finite, displayed scheduling horizon. Users must be told when reopening is needed to extend coverage; no indefinite closed-app coverage or replay of missed events is promised.
- **P05 — FR-023**: Browser saved locations use encrypted storage confined to that browser and site, with weaker protection than native device secure storage. No plaintext fallback is permitted; unavailable secure persistence must be explained and limited to the session.
- **P06 — FR-013/014/015 (notification increment)**: While the selected recording is unavailable or uncleared, a user may explicitly accept a standard short system notification sound for daily prayers. It is labelled as a standard sound, never as full athan or four takbirs; the requested recording/mode stays saved. Qiyam uses its own original non-verbal tone and remains independent. This does not satisfy the two-recording acceptance requirement or enable unproven Android full playback. System-owned short sounds cannot guarantee application Stop or pausing Quran; disclose that boundary on both native platforms.
- **P07 — late iOS system alerts**: The app installs only future iOS requests and cancels obsolete pending requests, but cannot run a pre-delivery expiry check before iOS presents a delayed local notification. The strict 60-second runtime rejection is enforced for Android/page-controlled delivery; do not claim that filter for iOS system-owned presentation. This limitation is shown before enablement and remains part of physical-device timing acceptance.

These limits follow platform behaviour rather than a user preference change. Physical-device verification and all unaffected requirements remain release gates. Apple documents the sound constraint in [UNNotificationSound](https://developer.apple.com/documentation/usernotifications/unnotificationsound); design research records the remaining platform sources.
