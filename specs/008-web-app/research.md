# Research: Mathani on the Web

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-26

Facts checked on 2026-10-26 are marked *(checked)*. Spikes S1–S3 are in [quickstart.md](./quickstart.md).

## Changes made during implementation (2026-10-26)

These replace the decisions below where they differ. Evidence:
[validation.md](./validation.md), [s2-results.md](./s2-results.md).

| # | Decision | Plan | Implemented | Why |
|---|----------|------|-------------|-----|
| 1 | Recognition engine (R10) | Build sherpa-onnx 1.13.8 with Emscripten (`tool/build_sherpa_wasm.sh`) | No build | `sherpa_onnx` 1.13.8 already ships its WebAssembly build (`sherpa_onnx_web`, web-only assets, single-threaded, omnilingual included). `web/speech/speech_worker.js` loads it with `importScripts`: the package's loader uses `eval`, which the CSP forbids. |
| 2 | Model download in browsers (R10) | The worker downloads and verifies | `AsrModel` on the page does it, as on phones, through `FileStore` and `package:http` | One download path. Only the unpack differs by platform (`unpackModel` in `lib/platform/speech_host_*.dart`): an isolate on phones; on the web, `DecompressionStream` with chunked hashing, awaited per chunk. The worker reads the saved files. |
| 3 | `SpeechRecogniser` (R10) | — | The interface and constants stay in `speech_recogniser.dart`; the FFI isolate moves to `sherpa_recogniser.dart` | The browser worker compiles `speech_recogniser.dart` and `live_follower.dart`, so they cannot import FFI. |
| 4 | Database paths (R4) | `'$dir/quran.db'` | `databasePath()` | The browser's databases directory is `/`. Its file system treats every `//name` as `/`, so all files were one file. |
| 5 | Opening the databases (R4) | In parallel | One at a time in browsers (`parallelDatabaseOpen`) | One SQLite instance serves the page. |
| 6 | Shared worker (R4) | `dart run sqflite_common_ffi_web:setup` | `tool/web/sqflite_sw.dart`, compiled with `dart compile js` | The setup fails on Windows (webdev), and it would replace `sqlite3.wasm` with an older release. |
| 7 | Font fallback (R1) | Never fetched | Fetched from `font-fallback/` on our own site | The reader needs Noto Sans Arabic for a character the bundled fonts lack. It is mirrored unmodified (OFL). `flutter_bootstrap.js` passes the setting to `initializeEngine()`: with a custom `onEntrypointLoaded`, settings given only to `load()` are dropped. |
| 8 | Unsupported-browser check (R14) | Requires service workers | Does not | Firefox private windows have none; the app still works there, without offline use. |
| 9 | Service worker (R9) | Precache the whole shell | Precache the small shell; cache the app build and engine variant on use | A browser uses one of several engine builds (about 25 MB in all). The page reports what the first visit loaded, so offline still works after one visit. |
| 10 | Persistent storage (R7) | Ask on first bookmark or download, recording the answer in `user.db` | `DeviceChannel.keepBrowserData()`, once per page load | Browsers remember the answer themselves. |
| 11 | Browser memory (R10) | `deviceSupport()` returns different types per platform | `webSupport()`, which returns null on phones | One signature the analyzer can check. |
| 12 | Memorization on the web | On | Off until S2 on the reference devices (`speechEngineAvailable`) | Builds for the spikes use `--dart-define=MATHANI_WEB_MEMORIZATION=true`. |
| 14 | Host (R5) | Netlify | **Cloudflare Pages**, project `mthani-web`; get.mthani.app is a CNAME at Namecheap (owner decision) | Pages charges no bandwidth for static files, so the shared-credit pause risk of row 13 is gone. Classic Pages (`--force` once at creation) accepts a custom subdomain whose DNS is elsewhere; Workers custom domains need the zone on Cloudflare. `_headers` works unchanged, and Pages injects no script (Netlify's injected toolbar script broke the CSP). |
| 13 | Netlify team (R5) (superseded by row 14) | A separate team | The existing "Mathani" team, shared with mthani.app (owner decision) | Netlify refused a second Free team ("Account plan is unavailable to this user"). The pause risk stays, so bandwidth is watched (docs/release.md › Web). |

## What does not run in a browser today

The development preview ([tool/web_preview.dart](../../tool/web_preview.dart)) already starts the
app in Chrome. It swaps in a WebAssembly SQLite and a browser gunzip. What it cannot do:

| Area | Files | Why it breaks on the web |
|------|-------|--------------------------|
| Quran database | `lib/data/quran_repository.dart` | `dart:io` files; the preview rewrites 6.4 MB into the browser on every launch |
| Page fonts | `lib/features/reader/printed_fonts.dart` | `dart:io` `gzip` |
| Recordings, downloads | `ayah_fetcher.dart`, `download_queue.dart`, `recitation_controller.dart`, `audio_engine.dart`, `downloads_screen.dart` | `dart:io` `File`, `Directory` and `HttpClient`; `path_provider`; `AudioSource.file` |
| Lock-screen controls | `media_handler.dart` | writes artwork to a cache file |
| Memorization model | `asr_model.dart` | `dart:io`, `HttpClient`, `Isolate.run`; GitHub release files have no CORS (R6) |
| Recognition | `speech_recogniser.dart` | `sherpa_onnx` uses FFI, and there are no isolates on the web |
| Microphone | `mic_source.dart` | iOS/Android audio session settings (harmless on the web, but not configured for it) |
| Device facts | `lib/shared/device_channel.dart` | a platform channel that falls back to "unmetered, unlimited space, supported" |

---

## R1. Build target and renderer

- **Decision**: `flutter build web --wasm --release --no-web-resources-cdn`.
  - The loader uses the WebAssembly build (skwasm renderer) where the browser supports it, and
    the JavaScript build (CanvasKit) everywhere else.
  - The engine files are served from our own site, not from Google's CDN.
  - Font fallback must never fetch from fonts.gstatic.com. Every glyph the app draws is in a
    bundled font (PlexArabic, QuranText, the page fonts, Lucide). S1 checks the network log for
    requests to Google hosts.
- **Rationale**:
  - Self-hosting keeps FR-027 (no third parties beyond the content sources), lets the service
    worker cache the engine for offline use (FR-017), and keeps start-up independent of a CDN.
  - Both builds come from one command, so one deploy serves every browser.
- **Alternatives considered**:
  - JavaScript only (CanvasKit everywhere): simpler, but gives up skwasm's faster frames on
    Chromium. Kept as the fallback the loader already provides.
  - Flutter's HTML renderer: removed from Flutter.

## R2. No cross-origin isolation in this feature

- **Decision**: serve the app without `Cross-Origin-Opener-Policy` and
  `Cross-Origin-Embedder-Policy`. Rendering and recognition run single-threaded.
- **Rationale**:
  - Multi-threaded skwasm and multi-threaded WebAssembly need `SharedArrayBuffer`, which needs
    cross-origin isolation.
  - With `require-corp`, recordings from everyayah.com, quranicaudio.com and tarteel.ai stop
    loading. They send `Access-Control-Allow-Origin: *` but no `Cross-Origin-Resource-Policy`
    *(checked)*.
  - `credentialless` would avoid that, but Safari does not support it.
  - Single-threaded performance is measured in S1 (frames) and S2 (recognition). If a live pass
    is too slow, memorization already falls back to 006's pause-based reveal (007 FR-010).
- **Alternatives considered**: COEP `credentialless` on Chromium and Firefox only. That gives
  faster recognition there, but Safari behaves differently and there are two header sets to test.
  It stays a follow-up if S2 shows that live reveal fails on the reference laptop.

## R3. One entry point, platform seams by conditional import

- **Decision**:
  - `lib/main.dart` stays the only entry point. `tool/web_preview.dart` is deleted.
  - Each place that differs gets a small seam with an `io` and a `web` implementation, picked by
    a conditional import (`if (dart.library.js_interop)`) under `lib/platform/`:
    - the database factory and the Quran database opener;
    - gunzip;
    - the file store (R7);
    - device facts (R16);
    - the speech engine host (R10).
  - `sqflite_common_ffi_web` and `sqlite3` move from dev dependencies to dependencies, and the
    `web` package becomes a direct dependency. They are imported only from `lib/platform/*_web.dart`,
    so the phone builds tree-shake them away. The size check confirms this (constitution IV).
- **Rationale**: one codebase and one behaviour (spec Assumptions). Conditional imports keep web
  code out of the phone builds and `dart:io` out of the web build, with no runtime flags.
- **Alternatives considered**:
  - `kIsWeb` branches in place, as the preview does: `dart:io` imports still have to compile for
    the web, and every file grows two paths.
  - A separate web app: two products to maintain, which the spec rules out.

## R4. The Quran database in the browser

- **Decision**:
  - The bundled `quran.db` (6.4 MB) is written into the browser's SQLite store (IndexedDB, through
    `sqflite_common_ffi_web`) **only when `quran.version` changed**. That is the same rule as on
    phones; the installed version is kept next to it.
  - The web build serves it gzip-compressed (2.8 MB *(checked, gzip -9)*). The deploy step adds
    `quran.db.gz` and removes the uncompressed file. The web opener fetches the `.gz` and
    inflates it with the browser's `DecompressionStream`.
  - The database factory is the shared-worker variant (`databaseFactoryFfiWeb`), so two tabs
    write `user.db` through one worker. Where `SharedWorker` is missing (Chrome on Android), the
    package uses a dedicated worker.
  - `dart run sqflite_common_ffi_web:setup` adds `web/sqflite_sw.js` and `web/sqlite3.wasm`, both
    committed and both matching the locked `sqlite3` version.
- **Rationale**:
  - Rewriting 6.4 MB on every start would break the 2-second return visit (SC-002).
  - Netlify does not compress `application/octet-stream`, so gzipping saves about 3.6 MB on a
    first visit, roughly 1.5 s at 20 Mbit/s (SC-001).
  - The shared worker covers the two-tabs edge case: nothing lost, nothing duplicated.
- **Alternatives considered**:
  - Fetching rows from a server: there is no server, and the app would no longer work offline.
  - The no-worker factory the preview uses: two tabs would each write IndexedDB blocks for the
    same file.

## R5. Hosting on Netlify

- **Decision**:
  - A new Netlify site serves the web app at get.mthani.app.
  - The site belongs to its **own Netlify team**, not the team that hosts mthani.app.
  - Deploys are full deploys of `build/web` (after the R4 and R9 steps) by a new
    `tool/web_deploy.mjs`. It uses the same DPAPI-protected token as the landing deploy script.
  - Netlify keeps every deploy, so rollback is "publish the previous deploy" (FR-029).
  - Headers and redirects live in `web/_headers` and `web/_redirects`
    ([contracts/hosting.md](./contracts/hosting.md)).
- **Rationale**:
  - **Netlify's free plan is a monthly pool of 300 credits.** Bandwidth costs 10–20 credits per
    GB (sources disagree; check Netlify's pricing page), so the pool covers about 15–30 GB a month.
  - **When the pool runs out, Netlify pauses every site in the team** *(third-party sources,
    2026)*. If the web app shared a team with mthani.app, heavy use could take down
    `/privacypolicy`, the URL given to both stores.
  - A separate team caps the damage to the web app. Moving it to a paid plan later is a billing
    change, not a code change.
- **Alternatives considered**:
  - A path under mthani.app: ruled out in Clarifications, and it has the same pause risk.
  - Another host (Cloudflare Pages, GitHub Pages): the user chose Netlify.
- **Bandwidth estimate**:

  | What | Size |
  |------|------|
  | First visit | ≈ 7–8 MB (R1 build, R4 database, UI fonts, first page font) |
  | Return visit | near 0 (service worker cache, R9) |
  | Each newly read page | ≈ 0.1–0.3 MB |
  | Reading the whole Mushaf once | ≈ 130 MB |

  On 15 GB a month, that is roughly 2,000 first visits, or about 100 readers who finish a
  khatma. The deploy script prints the site's bandwidth use so the user can see it coming.

## R6. Where the heavy files come from

- **Page fonts** (604 files, 130 MB, gzip):
  - **Decision**: served from get.mthani.app as part of the app, fetched as each page is first
    shown and then cached.
  - **Rationale**: they are proprietary KFGQPC fonts (docs/licences.md D3). Serving them from the
    app itself matches how the phone app bundles them. A public mirror would make them a
    standalone download.
- **Recognition model** (107.5 MB gz, 133.3 MB unpacked):
  - **Decision**: served from a Hugging Face model repo, pinned to a commit, with the same files
    and SHA-256 sums as the GitHub release `asr-khatma-v1`. The phone app keeps the GitHub URL;
    only the base URL differs by platform.
  - **Rationale**:
    - GitHub release downloads redirect to `release-assets.githubusercontent.com` without
      `Access-Control-Allow-Origin`, so a browser cannot read them *(checked)*.
    - Hugging Face's `resolve/` URLs send `Access-Control-Allow-Origin` and honour `Range`, which
      the resumable download needs *(checked)*.
    - The model is CC BY 4.0 with an MIT export, so mirroring it is allowed. The credit stays in
      About.
    - Hosting it on Netlify would cost about 108 MB of the credit pool per reader.
  - **Alternatives considered**: Netlify (bandwidth), jsDelivr (file size limit), a new
    Cloudflare R2 bucket (a new account and service for one file set).
- **Recordings**: unchanged. everyayah.com, mirrors.quranicaudio.com, download.quranicaudio.com
  and audio-cdn.tarteel.ai all send `Access-Control-Allow-Origin: *` and honour `Range`
  *(checked)*, so the fetcher's ranged and resumable requests work from the browser. The spec's
  contingency for sources without CORS is not needed.

## R7. Storing files in the browser

- **Decision**:
  - Recordings (cache and downloads) and the recognition model live in the **Origin Private File
    System** (OPFS), behind a small `FileStore` interface ([contracts/web-platform.md](./contracts/web-platform.md)).
    On phones, `FileStore` wraps today's `dart:io` files in the same directories.
  - `ayah_fetcher.dart`, `download_queue.dart`, `asr_model.dart`, `recitation_controller.dart`
    and `downloads_screen.dart` use `FileStore` instead of `File` and `Directory`.
  - Free space is `navigator.storage.estimate()` quota minus usage.
  - `navigator.storage.persist()` is requested **in context**: on the first bookmark or the first
    download, not at start-up. Firefox shows a prompt for it, and the constitution asks for
    permissions only when needed.
- **Rationale**:
  - OPFS holds large binary files, supports writing in chunks (resume) and is in every supported
    browser.
  - A `File` from OPFS gives a `blob:` URL the audio element can play (R8).
  - One interface keeps the existing size, integrity, resume and trim rules (specs/004, 006)
    unchanged on both platforms.
- **Alternatives considered**:
  - Cache Storage: whole responses only, so no resuming a half-downloaded file.
  - IndexedDB blobs: slower for 100 MB files, and Safari has a history of blob bugs.
  - A web-only download path: two sets of rules for the same feature.

## R8. Playing recordings in the browser

- **Decision**:
  - The player keeps playing only files the fetcher has checked (specs/004 research R5).
  - On the web, `FileStore.playableUri` returns a `blob:` URL for the OPFS file, and the engine
    plays it with `AudioSource.uri` instead of `AudioSource.file`. URLs are revoked when the item
    leaves the playlist.
  - Lock-screen and media-key controls go through `audio_service`'s web implementation (the
    Media Session API), with artwork from a bundled image URL instead of a cache file.
  - The first play always comes from a tap, so autoplay rules never block it.
- **Rationale**: keeps "never skip an ayah" identical on every platform. `just_audio_web` and
  `audio_service_web` are already in the lockfile as transitive dependencies.
- **Alternatives considered**: streaming remote URLs straight into the audio element on the web.
  Simpler, but a size mismatch or a cut connection could then skip an ayah, which the phone app
  never does.
- **To verify in S1**:
  - Background-tab playback in each browser.
  - iOS Safari with the screen locked. Safari may pause an installed web app's audio; if so,
    that is recorded as a platform limit in the spec.

## R9. Offline use, installation and updates

- **Decision**:
  - **Service worker**: a hand-written `web/sw.js` (about 100 lines). Flutter's generated service
    worker is a deprecated no-op.
    - It precaches the app shell on install:
      - `index.html`, the bootstrap and both builds (JavaScript and WebAssembly);
      - the engine files;
      - `quran.db.gz` and `sqlite3.wasm`;
      - the UI fonts, `AssetManifest` and `FontManifest`.
    - Shell caches are named after the build (`shell-<version>-<build id>`).
    - Page fonts and other assets under `assets/` are cached cache-first at runtime and kept
      across versions while their names are unchanged. `tool/web_deploy.mjs` writes a manifest of
      their hashes; the new service worker drops entries whose hash changed.
    - Cross-origin requests (recordings, model) are not intercepted; they go to OPFS (R7).
  - **Updates**: a new service worker installs in the background and takes over on the next
    load. A returning reader gets the new version on that visit or the next one (FR-019), and
    `user.db`, OPFS and their contents are untouched.
  - **Installation**: `web/manifest.json` gets the Mathani name, icons, theme colour and
    `display: standalone` (FR-018). `index.html` gets the title, description, language and
    direction.
- **Rationale**: the precache list is exact, and nothing is fetched on start-up when cached
  (constitution III).
- **Alternatives considered**: Workbox. It is a dependency, and its build step does more than
  this needs (constitution IV, V).

## R10. Recognition in the browser

- **Decision**:
  - **The build**: sherpa-onnx **1.13.8**, the version the phones ship, compiled to WebAssembly
    with its own Emscripten scripts. The target is the `vad-asr` one, with SIMD, single-threaded,
    and with no model embedded.
    - `tool/build_sherpa_wasm.sh` builds it, for maintainers.
    - The output (`sherpa-onnx-wasm-main-vad-asr.{js,wasm}` and the JavaScript API files) is
      committed under `web/speech/` and is loaded only when a memorization session starts.
  - **Where it runs**: a dedicated Web Worker (`web/speech/speech_worker.js`), because a decode
    takes hundreds of milliseconds and the UI thread must never block (constitution III).
  - **Shared live-follow logic**: today's `_Worker` class (VAD windows, anchor, live and pause
    passes) becomes an engine-agnostic `LiveFollower` over a `SpeechEngine` interface with VAD and
    decode calls.
    - The phone isolate runs it with the FFI engine.
    - The web worker runs **the same Dart code** compiled with `dart compile js` from
      `lib/features/memorization/web_worker_main.dart`, with a JavaScript-interop engine.
  - **Messages**: the worker exchanges the same messages as the isolate, with `Float32Array`
    transfers ([contracts/web-platform.md](./contracts/web-platform.md) › Speech worker).
  - **Model loading**: the worker downloads, unpacks (`DecompressionStream`), verifies
    (chunked SHA-256 with `package:crypto`) and stores the model in OPFS. That keeps 133 MB of
    hashing off the UI thread. It then loads the model into the Emscripten file system
    (`WORKERFS` over the OPFS `File`, so there is no extra copy) and creates the VAD and the
    recogniser with the same settings as the phones.
- **Rationale**: same model, same VAD settings, same CTC decoding and the same matcher, so the
  same recitation gives the same words (FR-022, SC-006). One live-follow implementation keeps
  live reveal behaving the same everywhere.
- **Alternatives considered**:
  - onnxruntime-web, which has WebGPU: a different decoder and different VAD glue, so results
    could differ from the phones. Kept as a later option if S2 is too slow.
  - Porting `_Worker` to JavaScript: two copies of subtle timing logic.
  - Decoding on the UI thread: freezes the page.
- **Gate** (replaces the phones' arm64 / 3 GB check on the web): memorization is offered when
  the browser has
  - WebAssembly SIMD;
  - `AudioWorklet`;
  - OPFS;
  - a `navigator.deviceMemory` of at least 4 GB where the browser reports it (Chromium only).

  A model load that fails for memory is caught and reported as "not available in this browser"
  (FR-026). S2 sets the final gate.

## R11. The microphone in the browser

- **Decision**:
  - The `record` 7.1.2 web implementation (`record_web`, already in the lockfile) with
    `startStream` and `pcm16bits` at 16 kHz mono. The browser resamples.
  - Echo cancellation, noise suppression and automatic gain are **off**, closest to Android's
    `VOICE_RECOGNITION` source. S3 compares results with them on and off.
  - The audio session setup is skipped on the web.
  - The mistake tone is a short Web Audio tone, using the same microphone gate as the phones.
  - Denied permission: the browser cannot open its own settings, so the explainer shows how to
    allow the microphone for the site (FR-023).
- **Rationale**: no new dependency, and the same `MicSource` stream into the recogniser.
- **Alternatives considered**: a custom `AudioWorklet` capture. Only worth it if S3 finds
  `record_web` drops samples.

## R12. Back button, keyboard, mouse and screen readers

- **Decision**:
  - **Back button**: with `MaterialApp` and Navigator 1.0, Flutter's web engine turns the
    browser's back button into a route pop, the same as Android back (FR-008). With nothing left
    to pop, the app stays. Verified in the quickstart; no router migration.
  - **Keyboard**: a `Shortcuts`/`Actions` layer on the reader:
    - ←/→ turn pages in the Mushaf's reading direction;
    - PageUp and PageDown do the same;
    - Space plays or pauses when the reader has focus;
    - Escape closes the top sheet.
  - **Mouse**: a secondary tap (right-click) on an ayah does the same as a long press. The
    browser's context menu is turned off over the Mushaf only.
  - **Focus**: focus stays visible, using Flutter's focus highlight, which switches on with
    keyboard use.
  - **Screen readers**: Flutter's default web opt-in is kept. A hidden "Enable accessibility"
    button turns semantics on. It is checked with NVDA (Chrome, Windows) and VoiceOver (Safari,
    macOS and iOS) (FR-010).
- **Rationale**:
  - Keys and right-click are extra ways to do the same action, not desktop navigation patterns,
    so constitution II holds.
  - Turning semantics on always would cost frame time for every reader.

## R13. Centred phone layout on wide windows

- **Decision**:
  - When the window is wider than 600 logical px, `MathaniApp`'s builder centres the app in a
    column 480 px wide, the full window height.
  - The column gets a `MediaQuery` whose size is the column's, so sheets, dialogs, toasts and the
    page-size calculation all see a phone.
  - Outside the column is the theme's background colour.
  - Resizing keeps the reader's anchor: the page stays the same, as after rotation today.
- **Rationale**: the clarified answer. One layout, nothing new to design, and the Mushaf page
  geometry already scales to the column.
- **Alternatives considered**: scaling the phone layout up. Text would be too large on a
  1440p screen and too small on a laptop.

## R14. Unsupported browsers

- **Decision**:
  - A short inline script in `web/index.html` runs before the Flutter bootstrap and checks for
    the features the app needs: WebAssembly, `DecompressionStream`,
    `navigator.storage.getDirectory`, `structuredClone` and service workers.
  - If one is missing, it shows a static Arabic and English page (by `navigator.language`) that
    names the supported browsers and links to the App Store and Google Play. It does not load
    Flutter.
  - It detects features, not user-agent versions.
- **Rationale**: feature detection is reliable and needs no updates for each browser release
  (FR-003, Edge Cases).

## R15. Versions, releases and permissions

- **Decision**:
  - The web build reads the same `pubspec.yaml` version, and Settings › About already shows it
    (`lib/app/version.dart`).
  - Web releases are deployed from the same release commit as the store builds
    (`docs/release.md` gains a web section).
  - Before the web app is announced:
    - The landing site's `/privacypolicy` is updated to cover the web (FR-028). Nothing is
      collected. Content is fetched from Netlify, Hugging Face and the recitation hosts, which
      see the reader's IP address like any web request. Data is kept in the browser.
    - The landing site links to get.mthani.app (FR-002), using the existing partial deploy, so
      nothing else on mthani.app changes (SC-009).
    - The permission drafts for D1–D4 (docs/permissions) are widened from "the App Store and
      Google Play" to "and the web app at get.mthani.app".
- **Rationale**: one version across platforms (FR-029). The permissions requests currently name
  only the two stores.

## R16. Device facts in the browser

`DeviceChannel` gets a web implementation:

| Fact | Browser source |
|------|----------------|
| Network state | `navigator.onLine`. Metered when `navigator.connection` reports `cellular` or `saveData`, otherwise unmetered. Only Chromium on Android reports this, so on other browsers the "ask before using mobile data" step does not apply. |
| Free bytes | R7 |
| Exclude from backup | no-op |
| Device support | R10 gate |
| Open app settings | shows instructions, R11 |
| Mistake tone | R11 |

Other plugins:
- **Haptics** (`HapticFeedback`): uses `navigator.vibrate` where the browser has it, otherwise
  does nothing.
- **Wakelock** (`wakelock_plus`): the Screen Wake Lock API.
- **Sharing**: `share_plus` is used only when `navigator.share` exists. Otherwise the text is
  copied, with a toast (spec US1 scenario 6).

## R17. The reference devices for the web

The web app is measured against the constitution III budgets and SC-001–003 on:

- a **mid-range laptop**: 4 cores, 8 GB, about 2021 (for example a Core i5-1135G7), running
  current Chrome and Firefox;
- the **Galaxy A15** in Chrome;
- the **iPhone SE (2nd gen)** in Safari.

The phones are already the app's reference devices (specs/001 plan). The network is throttled to
20 Mbit/s down with a 40 ms round trip.

## R18a. HTTP for recordings (added during task generation)

- **Decision**:
  - `ayah_fetcher.dart` moves from `dart:io` `HttpClient` to `package:http`'s `Client` (1.6.0,
    already transitive; it becomes a direct dependency). Phones get `IOClient` over today's
    `HttpClient` with the same timeouts. The web gets `BrowserClient`, which uses `fetch` and
    streams the body.
  - Running out of space is reported by `FileStore` as a `NoSpaceException`, instead of the
    fetcher reading `FileSystemException` OS codes.
- **Clip check on the web**:
  - The fetcher accepts a clip only when the response is `206` with
    `Content-Range: bytes <start>-<end-1>/<total>`.
  - everyayah.com and quranicaudio.com send `Access-Control-Expose-Headers` without
    `Content-Range` *(checked 2026-10-26)*, so a browser cannot read that header. tarteel.ai does
    expose it.
  - When `Content-Range` is not readable, the web accepts `206` plus a body of exactly
    `end - start` bytes. The existing size check against the catalogue does the rest.
  - This is weaker only against a replaced file whose new range happens to have the same length,
    and the catalogue size check would still catch most of those.
- **Rationale**: one fetch path for both platforms. `http` is a small Dart-team package already
  in the lockfile.
- **Alternatives considered**: a `dart:io`/web HTTP seam of our own. It would duplicate what
  `package:http` already is.

## R18. Tests

| What | How |
|------|-----|
| Shared logic (matcher, live follower, fetcher rules over a fake `FileStore`) | VM tests in `test/` (`flutter test`), as now |
| Web seams (OPFS `FileStore`, web database opener, gunzip, unsupported check helpers) | `flutter test --platform chrome`, tagged `web` in `dart_test.yaml` |
| App flow | `integration_test/app_flow_test.dart` in Chrome through `flutter drive -d web-server` with chromedriver |
| Safari, Firefox and phone browsers | The manual matrix in the quickstart; no new browser-automation dependency |
| Privacy (SC-007) | A network-log check during a session (quickstart V7), plus the existing `memorization_privacy_test` extended to the web engine host |

**Rationale**: Lean (constitution IV). Browser automation beyond Chrome would add Node
dependencies for a matrix of about 10 manual checks per release.
