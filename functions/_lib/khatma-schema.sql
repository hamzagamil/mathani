-- Group khatmas (specs/014 data-model.md › 4). D1 database `mthani-khatma`, bound as KHATMA_DB.
-- Apply with: npx wrangler@4 d1 execute <name> --remote --file functions/_lib/khatma-schema.sql

CREATE TABLE IF NOT EXISTS khatmas (
  code          TEXT PRIMARY KEY,            -- 16 characters, Crockford base32, random
  title         TEXT NOT NULL,               -- 1 to 60 characters, filtered
  division      INTEGER NOT NULL CHECK (division IN (30, 60)),
  finish_date   TEXT,                        -- YYYY-MM-DD
  organiser     TEXT NOT NULL,               -- hash of the organiser's key
  version       INTEGER NOT NULL DEFAULT 1,  -- rises by one with every change
  created_at    INTEGER NOT NULL,            -- milliseconds, the server's clock
  changed_at    INTEGER NOT NULL,
  completed_at  INTEGER                      -- set when every part is read
);
CREATE INDEX IF NOT EXISTS khatmas_changed ON khatmas (changed_at);
CREATE INDEX IF NOT EXISTS khatmas_created ON khatmas (created_at);
CREATE INDEX IF NOT EXISTS khatmas_organiser ON khatmas (organiser);

CREATE TABLE IF NOT EXISTS participants (
  id         TEXT PRIMARY KEY,               -- 12 random characters, public inside the khatma
  code       TEXT NOT NULL,
  name       TEXT NOT NULL,                  -- 1 to 30 characters, filtered; empty once removed
  key_hash   TEXT,                           -- null for a name the organiser typed
  removed    INTEGER NOT NULL DEFAULT 0,     -- 1: the key cannot join this khatma again
  joined_at  INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS participants_key ON participants (code, key_hash);
CREATE INDEX IF NOT EXISTS participants_code ON participants (code);

CREATE TABLE IF NOT EXISTS parts (
  code     TEXT NOT NULL,
  number   INTEGER NOT NULL,                 -- 1 to division
  holder   TEXT,                             -- a participant id
  read_at  INTEGER,                          -- the server's clock
  PRIMARY KEY (code, number)
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS reports (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  code         TEXT NOT NULL,
  participant  TEXT,                         -- null: the whole khatma
  title        TEXT NOT NULL,                -- copies as they were when reported
  name         TEXT NOT NULL,
  poster       TEXT,                         -- hash of the key that typed the reported text
  reporter     TEXT NOT NULL,                -- hash of the reporter's key
  created_at   INTEGER NOT NULL,
  notified_at  INTEGER,
  resolved_at  INTEGER,
  action       TEXT                          -- none | name | khatma, and whether blocked
);
CREATE INDEX IF NOT EXISTS reports_open ON reports (resolved_at, created_at);
CREATE INDEX IF NOT EXISTS reports_reporter ON reports (reporter, created_at);

CREATE TABLE IF NOT EXISTS blocks (
  key_hash    TEXT PRIMARY KEY,              -- a key Mathani blocked
  blocked_at  INTEGER NOT NULL,
  report      INTEGER
);
