---

description: "Task list for Mathani on the Web"
---

# Tasks: Mathani on the Web

**Input**: Design documents from `specs/008-web-app/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/web-platform.md](./contracts/web-platform.md),
[contracts/hosting.md](./contracts/hosting.md), [quickstart.md](./quickstart.md)

**Tests**: Included. The plan (research R18) and the quickstart list them, and several rules can
only be held by automated checks:
- the phone behaviour does not change while `dart:io` moves behind seams (constitution I);
- the database is rewritten only on a version change (SC-002);
- no audio leaves the device (SC-007).

**Organization**: grouped by user story. US1 is reading (the MVP), US2 recitations, US3
memorization, US4 install and offline.
- **Phase 2 changes phone code.** It moves `dart:io` behind seams with no behaviour change, and
  T024 gates it on both reference phones before any story starts.
- **Spike gates**: S1 (T040) gates the US1 release. S2 (T052) gates the US3 worker. S3 (T064)
  sets the microphone settings.
- **Outward-facing steps**: T005 (a Netlify team, site and DNS), T051 (a Hugging Face upload),
  T078–T079 (the landing site and the production deploy). Confirm each with the owner before
  running it.

## Implementation status (2026-10-26)

Done and checked: Phases 1–2 code, US1, US4, the US3 code and the Polish drafts. The VM suite
passes, 343 tests, including the desktop sherpa-onnx run. The release web build runs locally in
Chrome ([validation.md](./validation.md)), and browser recognition works on the development
laptop ([s2-results.md](./s2-results.md)).

**Changed from the task text** (research.md › Changes made during implementation):
- **T005, T037, T072**: the host is Cloudflare Pages, not Netlify (row 14). `tool/web_deploy.mjs`
  deploys with `wrangler pages deploy`, and rollback goes through the Pages dashboard. Task text
  that names Netlify (team, token, bandwidth report) is superseded.
- **T002**: the shared worker is compiled from `tool/web/sqflite_sw.dart`, because the package
  setup fails on Windows.
- **T050**: no Emscripten build. sherpa-onnx's own WebAssembly build (`sherpa_onnx_web`) is used,
  loaded by `web/speech/speech_worker.js`.
- **T022, T060, T061**: no `AsrStore`. `AsrModel` downloads on every platform, and only
  `unpackModel` differs. The worker reads the saved model and does not download it.
- **T034**: `DeviceChannel.keepBrowserData()` asks for persistent storage on the first bookmark
  or download. Nothing is stored in `user.db`.
- **T035**: the support check does not require service workers (Firefox private windows).
- **T041**: fallback fonts are served from `web/font-fallback/`, not blocked.
- **T051, T058**: `hamzagamil/mathani-asr` uploaded 2026-10-26 at commit `dd396c6`. The sizes and SHA-256 sums match `asrModelFiles`, and CORS and `Range` were checked; `asrModelBaseWeb` is pinned to that commit.
- **T070**: no widget test. The font loader has no hook for a failing page font, so this is
  checked by hand in V9.
- **T074, T075**: the drafts are in [landing-drafts.md](./landing-drafts.md) for review, not
  written into `Mathani-landing`.
- **Memorization on the web** stays off (`speechEngineAvailable`) until T052 passes on the
  reference devices.

**Open, and why:**

| Waiting for | Tasks |
|-------------|-------|
| The owner (outward-facing) | T005: hosting **moved to Cloudflare Pages** (project `mthani-web`, deployed and checked on mthani-web.pages.dev, offline start included). Still to do: switch the Namecheap CNAME `get` to `mthani-web.pages.dev`, then delete the Netlify `mthani-web` site; T078, T079 publishing; T077 the constitution amendment (optional) |
| Devices and browsers | T024 step 6 and T076 (phones); T040, T042, T049, T052, T063–T065, T071 (browser matrix, spikes) |
| A draft deploy (needs T005) | T039 |
| A Chrome test-runner fix | T013, T043: `flutter test --platform chrome` stays at "loading" on this machine |
| Not yet adapted | T038's `app_flow_test` run in Chrome; T047 and T048 checks in a real browser |

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US4)

## Path Conventions

Single Flutter project at the repository root: `lib/`, `test/`, `tool/`, `web/`,
`integration_test/`, `test_driver/`, `docs/`. The new seams are in `lib/platform/`, and files the
browser loads directly are in `web/`.

## Shared conventions

- **Seams**: each one is `lib/platform/<name>.dart` (the interface, plus
  `export '<name>_io.dart' if (dart.library.js_interop) '<name>_web.dart';`) with `<name>_io.dart`
  and `<name>_web.dart` beside it ([contracts/web-platform.md](./contracts/web-platform.md)).
  - Only `*_web.dart` files and `lib/features/memorization/web_worker_main.dart` may import
    `package:web`, `dart:js_interop` or `sqflite_common_ffi_web`.
  - Only `*_io.dart` files and the FFI speech engine may import `dart:io`, `dart:ffi`,
    `dart:isolate` or `path_provider`.
  - T023 enforces both rules with a test.
- **Tests**:
  - VM tests use `test/support/memory_file_store.dart` (T008) instead of temp directories, except
    `file_store_io_test.dart`.
  - Browser tests live in `test/web/`, carry `@Tags(['web'])` and run with
    `flutter test --platform chrome --tags web`. The VM run excludes them.
  - Existing conventions hold: `openTestReader()` inside `tester.runAsync(...)`,
    `test/support/fake_audio_server.dart` for HTTP, `test/support/fake_memorization.dart` for the
    recogniser and microphone. No test reaches GitHub, Hugging Face or a recitation host.
- **Strings**: every new string goes into `lib/app/l10n/app_en.arb` and `app_ar.arb`, then
  `flutter gen-l10n`.
- **Constants**: one definition each:

  | Constant | Value | Defined in |
  | --- | --- | --- |
  | `wideWindowMin` | 600 logical px | `lib/app/app.dart` |
  | `phoneColumnWidth` | 480 logical px | `lib/app/app.dart` |
  | `webMinDeviceMemoryGb` | 4 | `lib/features/memorization/device_support.dart` |
  | `mistakeToneHz` / `mistakeToneMs` | 880 / 120 | `lib/platform/device_web.dart` |
  | `asrModelBaseWeb` | `https://huggingface.co/hamzagamil/mathani-asr/resolve/<commit>/$asrModelVersion/` | `lib/features/memorization/asr_model.dart` |

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: dependencies, test tags, and the hosting the spikes deploy to.

- [X] T001 Update `pubspec.yaml`:
  - move `sqflite_common_ffi_web` and `sqlite3` from `dev_dependencies` to `dependencies`, with
    the versions unchanged;
  - add `web` and `http: ^1.6.0` as direct dependencies (both already transitive; research R3,
    R18a);
  - run `flutter pub get` and confirm `pubspec.lock` changes only their `dependency:` kind.
- [X] T002 Run `dart run sqflite_common_ffi_web:setup`. Commit the generated `web/sqflite_sw.js`
  and the `web/sqlite3.wasm` that matches the locked `sqlite3` version (research R4).
- [X] T003 [P] Add a `web` tag to `dart_test.yaml`: "browser-only tests; run with
  `flutter test --platform chrome --tags web`; VM runs use `--exclude-tags web`". Create
  `test/web/`.
- [X] T004 [P] Create `lib/platform/supported_browsers.dart` with the list from data-model.md ›
  Supported browser list, as a `const` list of `(name, desktop, phone)` records:
  - Chrome: Windows, macOS / Android;
  - Edge: Windows / —;
  - Firefox: Windows, macOS / Android;
  - Safari: macOS / iOS.

  Add a `supportedBrowserNames` getter ("Chrome, Edge, Firefox, Safari") for messages.
- [ ] T005 **Outward-facing, confirm with the owner first**: create the hosting
  ([contracts/hosting.md](./contracts/hosting.md) › Sites).
  - Create a **new Netlify team** and, in it, a new site.
  - Add the custom domain `get.mthani.app`, with a CNAME at the mthani.app DNS provider pointing
    at the site's `*.netlify.app` name.
  - Confirm that HTTPS is issued and HTTP redirects to it.
  - Record the site id and the team name (not the token) in a new "Web" section of
    `docs/release.md`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: move every `dart:io`, `path_provider`, isolate and FFI use in shared code behind the
seams in [contracts/web-platform.md](./contracts/web-platform.md), with **no behaviour change on
phones**, so the app compiles and starts in a browser.

**⚠️ CRITICAL**: No user story work can begin until T024 passes.

### Seams

- [X] T006 [P] Create `lib/platform/gunzip.dart`, `gunzip_io.dart` and `gunzip_web.dart`
  exposing `Future<Uint8List> gunzip(Uint8List gz)`.
  - `_io` uses `dart:io` `gzip`.
  - `_web` uses `DecompressionStream('gzip')`; move `_browserGunzip` and its interop types from
    `tool/web_preview.dart`.

  In `lib/features/reader/printed_fonts.dart`, drop `import 'dart:io' show gzip` and the
  `inflate` swap and call `gunzip`. Keep a `@visibleForTesting` override only if an existing test
  sets `PrintedFonts.inflate`.
- [X] T007 Create `lib/platform/file_store.dart`:
  - `StoreRoot { cache, support }`;
  - the `FileStore` interface exactly as in the contract (`length`, `append`, `rename`, `delete`,
    `list`, `read`, `playableUri`, `release`, `freeBytes`, `protect`);
  - `class NoSpaceException implements Exception`;
  - a `FileStore fileStore()` factory.

  `file_store_io.dart`:
  - maps `cache` and `support` to `getApplicationCacheDirectory()` and
    `getApplicationSupportDirectory()`;
  - turns `FileSystemException` with OS error 28 (ENOSPC) or 112 (ERROR_DISK_FULL) into
    `NoSpaceException` (the rule now in `AyahFetcher._isNoSpace`);
  - `playableUri` returns `Uri.file`, and `release` is a no-op;
  - `freeBytes` and `protect` call the device seam (T010), with `protect` excluding the support
    root from backup.

  `file_store_web.dart` is a stub whose methods throw `UnsupportedError('FileStore: OPFS lands in
  US2')`, except `protect`, which T034 implements.
- [X] T008 [P] Create `test/support/memory_file_store.dart`, an in-memory `FileStore`:
  - a configurable `freeBytes`;
  - a `failWithNoSpaceAfter(bytes)` switch;
  - `playableUri` returning `memory:<root>/<path>`.
- [X] T009 [P] Create `test/unit/file_store_io_test.dart` over a temp directory:
  - `append` creates a file, and a second `append` resumes it;
  - `rename` replaces the target;
  - `list` gives names, sizes and directories;
  - `delete(recursive: true)` removes a tree;
  - `length` is null for a missing file;
  - `read` streams the bytes back.
- [X] T010 Create `lib/platform/device.dart`, `device_io.dart` and `device_web.dart`.
  - Move `NetworkState` to `device.dart`.
  - Move `DeviceChannel` unchanged from `lib/shared/device_channel.dart` to `device_io.dart`, and
    delete the old file.
  - `device_web.dart` gives a `DeviceChannel` with the same members, returning today's fallbacks:
    `unmetered`, `1 << 40`, `(arm64: true, ramBytes: 1 << 40)` and no-ops. US1–US3 replace them.
  - Update the imports in the files that use it: `asr_model.dart`, `device_support.dart`,
    `memorization_controller.dart`, `mic_explainer.dart`, `setup_steps.dart`,
    `ayah_fetcher.dart`, `download_queue.dart`, `test/unit/asr_model_test.dart`,
    `test/unit/device_support_test.dart`.
- [X] T011 Create `lib/platform/database.dart`, `database_io.dart` and `database_web.dart`:
  - `Future<void> initDatabases()`;
  - `Future<String> installQuranDb(String bundledVersion)`, which returns the path to open.

  `_io`: `initDatabases` does nothing, and `installQuranDb` is the copy-if-`quran.version`-changed
  code moved verbatim from `QuranRepository.open` in `lib/data/quran_repository.dart`.

  `_web`:
  - `initDatabases` sets `databaseFactory = databaseFactoryFfiWeb` (the shared-worker factory,
    research R4).
  - `installQuranDb` reads the installed version with
    `databaseFactory.readDatabaseBytes('<dir>/quran.version')` (missing counts as none).
  - Only when it differs from `bundledVersion`, it fetches `assets/assets/db/quran.db.gz` and
    runs `gunzip`. If that is 404 (a `flutter run` without the deploy step), it uses
    `rootBundle.load('assets/db/quran.db')`. It then writes the database with
    `writeDatabaseBytes` and writes the version file **after** the database.

  `QuranRepository.open` becomes: read `assets/db/quran.version`, then
  `_openAt(await installQuranDb(version))`. Remove its `dart:io` and `kIsWeb` imports.
- [X] T012 Update `runMathani` in `lib/main.dart`:
  - call `await initDatabases()` first;
  - remove both `kIsWeb` branches: open the two databases in parallel on every platform, and call
    `AsrModel.removeOtherVersions()` after the first frame on every platform.

  If T024 shows that the web factory needs sequential opens, add a `const parallelDatabaseOpen`
  to `lib/platform/database*.dart` rather than a `kIsWeb` check.
- [ ] T013 [P] Create `test/web/database_web_test.dart` (`@Tags(['web'])`):
  - a first install writes `quran.db` and `quran.version`;
  - a second `installQuranDb` with the same version does **not** call `writeDatabaseBytes` (spy
    factory);
  - a new version rewrites both;
  - a missing `.gz` falls back to the bundled asset.

  Create `test/web/gunzip_web_test.dart`: the output of `gzip.encode` from a fixture round-trips.

### Recitations onto FileStore and package:http

- [X] T014 Refactor `lib/features/recitation/ayah_fetcher.dart` (research R7, R18a):
  - **Constructor**: takes `FileStore store` (default `fileStore()`) and
    `http.Client Function()? httpClient` (default `http.Client.new`). The `cacheRoot`,
    `supportRoot` and `HttpClient` parameters go.
  - **Paths**: `cacheFile`, `downloadFile`, `basmalaFile` and `downloadDir` return store-relative
    paths (`recitations/<reciter>/<sss>/<aaa>.mp3`, `recitations/cache/...`) with their
    `StoreRoot`, matching data-model.md › Browser data. `isValid` checks
    `store.length == bytes`.
  - **`_get`**:
    - sends a `StreamedRequest` with the `Range` header for clips;
    - applies `fetchTimeout` to `send()` and to the body stream;
    - writes the body with `store.append(root, '$path.part', ...)`, then `rename`s;
    - on `NoSpaceException`, deletes the `.part` and rethrows; on any other error, deletes it
      and returns false.
  - **Clip acceptance** (R18a): `206`, plus either
    `Content-Range == 'bytes <start>-<end-1>/<total>'` when the header is readable, or a body of
    exactly `end - start` bytes when it is absent.
  - Remove `dart:io` and `path_provider`.
- [X] T015 Move these tests onto `MemoryFileStore` and `fake_audio_server.dart`'s `http` client:
  `test/unit/ayah_fetcher_test.dart`, `test/unit/ayah_fetcher_range_test.dart`,
  `test/unit/clip_range_test.dart`.
  - Existing expectations stay unchanged.
  - Add "clip accepted when Content-Range is hidden and the length matches" and "clip rejected
    when Content-Range is hidden and the length differs".
- [X] T016 Refactor `lib/features/recitation/download_queue.dart` and
  `lib/features/recitation/downloads_screen.dart` to `FileStore` paths:
  - `Directory(...).list` becomes `store.list`;
  - the `.part` rename at line ~303 becomes `store.rename`;
  - deletes become `store.delete(recursive: true)`.

  Update `test/unit/download_queue_test.dart` and `test/widget/downloads_screen_test.dart` to
  `MemoryFileStore`.
- [X] T017 Refactor `lib/features/recitation/audio_engine.dart` and
  `lib/features/recitation/recitation_controller.dart`:
  - The engine receives `(RecitedItem, StoreRoot, String path)` and plays
    `AudioSource.uri(await store.playableUri(root, path), tag: item)` instead of
    `AudioSource.file`.
  - It calls `store.release(uri)` when an item is removed (`removeAudioSourceAt`) and on
    `dispose`.
  - The controller's `paths.add(...cacheFile(...).path)` becomes store paths.
  - Remove `dart:io` from both files.

  Update `test/unit/recitation_controller_test.dart` and the recitation fakes in
  `test/support/fake_recitation.dart`.
- [X] T018 Update `lib/features/recitation/media_handler.dart`:
  - write the artwork with `store.append(StoreRoot.cache, 'recitation_art.png', ...)` (deleting
    any old copy first) and pass `await store.playableUri(...)` as `artUri`;
  - remove `dart:io` and `path_provider`.

  Update `test/unit/media_handler_test.dart`.

### Memorization behind seams

- [X] T019 Create `lib/features/memorization/live_follower.dart`:
  - Define `SpeechEngine` exactly as in the contract (`vadAccept`, `vadDetected`, `vadEmpty`,
    `vadFront`, `vadPop`, `vadFlush`, `vadReset`, `decode`, `free`).
  - Move `_Worker`'s fields and methods from `speech_recogniser.dart` into
    `class LiveFollower(SpeechEngine engine, void Function(Heard) send)` without changing its
    logic. The `Stopwatch` timing, `liveSlowPass` suspension, `maxHeld` cut and `liveContext`
    window all stay.
  - The constants stay in `speech_recogniser.dart`.
- [X] T020 In `lib/features/memorization/speech_recogniser.dart`:
  - add `class SherpaEngine implements SpeechEngine`, wrapping today's
    `sherpa.VoiceActivityDetector` and `sherpa.OfflineRecognizer` setup with the same config
    values;
  - make the isolate's `_run` build `LiveFollower(SherpaEngine(dir, threads, library),
    main.send)`.

  The public `SpeechRecogniser` interface and `SherpaSpeechRecogniser` are unchanged.
- [X] T021 [P] Create `test/unit/live_follower_test.dart` with a scripted fake `SpeechEngine`
  (VAD segments and decode results per call). Cover:
  - live passes every `livePassEvery`, with none while awaiting a commit;
  - `commit` moves the anchor only for the latest live pass;
  - a pause pass at a VAD segment end;
  - a segment ended by `vadMaxSpeech` is not a pause;
  - `liveSlowPass` suspends live passes until the next pause;
  - `maxHeld` cuts to the last second;
  - `reset` drops context.

  The desktop sherpa tests in `test/unit/speech_recogniser_test.dart` must still pass, and still
  skip when `build/asr/` is absent.
- [X] T022 Create `lib/platform/speech_host.dart`, `speech_host_io.dart` and
  `speech_host_web.dart`:
  - `SpeechRecogniser newSpeechRecogniser()`;
  - an `AsrStore` interface: `Future<AsrModelState> state()`,
    `Future<void> download({required void Function(int received, int total) onProgress})`,
    `Future<void> delete()`, `Future<String> modelDir()`, `Future<void> removeOtherVersions()`,
    `Future<int> keptBytes()`.

  `_io` holds the file, `HttpClient`, `.part`, resume, `Isolate.run` unpack and SHA-256 code
  moved from `lib/features/memorization/asr_model.dart`, with unchanged behaviour.

  `lib/features/memorization/asr_model.dart` keeps the `AsrModel` `ChangeNotifier`, its states
  and errors, the free-space and metered checks and `asrModelFiles`, and calls `AsrStore`. It no
  longer imports `dart:io`, `dart:isolate` or `path_provider`.

  `_web` is a stub that throws `UnsupportedError` until US3 (T061).

  Update `test/unit/asr_model_test.dart` to the io `AsrStore` over a temp directory, with the same
  expectations.
- [X] T023 [P] Create `test/unit/platform_imports_test.dart`. It reads every `.dart` file under
  `lib/` and fails when:
  - `dart:io`, `dart:ffi`, `dart:isolate` or `package:path_provider` appears outside
    `lib/platform/*_io.dart`, `lib/features/memorization/speech_recogniser.dart` and
    `speech_host_io.dart`;
  - `dart:js_interop`, `package:web` or `sqflite_common_ffi_web` appears outside
    `lib/platform/*_web.dart` and `lib/features/memorization/web_worker_main.dart`.

### Gate

- [ ] T024 **Foundation gate**:
  1. Delete `tool/web_preview.dart` and its mentions (`grep -rn web_preview` across `lib/`,
     `tool/`, `specs/`, `docs/`; update or remove each).
  2. `flutter analyze` is clean, and `flutter test --exclude-tags web,golden` passes.
  3. `flutter test --platform chrome --tags web` passes.
  4. `flutter run -d chrome --wasm` opens the Mushaf.
  5. `dart run tool/size_check.dart` shows growth under 1 MB on both platforms.
  6. On the **Galaxy A15** and the **iPhone SE (2nd gen)**, run quickstart V18: reading,
     recitation (stream, download, offline play, lock-screen controls) and a memorization session
     behave as in 1.5.0.

  Record the results in `specs/008-web-app/foundation-check.md`.

**Checkpoint**: shared code is platform-neutral, the phones are unchanged, and the app starts in a
browser.

---

## Phase 3: User Story 1 - Read the Quran in the browser (Priority: P1) 🎯 MVP

**Goal**: get.mthani.app shows the Mushaf, with the index, search, bookmarks, settings, sharing,
keyboard and mouse, keeping the reader's place across visits.

**Independent Test**: spec US1. On a clear profile, read in both layouts, search, bookmark two
ayat, change theme and language, close the browser, reopen, and find everything kept (quickstart
V1).

### Tests for User Story 1

- [X] T025 [P] [US1] Create `test/widget/wide_window_test.dart`:
  - at 1440×900, the reader's content is `phoneColumnWidth` (480) wide and centred, and the area
    outside is the theme's background colour;
  - `showAyahActions` and the index sheet render inside the column;
  - resizing to 400×800 and back keeps the same page;
  - at 400×800, nothing is constrained.
- [X] T026 [P] [US1] Create `test/widget/keyboard_test.dart`:
  - with the reader focused, → and ← turn pages in the Mushaf's reading direction (← is the next
    page in RTL);
  - PageDown and PageUp do the same;
  - Escape closes an open ayah-actions sheet;
  - Space toggles playback through `fake_recitation.dart`.
- [X] T027 [P] [US1] Extend `test/widget/ayah_actions_test.dart`:
  - a secondary tap on an ayah in `MushafView` and in `FlowingView` opens the same actions as a
    long press;
  - with sharing marked unavailable, "Share" copies the formatted text and shows the copied
    toast.

### Implementation for User Story 1

- [X] T028 [US1] Add the centred column in `lib/app/app.dart` (research R13):
  - Define `wideWindowMin = 600` and `phoneColumnWidth = 480`.
  - In `MaterialApp.builder`, when the window is wider than `wideWindowMin`, wrap the child in a
    `ColoredBox` of the theme background, then `Center`, then a `SizedBox` of `phoneColumnWidth`
    at full height, then a `MediaQuery` whose `size` is the column size.
  - This keeps the Navigator's overlays (sheets, dialogs, snack bars) inside the column. Do not
    change the reader's page-geometry code.
- [X] T029 [P] [US1] Add keyboard shortcuts in `lib/features/reader/reader_screen.dart`
  (research R12):
  - A `Shortcuts` and `Actions` layer with a `Focus(autofocus: true)` on the reader.
  - Arrow keys and PageUp/PageDown map to next and previous page, respecting the Mushaf direction
    used by `onPageTurned`. Space maps to the recitation controller's play/pause.
  - Escape uses Flutter's `DismissIntent`; make sure modal sheets opened by `showAyahActions`
    accept it.
- [X] T030 [P] [US1] Add right-click in `lib/features/reader/mushaf_view.dart` and
  `lib/features/reader/flowing_view.dart`:
  - add `onSecondaryTapUp` next to the existing `onLongPressStart` (mushaf_view.dart ~line 172)
    and the `LongPressGestureRecognizer` (flowing_view.dart ~line 395), calling the same
    `onAyahLongPress` with the same `inSession` guard;
  - in `reader_screen.dart`, call `BrowserContextMenu.disableContextMenu()` in `initState` and
    `enableContextMenu()` in `dispose`, only when `kIsWeb`.
- [X] T031 [P] [US1] Create `lib/platform/share.dart`, `share_io.dart` and `share_web.dart` with
  `Future<void> shareText(BuildContext context, String text)`:
  - `_io` calls `SharePlus.instance.share(ShareParams(text: text))`;
  - `_web` uses `SharePlus` when `navigator.share` exists, otherwise
    `Clipboard.setData(ClipboardData(text: text))` and the existing "copied" snack bar string.

  `lib/features/reader/ayah_actions.dart` (~line 121) calls `shareText`, and its `share_plus`
  import goes.
- [X] T032 [P] [US1] Implement `networkState()` in `lib/platform/device_web.dart` (research R16):
  - `none` when `!navigator.onLine`;
  - `metered` when `navigator.connection?.type == 'cellular'` or `navigator.connection?.saveData`
    is true (read through `js_interop` with null checks; only Chromium has `connection`);
  - otherwise `unmetered`.
- [X] T033 [US1] Add the "kept in this browser" note (FR-015) in
  `lib/features/settings/about_section.dart`. When `kIsWeb`, show a line with the new string
  `webDataKeptHere` (en: "Your bookmarks, settings and downloads are kept only in this browser.";
  ar: "تُحفظ علاماتك وإعداداتك وتنزيلاتك في هذا المتصفح فقط.") in `app_en.arb` and `app_ar.arb`.
- [X] T034 [US1] Implement `protect()` in `lib/platform/file_store_web.dart` (data-model.md ›
  State: persistent storage):
  - If the `user.db` setting `storage_persist` is unset, call `navigator.storage.persist()` once
    and store `granted` or `refused`. Never ask again.
  - Call `fileStore().protect()` after the first bookmark is added, at the add-bookmark path in
    `lib/shared/reader_state.dart` (or wherever bookmarks are written through `UserRepository`).
    On phones `protect` already exists and does the same as today's backup exclusion.
- [X] T035 [US1] Rewrite `web/index.html` per [contracts/hosting.md](./contracts/hosting.md) ›
  index.html:
  - `<html lang dir>` set by a tiny inline script from `navigator.language` (`ar`/`rtl`, else
    `en`/`ltr`);
  - `<title>Mathani · مثاني</title>`, a description, `theme-color` for both colour schemes, and
    `apple-touch-icon`;
  - the **support check** (research R14): if `WebAssembly`, `DecompressionStream`,
    `navigator.storage?.getDirectory`, `structuredClone` or `'serviceWorker' in navigator` is
    missing, render a static bilingual page that names "Chrome, Edge, Firefox, Safari" (the same
    names as `supportedBrowserNames`) and links to the App Store and Google Play listings (URLs
    from `docs/store/`), and do not load `flutter_bootstrap.js`.
- [X] T036 [P] [US1] Create `web/_headers` exactly as in [contracts/hosting.md](./contracts/hosting.md)
  › Files and headers:
  - the Cache-Control rows;
  - `.wasm` served as `application/wasm`;
  - the `Content-Security-Policy` with `'sha256-…'` of T035's inline scripts (computed by T037,
    which rewrites the placeholder);
  - `Referrer-Policy: no-referrer`, `X-Content-Type-Options: nosniff`,
    `Permissions-Policy: microphone=(self), camera=(), geolocation=()`;
  - no COOP or COEP headers (research R2).
- [X] T037 [US1] Create `tool/web_deploy.mjs` ([contracts/hosting.md](./contracts/hosting.md) ›
  Build and deploy).

  **Token**: decrypt the Netlify token from `C:\Users\Hamza\keys\netlify-token.dpapi` the way
  `C:\Users\Hamza\Documents\Mathani-landing\_deploy\netlify-deploy.mjs` does. Never print it.

  **Prepare `build/web`**:
  - gzip `assets/assets/db/quran.db` to `quran.db.gz` (level 9) and delete the original;
  - compute the CSP `sha256` hashes of `index.html`'s inline scripts into `_headers`.

  **Refuse to deploy** when:
  - `version.json`'s version ≠ `pubspec.yaml`'s;
  - any built `.js` contains `fonts.gstatic.com`, `fonts.googleapis.com` or
    `www.gstatic.com/flutter-canvaskit`;
  - the browser names in `index.html` ≠ `supported_browsers.dart`'s;
  - `lib/features/memorization/web_worker_main.dart` exists and
    `build/web/speech/speech_worker.dart.js` does not.

  **Deploy**: send every file in `build/web` as a full deploy to the site id from
  `docs/release.md`.
  - `--dry-run` creates a draft deploy and prints its URL.
  - `--restore <deploy id>` publishes an earlier deploy.
  - It always prints the new and previous deploy ids and the team's bandwidth used this month.
- [ ] T038 [P] [US1] Create `test_driver/integration_test.dart`, the standard
  `integrationDriver()`. Make `integration_test/app_flow_test.dart` run under
  `flutter drive -d web-server`, skipping only steps that need a phone-only plugin (with a
  comment per skip).
- [ ] T039 [US1] Run `flutter build web --wasm --release --no-web-resources-cdn` and
  `node tool/web_deploy.mjs --dry-run`, and open the draft URL in Chrome. Fix anything that does
  not start.
- [ ] T040 [US1] **Spike S1** ([quickstart.md](./quickstart.md) › S1) on the R17 reference
  devices at 20 Mbit/s and 40 ms. Record in `specs/008-web-app/s1-results.md`:
  - first visit and return visit times (SC-001; SC-002 baseline before the US4 service worker);
  - frame stats for 50 page turns and 30 s of flowing scroll, for the WebAssembly build in Chrome
    and the JavaScript build in Firefox and Safari (SC-003);
  - the hosts in the network log;
  - where background or locked-screen playback stops.

  If SC-001 fails, record it in plan.md › Complexity Tracking and trim per S1's decision before
  T042.
- [X] T041 [US1] If T040 finds requests to Google font or engine hosts, stop them, in this
  order:
  1. the engine `fontFallbackBaseUrl` set in the `flutter_bootstrap.js` config in
     `web/index.html`, pointing at our own `assets/`;
  2. a bundled font for any missing glyph.

  Then re-check the network log.
- [ ] T042 [US1] On the draft deploy, run quickstart V1–V5, V12–V16 in each browser of
  data-model.md › Supported browser list, with V14 using NVDA with Chrome and VoiceOver with
  Safari (macOS and iOS). V4 compares the 20 listed pages with phone screenshots (SC-005). Record
  the results in `specs/008-web-app/validation.md`, and fix failures in the files above.

**Checkpoint**: US1 works in every supported browser on a draft deploy. It can be published on
its own (T078, T079), with recitation and memorization showing their current web stubs as unavailable.

---

## Phase 4: User Story 2 - Listen to recitations (Priority: P2)

**Goal**: every reciter plays ayah by ayah with highlighting, keeps playing in a background tab,
responds to media keys, and downloads play offline.

**Independent Test**: spec US2 and quickstart V6. Play two reciters, switch tabs, pause with the
media key, download a short surah, go offline, reload and play it.

### Tests for User Story 2

- [ ] T043 [P] [US2] Create `test/web/file_store_web_test.dart` (`@Tags(['web'])`) for OPFS:
  - `append` then a resumed `append`;
  - `length`;
  - `rename` replacing a target;
  - `list` sizes;
  - `delete(recursive: true)`;
  - `read` round-trip;
  - `playableUri` is a `blob:` URL whose fetched bytes equal the file, and `release` revokes it;
  - `freeBytes` > 0.
- [X] T044 [P] [US2] Add "a `NoSpaceException` from the store shows the no-space message and
  lists nothing for that surah" to `test/unit/download_queue_test.dart`, using
  `MemoryFileStore.failWithNoSpaceAfter` (spec US2 scenario 4).

### Implementation for User Story 2

- [X] T045 [US2] Implement `lib/platform/file_store_web.dart` over OPFS (research R7):
  - **Roots**: `cache` maps to the OPFS directory `cache/` and `support` to `support/`. Nested
    paths create directories with `getDirectoryHandle(..., {create: true})`.
  - **`append`**: `createWritable({keepExistingData: true})`, then `seek(size)`, then write the
    chunks, then `close`. A `QuotaExceededError` deletes the partly written file and throws
    `NoSpaceException`.
  - **`rename`**: `FileSystemFileHandle.move(newName)` where it exists; otherwise copy, then
    delete.
  - **`read`**: streams `getFile()` in slices.
  - **`playableUri`**: `URL.createObjectURL(await getFile())`. `release` calls
    `revokeObjectURL`.
  - **`freeBytes`**: `navigator.storage.estimate()` quota minus usage.
  - Replace the US2 stub. Keep T034's `protect`, and call it on the first download too, in
    `download_queue.dart`.
- [X] T046 [US2] Implement `freeBytes()` in `lib/platform/device_web.dart` as `fileStore().freeBytes()`.
- [ ] T047 [US2] Check `lib/features/recitation/media_handler.dart` on the web:
  - `AudioService.init` works with `audio_service_web` (the Media Session API);
  - the title, artist and artwork show in Chrome's media hub and the macOS and Android media
    controls;
  - play, pause, next and previous media keys reach the handler.

  Fix any config that only applies on phones (Android notification channel, iOS options) by
  leaving it unset on the web rather than branching the handler.
- [ ] T048 [US2] Make sure the first play on the web always comes from a user gesture (the play
  buttons in `recitation_bar.dart` and `ayah_actions.dart`) and that no code path calls `play()`
  at start-up or after restoring state (the autoplay edge case). Add a short comment where state
  is restored.
- [ ] T049 [US2] On the draft deploy, run quickstart V6 and V11 in each supported browser,
  including one per-ayah reciter (Al-Husary) and one per-surah reciter from quranicaudio.com,
  whose `Content-Range` is hidden (R18a).
  - If T040 found that a browser pauses playback with the screen locked or in an installed app,
    add that browser and the behaviour to spec.md › Edge Cases as a platform limit.
  - Record the results in `specs/008-web-app/validation.md`.

**Checkpoint**: US1 and US2 both work in a browser.

---

## Phase 5: User Story 3 - Memorize with live recognition (Priority: P3)

**Goal**: memorization in the browser, with the same model, the same live reveal, the same
results, and no audio leaving the device.

**Independent Test**: spec US3 and quickstart V7. Allow the microphone, download the model,
recite a short surah with one mistake, compare with the phone app, and watch the network.

### Build and spikes

- [X] T050 [US3] Create `tool/build_sherpa_wasm.sh` (research R10). It:
  - pins `emsdk` to an exact version (recorded at the top of the script) and clones sherpa-onnx
    at tag `v1.13.8`;
  - runs its `build-wasm-simd-vad-asr.sh` with no model files copied in, SIMD on and pthreads
    off;
  - copies `sherpa-onnx-wasm-main-vad-asr.js`, `.wasm`, `sherpa-onnx-asr.js` and
    `sherpa-onnx-vad.js` into `web/speech/`.

  If `sherpa-onnx-asr.js` has no omnilingual CTC config, the script applies a patch kept in
  `tool/sherpa_wasm_omnilingual.patch` that adds it by mirroring the C struct
  `SherpaOnnxOfflineOmnilingualAsrCtcModelConfig`. Run it and commit `web/speech/`.
- [X] T051 [US3] **Outward-facing, confirm with the owner first**: create the Hugging Face model
  repo `hamzagamil/mathani-asr` and upload `asr-khatma-v1/model.int8.onnx.gz`, `tokens.txt` and
  `silero_vad.onnx`, byte-identical to the GitHub release.
  - Check each file's size and SHA-256 against `asrModelFiles` by downloading through
    `resolve/<commit>/`.
  - Add the model card's CC BY 4.0 and MIT credits, matching About.
  - Add an "Upload to Hugging Face" step to `tool/README.md`.
- [ ] T052 [US3] **Spike S2** ([quickstart.md](./quickstart.md) › S2): a throwaway page
  `build/s2/index.html` (not committed) that loads `web/speech/` in a worker, loads the model
  from OPFS and decodes the specs/007 S1 clips. On each reference device, record:
  - the load time;
  - the peak tab memory;
  - the decode time for 3, 8 and 20 s;
  - whether the words match desktop sherpa-onnx.

  Write the results and the resulting gate to `specs/008-web-app/s2-results.md`. If a reference
  device cannot load the model, set the gate so it is excluded. If the laptop's live pass exceeds
  `liveSlowPass` in Chrome, stop and revisit research R2 with the owner.

### Tests for User Story 3

- [X] T053 [P] [US3] Extend `test/unit/memorization_privacy_test.dart`:
  - `lib/features/memorization/web_worker_main.dart` and `lib/platform/speech_host_web.dart`
    contain no URL other than `asrModelBaseWeb`;
  - the worker's message handler never posts audio or words to anything but the page (the
    `heard` message), checked by source scan as the existing test does for the phone files.
- [X] T054 [P] [US3] Extend `test/unit/device_support_test.dart` with web gate cases:
  - no SIMD gives `Unsupported.browser`;
  - no AudioWorklet gives `Unsupported.browser`;
  - no OPFS gives `Unsupported.browser`;
  - `deviceMemoryGb == 2` gives `Unsupported.lowMemory`;
  - `deviceMemoryGb == null` with everything else present gives supported.

### Implementation for User Story 3

- [X] T055 [US3] Update `lib/features/memorization/device_support.dart`:
  - add `Unsupported.browser` and `webMinDeviceMemoryGb = 4`;
  - `memorizationSupport` uses `WebSupport` on the web (`wasmSimd`, `audioWorklet`, `opfs`, and
    `deviceMemoryGb >= 4` when non-null) and today's `(arm64, ramBytes)` rule on phones.

  Add a `memorizationBrowserUnsupported` string (en: "Memorization isn't available in this
  browser. It works in {browsers}."; ar: "الحفظ غير متاح في هذا المتصفح. يعمل في {browsers}.")
  filled from `supportedBrowserNames`, and show it where the low-memory message is shown today.
- [X] T056 [US3] Implement `deviceSupport()` in `lib/platform/device_web.dart` returning
  `WebSupport`:
  - `wasmSimd`: `WebAssembly.validate` on the standard 30-byte SIMD probe module;
  - `audioWorklet`: `'audioWorklet' in AudioContext.prototype`;
  - `opfs`: `navigator.storage?.getDirectory`;
  - `deviceMemoryGb`: `navigator.deviceMemory`, or null.

  Also implement `playMistakeTone()` (an `OscillatorNode` sine at `mistakeToneHz` for
  `mistakeToneMs`, through a short gain envelope) and make `openAppSettings()` a no-op.
- [X] T057 [US3] Update the microphone for the web (research R11):
  - In `lib/features/memorization/mic_source.dart`, set `echoCancel`, `noiseSuppress` and
    `autoGain` in `RecordConfig` to the values chosen by T064 (start with all `false`). Skip the
    `AudioSession` configure and `_recorder.ios` calls when `kIsWeb`.
  - In `lib/features/memorization/mic_explainer.dart`, when `kIsWeb` and permission is denied,
    show the new string `micDeniedBrowser` (en: "Allow the microphone for get.mthani.app in your
    browser's site settings, then try again."; ar: "اسمح باستخدام الميكروفون لموقع get.mthani.app
    من إعدادات الموقع في متصفحك، ثم حاول مرة أخرى.") instead of the "open settings" button.
- [X] T058 [US3] Point the model at Hugging Face on the web. In
  `lib/features/memorization/asr_model.dart`, add `asrModelBaseWeb` (with the commit pinned from
  T051), make `asrModelBase` choose by `kIsWeb`, and leave `asrModelFiles` unchanged.
- [X] T059 [US3] Create `web/speech/speech_worker.js`:
  - `importScripts('sherpa-onnx-wasm-main-vad-asr.js', 'sherpa-onnx-asr.js',
    'sherpa-onnx-vad.js')`;
  - wait for the Emscripten module's `onRuntimeInitialized`;
  - then `importScripts('speech_worker.dart.js')`;
  - expose the module as `self.sherpaModule` for the Dart side.
- [X] T060 [US3] Create `lib/features/memorization/web_worker_main.dart` (compiled by
  `dart compile js`; [contracts/web-platform.md](./contracts/web-platform.md) › Speech worker):

  **`JsSherpaEngine implements SpeechEngine`** over `self.sherpaModule`:
  - the VAD is created with the same `vadThreshold`, `vadMinSilence`, `vadMinSpeech`,
    `vadMaxSpeech`, `vadWindow` and 30 s buffer as `SherpaEngine`;
  - the recogniser uses the omnilingual CTC config with `model.int8.onnx`, `tokens.txt` and
    `numThreads: 1`;
  - `decode` returns tokens and timestamps.

  **The `load` message** downloads each `AsrFile` from `base` into OPFS `support/asr/<version>/`:
  - resumes a `.part` with `Range: bytes=<len>-`;
  - unpacks `.gz` files with `DecompressionStream`;
  - checks sizes and SHA-256 with chunked `package:crypto` `sha256`;
  - posts `progress` messages;
  - removes other versions' folders.

  It then mounts the folder through `WORKERFS` from the OPFS `File`s, builds `LiveFollower`, and
  posts `loaded`.

  **Messages**: `samples`, `commit`, `flush`, `reset` and `dispose` map to `LiveFollower` and
  `free`. `heard` is posted as `{type, pass, hearing, windowStart, endSample, words}`.

  **Errors**: a failed fetch is `failed`; a size or hash mismatch is `damaged`; a
  `QuotaExceededError` is `noSpace`; a `RangeError` or out-of-memory during the module load is
  `memory`; a missing API is `unsupported`.
- [X] T061 [US3] Implement `lib/platform/speech_host_web.dart`:
  - **`WebSpeechRecogniser`**: starts `Worker('speech/speech_worker.js')` on `load`, forwards
    `accept` as a transferred `Float32Array`, turns `heard` messages back into `Heard`, and
    terminates the worker on `dispose`.
  - **Web `AsrStore`**:
    - `state()` reads OPFS `support/asr/<version>/` sizes against `asrModelFiles` (`keptBytes`);
    - `download` sends `load` and maps `progress` and `error` codes to `AsrModelError`
      (`memory` → `Unsupported.lowMemory`, `unsupported` → `Unsupported.browser`);
    - `delete` and `removeOtherVersions` use `FileStore`;
    - `modelDir` is unused on the web.

  Replace the T022 stub.
- [X] T062 [US3] Add the worker compile to the build. Document the
  `dart compile js -O2 -o build/web/speech/speech_worker.dart.js
  lib/features/memorization/web_worker_main.dart` step in `docs/release.md` › Web and in
  quickstart.md › Run locally (already listed). Make `tool/web_deploy.mjs` run it itself when
  `build/web/speech/speech_worker.dart.js` is missing or older than the Dart source.
- [ ] T063 [US3] Check that the memorization download sheet and Settings › Downloads
  (`downloads_screen.dart`) show the model's size, progress, resume after a reload, and delete on
  the web through `AsrModel`, with no web-specific UI. Fix only the platform seams if they don't.
- [ ] T064 [US3] **Spike S3** ([quickstart.md](./quickstart.md) › S3): record the same
  recitation on the laptop and the Galaxy A15 (Chrome) with browser audio processing off and then
  on, and compare the revealed words and mistakes with the phone app's. Write the chosen setting
  to `specs/008-web-app/s3-results.md` and apply it in `mic_source.dart` (T057).
- [ ] T065 [US3] On the draft deploy, run quickstart V7 and V8 in each supported browser, with
  DevTools › Network recording during V7. Confirm there are no requests other than the model
  files on first use (SC-007), and that words match the phone app on the same recitation
  (SC-006). Record the results in `specs/008-web-app/validation.md`.

**Checkpoint**: US1–US3 all work in the supported browsers that pass the gate.

---

## Phase 6: User Story 4 - Use it like an app (Priority: P3)

**Goal**: installable, starts offline, and updates on the next visit without losing data.

**Independent Test**: spec US4 and quickstart V9. Install, read some pages, go offline, open the
installed app, and find the pages, bookmarks and downloads there.

- [X] T066 [P] [US4] Rewrite `web/manifest.json` ([contracts/hosting.md](./contracts/hosting.md)
  › manifest):
  - `name` "Mathani · مثاني", `short_name` "Mathani";
  - `start_url` "/", `scope` "/", `display` "standalone";
  - `theme_color` and `background_color` from `lib/app/theme`;
  - icons 192 and 512, `any` and `maskable`, exported from `tool/brand` into `web/icons/`
    (replace Flutter's default icons and `web/favicon.png`).
- [X] T067 [US4] Create `web/sw.js` (about 100 lines; research R9):
  - **install**: precache `self.__PRECACHE` (the shell list injected by T068) into
    `shell-__VERSION__-__BUILD__`.
  - **activate**: delete other `shell-*` caches; read `asset-hashes.json` and delete entries of
    the `assets` cache whose hash changed; `clients.claim()`.
  - **fetch**:
    - same-origin navigations: network first, falling back to the cached `index.html`;
    - same-origin `/assets/` and `/speech/`: cache first into `assets`;
    - other shell files: cache first from the shell cache;
    - cross-origin requests: not intercepted.
  - **updates**: no `skipWaiting` on install. A waiting worker takes over on the next load, when
    no client is using the old one.
- [X] T068 [US4] Extend `tool/web_deploy.mjs`:
  - write `asset-hashes.json` (SHA-256 of every file under `build/web/assets/` and
    `build/web/speech/`);
  - replace `__VERSION__`, `__BUILD__` and `self.__PRECACHE` in `build/web/sw.js` with the
    version, the `version.json` build id, and the list of every file in `build/web` outside
    `assets/assets/qcf/` and `speech/`;
  - delete Flutter's generated `flutter_service_worker.js` from the build.
- [X] T069 [US4] Register the service worker in `web/index.html` from the Flutter loader's
  `onEntrypointLoaded`, after `runApp`, so registration never delays the first frame. Make sure
  nothing registers `flutter_service_worker.js`.
- [X] T070 [US4] Show a message for a page whose font isn't cached while offline. When
  `PrintedFonts.load` fails and `DeviceChannel.networkState()` is `none`, the page in
  `lib/features/reader/mushaf_view.dart` shows the new string `pageNeedsConnection` (en: "This
  page needs a connection the first time you open it."; ar: "تحتاج هذه الصفحة إلى اتصال عند فتحها
  أول مرة.") with a retry, instead of an empty page. Add a widget test in
  `test/widget/printed_lettering_test.dart`.
- [ ] T071 [US4] On the draft deploy, run quickstart V9 and V10, and re-measure SC-002 (the
  return visit, now with the service worker) on the reference devices. Update
  `specs/008-web-app/s1-results.md` and `validation.md`.

**Checkpoint**: all four stories work. The web app is ready to publish.

---

## Phase 7: Polish & Release

**Purpose**: documentation, legal, the release, and the final checks across the whole feature.

- [X] T072 [P] Write the `docs/release.md` › Web section:
  - the build commands;
  - `tool/web_deploy.mjs` (`--dry-run`, `--restore`);
  - the bandwidth report and what to do near the Netlify credit limit (research R5);
  - the rule that web releases ship from the same commit and version as the store builds
    (FR-029).
- [X] T073 [P] Update the permission drafts in `docs/permissions/` (the KFGQPC request for D1
  and D3, the QUL request for D2, and `everyayah-request.md` for D4). Widen "a free app on the
  App Store and Google Play" to add "and the free web app at https://get.mthani.app". In
  `docs/licences.md`, add the web to the D1–D4 rows' scope and list Hugging Face as the web host
  of the recognition model.
- [X] T074 [P] Draft the web section of the privacy policy in
  `C:\Users\Hamza\Documents\Mathani-landing\privacypolicy\index.html` (research R15). It says:
  - nothing is collected;
  - data stays in the browser;
  - pages come from Netlify, the model from Hugging Face and recordings from the listed hosts,
    which see the reader's IP address like any web request;
  - the microphone is used only during memorization, and its audio never leaves the device.

  Draft only; T078 publishes it.
- [X] T075 [P] Add the "Open in your browser" link to https://get.mthani.app in
  `C:\Users\Hamza\Documents\Mathani-landing\index.html` (FR-002). Draft only; T078 publishes it.
- [ ] T076 Re-run the full phone regression: quickstart V18 on the Galaxy A15 and the iPhone SE
  2, then `dart run tool/size_check.dart`, `flutter analyze` and
  `flutter test --exclude-tags web,golden`. Record the results in
  `specs/008-web-app/validation.md`.
- [ ] T077 [P] (Optional, recommended in plan.md) Run `/speckit-constitution` for a MINOR
  amendment:
  - add the web as a supported platform, with its budgets (first visit 5 s, return visit 2 s)
    and reference devices (research R17);
  - reword Principle II's "no desktop or web layout" to "no desktop layout".
- [ ] T078 **Outward-facing, confirm with the owner first**: publish the privacy policy (T074) and
  the landing link (T075) with
  `node _deploy/netlify-deploy.mjs privacypolicy/index.html index.html` from `Mathani-landing`.
  Then run quickstart V17: mthani.app and `/privacypolicy` unchanged apart from these (SC-009).
- [ ] T079 **Outward-facing, confirm with the owner first**: run the production deploy,
  `node tool/web_deploy.mjs` from the release commit, and note the deploy id in `docs/release.md`.
  Then run the full quickstart matrix once more on https://get.mthani.app and record it in
  `specs/008-web-app/validation.md`.

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: none. T005 is needed by T039 (the first draft deploy).
- **Foundational (Phase 2)**: needs T001 and T002. T024 gates every story.
- **US1 (Phase 3)**: needs Phase 2.
- **US2 (Phase 4)**: needs Phase 2. Its browser validation (T049) needs US1's deploy tooling
  (T035–T039).
- **US3 (Phase 5)**: needs Phase 2 and T045 (the OPFS `FileStore`, which the model store
  uses).
  - T052 (S2) needs T050 and T051.
  - T060 and T061 need T052's gate.
  - T064 (S3) needs T057 and T061.
- **US4 (Phase 6)**: needs US1 (`index.html`, deploy tooling). It is best done after US2 and
  US3, so the precache list and `asset-hashes.json` cover `speech/`.
- **Release (Phase 7)**: T078 and T079 need every story the owner wants to publish. A US1-only
  release is possible (see the MVP strategy below).

### Within phases

- T007 comes before T014–T018 and T022.
- T010 comes before T014, T016 and T022.
- T019 → T020 → T021.
- T011 → T012 → T024.
- T037 → T039 → T040 → T041 → T042.
- T045 → T046 and T061.
- T050 → T052 → T059 → T060 → T061 → T062 → T063 → T065.
- T067 → T068 → T069 → T071.

### Story independence

- **US1** stands alone: recitation and memorization still load on the web, but downloads and the
  model use stubs that fail as "unavailable" until US2 and US3.
- **US2** adds the OPFS store and needs nothing from US3 or US4.
- **US3** reuses US2's `FileStore`. Nothing in US1 or US2 depends on it.
- **US4** wraps whatever is built.

---

## Parallel Examples

**Phase 2** (after T007 and T010):

```text
T006 gunzip seam           T008 MemoryFileStore      T009 file_store_io_test
T013 web database tests    T021 live_follower_test   T023 platform_imports_test
```

**US1** (after T024):

```text
T025 wide_window_test   T026 keyboard_test   T027 ayah_actions_test
T029 shortcuts          T030 right-click     T031 share seam      T032 networkState    T036 _headers
```

**US2**:

```text
T043 file_store_web_test   T044 no-space queue test
```

**US3**:

```text
T053 privacy test   T054 gate test   (while T050 builds web/speech/)
```

**Polish**:

```text
T072 release docs   T073 permission drafts   T074 privacy draft   T075 landing link   T077 constitution
```

---

## Implementation Strategy

### MVP first (User Story 1)

1. Phase 1 and Phase 2, then the T024 gate (the phones unchanged).
2. Phase 3 (US1). S1 (T040) proves the load and frame budgets.
3. **Stop and validate**: run T042 across browsers.
4. Optionally publish US1 alone, through T078 and T079 with only the reading parts announced.
   Recitations and memorization show "unavailable", which SC-004 lists as a temporary exception.

### Incremental delivery

1. US1 → publish (optional).
2. US2 → validate T049 → publish.
3. US3 behind S2 and S3 → validate T065 → publish.
4. US4 → validate T071 → final publish, privacy policy and landing link (T078, T079).

Each publish is a new Netlify deploy, so any step can be rolled back with
`tool/web_deploy.mjs --restore`.

---

## Notes

- [P] tasks touch different files and have no dependency on an incomplete task.
- Commit after each task or logical group, without AI attribution lines (the owner's standing
  rule).
- Every phone-touching task in Phase 2 must leave `flutter test` green before the next one
  starts.
- Never print the Netlify token. Never commit the Hugging Face token.
