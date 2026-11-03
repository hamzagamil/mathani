# Implementation Plan: Online Mutashabihat Editor

**Branch**: `011-mutashabihat-online-editor` (feature ID; the work starts from `010-mutashabihat`,
merged to `main` at `4eecd08`) | **Date**: 2026-11-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/011-mutashabihat-online-editor/spec.md`, with the
clarifications of 2026-11-03 (editors with equal rights; shared draft, then Publish).

## Summary

- **Editor**: a private page at `get.mthani.app/editor/`, on the same Cloudflare Pages project as
  the web app, lets the owner and the editors they add manage the Mutashabihat groups.
  - Cloudflare Access handles sign-in with an emailed one-time code.
  - The server functions check every request against the owner's email and the editor list in a
    new D1 database.
- **Publishing**: changes collect in one shared draft. Publish checks every group with the
  specs/010 rules and writes a new numbered version, and any earlier version can be restored.
- **Apps**: the iOS, Android and web apps fetch `/api/mutashabihat` after the first frame and on
  resume, at most every 6 hours, using `ETag`/`304`. They check what arrives, keep it on the
  device, and swap it in without a restart.
- **Releases**: they bundle the latest published version, pulled by a tool, and the web deploy
  refuses an older bundle.

Details: [research.md](./research.md).

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned) for the apps and tools. JavaScript
(ES modules) for Cloudflare Pages Functions, Node 24 for their tests. Plain HTML, CSS and
JavaScript for the editor page.

**Primary Dependencies**:
- **App**: no new packages. It reuses `http`, `FileStore`, `rootBundle` and the specs/010 parser.
- **Functions**: no npm packages. They use Web Crypto for token checks and the D1 binding.
- **Editor**: no libraries.
- **New platform services**: Cloudflare D1 and Cloudflare Access, both on free plans
  (Complexity Tracking).

**Storage**:
- **Server**: D1 `mthani-mutashabihat` with tables `groups`, `versions` and `editors`
  ([data-model.md](./data-model.md)).
- **Device**: `FileStore` support root, `mutashabihat/content.md` and `meta.json`.

**Testing**:
- **Server**: `node --test tool/mutashabihat/*.test.mjs`, with D1 stood in for by `node:sqlite` and Access
  tokens signed in the test.
- **App**: `flutter_test` for the updater, the startup choice and the live swap.
- **Cross-check**: the Dart and JavaScript parsers on the same fixture.
- **Manual**: [quickstart.md](./quickstart.md) E1–E6 on the reference phones and a browser.

**Target Platform**:
- **Apps**: iOS 15.0+, Android 7.0 (API 24)+, and the browsers of specs/008.
- **Editor**: current desktop and phone browsers.
- **Server**: Cloudflare Pages Functions.

**Project Type**: Existing Flutter app with a web build, plus existing Pages Functions, gaining a
small web tool.

**Performance Goals**:
- No change to cold start (≤ 2 s on Galaxy A15 and iPhone SE 2nd gen).
- An unchanged check is a `304` under 1 KB. A full download is under 200 KB compressed.
- Swapping content relayouts only the visible page.

**Constraints**:
- No personal data in content requests.
- A damaged, partial or unsupported download is never used.
- Releases must carry the latest published content, or fail loudly.
- The editor works under the site's existing Content Security Policy.

**Scale/Scope**:
- About 100 groups now and up to about 1,000 later, with a few editors.
- Up to tens of thousands of reader checks a day, within the free plans (research R6, R9).

## Constitution Check

Constitution 2.0.0. Checked before research and again after design.

| Principle | Result |
| --- | --- |
| **I. Platform parity** | **Pass.** One Dart updater serves iOS, Android and web. Only the address differs: the app's own origin on the web, `get.mthani.app` on phones. iOS 15.0 and Android API 24 are stated. No permission is needed. |
| **II. Mobile-first** | **Pass, with a note.** The reader experience doesn't change. The editor is a tool for the owner and editors, not part of the reader app. It is built to work at phone width first (FR-003; contracts/editor-ui.md › Layout), with 44 px targets and keyboard and screen-reader support. A wider two-column view is an addition for laptops. |
| **III. Performance** | **Pass by design.** The update check runs after the first frame and at most every 6 hours, off the UI thread's critical path. Startup reads the bundled and downloaded copies in parallel with the databases (specs/010 R3). A swap relayouts one page. Measured in quickstart E6. |
| **IV. Lean** | **Pass.** No new app, function or editor dependencies. The app grows by about 10 KB of code. The editor's `quran.json` is a web-deploy file only, not in the store packages. |
| **V. Simplicity** | **Pass with justified additions** (Complexity Tracking): a D1 database, an Access application and the editor page. One content format serves every path (research R3). The prayer service's base-address rule moves into one helper, so there is one way to address the server. |
| **Platform and store** | **Pass.** No secrets in the app. Server settings are not secrets, because token checks use Access's public keys. The apps send no personal data (FR-017), and they already contact `get.mthani.app`, so the App Privacy and Data safety answers are unchanged. HTTPS only. |
| **Workflow** | **Pass.** specify → clarify → plan → tasks → implement. Before merge: quickstart E1–E6 on iPhone and Android, the performance check E6, and the size check. |

**Gate result**: passes before and after design. No unresolved clarifications. One external
dependency: the owner creates the Access application (quickstart › Setup 4). It blocks testing
the editor end to end, not the code.

## Project Structure

### Documentation (this feature)

```text
specs/011-mutashabihat-online-editor/
├── plan.md              # This file
├── research.md          # R1–R10
├── data-model.md        # D1 tables, rendered content, device files, updater states
├── quickstart.md        # Setup, then validation E1–E6
├── contracts/
│   ├── content-api.md   # GET /api/mutashabihat
│   ├── editor-api.md    # /api/editor/*
│   └── editor-ui.md     # the editor page
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
functions/
├── _lib/
│   ├── access.js                    # NEW: verify the Access token, get the email
│   ├── mutashabihat-content.js      # NEW: parse, check, render (the JS port of the Dart parser)
│   ├── mutashabihat-schema.sql      # NEW: D1 tables
│   ├── editor-store.js              # NEW: D1 queries: groups, versions, editors, publish, restore
│   └── editor-api.js                # NEW: dispatch for /api/editor/*
└── api/
    ├── mutashabihat.js              # NEW: GET /api/mutashabihat (public, cached)
    └── editor/[[path]].js           # NEW: /api/editor/* → editor-api.js

web/
├── editor/                          # NEW: index.html, editor.js, editor.css
├── _routes.json                     # add /api/mutashabihat and /api/editor/*
├── _headers                         # /editor/* and /api/* no-cache
└── sw.js                            # leave /api/ and /editor/ to the network

wrangler.toml                        # D1 binding; OWNER_EMAIL, ACCESS_TEAM_DOMAIN, ACCESS_AUD

lib/
├── platform/api_base.dart           # NEW: the server address (moved from prayer_location.dart)
├── platform/prayer_location.dart    # uses api_base.dart
├── main.dart                        # start the updater after the first frame and on resume
├── shared/reader_state.dart         # replaceSimilar()
└── features/mutashabihat/
    ├── mutashabihat_content.dart    # Mutashabihat.version from «<!-- version: N -->»
    ├── mutashabihat_loader.dart     # bundled vs downloaded: the higher version
    └── mutashabihat_updater.dart    # NEW: check, download, verify, save, apply

tool/
├── pull_mutashabihat.dart           # NEW: release snapshot of the published content
├── build_editor_quran.dart          # NEW: build/web/editor/quran.json from quran.db
├── web_deploy.mjs                   # build quran.json; refuse a bundle older than published
└── mutashabihat/                    # NEW: node --test suites for the functions

test/
├── unit/mutashabihat_updater_test.dart     # NEW
├── unit/mutashabihat_loader_test.dart      # NEW: version choice
├── unit/mutashabihat_parsers_agree_test.dart  # NEW: Dart side of the cross-check
└── widget/similar_live_swap_test.dart      # NEW: the page recolours after replaceSimilar

.github/workflows/ios-release.yml    # pull the published content before the build
.github/workflows/ci.yml             # node --test tool/mutashabihat/
docs/release.md                      # pull and commit the snapshot before releases; editor setup
```

**Structure Decision**:
- **Server code** follows the prayer location functions: thin `functions/api/*` entry points,
  logic in `functions/_lib/` so the tests can import it, and tests under `tool/`.
- **The editor** lives in `web/editor/`, so `flutter build web` carries it into `build/web` and
  the existing deploy publishes it.
- **App changes** stay in `lib/features/mutashabihat/`, apart from the shared address helper and
  `replaceSimilar`.

## Complexity Tracking

| Addition | Why needed | Simpler alternative rejected because |
| --- | --- | --- |
| Cloudflare D1 database | Shared drafts, revisions for conflicts, version history and the editor list need queries and atomic publishes (FR-009 to FR-011, FR-002a). | KV or R2: no transactions or queries, so the same logic would be built by hand on files. A Git-backed store: a GitHub token on the server, and a rebuild per publish. |
| Cloudflare Access application | Email sign-in for several people without storing passwords or sending email ourselves (FR-001, FR-002). | A password in the editor: hashing, reset and lockout to build and run. Own email codes: no sending service in the account. |
| Editor web page (`web/editor/`) | The owner and editors need a place to edit (Stories 1–4). | Editing in the Flutter app: it would ship editor code to every reader, against Principle IV. |
| App updater | Readers get changes without a store release (Story 1). | None: this is the feature. |
