# Research: Online Mutashabihat Editor

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-11-03

The spec has no open questions (Clarifications, 2026-11-03). This file records the design choices.

## R1. Where the editor and the content live

**Decision**: On the Cloudflare Pages project that already serves the web app, `mthani-web`
(specs/008, docs/release.md › Web):

- **Editor page**: static files at `get.mthani.app/editor/`, kept in `web/editor/`. Flutter copies
  the `web/` folder into `build/web` as it is, so the existing deploy publishes them.
- **Server**: Pages Functions under `/api/editor/*` (editing) and `/api/mutashabihat` (what the
  apps download), next to the existing `/api/prayer-*` functions.
- **Storage**: one Cloudflare D1 database, `mthani-mutashabihat`, bound as `DB`.

**Rationale**:
- No new host, account or bill (spec Assumptions: "Hosting").
- One deploy publishes the app and the editor together.
- Functions and D1 are covered by the free plan at this scale (R9).
- The apps already call this host for prayer locations, so no new domain enters the app or the
  store privacy answers.

**Alternatives considered**:
- *A Git-backed editor* (the page commits to GitHub): needs a GitHub token on the server and a
  rebuild for every publish, and readers would still wait for a release.
- *A hosted CMS*: a new service, account and data processor for 72 groups of text.
- *Cloudflare KV only*: no transactions or queries, so drafts, conflicts and history would be
  hand-built on top of key-value pairs.
- *R2 files*: the same objection as KV, for structured data.

## R2. Signing in and who may edit

**Decision**: Cloudflare Access in front of the editor, with the app checking permission itself.

1. **Access**: an Access application covers `get.mthani.app/editor` and
   `get.mthani.app/api/editor`, and also the `mthani-web.pages.dev` and preview hostnames. Its
   policy allows anyone who proves an email address with Access's one-time PIN. Access shows its
   own sign-in page, so no content is visible before sign-in (spec Edge Cases).
2. **The functions check permission on every request**:
   - verify the `Cf-Access-Jwt-Assertion` token: RS256 signature against the team's published
     keys, audience, expiry;
   - read the email from the token;
   - allow the request only if the email is `OWNER_EMAIL` or is in the `editors` table.
   - A removed editor is refused on their next request (FR-002), even with a valid Access
     session.
3. **Editor management**: only `OWNER_EMAIL` can add or remove editors (FR-002a).

**Rationale**:
- Access gives email sign-in with one-time codes, free for up to 50 users, and the app never
  stores passwords.
- Keeping the editor list in D1 lets the owner manage editors in the editor itself. If Access
  held the list, managing editors would need a Cloudflare dashboard login.
- Checking the token in the function means a request that bypasses Access, for example straight
  to a `pages.dev` address, still fails.

**Alternatives considered**:
- *A password in the editor*: would mean storing hashes and building reset and lockout ourselves.
- *Our own email codes*: the account has no mail-sending service (Email Routing only receives).
- *An Access email allow-list*: managing editors would need the Cloudflare dashboard.

**Owner setup**: the Zero Trust dashboard steps are in [quickstart.md](./quickstart.md) › Setup.
Wrangler's login cannot create Access applications.

## R3. One content format end to end

**Decision**: The published content is the same Markdown file format as today
([specs/010 contracts/content-file.md](../010-mutashabihat/contracts/content-file.md)), produced
by the server from the groups. Its preamble gains one line, `<!-- version: N -->`, which the app
reads.

- The app keeps one parser (`parseMutashabihat`) for the bundled, downloaded and released copies.
- The server has a JavaScript port of the same rules: `functions/_lib/mutashabihat-content.js`
  parses the import, checks saves and publishes, and renders the Markdown. A test runs both
  parsers on the same fixture and expects the same groups.
- `parseMutashabihat` reads `version` from the preamble line. It is `0` when the line is absent,
  as in today's bundled file.

**Alternatives considered**: JSON for the download. It is simpler to parse, but the app would
need a second parser and the release snapshot would no longer be the file the owner knows.

## R4. Drafts, publishing and history

**Decision**:
- **The working set**: table `groups` holds every group's current saved state, with a stable
  `id`, a `revision` counter, `updated_by` and `updated_at`, and a `deleted` flag.
- **Published versions**: each publish writes a row to `versions` with:
  - the rendered Markdown and its SHA-256;
  - the groups as JSON;
  - who published it, and when;
  - a summary of groups added, changed and removed.
- **The draft** is the difference between `groups` and the latest version's groups, matched by
  `id`.
- **Conflicts**: a save sends the `revision` it started from. If the stored revision has moved
  on, the save is refused with `409` and the name of who changed it (spec Edge Cases).
- **Deletes**: a deleted group stays until the next publish, so it can be undone (Story 2 AS4).
  A publish removes rows that are deleted and were never published.
- **Restore** (Story 4):
  - copies an old version's groups back into `groups` and publishes them as a new version,
    recording `restored_from`;
  - is refused while there are unpublished changes, unless the request says to discard them.
    The editor asks first.
- **Checks on publish**: every publish runs the full check on all groups (FR-010), in a D1 batch,
  so a failed publish changes nothing.

**Rationale**: one shared draft is what the owner chose (Q2: A). Revisions catch the two-editor
case without locking.

## R5. How the apps get updates

**Decision**: `GET /api/mutashabihat` (contract: [contracts/content-api.md](./contracts/content-api.md)).

- **When to check**: after the first frame, and when the app comes back to the foreground, at
  most once every 6 hours (FR-012). The check is skipped while offline.
- **Request**: carries `If-None-Match` with the version the app has. An unchanged result is a
  `304` with no body, well under 1 KB (SC-004).
- **Response**: a new version comes back as `200` with the Markdown and these headers:
  - `ETag: "vN"`;
  - `X-Content-Version`, `X-Content-Format` and `X-Content-SHA256`.
- **Using a download**: the app uses it only if all of these hold (FR-014):
  - the format is one it supports (1);
  - the SHA-256 and length match;
  - the version is newer than the one it has;
  - the parse finds no errors and at least one group.
- **Saving**: the file is written as `.part` and then renamed through `FileStore`
  (`support/mutashabihat/content.md`). A small `meta.json` stores the version and the time of
  the last check.
- **Applying**: `ReaderController.replaceSimilar(content)` swaps the content and notifies
  listeners. The Mushaf relayouts the visible page, because the renderer compares `similar` by
  identity (specs/010 R5). An open overlay keeps the groups it was opened with (FR-015).
- **At startup**: `loadMutashabihat()` reads the bundled asset and the downloaded copy in
  parallel and uses the higher version. A newer app release is not shadowed by an older
  download.
- **Base address**: the app's own origin on the web, and `https://get.mthani.app` on phones. This
  is the same rule as the prayer location service, moved into one shared helper
  (`lib/platform/api_base.dart`).

**Web specifics**: the service worker currently caches every same-origin GET except
`/api/prayer-*`. It must pass every `/api/` request and every `/editor/` request straight to the
network. Otherwise readers would get a stale copy, and the editor would be served from the app's
cache.

**Alternatives considered**:
- *Push notifications to trigger updates*: the spec puts push out of scope, and a delay of a day
  is acceptable.
- *Checking on every launch*: more requests for no reader benefit.

## R6. Serving many readers cheaply

**Decision**:
- **Edge cache**: `/api/mutashabihat` serves from the Cloudflare edge cache (Cache API) under the
  key `vN`. D1 is read only to learn the current version number, and that number is itself
  cached for 60 seconds, so a publish is served within about a minute.
- **Headers**:
  - `200`: `Cache-Control: public, max-age=300`;
  - `304`: no body.
- **Rough load**: 10,000 daily readers checking about every 6 hours is roughly 40,000 function
  requests a day. That is under the free plan's 100,000, with almost no D1 reads.

## R7. Releases carry the latest content (Story 5, FR-018)

**Decision**:
- **`dart run tool/pull_mutashabihat.dart`**: downloads `/api/mutashabihat`, checks it like the
  app does, and writes it to `assets/mutashabihat/mutashabihat.md`, version line included. It
  fails with a clear message if the server cannot be reached.
- **Where it runs**:
  - *Local releases* (`docs/release.md`): run it before `flutter build`, then commit the snapshot
    (`chore(content): mutashabihat vN`), so a release can be rebuilt from git.
  - *`ios-release.yml`*: runs it before the build. The release log records the content version,
    and D1 keeps every version, so the build can be reproduced.
  - *`tool/web_deploy.mjs` `prepare()`*: compares the bundled version with the published one.
    It stops if the bundle is older ("pull and rebuild") or if the server cannot be reached.
- **The existing `check_mutashabihat` step stays** and runs on the pulled file.

## R8. The editor page

**Decision**:
- **Construction**: plain HTML, CSS and JavaScript in `web/editor/`, with no framework and no
  build step (Principle IV). The interface is Arabic and right to left (spec Assumptions).
- **Layout**: one column at phone width, a list beside the detail on wide screens (FR-003).
- **Screens** ([contracts/editor-ui.md](./contracts/editor-ui.md)):
  - the group list, with search and a filter for unpublished changes;
  - the group form;
  - Publish, with the list of changes;
  - History;
  - Editors, shown to the owner only.
- **Ayah text preview** (FR-005): `build/web/editor/quran.json` holds every ayah's Uthmani text
  and surah names, about 2 MB, or about 0.5 MB compressed. `tool/build_editor_quran.dart`
  generates it from `quran.db` during deploy `prepare()`. It is not committed, and is loaded once
  per session.
- **Unsaved edits**: kept in `localStorage` per group id, and offered back on return (spec Edge
  Cases).
- **First use** (FR-008): when D1 has no groups, the owner sees «استيراد المحتوى الحالي». It
  fetches the bundled `/assets/assets/mutashabihat/mutashabihat.md` and posts it to
  `/api/editor/import`. The server accepts this only from the owner and only when D1 is empty,
  and it creates the groups plus version 1 from them.
- **Font**: Amiri Quran from the web build's own assets, so no external font host.

## R9. Limits and cost

- **D1 (free plan)**: 5 GB, 5 million reads and 100,000 writes a day. At a few hundred KB per
  version, a thousand versions of history is still tiny.
- **Workers/Pages Functions (free plan)**: 100,000 requests a day (R6).
- **Access (free plan)**: up to 50 users.
- **App size**: about 10 KB of code. No new packages in the app or the functions.

## R10. Testing

- **Functions**: `node --test tool/mutashabihat/*.test.mjs`, the same style as
  `tool/prayer/location_api_test.mjs`.
  - D1 is stood in for by a small adapter over Node 24's `node:sqlite`, with the same SQL.
  - Access tokens are signed in the test with a generated RSA key, and the key fetcher is
    injected.
- **App**: `flutter_test` for the updater (fake HTTP client, `MemoryFileStore`), for the version
  choice at startup, and for `replaceSimilar` updating the page.
- **Cross-check**: one test parses `test/fixtures/mutashabihat/quickstart.md` with both the Dart
  and the JS parser (the Dart side writes JSON to compare).
- **On devices**: [quickstart.md](./quickstart.md).
