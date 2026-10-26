# Data Model: Mathani on the Web

**Feature**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

The web app keeps the phone app's data model unchanged: the same `quran.db` schema
(specs/001 contracts/quran-db.md), the same `user.db` tables, and the same recording, download
and model files. Only **where** they are kept changes. Nothing is stored on a server.

## Browser data (spec › Key Entities)

Everything is kept per browser profile, per origin (`https://get.mthani.app`).

| Store | What | Browser storage | Size | Survives a new version | Eviction |
|-------|------|-----------------|------|------------------------|----------|
| `quran.db` | Quran text, layout, reciters catalogue (read-only) | SQLite file in IndexedDB (sqflite web, R4) | 6.4 MB | Rewritten only when `quran.version` changes | Rebuilt from the cached shell on next start |
| `quran.version` | Version of the installed `quran.db` | Next to `quran.db` in the same store | bytes | Yes | With `quran.db` |
| `user.db` | Bookmarks, reading position, settings, onboarding progress, memorization results, download records | SQLite file in IndexedDB (R4) | < 1 MB | Yes, migrations as on phones | Protected by `persist()` where granted (R7) |
| Recitation cache | Recently played ayat | OPFS `recitations/cache/<reciter>/<sss><aaa>.mp3` | ≤ 100 MB, trimmed to 90 MB (specs/004) | Yes | Shown as not cached, fetched again |
| Downloads | Surahs and reciters downloaded by the reader | OPFS `recitations/<reciter>/<sss>/<aaa>.mp3`, `recitations/<reciter>/basmala.mp3` | as downloaded | Yes | Shown as not downloaded (Edge Cases); downloadable again |
| Recognition model | `model.int8.onnx`, `tokens.txt`, `silero_vad.onnx` | OPFS `asr/asr-khatma-v1/` | 134 MB | Yes; other versions deleted after an update (specs/007 FR-004) | Shown as not downloaded |
| App shell | index, bootstrap, both builds, engine, `quran.db.gz`, `sqlite3.wasm`, UI fonts, manifests | Cache Storage `shell-<version>-<build>` | ≈ 15 MB uncompressed | Replaced by the new version's cache | Fetched again online |
| Page fonts and other assets | `assets/assets/qcf/pNNN.ttf.gz` as each page is shown | Cache Storage `assets` | ≤ 130 MB, grows with pages read | Yes, unless the file's hash changed (R9) | Fetched again online |
| Speech engine | `web/speech/*` (sherpa-onnx WebAssembly, worker) | Cache Storage `assets`, on first memorization session | a few MB | Yes, unless changed | Fetched again online |

The OPFS paths mirror the phone directories (`<app cache>/recitations/…`,
`<app support>/recitations/…`, `<app support>/asr/…`). The file names and the rules for checking
size, `.part` resume and integrity are the same, through `FileStore`
([contracts/web-platform.md](./contracts/web-platform.md)).

## Validation rules carried over

- A recording counts as present only if its size matches the catalogue (specs/004). On the web an
  evicted or truncated OPFS file therefore shows as absent.
- A model file counts as present only if its size and SHA-256 match `asrModelFiles` (specs/007).
  The web checks the hash once after writing and records it. On later loads it checks the size
  only, as on phones.
- `user.db` writes go through one SQLite worker for all tabs (R4). There is no separate
  last-writer-wins logic.

## State: the web app release (spec › Web app release)

```text
published (Netlify deploy, live)
   │ reader opens get.mthani.app
   ▼
service worker: installed ──(next load)──► active ──(newer deploy found)──► waiting ──(next load)──► replaced
                                                     shell cache shell-<new> filled in background
```

- Version: `pubspec.yaml` `version`, shown in Settings › About. The build id comes from Flutter's
  `version.json`.
- Rollback: re-publishing an earlier Netlify deploy (contracts/hosting.md). Readers get it
  through the same update path as a newer version, because the build ids differ.

## State: persistent storage

```text
not asked ──(first bookmark or first download)──► asked ──► granted (no eviction)
                                                      └──► refused (data may be evicted; Settings says so)
```

- The result is kept in `user.db` settings, so the app does not ask again on every start.
- Settings › About shows "Your bookmarks, settings and downloads are kept only in this browser"
  (FR-015) in both cases.

## Supported browser list (spec › Key Entities)

These are the current and previous major versions at release time (FR-003), as tested in the
quickstart matrix:

| Browser | Desktop | Phone |
|---------|---------|-------|
| Chrome | Windows, macOS | Android |
| Edge | Windows | — |
| Firefox | Windows, macOS | Android |
| Safari | macOS | iOS |

The list is kept in one place, `lib/platform/supported_browsers.dart`. The unsupported page in
`web/index.html` repeats the names, and the deploy script checks the two match.
