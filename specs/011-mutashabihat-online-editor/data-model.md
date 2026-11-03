# Data Model: Online Mutashabihat Editor

**Feature**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

## Server: D1 database `mthani-mutashabihat`

Schema file: `functions/_lib/mutashabihat-schema.sql`. It is applied with
`npx wrangler@4 d1 execute mthani-mutashabihat --remote --file functions/_lib/mutashabihat-schema.sql`.

### `groups`: the working set (published state plus the shared draft)

| Column | Type | Rule |
| --- | --- | --- |
| `id` | TEXT PK | Random, 12 characters, never reused. |
| `ayat` | TEXT | Space-separated `surah:ayah`, Mushaf order, 2 or more distinct, all real ayat (FR-006). |
| `note` | TEXT | The owner's private note; may be empty (FR-007). |
| `explanation` | TEXT | Not empty after trimming. Paragraphs separated by one blank line. |
| `deleted` | INTEGER 0/1 | A delete waiting for the next publish; can be undone until then. |
| `revision` | INTEGER | +1 on every save; a save must send the revision it started from (R4). |
| `updated_by` | TEXT | Email of the last person who saved it. |
| `updated_at` | INTEGER | Milliseconds since the epoch. |

Each row has a draft status, worked out by comparing it with the latest version's `groups_json`
by `id`:

| Status | Meaning |
| --- | --- |
| `published` | Same as in the latest version. |
| `added` | Not in the latest version and not deleted. |
| `changed` | In the latest version with a different `ayat`, `note` or `explanation`. |
| `removed` | In the latest version and `deleted = 1`. |
| `discarded` | Neither in the latest version nor kept (`deleted = 1`). Hidden, and purged on publish. |

### `versions`: published history (append only)

| Column | Type | Rule |
| --- | --- | --- |
| `number` | INTEGER PK | 1, 2, 3… |
| `format` | INTEGER | Content format: 1 for the Markdown of specs/010 plus the version line. |
| `content` | TEXT | The rendered Markdown that apps download. |
| `sha256` | TEXT | Hex SHA-256 of `content` (UTF-8). |
| `bytes` | INTEGER | UTF-8 length of `content`. |
| `groups_json` | TEXT | `[{id, ayat, note, explanation}]` in file order, for diffs and restore. |
| `summary` | TEXT | JSON `{added, changed, removed}` counts against the previous version. |
| `published_by` | TEXT | Email. |
| `published_at` | INTEGER | Milliseconds since the epoch. |
| `restored_from` | INTEGER NULL | Set when the version restores an earlier one. |

### `editors`

| Column | Type | Rule |
| --- | --- | --- |
| `email` | TEXT PK | Lower-case. Never `OWNER_EMAIL`, who is always allowed and is not stored. |
| `added_by` | TEXT | Always the owner. |
| `added_at` | INTEGER | Milliseconds since the epoch. |

### Configuration (Pages environment, `wrangler.toml` `[vars]`)

| Name | Meaning |
| --- | --- |
| `OWNER_EMAIL` | The owner's email. Only this address manages editors and runs the first import. |
| `ACCESS_TEAM_DOMAIN` | For example `mthani.cloudflareaccess.com`: where Access publishes its signing keys. |
| `ACCESS_AUD` | The Access application's audience tag. |

None of these is a secret: the token signature is checked against Access's public keys.

## Rendered content (what apps download)

```markdown
<!-- version: 12 -->
# متشابهات القرآن — ملف المحتوى
…the guide preamble from specs/010…

## 2:1 3:1 29:1 30:1 31:1 32:1 | البقرة ١
…explanation…
```

- **Order**: groups appear in a stable order (`groups.rowid`), so the file diffs cleanly between
  versions.
- **Rules**: the specs/010 content-file contract applies unchanged, and the version line sits in
  the preamble.
- **Parser**: `parseMutashabihat` exposes `Mutashabihat.version`, which is `0` when the line is
  absent.

## App: content on the device

`FileStore`, root `support`:

| File | Content |
| --- | --- |
| `mutashabihat/content.md` | The last complete, checked download. |
| `mutashabihat/content.md.part` | A download in progress; never read. |
| `mutashabihat/meta.json` | `{"version": 12, "sha256": "…", "checkedAt": 1730620000000}` |

### Choosing the content at startup

`loadMutashabihat()` uses `max(bundled.version, downloaded.version)`. On a tie it uses the
bundled copy, which is the same content without a file read. A downloaded copy that fails to
parse is ignored and deleted.

### Updater state

```
idle ──(first frame or resume, online, checkedAt older than 6 h)──▶ checking
checking ──304──────────────────────────▶ idle (checkedAt = now)
checking ──200, all checks pass────────▶ saving ──▶ applied ──▶ idle
checking ──200, a check fails──────────▶ idle (keeps current; checkedAt = now)
checking ──network error or timeout────▶ idle (checkedAt unchanged, retried on next resume)
```
