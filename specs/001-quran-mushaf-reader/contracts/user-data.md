# Contract: On-Device User Data (`user.db`)

- **Owner**: the app (`UserRepository`).
- **Location**: the platform's app database directory. It is never synced or uploaded (FR-027).
- **Lifetime**: survives app updates. It is deleted with the app (accepted in spec assumptions).
- **Migrations**: `PRAGMA user_version` holds the schema version. Each version step has a
  forward-only migration. A migration never deletes bookmarks.

## Schema v1

```sql
CREATE TABLE bookmarks (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  surah       INTEGER NOT NULL,
  ayah        INTEGER NOT NULL,
  page        INTEGER NOT NULL,
  created_at  INTEGER NOT NULL,          -- Unix ms
  UNIQUE (surah, ayah)
);
CREATE INDEX bookmarks_created ON bookmarks(created_at DESC);

CREATE TABLE reading_state (
  id            INTEGER PRIMARY KEY CHECK (id = 1),
  anchor_surah  INTEGER NOT NULL DEFAULT 1,
  anchor_ayah   INTEGER NOT NULL DEFAULT 1,
  updated_at    INTEGER NOT NULL
);

CREATE TABLE preferences (
  key    TEXT PRIMARY KEY,
  value  TEXT NOT NULL
) WITHOUT ROWID;
-- keys and allowed values: see data-model.md › Preferences
```

## Operations

| Operation | Behaviour |
| --- | --- |
| `addBookmark(surah, ayah)` | `INSERT OR IGNORE`, then returns the row. A duplicate is a no-op (FR-015). |
| `removeBookmark(id)` | deletes the row; the page indicator updates through change notification |
| `listBookmarks()` | `ORDER BY created_at DESC` |
| `isBookmarked(page)` | true if any bookmark's page equals *page* (page indicator) |
| `saveAnchor(surah, ayah)` | upsert the single row (debounce and lifecycle policy in data-model.md) |
| `loadStartup()` | one call returning anchor and all preferences; it must finish before the first reader frame (≤ 30 ms) |
