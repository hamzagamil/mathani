# Implementation Plan: All Available Reciters and Memorization Mode

**Branch**: `006-reciters-memorization` | **Date**: 2026-10-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/006-reciters-memorization/spec.md`

## Summary

Two additions on top of feature 004's recitations.

1. **All reciters** (research R0–R5, R18, R19; plan run 2 adds QUL at the owner's request):
   - **51 entries (49 new)**, one per reciter and style (Murattal, Mujawwad, teaching). This is
     every complete Hafs recitation on **QUL** or **EveryAyah** that can be followed ayah by ayah.
   - **What QUL adds**: QUL lists 133 recitations, but only 8 are new and usable.
     - Its 18 ayah-by-ayah sets are EveryAyah's own files (checked byte for byte), except
       Al-Nufais.
     - 68 surah sets have no ayah timings, or are Taraweeh, translations or other narrations.
     - QUL adds Al-Nufais (ayah files) and **7 reciters or styles that exist only as timed surah
       files**: Bandar Baleela, Khalid Al-Jalil, Hady Toure, Mansour Al-Salimi, Mostafa Ismail,
       the Husary Ijazah and Minshawi with children.
   - **Surah files as ayah clips** (R18): these files are constant-bitrate, so the build turns
     QUL's ayah timings into exact frame-aligned byte offsets. At runtime each ayah is fetched
     with an HTTP `Range` request into the usual per-ayah file. The 004 engine is unchanged:
     cache, downloads, gapless playlist, "never skip". The app never calls QUL's servers; it
     only streams audio from their CDNs.
   - **Same recording on both sources**: the EveryAyah folder at the lowest bitrate ≥ 64 kbps is
     used. It is the same audio at up to half the data, and existing `husary` downloads stay valid.
   - **Catalogue size**: recording sizes move to one packed BLOB per reciter and surah, about
     0.9 MB instead of about 1.9 MB.
   - **Reciter sheet**: becomes a searchable list.
   - **Unchanged**: playback, following, background play and downloads.
2. **Memorization mode** (R6–R16):
   - The reader picks a range in one surah and recites from memory.
   - Recognition runs **on the device**: `sherpa_onnx` 1.13.8 with Tarteel's Quran-tuned
     Whisper tiny (int8, Apache-2.0), Silero VAD, and `record` for microphone PCM. The model is a
     one-time ≈ 61.5 MB download from the project's GitHub Releases; after that, memorization works
     offline. No audio is ever written or sent.
   - A pure-Dart `RecitationMatcher` aligns the decoded words with the ayah's imla'i reference
     words. It accepts repeats, restarts, pauses and an opening isti'adha or basmala, and
     declares missed, wrong or added words only from finished segments. After a mistake the
     reader carries on from the wrong word.
   - Ayat are hidden in place (no reflow) and revealed as completed. "Next word" and "Show this
     ayah" give help.
   - Mistakes are signalled on screen, plus vibration, sound or neither.
   - The result gives a score out of 100 (1 / 0.5 / 0.25 / 0) and a review.

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned). Small Kotlin and Swift additions to
the existing `app.mathani/device` channel. A Python script, run once by a maintainer, to export
the model.

**Primary Dependencies**:
- **Existing**: `just_audio`, `audio_service`, `audio_session`, `sqflite`, `path_provider`,
  `url_launcher`, `share_plus`, `wakelock_plus`, `intl`.
- **New**:
  - `sherpa_onnx` 1.13.8 (Apache-2.0), with its per-platform packages and onnxruntime (MIT):
    on-device VAD and Whisper (R6, R7);
  - `record` 7.1.2 (MIT): microphone PCM stream (R10).

  Both are justified in Complexity Tracking.

**Storage**:
- `quran.db`:
  - `reciters` grows to 51 rows, with new columns `source`, `file_pattern` and
    `basmala_in_ayah1`;
  - `recitation_files` is replaced by `recitation_sizes`: 5,814 rows of packed sizes, plus
    `range_start` for QUL surah files.
- `user.db`: new preference key `mistake_signal`.
- Files: recognition model (61.5 MB, measured in T029) in the app support directory, excluded from backup.
- No session data is stored.

**Testing**: `flutter_test` unit and widget tests. Fakes for the recogniser and the device
channel, a localhost `HttpServer` for the model download, and goldens for the hidden page. A
property test of the matcher over all 6,236 ayat. Spike S1 on recorded test sets on the
reference phones. Device scenarios in [quickstart](./quickstart.md).

**Target Platform**: iOS 15.0+ and Android 7.0 (API 24)+, target API 36. Phones, portrait.
Memorization additionally needs arm64 and ≥ 3 GB RAM (R15). It is unavailable, with a message,
elsewhere.

**Project Type**: mobile app (single Flutter project). Third-party hosts:
- **Audio**: EveryAyah's CDN, plus `download.quranicaudio.com` (Quran.com Foundation) and
  `audio-cdn.tarteel.ai` (Tarteel).
- **Model**: GitHub Releases.
- **QUL's website**: used only at build time, by a maintainer.

**Performance Goals**:
- Reciter search ≤ 100 ms per keystroke, 60 fps list (SC-002).
- Ayah revealed ≤ 1 s after the reader finishes it in 95% of cases (SC-007).
- Pause, resume and end ≤ 100 ms (FR-021).
- Result ≤ 1 s (SC-008).
- 60 fps paging during a session (SC-010).
- Recogniser load ≤ 1.5 s at session start.
- Cold start unchanged (≤ 2 s): nothing new on the startup path.

**Constraints**:
- **Privacy**: voice on the device only; no audio on disk; mic on only while listening (FR-019,
  FR-020).
- **Reveal rules**: never reveal an unrecited word or ayah (SC-006).
- **No background work**: nothing runs in the background.
- **Accuracy**: ≥ 95% on SC-004 and SC-005 on the device, or stop and report.
- **Size**: store growth over 1 MB is called out (≈ +11 MB expected).

**Scale/Scope**:
- **Catalogue**: 51 reciters × 6,236 ayat. One manifest run: about 255,000 HEAD requests
  (EveryAyah and QUL ayah files) and about 44,000 small range reads (QUL surah files).
- **New UI**: range sheet, mic explainer, memorization bar, result screen, 1 Settings row, 1
  Downloads row, a reworked reciter list.
- **Reader changes**: hidden words, hint and mistake marks in both layouts; 2 entry points.
- **Native**: 3 device-channel methods.
- **New code**: about 9 files in `lib/features/memorization/`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution v2.0.0.

| Principle | Gate | Pre-research | Post-design |
| --- | --- | --- | --- |
| I. Cross-Platform Parity | Same on iOS and Android; platform conventions; OS versions stated | ✅ | ✅ Both dependencies support iOS ≥ 13 and API ≥ 21, below our 15.0 and 24. The device gate (arm64 and ≥ 3 GB) is the same rule on both platforms, with no parity gap. Permission prompts, Settings deep links and silent-mode behaviour follow each platform (R10, R12). Every quickstart scenario runs on both phones. |
| II. Mobile-First Design | Portrait; 44 pt / 48 dp; safe areas; dark mode; font scaling; screen readers | ✅ | ✅ The bar is docked like the recitation bar, with 48 dp buttons in one-handed reach. New `hint` and `mistake` tokens for day and night. Hidden ayat have semantics and reveals are announced (Q-20). Largest font checked (Q-21). The pulse respects reduce motion. |
| III. Performance (NON-NEGOTIABLE) | ≤ 2 s cold start; 60 fps; ≤ 100 ms feedback; no UI-thread blocking | ✅ | ✅ Decoding runs on a background isolate. The model loads at session start, never at app start. Repaint happens once per reveal. Hidden words keep their layout, so no reflow. Controls change state before platform calls. The paging perf test reruns with a session listening. The reciter list is lazily built. |
| IV. Lean by Default | Dependencies justified; > 1 MB growth called out; large content on demand; minimal background and battery | ✅ | ⚠️ **≈ +11 MB store growth per platform** (Android measured: +9.59 MB per arm64 phone, approved 2026-10-24): onnxruntime and sherpa-onnx ≈ 10 MB, catalogue ≈ 0.8 MB, `record` ≈ 0.1 MB. QUL surah recordings add no dependency; they reuse the 004 fetcher with a `Range` header. Same-recording duplicates use the lower-bitrate copy (R0). Called out below; **owner approval required in review**. The model (61.5 MB) is downloaded on demand, never bundled. The mic and decoding run only while listening. Nothing runs in the background. |
| V. Simplicity | Simplest approach; reuse; complexity justified | ✅ | ⚠️ A new engine (recogniser isolate + matcher) is unavoidable for the feature. QUL surah files are served as ayah clips through the existing 004 engine, not a second player (R18). Reused: `normalizeArabic`, `ayahs.search_text` and `search_offset` as reference words, the device channel, the download preconditions and sheet, the bar docking, `jumpTo`, preferences, and the reciter sheet entry point. No new tables for sessions. |
| Store & privacy | Policies; permissions in context; graceful degradation | ✅ | ⚠️ New runtime permission: microphone, asked in context after an explainer, with graceful denial (R10). "Audio processed on device, not collected" (R16). New hosts: GitHub Releases (model only), `download.quranicaudio.com` and `audio-cdn.tarteel.ai` (recordings). No identifiers are sent (004 FR-023). Store answers and the privacy policy are updated before release. |

**Result**: **PASS**, with the items in Complexity Tracking. The **size growth needs the owner's
explicit approval** (Principle IV): approved on 2026-10-24 for the measured +9.59 MB per Android
phone (S2, T027). Release measurement (T058): +10.52 MB per arm64 phone and +10.8 MB for the iOS
.ipa, everything in 006 included. Release stays **gated on D4** (Quran.com Foundation: 43
EveryAyah recordings and 5 quranicaudio surah recordings) **and D2** (QUL / Tarteel: timings for 7
recordings, 3 Tarteel-hosted recordings).

## Project Structure

### Documentation (this feature)

```text
specs/006-reciters-memorization/
├── plan.md              # This file
├── research.md          # R0 QUL vs EveryAyah; R1–R5 selection, styles, packing, list;
│                        #   R6–R17 ASR, model, mic, matcher, signals, hiding, lifecycle, gate,
│                        #   privacy, licences; R18–R19 QUL surah files as ayah clips
├── data-model.md        # Reciter, recitation_sizes, preferences, model files, range, session,
│                        #   progress, result
├── quickstart.md        # spikes S1/S2, catalogue build, model export, tests, 22 device scenarios
├── contracts/
│   ├── reciter-catalogue.md   # sources, build, schema, clip fetching, 51 rows, reciter list UI
│   ├── memorization-engine.md # model, recogniser, matcher rules, controller, device channel
│   └── memorization-ui.md     # entry points, range sheet, explainer, bar, result, settings, strings
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks; not created here)
```

### Source Code (repository root)

```text
lib/
├── features/memorization/                 # NEW
│   ├── asr_model.dart                     # download/verify/delete the model; pinned hashes
│   ├── device_support.dart                # arm64 + RAM gate
│   ├── mic_source.dart                    # record → Float32List, tone gating
│   ├── speech_recogniser.dart             # sherpa-onnx VAD + Whisper on an isolate
│   ├── recitation_matcher.dart            # pure Dart alignment and mistakes
│   ├── memorization_score.dart            # pure Dart result
│   ├── memorization_controller.dart       # session, lifecycle, signals; MemorizationScope
│   ├── memorization_bar.dart              # docked bar
│   ├── range_sheet.dart                   # surah / from / to; model row
│   ├── mic_explainer.dart                 # pre-permission sheet
│   └── result_screen.dart                 # score, counts, review
├── features/recitation/
│   ├── reciter_sheet.dart                 # searchable ReciterList (51 rows)
│   ├── ayah_fetcher.dart                  # Range requests for qul_surah clips; no mirror
│   ├── recitation_controller.dart         # skip the basmala item when basmalaInAyah1
│   └── downloads_screen.dart              # + memorization model row
├── features/reader/
│   ├── reader_screen.dart                 # Memorize button; dock the memorization bar
│   ├── mushaf_page_renderer.dart          # hidden / hint / mistake painting
│   ├── mushaf_view.dart, flowing_view.dart# pass the memorization predicates; follow jumps
│   └── ayah_actions.dart                  # "Memorize from this ayah"
├── features/onboarding/                   # reciter step uses ReciterList; tour hint for Memorize
├── features/settings/settings_screen.dart # Mistake alert row
├── features/settings/about_section.dart   # new licence texts
├── data/models.dart                       # Reciter source/filePattern/basmalaInAyah1; mistakeSignal
├── data/quran_repository.dart             # recordingBytes from recitation_sizes; clipRange
├── data/user_repository.dart              # mistake_signal key
├── shared/device_channel.dart             # deviceSupport, openAppSettings, playMistakeTone
├── shared/mathani_icons.dart              # brain, lightbulb (hint), eye (show)
├── app/app.dart                           # MemorizationScope
├── app/theme/tokens.dart, app_theme.dart  # hint, mistake
└── app/l10n/app_ar.arb, app_en.arb        # strings in the contracts
tool/
├── recitations.json                       # 51 reciters (43 EveryAyah, 8 QUL)
├── src/recitations.dart                   # recitation_sizes, new columns and checks
├── src/mp3_frames.dart                    # NEW: ID3 length, CBR check, frame start search
├── build_recitation_manifest.dart         # qul_surah source; --skip-existing
├── sources/qul-recitations/<qul_id>.json  # QUL timings (gitignored; pinned in sources.lock.json)
└── export_asr_model.py                    # NEW: HF → ONNX int8 (maintainer, once)
assets/licences/                           # Apache-2.0 (sherpa-onnx, Tarteel), MIT (onnxruntime, record)
android/app/src/main/
├── AndroidManifest.xml                    # RECORD_AUDIO
└── kotlin/…/MainActivity.kt               # 3 channel methods
ios/Runner/
├── Info.plist, ar.lproj/ en.lproj/InfoPlist.strings   # NSMicrophoneUsageDescription
├── mistake.caf                            # 3 KB tone
└── AppDelegate.swift                      # 3 channel methods
test/unit/    recitation_sizes, clip_range, mp3_frames, ayah_fetcher_range, reciter_search,
              recitation_matcher, memorization_score, memorization_controller, asr_model,
              memorization_privacy
test/widget/  reciter_list, range_sheet, hidden_page (+ goldens), memorization_bar, result_screen
integration_test/paging_perf_test.dart     # WITH_MEMORIZATION variant
docs/licences.md, docs/permissions/everyayah-request.md, docs/permissions/qul-request.md,
docs/store/privacy.md
```

**Structure Decision**: a new `lib/features/memorization/` folder beside `recitation/`, following
the per-feature layout. The matcher and score are pure Dart and have no plugin imports, so they
are unit tested on the full Quran without devices. The reader gets predicates (`isHidden`,
`isHinted`, mistake markers) rather than knowing about sessions. That mirrors how 004's
`recited` highlight is passed in.

## Delivery Order

1. **Spikes**:
   - S2 (size), at once;
   - S1 (accuracy and latency), once the test sets are recorded.

   S1 gates step 5 onward. S2 is reported to the owner before step 5 merges.
2. **All reciters** (US1, independent of the rest):
   1. `recitations.json`;
   2. `recitation_sizes` and the new columns;
   3. the manifest run for EveryAyah and QUL ayah sets;
   4. the searchable list;
   5. V-1 listening.

   Shippable alone once D4 and D2 are widened.
3. **QUL surah clips** (US1, R18–R19):
   1. download the 7 QUL timing JSONs;
   2. `mp3_frames.dart` and the `qul_surah` manifest path;
   3. the fetcher's `Range` path;
   4. basmala-item skip;
   5. Q-6 to Q-8 on both phones.

   Can ship after step 2 or with it.
4. **Matcher and score** (pure Dart): rules, variants, the property test, scoring.
5. **Engine**: model download, device gate, mic, recogniser isolate, controller with the fake
   recogniser.
6. **Memorization UI** (US2): entry points, range sheet, explainer, hidden page in both layouts,
   bar, signals, settings row.
7. **Result** (US3): result screen, review, Try again.
8. **Release prep**: licences, privacy answers, Info.plist text, size report, quickstart on both
   phones, deleting the test sets.

## Risks & Open Dependencies

| ID | Risk | Impact | Mitigation |
| --- | --- | --- | --- |
| D4 | Quran.com Foundation permission not yet granted; now covers 43 EveryAyah recordings and 5 quranicaudio surah recordings | **Blocks release** | Widen and send the request now. If some reciters are refused, drop their rows; the code doesn't change. |
| D2 | QUL / Tarteel permission (already pending for layout data) now also covers timings for 7 recordings and 3 Tarteel-hosted recordings; QUL states no licence for them | **Blocks release** of the 8 QUL entries | Widen `docs/permissions/qul-request.md`. If refused, the 8 rows are removed and the other 43 still ship. |
| R-8 | QUL updates a recitation's timings (for example its changelog "Fixed the segments for surah 39", 2026-10-13) or a host replaces a file | Clip boundaries cut mid-word, or size checks fail and the fetch retries forever | Timings are pinned at build. The fetcher requires the exact `Content-Range` total length, so a replaced file fails cleanly with the retry message rather than playing wrong audio. Re-run the manifest for that reciter in the next release. |
| R-9 | MP3 bit reservoir at clip starts | Up to 26 ms of silence at an ayah boundary | Cut mid-pause between ayat (R18), so no recited sound is lost; within 004 FR-009 (≤ 150 ms). Checked by listening in Q-7. |
| R-1 | On-device accuracy below 95% for ordinary readers (Tarteel's training data is mostly professional reciters) | US2 does not meet SC-004/005 | S1 before the UI work. Tune the matcher thresholds; try base. If both fail, report to the owner; the spec forbids moving the voice online. |
| R-2 | +≈ 11 MB store growth | Principle IV | Measured in S2 and called out. The owner approves or chooses the fallback: an own whisper.cpp FFI build at ≈ 2 MB with more code to maintain (R6). |
| R-3 | Latency on slower supported phones above 1 s | SC-007 | The device gate (R15) is set from S1 measurements; it may be raised, for example to ≥ 4 GB. |
| R-4 | A new reciter set doubles the basmala or mislabels style | Wrong recitation | V-1 listening of 4 ayat per new reciter; fix or drop the row. |
| R-5 | Manifest run throttled for hours | Build delay | `--skip-existing` resume; concurrency 4; mirror fallback. |
| R-6 | GitHub Releases URL changes or rate limits | Model download fails | Pinned hashes and a retry message. A mirror URL can be added in `asr_model.dart` without format changes. |
| R-7 | Recording test sets of volunteers' voices | Privacy | Written consent; kept off the repository and cloud storage; deleted after release checks (quickstart). |

## Complexity Tracking

| Addition | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| `sherpa_onnx` + onnxruntime (Android, *measured in S2*: **+9.59 MB per arm64 phone**, +28.98 MB summed over the 3 bundled ABIs as `tool/size_check.dart` counts; iOS not yet measured) | On-device recognition of recitation with a Quran-tuned model, in-memory audio and built-in VAD on both platforms (FR-013, FR-019, Q2) | Platform recognisers can't guarantee on-device processing on Android API 24–30, and Arabic on-device support on iOS is undocumented (R6). `whisper_ggml` requires iOS 15.6 and bundles FFmpeg. An own whisper.cpp build is smaller (≈ 2 MB) but adds about 300 lines of FFI, a build pipeline and a VAD to maintain; it is kept as the fallback if the owner rejects the size. |
| `record` (≈ 0.1 MB) | 16 kHz PCM stream, permission request and interruption handling on both platforms (R10) | Native capture in the device channel is about 150 lines per platform, duplicating a focused, maintained plugin. |
| Model download (61.5 MB, on demand; measured in T029) | The recogniser needs weights; bundling would add 61.5 MB for every user (R9) | Store-specific asset delivery (Play Asset Delivery, On-Demand Resources) means two paths. Hugging Face hosting is outside our control. |
| `RecitationMatcher` with variant pairs | Word-level resume after a mistake (Q1), repeats and restarts not counted as mistakes (FR-014), hints (Q3) | Whole-ayah comparison can't resume from the wrong word or flag early mistakes in long ayat. |
| Packed `recitation_sizes` BLOB | Keeps the 51-reciter catalogue at about 0.9 MB instead of about 1.9 MB (R4) | Row-per-file doubles the size. Dropping sizes loses offline integrity checks and download sizes (004 FR-028, FR-031). |
| QUL surah files as byte-range ayah clips (build-time frame offsets, `Range` fetches) | 7 recitations exist only as gapless surah files (R0). Clips keep every 004 guarantee with about 150 lines: a frame scanner in the tool and a `Range` branch in the fetcher (R18) | A second, surah-level player duplicates caching, buffering, downloads and error handling, and loses per-ayah resume. Re-hosting split files needs our own hosting and redistribution rights. |
| 3 device-channel methods | Device gate, Settings deep link, a mistake tone that honours silent mode (R12, R15) | `device_info_plus`, `app_settings` and an audio plugin are 3 dependencies for about 40 lines of native code. |
| `crypto` moved from `dev_dependencies` to `dependencies` (pure Dart, already locked) | SHA-256 check of the downloaded model files (R9, T038) | A size-only check would accept a damaged or replaced file and load it into the recogniser. |
