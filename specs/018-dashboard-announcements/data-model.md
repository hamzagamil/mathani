# Data Model: Send Announcements from the Owner Dashboard

## Announcement (D1 `mthani-mutashabihat`, table `announcements`)

One row per send attempt (spec FR-014). Holds nothing about readers.

| Column | Type | Rules |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | |
| `request_id` | TEXT NOT NULL UNIQUE | UUID from the page, one per confirmation (research R4) |
| `audience` | TEXT NOT NULL | `all`, `lang_ar` or `lang_en` |
| `title` | TEXT NOT NULL | trimmed, 1–65 characters |
| `body` | TEXT NOT NULL | trimmed, 1–240 characters |
| `link` | TEXT | null, or `https://` on `mthani.app`, `www.mthani.app`, `get.mthani.app` |
| `ttl` | INTEGER NOT NULL | seconds: 3600, 86400, 604800 or 2419200 |
| `sent_by` | TEXT NOT NULL | the owner's address from the Access token |
| `created_at` | INTEGER NOT NULL | milliseconds, the server's clock |
| `status` | TEXT NOT NULL | see below |
| `message` | TEXT | FCM's message name when sent (`projects/mthani/messages/…`) |
| `detail` | TEXT | FCM's error text when not sent, at most 500 characters |
| `finished_at` | INTEGER | when the status left `sending` |

Index: `announcements_created (created_at)` for the history and the hourly limit.

Characters are counted as the page counts them (`[...text].length`, code points), on both sides.

## Status

```text
sending ──► sent
   │
   ├──► notConfigured | rejected | busy | unavailable
```

- A row is written as `sending` before FCM is called and is updated once.
- A row still `sending` after 1 minute is shown as "unknown, check before resending" (the call
  may or may not have reached FCM).
- Only `sending` and `sent` count toward 10 per hour (research R6).

## Audience (fixed, not stored)

| Value | Shown as | App topic (015) |
| --- | --- | --- |
| `all` | جميع القراء | `all` |
| `lang_ar` | قراء العربية | `lang_ar` |
| `lang_en` | قراء الإنجليزية | `lang_en` |

## Retention

Rows stay until the owner deletes them in D1 (spec FR-017); there is no delete button.
