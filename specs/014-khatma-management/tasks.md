---

description: "Task list for the personal and group khatma (specs/014)"
---

# Tasks: Personal and Group Khatma

**Input**: Design documents from `specs/014-khatma-management/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Included. The plan (Technical Context › Testing) and each contract's "What the tests
must show" name the test files, and SC-003, SC-004, SC-015, SC-019 and SC-021 are checked by
tests. Within each story, write the tests first and see them fail.

**Organization**: Two releases (research R26). **Release A** (Phases 1 to 8) is the personal
khatma: Stories 1, 2, 3, 4 and 8. **Release B** (Phases 9 to 13) is the group khatma: Stories
5, 6 and 7. Story 8 is P3 but belongs to release A, so it comes before Stories 5 to 7. Release
A can ship without any task of release B.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: The user story the task belongs to (US1 to US8, as in spec.md)
- Paths are relative to the repository root

## Rules that apply to every task

- **Wording**: use the proposed text in the "Wording" tables of
  [contracts/khatma-ui-and-reminders.md](./contracts/khatma-ui-and-reminders.md) and
  [contracts/group-ui.md](./contracts/group-ui.md). Strings go in `lib/app/l10n/app_en.arb` and
  `lib/app/l10n/app_ar.arb`, then `flutter gen-l10n`.
- **Every screen**: Arabic and English (RTL and LTR), light and dark themes, safe areas, text
  scaling, usable sideways (specs/013), touch targets of at least 44 pt on iPhone and 48 dp on
  Android (`minTouchTarget` in `lib/app/theme/app_theme.dart`), a semantic label on every
  control, feedback within 100 ms. Numbers and dates follow the interface language (FR-040).
- **Neutral wording** about missed days: dates and amounts only. No streaks, scores or rankings
  (FR-029).
- **Startup**: nothing of this feature runs, and no request is made, before the first frame
  (FR-039). No permission is asked at startup.
- **Commits**: only when the owner asks. No AI attribution lines in commit messages.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Branch, strings and icons that every release A story uses.

- [X] T001 Create and switch to git branch `014-khatma-management` from the current head, so that `specs/014-khatma-management/` and the code of this feature live on it (the spec and plan were written on `013-page-zoom-similar-labels`; no branch exists yet)
- [X] T002 [P] Add every release A English string to `lib/app/l10n/app_en.arb`, from the Wording table and the "User-visible states" table of `contracts/khatma-ui-and-reminders.md`: screen title, "Today's wird", Read / Continue, Done, Undo, "{n} pages left" (ICU plural), "End of today's wird at ayah {n}", "Today's wird ends on this page", "Set khatma place here" and its confirmation ("{read} wirds become read, {unread} unread"), Start a khatma, the one-line explanation, the plan sheet labels and summary "{n} days · {a} to {b} pages a day · ends {date}", "from page {p}", Change plan, Pause / Resume, "Paused since {date}", "Starts on {date}", End khatma and its confirmation, "A khatma is already in progress", progress labels, "Expected finish {date}, {n} days after the planned date", All wirds, "not read", Daily reminder, notifications blocked / Open settings, "may come a few minutes late", "Reminders are available in the phone apps", reminder title "Today's wird" and bodies ("Juz 3 · pages 42 to 62", "Wird 12 of 29 · pages 240 to 260"), Finished khatmas, "{n} khatmas finished", the completion screen texts, the tour stop's hint
- [X] T003 [P] Add the Arabic of every key of T002 to `lib/app/l10n/app_ar.arb` from the same tables (for example الختمة، ورد اليوم، اقرأ / تابع، أتممت الورد، بقي {n} صفحة، اجعل موضع الختمة هنا), then run `flutter gen-l10n` and check `flutter analyze` is clean
- [X] T004 [P] Add a khatma icon (for the toolbar and the tour) to `lib/shared/mathani_icons.dart`, drawn in the style of the existing icons

---

## Phase 2: Foundational (Blocking Prerequisites for Release A)

**Purpose**: The models, the tables, the controller and the reader hooks that Stories 1 to 4
and 8 all use.

**⚠️ CRITICAL**: No release A story can begin until this phase is complete.

- [X] T005 [P] Create the models in `lib/features/khatma/khatma_models.dart` (plain Dart, no Flutter import): `KhatmaState` (`active`, `paused`, `finished`); `Khatma` with the columns of data-model.md › `khatmas` (`start_ayah` "Ayah id of the start point, 1 to 6236"; `place_page` "a page of the current wird, 1 to 604"; `paused_on` and `finished_on` nullable; dates as `YYYY-MM-DD`); `Wird` (`khatmaId`, `number`, `firstAyah`, `lastAyah`, `readOn` nullable `YYYY-MM-DD`); `KhatmaPlan` as a sealed type that reads and writes exactly `{"kind":"marks","quarters":q}` with q in 1, 2, 4, 8, 16, 24 or 80, `{"kind":"seven"}`, and `{"kind":"days","days":n}` with n from 1 to 604; `ReminderSetting` that reads and writes `{"on": true, "time": "05:30"}` (missing means off); `WirdRange(firstAyah, lastAyah)`; `Reading` (kind: personal wird or group part, first and last ayah, first and last page, place, `following`); a `CalendarDay` value for `YYYY-MM-DD` with day arithmetic, and a `Clock` typedef so tests inject today (research R11)
- [X] T006 Raise `_schemaVersion` from 1 to 2 in `lib/data/user_repository.dart` and add, in a forward-only migration that never touches `bookmarks`, `reading_state` or `preferences`, the tables `khatmas` (`id` INTEGER key, `state` TEXT, `plan` TEXT, `start_ayah` INTEGER, `start_date` TEXT, `planned_finish` TEXT, `paused_on` TEXT null, `place_page` INTEGER, `wird_count` INTEGER, `finished_on` TEXT null, `created_at` INTEGER) and `khatma_wirds` (`khatma_id`, `number` as the key, `first_ayah`, `last_ayah`, `read_on` TEXT null). Add `khatma.reminder` to the keys that `loadStartup` skips, as `prayerStateKey` is today. Works on iOS, Android and the web database
- [X] T007 Create `lib/features/khatma/khatma_repository.dart` over `UserRepository`'s database: load the khatma that is not `finished` with its wirds, load finished khatmas newest first, read and write the `khatma.reminder` preference. Every state change of data-model.md › State changes is one transaction, and writes are serialized. Starting checks inside its transaction that "at most one row has a state other than `finished`" (FR-005). Wird rows are deleted with their khatma in the same transaction ("the app does not rely on cascades"). This task adds `start`, `markRead`, `undo` (restores a saved copy of the khatma row and its wird rows) and `savePlace`; later stories add the rest
- [X] T008 [P] Add `spreadOnScreen` (bool) to `ReaderController` in `lib/shared/reader_state.dart`, and set it from `lib/features/reader/mushaf_view.dart` whenever `showsSpread` changes, so the pages on screen are the odd page and the next one when it is true (research R3). Do not change `jumpSerial` or any existing behaviour
- [X] T009 [P] Add the colour token `khatmaMark`, the brand terracotta, to `lib/app/theme/tokens.dart` for the light and dark themes, add it to `MushafPalette` in `lib/features/reader/mushaf_page_renderer.dart` and pass it where `mushaf_view.dart` builds the palette. It must have at least 3:1 contrast against the page colour in both themes
- [X] T010 Create `KhatmaController` (`ChangeNotifier`) in `lib/features/khatma/khatma_controller.dart`: built at launch and idle until `load()`; `load()` reads the open khatma, its wirds and the reminder setting through `KhatmaRepository`; exposes the khatma, the current wird ("the lowest `number` with `read_on` null"), whether today is read ("some wird has `read_on` equal to today"), pages in the khatma, pages read, and the readings list (one `Reading` for the current wird); takes a `Clock`
- [X] T011 Wire the feature into the app: create `KhatmaRepository` and `KhatmaController` in `lib/main.dart`, provide them through a `KhatmaScope` (an `InheritedNotifier`, defined in `lib/features/khatma/khatma_controller.dart`) in `lib/app/app.dart`, and call `load()` from a post-frame callback so nothing runs before the first frame (FR-039, research R10)
- [X] T012 [P] Write `test/unit/khatma_repository_test.dart`: the migration from a schema 1 database keeps every bookmark, the reading position and preferences; a second `start` while one khatma is `active` or `paused` is refused; `start`, `markRead`, `undo` and `savePlace` each leave the tables as data-model.md › State changes says; `loadStartup` does not return `khatma.reminder`

**Checkpoint**: The tables exist, the controller loads after the first frame, and the reader
reports two facing pages.

---

## Phase 3: User Story 1 - Plan a khatma and read today's wird (Priority: P1) 🎯 MVP

**Goal**: The reader plans a khatma, opens today's wird in the Mushaf, sees where it ends and
how many pages are left, and marks it Done.

**Independent Test**: With the network off, start a "juz a day" khatma, read the first wird to
its end, mark it done, close and reopen the app. The Khatma screen shows 1 of 30 read and the
second wird as next (quickstart A1, A2).

### Tests for User Story 1 ⚠️

- [X] T013 [P] [US1] Write `test/unit/khatma_division_test.dart` on a small synthetic index: rules 1 to 7 of `contracts/wird-division.md` (cover with no gap or overlap, marks every q-th quarter, seven-day surah starts 5, 10, 17, 26, 37, 50, `days(n)` page spread ⌊(k−1)·p/m⌋ with m = min(n, p), pages a day → `days(⌈p/P⌉)`, finish date → `days(F − start + 1)` and refused before the start date, a short first wird off a boundary, pages counted as last − first + 1)
- [X] T014 [P] [US1] Write `test/unit/khatma_division_db_test.dart` on the bundled `quran.db`: SC-003 (all seven mark amounts and `seven` from the first ayah of each of the 604 pages; `days(n)` for every n from 1 to 604 from pages 1, 2, 50, 302, 603 and 604; n = 1, 2, 7, 29, 30, 100, 365 and 604 from every page), SC-004 (custom sizes differ by at most one page; every marks/seven wird start after the first is a boundary), and every row of the Examples table of `contracts/wird-division.md` exactly (for example `marks(8)` wird 3 = Al-Baqarah 253 to Al 'Imran 92, pages 42 to 62; `seven` = 106, 102, 74, 85, 79, 72, 87 pages; 50 pages a day = 13 wirds of 46 or 47 pages; `days(40)` from page 600 = 5 wirds)
- [X] T015 [P] [US1] Write `test/unit/khatma_dates_test.dart` with an injected clock: planned finish = start date + wirds − 1; expected finish = today + unread wirds − 1 when today is not read, from tomorrow when it is; before the start date = start date + wirds − 1 (FR-027, research R11); a day is the phone's calendar date, so a wird read after midnight counts for the new day
- [X] T016 [P] [US1] Write `test/widget/khatma_screen_test.dart` and `test/widget/plan_sheet_test.dart`: no khatma shows one line and "Start a khatma"; "a juz a day" shows 30 days and the finish date before Start; 29 days shows 20 to 21 pages a day; start from Juz 16 shows 15 days; 50 pages a day shows 13 days of 46 to 47 pages; after Start the wird card shows "1 of 30", Al-Fatiha 1 to Al-Baqarah 141, pages 1 to 21; a second start is refused with "A khatma is already in progress"; a start date three days ahead shows "Starts on {date}"
- [X] T017 [P] [US1] Write `test/widget/wird_end_mark_test.dart` with one golden per theme (light, dark) of page 62 with wird 3 current: the ayah-end sign of Al 'Imran 92 is painted in `khatmaMark`, the triangle sits in the end-side (left) margin on that line, word rectangles are identical to the page without the mark, the page's semantics label contains "End of today's wird at ayah 92", nothing is drawn during a memorization session, and `khatmaMark` has at least 3:1 contrast against the page colour in both themes. Tag the golden tests `golden`
- [X] T018 [P] [US1] Write `test/widget/reader_khatma_controls_test.dart`: the toolbar order is index, search, listen, memorize, khatma, bookmark, settings; at 320 wide on iOS all seven fit at 44 pt; at 320 wide on Android the toolbar scrolls sideways and every button stays 48 dp; the header's second line ends with "· 21 pages left" on page 1 of wird 1 and never wraps; the Done row shows only when the wird's last page is on screen; Done shows the "Today's wird is done" snack bar with Undo; Undo restores the wird
- [X] T019 [P] [US1] Write `test/widget/khatma_tour_stop_test.dart`: the first-run tour and the tour replayed from Settings each have one stop on the Khatma button, after the memorization stop and before Settings
- [X] T020 [P] [US1] Add the Khatma screen and the plan sheet at 780 × 360 to `test/widget/sideways_screens_test.dart` (no overflow, as for the specs/013 screens)

### Implementation for User Story 1

- [X] T021 [US1] Implement `divide(index, startAyah, plan) → List<WirdRange>` and `preview(index, startAyah, plan, startDate) → (wirds, fewestPages, mostPages, finishDate)` in `lib/features/khatma/khatma_division.dart` (plain Dart, no Flutter import, no query) exactly as rules 1 to 7 of `contracts/wird-division.md`. Its `index` is each ayah's page, the 240 quarter starts and the 114 surah starts; if `QuranRepository` in `lib/data/quran_repository.dart` does not already expose these from memory, add a read-only accessor there. Also add a wird name helper: "Juz *n*", "Hizb *n*" or a quarter's name when the wird is exactly one of them, otherwise its number (data-model.md › Values worked out). `divide` for 604 wirds must take under 5 ms. Make T013 and T014 pass
- [X] T022 [US1] Add to `KhatmaController` in `lib/features/khatma/khatma_controller.dart`: `start(plan, startAyah, startDate)` (refused while one is in progress, FR-005; wirds from `divide`; `place_page` = the start point's page; `planned_finish` = start date + wirds − 1; on the web, call `Device.keepBrowserData()` from `lib/platform/device.dart` as the first bookmark does, FR-042); `markRead()` for the current wird (`read_on` = today; the place becomes the next wird's first page; if none is left the khatma finishes, see US8); `undo()`; the derived values of data-model.md (pages read, expected finish); and the reading-screen answers `endMarksOn(page)` (ayah-end word ids where a reading ends on that page), `pagesLeft(pagesOnScreen)` (reading's last page − first page on screen + 1) and `readingsEndingOn(pagesOnScreen)`. All return nothing while a memorization session is on
- [X] T023 [P] [US1] Build the plan sheet in `lib/features/khatma/plan_sheet.dart`: Daily amount (the seven amounts with their number of days), Seven days, Custom (days 1 to 604, pages a day 1 to 604, or a finish date); Start from (the beginning, this page, or a juz, surah or page); Start on (today or a later date); the summary line "{n} days · {a} to {b} pages a day · ends {date}" from `preview`, updated on every change; Start. Take an optional preselected plan (used by US8)
- [X] T024 [US1] Build `KhatmaScreen` in `lib/features/khatma/khatma_screen.dart`: no khatma (one line, "Start a khatma" opening the plan sheet); in progress, the wird card (number of the total, name, start and end as surah, ayah and page, pages, Read or Continue once begun, Done); when today is read, "Today's wird is done", the next wird and "Read now"; "Starts on {date}" before the start date. Read / Continue pops back to the reader and calls `ReaderController.jumpToPage(place)` in the reader's current layout. Leave empty slots, in this order, for the progress section (US4), the reminder section (US3), group khatmas (release B) and the record (US8)
- [X] T025 [US1] Add `endMarks` (a set of ayah-end word ids) to `MushafPageRenderer` in `lib/features/reader/mushaf_page_renderer.dart`: paint each listed ayah-end sign in `palette.khatmaMark` through the existing `saveLayer` + `ColorFilter.mode(tint, BlendMode.srcIn)` tint path, and paint a small filled triangle in the end-side margin (the left margin; the hizb and sajdah marks use the start-side margin) centred on that line. Include `endMarks` in `shouldRepaint` only, so a change repaints without layout. No word moves and nothing is drawn over text (FR-010, research R5)
- [X] T026 [US1] In `lib/features/reader/mushaf_view.dart`, pass `endMarks` from `KhatmaScope.endMarksOn(page)` for each page (single page, two facing pages and the sideways scrolling page), and add "End of today's wird at ayah {n}" to the page's semantics label when a mark is on it. Pass nothing during a memorization session. Make T017 pass
- [X] T027 [P] [US1] In `lib/features/reader/flowing_view.dart`, give the ayah-end sign of the last ayah of each reading the `khatmaMark` colour and an underline without changing its text, and give it the semantics label "End of today's wird at ayah {n}"; nothing during a memorization session
- [X] T028 [P] [US1] Build `lib/features/khatma/reader_khatma_row.dart`: one row per reading in `readingsEndingOn(pagesOnScreen)` with "Today's wird ends on this page" and a Done button (two readings on one page give two named rows), and a helper that returns the "· {n} pages left" suffix for the header. Nothing during a memorization session
- [X] T029 [US1] In `lib/features/reader/reader_screen.dart`: add the Khatma button between memorize and bookmark with key `TourTargets.khatma`, pushing `KhatmaScreen`; when 7 × `minTouchTarget` is wider than the toolbar, put the buttons in a horizontal scroll view and never shrink one; append the pages-left suffix to the header's second line, shrinking to fit without wrapping; show the Done rows above the toolbar with the controls (Mushaf layout) or while that page is on screen (flowing layout); after Done show the existing snack bar pattern "Today's wird is done" with Undo for about 6 seconds. Make T018 pass
- [X] T030 [US1] Add `OnboardingStep.khatma` (kind button) after `memorize` and before `settings` in `lib/features/onboarding/onboarding_steps.dart`, and the `khatma` target and its hint in `TourTargets` in `lib/features/onboarding/button_tour.dart`, shown in the first-run tour and the replay from Settings (FR-043, research R12). Make T019 pass

**Checkpoint**: Story 1 works alone and offline: quickstart A1 and A2 pass.

---

## Phase 4: User Story 2 - Keep my place in the khatma whatever else I read (Priority: P1)

**Goal**: The khatma place follows the reader's own page turns, ignores jumps, recitation and
memorization, marks a wird read when the reader reads on past it, and can be set by hand.

**Independent Test**: Read part of a wird, then open other surahs through the index, search and
a bookmark, play a recitation and run a memorization session. Tap Continue and check the page.
Read past the end of the wird and check the khatma moved on (quickstart A3, A4).

### Tests for User Story 2 ⚠️

- [X] T031 [P] [US2] Write `test/unit/reading_tracker_test.dart`: rows P1 to P11 of `contracts/khatma-ui-and-reminders.md` › The place, each with one page, with two facing pages, and with the flowing layout (pages from the top ayah)
- [X] T032 [P] [US2] Write `test/unit/khatma_controller_test.dart` with a fake `ReaderController` and clock: a page change with an unchanged `jumpSerial` while following moves the place and saves it; a page change with a changed `jumpSerial` does not; reading on past the last page marks the wird read, moves the place to the page on screen or the next wird's first page when that is later, and emits an Undo event; Undo restores the wird and puts the place on its last page; page changes during a recitation follow (jumps) and during a memorization session change nothing
- [X] T033 [P] [US2] Write `test/widget/set_khatma_place_test.dart`: the long-press sheet offers "Set khatma place here" only while a personal khatma is in progress; the confirmation states how many wirds become read and how many unread; on an ayah in Juz 10 of a "juz a day" khatma, Juz 10 is current and the nine before are read with today's date; then on an ayah in Juz 5, Juz 5 and later are unread

### Implementation for User Story 2

- [X] T034 [P] [US2] Implement `ReadingTracker` in `lib/features/khatma/reading_tracker.dart` (plain Dart): `onJump(firstPage, lastPage)` sets `following` when the pages on screen include the place; `onMove(firstPage, lastPage, byReader)` while following sets the place to the first page on screen clamped to the reading's pages and reports `passedEnd` when the first page on screen is after the reading's last page; while not following, sets `following` when the pages on screen include the place. A `marksOnPass` flag is false for group parts, which never report `passedEnd` (P11). Make T031 pass
- [X] T035 [US2] In `lib/features/khatma/khatma_controller.dart`, listen to `ReaderController`: keep the last `jumpSerial`; compute the pages on screen from the page and `spreadOnScreen` (or the flowing top ayah's page); call `onJump` or `onMove`; ignore everything while a memorization session is on (use the session state the reader screen already reads in `lib/features/memorization/`); save the place through `KhatmaRepository.savePlace`, coalesced like the reader's 500 ms save; on `passedEnd` call `markRead` and emit an event carrying Undo (FR-016). Make T032 pass
- [X] T036 [US2] In `lib/features/reader/reader_screen.dart`, show the same "Today's wird is done" snack bar with Undo when the controller reports a wird read by reading on
- [X] T037 [US2] Add `setPlaceAt(ayah)` to `KhatmaRepository` in `lib/features/khatma/khatma_repository.dart` and to `KhatmaController` in `lib/features/khatma/khatma_controller.dart`: one transaction where wirds before the one holding the ayah become read (today for those newly marked), that wird and later ones unread, and the place becomes the ayah's page; plus `countChangesFor(ayah)` returning how many wirds become read and how many unread (FR-017)
- [X] T038 [US2] Add "Set khatma place here" to the long-press sheet in `lib/features/reader/ayah_actions.dart`, shown only while a personal khatma is in progress (state `active`, including before its start date, or `paused`: the same rows FR-005 counts), with a confirmation dialog stating the counts from `countChangesFor`, then `setPlaceAt`. Make T033 pass
- [X] T039 [US2] In `lib/features/khatma/khatma_screen.dart`, show Continue instead of Read once the place is after the current wird's first page, and keep Done on the card working without opening the Mushaf (Story 2 scenario 9)

**Checkpoint**: Stories 1 and 2 work: quickstart A3 and A4 pass.

---

## Phase 5: User Story 3 - Be reminded once a day (Priority: P2)

**Goal**: One local notification a day at the chosen time, only when a wird is waiting, through
the alarm and notification code that prayer alerts use.

**Independent Test**: Turn on the reminder two minutes ahead, lock the phone and wait; tap it.
Read the wird before the time the next day and see none. Restart the phone and leave the app
closed for 7 days (quickstart A5).

### Tests for User Story 3 ⚠️

- [X] T040 [P] [US3] Write `test/unit/khatma_reminders_test.dart` with a fake `KhatmaReminderPlatform` and clock: rows N1 to N11 of `contracts/khatma-ui-and-reminders.md` › The reminder; ids are a hash of the date, so a rebuild never doubles one; texts "Today's wird" and "Juz 3 · pages 42 to 62" / "Wird 12 of 29 · pages 240 to 260" in both languages; concurrent `sync()` calls are merged into one `replace`
- [X] T041 [P] [US3] Change the expectation in `test/features/prayer_times/prayer_alerts_test.dart` from 60 to 52 alerts ("at most 52, all in the future, in time order, never sunrise") and check that 52 alerts still cover more than 7 days
- [X] T042 [P] [US3] Extend `android/app/src/test/kotlin/app/mathani/mathani/PrayerAlarmStoreTest.kt`: a store built with the file name `mathani_khatma_reminders` keeps its list apart from `mathani_prayer_alerts` (a prayer replace leaves reminders untouched and the reverse); `PrayerAlert.kind` accepts `wird`; the 64 cap holds per file
- [X] T043 [P] [US3] Extend `android/app/src/test/kotlin/app/mathani/mathani/PrayerAlarmReceiverTest.kt`: a `wird` alert is posted up to 3 hours late and dropped beyond; prayer alerts keep 15 minutes; after boot both files' alarms are set again

### Implementation for User Story 3

- [X] T044 [US3] Create `lib/platform/local_notifications_io.dart` holding what prayer alerts and the reminder share: one `FlutterLocalNotificationsPlugin` initialisation whose iOS tap callback hands each tap to its owner by payload prefix (`mathani.prayer.v2` or `mathani.khatma.v1`), and one handler of `MethodChannel('app.mathani/prayer_notifications')` that routes `opened {kind, alertId}` events: prayer kinds to `PrayerAlerts`, `wird` to `KhatmaReminders`. Refactor `lib/platform/prayer_notifications_io.dart` to use it with no change of behaviour, and lower `IosPrayerAlerts.max` from 60 to 52
- [X] T045 [US3] Lower the default `max` from 60 to 52 in `lib/features/prayer_times/prayer_alerts.dart` (research R8: 52 + 10 ≤ 64). Make T041 pass
- [X] T046 [P] [US3] Create `lib/platform/khatma_reminders.dart` (the `KhatmaReminderPlatform` interface and conditional import: `status()` without prompting, `requestPermission()`, `openSettings()`, `replace(List<Reminder>)`, `clearDelivered(ids)`, `opened` stream, `takeLaunchOpen()`), `lib/platform/khatma_reminders_io.dart` (iOS: `zonedSchedule` at absolute times in the UTC zone, at most 10 pending, default sound, thread `mathani.khatma`, payload prefix `mathani.khatma.v1`, cancel own pending ids not in the list; Android: `replaceReminders {generation, alerts, channelName}`, `cancelReminders`, `clearReminders {ids}` through the shared channel of T044), and `lib/platform/khatma_reminders_web.dart` (`status()` returns `unsupported`, everything else does nothing)
- [X] T047 [US3] In `android/app/src/main/kotlin/app/mathani/mathani/PrayerAlarmStore.kt`, take the preferences file name as a constructor argument (prayer alerts keep `mathani_prayer_alerts`; reminders use `mathani_khatma_reminders`) and add `wird` to the kind whitelist. Make T042 pass
- [X] T048 [US3] In `android/app/src/main/kotlin/app/mathani/mathani/PrayerNotificationsPlugin.kt`, add `replaceReminders`, `cancelReminders` and `clearReminders` on the existing channel; create the channel `khatma_reminder_v1` with the phone's default sound and default importance; give reminder alarms their own intent action and data URI so their ids never meet prayer ids; return `{pending: int}` from `replaceReminders`
- [X] T049 [US3] In `android/app/src/main/kotlin/app/mathani/mathani/PrayerAlarmReceiver.kt`, post a due `wird` alert on `khatma_reminder_v1`, drop it only when more than 3 hours late (prayer alerts keep `LATENESS_MS = 15 * 60_000L`), open `MainActivity` with `kind = "wird"` on tap, and after boot, a clock change or an app update set the alarms of both store files again. No new manifest permission. Make T043 pass
- [X] T050 [US3] Create `KhatmaReminders` in `lib/features/khatma/khatma_reminders.dart` (app-scoped, lazy): `sync()` builds the reminders for today and the next nine days at the chosen time per research R8 (a day is due when a personal khatma is `active`, has started and that day has no read wird, or when group parts wait — an empty provider in release A); leaves out today when read, when the time has passed, or while a page of the current wird is on screen (puts it back when the reader leaves that page or the app); builds the texts in the interface language; merges calls made while one runs; calls `replace`; calls `clearDelivered` for today's id once today is read. Run it after the first frame, on resume, and after every change from `KhatmaController` (reminder setting, start, read, Undo, place, plan, pause, end). Make T040 pass
- [X] T051 [US3] Add the reminder section to `lib/features/khatma/khatma_screen.dart`: a switch (off by default) and a time picker; turning it on asks for notification permission at that moment only (FR-020) and saves `khatma.reminder`; when refused, keep "on" and the time and show "notifications blocked" with Open settings; on Android without exact alarms, "may come a few minutes late" with no action; on the web, only "Reminders are available in the phone apps" with the store links
- [X] T052 [US3] Create `lib/features/khatma/reminder_open_host.dart`, modelled on `lib/features/prayer_times/prayer_notification_open_host.dart`, and mount it in `lib/app/app.dart`: a tap (or `takeLaunchOpen()` after the first frame) that names one wird opens the Mushaf at its place; one that names more opens `KhatmaScreen`; during a memorization session it opens the app without moving the page or ending the session (FR-023)

**Checkpoint**: Stories 1 to 3 work: quickstart A5 passes, and prayer alerts still have more
than 7 days pending.

---

## Phase 6: User Story 4 - See how the khatma is going and change it (Priority: P2)

**Goal**: Honest progress numbers, the list of wirds, and ways to change the plan, pause,
resume and end.

**Independent Test**: Start a 30-day khatma, read 3 wirds over 5 days and check the dates. Read
two wirds in one day. Change the plan to finish on the first planned date. Pause for 3 days,
resume and check the dates and the reminder (quickstart A6).

### Tests for User Story 4 ⚠️

- [X] T053 [P] [US4] Extend `test/unit/khatma_repository_test.dart`: change plan keeps every read wird, keeps the part of the current wird before the place as a read wird when the place is past its first page, numbers the new wirds on from the last kept one, and sets `planned_finish` to the new expected finish; pause sets `state = paused` and `paused_on`; resume moves `planned_finish` later by the days paused and clears `paused_on`; end deletes the row and its wirds and leaves bookmarks and `reading_state` unchanged
- [X] T054 [P] [US4] Extend `test/widget/khatma_screen_test.dart`: on day 6 of a 30-day khatma with 3 wirds read, none today, it shows "3 of 30", pages read and left, the percentage, and an expected finish 2 days after the planned date; two wirds read today move the expected finish one day earlier; paused shows "Paused since {date}" and Resume; End asks for a confirmation and then shows no khatma; Change plan opens the sheet with "from page {p}" and no start fields
- [X] T055 [P] [US4] Write `test/widget/wird_list_screen_test.dart`: a page-a-day khatma builds its list lazily (only visible rows are built); each row shows number, name, range, pages and the read date or "not read"; the current wird is marked; tapping a row jumps to its first page and does not move the place

### Implementation for User Story 4

- [X] T056 [US4] Add `changePlan(plan)`, `pause()`, `resume()` and `end()` to `lib/features/khatma/khatma_repository.dart`, each one transaction as data-model.md › State changes, and expose them with the derived values in `lib/features/khatma/khatma_controller.dart` (each followed by a reminder `sync()`). Make T053 pass
- [X] T057 [US4] Add the change-plan mode to `lib/features/khatma/plan_sheet.dart`: no Start from / Start on fields, the line "from page {p}", the same choices as FR-002 applied from the place to the end, and the new number of days and finish date shown before Confirm
- [X] T058 [US4] Add the progress and actions sections to `lib/features/khatma/khatma_screen.dart`: wirds read of the total, pages read and left, the percentage, the start date, the planned finish, the expected finish when it differs ("Expected finish {date}, {n} days after the planned date" with Change plan), "Paused since {date}" with Resume; actions All wirds, Change plan, Pause or Resume, End khatma (confirmation). Neutral wording only (FR-029). Make T054 pass
- [X] T059 [P] [US4] Build `lib/features/khatma/wird_list_screen.dart` with `ListView.builder` (604 rows must scroll at 60 fps): number, name, range (surah and ayah), pages, read date or "not read", the current wird marked; a tap pops to the reader and calls `jumpToPage(firstPage)` without moving the khatma place (FR-033). Make T055 pass

**Checkpoint**: Stories 1 to 4 work: quickstart A6 passes.

---

## Phase 7: User Story 8 - Finish a personal khatma and keep a record (Priority: P3)

**Goal**: A completion screen, a record of finished khatmas, and starting the next one with the
same plan.

**Independent Test**: Start a one-day khatma, mark its only wird as read, check the completion
screen and the record, start a new khatma from it, and restart the app (quickstart A7).

### Tests for User Story 8 ⚠️

- [X] T060 [P] [US8] Extend `test/unit/khatma_repository_test.dart`: finishing sets `state = finished`, `finished_on` = today, keeps `wird_count` and deletes the wird rows; Undo after finishing restores the khatma and its wirds; deleting a record entry deletes only that row; finished rows survive a reopen of the database
- [X] T061 [P] [US8] Write `test/widget/khatma_complete_screen_test.dart`: marking the last wird of a one-day khatma shows "The khatma is complete" with start date, end date and "1 day"; Undo brings the khatma back; the record lists entries newest first with "{n} khatmas finished"; "Start a new khatma" opens the plan sheet with the previous plan selected and leaves the reminder setting unchanged; deleting an entry asks for a confirmation and lowers the count

### Implementation for User Story 8

- [X] T062 [US8] Add `finish()` (inside `markRead` when no wird is left, in the same transaction) and `deleteRecord(id)` to `lib/features/khatma/khatma_repository.dart`, keep the deleted wird rows in the controller's Undo copy so Undo can restore them, and expose the record (finished khatmas newest first) from `lib/features/khatma/khatma_controller.dart`
- [X] T063 [P] [US8] Build `lib/features/khatma/khatma_complete_screen.dart`: "The khatma is complete", start date, end date, number of days, Start a new khatma (plan sheet with the previous plan), Undo, Close; push it from `lib/features/reader/reader_screen.dart` and `lib/features/khatma/khatma_screen.dart` after the last wird is marked
- [X] T064 [US8] Add the record section to `lib/features/khatma/khatma_screen.dart`: "{n} khatmas finished", entries newest first (plan, start date to end date, days), delete with a confirmation, "Start a new khatma" with the last plan selected (FR-034 to FR-037). Make T061 pass

**Checkpoint**: Release A is complete: every personal story works on its own.

---

## Phase 8: Polish and Release A Checks

**Purpose**: The checks the constitution asks for before release A ships.

- [X] T065 Run `flutter analyze`, `flutter test --exclude-tags golden,web`, `flutter test --tags golden` and `cd android; ./gradlew :app:testDebugUnitTest`, fix every failure, and note the result in `specs/014-khatma-management/checklists/release-a.md`
- [ ] T066 [P] Profile on the Galaxy A15 and the iPhone SE 2nd gen (quickstart A9 steps 1 to 3): cold start with a khatma in progress at or under 2 s in five runs each; page turns across page 62 with the mark show no frame over 16 ms beyond those of an unmarked page; "All wirds" of a page-a-day khatma scrolls at 60 fps. Record the figures in `specs/014-khatma-management/checklists/release-a.md`
- [ ] T067 [P] Run `dart run tool/size_check.dart` on both platforms and record a growth under 1 MB (SC-009) in `specs/014-khatma-management/checklists/release-a.md`
- [ ] T068 [P] Check the toolbar on an iPhone SE (1st gen) simulator and a 320 dp Android emulator (quickstart A9 step 4), and watch the network through A1 to A7 to confirm the feature makes no request (SC-012); record both in `specs/014-khatma-management/checklists/release-a.md`
- [X] T069 Add release A lines to the release checklist in `docs/release.md` (prayer alerts now 52 pending; check the reminder on both phones; the quickstart A1 to A9)
- [ ] T070 Run quickstart A1 to A9 on one iPhone and one Android phone, in both languages, with VoiceOver and TalkBack, and in a supported browser at phone width (A8), and record the results in `specs/014-khatma-management/checklists/release-a.md`

**Checkpoint**: Release A can ship.

---

## Phase 9: Release B Foundation (Blocking Prerequisites for Stories 5 to 7)

**Purpose**: The server tables, the API skeleton, the key, the code reader, the client and the
device tables that every group story uses.

**⚠️ CRITICAL**: No group story can begin until this phase is complete. Release A must be
merged first (US5 reuses the tracker, the end mark and the Done row).

- [X] T071 Write `functions/_lib/khatma-schema.sql` with the five tables of data-model.md › 4: `khatmas` (`code` TEXT key "16 characters, Crockford base32, random", `title` "1 to 60 characters", `division` "30 or 60", `finish_date` TEXT null, `organiser`, `version`, `created_at`, `changed_at`, `completed_at` null; indexes on `changed_at`, `created_at`, `organiser`), `participants` (`id` "12 random characters", `code`, `name` "1 to 30 characters … Empty once removed", `key_hash` null for a typed name, `removed`, `joined_at`; unique on `code` + `key_hash`), `parts` (`code`, `number` as the key, `holder` null, `read_at` null), `reports` (`id`, `code`, `participant` null, `title`, `name`, `poster` null, `reporter`, `created_at`, `notified_at` null, `resolved_at` null, `action` null) and `blocks` (`key_hash` key, `blocked_at`, `report` null)
- [X] T072 [P] Add the `KHATMA_DB` D1 binding for `mthani-khatma` and the preview override for `mthani-khatma-preview` to `wrangler.toml`. Both databases were created on 2026-11-15 (region WEUR): `mthani-khatma` id `66f17814-8791-4a0b-956a-a44aaa74a3a6`, `mthani-khatma-preview` id `b4030786-7453-4876-a656-802e3e3371bb`. Once T071 exists, apply the schema to both with `npx wrangler@4 d1 execute <name> --remote --file functions/_lib/khatma-schema.sql` (Node needs `--use-system-ca` on this machine)
- [X] T073 [P] Create `tool/khatma/support.mjs`, a D1 stand-in over `node:sqlite` loaded with `functions/_lib/khatma-schema.sql`, plus helpers to build requests with a key, in the style of `tool/mutashabihat/support.mjs`
- [X] T074 Create `functions/_lib/khatma-store.js`: the queries on the five tables, the snapshot builder (the `Snapshot` shape of `contracts/group-api.md`, `participants` listing the organiser and everyone holding or having read a part, never a removed one), version bump and `changed_at` on every write, the "gone" rule (30 days after `completed_at`, 90 days after `changed_at`), and the conditional take (one statement that sets `holder` only where `holder` is null and `read_at` is null)
- [X] T075 Create `functions/_lib/khatma-api.js` with `dispatch()` and the "Every request" rules of `contracts/group-api.md`: JSON with `Cache-Control: private, no-store`; `X-Mathani-Key` of 43 base64url characters on every write, else `401 {"error":"key"}`, hashed with SHA-256 through Web Crypto and never stored raw; writes need `Content-Type: application/json`, a body under 2 KB, and an `Origin` equal to the request's own when present, else `403 {"error":"origin"}`; codes of 16 Crockford base32 characters; `404 {"error":"gone"}`; `403 {"error":"organiser"}`; `422 {"error":"terms","current":n}`. Create the entry point `functions/api/khatma/[[path]].js` and add `/api/khatma/*` to `web/_routes.json`
- [X] T076 [P] Write `tool/khatma/requests.test.mjs`: a write without a key, with a malformed key, with a foreign `Origin`, with a body over 2 KB, or with a malformed code is refused with the listed answer
- [X] T077 [P] Add `flutter_secure_storage: 11.2.0` (exact) to `pubspec.yaml` and run `flutter pub get`
- [X] T078 Create `lib/platform/key_store.dart` (interface and conditional import: `read()`, `create()`, `delete()`), `lib/platform/key_store_io.dart` (32 random bytes from `Random.secure()`, base64url without padding, in `flutter_secure_storage`; iPhone accessibility "after first unlock, this device only"; on the first launch with no `group.installed` preference, delete any key left by an earlier install, then write the marker) and `lib/platform/key_store_web.dart` (the key in the `group.key` preference). `create()` is called only by the first start, take or report (FR-065)
- [X] T079 Raise `_schemaVersion` to 3 in `lib/data/user_repository.dart` with a forward-only migration adding `group_khatmas` (`code` TEXT key "16 characters", `snapshot` TEXT JSON, `version` INTEGER, `seen_at` INTEGER, `hidden` TEXT JSON) and `group_parts` (`code`, `number` as the key, `place_page` INTEGER, `pending` INTEGER "1 while a read mark waits to be sent"); skip `group.name`, `group.terms`, `group.installed` and `group.key` in `loadStartup`; extend `test/unit/khatma_repository_test.dart` with the migration from schema 2
- [X] T080 [P] Implement `GroupCode` in `lib/features/khatma/group/group_code.dart` (plain Dart): `parse(text)` takes a code or a whole `https://get.mthani.app/k/<code>` link, ignores case, spaces and hyphens, maps Crockford look-alikes, and returns null for anything else; `format(code)` gives `XXXX-XXXX-XXXX-XXXX`; `linkOf(code)`. Write `test/unit/group_code_test.dart`
- [X] T081 [P] Create `lib/features/khatma/group/group_models.dart`: `Snapshot`, `GroupPart` (`n`, state free/taken/read, `holder`, `readAt`), `Participant` (`id`, `name`, `typed`), `You` (`id`, role organiser/participant/viewer), `Problem` (field and kind as in `contracts/group-api.md`), and a part's ayah range from juz *n* or hizb *n* in the app's own divisions (research R22)
- [X] T082 Create `GroupClient` in `lib/features/khatma/group/group_client.dart`: one method per endpoint of `contracts/group-api.md`, base address from `lib/platform/api_base.dart`, the key on writes and on reads once a key exists, `If-None-Match: "v{version}"` on reads, typed failures for `304`, `401`, `403` (blocked, organiser, removed, origin), `404 gone`, `409` (taken, notYours, read, complete, organiser, each with its snapshot when sent), `422` (invalid with `Problem`, terms with `current`), `429` with `which`, and no connection. It takes the HTTP client as a parameter. Write `test/unit/group_client_test.dart` with a fake client (snapshot, `304`, `409 taken`)
- [X] T083 Create `GroupRepository` in `lib/features/khatma/group/group_repository.dart` over the two device tables (kept khatmas with snapshot, version, `seen_at` and hidden ids; held parts with place and `pending`) and the `group.*` preferences, and `GroupController` (`ChangeNotifier`, app-scoped, idle until the reader keeps a group khatma or opens a link) in `lib/features/khatma/group/group_controller.dart`, provided next to `KhatmaScope` in `lib/app/app.dart`
- [X] T084 [P] Add every release B string in English and Arabic to `lib/app/l10n/app_en.arb` and `lib/app/l10n/app_ar.arb` from the Wording and "User-visible states" tables of `contracts/group-ui.md`, the terms text (four points), the limit messages, and the part sentence for screen readers ("Juz 7, Al-Ma'idah 82 to Al-An'am 110, taken by Maryam"); add a group icon to `lib/shared/mathani_icons.dart`; run `flutter gen-l10n`

**Checkpoint**: The API answers its common errors, and the app can read codes, call the API and
keep group khatmas.

---

## Phase 10: User Story 5 - Read the Quran together through a link (Priority: P2)

**Goal**: Start a group khatma, share its link, open it in the app or a browser, take parts,
read them in the Mushaf, mark them, and see everyone's progress.

**Independent Test**: On one phone, start a group khatma and share the link. On a second phone
with Mathani and a third device with only a browser, open the link, give names and take parts.
Take the same part on two devices at once. Mark parts, one offline. All three show the same
state, and the khatma completes with the last part (quickstart B1 to B4, B7).

**Note**: Story 6 must ship in the same release as this story.

### Tests for User Story 5 ⚠️

- [X] T085 [P] [US5] Write `tool/khatma/api.test.mjs`: `POST /api/khatma` (201, 30 or 60 free parts, organiser role, `422` on a bad division or finish date); `GET` with and without the key (`you`), `ETag: "v{version}"`, `304` with no body on the current ETag; `take` (name needed the first time, `409 taken` with the snapshot, `409 complete`); `release` (holder or organiser, `409 notYours`, `409 read`); `read` (`{read: true|false}`, `completedAt` set when no part is unread, `409 complete` for a holder undoing a mark in a complete khatma); `leave` (`204`, name gone, unread parts free, read parts kept with no holder, `409 organiser`); two `take` calls on one part run together 50 times give one `Snapshot`, one `409 taken` and one holder each time (SC-015)
- [X] T086 [P] [US5] Write `test/unit/group_waiting_marks_test.dart`: Done offline marks the part read on the device with `pending = 1`; it is sent on resume, when a khatma screen opens, after any successful call and every 60 s in the foreground; a `409 notYours` drops it and reports "This part is no longer yours"; sending twice is harmless
- [X] T087 [P] [US5] Write `test/widget/group_screen_test.dart`: the header (title, finish date or "passed", "{free} free · {taken} taken · {read} read", progress bar, "Complete on {date}"); My parts first with Read / Continue, Done, Give back and "waiting to be sent"; All parts with Take, names and "you"; the name prompt with its warning before the first take; "Last updated {time}. It may be out of date" offline; "just taken" after a `409 taken`; the Gone state; a poll every 20 s only while the screen is shown and the app is in the foreground
- [X] T088 [P] [US5] Write `test/widget/group_link_test.dart`: a link from `takeLink()` or the `links` stream after the first frame closes open sheets and pushes the Khatma screen and the group khatma; during a memorization session it waits until the session ends; pasting a link or a code with or without hyphens in "Open a link or code" opens the same khatma

### Implementation for User Story 5

- [X] T089 [US5] Implement in `functions/_lib/khatma-api.js` and `functions/_lib/khatma-store.js` the endpoints `POST /api/khatma`, `GET /api/khatma/{code}` (with `ETag` and `304`), `POST …/parts/{n}/take`, `…/release`, `…/read` (holder path; the organiser path is completed in US7) and `…/leave`, each returning the snapshot (or `204`) with the errors of the endpoints table. Use 80 random bits for the code and 12 random characters for participant ids. Make T085 pass
- [X] T090 [US5] Add to `GroupController` in `lib/features/khatma/group/group_controller.dart`: start, open (from the kept copy at once, then a read), take (with the name prompt result, saving `group.name`), give back, Done (write to the device first, then send; queue on failure), undo the mark, leave, refresh; the timers of `contracts/group-ui.md` › Refreshing and waiting marks (a read when the Khatma screen opens; every 20 s while a group khatma is on screen in the foreground and on resume; no request in the background or when neither screen is open, except to send a waiting mark; waiting marks retried every 60 s in the foreground); `keepBrowserData()` on the web when starting or joining (FR-042). Make T086 pass
- [X] T091 [US5] Feed the group parts the reader holds and has not read into `KhatmaController` as readings in `lib/features/khatma/khatma_controller.dart`: each with its own `ReadingTracker` (`marksOnPass` false, place saved in `group_parts.place_page`), its end in `endMarksOn`, its pages left, and its Done row named "Your part in «{title}» ends on this page" in `lib/features/khatma/reader_khatma_row.dart`; Done there calls `GroupController` Done (FR-052)
- [X] T092 [P] [US5] Build `lib/features/khatma/group/group_section.dart` and add it to `lib/features/khatma/khatma_screen.dart` after the reminder section: one row per kept khatma (title, "{read} of {total} read", the reader's own unread parts each with Read), "Start a group khatma", "Open a link or code" (a field taking a pasted link or code)
- [X] T093 [P] [US5] Build `lib/features/khatma/group/group_start_sheet.dart`: title (60 characters), your name (30, filled from `group.name`), division (30 ajza' or 60 ahzab), optional finish date, Start; "a connection is needed" without one; after starting, the line "Anyone who has the link can see the names and take parts", then the share sheet through `lib/platform/share.dart` with "{title}: a group khatma in Mathani. Take your part: {link}" (copy where there is no share sheet)
- [X] T094 [US5] Build `lib/features/khatma/group/group_screen.dart` per `contracts/group-ui.md` › Screens (header, My parts, All parts, Share, Refresh, Leave, offline line, Gone), with names and titles shown isolated from the surrounding direction, and each part row read as one sentence by screen readers. Make T087 pass
- [X] T095 [US5] Add group parts to the reminder in `lib/features/khatma/khatma_reminders.dart`: a day is also due when the last snapshot shows an unread part the reader holds; each part is a line "Your part in «{title}»: Juz 7"; `sync()` runs after every change to the held parts; a tap naming one part opens its place, more opens the Khatma screen
- [X] T096 [P] [US5] Create `lib/platform/app_links.dart` (interface and conditional import: `takeLink()` and a `links` stream), `lib/platform/app_links_io.dart` (the `takeLink` method and the `link` event on the existing `MethodChannel('app.mathani/device')` used in `lib/platform/device_io.dart`) and `lib/platform/app_links_web.dart` (after the first frame, read `/k/<code>` from the page's address once, then set the address back to `/`)
- [X] T097 [US5] Build `lib/features/khatma/group/group_link_host.dart` and mount it in `lib/app/app.dart`: after the first frame and on each link, close any open sheet and push `KhatmaScreen` and the group khatma; during a memorization session, wait until it ends. Make T088 pass
- [X] T098 [P] [US5] Android: in `android/app/src/main/AndroidManifest.xml`, add a verified (`android:autoVerify="true"`) intent filter for `https` `get.mthani.app` with path prefix `/k/`, and set the `flutter_deeplinking_enabled` meta-data to `false`; in `android/app/src/main/kotlin/app/mathani/mathani/MainActivity.kt`, read the link from the launch intent and from `onNewIntent`, answer `takeLink` once, and send a `link` event on the device channel
- [X] T099 [P] [US5] iOS: create `ios/Runner/Runner.entitlements` with `com.apple.developer.associated-domains` = `applinks:get.mthani.app` and reference it from the Runner target's `CODE_SIGN_ENTITLEMENTS` in `ios/Runner.xcodeproj/project.pbxproj`; set `FlutterDeepLinkingEnabled` to `false` in `ios/Runner/Info.plist`; in `ios/Runner/SceneDelegate.swift`, read the link when the scene connects (`connectionOptions.userActivities`) and in `scene(_:continue:)`; in `ios/Runner/AppDelegate.swift`, answer `takeLink` once and send the `link` event on the device channel
- [X] T100 [P] [US5] Web: add `web/.well-known/apple-app-site-association` (app id `YJBH85NYZU.com.mthani.app`, paths `/k/*`) and `web/.well-known/assetlinks.json` (package `com.mthani.app`, SHA-256 fingerprints left as placeholders for the owner); in `web/_headers`, serve both as `application/json` and give `/k/*` `Cache-Control: no-cache`

**Checkpoint**: Story 5 works on a preview deployment through "Open a link or code"; links open
the apps after the production deploy and the owner's link settings.

---

## Phase 11: User Story 6 - Keep a group khatma safe and in order (Priority: P2)

**Goal**: Terms first, a filter on names and titles, reporting, the organiser's tools, the
owner's page, blocks, limits, a lifetime for every khatma, and the store and privacy updates.

**Independent Test**: Join on a new device and see the terms first. Try an offensive name and a
name with a link. Report a name and check the owner's email. As organiser, free a part, remove a
participant and delete the khatma. Remove a khatma as the owner and see its organiser blocked
(quickstart B5).

### Tests for User Story 6 ⚠️

- [X] T101 [P] [US6] Write `tool/khatma/text.test.mjs`: the five checks of `contracts/group-api.md` › Checks on names and titles in order; at least 50 refused names and 50 refused titles in each of Arabic and English (listed words with Arabic marks, tatweel and letter-form variants, mixed Latin case, links, `@`, `www.`, direction overrides, line breaks, 31-character names and 61-character titles); a list of ordinary names in both languages that pass; the stored text is the trimmed text as typed (SC-021)
- [X] T102 [P] [US6] Write `tool/khatma/safety.test.mjs`: `report` (`202`, the report row copies title and name and the poster's key hash, `429 … "reports"` at 11 in a day); organiser `release` of another's part, `participants/{id}/remove` (name emptied, unread parts free, that key refused on `take` in this khatma with `403 removed`) and `DELETE` (`204`, every row gone); non-organiser keys get `403 organiser`; a blocked key gets `403 blocked` on start, take, assign and report; limits answer `429` at 6 open organised khatmas, 21 starts by one key in a day and 2,001 starts in a day, and not before; after leave, remove and delete, no table holds the names concerned (SC-019); a khatma past its lifetime answers `404 gone`
- [X] T103 [P] [US6] Write `tool/khatma/admin.test.mjs`: `GET /api/editor/khatma/reports` lists open reports first with `exists`; `POST reports/{id}/resolve` with `none`, `name` (removes the participant; a typed name's part becomes free) and `khatma` (deletes it), each with and without `block` (the poster's key hash goes into `blocks`); a caller other than `OWNER_EMAIL` is refused as the editor endpoints refuse it
- [X] T104 [P] [US6] Write `tool/khatma/worker.test.mjs`: the minute job emails each report with `notified_at` null once, with its number, title, name and the owner's page link, then sets `notified_at`, and retries a failed send the next minute; the daily job deletes khatmas past their lifetime with their parts and participants and reports closed more than 30 days ago, and nothing else
- [X] T105 [P] [US6] Write `test/widget/group_terms_test.dart`: the terms show before the first start and the first take on a device, Cancel saves nothing, "I agree" saves `group.terms`; a `422 terms` shows them again; report a name hides it on this device at once and says "Report sent"; reporting the khatma removes it from the list; organiser menus are absent for a non-organiser; the Blocked state shows the contact address; a refused name keeps the text in the field with its reason

### Implementation for User Story 6

- [X] T106 [P] [US6] Create `functions/_lib/khatma-text.js` (trim and collapse spaces; `empty`; `long` over 30 code points for a name or 60 for a title; `characters` for line breaks, control characters and direction override or isolate characters; `link` for `://`, `www.`, `@` or a dot between letters followed by two or more letters; `word` after removing Arabic marks and tatweel, unifying alef, hamza, yaa and taa marbuta forms and lower-casing Latin) and `functions/_lib/khatma-words.js` (two lists: whole words and strings matched anywhere, Arabic and English, for the owner to maintain). Apply them to `title` and `name` on create, take, assign and patch. Make T101 pass
- [X] T107 [US6] Add to `functions/_lib/khatma-api.js` and `functions/_lib/khatma-store.js`: `POST …/report` (`{participant?}`, `202`), `POST …/participants/{id}/remove`, `DELETE …/{code}`, the organiser path of `release`, blocked-key refusals on start, take, assign and report, and the limits of `contracts/group-api.md` › Limits counted from existing rows (5 open organised, 20 started per key per day, 2,000 started per day overall, 10 reports per key per day). Make T102 pass
- [X] T108 [US6] Create `functions/_lib/khatma-admin.js` with `GET reports` and `POST reports/{id}/resolve` per `contracts/group-api.md` › Owner endpoints, route `khatma …` paths to it from `functions/_lib/editor-api.js` behind the existing Access and `OWNER_EMAIL` checks, and bind `KHATMA_DB` for it. Make T103 pass
- [X] T109 [P] [US6] Build the owner's page `web/editor/khatma.html` and `web/editor/khatma.js` (plain HTML and JavaScript, phone width first, styled with `web/editor/editor.css`): the open reports first, each with title, name, date and whether the khatma still exists, and the actions dismiss, remove the name, remove the khatma, each with a "block the poster" box
- [X] T110 [P] [US6] Create the Worker `workers/khatma-ops/wrangler.toml` (name `mthani-khatma-ops`, the `mthani-khatma` D1 binding, an email sending binding, vars `OWNER_EMAIL` and `REPORT_FROM`, crons `* * * * *` and `0 3 * * *`, no route) and `workers/khatma-ops/src/index.js` (the minute job and the daily job of `contracts/group-api.md` › The Worker; when the email binding is absent and a `REPORT_WEBHOOK` variable is set, post the same text there instead). Make T104 pass
- [X] T111 [US6] Build `lib/features/khatma/group/group_terms.dart` (the four points of `contracts/group-ui.md` › Terms with a version number, "I agree" and "Cancel", the contact address) and require it in `GroupController` before the first start or take, sending the accepted version as `terms`
- [X] T112 [US6] Add to `lib/features/khatma/group/group_screen.dart` and `GroupController`: Report (a name, or the khatma; one confirmation; "Report sent"; the reported participant id added to `group_khatmas.hidden` and shown as "hidden", or the khatma removed from the list; the reader's own name never hidden), the organiser's menus (free a part; remove a participant with a confirmation; delete the khatma with a confirmation naming the title), the Gone and Blocked states, the limit messages, and the app-side length and link checks of names and titles for a quick answer. Make T105 pass
- [X] T113 [P] [US6] Show the contact address chosen by the owner in `lib/features/settings/about_section.dart` (FR-068), from one constant shared with the terms
- [X] T114 [P] [US6] Update `docs/store/privacy.md`, `docs/store/listing_en.md` and `docs/store/listing_ar.md` with the group khatma per research R23 (App Privacy and Data safety answers, age-rating answer, "No account, no ads. Nothing leaves your device unless you join a group khatma.", what is kept, why, for how long, how to remove it, the contact address), and add the owner's setup steps of quickstart Part B and the review-notes link to `docs/release.md` (FR-069)

**Checkpoint**: Stories 5 and 6 together meet the stores' rules: quickstart B5 passes.

---

## Phase 12: User Story 7 - Organise for people who do not use the link (Priority: P3)

**Goal**: The organiser gives parts to typed names, marks any part read or not read, and
changes the title and the finish date.

**Independent Test**: As organiser, give two parts to typed names, mark one read, mark a
participant's part read and then not read, change the title and the finish date, and check each
on another device (quickstart B6).

### Tests for User Story 7 ⚠️

- [X] T115 [P] [US7] Write `tool/khatma/organiser.test.mjs`: `assign` (`{name}` makes a participant with `typed: true` and null key hash, `409 taken`, `422 invalid` through the text checks, `403 blocked`); the organiser's `read` with `true` and `false` on any taken part, including clearing `completedAt` when a part of a complete khatma is marked not read; `PATCH` of `title` and `finishDate` (`422 invalid`); a typed name can be reported and removed like any other; non-organiser keys get `403 organiser`

### Implementation for User Story 7

- [X] T116 [US7] Add `POST …/parts/{n}/assign`, the organiser path of `…/read` (any taken or read part, at any time), and `PATCH …/{code}` (`{title?, finishDate?}`) to `functions/_lib/khatma-api.js` and `functions/_lib/khatma-store.js`. Make T115 pass
- [X] T117 [US7] Add to the organiser's menus in `lib/features/khatma/group/group_screen.dart`, with the calls in `GroupController`: on a free part "Give to a name" (a field with the same checks); on a taken or read part "Mark as read" or "Mark as not read" and "Free it"; on the khatma "Edit the title or the finish date"

**Checkpoint**: Release B is complete.

---

## Phase 13: Polish and Release B Checks

**Purpose**: CI, deploy checks, the owner's setup and the device checks before release B ships.

- [X] T118 [P] Add a step running `node --test tool/khatma/` to `.github/workflows/ci.yml`, next to the existing Node test steps
- [X] T119 [P] Extend `tool/web_deploy.mjs` to check, before deploying, that `functions/api/khatma/[[path]].js`, `web/.well-known/apple-app-site-association` and `web/.well-known/assetlinks.json` are present, and that `assetlinks.json` has no placeholder fingerprint
- [ ] T120 Owner steps, listed for the owner to do (research R26; quickstart Part B › Setup): (the two databases were created on 2026-11-15, see T072); deploy the Worker and enable email sending for mthani.app or set the webhook; add the rate limiting rule (path starts with `/api/khatma`, over 100 requests in 10 s from one IP, block 10 s); enable Associated Domains for `com.mthani.app` and renew the profiles; give the Play signing and upload key SHA-256 fingerprints for `web/.well-known/assetlinks.json`; choose the contact address; confirm the store answers and update the policy page. Then check both association files with `curl.exe -sI` (expect `200` and `application/json`; if not, add two small functions that serve them)
- [ ] T121 Run `flutter analyze`, `flutter test --exclude-tags golden,web`, `node --test tool/khatma/*.test.mjs` and `dart run tool/size_check.dart` on both platforms, and fix every failure
- [ ] T122 Run quickstart B1 to B8 on an iPhone, an Android phone and a phone browser against a preview deployment (`node --use-system-ca tool/web_deploy.mjs --dry-run`, apps built with `--dart-define=MATHANI_API_BASE=<preview address>`), then B2 steps 1 and 2 after the production deploy, including with a recitation playing in the background; record SC-016, SC-017 and SC-018 figures in `specs/014-khatma-management/checklists/release-b.md`

**Checkpoint**: Release B can be submitted to the stores.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependency.
- **Foundational (Phase 2)**: after Setup. Blocks every release A story.
- **US1 (Phase 3)**: after Phase 2. It is the MVP.
- **US2 (Phase 4)**: after US1 (it moves the place of the wirds US1 creates, and its snack bar
  joins US1's).
- **US3 (Phase 5)**: after US1. Independent of US2, apart from "today's reminder is withheld
  while the wird is on screen", which reads the pages on screen that US2 also uses.
- **US4 (Phase 6)**: after US1. Independent of US2 and US3; its actions call `sync()` once US3
  exists.
- **US8 (Phase 7)**: after US1.
- **Release A polish (Phase 8)**: after the release A stories chosen for the release.
- **Release B foundation (Phase 9)**: after release A is merged.
- **US5 (Phase 10)**: after Phase 9. Reuses US2's tracker, US1's end mark and Done row, and
  US3's reminder.
- **US6 (Phase 11)**: after Phase 9; its app tasks after US5's screens. Ships with US5.
- **US7 (Phase 12)**: after US5 and US6.
- **Release B polish (Phase 13)**: after US5 to US7, and after the owner steps of T120.

### Story completion order

```text
Setup → Foundational → US1 ─┬─ US2 ─┐
                            ├─ US3 ─┼─ Release A polish ─→ Release B foundation → US5 → US6 → US7 → Release B polish
                            ├─ US4 ─┤                                              (US5 + US6 ship together)
                            └─ US8 ─┘
```

### Within each story

- Tests first, and they fail before the implementation.
- Models and plain-Dart rules before the controller, the controller before the screens.
- Server store before the API, the API before the app's calls.
- Story complete before the next priority, unless several people work in parallel.

### Files that several tasks change (no [P] between them)

- `lib/features/khatma/khatma_controller.dart`: T010, T011, T022, T035, T037, T056, T062, T091
- `lib/features/khatma/khatma_screen.dart`: T024, T039, T051, T058, T064, T092
- `lib/features/reader/reader_screen.dart`: T029, T036, T063
- `lib/features/khatma/khatma_repository.dart`: T007, T037, T056, T062
- `lib/data/user_repository.dart`: T006, T079
- `functions/_lib/khatma-api.js` and `khatma-store.js`: T074, T075, T089, T106, T107, T116
- `lib/features/khatma/group/group_screen.dart`: T094, T112, T117
- `lib/app/l10n/*.arb`: T002, T003, T084
- `test/unit/khatma_repository_test.dart`: T012, T053, T060, T079

### Parallel opportunities

- Phase 1: T002, T003 and T004.
- Phase 2: T005, T008, T009 and T012 together; then T006 → T007 → T010 → T011.
- US1: all eight tests (T013 to T020) together; T023, T027 and T028 alongside T025 and T026.
- US2: T031, T032 and T033 together; T034 alongside them.
- US3: T040 to T043 together; T046, T047 and the Kotlin tasks alongside the Dart refactor T044.
- US4: T053, T054 and T055 together; T059 alongside T056 to T058.
- US8: T060 and T061 together; T063 alongside T062.
- After US1, US2, US3, US4 and US8 can be done by different people.
- Phase 9: T072, T073, T076, T077, T080, T081 and T084 together.
- US5: T085 to T088 together; the native tasks T098, T099 and T100 alongside the Dart tasks.
- US6: T101 to T105 together; T106, T109, T110, T113 and T114 alongside each other.

---

## Parallel Example: User Story 1

```text
# All tests for User Story 1 together:
Task: "T013 division rules on a synthetic index in test/unit/khatma_division_test.dart"
Task: "T014 SC-003, SC-004 and the examples on quran.db in test/unit/khatma_division_db_test.dart"
Task: "T015 dates in test/unit/khatma_dates_test.dart"
Task: "T016 Khatma screen and plan sheet in test/widget/khatma_screen_test.dart, plan_sheet_test.dart"
Task: "T017 end mark and goldens in test/widget/wird_end_mark_test.dart"
Task: "T018 toolbar, pages left, Done, Undo in test/widget/reader_khatma_controls_test.dart"
Task: "T019 tour stop in test/widget/khatma_tour_stop_test.dart"
Task: "T020 sideways screens in test/widget/sideways_screens_test.dart"

# Then, in parallel with the renderer work (T025, T026):
Task: "T023 plan sheet in lib/features/khatma/plan_sheet.dart"
Task: "T027 flowing layout mark in lib/features/reader/flowing_view.dart"
Task: "T028 Done row in lib/features/khatma/reader_khatma_row.dart"
```

## Parallel Example: User Story 5

```text
Task: "T098 Android intent filter and MainActivity link reading"
Task: "T099 iOS entitlement, SceneDelegate and AppDelegate"
Task: "T100 association files and headers in web/"
Task: "T092 group section in lib/features/khatma/group/group_section.dart"
Task: "T093 start sheet in lib/features/khatma/group/group_start_sheet.dart"
```

---

## Implementation Strategy

### MVP first (User Story 1 only)

1. Phase 1: Setup.
2. Phase 2: Foundational.
3. Phase 3: User Story 1.
4. **Stop and check**: quickstart A1 and A2 on one iPhone and one Android phone.
5. Without Story 2 the place does not follow page turns: Read always opens the wird's first page
   until Done. That is usable for a demo, not for a release.

### Release A (incremental)

1. US1 + US2 together are the smallest releasable khatma (both P1).
2. Add US3 (the reminder), then US4 (progress and changes), then US8 (completion and record).
   Each is checked alone with its quickstart part.
3. Phase 8, then ship release A. No store answer changes.

### Release B

1. Phase 9 while the owner does the setup steps of T120 (none blocks the code).
2. US5 and US6 together, tested on a preview deployment.
3. US7.
4. Phase 13, store answers updated, then submit.

### Parallel team strategy

After Phase 2 and US1: one person on US2, one on US3 (Dart and Kotlin), one on US4 and US8.
After release A: one person on the functions and the Worker (T071 to T076, T085, T089, T101 to
T110, T115, T116), one on the app (T077 to T084, T086 to T097, T111 to T113, T117), one on the
native link work and the web files (T098 to T100, T119).

---

## Notes

- [P] tasks touch different files and depend on no unfinished task.
- [Story] labels map each task to its story for traceability.
- Check each story at its checkpoint before moving on.
- `lib/features/khatma/reminder_open_host.dart` (T052) and the test files
  `khatma_controller_test.dart`, `wird_list_screen_test.dart`,
  `khatma_complete_screen_test.dart` and the `tool/khatma/*.test.mjs` names are additions to the
  plan's file list; they follow its layout.
