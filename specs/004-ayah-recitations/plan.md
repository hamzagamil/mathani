# Implementation Plan: Ayah-by-Ayah Recitations

**Branch**: `004-ayah-recitations` | **Date**: 2026-10-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/004-ayah-recitations/spec.md`

## Summary

Mathani's first audio: the Quran recited ayah by ayah by Al-Husary or El-Minshawi (Murattal),
with the recited ayah highlighted in the Mushaf as the reader follows along. Streaming works
everywhere, and surahs can be downloaded for offline listening.

1. **Source** (research R1, R2, R6): EveryAyah's per-ayah MP3s. Al-Husary uses 64 kbps (1.23 GB
   whole Quran), El-Minshawi 128 kbps (1.67 GB), with a mirror host as fallback. A build tool
   records every file's size into `quran.db`. That gives download sizes offline, a completeness
   check for every file, and a build that fails if any ayah is missing. Permission is a new
   dependency, **D4**, which gates release.
2. **Playback** (R3, R4, R5): `just_audio` (gapless sliding playlist) and `audio_service` (lock
   screen, notification, headset, background). The player only plays **local files**. A fetcher
   resolves each ayah from downloads, then a 100 MB recent cache, then the network, and keeps 3
   ayat ahead. This is how "never skip an ayah" is guaranteed on both platforms.
3. **Following** (R9, R10): a `RecitationController` beside `ReaderController` drives a new
   `recited` highlight and follow jumps through the existing `jumpTo`. Any other navigation turns
   following off, and "Back to recitation" turns it on again. A docked recitation bar never
   covers Quran text. The page refits once when the bar appears.
4. **Downloads** (R7, R8): per surah, state derived from the files on disk (no table). Downloads
   are resumable at ayah granularity, run 2 at a time, and only in-process. Before starting, a
   tiny platform channel checks for metered networks and free space.

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned). Small Kotlin and Swift additions
for the device channel and the audio_service setup.

**Primary Dependencies**:
- Existing: `sqflite`, `share_plus`, `url_launcher`, `wakelock_plus`, `intl`.
- **New**:
  - `just_audio` ^0.10.6;
  - `audio_service` ^0.18.19;
  - `audio_session` ^0.2.4 (direct, for configuration; it is already a transitive dependency of
    both);
  - transitive, through `audio_service`: `flutter_cache_manager` (with `http`, `uuid` and
    others). `audio_service` uses it only to download artwork from `http` URIs. The app passes a
    local `file://` artwork URI, so it is never used at runtime, but its code ships. Its size is
    included in the T063 size report.
  - `path_provider` (direct; already transitive through `sqflite` and `just_audio`).

  Justified in research R3 and R4 and in Complexity Tracking. Downloads use `dart:io`
  `HttpClient`, with no HTTP package.

**Storage**:
- `quran.db`: two new tables, `reciters` and `recitation_files` (12,472 rows).
- `user.db`: one preference key, `reciter`. No schema change.
- Audio files: a cache directory (100 MB LRU) and the app support directory (downloads).

**Testing**: `flutter_test` unit and widget tests with a fake player, a localhost `HttpServer`
and a fake device channel. Existing goldens are kept. Integration profile runs on the reference
phones, plus the device scenarios in [quickstart](./quickstart.md).

**Target Platform**: iOS 15.0+ and Android 7.0 (API 24)+, target API 36. Phones, portrait.

**Project Type**: mobile app (single Flutter project; no backend of our own; a third-party CDN
for audio).

**Performance Goals**:
- First ayah audible ≤ 2 s on 4G or Wi-Fi in 95% of starts (SC-001).
- ≤ 150 ms added between ayat (FR-009).
- Controls react in ≤ 100 ms.
- 60 fps paging while playing.
- Cold start unchanged at ≤ 2 s (audio is initialised on first play).

**Constraints**:
- Never skip or repeat an ayah.
- Recordings unaltered.
- Reading stays fully offline.
- No personal data sent.
- Foreground service only while playing.
- No background downloads after suspension.
- Store download growth reported if over 1 MB.

**Scale/Scope**:
- 2 reciters, each with 6,236 ayat plus the basmala.
- 114 downloadable surahs per reciter, from 0.2 MB to about 131 MB each.
- New UI: 1 bar, 1 sheet, 1 Settings section, 1 Downloads screen.
- Changes to the toolbar, ayah actions, Surahs index, renderer and flowing view.
- 1 new build tool.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution v2.0.0, which removed the 30 MB budget; `tool/size_check.dart` checks only growth
over 1 MB against `docs/size_baseline.json` (updated 2026-10-24).

| Principle | Gate | Pre-research | Post-design |
| --- | --- | --- | --- |
| I. Cross-Platform Parity | Same on iOS and Android; platform conventions | ✅ | ✅ Both plugins support iOS 15 and API 24. Interruptions, lock screen and media notification follow each platform's convention (R3, R4). The device channel is implemented on both. Quickstart runs every scenario on both phones plus an API 24 emulator. |
| II. Mobile-First Design | Phone portrait; 44 pt / 48 dp; safe areas; dark mode; font scaling; screen readers | ✅ | ✅ The bar is in one-handed reach with 48 dp targets, and is laid out within the safe area. Night palette includes `recited`. Q-22 (largest font) and Q-21 (VoiceOver/TalkBack). Ayah changes are not announced, so screen-reader use isn't interrupted. |
| III. Performance (NON-NEGOTIABLE) | ≤ 2 s cold start; 60 fps; ≤ 100 ms feedback; no UI-thread blocking | ✅ | ✅ `AudioService.init` and the audio session are deferred to the first play. The catalogue is read lazily per surah. Download state is scanned on a background isolate. Repaint happens once per ayah. State changes come before platform calls (≤ 100 ms). The paging perf test reruns with audio playing. |
| IV. Lean by Default | Dependencies justified; > 1 MB growth called out; on-demand content; minimal background, battery and data | ✅ | ⚠️ Two dependencies (justified below). Android growth is expected at about 1–1.5 MB (Media3) and **will be called out** with the measured number. Audio is never bundled. Al-Husary uses 64 kbps to halve data. The 100 MB cache is capped and clearable. The foreground service runs only while playing. Downloads run only while the process runs. |
| V. Simplicity | Simplest solution; reuse; complexity justified | ✅ | ⚠️ A fetcher and a sliding playlist instead of plain URL streaming, and a small platform channel. Both are justified below. Reuses `jumpTo` and `jumpSerial`, the highlight path, the preferences table and the HTTP code of `dart:io`. No download table. |
| Store & privacy | Policies; permissions only when needed; graceful degradation | ✅ | ⚠️ First network use. New Android install-time permissions (`INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`); no runtime prompts. iOS `UIBackgroundModes: audio`. Still "no data collected". `docs/store/privacy.md` and the privacy policy are updated before release (R11). |

**Result**: PASS, with the items in Complexity Tracking. **Release is gated on D4** (audio
permission). Development is not.

## Project Structure

### Documentation (this feature)

```text
specs/004-ayah-recitations/
├── plan.md              # This file
├── research.md          # R1–R11: source, basmala, engine, background, fetch/cache, catalogue,
│                        #   downloads, device channel, following, bar placement, size/privacy
├── data-model.md        # Reciter, catalogue, preference, files on disk, download states, session
├── quickstart.md        # catalogue build, tests, 23 device scenarios, perf/size gates, release
├── contracts/
│   ├── recitation-catalogue.md   # build tool, quran.db tables, repository API, URLs
│   ├── audio-storage.md          # resolve order, cache, DownloadQueue, preconditions, channel
│   ├── recitation-playback.md    # controller API, states, playlist, following, session, media
│   └── recitation-ui.md          # toolbar, bar, reciter sheet, ayah action, index, settings, strings
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks; not created here)
```

### Source Code (repository root)

```text
lib/
├── features/recitation/                  # NEW feature folder
│   ├── recitation_controller.dart        # session, item order, follow logic, RecitationScope
│   ├── recited_item.dart                 # RecitedItem + next/previous order (pure Dart)
│   ├── audio_engine.dart                 # just_audio player, sliding playlist, audio session
│   ├── media_handler.dart                # audio_service AudioHandler → controller
│   ├── ayah_fetcher.dart                 # resolve: downloads → cache → network; LRU cache
│   ├── download_queue.dart               # per-surah downloads, state from disk
│   ├── recitation_bar.dart               # docked player bar
│   ├── reciter_sheet.dart                # reciter picker
│   └── downloads_screen.dart             # Settings › Downloads
├── features/reader/
│   ├── reader_screen.dart                # Listen button; dock the bar; inset the Mushaf view
│   ├── mushaf_view.dart                  # pass `recited`; follow jumps
│   ├── mushaf_page_renderer.dart         # third highlight (recited), basmala-line highlight
│   ├── flowing_view.dart                 # recited background; ensureVisible on follow jumps
│   └── ayah_actions.dart                 # "Play from this ayah"
├── features/index/surahs_tab.dart        # downloaded mark; surah menu (download/stop/delete)
├── features/settings/
│   ├── settings_screen.dart              # Recitations section
│   └── about_section.dart                # recitation attribution
├── data/
│   ├── models.dart                       # Reciter; ReaderPreferences.reciter
│   ├── quran_repository.dart             # reciters, recordingBytes, surahDownloadBytes
│   └── user_repository.dart              # `reciter` key
├── shared/
│   ├── device_channel.dart               # NEW: networkState(), freeBytes()
│   └── mathani_icons.dart                # play, pause, skip-back, skip-forward, x, download, check
├── app/
│   ├── app.dart                          # create RecitationController + scope
│   ├── theme/tokens.dart, app_theme.dart # `recited` colour, day and night
│   └── l10n/app_ar.arb, app_en.arb       # strings in contracts/recitation-ui.md
tool/
├── build_recitation_manifest.dart        # NEW
├── recitations.json                      # NEW: reciter definitions (committed)
├── sources/recitations/<reciter>.json    # NEW: generated sizes (pinned in sources.lock.json)
└── build_quran_db.dart                   # + reciters, recitation_files
android/app/src/main/
├── AndroidManifest.xml                   # permissions, AudioService, MediaButtonReceiver
└── kotlin/app/mathani/mathani/MainActivity.kt   # AudioServiceActivity; device channel
ios/Runner/
├── Info.plist                            # UIBackgroundModes: audio
└── AppDelegate.swift                     # device channel (NWPathMonitor, free space)
test/unit/    recited_item_order_test, ayah_fetcher_test, download_queue_test, recitation_controller_test
test/widget/  recitation_bar_test, recitation_highlight_test, downloads_screen_test
integration_test/paging_perf_test.dart    # WITH_RECITATION variant
docs/licences.md                          # D4 + attribution row
docs/permissions/everyayah-request.md     # NEW: request draft
docs/store/privacy.md                     # network use, permissions, background audio
```

**Structure Decision**: a new `lib/features/recitation/` folder holds everything audio. It
follows the existing per-feature layout. The reader, index and settings get small hooks into it.
The pure-Dart pieces (`recited_item.dart`, fetcher and queue logic) are kept separate from the
plugins so they can be unit tested without devices.

## Delivery Order

1. **Catalogue**: `tool/recitations.json`, the manifest tool, the `quran.db` tables and the repository
   API. Run the tool and confirm 6,236/6,236 for both reciters.
2. **Listen and follow** (User Story 1, plus the default reciter from US2): item order, fetcher
   with cache, audio engine, controller, bar, highlight, follow, Listen button and ayah action.
   Shippable alone, once D4 is granted.
3. **Choose a reciter** (US2): reciter sheet, preference, mid-session switch.
4. **Background** (US3): audio_service handler, platform setup, interruptions. Can ship with 2–3.
5. **Downloads** (US4): device channel, DownloadQueue, index menu and mark, Settings section,
   Downloads screen, offline resolve paths.
6. **Release prep**: D4 request, attribution, privacy docs, size report, quickstart run on both
   phones.

## Risks & Open Dependencies

| ID | Risk | Impact | Mitigation |
| --- | --- | --- | --- |
| D4 | No stated licence on EveryAyah; permission needed from the Quran.com Foundation | **Blocks release** | Send `docs/permissions/everyayah-request.md` now via the help desk. Fallbacks if refused or required: self-hosting under terms they set, or another licensed source. The catalogue design takes any `base_url`. |
| R-1 | The CDN throttles or changes URLs | Playback or downloads fail | Concurrency ≤ 2 (app) and 4 (tool), backoff, mirror fallback, clear retry UI. Files have been unchanged since 2023. A URL move means a catalogue update in the next release. |
| R-2 | Android size growth over 1 MB (Media3) | Principle IV call-out | Measure with `size_check`. Confirm R8 strips unused Media3 modules (HLS, DASH, RTSP are not used). Report in the PR. |
| R-3 | A double basmala, if some 2:1-style files include it (V-1) | Wrong recitation | Q-3 listening check on 10 surah starts per reciter before release. If found, add a per-reciter `basmala_in_ayah1` flag to `reciters`. |
| R-4 | Page refit when the bar appears changes the text size on short phones | Brief visual change | It happens once per session start and stop, never during playback. Checked in Q-22. |
| R-5 | Downloads paused by iOS suspension surprise readers | Resume needed | The paused state shows a clear "Resume". Downloads continue while a recitation keeps the app alive. Revisit with a background-transfer API only if readers ask. |

## Complexity Tracking

| Addition | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| `just_audio` + `audio_service` (+ about 1–1.5 MB on Android, including `audio_service`'s transitive `flutter_cache_manager`) | Gapless per-ayah playback, interruptions, lock screen and notification, background audio on both platforms (FR-009, FR-015–017) | `audioplayers` has no gapless playlist. Writing native players and media sessions on both platforms is far more code. `just_audio_background` is beta and cannot route next/previous through our ayah order. |
| Fetch-to-file with a sliding playlist, instead of streaming URLs | "Never skip an ayah" (FR-007, FR-020) behaves the same on both platforms. One code path for streaming, cache and downloads (FR-021). | Direct URL streaming skips or stalls differently on ExoPlayer and AVQueuePlayer and would need its own cache. `LockCachingAudioSource` is experimental. |
| `app.mathani/device` platform channel (about 40 lines per platform) | Metered network and free-space checks before downloads (FR-028), and an instant offline message (SC-008) | Two plugins (`connectivity_plus` plus a disk-space plugin) cost more in size and manifests, and "mobile" is not "metered". |
| Catalogue of 12,472 file sizes in `quran.db` (about 0.1 MB) | Offline download sizes, completeness checks, and a build that fails on missing ayat (FR-002, FR-028, FR-031, SC-003) | Runtime HEAD requests give no offline sizes and are slow (286 requests for Al-Baqarah). Hashes would cost 4× the space and a 2.9 GB build download. |

**Measured (T063, 2026-10-24, Android arm64 `appbundle --release`)**: download size 139.12 MB →
140.21 MB, **+1.09 MB**. Code (dex: Media3 ExoPlayer, audio_service, audio_session and its
transitive flutter_cache_manager) +579 KB; Dart AOT (feature code and packages) +460 KB; assets
(recitation catalogue in `quran.db`) +75 KB. Over the 1 MB line by 0.09 MB: called out here and
to be stated in the PR (Principle IV, SC-007). iOS not measured yet (needs a Mac).
