# Feature Specification: Usage Analytics

**Feature Branch**: `016-usage-analytics`

**Created**: 2026-11-21

**Status**: Draft

## Clarifications

### Session 2026-11-21

- Q: Consent model on the phones? → A: Analytics are always on, with no switch in Settings and no
  question; readers are told in the privacy policy, the store privacy sections and About (FR-006,
  FR-007).
- Q: Consent model on the web? → A: The same as the phones: always on, no banner, no switch
  (FR-012).
- Q: How detailed are the events? → A: Screens, a fixed list of actions, and coarse details from
  fixed lists (which feature, which setting value), never content or free text (FR-003).

**Input**: User description: "Add Google Analytics to the app (Android and iOS, through Firebase
Analytics in the existing Firebase project "mthani", property 539746070) and to the web app
(get.mthani.app), so the owner can see usage on a custom dashboard that reads the GA4 property:
active users (daily, over time), user activity, event counts, events per active user, and screens
and views. It must respect readers' privacy, in keeping with the app's current "nothing leaves your
device" stance: decide which events are collected (no Quran reading content, recitation audio or
personal data), whether readers can opt out or must opt in, and update the store privacy answers,
the privacy policy and the store listing text."

**Scope of this spec**: Mathani today collects no usage data at all (docs/store/privacy.md;
specs/008 FR-027 for the web app; specs/015 kept analytics out). This feature adds anonymous usage
counts on the phone apps and the web app, sent to the owner's existing analytics property, so the
owner can see how many people use Mathani and which parts they use. It supersedes specs/008 FR-027
and the "no Firebase Analytics" line of specs/015 for the analytics described here, and nothing
more: no advertising, no tracking across apps or sites, no accounts.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The owner sees how many people use Mathani (Priority: P1)

The owner opens the custom dashboard (or the analytics console) and sees daily active users, active
users over time and a user-activity trend, separately for Android, iOS and the web, within a day of
readers using the app.

**Why this priority**: This is the reason for the feature. Without counts of active readers, the
owner cannot tell whether a release helped, or where to put effort.

**Independent Test**: Install a build with analytics, open it on one phone and in one browser, and
check that both appear as active users in the analytics property's real-time view within minutes
and in the daily report the next day.

**Acceptance Scenarios**:

1. **Given** a reader on a build with analytics, **When** they open the app, **Then** they are counted
   once as an active user for that day, under their platform.
2. **Given** the same reader opening the app five times in a day, **When** the owner looks at daily
   active users, **Then** they count as one user, with five sessions.
3. **Given** a reader offline, **When** they use the app, **Then** it works as before and their use
   is counted once they are back online, if within the retry period.

---

### User Story 2 - The owner sees which parts of the app are used (Priority: P1)

The owner sees screens and views (for example the mushaf, search, recitation, memorization, prayer
times, khatma, settings) and counts of key actions (for example a recitation started, a
memorization session started, a khatma wird completed), with events per active user.

**Why this priority**: Active-user counts say how many; this says what for. It guides which
features to improve and which to simplify.

**Independent Test**: Visit each main screen and perform each listed action once; the real-time view
shows each screen name and each action name once, with only its allowed details.

**Acceptance Scenarios**:

1. **Given** a build with analytics, **When** the reader opens the prayer times screen, **Then** a
   view of a screen named for prayer times is counted, without the place, coordinates or times.
2. **Given** a build with analytics, **When** the reader starts a recitation, **Then** a "recitation
   started" action is counted with its allowed details (for example the reciter from the app's
   list and whether it streamed or was downloaded), without the surah, ayah or page.
3. **Given** a build with analytics, **When** the reader searches, **Then** a "search" action is
   counted, without the words searched.
4. **Given** a build with analytics, **When** the reader changes a setting such as theme or mushaf
   layout, **Then** a "setting changed" action is counted with the setting's name and new value
   from the app's fixed list.

---

### User Story 3 - The reader is told honestly what is collected (Priority: P1)

Analytics are always on (Clarifications). A reader who wants to know what leaves their device finds
it in About, the privacy policy and the store's privacy section: anonymous counts of app use,
screens, actions and settings, and never what they read, recite or search, or anything personal.
No text anywhere still says that nothing is collected.

**Why this priority**: Mathani's promise until now has been that nothing leaves the device. Without
a switch, honest disclosure is what keeps readers' trust, and both stores require it.

**Independent Test**: Read About, the privacy policy and both store listings and privacy sections;
each describes the analytics the same way, and none says that no data is collected.

**Acceptance Scenarios**:

1. **Given** a first launch, **When** the app starts, **Then** analytics start after the first frame
   with no question or banner (FR-006).
2. **Given** a reader in About, **When** they read the privacy line, **Then** it says in one sentence
   what is collected and what never is, with a link to the full policy.
3. **Given** the store pages, **When** a reader checks the privacy section, **Then** it lists the
   analytics data types, and the listing text no longer says nothing leaves the device.

---

### User Story 4 - The same on the web app (Priority: P2)

Readers of get.mthani.app are counted the same way, with the same screens, actions and details, and
the same disclosure.

**Why this priority**: The web app has its own readers, and the owner wants one picture of all
platforms. It is second because the phone apps carry most readers.

**Independent Test**: Open get.mthani.app in a fresh browser profile and check the real-time view
for a web user and a screen view, with no banner shown.

**Acceptance Scenarios**:

1. **Given** a first visit, **When** the app loads, **Then** analytics start after the first frame
   with no banner (FR-012).
2. **Given** the same browser on the next day, **When** the reader returns, **Then** they count as a
   returning user, not a new one.

---

### Edge Cases

- **Offline**: events made offline are kept on the device for a limited time and sent when the
  connection returns; if they expire first they are dropped. The app never waits for analytics.
- **Readers who never update**: older versions keep sending nothing; they appear in store
  statistics only.
- **Children**: Mathani is used by families. No event may identify a person, and nothing is used
  for advertising, so the app stays suitable for its current age rating.
- **Announcements setting**: independent of analytics; turning announcements off does not stop
  analytics, and analytics never depend on the announcement topics.
- **Reader asks for their data to be deleted**: there is no account to look them up by; the
  policy's contact address handles requests, and the owner can delete a single app instance's data
  in the analytics console if the reader provides nothing identifying. The policy says so.
- **Browser privacy tools**: on the web, blockers or strict tracking protection may stop analytics;
  the app works the same and those visits are simply not counted.
- **Group khatma**: participant names, khatma titles and links are never part of any event.
- **Debug and test builds**: do not count toward the owner's reports.
- **Analytics service unavailable**: the app works exactly as without analytics.

## Requirements *(mandatory)*

### Functional Requirements

**What is collected**

- **FR-001**: The phone apps and the web app MUST report active use (app opens and sessions), so
  that daily active users, active users over time and user activity can be read per platform.
- **FR-002**: The apps MUST report a view each time the reader opens one of the main screens, named
  from a fixed list (for example: mushaf, surah index, search, bookmarks, recitation, memorization,
  khatma, group khatma, prayer times, qibla if present, mutashabihat, settings, about, onboarding).
- **FR-003**: The apps MUST report a fixed list of key actions (for example recitation started,
  memorization session started, search, bookmark added, khatma started or wird completed, group
  khatma joined, prayer alert turned on, announcement opened, setting changed), each with coarse
  details whose values come only from fixed lists in the app: which feature or mode, which setting
  and its new value (theme, language, mushaf layout, font size step, prayer calculation method,
  alert sound type), which reciter from the app's list, streamed or downloaded. Every action and
  every allowed detail is defined in the plan and kept in one place in the code so it can be
  reviewed; anything not on the list is never sent.
- **FR-004**: Events MUST NOT contain: Quran text, surah, ayah, page or juz numbers; search words;
  reciter choices tied to content; microphone audio or recognition results; bookmark notes; khatma
  titles, participant names or links; prayer places, coordinates or times; announcement content;
  or any name, email or phone number.
- **FR-005**: The apps MUST NOT use an advertising identifier, MUST NOT link analytics with other
  apps or websites, MUST NOT use the data for advertising or personalised ads, and MUST NOT need
  Apple's tracking permission prompt.

**Reader control**

- **FR-006**: Analytics MUST be on for every reader of a build that includes them, with no question,
  banner or switch (Clarifications, owner decision).
- **FR-007**: About MUST carry one sentence saying what is collected (anonymous counts of app use,
  screens, actions and settings) and what never is (what you read, recite or search, and anything
  personal), with a link to the privacy policy, on Android, iOS and the web.
- **FR-008**: The analytics identifier MUST be the random per-install (per-browser) one only; it is
  never combined with the announcement push token, a group khatma key or any other identifier.
- **FR-009**: Events MUST NOT include free text of any kind, even where a fixed-list detail would
  otherwise allow it.

**Platforms**

- **FR-010**: Android and iOS MUST report to the existing analytics property behind Firebase project
  "mthani", as separate app streams.
- **FR-011**: The web app MUST report to the same property as its own web stream.
- **FR-012**: The web app MUST behave as the phones: analytics on, no banner, no switch, with the
  same About sentence.
- **FR-013**: Debug builds, test runs and the web preview deployments MUST NOT send to the
  production property.

**Retention and the owner's side**

- **FR-014**: The property's data retention MUST be set to the shortest standard period (2 months
  for detailed data), and Google signals and ads personalisation MUST stay off.
- **FR-015**: The owner's dashboard reads the property with a read-only account; no write or admin
  credential is given to the dashboard tool.

**Disclosure**

- **FR-016**: docs/store/privacy.md MUST list exactly what is collected, why, for how long and by
  whom, and the answers to change in Apple App Privacy and Google Play Data safety.
- **FR-017**: The published privacy policy (mthani.app/privacypolicy) and the store listings
  (listing_en.md, listing_ar.md) MUST be updated so that no text still says no data is collected.
- **FR-018**: The iOS privacy manifest MUST declare the collected data types, with tracking still
  false.

**Performance and size**

- **FR-019**: Analytics MUST NOT delay the first screen; it starts after the first frame, like
  announcements (specs/015).
- **FR-020**: The download size increase MUST be measured and called out if over 1 MB
  (constitution IV).

### Key Entities

- **Usage event**: a name from the fixed list (screen view, session, or key action), the time,
  platform, app version, app language and coarse device facts the analytics service adds (OS
  version, device category, country from the connection). No content and no identity.
- **Allowed-events list**: the fixed list of screen names, action names and, for each action, the
  details and their possible values; the single place reviewed for privacy.
- **App instance id**: the random identifier the analytics service creates per installation (or
  per browser on the web) so one reader counts once a day; reset when the app is deleted or the
  browser's site data is cleared.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Within 24 hours of a release reaching readers, the owner's dashboard shows daily active
  users per platform (Android, iOS, web), and screens and views, with no manual export.
- **SC-002**: 100% of the screens in the fixed list and 100% of the listed actions appear in the
  real-time view during a manual test pass on each platform.
- **SC-003**: A review of every event sent during a full test pass (all screens, recitation,
  memorization, search, prayer times, group khatma) finds zero items from the FR-004 list.
- **SC-004**: Every event and detail seen in that review is on the allowed-events list; zero
  unlisted names or values.
- **SC-005**: Cold start time stays within the constitution's 2-second budget, and does not
  regress by more than 50 ms on the reference device.
- **SC-006**: A reader can find the privacy sentence in About in under 30 seconds from the home
  screen.
- **SC-007**: The store privacy answers, privacy policy and listings are updated before the first
  public release that sends analytics; no store text contradicts what is collected.

## Assumptions

- The analytics property (539746070) linked to Firebase project "mthani" is the destination; the
  owner already has admin access and a read-only service account for the dashboard.
- **Risk accepted by the owner (Clarifications)**: with no consent and no switch, collection relies
  on the owner's position that anonymous, non-advertising analytics need no consent. EU and UK
  rules on storing an identifier on a device generally require consent for analytics, so this is a
  legal risk for readers there, and the Play Data safety form must mark the data as required, not
  optional. If the owner later decides to add consent for some regions, it is a separate change.
- Store answers expected (confirmed in the plan): Apple App Privacy "Product Interaction" and
  "Device ID" (and "Other Usage Data" if needed) for Analytics, not linked to the user, not used for
  tracking; Play Data safety "App interactions" and "Device or other IDs", collected, required, for
  Analytics, not shared.
- Country and city come from the analytics service's handling of the connection; the app sends no
  location. City-level detail is not needed and is left at the service's default granularity.
- Store statistics (installs, uninstalls, ratings) stay in the store consoles and are not merged.
- The announcement topics (specs/015) are not used as an analytics dimension.
- The minimum OS versions are those of the current app (no change).
- Crash reporting is out of scope; it may be a later feature.
- Segment-based announcements (specs/015 "later") may later use analytics audiences; that is a
  separate feature and needs analytics on for the reader.
