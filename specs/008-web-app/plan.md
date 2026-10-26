# Implementation Plan: Mathani on the Web

**Branch**: `008-web-app` | **Date**: 2026-10-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/008-web-app/spec.md`

## Summary

The same Flutter app, built for the web and served at get.mthani.app from its own Netlify
site, with every 1.5.0 feature.

1. **One codebase, small seams** (research R3). `lib/main.dart` stays the only entry point, and
   `tool/web_preview.dart` is deleted. Six seams under `lib/platform/` get an `io` and a `web`
   implementation, chosen by a conditional import:
   - databases;
   - gunzip;
   - a `FileStore` for recordings and the model;
   - device facts;
   - the speech engine host;
   - sharing.

   Web-only packages are imported only from `*_web.dart` files, so the phone builds do not change.
2. **Reading** (R1, R4, R12, R13).
   - **Build**: `flutter build web --wasm`. The WebAssembly build (skwasm) runs where the browser
     supports it, and the JavaScript build (CanvasKit) everywhere else. The engine is
     self-hosted.
   - **Quran database**: served gzipped (2.8 MB) and written into the browser's SQLite store
     only when its version changes.
   - **Wide windows**: a centred 480 px phone column.
   - **Input**: browser Back, arrow keys, Escape and right-click map onto existing actions.
3. **Recitations** (R7, R8). Recordings and downloads go into the browser's private file system
   (OPFS) under the same rules (size match, `.part` resume, cache trim) and play from `blob:`
   URLs. Media keys and browser controls go through `audio_service`'s web implementation.
   All four recitation hosts allow browser requests (checked).
4. **Memorization** (R10, R11).
   - **Engine**: sherpa-onnx 1.13.8, the phones' version, compiled to WebAssembly and run in a
     Web Worker.
   - **Live-follow logic**: today's isolate worker becomes an engine-agnostic `LiveFollower`,
     shared by the isolate and by a `dart compile js` worker, so live reveal behaves the same
     everywhere.
   - **Model**: mirrored to Hugging Face, because GitHub release files cannot be read by a
     browser (checked).
   - **Microphone**: through `record`'s web implementation.
5. **Offline, install, updates** (R9, R14). A hand-written service worker precaches the app
   shell per build, caches page fonts as they are read, and updates on the next visit. A
   manifest makes the app installable. An inline feature check shows a bilingual "unsupported
   browser" page.
6. **Hosting** (R5, R6, R15).
   - The new Netlify site is in a **separate Netlify team**. The free plan's credits pause every
     site in a team when they run out, and mthani.app/privacypolicy is a store URL that must
     stay up.
   - Full deploys run through `tool/web_deploy.mjs`, and rollback is through Netlify's deploy
     history.
   - Before the announcement: the privacy policy, the landing link and the D1–D4 permission
     drafts are updated to cover the web.

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned). The JavaScript in `web/` is
hand-written (`sw.js`, the inline support check, the worker bootstrap). Node 20+ runs
`tool/web_deploy.mjs`. Emscripten builds sherpa-onnx's WebAssembly, for maintainers only.

**Primary Dependencies**:
- **Moved from dev to main**: `sqflite_common_ffi_web` and `sqlite3`, already used by the
  preview.
- **New direct dependencies**: `web` and `http` 1.6.0, both already transitive (`http` replaces
  `dart:io` `HttpClient` in the fetcher, research R18a).
- **Built and committed**: sherpa-onnx 1.13.8 WebAssembly.
- **Already present with web implementations**: `just_audio_web`, `audio_service_web`,
  `record_web`, `url_launcher_web`, `share_plus`, `wakelock_plus`.

No new third-party package.

**Storage**:
- `quran.db` and `user.db`: SQLite in IndexedDB through sqflite's shared worker.
- Recordings and the model: OPFS, behind `FileStore`.
- The app shell and page fonts: Cache Storage, through the service worker.

Layout and rules are in [data-model.md](./data-model.md). Nothing is stored on a server.

**Testing**: as in research R18:
- VM tests (`flutter test`) for shared logic, with an in-memory `FileStore`;
- `flutter test --platform chrome --tags web` for the web seams;
- `flutter drive -d web-server` for the app flow in Chrome;
- a manual browser matrix and spikes S1–S3 ([quickstart.md](./quickstart.md));
- the phone regression and size check.

**Target Platform**:
- **Web**: the current and previous major versions of Chrome, Edge, Firefox and Safari, on
  desktop and phones (FR-003). The gate is feature detection (R14).
- **Phones**: unchanged at iOS 15.0+ and Android 7.0 (API 24)+, target API 36.
- **Memorization in the browser**: needs WebAssembly SIMD, AudioWorklet, OPFS and ≥ 4 GB of
  device memory where reported (R10).

**Project Type**: mobile app (Flutter) that also ships to the web. One codebase, no backend.

**Performance Goals**:
- First visit ≤ 5 s to a readable page; return visit ≤ 2 s (SC-001, SC-002).
- 60 fps paging and scrolling (SC-003), with tap feedback ≤ 100 ms (constitution III).
- No recognition work on the UI thread.

These are measured on the research R17 reference devices at 20 Mbit/s.

**Constraints**:
- No cross-origin isolation (R2).
- No third-party hosts beyond the content sources: CSP `connect-src` lists them all (FR-027).
- Phone store sizes grow < 1 MB (constitution IV).
- Netlify's free plan is about 15–30 GB a month (R5).
- The KFGQPC page fonts are served only from the app's own site (R6).

**Scale/Scope**:
- About 15 files changed in `lib/`.
- 6 seam pairs added in `lib/platform/`.
- `LiveFollower` extracted from the speech isolate.
- `web/` gains `sw.js`, `_headers`, `speech/` and the support check.
- Two tools: `web_deploy.mjs` and `build_sherpa_wasm.sh`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

The constitution (2.0.0) was written for an iOS and Android app. It does not forbid a web build,
but Principle II says "there is no desktop or web layout to fall back on". Each principle is
checked below for the phones (which must not regress) and for the web (which adopts the same
rules where they apply).

| Principle | Requirement | Pre-design | Post-design |
|-----------|-------------|------------|-------------|
| I. Cross-Platform Parity | Features work on iOS and Android; minimum OS stated | ✅ Phones unchanged; minimum OS stated above. The web is additive and follows the same parity rule: every feature or a documented exception (SC-004). | ✅ Seams keep one behaviour. Refactors (`FileStore`, `LiveFollower`) are verified on both phones (quickstart V18). |
| II. Mobile-First Design | Phone portrait first; touch targets; safe areas; font scaling, dark mode, screen readers; mobile navigation | ✅ The web shows **the phone layout** (FR-012). There is no desktop layout; a wide layout is a separate later feature. | ✅ Keys and right-click are extra ways into existing actions, not hover menus or sidebars (R12). Browser zoom stands in for font scaling (V13). Screen readers are checked (V14). |
| III. Performance (NON-NEGOTIABLE) | ≤ 2 s cold start, 60 fps, ≤ 100 ms feedback, cached content, virtualised lists | ⚠️ A first web visit must download the app, so its budget is 5 s (SC-001). See Complexity Tracking. | ✅ The return visit has the 2 s budget (SC-002). Nothing is fetched at start-up when cached (R9). The database is written only on a version change (R4). Recognition runs in a worker (R10). S1 measures it all. Phones are unchanged. |
| IV. Lean by Default | Justified dependencies; size growth > 1 MB called out; on-demand large content; minimal background work | ✅ No new third-party package. Web-only code stays out of phone builds (conditional imports, size check V18). | ✅ Page fonts, the speech engine and the model load only when needed. The service worker does nothing in the background beyond caching what the reader opened. sherpa-onnx WebAssembly is committed build output, justified in R10. |
| V. Simplicity | Simplest thing; one way; justified complexity | ⚠️ New seams and a worker. See Complexity Tracking. | ✅ Each seam is the smallest that removes `dart:io` from shared code. `LiveFollower` *removes* a would-be duplicate. No router migration, no Workbox, no web-only feature paths. |
| Platform & Store | Privacy disclosures; permissions in context; secure storage | ✅ Store builds unchanged. | ✅ Microphone only at session start (FR-023). Persistent storage asked on the first bookmark or download (R7). The privacy policy is updated before the announcement (R15). No secrets in the web build. |
| Workflow & Quality Gates | Verified on iOS and Android; performance and size checks | ✅ | ✅ V18 runs on both phones. S1 and the size check cover performance and size. The browser matrix is added. |

**Result**: passes, with the two justified deviations below.

**Recommended follow-up** (not a blocker): a MINOR amendment through `/speckit-constitution`.
It would add the web as a supported platform, state its budgets (first visit 5 s, return visit
2 s) and its reference devices (R17), and reword Principle II's "no desktop or web layout" to
"no desktop layout". Future web features would then be checked against written rules rather
than against this plan.

## Project Structure

### Documentation (this feature)

```text
specs/008-web-app/
├── plan.md              # This file
├── research.md          # Phase 0: R1–R18
├── data-model.md        # Phase 1: browser data, states, supported browsers
├── quickstart.md        # Phase 1: run, spikes S1–S3, validation V1–V18
├── contracts/
│   ├── web-platform.md  # FileStore, DeviceFacts, speech worker, platform seams
│   └── hosting.md       # Sites, deploy, headers, CSP, manifest, landing changes
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/
├── main.dart                         # calls initDatabases(); no kIsWeb branches left
├── app/app.dart                      # centred phone column on wide windows (R13); context menu off over the Mushaf
├── platform/                         # NEW: seams, one interface + _io / _web per file (contracts/web-platform.md)
│   ├── database.dart, database_io.dart, database_web.dart
│   ├── gunzip.dart, gunzip_io.dart, gunzip_web.dart
│   ├── file_store.dart, file_store_io.dart, file_store_web.dart
│   ├── device.dart, device_io.dart, device_web.dart        # DeviceChannel moves here
│   ├── speech_host.dart, speech_host_io.dart, speech_host_web.dart
│   ├── share.dart, share_io.dart, share_web.dart
│   └── supported_browsers.dart
├── data/quran_repository.dart        # opener through platform/database
├── features/
│   ├── reader/printed_fonts.dart     # gunzip through platform/gunzip
│   ├── reader/reader_screen.dart     # keyboard shortcuts, secondary tap = long press (R12)
│   ├── recitation/ayah_fetcher.dart, download_queue.dart, downloads_screen.dart,
│   │   recitation_controller.dart, audio_engine.dart, media_handler.dart   # FileStore, playableUri, artwork URL
│   ├── memorization/
│   │   ├── live_follower.dart        # NEW: _Worker logic over SpeechEngine (shared)
│   │   ├── speech_recogniser.dart    # isolate host + FFI SpeechEngine
│   │   ├── web_worker_main.dart      # NEW: worker entry (dart compile js), JS-interop SpeechEngine
│   │   ├── asr_model.dart            # FileStore; web delegates download/verify to the worker; base URL by platform
│   │   ├── mic_source.dart           # web: no audio session, DSP off (R11)
│   │   ├── device_support.dart       # Unsupported.browser
│   │   └── mic_explainer.dart        # browser instructions when denied
│   └── settings/about_section.dart   # "kept only in this browser" (FR-015)
└── shared/device_channel.dart        # removed (moved to platform/device_io.dart)

web/
├── index.html                        # title, lang/dir, support check, SW registration (contracts/hosting.md)
├── manifest.json                     # name, icons, standalone
├── sw.js                             # NEW: service worker (R9)
├── _headers                          # NEW: caching, CSP, security headers
├── sqflite_sw.js, sqlite3.wasm       # from sqflite_common_ffi_web:setup
└── speech/                           # NEW: sherpa-onnx 1.13.8 WebAssembly + worker bootstrap

tool/
├── web_deploy.mjs                    # NEW: prepare build/web, deploy, rollback, bandwidth report
├── build_sherpa_wasm.sh              # NEW: maintainer build of web/speech/
└── web_preview.dart                  # REMOVED

test/
├── support/memory_file_store.dart    # NEW
├── unit/…                            # fetcher/queue/model tests onto FileStore; live_follower_test.dart
└── web/                              # NEW, tagged web: file_store_web_test, database_web_test, gunzip_web_test

docs/release.md                       # web release + rollback section
docs/permissions/*.md                 # D1–D4 drafts widened to the web
```

**Structure Decision**: a single Flutter project, with the web as one more build target. The new
code sits in `lib/platform/`, the only directory with platform-specific imports, plus `web/` for
files the browser loads directly. There is no backend.

## Phases after this plan

`/speckit-tasks` should order the work so each user story ships on its own:

1. **Foundation**: the seams and refactors with no behaviour change, verified on the phones (V18).
2. **S1**, then **US1 Reading**: database, layout, input, unsupported page, hosting, deploy.
3. **US2 Recitations**: OPFS `FileStore`, playback, media session.
4. **S2 and S3**, then **US3 Memorization**: `LiveFollower`, worker, WebAssembly build, model
   mirror, microphone.
5. **US4 Install and offline**: service worker, manifest, updates.
6. **Release**: privacy policy, landing link, permission drafts, `docs/release.md`, first
   production deploy.

S1 could be folded into US1, but US4's service worker is needed for SC-002's return-visit timing.
So US1 is measured once without it, as a baseline, and again after US4.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| First-visit budget of 5 s instead of the 2 s cold start (III) | A first web visit downloads about 7–8 MB that a store install has already put on the phone. Return visits keep the 2 s budget. | No budget, or "best effort": SC-001 makes it testable instead. Downloading less is not possible without dropping the Quran database or the engine. |
| Six platform seams and a `FileStore` interface (V) | Shared code uses `dart:io`, which does not exist in browsers. The seams are the smallest cut that keeps one behaviour. | `kIsWeb` branches in place: `dart:io` still has to compile for the web, and every file grows two code paths. A separate web codebase: two products. |
| A Web Worker compiled from Dart, plus sherpa-onnx WebAssembly committed under `web/speech/` (IV, V) | Recognition takes hundreds of milliseconds per pass and must not block the UI. Same engine and same live-follow code give the same results (SC-006). | onnxruntime-web: different decoding, so different results. Porting the live-follow logic to JavaScript: two copies of timing-sensitive code. UI-thread decoding: frozen pages. |
| A separate Netlify team and a Hugging Face mirror of the model (V) | Credit exhaustion pauses every site in a team, including the store-required privacy policy. GitHub release files cannot be fetched by browsers. | Same team: one bad month takes the privacy policy down. Model on Netlify: about 108 MB of credits per reader. |
