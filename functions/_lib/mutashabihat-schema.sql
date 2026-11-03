-- Mutashabihat editor storage (specs/011 data-model.md). Safe to apply again.
--   npx wrangler@4 d1 execute mthani-mutashabihat --remote --file functions/_lib/mutashabihat-schema.sql

-- The working set: what is published plus the shared draft.
CREATE TABLE IF NOT EXISTS groups (
  id          TEXT PRIMARY KEY,
  ayat        TEXT NOT NULL,             -- "2:35 7:19", Mushaf order, normalised
  note        TEXT NOT NULL DEFAULT '',  -- the owner's private note
  explanation TEXT NOT NULL,
  deleted     INTEGER NOT NULL DEFAULT 0,
  revision    INTEGER NOT NULL DEFAULT 1,
  updated_by  TEXT NOT NULL,
  updated_at  INTEGER NOT NULL
);

-- Published versions, append only.
CREATE TABLE IF NOT EXISTS versions (
  number        INTEGER PRIMARY KEY,
  format        INTEGER NOT NULL,
  content       TEXT NOT NULL,
  sha256        TEXT NOT NULL,
  bytes         INTEGER NOT NULL,
  groups_json   TEXT NOT NULL,
  summary       TEXT NOT NULL,
  published_by  TEXT NOT NULL,
  published_at  INTEGER NOT NULL,
  restored_from INTEGER
);

-- People the owner allowed to edit. The owner (OWNER_EMAIL) is never stored here.
CREATE TABLE IF NOT EXISTS editors (
  email    TEXT PRIMARY KEY,
  added_by TEXT NOT NULL,
  added_at INTEGER NOT NULL
);
