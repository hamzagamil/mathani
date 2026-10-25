# Implementation Plan: Khatma Recogniser and Live Word-by-Word Reveal

**Branch**: `007-khatma-live-recognition` | **Date**: 2026-10-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/007-khatma-live-recognition/spec.md`

## Summary

Two changes to 006's memorization engine.

1. **Khatma replaces Tarteel Whisper tiny** (research R1, R2, R4):
   - Khatma is NVIDIA's Arabic FastConformer (CTC head, int4), licensed CC BY 4.0, with Tilawa's
     export under MIT.
   - **It runs on the `sherpa_onnx` 1.13.8 the app already ships**, as a raw-audio CTC model
     (sherpa-onnx's "omnilingual" type) with Khatma's own in-graph features. That means no new
     dependency and no store-size growth.
   - A maintainer tool converts the Khatma package once:
     - unpacks the int4 weights to int8 and embeds them;
     - computes the graph's `length` input from the waveform;
     - writes a 1025-entry `tokens.txt`.
   - Spike S1 rejected the first plan (cut the preprocessor, run as NeMo CTC): sherpa-onnx's
     own features dropped final words (research R2).
   - **Download**: 107.5 MB gzip, unpacked on the phone to 133.3 MB, from the GitHub release
     `asr-khatma-v1`. The previous model is deleted on the first launch after updating.
2. **Live-like word-by-word reveal** (research R3, R5):
   - Neither model streams. So while the reader speaks, the speech isolate re-decodes the
     audio since the **anchor** (the start of the last word the matcher accepted) every
     ≥ 0.5 s, paced so decoding takes at most about half the time.
   - The controller holds back the last word (it may be cut) and feeds the rest to the 006
     matcher under **live rules**:
     - it advances and skips unclear words;
     - it declares a mistake only when 2 following words confirm it;
     - it never declares the same mistake twice in one stretch of speech.
   - The controller then commits the new anchor.
   - At a pause, the rest is decoded once under 006's pause rules.
   - Revealed words are never hidden again. A slow phone falls back to 006's pause-based reveal.

## Technical Context

**Language/Version**: Dart 3.13.5 / Flutter 3.47.7 (pinned). Python 3.12 for the one-off
maintainer export tool.

**Primary Dependencies**: no change. `sherpa_onnx` 1.13.8 (now with `OfflineOmnilingualAsrCtcModelConfig`
instead of Whisper), `record` 7.1.2, `crypto`, `path_provider`. `dart:io` `gzip` for unpacking.
The export tool needs `onnx`, `onnxruntime` and `numpy`; it is not part of the app.

**Storage**: model files in `<app support>/asr/asr-khatma-v1/` (≈ 134 MB), excluded from backup.
`asr-tarteel-tiny-v1/` (64.5 MB) is deleted. No database change.

**Testing**:
- `flutter_test` unit and widget tests, with the fake recogniser extended to `Heard` and
  `commit`.
- The matcher's property test over all 6,236 ayat, extended to overlapping live passes.
- A localhost server for the `.gz` download and unpack.
- A desktop sherpa-onnx test on real clips (skipped without the model).
- Spikes S1–S3 ([quickstart](./quickstart.md)).

**Target Platform**: iOS 15.0+ and Android 7.0 (API 24)+, target API 36, phones in portrait.
Memorization keeps 006's gate (arm64, ≥ 3 GB RAM). S2 confirms the iPhone SE 2 (3 GB) stays
usable.

**Project Type**: mobile app (single Flutter project). Model host: GitHub Releases (unchanged).

**Performance Goals**:
- A word is revealed ≤ 1.5 s after it is said, in 90% of cases (SC-001).
- Words before a pause are revealed ≤ 1 s after the pause; an ayah ≤ 1 s after its last word
  (SC-002).
- No gap over 3 s without a new word during correct recitation (SC-003).
- Recogniser load ≤ 3 s (was 1.5 s for a model half the size; R8).
- Pause, resume and end ≤ 100 ms; 60 fps paging during a session.
- Cold start unchanged.

**Constraints**:
- Privacy: voice on the device only, held audio in memory only (FR-002). Only words and sample
  indexes leave the speech isolate.
- Reveals are monotonic and only in order (FR-007).
- Battery: ≤ 10% per 15 minutes on the Galaxy A15 (SC-008); decoding ≤ about 50% of speech time
  by pacing.
- Download ≈ 108 MB, asked first on mobile data; free space for download plus unpack (≈ 241 MB).

**Scale/Scope**:
- **Changed files**: 4 in `lib/features/memorization/` (`asr_model`, `speech_recogniser`,
  `recitation_matcher`, `memorization_controller`), plus `app.dart` (one call) and
  `about_section.dart`.
- **New files**: 1 pure helper (`speech_words.dart`), 1 tool script and 1 licence text.
- **UI**: no new screens or strings, except the download size, which is computed.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution v2.0.0.

| Principle | Gate | Pre-research | Post-design |
| --- | --- | --- | --- |
| I. Cross-Platform Parity | Same on iOS and Android; OS versions stated | ✅ | ✅ Same sherpa-onnx model on both. The gate is unchanged. Every D-scenario runs on both reference phones. iOS 15.0+ and Android API 24+. |
| II. Mobile-First Design | Portrait, touch targets, safe areas, dark mode, font scaling, screen readers | ✅ | ✅ No new UI. Word reveals reuse 006's painting and announcements. Live reveals are announced per ayah, not per word, as in 006, so screen readers are not flooded. |
| III. Performance (NON-NEGOTIABLE) | ≤ 2 s cold start; 60 fps; ≤ 100 ms feedback; no UI-thread blocking | ✅ | ✅ Decoding stays on the speech isolate, and the unpack runs on its own isolate. The controller never awaits the isolate for pause or end. Each reveal changes the page only by the newly revealed words (006 `_syncWords`). `removeOtherVersions` runs after the first frame. The paging perf test reruns with live passes. ⚠️ Recogniser load rises from 1.5 s to ≤ 3 s, behind the existing "preparing" state (Complexity Tracking). |
| IV. Lean by Default | Dependencies justified; > 1 MB growth called out; on-demand content; battery | ✅ | ✅ No new dependency and ≈ 0 MB store growth. A second onnxruntime (+10 MB) was rejected (R2). The model stays on demand. ⚠️ The download grows from 61.5 MB to ≈ 105 MB, and disk use from 64.5 MB to ≈ 134 MB. Repeated decoding costs battery, so it is paced (≤ ~50% duty), runs only while the VAD hears speech, and has a measured budget (S3). |
| V. Simplicity | Simplest approach; reuse; complexity justified | ✅ | ✅ The 006 matcher is extended rather than adding the test project's second alignment engine (R5). Two rules are added, and rule 7 becomes "live". `Segment`, forced splits and three Whisper constants are removed. A gzip file was chosen over a custom int4 package with on-device protobuf writing (R4). |
| Store & privacy | Policies; permissions; privacy disclosures | ✅ | ✅ No new permission, host or data flow. The privacy answers are unchanged (still on the device). New licence credits (CC BY 4.0, MIT) are in the app and the release. |

**Result**: **PASS**. Two items are recorded in Complexity Tracking for the owner to see in
review: the larger download and the longer load.

## Project Structure

### Documentation (this feature)

```text
specs/007-khatma-live-recognition/
├── plan.md              # This file
├── research.md          # R1 model, R2 runtime and conversion, R3 live vs live-like, R4 packaging,
│                        #   R5 re-read/commit/trim, R6 output cleaning, R7 migration, R8 memory,
│                        #   R9 credits, R10 accuracy checks; spikes S1–S3
├── data-model.md        # model files, Heard/HeardWord, live follow state, matcher additions
├── quickstart.md        # spikes, export, tests, device scenarios D-1–D-14, gates
├── contracts/
│   └── live-recognition.md    # AsrModel, SpeechRecogniser, matcher rules, controller, constants
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks; not created here)
```

### Source Code (repository root)

```text
lib/
├── features/memorization/
│   ├── asr_model.dart                 # asr-khatma-v1 files; .gz unpack on an isolate; diskBytes,
│   │                                  #   requiredBytes; removeOtherVersions()
│   ├── speech_recogniser.dart         # NeMo CTC; anchor, live passes, pacing, commit; Heard
│   ├── speech_words.dart              # NEW, pure: pieces + timestamps → cleaned HeardWords
│   ├── recitation_matcher.dart        # Hearing; live rules 4–7; rules 10, 11; lastMatchedToken
│   ├── memorization_controller.dart   # live/pause handling, hold-back, commit
│   └── range_sheet.dart               # free-space check uses requiredBytes
├── features/recitation/downloads_screen.dart   # model row shows diskBytes
├── features/settings/about_section.dart        # Khatma/NVIDIA + Tilawa credits; Tarteel removed
└── app/app.dart                                # removeOtherVersions after first frame
tool/
├── export_khatma_model.py             # NEW: Khatma → sherpa-onnx NeMo CTC (maintainer, once)
├── export_asr_model.py                # REMOVED (Whisper export; Principle IV: no dormant code)
└── README.md                          # Memorization model section rewritten
assets/licences/
├── LICENSE-khatma-model.txt           # NEW: NVIDIA CC BY 4.0 attribution, changes, Tilawa MIT
└── LICENSE-tarteel-whisper.txt        # REMOVED
test/unit/   recitation_matcher_test, recitation_matcher_quran_test, memorization_controller_test
             (via memorization_session_test), speech_recogniser_test, speech_words_test (new),
             asr_model_test, memorization_privacy_test
test/support/fake_memorization.dart    # FakeSpeechRecogniser emits Heard, records commits
docs/licences.md, docs/release.md
```

**Structure Decision**: everything stays in 006's `lib/features/memorization/` folder. The only
new app file is `speech_words.dart`: the piece-to-word logic is pure Dart, so it is unit tested
without the native library and can run inside the speech isolate. The matcher remains pure Dart
and keeps its full-Quran property test.

## Complexity Tracking

| Item | Why needed | Simpler alternative rejected because |
| --- | --- | --- |
| Model download ≈ 108 MB, ≈ 134 MB on the device (was 61.5 / 64.5 MB) | It is the model the owner chose; sherpa-onnx needs the weights as int8 inside one file (R2, R4) | A custom int4 package (≈ 88 MB) needs the app to write protobuf with weights placed at offsets, which means more code and more failure modes for a one-time 17 MB saving. It is kept as the next step if the owner wants it. A plain `.onnx` download would be 26 MB more. |
| Recogniser load target 3 s (was 1.5 s) | The model has twice the bytes; load happens once per app run, behind "preparing" | Loading at app start would break cold start (Principle III). A smaller model would not be the owner's choice. |
| Repeated decoding while speaking (battery) | It is the only way to reveal words before a pause with an offline model (R3) | Pause-only reveal is what the owner asked to replace. Whole-utterance re-decoding costs more on long ayat. Pacing and VAD gating keep the duty cycle at or under about 50%, measured in S3. |
| Gzip unpack step on the phone | It saves ≈ 26 MB of download for every reader | Covered by the same resume, check and delete flow; a `.gz` interrupted mid-unpack is unpacked again without fetching it. |
