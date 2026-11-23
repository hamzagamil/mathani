-- Owner announcements (specs/018 data-model.md). D1 database `mthani-mutashabihat`, bound as DB.
-- Apply with: npx wrangler@4 d1 execute mthani-mutashabihat --remote --file functions/_lib/announcements-schema.sql

CREATE TABLE IF NOT EXISTS announcements (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  request_id   TEXT NOT NULL UNIQUE,         -- one per confirmation on the page (research R4)
  audience     TEXT NOT NULL,                -- all | lang_ar | lang_en
  title        TEXT NOT NULL,                -- trimmed, 1 to 65 characters
  body         TEXT NOT NULL,                -- trimmed, 1 to 240 characters
  link         TEXT,                         -- https on mthani.app, www.mthani.app or get.mthani.app
  ttl          INTEGER NOT NULL,             -- seconds: 3600, 86400, 604800 or 2419200
  sent_by      TEXT NOT NULL,                -- the owner's address from the Access token
  created_at   INTEGER NOT NULL,             -- milliseconds, the server's clock
  status       TEXT NOT NULL,                -- sending | sent | notConfigured | rejected | busy | unavailable
  message      TEXT,                         -- FCM's message name when sent
  detail       TEXT,                         -- FCM's error text when not sent, at most 500 characters
  finished_at  INTEGER
);
CREATE INDEX IF NOT EXISTS announcements_created ON announcements (created_at);
