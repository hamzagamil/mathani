---

description: "Tasks for the Online Mutashabihat Editor"
---

# Tasks: Online Mutashabihat Editor

**Input**: Design documents from `specs/011-mutashabihat-online-editor/`. Read these before
starting a phase:
- [plan.md](./plan.md)
- [spec.md](./spec.md)
- [research.md](./research.md)
- [data-model.md](./data-model.md)
- [contracts/content-api.md](./contracts/content-api.md)
- [contracts/editor-api.md](./contracts/editor-api.md)
- [contracts/editor-ui.md](./contracts/editor-ui.md)
- [quickstart.md](./quickstart.md)

**Tests**: The plan lists automated tests (Technical Context › Testing):
- the functions, with `node --test` over a `node:sqlite` D1 stand-in;
- the app updater and loader, with `flutter_test`;
- a check that the Dart and JavaScript parsers agree.

They are included below. Device checks are in [quickstart.md](./quickstart.md).

**Organization**: Tasks are grouped by user story (US1–US5 from spec.md).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on unfinished tasks).
- **[Story]**: US1–US5.

## Path Conventions

- **Functions**: `functions/`, with tests in `tool/mutashabihat/` (style of
  `tool/prayer/location_api_test.mjs`).
- **Editor page**: `web/editor/`.
- **App**: `lib/`, `test/`.
- **Tools**: `tool/`.

---

## Phase 1: Setup

- [X] T001 Create `functions/_lib/mutashabihat-schema.sql` with the `groups`, `versions` and
  `editors` tables exactly as in [data-model.md](./data-model.md), with `CREATE TABLE IF NOT
  EXISTS` so it can be applied again.
- [X] T002 Add to `wrangler.toml`:
  - a `[[d1_databases]]` block, `binding = "DB"`, `database_name = "mthani-mutashabihat"`, with
    a placeholder `database_id` filled in T046;
  - `OWNER_EMAIL = "hamzagamil@gmail.com"` under `[vars]`;
  - `ACCESS_TEAM_DOMAIN` and `ACCESS_AUD` as empty strings, with a comment pointing to
    quickstart › Setup 4.
- [X] T003 [P] In `web/_routes.json`, add `"/api/mutashabihat"` and `"/api/editor/*"` to
  `include`.
- [X] T004 [P] In `web/_headers`, add `Cache-Control: no-cache` for `/editor/*`. The functions
  set their own headers.
- [X] T005 [P] In `web/sw.js` `fetch`, pass every request whose path starts with `/api/` or
  `/editor` to the network untouched: replace the `/api/prayer-` test with
  `url.pathname.startsWith('/api/') || url.pathname.startsWith('/editor')`. Add a comment
  pointing to research R5.
- [X] T006 [P] Create `tool/mutashabihat/support.mjs` with:
  - `d1()`: a D1-like adapter over `node:sqlite` `DatabaseSync(':memory:')`, offering
    `prepare(sql).bind(...).all()/first()/run()` and `batch([...])` (in one transaction), with
    `mutashabihat-schema.sql` applied;
  - `accessKeys()`: makes an RSA key pair with `node:crypto`, and returns
    `sign({email, aud, exp})` → JWT plus a `certs` fetcher returning `{keys:[jwk with kid]}`;
  - `request(path, {method, body, token, origin})`: builds a `Request` for
    `https://get.mthani.app`;
  - `env`: `{DB, OWNER_EMAIL:'owner@example.com', ACCESS_TEAM_DOMAIN:'t.cloudflareaccess.com',
    ACCESS_AUD:'aud1'}`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T007 Create `functions/_lib/mutashabihat-content.js`, the JavaScript port of
  `lib/features/mutashabihat/mutashabihat_content.dart`. It exports:
  - `ayahCounts` (the same 114 numbers);
  - `parse(text)` → `{version, groups:[{ayat:[[s,a]...], note, explanation, line}], problems}`,
    with the same rules and message texts as the Dart parser (see
    [contracts/editor-api.md](./contracts/editor-api.md) › Checks);
  - `checkGroup({ayat, note, explanation})` → `{ayat: normalised "2:35 7:19", problems}`, which
    also rejects a note with a line break and an explanation line starting `## `;
  - `render({version, groups})` → Markdown: `<!-- version: N -->`, then the specs/010 guide
    preamble, copied from the first 13 lines of `assets/mutashabihat/mutashabihat.md` before the
    source note, then `## ayat | note` and the explanation, groups separated by one blank line;
  - `sha256Hex(text)` using `crypto.subtle`.
- [X] T008 [P] Create `tool/mutashabihat/content.test.mjs`:
  - each rule and message (bad reference, missing ayah, too few, empty, duplicate kept once,
    Arabic-Indic digits);
  - `render` then `parse` gives back the same groups and version;
  - the shipped `assets/mutashabihat/mutashabihat.md` parses with no errors into 72 groups;
  - `test/fixtures/mutashabihat/quickstart.md` gives 5 groups.
- [X] T009 Create `functions/_lib/access.js` exporting
  `async verifyAccess(request, env, {fetchCerts, now})` → `{email}` or `null`:
  - reads `Cf-Access-Jwt-Assertion`;
  - splits the JWT and finds the key by `kid` in
    `https://{ACCESS_TEAM_DOMAIN}/cdn-cgi/access/certs`, cached in a module `Map` for 1 hour;
  - verifies RS256 with `crypto.subtle.importKey('jwk', …, {name:'RSASSA-PKCS1-v1_5',
    hash:'SHA-256'})`;
  - checks that `aud` (a string or an array) contains `ACCESS_AUD`, and `exp` > now;
  - returns the lower-cased `email`;
  - returns `null` on any failure, including an empty `ACCESS_AUD`.
- [X] T010 [P] Create `tool/mutashabihat/access.test.mjs`: valid token → email; wrong signature,
  wrong `aud`, expired, missing header, unknown `kid`, empty `ACCESS_AUD` → `null`.
- [X] T011 Create `functions/_lib/editor-store.js`, taking a D1 `db`:
  - `listGroups()`: every row except `discarded`, with `status` from the latest version
    ([data-model.md](./data-model.md) › draft status);
  - `latestVersion()`;
  - `getGroup(id)`;
  - `isEmpty()`;
  - `importMarkdown(markdown, email)`:
    - only when `isEmpty()`;
    - uses `parse`, refusing on any error;
    - inserts groups with new 12-character ids (`crypto.getRandomValues`, base32);
    - writes version 1 from them with `render`, in one `batch`;
  - `isEditor(email)`.

  Store `ayat` normalised, as in T007.
- [X] T012 Create `functions/_lib/editor-api.js` exporting
  `dispatch(request, env, deps = {})`:
  - **Access**: `verifyAccess` → `401 {"error":"signIn"}`, then owner or `isEditor` →
    `403 {"error":"notAnEditor"}`.
  - **Writes**: refuse an `Origin` that differs from the request's origin with
    `403 {"error":"origin"}`, and refuse a non-JSON body with `415`.
  - **Responses**: JSON with `Cache-Control: private, no-store`.
  - **Routes**: `GET me`, `GET groups`, `POST import` (owner only;
    `409 notEmpty`/`422`). An unknown route → `404`.

  Create `functions/api/editor/[[path]].js`:
  `export const onRequest = ({request, env}) => dispatch(request, env);`.
- [X] T013 [P] Create `tool/mutashabihat/editor_api.test.mjs` with the first cases:
  - no token → 401;
  - a stranger → 403;
  - owner `GET me` → `isOwner: true`;
  - owner `POST import` with the shipped file → version 1, and `GET groups` gives 72 groups all
    `published`;
  - a second import → 409;
  - a cross-origin `POST` → 403.
- [X] T014 [P] In `lib/features/mutashabihat/mutashabihat_content.dart`:
  - add `final int version` to `Mutashabihat` (default `0`; `empty` has `0`);
  - make `parseMutashabihat` read it from a preamble line matching `^<!-- version: (\d+) -->$`.

  Add tests to `test/unit/mutashabihat_content_test.dart`: version read; absent → 0; a version
  line inside a group's explanation is ignored.
- [X] T015 [P] Create `lib/platform/api_base.dart`, moving `_defaultBase()` out of
  `lib/platform/prayer_location.dart`: `Uri apiBase()`, which keeps the
  `MATHANI_API_BASE`/localhost rules. Make `PrayerLocationService` use it. Its tests stay green.
- [X] T016 In `lib/shared/reader_state.dart`:
  - make `similar` a private field with a getter;
  - add `void replaceSimilar(Mutashabihat next)`, which sets it and calls `notifyListeners()`
    (no-op when `identical`).

  Create `test/widget/similar_live_swap_test.dart`: on 2:35's page in both layouts, the renderer
  colours 2:35 after `replaceSimilar(content with 2:35)` and stops after
  `replaceSimilar(Mutashabihat.empty)`, without a restart.
- [X] T017 [P] Create `tool/mutashabihat/parse_cli.mjs`: prints `parse(file)` as JSON
  `{version, groups:[{ayat:"2:35 7:19", explanation}]}`.

  Create `test/unit/mutashabihat_parsers_agree_test.dart`: runs `node
  tool/mutashabihat/parse_cli.mjs` on `test/fixtures/mutashabihat/quickstart.md` and on the
  shipped file, compares with `parseMutashabihat`, and is skipped with a reason when `node` is
  not on the PATH.
- [X] T018 Create the editor shell in `web/editor/`:
  - **`index.html`**: `lang="ar" dir="rtl"`, links `editor.css` and `editor.js`, no inline
    script.
  - **`editor.css`**: tokens matching the app's day palette (surface `#F2EADD`, ink `#183159`,
    accent `#BA9757`, line `#D9CCB5`), Amiri Quran from
    `/assets/assets/fonts/AmiriQuran-Regular.ttf` and IBM Plex Sans Arabic from
    `/assets/assets/fonts/IBMPlexSansArabic-Regular.ttf`, one column under 900 px, 44 px
    targets, a visible focus.
  - **`editor.js`**:
    - `api(method, path, body)`, sending JSON with `credentials:'same-origin'`;
    - the hash router of [contracts/editor-ui.md](./contracts/editor-ui.md);
    - a top bar with the email from `GET me`;
    - the «خروج» link `/cdn-cgi/access/logout`;
    - the not-an-editor screen on `403`;
    - first use: «استيراد المحتوى الحالي» for the owner. It fetches
      `/assets/assets/mutashabihat/mutashabihat.md` and posts it to `import`.
- [X] T019 [P] Create `tool/build_editor_quran.dart` (`dart run`, `package:sqlite3` as in
  `tool/verify_quran.dart`). It writes `build/web/editor/quran.json` as
  `{"surahs":[{"n":1,"name":"الفاتحة","count":7}…],"ayat":{"1:1":"بِسْمِ …"}}` with Uthmani text
  without the ayah-end marker.

  In `tool/web_deploy.mjs` `prepare()`, run it with `execSync` after the existing checks, and
  `fail()` if it does not produce the file.

**Checkpoint**:
- `node --test tool/mutashabihat/*.test.mjs` and `flutter test` pass.
- A local `wrangler pages dev build/web` with the D1 binding serves the editor shell and import.

---

## Phase 3: User Story 1 - Fix an explanation and see it on phones the same day (Priority: P1) 🎯 MVP

**Goal**: edit a group's explanation, publish it, and installed apps show it after their next
check (FR-004, FR-009, FR-010, FR-012 to FR-016).

**Independent Test**: [quickstart.md](./quickstart.md) E1.

### Tests for User Story 1

- [X] T020 [P] [US1] Create `tool/mutashabihat/content_api.test.mjs` for
  `functions/api/mutashabihat.js`:
  - `404 notPublished` before import;
  - after import, `200` with the [contracts/content-api.md](./contracts/content-api.md) headers,
    a body SHA-256 that matches, and the version line;
  - `If-None-Match: "v1"` → `304` with no body;
  - after a second publish, `"v1"` → `200` `v2`.

  Inject a `Map`-backed cache in place of `caches.default`.
- [X] T021 [P] [US1] Add to `tool/mutashabihat/editor_api.test.mjs`:
  - `PUT groups/{id}` with the right revision → saved and `status: changed`;
  - a stale revision → `409` carrying the current group and `updatedBy`;
  - an empty explanation → `422`;
  - `GET publish` lists the change with `updatedBy`;
  - `POST publish` with a matching `expect` → version 2 with `summary {changed:1}`;
  - a mismatched `expect` → `409 draftChanged`;
  - nothing to publish → `400`;
  - a group failing the checks blocks the publish with `422` and leaves `versions` unchanged.
- [X] T022 [P] [US1] Create `test/unit/mutashabihat_updater_test.dart`, using a fake
  `http.Client`, `MemoryFileStore` from `test/support/memory_file_store.dart` and a fixed clock:
  - `304` → keeps the content and stores `checkedAt`;
  - a valid `200` → saves `content.md` and `meta.json` and calls `replaceSimilar` with the new
    version;
  - a wrong SHA-256, format 2, a version ≤ current, or a parse error → keeps the content and
    writes no file;
  - a check within 6 hours → no request;
  - a network error → `checkedAt` unchanged;
  - the request carries `If-None-Match` and no other identifying header.
- [X] T023 [P] [US1] Create `test/unit/mutashabihat_loader_test.dart`, using a fake
  `AssetBundle` and `MemoryFileStore`:
  - the downloaded v3 beats the bundled v0;
  - the bundled v5 beats the downloaded v3;
  - a tie → bundled;
  - a damaged download → bundled, and the file is deleted.

### Implementation for User Story 1

- [X] T024 [US1] Create `functions/api/mutashabihat.js`:
  - `onRequestGet({request, env})` → `serveContent(request, env, {cache: caches.default})`,
    implemented in `functions/_lib/editor-store.js` or a small `functions/_lib/content-api.js`;
  - the current version number is cached for 60 s, and the body under `mutashabihat:v{N}`
    ([contracts/content-api.md](./contracts/content-api.md) › Caching);
  - on any D1 error → `503` with `Retry-After: 600`.
- [X] T025 [US1] In `functions/_lib/editor-store.js` and `editor-api.js`, add:
  - `updateGroup(id, {ayat, note, explanation, revision}, email)`: uses `checkGroup`, bumps
    `revision`, sets `updated_by`/`updated_at`, and returns `409` with the current row on a
    revision mismatch;
  - `draftChanges()`;
  - `publish(expectIds, email)`:
    - recomputes the changes and refuses on a mismatch;
    - checks every live group;
    - renders all non-deleted groups in `rowid` order with the version `latest + 1`;
    - inserts the version with its `summary`;
    - purges deleted rows, all in one `batch`.

  Routes: `PUT groups/{id}`, `GET publish`, `POST publish`.
- [X] T026 [US1] In `web/editor/editor.js`, add:
  - **The list**: search over references, Arabic-Indic digits, surah names (from `quran.json`)
    and diacritic-free note and explanation text; the «غير المنشور فقط» filter; status chips.
  - **The group form**, for editing the note and explanation:
    - «حفظ» with `revision`;
    - the `409` conflict message and its two choices;
    - the `localStorage` unsaved copy under `mutashabihat-draft:{id}`, offered back and
      cleared on save.
  - **The Publish view**: the changes in three sections, the problems list, «نشر الآن» with
    `expect`, and the success message.
  - **The top bar**: «نشر (n)».
- [X] T027 [US1] Create `lib/features/mutashabihat/mutashabihat_updater.dart`, the class
  `MutashabihatUpdater`:
  - **Constructor**: `{required ReaderController reader, http.Client? client, FileStore? store,
    DateTime Function()? now, Uri? base}`.
  - **`Future<void> check()`**:
    - skip if a check is running or `meta.json.checkedAt` is within 6 h;
    - `GET {apiBase()}/api/mutashabihat` with `If-None-Match: "v{reader.similar.version}"`
      (omitted at 0) and a 10 s timeout;
    - handle each result as in [contracts/content-api.md](./contracts/content-api.md) › What
      the app does;
    - write `content.md.part`, then rename it and write `meta.json`;
    - then `reader.replaceSimilar(parsed)`.
  - **Logging**: errors go to `debugPrint` only.
- [X] T028 [US1] In `lib/features/mutashabihat/mutashabihat_loader.dart`, read the bundled
  asset and `support/mutashabihat/content.md` in parallel, and return the higher version (ties:
  bundled). On a parse error, delete the downloaded files.
- [X] T029 [US1] In `lib/main.dart`, create `MutashabihatUpdater(reader: controller)` and call
  `unawaited(updater.check())` in the existing post-frame callback and in the
  `AppLifecycleListener` `onResume`, next to the prayer refill. Add the comment
  `// Mutashabihat content updates (specs/011 R5)`.

**Checkpoint**: E1 passes. An explanation edited in the editor reaches installed apps without a
release.

---

## Phase 4: User Story 2 - Add, change and remove groups (Priority: P1)

**Goal**: create groups, change their ayat, delete and undelete, with ayah text previews (FR-004
to FR-007).

**Independent Test**: [quickstart.md](./quickstart.md) E2.

### Tests for User Story 2

- [X] T030 [P] [US2] Add to `tool/mutashabihat/editor_api.test.mjs`:
  - `POST groups` valid → `201 added`;
  - `2:300` → `422 noSuchAyah` naming 2:300;
  - one ayah → `422 tooFewAyat`;
  - a note with a line break → `422`;
  - `DELETE` → `removed` and listed in `GET publish`;
  - `undelete` → back to `published`;
  - deleting an `added` group → `discarded`, hidden from `GET groups` and purged at publish;
  - a publish renders the new group and drops the removed one.

### Implementation for User Story 2

- [X] T031 [US2] In `functions/_lib/editor-store.js` and `editor-api.js`, add
  `createGroup`, `deleteGroup(id, revision)` and `undeleteGroup(id, revision)`, and the routes
  `POST groups`, `DELETE groups/{id}` and `POST groups/{id}/undelete`.
- [X] T032 [US2] In `web/editor/editor.js`, extend the group form:
  - **Ayah chips** with remove buttons, and the «إضافة آية» field accepting `2:35` or `٢:٣٥`.
  - **The ayah text** from `quran.json` (loaded once, lazily) under each chip.
  - **An inline error** for a missing ayah, «لا توجد آية ٢:٣٠٠ (سورة البقرة ٢٨٦ آية)».
  - **Links** to other groups that contain the same ayah.
  - **Buttons**: «جديد» (`#new`), «حذف» and «تراجع عن الحذف».

**Checkpoint**: E2 passes.

---

## Phase 5: User Story 3 - Share the work with editors (Priority: P2)

**Goal**: the owner adds and removes editors, who edit and publish with the same rights. Removal
takes effect on the editor's next request (FR-001, FR-002, FR-002a).

**Independent Test**: [quickstart.md](./quickstart.md) E3.

### Tests for User Story 3

- [X] T033 [P] [US3] Add to `tool/mutashabihat/editor_api.test.mjs`:
  - the owner `POST editors` → `201`;
  - a bad email → `422`;
  - a duplicate → `409`;
  - the new editor can `PUT` and `POST publish`, and the version's `publishedBy` is their email;
  - the editor's `GET editors` → `403`;
  - the owner `DELETE editors/{email}` → the editor's next request → `403 notAnEditor`;
  - the owner's own email can't be added.

### Implementation for User Story 3

- [X] T034 [US3] In `functions/_lib/editor-store.js` and `editor-api.js`, add `listEditors`,
  `addEditor` and `removeEditor`, and the owner-only routes `GET`/`POST editors` and
  `DELETE editors/{email}`. Emails are lower-cased and checked with a simple
  `^[^\s@]+@[^\s@]+\.[^\s@]+$` test.
- [X] T035 [US3] In `web/editor/editor.js`, add:
  - the «المحررون» view (owner only): the list with «إزالة», the add field, and the note;
  - «آخر تعديل: {email}» on the group form and in the Publish list.

**Checkpoint**: E3 passes, including the `curl` checks.

---

## Phase 6: User Story 4 - Undo a bad publish (Priority: P2)

**Goal**: a history of versions, and restoring any one as a new publish (FR-011).

**Independent Test**: [quickstart.md](./quickstart.md) E4.

### Tests for User Story 4

- [X] T036 [P] [US4] Add to `tool/mutashabihat/editor_api.test.mjs`:
  - `GET versions` newest first, without `content`;
  - `GET versions/1` with its groups;
  - restoring v1 after v2 → v3 with `restoredFrom: 1`, groups equal to v1's, and the content
    endpoint serving v3;
  - restoring with an unpublished change and `discardDraft: false` → `409 draftNotEmpty`;
  - with `true` → restored, and the change is gone.

### Implementation for User Story 4

- [X] T037 [US4] In `functions/_lib/editor-store.js` and `editor-api.js`, add `listVersions`,
  `getVersion` and `restore(n, discardDraft, email)`:
  - in one batch, replace `groups` with the version's groups (keeping their ids, `revision` + 1);
  - write a new version with `restored_from`.

  Routes: `GET versions`, `GET versions/{n}`, `POST versions/{n}/restore`.
- [X] T038 [US4] In `web/editor/editor.js`, add the «السجل» view:
  - versions with their number, date and time, who published and the counts, and «مستعاد من
    الإصدار n»;
  - opening a version shows its groups, read only;
  - «استعادة هذا الإصدار» with the two confirmation texts of
    [contracts/editor-ui.md](./contracts/editor-ui.md).

**Checkpoint**: E4 passes.

---

## Phase 7: User Story 5 - Releases carry the latest content (Priority: P2)

**Goal**: every app and web release bundles the latest published version, or stops (FR-018).

**Independent Test**: [quickstart.md](./quickstart.md) E5.

- [X] T039 [US5] Create `tool/pull_mutashabihat.dart`:
  - `GET https://get.mthani.app/api/mutashabihat` (or `--base <url>`) with `dart:io`
    `HttpClient`;
  - check the format, SHA-256 and `parseMutashabihat` with no errors;
  - write `assets/mutashabihat/mutashabihat.md`;
  - print `mutashabihat.md: vN, G groups`;
  - exit 1 with a clear message on any failure, leaving the file unchanged.

  Add it to `tool/README.md`.
- [X] T040 [US5] In `tool/web_deploy.mjs` `prepare()`, after the content check:
  - read the version line of `build/web/assets/assets/mutashabihat/mutashabihat.md`;
  - fetch the published version (`GET /api/mutashabihat`, reading only `X-Content-Version`);
  - `fail('bundled content vN is older than published vM: run dart run
    tool/pull_mutashabihat.dart and build again')` if the bundle is older;
  - `fail('cannot reach the published Mutashabihat content')` on a network error;
  - treat `404 notPublished` (before the first import) as v0.
- [X] T041 [P] [US5] In `.github/workflows/ios-release.yml`, add a step "Pull published
  Mutashabihat content" (`dart run tool/pull_mutashabihat.dart`) before "Check Mutashabihat
  content".
- [X] T042 [P] [US5] In `.github/workflows/ci.yml`, add `- run: node --test tool/mutashabihat/`
  after the Flutter tests (`actions/setup-node@v4` with Node 24 if the runner's Node is older
  than 22.5).
- [X] T043 [P] [US5] In `docs/release.md`:
  - Release builds: `dart run tool/pull_mutashabihat.dart`, then commit
    `chore(content): mutashabihat vN` before `flutter build`;
  - Release checklist: replace the "only the owner's real groups" item with "content pulled from
    the editor (vN recorded in the release log)";
  - a new "Mutashabihat editor" section: the D1 database, the Access application, the vars,
    adding editors, and rollback through «السجل».

**Checkpoint**: E5 passes.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T044 Run `flutter analyze`, `flutter test --exclude-tags golden,web`, the golden test and
  `node --test tool/mutashabihat/*.test.mjs`. All must pass.
- [X] T045 In `specs/010-mutashabihat/contracts/content-file.md`, note the `<!-- version: N -->`
  preamble line and that the editor (specs/011) now produces the file.
- [ ] T046 Create the D1 database and apply the schema with wrangler (quickstart › Setup 1–3),
  and put the real `database_id` in `wrangler.toml`. This creates a Cloudflare resource:
  confirm with the owner first.
- [ ] T047 Owner: create the Access application (quickstart › Setup 4) and give
  `ACCESS_TEAM_DOMAIN` and `ACCESS_AUD`, to put in `wrangler.toml`.
- [ ] T048 Deploy the web app (a production deploy: the owner runs it or approves it), sign in
  and import (quickstart › Setup 5), then run E1–E6 and record them in
  `specs/011-mutashabihat-online-editor/validation/checks.md`.

---

## Dependencies & Execution Order

- **Setup (T001–T006)**: none.
- **Foundational (T007–T019)**: needs Setup. Blocks all stories. Within it:
  - T007 before T008, T011 and T017;
  - T009 before T010 and T012;
  - T011 before T012, and T012 before T013;
  - T014 before T017;
  - T016 after T014.
- **US1 (T020–T029)**: needs Foundational. T024 and T025 before T026. T027 needs T014–T016.
  T028 needs T014. T029 needs T027.
- **US2 (T030–T032)**: needs US1's T025 (store patterns) and T026 (the form).
- **US3 (T033–T035)** and **US4 (T036–T038)**: need Foundational and US1's publish (T025). They
  are independent of each other.
- **US5 (T039–T043)**: needs T014 and US1's T024 (the endpoint).
- **Polish**: T046 and T047 can happen any time. T048 needs everything else.

### Parallel Opportunities

- Setup: T003, T004, T005 and T006 together.
- Foundational: T008, T010, T014, T015 and T019 alongside the server modules.
- After Foundational:
  - the app side of US1 (T022, T023, T027–T029) runs alongside its server and editor side
    (T020, T021, T024–T026);
  - US3, US4 and US5 can proceed in parallel once T025 is done.

---

## Implementation Strategy

### MVP (US1)

1. Setup and Foundational.
2. US1: edit an explanation, publish, and apps update.
3. Set up Cloudflare (T046–T047), deploy, import, and validate E1.

### Then

- US2: groups editing.
- US3: editors.
- US4: restore.
- US5: releases.
- Polish.

Each story is shippable on its own after US1.

---

## Notes

- **Git**: commit after each phase. No AI attribution lines in commits (project rule).
- **Cloudflare resources**: creating them (T046), the Access application (T047) and production
  deploys (T048) are owner-approved steps.
