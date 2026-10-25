# Quickstart: Khatma Recogniser and Live Word-by-Word Reveal

How to export the model, test the change and check it on the phones. Design: [plan](./plan.md),
[research](./research.md), [data model](./data-model.md),
[contract](./contracts/live-recognition.md). Everything 006's quickstart checks still applies
([006 quickstart](../006-reciters-memorization/quickstart.md)); this file lists what changes.

## Prerequisites

- Flutter 3.47.7 (pinned).
- Reference phones: Galaxy A15 (Android 14) and iPhone SE 2nd gen (iOS 15+), as in 006.
- Python 3.12 with `onnx` and `onnxruntime`, for the export tool.
- The 006 speech test sets (correct and with mistakes), kept outside the repository as 006
  requires.
- The Memorize-Ayah recordings and results:
  - In the test project, "Export audio" gives a zip of WAV files and "Export CSV" gives the
    per-model results.
  - Convert the WAVs to 16 kHz mono float32 `.f32` in `build/asr/check/`, named
    `SSSAAA[-label].f32`, with a CSV of planned mistakes next to them.
  - These recordings hold voices: delete them after the release checks, as in 006.

## Spikes

| Spike | Run | Pass |
| --- | --- | --- |
| **S1** Conversion | Export (below) with `--check build/asr/check`, then `flutter test test/unit/speech_recogniser_test.dart` on Windows | The tool reports ≥ 97% of words agreeing (matcher similarity) between the Khatma graph on raw audio and the converted model through sherpa-onnx; the desktop test decodes every clip; sizes recorded in research R4. **Passed 2026-10-25: 98.97%** |
| **S2** Phones | Profile build with `MEMO_TRACE=1` (logs per pass: window length, decode ms, words used); run D-1 and D-2 on both phones | Load ≤ 3 s; peak memory recorded (iPhone SE 2 must stay usable); 90% of words revealed ≤ 1.5 s after being said (SC-001); decode time ≤ 50% of speech time |
| **S3** Battery | Galaxy A15 at 100%, screen at 50%, airplane mode, 15-minute session reciting continuously | ≤ 10% battery used (SC-008) |

If S1 fails, use the fallback in research R2 and tell the owner, since the comparison results
then no longer apply directly. If S2 or S3 fail, tune the constants in the contract (threads,
`livePassEvery`, `liveHoldBack`) and run them again. If they still fail, report to the owner
before going further.

## Export and publish the model (once per model version)

```text
py -3.12 -m venv build/asr/venv
build/asr/venv/Scripts/python -m pip install onnx onnxruntime numpy sherpa-onnx==1.13.8
build/asr/venv/Scripts/python tool/export_khatma_model.py --out build/asr/khatma-v1 --check build/asr/check
```

The tool works as follows:
1. Downloads the Khatma package and the reference `tokens.txt`, both pinned by SHA-256.
2. Unpacks the weights into the graph and computes its `length` input from the waveform (research R2).
3. Writes `model.int8.onnx`, `model.int8.onnx.gz`, `tokens.txt` and `silero_vad.onnx`, with
   `SHA256SUMS` and `NOTICE.txt`.
4. With `--check`, runs the equivalence check and prints each file's size and SHA-256.

Then:
1. Upload `model.int8.onnx.gz`, `tokens.txt`, `silero_vad.onnx` and `NOTICE.txt` to the GitHub
   release `asr-khatma-v1`.
2. Paste the sizes and SHA-256 values (download and unpacked) into
   `lib/features/memorization/asr_model.dart`. Never replace files in a published release.

## Tests

```text
flutter test test/unit test/widget
```

- **`recitation_matcher_test`**:
  - rules 4–7 under `Hearing.live` and `Hearing.pause`, and the new rules 10 and 11;
  - `lastMatchedToken`;
  - the property test over all 6,236 ayat with overlapping live passes (contract › RecitationMatcher).
- **`memorization_controller_test`**, with the fake recogniser:
  - live words revealed while speaking, the last word held back;
  - commit positions (matched, mistake, nothing);
  - a live mistake signalled once and not repeated by the closing pause pass;
  - revealed words never hidden after a repeat;
  - Next word during a pass.
- **`speech_recogniser_test`** (desktop, skipped without the model and clips):
  - **Live and pause passes** over each clip, played at real time through `accept` with commits
    answered as the controller would: the ayah completes, and words come out before the clip
    ends.
  - **Accuracy**: SC-004 and SC-005 rates on the 006 sets and the Memorize-Ayah recordings,
    printed next to the 006 path's rates and M5's rates from the CSV (SC-005 in the spec).
- **`speech_words_test`** (new, pure): pieces and timestamps become words with the right
  `startSample`, punctuation is stripped, and empty words are dropped.
- **`asr_model_test`**: `.gz` download, then unpack and check; a damaged unpack is deleted; a
  checked `.gz` left from a closed app is unpacked without fetching it again;
  `removeOtherVersions` deletes `asr-tarteel-tiny-v1` only; `requiredBytes` is used for the
  free-space check.
- **`memorization_privacy_test`**: unchanged rule; the unpack isolate lives in `asr_model.dart`.

## Device scenarios

Run on both reference phones. 006's Q-10 to Q-23 are run again with the new model; their
expectations hold except where a row below replaces them.

| ID | Steps | Expected |
| --- | --- | --- |
| D-1 | Airplane mode. Al-Mulk 1–5: recite ayah 1 in one breath | Words appear one by one while reciting; the first within 1.5 s of saying it; none appears before it is said (US1-1, SC-001) |
| D-2 | Al-Mulk 1–10 without pausing between ayat (about 2 minutes) | Words keep appearing; no stretch of over 3 s without a new word; each ayah completes without a pause (US1-6, SC-003) |
| D-3 | Al-Mulk 2: swap one word and carry on two more words without pausing | Mistake signalled before the pause; the swapped word and all after it stay hidden; reciting from that word reveals the rest (US1-4, SC-007) |
| D-4 | Pause mid-ayah for 2 s, then go on | Words before the pause all shown within 1 s; no mistake (US1-5) |
| D-5 | Repeat a phrase; restart the ayah; begin ayah 2 by repeating the end of ayah 1 | No mistake; nothing hidden again (rule 10, FR-007) |
| D-6 | Ar-Rahman 13–16 («فبأي آلاء ربكما تكذبان» recurring) | Only the expected place is revealed |
| D-7 | Tap Next word while reciting that same word | The word appears once as a hint; the following word is still expected |
| D-8 | Al-Baqarah 282 in long breaths | Words keep appearing through the ayah; reveal does not slow as the ayah grows |
| D-9 | Play a reciter from another phone next to the mic, without reciting | Nothing revealed (SC-006) |
| D-10 | Install 1.4.0, download its model, update; open Settings › Downloads, then Memorize | Old model gone from Downloads and from storage; the range sheet shows the new download size; asks first on mobile data (US3-1, US3-2) |
| D-11 | Start the download, kill the app at 50%, reopen and continue; then kill it during "unpacking" | Resumes; no second fetch of the finished `.gz`; ready afterwards (US3-3) |
| D-12 | Fill the storage to under 240 MB free; try the download | The sheet says how much space is needed; nothing else changes |
| D-13 | About › licences | Khatma/NVIDIA (CC BY 4.0) and Tilawa (MIT) credited; Tarteel Whisper gone (FR-012) |
| D-14 | Network monitor during D-1 | 0 bytes sent during the session (FR-002) |

## Performance and size gates

- `integration_test/paging_perf_test.dart` with `WITH_MEMORIZATION`: 60 fps paging while live
  passes run (FR-011, SC-008).
- Pause, resume and end change state within 100 ms while a pass is decoding: the controller
  never waits for the isolate.
- Cold start unchanged: `removeOtherVersions` runs after the first frame.
- `dart run tool/size_check.dart`: expected growth about 0 MB (no new dependency; licence text
  only), reported in the PR (SC-010).

## Release checklist

- [ ] S1, S2 and S3 results written into research (R2, R4, R5, R8).
- [ ] `asr-khatma-v1` release published with `NOTICE.txt`; hashes pinned.
- [ ] Licences page, About screen and `docs/licences.md` updated (R9).
- [ ] `tool/README.md` › Memorization model describes the new export.
- [ ] Release notes: memorization downloads a new model (≈ 108 MB) after updating.
- [ ] Test recordings deleted.
