# Data Model: Personal and Group Khatma

**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

Three places hold data: the reader's device (`user.db` and the platform's secure storage),
Mathani's server (a D1 database, release B only), and memory while the app runs.

## 1. On the device: the personal khatma (release A, `user.db` schema 2)

The migration from schema 1 only adds tables. It never touches `bookmarks`, `reading_state` or
`preferences`.

### `khatmas`

One row for each khatma: the one in progress, and each finished one (the record).

| Column | Type | Meaning |
| --- | --- | --- |
| `id` | INTEGER, key | |
| `state` | TEXT | `active`, `paused` or `finished` |
| `plan` | TEXT (JSON) | The plan, see below |
| `start_ayah` | INTEGER | Ayah id of the start point, 1 to 6236 |
| `start_date` | TEXT | `YYYY-MM-DD`, the phone's calendar date |
| `planned_finish` | TEXT | `YYYY-MM-DD` |
| `paused_on` | TEXT, null | The day a pause began |
| `place_page` | INTEGER | The khatma place: a page of the current wird, 1 to 604 |
| `wird_count` | INTEGER | Number of wirds, kept for the record |
| `finished_on` | TEXT, null | The day the last wird was read |
| `created_at` | INTEGER | Milliseconds |

Rules:
- At most one row has a state other than `finished` (FR-005). The repository checks this inside
  the transaction that starts a khatma.
- "Not started yet" is not a stored state: it is `active` with `start_date` after today.
- Ending a khatma deletes its row and its wirds (FR-032). Deleting a record entry deletes its
  row (FR-037).

### `khatma_wirds`

The wirds of the khatma in progress, in order. Removed when the khatma finishes or ends.

| Column | Type | Meaning |
| --- | --- | --- |
| `khatma_id` | INTEGER | Part of the key |
| `number` | INTEGER | 1, 2, 3, … in Mushaf order. Part of the key |
| `first_ayah` | INTEGER | Ayah id |
| `last_ayah` | INTEGER | Ayah id |
| `read_on` | TEXT, null | `YYYY-MM-DD` the wird was marked as read |

Rules (FR-003, checked by `divide` and its tests):
- `first_ayah` of wird 1 is `start_ayah`. Each next wird starts at the ayah after the one before
  it. The last wird ends at ayah 6236.
- Wirds are deleted with their khatma in the same transaction. The app does not rely on
  cascades.

### The plan (JSON in `khatmas.plan`)

| Value | Meaning |
| --- | --- |
| `{"kind":"marks","quarters":q}` | *q* quarter hizbs a day: 1, 2, 4, 8, 16, 24 or 80 |
| `{"kind":"seven"}` | Seven days by whole surahs |
| `{"kind":"days","days":n}` | A custom plan of *n* days, 1 to 604. "Pages a day" and "finish date" are turned into days before they are stored |

### The reminder setting (`preferences`, key `khatma.reminder`)

`{"on": true, "time": "05:30"}`. Missing means off. It belongs to the reader and outlives any
khatma (FR-025). The startup query skips this row.

### Values worked out, not stored

| Value | How |
| --- | --- |
| Current wird | The lowest `number` with `read_on` null (FR-007) |
| Today is read | Some wird has `read_on` equal to today (FR-018) |
| Pages in the khatma | 604 minus the start point's page, plus 1 |
| Pages read | The place's page minus the start point's page. All of them when finished |
| Expected finish | Today plus the unread wirds, minus 1 when today is not read. Before the start date: the start date plus the wirds minus 1 (FR-027) |
| A wird's name | "Juz *n*", "Hizb *n*" or a quarter's name when the wird is exactly one of them; otherwise its number |

### State changes

| Action | Change |
| --- | --- |
| Start | A row with `state = active`, the wirds from `divide`, `place_page` = the start point's page, `planned_finish` = start date + wirds − 1 |
| Mark the current wird as read | `read_on` = today. The place becomes the next wird's first page. If none is left: finish |
| Undo | The wird, the place and the state go back to what they were |
| Set khatma place here | Wirds before the one holding the ayah: read (today for those newly marked). That wird and later ones: unread. The place: the ayah's page |
| Change plan | Unread wirds are deleted. If the place is past the current wird's first page, the part before it stays as a read wird. New wirds from the place to the end follow, numbered on. `planned_finish` = the new expected finish |
| Pause | `state = paused`, `paused_on` = today |
| Resume | `state = active`, `planned_finish` moves later by the days paused, `paused_on` = null |
| Finish | `state = finished`, `finished_on` = today, `wird_count` kept, wird rows deleted |
| End | The row and its wirds are deleted |

## 2. On the device: group khatmas (release B, `user.db` schema 3)

### `group_khatmas`

One row for each group khatma the reader opened and kept.

| Column | Type | Meaning |
| --- | --- | --- |
| `code` | TEXT, key | The link's code, 16 characters |
| `snapshot` | TEXT (JSON) | The last state the server sent ([contracts/group-api.md](./contracts/group-api.md) › Snapshot), with the reader's role and participant id |
| `version` | INTEGER | The snapshot's version, sent back as `If-None-Match` |
| `seen_at` | INTEGER | When it was fetched, shown as "may be out of date" (FR-055) |
| `hidden` | TEXT (JSON) | Participant ids the reader reported, hidden on this device (FR-061) |

A row is removed when the reader leaves, reports the whole khatma, or the server says it no
longer exists and the reader has seen that message.

### `group_parts`

One row for each part the reader holds.

| Column | Type | Meaning |
| --- | --- | --- |
| `code`, `number` | key | The khatma and the part |
| `place_page` | INTEGER | The reader's place in this part |
| `pending` | INTEGER | 1 while a "read" mark waits to be sent (FR-053) |

### `preferences` rows

| Key | Value |
| --- | --- |
| `group.name` | The name last typed, offered again (FR-049) |
| `group.terms` | The terms version the reader accepted (FR-059) |
| `group.installed` | A marker written on first launch, so that a key left in the iPhone Keychain by an earlier install is removed |
| `group.key` | **Browsers only**: the key |

### The key (phones)

One item in the platform's secure storage: 32 random bytes, base64url. iPhone: readable after
first unlock, this device only. It is made the first time the reader starts, joins or reports,
never before (FR-065).

## 3. In memory

| Model | Fields | Notes |
| --- | --- | --- |
| **Reading** | what it is (the personal wird, or a group part), first and last ayah, first and last page, place, *following* | One for the current wird and one for each unread part held. Drives the tracker, the end marks, "pages left" and the Done row |
| **Reminder** | id, time, title, body, what a tap opens | Built for the next ten days ([research R8](./research.md#r8-the-reminder-what-is-scheduled)). The id is a hash of the date, so a rebuild never doubles one |
| **Wird preview** | number of wirds, daily amount in pages (least and most), finish date | Shown in the plan sheet before confirming (FR-002) |

## 4. On the server: group khatmas (release B, D1 `mthani-khatma`)

Schema file: `functions/_lib/khatma-schema.sql`.

### `khatmas`

| Column | Type | Meaning |
| --- | --- | --- |
| `code` | TEXT, key | 16 characters, Crockford base32, random |
| `title` | TEXT | 1 to 60 characters, filtered |
| `division` | INTEGER | 30 or 60 |
| `finish_date` | TEXT, null | `YYYY-MM-DD` |
| `organiser` | TEXT | Hash of the organiser's key |
| `version` | INTEGER | Rises by one with every change |
| `created_at`, `changed_at` | INTEGER | Milliseconds, the server's clock |
| `completed_at` | INTEGER, null | Set when every part is read; cleared if one is unmarked |

Indexes: `changed_at`, `created_at`, `organiser`.

### `participants`

| Column | Type | Meaning |
| --- | --- | --- |
| `id` | TEXT, key | 12 random characters. Public inside the khatma |
| `code` | TEXT | The khatma |
| `name` | TEXT | 1 to 30 characters, filtered. Empty once removed |
| `key_hash` | TEXT, null | Hash of the person's key. Null for a name the organiser typed (FR-070) |
| `removed` | INTEGER | 1: removed by the organiser or the owner. The key cannot join this khatma again (FR-062) |
| `joined_at` | INTEGER | |

Unique: one row for each key in a khatma.

### `parts`

| Column | Type | Meaning |
| --- | --- | --- |
| `code`, `number` | key | 1 to `division` |
| `holder` | TEXT, null | A participant id |
| `read_at` | INTEGER, null | The server's clock |

A part's state comes from the two columns:

| `holder` | `read_at` | State |
| --- | --- | --- |
| null | null | Free |
| set | null | Taken |
| set | set | Read |
| null | set | Read, by someone who left (no name) |

Part state changes:

| From | To | By |
| --- | --- | --- |
| Free | Taken | A participant takes it; the organiser gives it to a typed name |
| Taken | Free | The holder gives it back; the organiser frees it; the holder leaves or is removed |
| Taken | Read | The holder, or the organiser |
| Read | Taken | The holder, while the khatma is not complete; the organiser at any time |
| Read with no name | Free | The organiser marks it not read |

The khatma is complete when no part has `read_at` null (FR-056).

### `reports`

| Column | Type | Meaning |
| --- | --- | --- |
| `id` | INTEGER, key | |
| `code` | TEXT | The khatma |
| `participant` | TEXT, null | The participant reported. Null: the whole khatma |
| `title`, `name` | TEXT | Copies as they were when reported |
| `poster` | TEXT, null | Hash of the key that typed the reported text |
| `reporter` | TEXT | Hash of the reporter's key |
| `created_at` | INTEGER | |
| `notified_at` | INTEGER, null | When the owner was emailed |
| `resolved_at` | INTEGER, null | |
| `action` | TEXT, null | `none`, `name` or `khatma`, and whether the poster was blocked |

### `blocks`

| Column | Type | Meaning |
| --- | --- | --- |
| `key_hash` | TEXT, key | A key Mathani blocked (FR-063) |
| `blocked_at` | INTEGER | |
| `report` | INTEGER, null | The report that led to it |

### What is never stored

No account, email, phone number, address, device model, location or reading activity. Request
logs are not kept by the functions. A reader who never starts, joins or reports a group khatma
has no row anywhere (FR-065).

### Limits and lifetimes

| Rule | Value | Source |
| --- | --- | --- |
| Open khatmas organised by one key | 5 | FR-067 |
| Khatmas started by one key in a day | 20 | FR-067 |
| Khatmas started by everyone in a day | 2,000 | [research R20](./research.md#r20-limits-and-abuse) |
| Reports by one key in a day | 10 | FR-067 |
| Removed after completion | 30 days | FR-066 |
| Removed without a change | 90 days | FR-066 |
| Closed reports removed | 30 days after closing | [research R21](./research.md#r21-what-the-server-keeps-and-for-how-long) |

## 5. Entities of the spec and where they live

| Spec entity | Here |
| --- | --- |
| Personal khatma, Record entry | `khatmas` (device) |
| Plan | `khatmas.plan` |
| Wird | `khatma_wirds` |
| Khatma place | `khatmas.place_page`; `group_parts.place_page` |
| Reminder setting | `preferences` › `khatma.reminder` |
| Group khatma | `khatmas` (server); `group_khatmas.snapshot` (device copy) |
| Part | `parts` (server) |
| Participant, Organiser | `participants`, `khatmas.organiser` |
| Key | Secure storage (phones) or `preferences` › `group.key` (browsers); its hash on the server |
| Report | `reports` |
| Group khatma terms | Text in the app; the accepted version in `preferences` › `group.terms` |
