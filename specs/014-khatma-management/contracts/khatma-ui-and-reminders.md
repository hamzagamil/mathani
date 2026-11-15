# Contract: Khatma Screens, the Reading Screen, the Place and the Reminder

**Spec**: [../spec.md](../spec.md) Stories 1 to 4 and 8 | **Model**:
[../data-model.md](../data-model.md) | **Research**: [R3 to R12](../research.md)

Release A. The group parts of the same screens are in [group-ui.md](./group-ui.md).

## Screens

Entry: the reading toolbar's Khatma button pushes `KhatmaScreen`, one tap (FR-009). Back returns
to the reader with its page, recitation and memorization untouched.

| Screen or sheet | Contents |
| --- | --- |
| **Khatma, no khatma** | One line on what a plan does. "Start a khatma". The reminder section and the record follow, when they have something to show. |
| **Khatma, in progress** | **The wird card**: its number out of the total, its name, where it starts and ends (surah, ayah, page), its pages. Read (or Continue once begun) and Done. When a wird was read today: "Today's wird is done", the next wird, and "Read now". **Progress**: wirds read of the total, pages read and left, the percentage, the start date, the planned finish, and the expected finish when it differs. **Actions**: All wirds, Change plan, Pause or Resume, End khatma. A line says "Starts on {date}" before the start date, or "Paused since {date}". |
| **Reminder section** | A switch and the time. Status lines: notifications blocked, with Open settings; on Android without exact alarms, "may come a few minutes late", with no action. On the web: "Reminders are available in the phone apps", with the store links. |
| **Record section** | "{n} khatmas finished". Entries newest first: plan, start date to end date, days. Delete, with a confirmation. "Start a new khatma" opens the plan sheet with the last plan selected. |
| **Plan sheet** | **Daily amount**: the seven mark amounts, each with its number of days. **Seven days**. **Custom**: days, pages a day, or a finish date. **Start from**: the beginning, this page, or a juz, surah or page. **Start on**: today or a later date. A summary line: "{n} days · {a} to {b} pages a day · ends {date}". Start. For "change plan" the sheet has no start fields and says "from page {p}". |
| **All wirds** | A lazy list. Each row: number, name, range, pages, and the date read or "not read". The current wird is marked. A tap opens the wird's first page and does not move the place (FR-033). |
| **Completion** | "The khatma is complete", start date, end date, days. Start a new khatma. Undo. Close. |

Confirmations: End khatma; delete a record entry; Set khatma place here. Starting a khatma while
one is in progress is refused with one line (FR-005).

**All screens** use Arabic and English (RTL and LTR), the light and dark themes, safe areas and
text scaling, and stay usable sideways. Touch targets are at least 44 pt / 48 dp. Every control
has a semantic label. Taps give feedback within 100 ms. Numbers and dates follow the interface
language.

## The reading screen

| Part | Contract |
| --- | --- |
| **Khatma button** | In the toolbar, before the bookmark: index, search, listen, memorize, khatma, bookmark, settings. It has the tour key `TourTargets.khatma`. |
| **Toolbar fit** | When the buttons at their minimum size (44 pt iPhone, 48 dp Android) are wider than the screen, the toolbar scrolls sideways. Otherwise it is laid out as today. No button is ever smaller than its minimum. |
| **Pages left** | While the page on screen is inside a reading, the header's second line ends with "· {n} pages left". *n* is the reading's last page minus the first page on screen, plus one (FR-011). The line shrinks to fit and never wraps. |
| **End mark, Mushaf page** | `MushafPageRenderer.endMarks`: the ids of the ayah-end words where a reading ends. For each on the page: the ayah-end sign is painted in `khatmaMark`, and a small filled triangle is painted in the end-side margin, centred on that line. No word moves, and nothing is drawn over text. A change repaints without layout (FR-010). |
| **End mark, flowing layout** | The ayah-end sign takes `khatmaMark` and an underline. Its text is unchanged. |
| **End mark, screen readers** | The page's label gains "End of today's wird at ayah {n}". In the flowing layout the sign carries it. |
| **Done row** | When the last page of a reading is on screen, the bottom controls show one row above the toolbar buttons: "Today's wird ends on this page" and a Done button. In the Mushaf layout it shows with the controls. In the flowing layout it shows while that page is the one on screen. Two readings ending on the same page give two rows, each named (FR-012). |
| **After Done, or after reading on** | A message, "Today's wird is done", with Undo, for about 6 seconds (FR-016). After the last wird: the completion screen. |
| **Long press** | "Set khatma place here", while a personal khatma is in progress. A confirmation says how many wirds become read and how many unread (FR-017). |
| **During memorization** | No end mark, no Done row, no "pages left", and no khatma changes. |

Colour: `khatmaMark` is a new token, the brand terracotta, with at least 3:1 contrast against the
page in both themes. A test checks the contrast.

Unchanged: the page's geometry, the reading position, bookmarks, the recitation and memorization
bars, and how the controls show and hide.

## The place

The rules of [research R3](../research.md#r3-keeping-the-place), as the tests state them. "Pages
on screen" are one page, or the two facing pages of specs/012.

| # | Given | When | Then |
| --- | --- | --- | --- |
| P1 | The place is page 50 of a wird on pages 42 to 62, and page 50 is on screen | The reader turns to page 51 | The place is 51 |
| P2 | As P1 | The reader turns back to page 49 | The place is 49 |
| P3 | As P1 | The reader opens page 440 from the index, turns to 441, then closes the app | The place is 50 |
| P4 | As P1 | The reader opens page 42 from search and leaves | The place is 50 |
| P5 | The place is 50 and page 45 is on screen after a jump | The reader turns pages 46 to 50, then to 51 | The place is 51: it follows from page 50 on |
| P6 | As P1 | A recitation starts on page 50 and the page follows it to 51 | The place is 50 |
| P7 | The place is 62, the wird's last page, on screen | The reader turns to page 63 | The wird is read. The next wird is current, and the place is 63, or the next wird's first page when that is later |
| P8 | As P7, with two facing pages 61 and 62 on screen | The reader turns to pages 63 and 64 | As P7 |
| P9 | As P1, during a memorization session | The reader turns pages | Nothing changes |
| P10 | The reader went back before the wird's first page, turning pages | They turn forward again into the wird | The place is the page on screen |
| P11 | A group part on pages 121 to 141 (Juz 7), place 141, on screen | The reader turns to page 142 | The part is not read. Its place is 141 |

## The reminder

Rules: [research R8](../research.md#r8-the-reminder-what-is-scheduled).

| # | Given | Then |
| --- | --- | --- |
| N1 | The reminder is on at 05:30, a khatma is in progress, today is not read, and it is 04:00 | Ten reminders are pending: today and the nine days after, each at 05:30 |
| N2 | As N1, and it is 06:00 | Nine or ten are pending, the first for tomorrow |
| N3 | As N1, and the reader marks today's wird as read | Today's is gone. The others stay |
| N4 | As N3, then Undo | Today's is back |
| N5 | As N1, and the reader has a page of the current wird on screen | Today's is withheld. It returns when they leave that page or the app, if today is still not read |
| N6 | The khatma is paused, finished, ended or not started, and no group part waits | None is pending |
| N7 | The start date is in three days | The first pending reminder is on the start date |
| N8 | The reminder is on, there is no personal khatma, and the reader holds an unread group part | Ten are pending, naming the part and its khatma |
| N9 | Notifications are refused | None is pending. The setting keeps "on" and the time, and the screen says reminders are blocked |
| N10 | The time is changed | The pending ones are replaced. None fires at the old time |
| N11 | A reminder is delivered and the reader then marks the wird as read | It is removed from the notification list |

Text: the title is "Today's wird". The body names the wird ("Juz 3 · pages 42 to 62", or "Wird 12
of 29 · pages 240 to 260"). With group parts, each is a line: "Your part in «{title}»: Juz 7".
The texts are built in the interface language when the list is rebuilt.

## Dart interfaces (behavioural)

- **`divide`, `preview`**: [wird-division.md](./wird-division.md).
- **`KhatmaRepository`**: reads and writes the tables of the data model. Every state change in
  its table is one transaction. Writes are serialized.
- **`ReadingTracker`** (plain Dart): `onMove(firstPage, lastPage, byReader)` applies the rules
  above and reports "passed the end".
- **`KhatmaController`** (`ChangeNotifier`, app-scoped, created at launch, idle until
  `load()` after the first frame):
  - holds the khatma in progress, its current wird and the readings;
  - listens to `ReaderController` and to the memorization session, and feeds the trackers;
  - exposes the actions of the data model's state-change table, and Undo;
  - answers the reading screen: `endMarksOn(page)`, `pagesLeft(pagesOnScreen)`,
    `readingsEndingOn(pagesOnScreen)`;
  - tells `KhatmaReminders` after every change.
- **`KhatmaReminders`** (app-scoped, lazy): `sync()` builds the ten reminders and calls
  `KhatmaReminderPlatform.replace`. It runs after the first frame on start, on resume, and after
  changes. Calls made while one runs are merged.
- **`KhatmaReminderPlatform`** (conditional import: `_io` / `_web`):
  - `status()` returns the notification permission without prompting;
  - `requestPermission()` is called only when the reader turns the reminder on (FR-020);
  - `openSettings()`;
  - `replace(List<Reminder>)` cancels the feature's own pending reminders that are not in the
    list and schedules the rest;
  - `clearDelivered(ids)`;
  - `opened` (a stream of taps) and `takeLaunchOpen()`.
- **`ReaderController`**: one new field, `spreadOnScreen`, set by `MushafView`.

## Native contract

### Method channel `app.mathani/prayer_notifications` (Android), additions

| Call | Arguments | Returns |
| --- | --- | --- |
| `replaceReminders` | `{generation, alerts: [Alert], channelName}` | `{pending: int}` |
| `cancelReminders` | none | none |
| `clearReminders` | `{ids: [int]}` | none |

A tap emits the existing `opened {kind, alertId}` event with `kind = "wird"`. One Dart owner of
the channel hands prayer kinds to `PrayerAlerts` and `wird` to `KhatmaReminders`.

### Android

- **`PrayerAlarmStore`**: takes the name of its preferences file. The reminders use a second
  file, `mathani_khatma_reminders`. `PrayerAlert.kind` also accepts `wird`.
- **`PrayerNotificationsPlugin`**: the three calls above. The channel `khatma_reminder_v1`, with
  the phone's default sound and default importance. Reminder alarms use their own action and
  data address, so their ids never meet prayer ids.
- **`PrayerAlarmReceiver`**: posts a due reminder on that channel. It is dropped only when more
  than 3 hours late. A tap opens `MainActivity` with `kind = "wird"`. After a restart, a clock
  change or an update it sets the alarms of both files again.
- **Manifest**: no new permission.
- **Backup**: the new preferences file is covered by the existing rule that keeps shared
  preferences out of backups.

### iOS

- `flutter_local_notifications`, as for prayer alerts. One shared initialisation; taps are
  handed to their owner by the payload's prefix: `mathani.prayer.v2` or `mathani.khatma.v1`.
- Scheduling: `zonedSchedule` at absolute times, at most 10 pending, the default sound, thread
  `mathani.khatma`.
- Prayer alerts: at most 52 pending, down from 60.

### Web

No reminders. `status()` returns `unsupported`, and the Reminder section shows its one line.

## Behaviour by platform

| Situation | Android | iPhone | Web |
| --- | --- | --- | --- |
| Reminder due, app closed or phone locked | Notification with the default sound | The same | None |
| Reminder due, app open on another page | Notification | Banner | None |
| Reminder due, the pages it names on screen | Withheld | Withheld | None |
| Phone restarted | Alarms set again by the receiver | Kept by the system | None |
| App not opened for more than 10 days | Reminders stop until it is opened | The same | None |
| Exact alarms not allowed | May come a few minutes late; one line says so | Not applicable | None |

## User-visible states

Each state has one line of text and at most one action.

| State | Action |
| --- | --- |
| No khatma | Start a khatma |
| Starts on {date} | none |
| Today's wird is done | Read now (the next wird) |
| Paused since {date} | Resume |
| Expected finish {date}, {n} days after the planned date | Change plan |
| Notifications blocked | Open settings |
| A khatma is already in progress | none |
| The khatma is complete | Start a new khatma |

## Wording (proposed; the owner sets the final text)

| Key | Arabic | English |
| --- | --- | --- |
| Screen title | الختمة | Khatma |
| The daily portion | ورد اليوم | Today's wird |
| Open the wird | اقرأ / تابع | Read / Continue |
| Mark as read | أتممت الورد | Done |
| Undo | تراجع | Undo |
| Pages left | بقي {n} صفحة | {n} pages left |
| End of wird, on the page | نهاية ورد اليوم عند الآية {n} | End of today's wird at ayah {n} |
| Long-press item | اجعل موضع الختمة هنا | Set khatma place here |
| Start | ابدأ ختمة | Start a khatma |
| Change plan | غيّر الخطة | Change plan |
| Pause, resume | أوقف مؤقتا / استأنف | Pause / Resume |
| End | أنهِ الختمة | End khatma |
| Reminder | التذكير اليومي | Daily reminder |
| Record | الختمات السابقة | Finished khatmas |
