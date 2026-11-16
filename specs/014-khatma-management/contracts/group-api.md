# Contract: Group Khatma API

**Spec**: [../spec.md](../spec.md) Stories 5 to 7, FR-044 to FR-072 | **Model**:
[../data-model.md](../data-model.md) › 4 | **Research**: [R14 to R21](../research.md)

**Base**: `/api/khatma`. **Function**: `functions/api/khatma/[[path]].js` →
`functions/_lib/khatma-api.js` `dispatch()`. **Storage**: D1, bound as `KHATMA_DB`.

Release B.

## Every request

1. **Responses** are JSON with `Cache-Control: private, no-store`.
2. **The key**: every write must send `X-Mathani-Key`, the device's key as 43 base64url
   characters. Without it, or malformed: `401 {"error":"key"}`. The server works with the key's
   SHA-256 only and stores nothing else of it. A read may send the key, to learn `you`.
3. **A blocked key** gets `403 {"error":"blocked"}` on start, take, assign and report.
4. **Writes** must send `Content-Type: application/json` and a body under 2 KB. If a browser
   sends `Origin`, it must equal the request's own origin; otherwise `403 {"error":"origin"}`.
5. **The code** is 16 Crockford base32 characters. A khatma that never existed, was deleted, or
   is past its lifetime answers `404 {"error":"gone"}`.
6. **Organiser calls** from any other key get `403 {"error":"organiser"}`.
7. **Terms**: starting a khatma and joining one send `terms`, the version the reader accepted.
   An older version gets `422 {"error":"terms","current":n}`.

## Endpoints

| Method and path | Who | Request | Success | Errors |
| --- | --- | --- | --- | --- |
| `POST /api/khatma` | any key | `{title, name, division, finishDate?, terms}` | `201 Snapshot` | `422 invalid`; `429 limit` |
| `GET /api/khatma/{code}` | anyone | optional `If-None-Match` | `200 Snapshot` with `ETag: "v{version}"`; `304` when unchanged | `404 gone` |
| `POST …/{code}/parts/{n}/take` | any key | `{name?, terms?}` | `Snapshot` | `409 taken` with the snapshot; `403 removed`; `409 complete`; `422 invalid` |
| `POST …/{code}/parts/{n}/release` | the holder, or the organiser | none | `Snapshot` | `409 notYours` with the snapshot; `409 read` |
| `POST …/{code}/parts/{n}/read` | the holder, or the organiser | `{read: bool}` | `Snapshot` | `409 notYours` with the snapshot; `409 complete` for a holder undoing a mark in a complete khatma |
| `POST …/{code}/parts/{n}/assign` | organiser | `{name}` | `Snapshot` | `409 taken`; `422 invalid` |
| `POST …/{code}/leave` | a participant | none | `204` | `409 organiser`: the organiser deletes instead |
| `POST …/{code}/participants/{id}/remove` | organiser | none | `Snapshot` | `404` |
| `PATCH …/{code}` | organiser | `{title?, finishDate?}` | `Snapshot` | `422 invalid` |
| `DELETE …/{code}` | organiser | none | `204` | none |
| `POST …/{code}/report` | any key | `{participant?}` | `202` | `429 limit` |

Notes:
- `name` on `take` is needed the first time a key joins a khatma, and ignored after.
- Every successful write raises the khatma's `version` and sets `changed_at`.
- `finishDate` is `YYYY-MM-DD` or null.

## Shapes

```text
Snapshot = {code, title, division, finishDate, version, createdAt, completedAt,
            counts: {free, taken, read},
            organiser: participantId,
            parts: [{n, state: "free"|"taken"|"read", holder: participantId|null, readAt}],
            participants: [{id, name, typed}],
            you: {id: participantId|null, role: "organiser"|"participant"|"viewer"}}
Problem  = {field: "name"|"title"|"division"|"finishDate",
            kind: "empty"|"long"|"characters"|"link"|"word"|"value"}
```

- `participants` lists the organiser and everyone who holds or read a part. A removed
  participant is never listed.
- `typed` is true for a name the organiser typed for someone else.
- A snapshot of 60 parts is about 4 KB.

## Checks on names and titles (FR-060)

`functions/_lib/khatma-text.js`, in this order. The first failure is reported as a `Problem`.

1. Trim, and collapse runs of spaces. Empty: `empty`.
2. More than 30 characters for a name, 60 for a title, counted as code points: `long`.
3. A line break, a control character, or a direction override or isolate character:
   `characters`.
4. `://`, `www.`, `@`, or a dot between letters followed by two or more letters: `link`.
5. A listed word: `word`. The text is compared after removing Arabic marks and tatweel,
   unifying the forms of alef, hamza, yaa and taa marbuta, and lower-casing Latin letters.
   `functions/_lib/khatma-words.js` holds two lists: words matched as whole words, and strings
   matched anywhere.

The stored text is the trimmed text as typed, not the normalised form.

## Taking a part (FR-050)

One statement sets the holder where the part has no holder and is not read. If it changed a
row, the caller holds the part. If not, the answer is `409 {"error":"taken","snapshot":…}`. Two
calls for one part at the same moment therefore end with exactly one holder.

## Completion (FR-056)

After a `read` call, `completedAt` is set when no part is left unread, and cleared when the
organiser marks a part as not read. While `completedAt` is set, a holder cannot undo their own
mark.

## Limits (FR-067)

| Limit | Value | Answer |
| --- | --- | --- |
| Open khatmas organised by one key | 5 | `429 {"error":"limit","which":"organised"}` |
| Khatmas started by one key in a day | 20 | `429 … "started"` |
| Khatmas started by everyone in a day | 2,000 | `429 … "busy"` |
| Reports by one key in a day | 10 | `429 … "reports"` |

A Cloudflare rate limiting rule on the path, by IP, stands in front of the functions
([research R20](../research.md#r20-limits-and-abuse)).

## Lifetime (FR-066)

A khatma answers `404 gone` from 30 days after `completedAt`, or 90 days after `changedAt`. Its
rows are removed by the daily job below.

## Owner endpoints

Under `/api/editor/khatma/`, behind the existing Cloudflare Access application, and allowed only
for `OWNER_EMAIL` ([specs/011 contracts/editor-api.md](../../011-mutashabihat-online-editor/contracts/editor-api.md)
› Every request).

| Method and path | Request | Success |
| --- | --- | --- |
| `GET reports` | none | `{reports: [Report]}`, open ones first |
| `POST reports/{id}/resolve` | `{action: "none"\|"name"\|"khatma", block: bool}` | `Report` |

```text
Report = {id, code, participant, title, name, createdAt, resolvedAt, action, blocked,
          exists: bool}      exists: the khatma is still there
```

- `name`: the participant is removed as the organiser would remove them. For a typed name the
  part becomes free.
- `khatma`: the khatma is deleted.
- `block`: the hash of the key that typed the reported text goes into `blocks`.

The page `web/editor/khatma.html` lists the reports and calls these two endpoints. It is plain
HTML and JavaScript, like the Mutashabihat editor.

## The Worker `mthani-khatma-ops`

Source: `workers/khatma-ops/`. Bound to the same database, with an email sending binding and the
variables `OWNER_EMAIL` and `REPORT_FROM`. It has no public address.

| Schedule | Work |
| --- | --- |
| Every minute | For each report with `notified_at` null: send the owner one email with the report's number, the khatma's title, the reported name and the link to the owner's page, then set `notified_at`. A failed send is tried again the next minute. |
| Daily, 03:00 UTC | Delete khatmas past their lifetime, with their parts and participants. Delete reports closed more than 30 days ago. |

## What the tests must show

`node --test tool/khatma/*.test.mjs`, with D1 stood in for by `node:sqlite` and the real schema.

- Every endpoint: its success, each listed error, and that only the right key may call it.
- Two `take` calls for one part, run together 50 times: one `Snapshot`, one `409 taken`, and
  one holder in the database each time (SC-015).
- A read with the current `ETag` gives `304` and no body.
- The filter: at least 50 refused names and 50 refused titles in each of Arabic and English,
  and a list of ordinary names in both that pass (SC-021).
- Leaving, removing and deleting leave no copy of the names concerned in any table (SC-019).
- A blocked key is refused on the four calls, and a removed key cannot join that khatma.
- Each limit answers `429` at its value and not before.
- The minute job emails each new report once. The daily job removes what is past its lifetime
  and nothing else.
- A request without a key, with a foreign `Origin`, or with a body over 2 KB is refused.
