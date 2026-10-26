# Contract: Platform Seams for the Web

**Feature**: [../spec.md](../spec.md) | **Research**: R3, R7, R8, R10, R11, R16

> **Updated in implementation (2026-10-26)**: see research.md › Changes made during
> implementation. In short:
> - `FileStore` gained `copy`, `deleteDir`, `touch` and `locate`, and works with `StoreFile`
>   values. `protect` takes a root and a directory.
> - `DeviceChannel` keeps `deviceSupport()` and adds `webSupport()` (null on phones) and
>   `keepBrowserData()`.
> - There is no `AsrStore`: `lib/platform/speech_host_*.dart` exposes `newSpeechRecogniser()`,
>   `unpackModel()` and `speechEngineAvailable`.
> - The speech worker's `load` message carries only `{type, dir}` (the OPFS folder of the saved
>   model). The worker does not download, and sends `loaded`, `error` (`unsupported`, `memory`,
>   `failed`) and `heard`.
> - The database seam adds `databasePath()` and `parallelDatabaseOpen`.
> - The engine is sherpa-onnx's own WebAssembly build (`sherpa_onnx_web`), not a separate build.

Each seam has one interface and two implementations, chosen by a conditional import:

```dart
import 'file_store_io.dart' if (dart.library.js_interop) 'file_store_web.dart';
```

The phone implementations wrap today's code without changing its behaviour. The web
implementations live in `lib/platform/*_web.dart` and are the only files that import
`package:web`, `dart:js_interop` or `sqflite_common_ffi_web`.

## `lib/platform/`

| File pair | Exposes | Phone (`_io`) | Web (`_web`) |
|-----------|---------|---------------|--------------|
| `database_*.dart` | `Future<void> initDatabases()`, `Future<String> installQuranDb(String bundledVersion)` | today's copy-if-version-changed code from `QuranRepository.open` | sets `databaseFactory = databaseFactoryFfiWeb`; fetches `assets/assets/db/quran.db.gz`, inflates it, `writeDatabaseBytes` only when the version changed (R4) |
| `gunzip_*.dart` | `Future<Uint8List> gunzip(Uint8List gz)` | `dart:io` `gzip` | `DecompressionStream('gzip')` |
| `file_store_*.dart` | `FileStore` (below) | `dart:io` under `path_provider` roots | OPFS (R7) |
| `device_*.dart` | `DeviceFacts` (below) | today's `DeviceChannel` method channel | browser APIs (R16) |
| `speech_host_*.dart` | `SpeechRecogniser` factory | `SherpaSpeechRecogniser` (isolate + FFI) | `WebSpeechRecogniser` (Web Worker, below) |
| `share_*.dart` | `Future<void> shareText(String text, BuildContext context)` | `share_plus` | `navigator.share` when present, otherwise copy and toast |

`PrintedFonts.inflate` and `tool/web_preview.dart`'s swaps are removed in favour of these.

## FileStore

Replaces `File`/`Directory` in `ayah_fetcher.dart`, `download_queue.dart`, `asr_model.dart`,
`recitation_controller.dart` and `downloads_screen.dart`. Paths are relative and `/`-separated.
Each root maps to a phone directory or an OPFS directory.

```dart
enum StoreRoot { cache, support } // getApplicationCacheDirectory / getApplicationSupportDirectory

abstract class FileStore {
  /// Size in bytes, or null when the file does not exist.
  Future<int?> length(StoreRoot root, String path);

  /// Appends [chunks] to `path`, creating it; used for `.part` files and resumed downloads.
  Future<void> append(StoreRoot root, String path, Stream<List<int>> chunks);

  /// Atomically replaces `to` with `from` (the `.part` → final step).
  Future<void> rename(StoreRoot root, String from, String to);

  Future<void> delete(StoreRoot root, String path, {bool recursive = false});

  /// Entries directly under `dir`, with sizes; empty when `dir` does not exist.
  Future<List<({String name, int bytes, bool isDir})>> list(StoreRoot root, String dir);

  /// Reads a file as a stream of chunks (hashing, unpacking).
  Stream<List<int>> read(StoreRoot root, String path);

  /// A URI the audio player can play: `file://` on phones, a `blob:` URL on the web. The caller
  /// releases it with [release] when the item leaves the playlist (no-op on phones).
  Future<Uri> playableUri(StoreRoot root, String path);
  void release(Uri uri);

  /// Free bytes for downloads (phones: the device channel; web: estimate quota − usage).
  Future<int> freeBytes();

  /// Phones: excludes the support root from iCloud backup. Web: asks for persistent storage
  /// (R7), once.
  Future<void> protect();
}
```

`append` throws `NoSpaceException` when the disk or the browser quota is full. The fetcher and
the model download map it to their existing "no space" errors. HTTP goes through
`package:http`'s `Client` on both platforms (research R18a).

**Rules**:
- Every existing invariant holds on both implementations: size match against the catalogue,
  `.part` + rename, resume from the `.part` length, cache trim to 90 MB, integrity re-check, and
  the damaged-file stream.
- `test/support/memory_file_store.dart` is an in-memory `FileStore` for VM tests. Existing
  fetcher, queue and model tests move onto it, and the `io` implementation gets its own
  temp-directory tests.
- The web `append` uses `FileSystemWritableFileStream` with `keepExistingData: true`. A failed
  write with `QuotaExceededError` is reported as the existing "no space" error (spec US2
  scenario 4) and deletes the `.part`.

## DeviceFacts

The same members as today's `DeviceChannel`: `networkState`, `freeBytes`, `excludeFromBackup`,
`deviceSupport`, `openAppSettings`, `playMistakeTone`. The constructor is unchanged for callers.

| Member | Web behaviour |
|--------|---------------|
| `networkState()` | `none` when `!navigator.onLine`. `metered` when `navigator.connection?.type == 'cellular'` or `saveData`. Otherwise `unmetered`. |
| `freeBytes()` | `FileStore.freeBytes()` |
| `excludeFromBackup()` | no-op |
| `deviceSupport()` | returns `WebSupport` (below) instead of `(arm64, ramBytes)`; `memorizationSupport` maps it to `Unsupported.browser` or `Unsupported.lowMemory` |
| `openAppSettings()` | does nothing; the explainer shows the browser's steps instead (R11) |
| `playMistakeTone()` | 120 ms, 880 Hz Web Audio tone at the same loudness as the phone tone |

```dart
/// Null fields: the browser does not report them.
typedef WebSupport = ({bool wasmSimd, bool audioWorklet, bool opfs, int? deviceMemoryGb});
```

`Unsupported.browser` gets a new message in `l10n` (Arabic and English) that names the supported
browsers (FR-026).

## Speech worker (web)

`WebSpeechRecogniser implements SpeechRecogniser` (specs/007 contracts/live-recognition.md) keeps
the same public behaviour as `SherpaSpeechRecogniser`: `load`, `accept`, `heard`, `commit`,
`flush`, `reset` and `dispose`.

### Files

| File | What |
|------|------|
| `web/speech/speech_worker.js` | Worker bootstrap. Imports the sherpa-onnx glue, then `speech_worker.dart.js`. |
| `web/speech/sherpa-onnx-wasm-main-vad-asr.{js,wasm}`, `sherpa-onnx-asr.js`, `sherpa-onnx-vad.js` | sherpa-onnx **1.13.8** WebAssembly (SIMD, single thread), built by `tool/build_sherpa_wasm.sh` (R10) |
| `web/speech/speech_worker.dart.js` | `dart compile js -O2 lib/features/memorization/web_worker_main.dart`, run by the web build step |
| `lib/features/memorization/live_follower.dart` | today's `_Worker` logic over `SpeechEngine`, shared by both platforms |

### SpeechEngine (shared)

```dart
abstract class SpeechEngine {
  void vadAccept(Float32List window);      // exactly vadWindow samples
  bool get vadDetected;
  bool get vadEmpty;
  ({int start, int length}) vadFront();     // start and length in samples
  void vadPop();
  void vadFlush();
  void vadReset();
  /// Decodes [audio] at micSampleRate; tokens and their start times in seconds.
  ({List<String> tokens, List<double> timestamps}) decode(Float32List audio);
  void free();
}
```

`LiveFollower(SpeechEngine engine, void Function(Heard) send)` holds what `_Worker` holds today
and exposes `accept`, `commit`, `flush` and `reset`. The constants (`vadThreshold`,
`livePassEvery`, `liveContext` and the others) stay in `speech_recogniser.dart` and are shared.

### Messages (`postMessage`)

The main thread sends:

| Message | Payload |
|---------|---------|
| `load` | `{type: 'load', base: '<HF base URL>', files: [{name, bytes, sha256, unpackedBytes?, unpackedSha256?}], version}` |
| `samples` | `Float32Array`, transferred |
| `commit` | `{type: 'commit', pass, fromSample}` |
| `flush`, `reset`, `dispose` | `{type}` |

The worker sends:

| Message | Payload |
|---------|---------|
| `progress` | `{type: 'progress', received, total}` while downloading or unpacking the model |
| `loaded` | `{type: 'loaded'}` |
| `error` | `{type: 'error', code: 'failed' \| 'damaged' \| 'noSpace' \| 'memory' \| 'unsupported'}` |
| `heard` | `{type: 'heard', pass, hearing: 'live' \| 'pause', windowStart, endSample, words: [{text, startSample, endSample}]}` |

**Rules**:
- Audio, transcripts and words never leave the worker except as `heard` messages to the page.
  The worker's only network requests are the model files at `base` (FR-024, SC-007).
- On the web, `AsrModel` keeps the same public states and errors (`absent`, `partial`,
  `downloading`, `ready`; `failed`, `damaged`, `noSpace`). It delegates download, unpack and
  verification to the worker, so the download sheet and Settings › Downloads work unchanged.
- A `memory` error during `load` maps to `Unsupported.lowMemory`. An `unsupported` error maps to
  `Unsupported.browser`.

## Model source

```dart
const asrModelBase = kIsWeb
    ? 'https://huggingface.co/hamzagamil/mathani-asr/resolve/<commit>/$asrModelVersion/'
    : 'https://github.com/hamzagamil/mathani/releases/download/$asrModelVersion/';
```

The files and checksums are `asrModelFiles`, unchanged. `<commit>` is pinned: a new model is a
new `asrModelVersion` and a new commit (tool/README.md gains the upload step).
