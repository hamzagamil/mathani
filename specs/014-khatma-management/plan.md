# Implementation Plan: Personal and Group Khatma

**Branch**: `014-khatma-management` (feature ID; no branch exists yet, and the work so far is on
`013-page-zoom-similar-labels`) | **Date**: 2026-11-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/014-khatma-management/spec.md`, with the
clarifications of 2026-11-15 (a live group khatma; the place follows page turns; missed days
move the finish date).

## Summary

The feature ships in two releases. Each is useful alone, and the first carries none of the
second's risk (research R26).

**Release A, the personal khatma** (Stories 1 to 4 and 8). Everything stays on the device.

- **Plan** (R2): one pure function divides the Quran from the Mushaf data the app already holds
  in memory: by the quarter marks, by the seven surah groups, or evenly by pages.
- **Storage** (R1): `user.db` gains two tables. Wirds are stored rows, so changing the plan
  replaces only the unread ones.
- **Place** (R3): a small tracker follows the reader's own page turns and ignores jumps. The
  reader controller already tells the two apart.
- **Reading screen** (R5, R6): a seventh toolbar button, "pages left" in the header, a mark at
  the ayah where the wird ends, drawn in the page's empty margin, and a Done row in the
  controls on the wird's last page.
- **Reminder** (R8, R9): ten one-time local notifications, rebuilt on every change, through the
  alarm and notification code that prayer alerts use. Prayer alerts go from 60 to 52 pending, so
  both fit the iPhone's limit of 64.

**Release B, the group khatma** (Stories 5 to 7). Names and a title go to Mathani's server.

- **Server** (R14, R17): Pages Functions under `/api/khatma`, a second D1 database, and a small
  Worker that emails reports and removes expired khatmas on a schedule.
- **Identity** (R15): one random key per device, kept in the platform's secure storage. The
  server keeps only its hash. No account.
- **Link** (R16): `get.mthani.app/k/<code>` opens the web app in a browser and the installed
  app through Universal Links and App Links.
- **Live state** (R17, R18): one snapshot per khatma, polled every 20 seconds while its screen
  is open. A Done mark made offline waits and is sent later.
- **Safety** (R19 to R21): terms, a filter, reporting, the organiser's tools, a page for the
  owner to act on reports, blocks, limits and a lifetime for every khatma.
- **In the reader** (R22): a part the reader holds uses the same tracker, mark and Done row as
  a wird.

Details: [research.md](./research.md).

**Points the owner should know**:
- Planning corrected one figure in the spec. Counting every page a wird touches, a juz is 20 to
  23 pages and the seven-day wirds 72 to 106 (the spec said 19 to 23 and 72 to 105).
- "50 pages a day" becomes 13 days of 46 or 47 pages, so that wird sizes stay within one page
  (FR-003). The plan sheet shows this before the reader confirms.
- Reminders stop after ten days without the app being opened. The spec asks for seven.
- Release B waits on six owner steps (R26): the databases, the Worker and email sending, the
  rate limiting rule, the link settings in the Apple and Google consoles, the contact address,
  and the store answers and policy page.

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned). Kotlin and Swift for the existing
native code. JavaScript (ES modules) for Pages Functions and one Worker, Node 24 for their
tests. Plain HTML and JavaScript for the owner's reports page.

**Primary Dependencies**:
- **Release A**: no new packages. Reused: `sqflite`, `flutter_local_notifications` (iOS),
  `timezone` (its UTC zone only), `intl`, and the existing reader, renderer and prayer alarm
  code.
- **Release B**: one new package, `flutter_secure_storage` 11.2.0, exact (Complexity Tracking).
  Reused: `http`, `share_plus`.
- **Functions and Worker**: no npm packages. Web Crypto and the D1 binding.
- **New platform services** (release B): a D1 database, a Worker with two scheduled jobs and
  email sending, one rate limiting rule, Universal Links and App Links.

**Storage**:
- **Device**: `user.db` schema 2 (release A: `khatmas`, `khatma_wirds`) and schema 3 (release B:
  `group_khatmas`, `group_parts`). The key in secure storage on phones.
- **Server** (release B): D1 `mthani-khatma` with `khatmas`, `parts`, `participants`, `reports`
  and `blocks`.
- See [data-model.md](./data-model.md).

**Testing**:
- **`flutter_test` unit tests**: the division on the bundled database (SC-003, SC-004), the
  tracker, the repository and its migration, dates, the reminder list, and for release B the
  code reader, the client and the waiting marks.
- **`flutter_test` widget tests**: the Khatma screens, the reading controls, the end mark with
  goldens, the long-press item, the tour stop, the sideways sizes, and the group screens.
- **Node**: `node --test tool/khatma/*.test.mjs` for the functions and the Worker, with D1 stood
  in for by `node:sqlite`.
- **Android JVM**: the alarm store and the receiver's rules.
- **Devices**: [quickstart.md](./quickstart.md) A1 to A9 and B1 to B8.

**Target Platform**: iOS 15.0+, Android 7.0 (API 24)+, and the browsers of specs/008. The web
has everything except the reminder (FR-042). Server: Cloudflare Pages Functions and one Worker.

**Project Type**: Existing Flutter mobile app with a web build and existing Pages Functions,
gaining one small Worker.

**Performance Goals**:
- Cold start stays at or under 2 s on Galaxy A15 and iPhone SE 2nd gen. Nothing of the feature
  runs before the first frame (FR-039).
- 60 fps page turns with the end mark on screen. A change of marks repaints without layout.
- Dividing into 604 wirds takes under 5 ms. The list of 604 wirds scrolls at 60 fps (SC-008).
- Group: a change shows on other devices within 30 s (a read every 20 s). An unchanged read is
  a `304` under 1 KB. An action completes within 3 s on a mobile connection (SC-016, SC-018).

**Constraints**:
- The personal khatma never leaves the device. A reader with no group khatma makes no request
  (SC-012).
- The end mark moves and covers no Quran text (FR-010).
- An iPhone app holds 64 pending notifications: 52 for prayer alerts and 10 for the reminder.
- The server keeps only what FR-065 lists, plus a report's copy and a block's key hash (R21).
- The web app's Content Security Policy does not change: the API is on its own origin.

**Scale/Scope**:
- A personal khatma has at most 604 wirds. A group khatma has 30 or 60 parts.
- The free Cloudflare plan carries about 8,000 daily readers of group khatmas (R24).
- Release A: about 15 new Dart files and 16 changed, 3 Kotlin files changed. Release B: about
  16 new Dart files, 6 function files, one Worker, one owner page, and small changes to the
  Android activity, the iOS scene delegate and both platforms' settings. About 120 new strings
  in each language.

## Constitution Check

Constitution 2.0.0. Checked before research and again after design.

| Principle | Result |
| --- | --- |
| **I. Platform parity** | **Pass, with one stated gap.** One Dart code base serves iOS and Android. Each platform's own convention is used for notifications (alarms and a channel on Android, scheduled notifications on iOS) and for links (App Links, Universal Links). iOS 15.0 and Android API 24 are stated. The web has no reminder, which the spec states (FR-042), as specs/009 did for alerts. |
| **II. Mobile-first** | **Pass.** Every screen is designed for a phone in portrait first, and stays usable sideways (specs/013). The Khatma button is in the bottom toolbar, in one-handed reach. Buttons keep 44 pt and 48 dp; where seven do not fit, the toolbar scrolls and no target shrinks. Safe areas, text scaling, dark mode and screen readers are in the contracts and in quickstart A9 and B8. The owner's reports page is a tool for the owner, built for phone width first, like the editor. |
| **III. Performance** | **Pass by design, measured before merge.** Nothing runs before the first frame. The tracker does constant work per page change. The mark repaints one page. Lists are lazy. A group khatma shows its last copy at once, then refreshes; it reads the server only while its screen is open. Measured in quickstart A9 and B8. |
| **IV. Lean** | **Pass, with one justified package.** Release A adds no package and no asset. Release B adds `flutter_secure_storage` (Complexity Tracking). The functions have no packages. Nothing runs in the background: reminders are local notifications the reader turned on, and the app makes no request while closed. The size check runs on both platforms. |
| **V. Simplicity** | **Pass with justified additions** (Complexity Tracking). One division function serves every plan. One tracker, one mark and one Done row serve wirds and group parts. The reminder reuses the prayer alarm code. The server follows the existing functions' layout. No setting is added beyond the reminder. |
| **Platform and store** | **Pass, with one recorded exception.** Permissions are asked in context: notifications only when the reader turns the reminder on (FR-020). The key is in the platform's secure storage on phones; browsers have none, so there it is in the site's data (spec Assumptions; Complexity Tracking). The stores' rules on user-generated content are met by FR-059 to FR-063 and FR-068. The privacy answers and the policy change before release B (FR-069, research R23). HTTPS only. |
| **Workflow** | **Pass.** specify → clarify → plan → tasks → implement. Before each release: the quickstart on one iPhone and one Android phone, and the performance and size checks, since the feature touches the reading screen, lists, a dependency and work after startup. |

**Gate result**: passes before and after design. No unresolved clarifications. Six owner steps
are needed before release B can be tested end to end or released (research R26). None blocks the
code, and none affects release A.

## Project Structure

### Documentation (this feature)

```text
specs/014-khatma-management/
├── plan.md              # This file
├── research.md          # Phase 0: R1–R26
├── data-model.md        # Phase 1: device tables, server tables, models
├── quickstart.md        # Phase 1: checks A1–A9 and B1–B8, and the owner's setup
├── contracts/
│   ├── wird-division.md             # divide(): rules, examples, tests
│   ├── khatma-ui-and-reminders.md   # screens, reading screen, place, reminder, native
│   ├── group-api.md                 # /api/khatma, owner endpoints, the Worker
│   └── group-ui.md                  # group screens, links, refreshing, safety flows
├── checklists/
│   └── requirements.md  # From /speckit-specify
└── tasks.md             # Phase 2 (/speckit-tasks, not created here)
```

### Source Code (repository root)

```text
lib/
├── main.dart                          # create the controllers; load after the first frame
├── app/
│   ├── app.dart                       # KhatmaScope; B: the link host
│   ├── theme/tokens.dart, app_theme.dart  # khatmaMark colour
│   └── l10n/app_ar.arb, app_en.arb    # new strings
├── data/user_repository.dart          # schema 2 (A) and 3 (B); startup skips the feature's rows
├── shared/
│   ├── reader_state.dart              # spreadOnScreen (R3)
│   └── mathani_icons.dart             # khatma and group icons
├── features/
│   ├── khatma/                        # NEW
│   │   ├── khatma_models.dart         # Khatma, Wird, KhatmaPlan, Reading, Reminder
│   │   ├── khatma_division.dart       # divide, preview — plain Dart (R2)
│   │   ├── khatma_repository.dart     # the tables; one transaction per state change (R1)
│   │   ├── reading_tracker.dart       # the place rules — plain Dart (R3)
│   │   ├── khatma_controller.dart     # state, actions, readings, Undo (R4)
│   │   ├── khatma_reminders.dart      # the ten reminders (R8)
│   │   ├── khatma_screen.dart         # the Khatma screen (R7)
│   │   ├── plan_sheet.dart
│   │   ├── wird_list_screen.dart
│   │   ├── khatma_complete_screen.dart
│   │   ├── reader_khatma_row.dart     # the Done row and "pages left" (R6)
│   │   └── group/                     # NEW, release B
│   │       ├── group_models.dart      # Snapshot, Part, Participant
│   │       ├── group_code.dart        # parse, format, link — plain Dart (R16)
│   │       ├── group_client.dart      # the API calls (R17)
│   │       ├── group_repository.dart  # kept khatmas, places, waiting marks (R18)
│   │       ├── group_controller.dart  # list, one khatma, timers, readings
│   │       ├── group_section.dart     # the list on the Khatma screen
│   │       ├── group_screen.dart
│   │       ├── group_start_sheet.dart
│   │       ├── group_terms.dart
│   │       └── group_link_host.dart   # opens the khatma of a link
│   ├── reader/
│   │   ├── mushaf_page_renderer.dart  # endMarks, khatmaMark (R5)
│   │   ├── mushaf_view.dart           # passes the marks; sets spreadOnScreen; page label
│   │   ├── flowing_view.dart          # the mark on the ayah-end sign
│   │   ├── reader_screen.dart         # button, toolbar fit, pages left, Done row (R6)
│   │   └── ayah_actions.dart          # "Set khatma place here"
│   ├── onboarding/onboarding_steps.dart, button_tour.dart  # the khatma stop (R12)
│   ├── prayer_times/prayer_alerts.dart     # 60 → 52 alerts (R8)
│   └── settings/about_section.dart         # B: the contact address
└── platform/
    ├── local_notifications_io.dart    # NEW: what prayer alerts and the reminder share (R9)
    ├── prayer_notifications_io.dart   # uses it; at most 52 pending
    ├── khatma_reminders.dart, _io, _web    # NEW: KhatmaReminderPlatform
    ├── key_store.dart, _io, _web      # NEW, B: the key (R15)
    └── app_links.dart, _io, _web      # NEW, B: takeLink and links (R16)

android/app/src/main/
├── kotlin/app/mathani/mathani/
│   ├── PrayerAlarmStore.kt            # a second store file; the wird kind
│   ├── PrayerNotificationsPlugin.kt   # replaceReminders, cancelReminders, clearReminders
│   ├── PrayerAlarmReceiver.kt         # posts reminders; 3-hour lateness; restores both files
│   └── MainActivity.kt                # B: hands a link to the device channel
└── AndroidManifest.xml                # B: the verified link filter; Flutter's handler off
android/app/src/test/kotlin/…          # store and receiver tests

ios/Runner/
├── SceneDelegate.swift                # B: reads a link at connect and at continue
├── AppDelegate.swift                  # B: takeLink and the link event on the device channel
├── Info.plist                         # B: Flutter's handler off
└── Runner.entitlements                # NEW, B: applinks:get.mthani.app

functions/                             # release B
├── _lib/
│   ├── khatma-schema.sql              # NEW: the five tables
│   ├── khatma-store.js                # NEW: the queries, the conditional take, the limits
│   ├── khatma-api.js                  # NEW: dispatch for /api/khatma/*
│   ├── khatma-text.js                 # NEW: the checks on names and titles
│   ├── khatma-words.js                # NEW: the owner's word lists
│   ├── khatma-admin.js                # NEW: the owner's two endpoints
│   └── editor-api.js                  # routes `khatma …` to khatma-admin.js
└── api/khatma/[[path]].js             # NEW

workers/khatma-ops/                    # NEW, release B
├── wrangler.toml                      # the database, email sending, two schedules
└── src/index.js                       # email new reports; the daily removal

web/                                   # release B
├── _routes.json                       # + /api/khatma/*
├── _headers                           # /k/* no-cache; the two association files as JSON
├── .well-known/apple-app-site-association, assetlinks.json   # NEW
└── editor/khatma.html, khatma.js      # NEW: the owner's reports page

wrangler.toml                          # B: KHATMA_DB, and the preview database
tool/
├── khatma/                            # NEW, B: node --test suites and their support file
└── web_deploy.mjs                     # B: checks the function and the association files
.github/workflows/ci.yml               # B: node --test tool/khatma/
docs/
├── store/privacy.md, listing_ar.md, listing_en.md   # B: the group khatma (R23)
└── release.md                         # B: setup, checklist lines

test/
├── unit/
│   ├── khatma_division_test.dart          # NEW: rules and examples
│   ├── khatma_division_db_test.dart       # NEW: SC-003, SC-004 on quran.db
│   ├── reading_tracker_test.dart          # NEW: P1–P11
│   ├── khatma_repository_test.dart        # NEW: state changes, migration, bookmarks kept
│   ├── khatma_dates_test.dart             # NEW
│   ├── khatma_reminders_test.dart         # NEW: N1–N11
│   └── group_code_test.dart, group_client_test.dart, group_waiting_marks_test.dart  # NEW, B
└── widget/
    ├── khatma_screen_test.dart, plan_sheet_test.dart            # NEW
    ├── reader_khatma_controls_test.dart                         # NEW: button, fit, Done, Undo
    ├── wird_end_mark_test.dart (+ goldens, both themes)         # NEW
    ├── set_khatma_place_test.dart, khatma_tour_stop_test.dart   # NEW
    ├── sideways_screens_test.dart                               # + the Khatma screens
    └── group_screen_test.dart, group_terms_test.dart, group_link_test.dart   # NEW, B
```

**Structure Decision**:
- **The app's code** lives in one new feature folder, `lib/features/khatma/`, with the group
  khatma in a subfolder, so release A can ship without it. The two files of rules,
  `khatma_division.dart` and `reading_tracker.dart`, have no Flutter imports, so they are tested
  without a device.
- **Platform code** follows the existing pattern: one file in `lib/platform/` with `_io` and
  `_web` halves for each thing that differs.
- **Server code** follows the prayer and Mutashabihat functions: thin entry points in
  `functions/api/`, logic in `functions/_lib/`, tests under `tool/`. The Worker is the one part
  that cannot be a function, and it gets its own small folder.
- **Native code** grows inside the files that already hold the alarm store, the plugin, the
  receiver and the device channel. No new plugin or channel is added.

## Complexity Tracking

| Addition | Why needed | Simpler alternative rejected because |
| --- | --- | --- |
| Package `flutter_secure_storage` (release B) | The key proves which parts are the reader's, so it is sensitive data, and the constitution requires platform secure storage for it. | The key in `user.db`: against the constitution's rule. Hand-written Keychain and Keystore code: cryptographic code to own and test on two platforms, for no smaller app. |
| The key outside secure storage in browsers | Browsers have no secure storage. A person without the app must still be able to take a part (FR-046). | No group khatma on the web: the link would be useless to anyone without the app. |
| A second D1 database | Reader data needs its own lifetime, its own preview copy, and no path to the published content. | Tables in the Mutashabihat database: a mistake in one feature's cleanup could reach the other's data. |
| The Worker `mthani-khatma-ops` | Pages Functions cannot send email or run on a schedule. Reports must reach the owner within minutes (FR-061), and expired khatmas must be removed even with no traffic (FR-066). | A third-party email API: another processor sees reported names. Removal only on the next request: data would outlive its time on a quiet day. |
| Universal Links and App Links, with native link reading | The link must open the installed app (FR-046). | Flutter's own handler: it pushes the link as a route name the app does not have, and its behaviour with the audio service's shared engine is unverified. A package: a dependency for two short native entry points. |
| One shared file for local notifications | Prayer alerts and the reminder use one Android channel handler and one iOS tap callback. Two owners would replace each other. | A second channel and receiver: more native code than the shared file removes. |
| The owner's reports page | Reports must be reviewed within 24 hours (FR-063), from a phone if need be. | SQL commands by hand: slow, error-prone, and not possible away from the development machine. |
| A second store file for reminders on Android | A prayer refill replaces its whole list. Reminders in the same list would be wiped by it. | One list with an owner column: every prayer refill would have to carry the reminders along. |
