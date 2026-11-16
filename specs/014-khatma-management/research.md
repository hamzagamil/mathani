# Research: Personal and Group Khatma

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-11-15

The spec has no open questions (Clarifications, 2026-11-15). This file records the design
choices. R1 to R13 cover the personal khatma (release A). R14 to R25 cover the group khatma
(release B). R26 is the order of work.

Facts marked *checked* were read in this repository, in the installed Flutter SDK, or on the
vendor's own documentation on 2026-11-15. Facts marked *to confirm* could not be checked and have
a step in [quickstart.md](./quickstart.md).

---

## R1. Where the personal khatma is kept

**Decision**: `user.db` goes from schema 1 to schema 2 with two tables, `khatmas` and
`khatma_wirds` ([data-model.md](./data-model.md)).

- Wirds are stored as rows: first ayah, last ayah, and the day the wird was read. They are not
  worked out again from the plan each time.
- A finished khatma keeps its `khatmas` row, which is the record entry, and drops its wird rows.
- The reminder setting is one JSON value in `preferences` under `khatma.reminder`. It is read
  when the feature loads, like `prayer.state`, and the startup query skips it.

**Rationale**:
- A khatma has at most 604 wirds. Stored rows make "change the plan for what is left" a delete
  and insert of the unread rows, and they keep each wird's read date.
- A later change to the division rules can never alter a khatma that is in progress.
- `user.db` already works on iOS, Android and the web. Its migrations are forward only and never
  delete bookmarks.

**Alternatives considered**:
- *One JSON value in `preferences`*, as prayer times use: up to 604 wirds with dates would be
  rewritten on every mark.
- *Storing only the plan and deriving the wirds*: a plan changed in the middle needs a list of
  segments anyway, which is the same data with more rules.

## R2. Dividing the Quran into wirds

**Decision**: one pure function, `divide`, in `lib/features/khatma/khatma_division.dart`, with no
Flutter imports. Its rules are in [contracts/wird-division.md](./contracts/wird-division.md).

- **By marks**: the boundaries are every *q*-th of the 240 quarter starts already in
  `divisions`, with *q* = 1, 2, 4, 8, 16, 24 or 80 (a quarter hizb up to ten ajza').
- **Seven days**: the boundaries are the first ayat of surahs 5, 10, 17, 26, 37 and 50.
- **Custom**: whole pages, spread evenly. "Pages a day" and "finish date" are turned into a
  number of days first.
- It works on the ayah index that `QuranRepository` loads at startup (6,236 ayat with their
  pages). It makes no query.

**Rationale**:
- Readers expect "a juz a day" to follow the juz marks, not 20 equal pages. In this Mushaf, Juz
  4, 7, 11 and 26 start in the middle of a page (*checked* in `quran.db`).
- Even division keeps FR-003 and SC-004: sizes differ by at most one page. So "50 pages a day"
  from the beginning gives 13 days of 46 or 47 pages, not 12 days of 50 and one of 4. The plan
  sheet shows the real amount before the reader confirms (FR-002).
- Pure Dart makes SC-003 a unit test over every plan and every start page.

**Data facts** (*checked* in `quran.db`, counting every page a wird touches): a juz is 20 to 23
pages, a quarter 2 to 5, the seven-day wirds 72 to 106. No ayah continues onto the next page,
and an ayah starts on every page, so a wird of whole pages always ends at the end of an ayah.

**Alternatives considered**: equal pages for every plan (not what readers follow). Hizb marks
only (no way to express 29 days).

## R3. Keeping the place

**Decision**: a small pure class, `ReadingTracker`, one for each thing the reader is reading: the
current wird, and each group part they hold. It is driven by `ReaderController`.

How it tells the reader's own move from a jump (*checked* in `lib/shared/reader_state.dart` and
`lib/features/reader/mushaf_view.dart`):
- `jumpTo` and `jumpToPage` raise `jumpSerial` in the same call that changes the page. The
  index, search, bookmarks, go-to, the similar-ayah sheet, recitation following and memorization
  all use them.
- A swipe or a scroll changes the page through `onMushafPageShown`, `onMushafSpreadShown` or
  `onFlowingTopAyah`, and leaves `jumpSerial` alone.
- So on each notification: `jumpSerial` changed means a jump; otherwise a changed page is the
  reader's own move.
- One new field, `ReaderController.spreadOnScreen`, set by `MushafView`, says whether two pages
  show. The pages on screen are then the odd page and the next one.

The rules:

| Event | Result |
| --- | --- |
| A jump | *Following* becomes true if the pages on screen include the place, else false. The place does not move. |
| The reader's move while following | The place becomes the first page on screen, kept inside the reading's pages. Past its last page: R4. |
| The reader's move while not following | *Following* becomes true if the pages on screen include the place. The place does not move. |
| Any move during a memorization session | Ignored. |

**Rationale**:
- It reads as one sentence: the place moves with you while you turn pages from it, and stays
  behind when you go somewhere else.
- It keeps the place in the case the spec names (Story 2, scenario 2): opening Ayat al-Kursi
  from search while the wird that holds it is in progress.
- Taking the first of two facing pages means the place is never ahead of what was on screen.

**Alternatives considered**:
- *The last page of the wird that was on screen*: opening any page of the wird for another
  reason moves the place, and the reader may not remember where they were.
- *The furthest page reached*: looking ahead moves the place for good.
- *A minimum time on a page*: more rules, and it still cannot tell reading from looking.

## R4. Marking a wird as read

**Decision**: a wird becomes read in three ways, all through one repository transaction.

1. **Done**, on the reading screen at the wird's end, or on the Khatma screen at any time.
2. **Reading on**: the reader's own move, while following, to pages past the wird's last page.
   The next wird becomes current and its place is the page now on screen. A very short wird
   that is passed whole is marked too.
3. **Set khatma place here** on an ayah: the wird that holds the ayah becomes current, earlier
   wirds become read (today's date for those newly marked), later ones unread.

After 1 and 2 a message offers Undo for about 6 seconds, and the completion screen offers it too
(FR-016). Undo puts back the wird, the place and the state as they were.

Group parts use way 1 only (FR-052).

**Rationale**: the reader who stops at the end taps once. The reader who reads on is not asked.
The reader the app got wrong has one tool that fixes any case.

## R5. The mark at the end of a wird

**Decision**: `MushafPageRenderer` gains `endMarks`, the ids of the ayah-end words where one of
the reader's readings ends, and a palette colour, `khatmaMark`.

- **Mushaf page**: the ayah-end sign is painted in `khatmaMark` through the tint layer that
  memorization already uses, and a small filled triangle is painted in the end-side margin on
  that line. A change of `endMarks` repaints only. Nothing is laid out again.
- **Flowing layout**: the ayah-end sign takes the colour and an underline. The text is the same
  string, so no position moves.
- **Screen readers**: the page's label gains "End of today's wird at ayah N". The flowing sign
  carries the same label.
- **Memorization**: no end mark while a session is on.

**Rationale** (*checked* in `mushaf_page_renderer.dart`): the hizb and sajdah marks sit in the
start-side margin. The end-side margin is empty on every page. A shape beside the line serves
readers who do not see the colour, and the coloured sign gives the exact ayah when a wird ends
in the middle of a line.

**Alternatives considered**: a line across the text (covers it). A label in the text (moves it,
and the page would no longer match the print). A banner at the bottom (covers the last lines on
short phones).

## R6. Controls on the reading screen

**Decision**:
- **Khatma button**: a seventh button in the reading toolbar, before the bookmark.
- **Fit**: the theme already sets buttons to 44 pt on iPhone and 48 dp on Android (*checked* in
  `app_theme.dart`). Seven are 308 pt, which fits the narrowest iPhone that iOS 15 runs on
  (320 pt). On Android they are 336 dp, so on a screen narrower than that the toolbar scrolls
  sideways and keeps 48 dp targets.
- **Pages left**: the header's second line gains "N pages left" while the page on screen is
  inside a reading (FR-011).
- **Done**: when the last page of a reading is on screen, the bottom controls show one row above
  the toolbar: what ends here, and a Done button (FR-012).
- **Undo**: a snack bar, the app's existing pattern.
- **Set khatma place here**: one more item in the long-press sheet, with a confirmation that
  says how many wirds will change (FR-017).

**Rationale**: the row lives in the controls, so it never covers text while the reader reads,
and it needs no change to the page's size.

**Alternatives considered**:
- *A bar docked under the page on the end page only*: the page would change size between two
  neighbouring pages. A size change makes the words be shaped again (commit `a2f970f`), which
  costs frames during a turn.
- *A button in the header*: out of one-handed reach on tall phones (constitution II).
- *A tab in the index*: three taps to the place, and hidden.

## R7. Screens

**Decision**: one pushed route, `KhatmaScreen`, with these parts in order: the personal khatma,
the reminder, group khatmas (release B), the record. Sheets and routes from it: the plan sheet
(also used for "change plan"), the list of wirds, the completion screen. Details:
[contracts/khatma-ui-and-reminders.md](./contracts/khatma-ui-and-reminders.md).

**Rationale**: one place for everything named "khatma", two taps from the reading screen
(FR-009), built from the list tiles, chips and sheets the app already has (constitution V).

## R8. The reminder: what is scheduled

**Decision**: ten one-time local notifications, one for each of the next ten days at the chosen
time. They are rebuilt whenever something they depend on changes.

- **A day is due** when a personal khatma is in progress, has started and that day has no read
  wird, or when the reader holds an unread group part (FR-021).
- **Today's is left out** when today is read, when the time has passed, or while the reader has
  the pages it would name on screen. It is put back if the reader leaves without finishing.
- **Rebuilt on**: app start (after the first frame) and resume, every change to the khatma, the
  plan, the place, the reminder setting or the group parts.
- **Text**: the wird by its name where it has one ("Juz 3"), with its pages. Group parts by part
  and title. Both when both wait.
- **When read**: a delivered reminder is removed from the notification list.
- **Tap**: one thing named opens its place; more opens the Khatma screen (FR-023).

**The iPhone limit**: an app holds 64 pending notifications. Prayer alerts take 60 today
(*checked*: `IosPrayerAlerts.max`). They drop to 52, and the khatma takes 10. 52 alerts at six
a day (five prayers and Qiyam) are 8.6 days, above the 7 days of specs/009 FR-021. The same
figures apply on Android, whose store caps one list at 64.

**Rationale**: only one-time notifications can skip a day that is already read (FR-022). Ten
days meets the 7 days of FR-021 with a margin.

**Limit accepted**: after ten days without the app being opened, reminders stop until it is
opened. After a time-zone change they keep the old zone's clock time until the app is opened.

**Alternatives considered**:
- *One repeating daily notification*: one slot, but it cannot skip today.
- *A server push*: needs a push service and the server to know each reader's khatma.

## R9. The reminder on each platform

**Decision**: a new interface, `KhatmaReminderPlatform`, with the same shape as the prayer one
(status, ask, open settings, replace the list, cancel, taps). The plumbing the two share moves
into one file, `lib/platform/local_notifications_io.dart`.

- **Android**: the existing plugin, receiver and alarm store.
  - A second store file holds the reminders, so a prayer refill and a reminder refill never
    replace each other.
  - A new alert kind, `wird`, and one channel with the phone's default sound (FR-026).
  - Alarms are exact when the reader already allowed exact alarms for prayer alerts, otherwise
    Android may deliver them a few minutes late. The reminder does not ask for that access.
  - A reminder up to 3 hours late is still shown (prayer alerts keep 15 minutes), since a late
    reminder for today's wird is still useful.
  - Restored after a restart by the existing receiver.
- **iOS**: `flutter_local_notifications`, as for prayer alerts. One shared initialisation hands
  each tap to its owner by the payload's prefix. Reminders use the default sound.
- **Web**: none. The setting is replaced by one line (FR-042).

**Rationale**: every part exists and has tests. A second store file is a few lines, against a
second receiver and boot path.

**Why the refactor**: on Android both features use one method channel, and a second handler
would replace the first. On iOS the plugin has one callback for taps (*checked* in
`prayer_notifications_io.dart`).

## R10. Startup and performance

**Decision**: nothing of the feature runs before the first frame (FR-039).

- After the first frame, `KhatmaController.load()` reads the open khatma, its current wird and
  the reminder setting, then starts the trackers and rebuilds the reminders. The end mark
  appears when this finishes, a moment after the first page.
- The division runs only when a plan is previewed or confirmed.
- The list of wirds is built lazily (604 rows, SC-008).
- Group khatmas: R17. No request is made unless the reader has one.

**Rationale**: constitution III. The same pattern as prayer alerts (specs/009 R11).

## R11. Dates

**Decision**:
- A day is the phone's calendar date, stored as `YYYY-MM-DD` text. The clock is injected for
  tests.
- **Planned finish**: start date plus the number of wirds minus one. Set when the khatma is
  made, when the plan changes, and moved by a pause.
- **Expected finish**: today plus the unread wirds, minus one when today is not read yet
  (FR-027). Before the start date: the start date plus the wirds minus one.
- **Pause**: stores the day it began. Resume adds the days paused to the planned finish.

**Rationale**: calendar-day text has no time-zone arithmetic to get wrong, and "read today" is
one comparison.

## R12. The onboarding stop

**Decision**: one new button stop, `OnboardingStep.khatma`, after the memorization stop and
before Settings, pointing at the Khatma button (FR-043, specs/005 Out of Scope: "their own specs
add tour stops when they ship"). Readers who update see nothing new by itself, as specs/005
decided.

## R13. Tests for release A

- **Unit** (`flutter_test`): the division rules and SC-003/SC-004 on the bundled database; the
  tracker's table (R3) with one page, two pages and the flowing layout; the repository,
  including the migration from schema 1 with bookmarks kept; dates; the reminder list (due
  days, ten days, texts, left out while reading, pause).
- **Widget**: the Khatma screen and plan sheet; the reading controls (button, pages left, Done,
  Undo, the toolbar at 320 wide on both platforms); the end mark, with one golden in each theme;
  the long-press item; the tour stop; the screens at 780 × 360 (specs/013's overflow test).
- **Android** (JVM): the second store, the `wird` kind and the lateness rule.
- **Devices**: [quickstart.md](./quickstart.md) A1 to A9.

---

## R14. Where the group khatma lives

**Decision**:
- **API**: Pages Functions under `/api/khatma/*` on the project that serves the web app, next
  to the prayer and Mutashabihat functions. Logic in `functions/_lib/`, tests in `tool/khatma/`.
- **Storage**: a second D1 database, `mthani-khatma`, bound as `KHATMA_DB`. Previews use
  `mthani-khatma-preview`.
- **A small Worker**, `mthani-khatma-ops`, bound to the same database, with two scheduled jobs:
  every minute it emails the owner any new report, and once a day it removes khatmas past their
  time (R21).

**Rationale**:
- The apps already call this host, and the web app is on the same origin, so its Content
  Security Policy needs no change.
- A separate database keeps reader data apart from the published content, with its own
  lifetime and its own preview copy.
- Pages Functions can bind D1, KV, R2, queues and service bindings, but not email sending, and
  scheduled jobs belong to Workers (*checked*: Cloudflare Pages "Bindings" and Workers "Cron
  Triggers" documentation). A Worker that reads the database on a schedule needs no call from
  the functions, so the API code has no email logic.

**To confirm at setup**: sending email from a Worker needs mthani.app enabled for sending in
Cloudflare's email service (a dashboard and DNS step for the owner). If it cannot be enabled,
the Worker posts the same text to a webhook of the owner's choice. The rest is unchanged.

**Alternatives considered**:
- *The whole API in a Worker on a route*: one place for every binding, but a second deploy for
  the API itself, and preview deployments of the web app would have no group API.
- *A third-party email API from the functions*: another processor sees reported names.
- *No scheduled job*: expired khatmas would stay until the next request (FR-066).

## R15. Who is who: the key

**Decision**:
- **One key per device or browser**: 32 random bytes, made the first time the reader starts,
  joins or reports. Every write sends it in the `X-Mathani-Key` header.
- **The server keeps only its SHA-256.** The hash names the organiser of a khatma and the
  participant of a part, and it is what a block names (R19).
- **On phones** the key is in the platform's secure storage through `flutter_secure_storage`
  11.2.0 (constitution: sensitive data). On iPhone it is "this device only", and it is removed
  on the first launch after a fresh install, because the Keychain outlives the app. That keeps
  the spec's promise that deleting the app loses the key.
- **In browsers** the key is a `preferences` row in the site's own database. Browsers have no
  secure storage. This is the stated exception (spec Assumptions).

**Rationale**: a key that proves "these parts are mine" is a credential. A random key needs no
salt to hash safely.

**Alternatives considered**:
- *A key per khatma*: Mathani could not block a device from the service (FR-063).
- *The key in `user.db` on phones*: against the constitution's storage rule.
- *Hand-written Keychain and Keystore code*: cryptographic code to own and test on two
  platforms, for no smaller app.

## R16. The link, the code, and opening it

**Decision**:
- **Link**: `https://get.mthani.app/k/<code>`. The code is 16 characters of Crockford base32
  (80 random bits), shown in groups of four. Reading a code ignores case, spaces and hyphens.
- **Browser**: Pages serves the app's page for `/k/…`, because the site has no `404.html`
  (*checked*: Cloudflare "Serving Pages"). The web app reads the code from its address after
  the first frame, opens the group khatma, and sets the address back to `/`.
- **Phones**: Universal Links on iOS and App Links on Android for `get.mthani.app/k/*`.
  - Two association files are served from `/.well-known/`.
  - Android gets a verified intent filter. iOS gets the Associated Domains entitlement.
  - The link reaches Dart through the existing `app.mathani/device` channel: `takeLink` at
    launch, and a `link` event while running. This is how notification taps arrive today.
  - Flutter's own link handler is switched off on both platforms.
- **Paste**: the Khatma screen takes a link or a code.

**Rationale**:
- 80 bits: a million guesses against 100,000 live khatmas succeed with a chance near 10⁻¹³
  (SC-024).
- The app has no named routes. Flutter's handler would push the link as a route name, and at
  launch it reports "Could not navigate to initial route" in debug builds (*checked* in the
  SDK: `widgets/app.dart`, `navigator.dart`). The Android activity also shares its engine with
  the audio service, and whether the handler sees a launch link then is *to confirm*. Reading
  the link natively does not depend on either.

**To confirm at setup**: that Pages serves the two files under `/.well-known/` with the right
content type. If not, two tiny functions serve them.

**Owner steps**: enable Associated Domains for the app id and renew the signing profiles; give
the SHA-256 fingerprints of the Play signing key and the upload key.

**Alternatives considered**: the `app_links` package (a dependency for what two short native
entry points do). A custom scheme such as `mathani://` (not clickable in chat apps, and no
browser fallback).

## R17. The API, live updates and taking a part

**Decision**: a small JSON API, [contracts/group-api.md](./contracts/group-api.md).

- **One snapshot** of a khatma (title, parts, names, counts) is the answer to a read and to
  every write, so the app always replaces what it shows with the server's state.
- **A version number** on each khatma rises with every change. A read sends it as
  `If-None-Match`, and an unchanged khatma answers `304` with no body after one row read.
- **Polling**: every 20 seconds while a group khatma is on screen and the app is in the
  foreground, plus once when the Khatma screen opens, when the app resumes on those screens,
  and after the reader's own actions (FR-054, SC-016).
- **Taking a part** is one conditional update: set the holder where the part has none. One
  caller changes the row, and the other gets `409` with the fresh snapshot (FR-050, SC-015).

**Rationale**: a poll is simple, works in every browser and on every phone, and 20 seconds is
inside the 30 the spec asks for. A snapshot of 60 parts is about 4 KB.

**Alternatives considered**: WebSockets or server-sent events (a Durable Object or a long-lived
connection for a list that changes a few times an hour). Sending changes only (more states to
get wrong, for 4 KB).

## R18. Without a connection

**Decision**:
- The last snapshot of each khatma is kept on the device and shown at once, with its age
  (FR-055).
- **Done on a group part** is written to the device first and shown as read. It is sent at once
  when possible. Otherwise it is retried on resume, when a khatma screen opens, after any
  successful call, and every 60 seconds while the app is in the foreground and something waits
  (FR-053, SC-017).
- A waiting mark that the server refuses, because the part was freed or given away, is dropped,
  and the reader is told.
- Every other action needs a connection and says so.

**Rationale**: reading happens in mosques and on the move. Sending a mark twice is harmless,
because it sets the same state.

## R19. Safety

**Decision**:
- **Terms**: a short text in the app, in Arabic and English, with a version number. The accepted
  version is kept on the device and sent with the calls that create content. The server refuses
  an older version (FR-059).
- **Filter**, on the server: a name or title is refused when it is empty or too long, has a
  line break, a control or direction-override character, a link or an address, or a word from
  the list. Text is compared after normalising Arabic letters and marks and Latin case. The
  list is a file deployed with the functions, so the owner changes it with a web deploy and no
  app release. The app repeats the length and link checks for a quick answer (FR-060).
- **Report**: one call. What was reported is hidden on that device at once. The report row
  keeps a copy of the title and name as they were, so the owner can judge it even if the khatma
  changes (FR-061).
- **Organiser**: free a part, remove a participant (the key cannot join that khatma again),
  delete the khatma (FR-062).
- **Owner**: a small page beside the Mutashabihat editor, behind the same Cloudflare Access
  sign-in, lists open reports with three actions: dismiss, remove the name, remove the khatma,
  each with or without blocking the key that posted it. Only `OWNER_EMAIL` may use it (FR-063).
- **Blocks**: a blocked key is refused on start, take, assign and report.
- **Contact**: one address, shown in About and in the terms (FR-068). The owner chooses it.

**Rationale**: these are the four things Apple's Guideline 1.2 lists and the items of Google
Play's User Generated Content policy (*checked* on both pages), kept to the smallest form that a
list of names needs.

**Alternatives considered**: reviewing every name before it shows (a queue for the owner on
every join). No typed title (little gained: names are typed anyway).

## R20. Limits and abuse

**Decision**:
- **Per key**: at most 5 open khatmas organised, 20 started in a day, 10 reports in a day.
- **For all**: at most 2,000 khatmas started in a day. Past it, starting one says "try later".
- **Per connection**: one Cloudflare rate limiting rule on the path `/api/khatma`, counted by
  IP over 10 seconds. The free plan has one such rule, by path and IP (*checked*). The owner
  adds it in the dashboard.
- **Sizes**: 30 or 60 parts, names of 30 characters, titles of 60, request bodies under 2 KB.
- Counts come from rows that exist for other reasons. No table of addresses is kept (FR-065).

**Rationale**: the caps bound storage and cost without keeping anything new about readers.

**Risk accepted**: someone who makes a new key for each call can use up the day's 2,000
khatmas, and nobody else can start one that day. Reading, taking and marking still work.

## R21. What the server keeps, and for how long

**Decision**: tables `khatmas`, `parts`, `participants`, `reports` and `blocks`
([data-model.md](./data-model.md)). Nothing else: no address, no device model, no log.

| When | What is removed |
| --- | --- |
| A participant leaves | Their row. Parts they read stay read with no holder. |
| The organiser removes a participant | The name. The row stays, marked removed, to refuse that key. |
| The organiser or the owner deletes a khatma | The khatma and every row under it. |
| 30 days after completion, or 90 days without a change | The same, by the daily job. The API also treats it as gone from that moment. |
| 30 days after a report is closed | The report, with its copy of the name and title. |

**Rationale**: FR-065 and FR-066. A report's copy and a block's key hash are the two things
kept beyond a khatma's life, and both are needed to act on abuse. The privacy policy says so
(R23).

## R22. Group parts in the reader and in the reminder

**Decision**: a group part the reader holds is one more reading (R3): it has its own place, its
end is in `endMarks`, the header shows its pages left, and the Done row names it. It differs
from a wird in one way: only a tap marks it. Part ranges are not stored anywhere: a part is juz
*n* or hizb *n* in the app's own `divisions`.

The reminder counts an unread held part as due, from the last snapshot on the device (FR-024).

**Rationale**: one mechanism for both (constitution V). The server does not need to know the
Mushaf.

## R23. The privacy policy and the store answers

**Decision**: `docs/store/privacy.md` gains a section for the group khatma with the proposed
answers below, for the owner to confirm, as specs/009 did. The store consoles and the published
policy page are owner actions before release B (FR-069).

| Where | Change |
| --- | --- |
| Apple App Privacy | Name; Other User Content (the title); User ID (the key's hash). Purpose: App Functionality. Not used for tracking. |
| Google Play Data safety | Name, other user-generated content, other IDs: collected, optional, for app functionality, encrypted in transit, not shared. Deletion: in the app (leave, delete) and on request. |
| Age-rating answers | The app lets users see text other users typed (names and a title), with reporting and blocking. |
| Store listings | "No account, no ads, no data collected" becomes "No account, no ads. Nothing leaves your device unless you join a group khatma." |
| Privacy policy page | What is kept, why, for how long, how to remove it, and the contact address. |
| Review notes | A group khatma link that reviewers can open, and where to find Report and the terms. |

Release A changes none of these: the personal khatma keeps everything on the device.

## R24. Cost and scale

- **Requests**: the free plan allows 100,000 function requests a day for the whole project.
  A reader in a group khatma makes about 3 polls a minute while the screen is open. 1,000 such
  readers a day at two one-minute visits and five actions each are about 11,000 requests.
  The Worker's minute job adds 1,440 invocations of its own.
- **Database**: a khatma is under 100 rows. The free plan's limits are far above this.
- **When to pay**: near 8,000 daily readers of group khatmas, or sooner if screens stay open
  for long. The paid plan is a fixed monthly price.
- **App size**: one package and about 60 KB of code. Measured by the size check.

## R25. Tests for release B

- **Functions**: `node --test tool/khatma/*.test.mjs`, in the style of `tool/mutashabihat/`,
  with D1 stood in for by `node:sqlite` and the real schema. They cover every endpoint, two
  callers taking one part, the filter in both languages, reports, the owner's actions, blocks,
  the limits and the daily job. CI runs them.
- **App** (`flutter_test`): the client with a fake HTTP client (snapshot, `304`, `409`), the
  waiting marks, the code reader, the screens and the terms.
- **Devices**: [quickstart.md](./quickstart.md) B1 to B8, on an iPhone, an Android phone and a
  phone browser, on a preview deployment with the preview database.

## R26. Order of work, and what waits for the owner

**Decision**: two releases.

- **Release A**: the personal khatma (Stories 1 to 4 and 8) and the tour stop. No server, no new
  package, no store answer changes.
- **Release B**: the group khatma (Stories 5 to 7), which adds the server, the key, the links
  and the safety pieces.

The code of release B does not wait for the owner. These steps do, before it can be tested end
to end or released:

1. Create the two databases and apply the schema.
2. Deploy the Worker; enable email sending for mthani.app, or choose a webhook.
3. Add the rate limiting rule.
4. Enable Associated Domains and renew the iOS profiles; give the Android fingerprints.
5. Choose the contact address.
6. Confirm the store answers of R23 and update the policy page.

**Rationale**: release A is useful alone and carries none of release B's risk. Each story is
testable alone (spec).
