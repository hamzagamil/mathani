---

description: "Task list for the Khatma recogniser and live word-by-word reveal"
---

# Tasks: Khatma Recogniser and Live Word-by-Word Reveal

**Input**: Design documents from `specs/007-khatma-live-recognition/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/live-recognition.md](./contracts/live-recognition.md),
[quickstart.md](./quickstart.md)

**Tests**: Included. The plan and quickstart list them, and several spec rules can only be held by
automated checks: no word revealed that was not recited and none hidden again (FR-007, SC-006),
the live mistake rules (FR-009), and the model files' integrity (FR-003).

**Organization**: grouped by user story. US1 is live reveal, US2 is accuracy with Khatma, US3 is
moving to the new model. US1 and US2 both need the new recogniser, which is in Phase 2.
- **Baseline first**: T003 measures the 006 recogniser's accuracy *before* Phase 2 removes it.
  SC-004 ("no lower than the previous recogniser") needs that number.
- **Spike gates**: S1 (T004) gates Phase 2. S2 (T025) gates the release of US1. S3 (T042) gates
  the release.
- **Outward-facing step**: T006 publishes a GitHub release. Confirm with the owner before running
  it.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US3)

## Path Conventions

Single Flutter project at the repository root: `lib/`, `test/`, `tool/`, `integration_test/`,
`docs/`, `assets/`. Memorization code is in `lib/features/memorization/`.

## Shared conventions

- **Tests**: follow 006's conventions (006 tasks.md › Shared conventions):
  - `openTestReader()` inside `tester.runAsync(...)` for Quran data;
  - `test/support/fake_audio_server.dart` for HTTP;
  - `test/support/fake_memorization.dart` for the recogniser and mic fakes;
  - no test reaches GitHub or Hugging Face.
- **Desktop model tests** (`test/unit/speech_recogniser_test.dart`):
  - they use `build/asr/khatma-v1` and `build/asr/check`;
  - they are skipped when those are absent, as in 006 T040;
  - they find sherpa-onnx's Windows library from `.dart_tool/package_config.json` as that test
    already does.
- **Named constants**: one definition each, as in the contract:

  | Constant | Value | Defined in |
  | --- | --- | --- |
  | `asrModelVersion` | `'asr-khatma-v1'` | `asr_model.dart` |
  | `livePassEvery` | 0.5 s | `speech_recogniser.dart` |
  | `liveSlowPass` | 2 s | `speech_recogniser.dart` |
  | `maxHeld` | 20 s | `speech_recogniser.dart` |
  | `anchorMargin` | 0.16 s | `speech_words.dart` |
  | `tailPad` | 0.25 s | `speech_recogniser.dart` |
  | `liveHoldBack` | 1 word | `memorization_controller.dart` |
  | `livePassesToAgree` | 1 | `memorization_controller.dart` |
  | `liveMistakeRun` | 2 tokens | `recitation_matcher.dart` |
  | `vadThreshold`, `vadMinSilence`, `vadMinSpeech`, `vadMaxSpeech`, `vadWindow` | unchanged from 006 | `speech_recogniser.dart` |

- **Comments** follow the surrounding code: a header comment naming the spec, contract and
  research sections; short doc comments on constants with their research reference.

---

## Phase 1: Setup (model export and baseline)

**Purpose**: produce and publish the converted model, check it matches Khatma (S1), and record
the 006 baseline before the old recogniser is removed.

- [X] T001 Create the maintainer tool `tool/export_khatma_model.py` (research R2, R4).
  **Done, revised by S1**: the tool keeps Khatma's graph whole and only computes `length`
  from the waveform's shape, for sherpa-onnx's raw-audio ("omnilingual") type. It does not cut
  the preprocessor or add NeMo metadata. `--check` compares words as the matcher does
  (diacritics removed, similarity ≥ 0.75, pass at 97%). The steps below are the original plan,
  kept for the record.
  - **Usage** (module docstring, in the style of `tool/export_asr_model.py`):
    `--out build/asr/khatma-v1 [--check build/asr/check] [--hf-endpoint URL]`.
  - **Downloads**, each checked against a pinned SHA-256:
    - `https://huggingface.co/adnanfet/khatma-model/resolve/main/fastconformer_ar_khatma_v1.bin`
      (89,410,608 bytes, `67043116646830400106be8177f69823e70a90d9b3a5d96d6bb374cab9dc9b9f`);
    - `tokens.txt` from `dev-ahmedhany/stt_ar_fastconformer_hybrid_large_pcd_v1.0-sherpa-ctc`
      (12,850 bytes; pin its SHA-256 on first download);
    - `silero_vad.onnx` (same URL and SHA-256 as `tool/export_asr_model.py`'s `SILERO_VAD`).
  - **Unpack KFC1** as in `C:\Users\Hamza\Memorize-Ayah\src\models\khatmaPackage.ts`:
    - layout: magic `KFC1`, uint32 LE header length, JSON header (`verzija` must be 1, `graf`,
      `tezine`, `matrice`);
    - for each matrix, `int8[k][n] = round_half_up((q − 8) × blockScale / rowScale)`, clamped
      to ±127, laid out [K, N] at offset `izlaz`;
    - assert every row's maximum absolute value is 127 (the layout check).
  - **Cut the graph**:
    - load it with `onnx.load(..., load_external_data=False)` and attach the int8 weights to the
      initializers that reference `tezine.bin`;
    - new input `audio_signal` (float, [N, 80, T]) replaces `/preprocessor/Cast_1_output_0`;
    - new input `length` (int64, [N]) replaces `/preprocessor/featurizer/Where_output_0`;
    - remove every node whose name starts with `/preprocessor` and every initializer no longer
      used;
    - keep output `log_probs`; run `onnx.checker.check_model`.
  - **Metadata**: `vocab_size`=`1025`, `subsampling_factor`=`8`, `normalize_type`=`per_feature`,
    `model_type`=`EncDecCTCModelBPE`.
  - **Writes**:
    - `model.int8.onnx` (weights embedded in one file);
    - `model.int8.onnx.gz` (`gzip`, level 9);
    - `tokens.txt` (each line of the reference file as `piece i` for i = 0…1023 in line order,
      then `<blk> 1024`);
    - `silero_vad.onnx`, `SHA256SUMS`, and `NOTICE.txt` (the text of T005);
    - finally, prints each file's size and SHA-256, giving both the download and unpacked values
      for the model.
  - **`--check DIR`**: for every `*.f32` clip (16 kHz mono float32), decode with:
    - (a) the original Khatma graph through `onnxruntime` with raw audio in;
    - (b) `model.int8.onnx` through the `sherpa-onnx` Python wheel at version 1.13.8 with
      `OfflineRecognizer.from_nemo_ctc`;
    - greedy CTC (blank 1024) for (a);
    - print the per-clip transcripts and the share of identical words; exit non-zero below 99%.
- [ ] T002 [P] Prepare the check set in `build/asr/check/` (quickstart › Prerequisites; not
  committed):
  - export the Memorize-Ayah recordings (Export audio → WAV zip) and the results CSV (Export
    CSV) from the test project;
  - convert each WAV to 16 kHz mono float32 `SSSAAA[-label].f32` with a small script in
    `tool/wav_to_f32.py` (stdlib `wave` + `array`, no other dependency; resample only if the input
    is not 16 kHz, by linear interpolation);
  - write `build/asr/check/mistakes.csv` (`file, surah, ayah, kind, position`) from the test
    project's planned mistakes, and copy the 006 S1 sets into the same folder.
  **Partly done**: `tool/wav_to_f32.py` is written and tested. The Memorize-Ayah recordings
  must be exported by the owner from the test project's UI; they are in its browser storage.
- [X] T003 Record the **006 baseline** before any code change:
  **Done** on the 8 Alafasy clips (7/8): [baseline.md](./baseline.md). Rerun it at `883f41f` once T002's
  recordings exist.
  - on the current `main`, run `flutter test test/unit/speech_recogniser_test.dart` against
    `build/asr/tarteel-tiny-v1` and `build/asr/check`;
  - extend that test's report temporarily, if needed, to print two rates over the check set:
    - (a) the share of correct ayat completed with 0 mistakes;
    - (b) the share of planned mistakes declared at the right position;
  - write both rates, the clip count and the date into
    `specs/007-khatma-live-recognition/baseline.md`;
  - do not commit the temporary test change.
- [X] T004 **Spike S1**: run T001 with `--check build/asr/check`.
  **Done**: the first plan failed (sherpa-onnx's NeMo features drop final words). The raw-audio
  route passed at 98.97%. Results are in research R2 and R4.
  - **Pass**: ≥ 97% of words agree as the matcher compares them (revised from 99% identical).
  - **Record** in `specs/007-khatma-live-recognition/research.md`, under a new "S1 results"
    heading in R2 and R4:
    - the measured sizes of `model.int8.onnx` and `model.int8.onnx.gz`;
    - the equivalence share;
    - any differing words;
    - whether `tailPad` 0.25 s changes the last word.
  - **If it fails**: stop. Report to the owner with the fallback of research R2.
- [X] T005 [P] Create `assets/licences/LICENSE-khatma-model.txt` (research R9). Include:
  - the attribution "NVIDIA FastConformer-Hybrid PCD Large (ar)
    (stt_ar_fastconformer_hybrid_large_pcd_v1.0) by NVIDIA", with the model URL;
  - the CC BY 4.0 name and link (https://creativecommons.org/licenses/by/4.0/);
  - Khatma's statement of changes (CTC head only, preprocessing in graph, int4/int8 repack;
    https://huggingface.co/adnanfet/khatma-model);
  - our changes: weights unpacked and embedded as int8 in one file, the length input computed
    from the audio, a vocabulary file added, gzip-compressed for download, no retraining;
  - the Tilawa MIT licence text exactly as on the Khatma model card ("Copyright (c) 2026
    yazinsai").

  The same text is used as `NOTICE.txt` by T001.
- [X] T006 Publish the GitHub release `asr-khatma-v1` on `hamzagamil/mathani`:
  - upload `model.int8.onnx.gz`, `tokens.txt`, `silero_vad.onnx` and `NOTICE.txt` from
    `build/asr/khatma-v1/`;
  - use `gh release create asr-khatma-v1 ... --title "Memorization model: Khatma FastConformer v1"`
    with notes naming the source and licences.
  - **Confirm with the owner before running.** Never replace files in a published release.

**Checkpoint**: converted model checked (S1), published, baseline recorded.

---

## Phase 2: Foundational (Khatma recogniser, pause-based reveal)

**Purpose**: swap the recogniser for Khatma with 006's pause-based behaviour and the new
`Heard` API. US1 then adds live passes, and US2 measures accuracy. After this phase the app works
end to end with Khatma, revealing words at pauses as before.

**⚠️ CRITICAL**: needs T004 (S1 passed). T009 needs T006's hashes.

- [X] T007 [P] Create the pure-Dart `lib/features/memorization/speech_words.dart` (contract ›
  Words from pieces, research R5, R6).
  - **`Hearing`**: `enum Hearing { live, pause }`, with a doc comment for each value.
  - **`HeardWord`**: `class HeardWord { final String text; final int startSample; }` with
    `==`/`hashCode`/`toString`.
  - **`anchorMargin`**: a constant, 0.16 s.
  - **`List<HeardWord> wordsFromPieces(List<String> tokens, List<double> timestamps, {required int windowStart})`**:
    - a token starting with `▁` (U+2581) starts a new word; other tokens join the current word;
    - `startSample = max(windowStart, windowStart + (firstPieceTime × micSampleRate).round() − (anchorMargin × micSampleRate).round())`;
    - the text is cleaned in this order:
      1. remove `▁`;
      2. remove punctuation: Unicode general category P*, plus `،` U+060C, `؛` U+061B, `؟`
         U+061F, `۔` U+06D4, `٪` U+066A and `٭` U+066D;
      3. apply `normalizeArabic` from `lib/features/search/arabic_normalizer.dart`;
    - drop words whose text is empty;
    - "never contains empty text" (data-model › Heard).

  No Flutter or plugin imports: the speech isolate and the matcher both import it. Move
  `micSampleRate` here from `speech_recogniser.dart` and re-export it there, so existing imports
  keep working.
- [X] T008 [P] Write `test/unit/speech_words_test.dart` for T007:
  - pieces `['▁بِسْمِ', '▁ال', 'لَّهِ', '،']` at times `[0.08, 0.40, 0.48, 0.56]` with
    `windowStart` 16000 give `[HeardWord('بسم', 16000), HeardWord('الله', 19840)]`, i.e.
    `16000 + 6400 − 2560` for the second word;
  - punctuation-only words are dropped;
  - `startSample` is never below `windowStart`;
  - empty input gives an empty list.
- [X] T009 Update `lib/features/memorization/asr_model.dart` for the new files (contract ›
  AsrModel, data-model › Recognition model):
  - **Version**: `asrModelVersion = 'asr-khatma-v1'`.
  - **`AsrFile`**: becomes
    `({String name, int bytes, String sha256, int? unpackedBytes, String? unpackedSha256})`.
  - **`asrModelFiles`**: `model.int8.onnx.gz` (download and unpacked values from T004/T006),
    `tokens.txt` and `silero_vad.onnx` (643,854 bytes, `9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6`).
    A `.gz` file is kept under its name without `.gz`.
  - **Unpack**: after a `.gz` passes its hash, it is decompressed in `Isolate.run`:
    - `File.openRead().transform(gzip.decoder)` is streamed to `<kept>.part` while hashing with
      `sha256`;
    - the result is checked against `unpackedBytes` and `unpackedSha256`, then renamed;
    - the `.gz` is deleted;
    - on a mismatch, delete the part and throw `AsrModelException(AsrModelError.damaged)`.
  - **Resume after a closed app**: a `.gz` with the right size whose kept file is missing is
    re-hashed and unpacked by the next `download()`, without fetching it again.
  - **`_readState`**:
    - ready when every kept file exists with its kept size;
    - `downloadedBytes` counts a kept file as its download `bytes`, so progress stays within
      `totalBytes`;
    - a complete `.gz` counts as fully downloaded.
  - **`diskBytes`**: sum of the kept sizes.
  - **`requiredBytes`**: `totalBytes` + the sum of `unpackedBytes`.
  - Update the header comment to cite specs/007.
- [X] T010 Extend `test/unit/asr_model_test.dart` (localhost server as today):
  - a `.gz` fixture built in the test with `gzip.encode` (a few KB) downloads, unpacks and
    becomes `ready`, and the `.gz` is gone;
  - a wrong `unpackedSha256` deletes the part and reports `damaged`;
  - a complete `.gz` left without its kept file is unpacked with **0** HTTP requests;
  - `requiredBytes` and `diskBytes` are correct;
  - existing resume and hash tests still pass with the new record type.
- [X] T011 Move `Hearing` into the matcher API in `lib/features/memorization/recitation_matcher.dart`:
  - `accept(tokens, {required Hearing hearing})` replaces `finalSegment`;
  - `Hearing.pause` keeps today's final-segment behaviour exactly;
  - for now `Hearing.live` keeps today's provisional behaviour (rule 7: never declares, stops at
    the first unexplained token);
  - add `MatchEvents.lastMatchedToken`: the index in `tokens` of the last token that matched a
    word, forward (rule 1) or back (rule 2), with −1 when none; set it in `accept`, and leave it −1
    for `hintNextWord`/`revealRest`;
  - import `Hearing` from `speech_words.dart`;
  - update the class doc to cite specs/007 contract › RecitationMatcher;
  - update every caller and test (`test/unit/recitation_matcher_test.dart`,
    `test/widget/recitation_matcher_quran_test.dart`): `finalSegment: true` becomes `Hearing.pause`
    and `false` becomes `Hearing.live`;
  - add a test of `lastMatchedToken` for forward, back and no match.
- [X] T012 Rewrite the recogniser core in `lib/features/memorization/speech_recogniser.dart`
  (contract › SpeechRecogniser), **pause passes only**:
  - **API**: replace `Segment`/`segments` with `Heard` (`pass`, `hearing`, `words`, `endSample`)
    and `Stream<Heard> get heard`. Add `commit(int pass, int fromSample)` (stored; used in T021).
  - **Recogniser**:
    `sherpa.OfflineRecognizer(OfflineRecognizerConfig(model: OfflineModelConfig(nemoCtc: OfflineNemoEncDecCtcModelConfig(model: '$dir/model.int8.onnx'), tokens: '$dir/tokens.txt', numThreads: threads, debug: false)))`.
  - **Worker state**: a global sample counter, `anchor`, and the held audio from `anchor` to now.
  - **Pause passes**:
    - on a VAD segment end, decode `anchor → segment end` plus `tailPad` of zeros and emit
      `Heard(pause)` with words from `wordsFromPieces(result.tokens, result.timestamps, windowStart: anchor)`;
    - then set `anchor` to the segment end;
    - segments ended by the VAD's 12 s soft limit are treated as speech continuing, not as a
      pause;
    - `flush()` does a pause pass over what is held.
  - **Temporary until T024**: held audio over `maxHeld` is decoded as a pause pass and the anchor
    moves to its end.
  - `reset()` sets `anchor` to the current sample and drops held audio.
  - **Remove**: `Segment`, `maxPiece`, `forcedSplitOverlap`, `tailSilence`, `_held` and the Whisper
    config.
  - Update the header comment to cite specs/007.
  **Done in its final form together with T021** (the same file): pause and live passes in one
  rewrite, so the temporary `maxHeld` pause pass was never written. The model runs as
  `OfflineOmnilingualAsrCtcModelConfig` (S1), not `nemoCtc`.

- [X] T013 Update `test/support/fake_memorization.dart`:
  - `FakeSpeechRecogniser` emits scripted `Heard`s, via
    `emit(List<String> words, {Hearing hearing = Hearing.pause, int startSample = 0})`, with
    increasing `pass` numbers and `startSample` values spaced 8000 apart;
  - it records `commit` calls in a `List<(int, int)> commits`;
  - `ReadyAsrModel` keeps working with the new `AsrFile` type.
- [X] T014 Update `lib/features/memorization/memorization_controller.dart` for `Heard`:
  - subscribe to `recogniser.heard`;
  - on `Heard(pause)`, call `_matcher.accept([for (final w in h.words) w.text], hearing: Hearing.pause)`
    then `_apply`;
  - ignore `Heard(live)` for now (T022 handles it);
  - re-arm the 30 s silence timer only when `h.words` is not empty;
  - remove the `normalizeArabic` split, which `speech_words.dart` now does.
  - Update `test/widget/memorization_session_test.dart` to the new fake: every existing scenario
    passes with `Hearing.pause` emissions.
- [X] T015 Update the desktop test `test/unit/speech_recogniser_test.dart` to the Khatma model:
  - `modelDir` becomes `build/asr/khatma-v1`, and availability is checked on `model.int8.onnx`;
  - feed each clip through `accept` in 0.1 s chunks and then `flush()`;
  - match `Heard(pause)` words;
  - keep the existing completion assertions;
  - run it on Windows and confirm every clean clip completes.

**Checkpoint**: the app runs memorization end to end with Khatma, revealing words at pauses (006
behaviour). US1 and US2 can start.

---

## Phase 3: User Story 1 - See each word appear as I recite it (Priority: P1) 🎯 MVP

**Goal**: words appear while the reader keeps reciting, within 1.5 s of being said. Mistakes are
signalled when two following words confirm them. Nothing is hidden again.

**Independent Test**: spec US1 › Independent Test, i.e. quickstart D-1 to D-4 on the Galaxy A15
with the network off.

### Tests for User Story 1

> Write these first; they fail until T020–T023 are done.

- [X] T016 [P] [US1] Add live-rule tests to `test/unit/recitation_matcher_test.dart` (contract ›
  rule changes):
  - **Live advances past unclear tokens**: an unexplained token mid-list does not stop later
    tokens from matching (rule 7 replaced).
  - **Live wrong word**: with 2 following words lined up, it is declared; with only 1 following
    word, it is not.
  - **Live missed and added**: the same 2-token rule.
  - **Live unclear words**: they never count toward rule 6 and never set the pending word, so a
    pause pass after a live pass with an unclear word needs 2 pause passes to declare it (rule 6
    unchanged).
  - **Rule 10**: at cursor 1 of ayah 2, the last 1 and the last 2 words of ayah 1 are repeats
    with no mistake, under both `Hearing` values; a token matching nothing there is still handled
    by rules 4–6.
  - **Rule 11**: a live mistake at (ayah, position), then a pause pass re-hearing the same wrong
    word and continuation, declares nothing new. After that pause pass, the same mistake can be
    declared again.
- [X] T017 [P] [US1] Extend the property test in `test/widget/recitation_matcher_quran_test.dart`
  to overlapping live passes over all 6,236 ayat (contract › Tests added).
  - **Simulated passes**: for each ayah's words `w[0..n)`, simulate live passes with windows
    `w[a..b)`:
    - `a` is the index of the last word matched (`lastMatchedToken` mapped back), starting at 0;
    - `b` grows by 2 words per pass;
    - each pass drops its last word (`liveHoldBack`);
    - then one pause pass over the remaining `w[a..n)`.
  - **Clean feed**: every ayah completes with 0 mistakes, and the revealed position never
    decreases.
  - **One word dropped, swapped or added** (the existing variants): exactly one mistake of the
    right kind and position is declared, and the cursor never passes it.
  - Keep the run under the existing test's time budget by sampling every 7th ayah for the
    variants and running the clean feed on all.
- [X] T018 [P] [US1] Add controller tests to `test/widget/memorization_session_test.dart` with
  the fake recogniser:
  - **Hold-back**: `emit(['w1','w2','w3'], hearing: live)` reveals `w1` and `w2`, not `w3`; the
    fake records `commit(pass, startSample of w2)`.
  - **Live mistake**: commits `endSample`, signals once, and a following `Heard(pause)` with the
    same words does not signal again.
  - **No match**: commits the current anchor.
  - **Repeat**: a live pass re-hearing an earlier word after a reveal does not hide anything
    (`isHidden` stays false for every revealed word).
  - **Next word mid-pass**: a live `Heard` containing the hinted word does not count it twice,
    and the next word stays expected.
  - **Silence timer**: re-armed by a live `Heard` with words, not by an empty one.
- [X] T019 [P] [US1] Add a live-recogniser test group to `test/unit/speech_recogniser_test.dart`
  (desktop, skipped without the model):
  - feed each clean clip in 0.1 s chunks at real time (`await Future.delayed` per chunk);
  - answer every `Heard(live)` with a `commit`, using the controller's rule against a
    `RecitationMatcher`;
  - **assert**: at least one `Heard(live)` with words arrives before the clip's audio ends; the
    ayah completes; no live pass decodes more than `maxHeld` + 1 s;
  - **print**, per clip: the number of passes, the median decode ms, and each word's delay
    between its `startSample` time and the wall time it was first used.

### Implementation for User Story 1

- [X] T020 [US1] Implement the live rules in `lib/features/memorization/recitation_matcher.dart`
  (contract › rule changes; makes T016 pass):
  - **Rule 7 replaced**: under `Hearing.live`, unexplained and unclear tokens are skipped exactly
    as under `Hearing.pause`, instead of `break`.
  - **Rules 4 and 5 under live**: a mistake from `_explain` is declared only when its winning run
    is ≥ `liveMistakeRun` (2). Otherwise the token is treated as unclear (skipped).
  - **Rule 6 under live**: does not touch `_unclearSegments` or `_pendingHeard`.
  - **Rule 10**: when `_cursor == 1 && _ayah > 0`, a token run matching the last words of
    `ayat[_ayah - 1]` in order is consumed as a repeat, with no progress and no mistake.
    `lastMatchedToken` is set to the last such token.
  - **Rule 11**: track `(int ayah, int position)? _lastMistakeInStretch`:
    - a mistake equal to it is not declared, and its token is skipped;
    - set it whenever a mistake is declared;
    - clear it at the end of every `Hearing.pause` call.
  - **Constant**: add `const liveMistakeRun = 2;` with a doc comment citing research R5.
  **Done, with more rules from the live property test and the desktop run**: rule 12 (a
  window starting on the last word matched hears it again), a live wait at a token or a
  one-token jump back that cannot be judged yet, no "wrong" reading for a word of the ayah
  said again, and `livePassesForMistake` (2 live passes in a row). Both property runs:
  115,914 mutations, 0 failed.

- [X] T021 [US1] Implement live passes in `lib/features/memorization/speech_recogniser.dart`
  (contract › Live passes; data-model › Live follow state):
  - **Worker state**: add `awaitingCommit`, `lastPassMs`, `liveSuspended` and
    `samplesAtLastPass`.
  - **When a pass starts**: after each `accept`, start a live pass when all of these hold:
    - `_vad.isDetected()`;
    - `!awaitingCommit && !liveSuspended`;
    - new samples since the last pass ≥ `livePassEvery × micSampleRate`;
    - wall time since the last pass ended ≥ `lastPassMs`.
  - **What a pass does**: decode `anchor → now` with no padding, emit `Heard(live)` with
    `endSample` = now, then set `awaitingCommit`.
  - **Slow device**: a pass that took > `liveSlowPass` sets `liveSuspended`.
  - **`commit(pass, from)`**: ignored unless `pass` is the latest pass and it was live. Otherwise:
    - `anchor = max(anchor, from)`;
    - trim the held audio;
    - when the held audio still exceeds `maxHeld`, keep only its last second (`anchor = now − 1 s`);
    - clear `awaitingCommit`.
  - **Pause passes**: clear `awaitingCommit` and `liveSuspended`.
  - Remove T012's temporary `maxHeld` pause pass.
  - **Pass numbers**: shared by live and pause passes.
  - **Tracing**: with `const bool.fromEnvironment('MEMO_TRACE')`, `debugPrint` one line per pass:
    hearing, window seconds, decode ms, word count. Never print audio or words in release
    builds; the flag is off by default.
  **Done, with changes from the desktop run (T024)**: every pass decodes with up to
  `liveContext` (3 s) before the anchor and sends only words from the anchor on
  (`anchorTolerance` 0.12 s); `Heard` carries `windowStart`; `tailPad` was dropped. See the
  contract and research R5.

- [X] T022 [US1] Implement live handling in `lib/features/memorization/memorization_controller.dart`
  (contract › MemorizationController; makes T018 pass):
  - **On `Heard(live)`**:
    1. `used = words` without the last `liveHoldBack`.
    2. `e = _matcher.accept([for (w in used) w.text], hearing: Hearing.live)`.
    3. Commit:
       - `e.mistakes.isNotEmpty`: `commit(h.pass, h.endSample)`;
       - else `e.lastMatchedToken >= 0`: `commit(h.pass, used[e.lastMatchedToken].startSample)`;
       - else commit the last anchor sent (keep it in a field, initially 0 and reset on session
         start and `resume`).
    4. `_apply(e)`.
  - **Phase check**: drop live `Heard`s while `phase != listening`.
  - **`livePassesToAgree`**: a constant, 1. When it is 2, a word is used only if the previous
    live pass had the same text at the same index; keep the previous pass's texts in a field.
    Write the branch, and test it in T018 by temporarily overriding the constant through a
    constructor parameter with the default 1.
  - **`_syncWords` stays add-only**: confirm by a comment, and assert in debug that the revealed
    count never decreases.
  **Done, with additions from the desktop run**: a finished last word (nothing heard for
  `wordEndGap` 0.4 s after it) is not held back; `startsOnMatched` is passed when a pass
  starts on a recent word anchor (matcher rule 12); session start resets the recogniser.

- [X] T023 [US1] Pause, resume and end while a pass decodes: in
  `lib/features/memorization/memorization_controller.dart`,
  - `pause()` and `end()` must change phase before anything awaits the isolate. `end()` still
    waits up to `endFlushWait` for the closing `Heard(pause)`.
  - Add a widget test in `test/widget/memorization_session_test.dart`: with the fake holding a
    live `Heard` unanswered, `pause()` changes `phase` synchronously, and a late live `Heard` after
    pause reveals nothing.
- [X] T024 [US1] Run T016–T019. Then on Windows, run the live desktop test over the check set and
  write into `specs/007-khatma-live-recognition/research.md`, in a new "Desktop live run"
  heading under R5:
  - median and 90th percentile word delay;
  - passes per clip;
  - any false reveal, which must be 0.
  **Done**: 8 / 8 clean ayat completed, 0 false alarms (old model 7 / 8); reveal median
  0.55 s, 90th percentile 1.56 s after the word ends. Research R5 › Desktop live run.

- [ ] T025 [US1] **Spike S2** on both reference phones (quickstart › Spikes):
  - **Setup**: profile build with `--dart-define=MEMO_TRACE=1`; run D-1 and D-2.
  - **Record** in research R5 and R8:
    - load time (≤ 3 s);
    - peak memory (Android Studio profiler / Xcode memory gauge);
    - decode ms per pass;
    - the share of words revealed ≤ 1.5 s after being said, which needs ≥ 90% (SC-001):
      measure it by screen recording at 60 fps against the audio track, over at least 100 words
      per phone;
    - decode time as a share of speech time (≤ 50%).
  - **Thread count**: compare `numThreads` 2 against 4 on the Galaxy A15, and fix the faster
    rule that meets the duty limit in `speech_recogniser.dart`.
  - **If it fails**: tune `livePassEvery`, threads and `liveHoldBack` (contract › Constants) and
    rerun. If it still fails, report to the owner before Phase 6.
- [ ] T026 [US1] Device scenarios D-1 to D-9 of `specs/007-khatma-live-recognition/quickstart.md`
  on both reference phones. Record pass or fail, with notes, in a "Device results" section
  appended to quickstart.md.

**Checkpoint**: live word-by-word reveal works on both phones (US1 independently testable).

---

## Phase 4: User Story 2 - Recognition I can trust with the new model (Priority: P1)

**Goal**: Khatma is at least as accurate as the 006 recogniser, is within 5 points of M5's
comparison results, and works offline.

**Independent Test**: spec US2 › Independent Test: the check set through the desktop test and on
the phones, compared with `baseline.md` and the test project's CSV.

- [ ] T027 [P] [US2] Add an accuracy group to `test/unit/speech_recogniser_test.dart` (desktop,
  skipped without the model). It runs every clip through the live and pause path of T019 and
  reads `build/asr/check/mistakes.csv`, then prints:
  - (a) the share of correct ayat completed with 0 mistakes;
  - (b) the share of planned mistakes declared at the right position;
  - (c) false alarms per 100 ayat;
  - each next to `specs/007-khatma-live-recognition/baseline.md` and to M5's rows from the test
    project's results CSV, if its path is given with `--dart-define=M5_CSV=...`.

  It fails when (a) or (b) is below 95%, or below the baseline (SC-004).
  **Partly done**: the desktop test reports (a) clean ayat completed, (b) planned mistakes
  caught from `mistakes.csv`, and false alarms, next to the baseline. Not done: the M5 CSV
  column (`--dart-define=M5_CSV`), and the run on the Memorize-Ayah and 006 S1 sets, which
  need T002's recordings.

- [ ] T028 [US2] Re-check the spellings (research R6):
  - run T027 and list every heard word that failed to match its expected word at similarity
    ≥ `thetaMatch`, grouped by expected word;
  - for systematic Uthmani-style spellings (as in 006 T037), add pairs to `kVariantPairs` in
    `lib/features/memorization/recitation_matcher.dart`, with a test per new pair in
    `test/unit/recitation_matcher_test.dart`;
  - rerun T017's property test.
  **Not started**: no systematic misspellings on the 8 check clips. Needs T002's set.

- [ ] T029 [US2] Tune only if needed: if T027 misses 95%, adjust `thetaMatch`, `thetaUnsure` and
  `liveMistakeRun` within research R5's ranges.
  - Record before and after rates in research R10.
  - Rerun T016, T017 and T027.
  - **If still below 95%**: stop and report to the owner, as 006 required.
- [ ] T030 [US2] Write the accuracy results into research R10: the T027 rates against the baseline
  and M5's CSV, with the SC-005 check (within 5 points).
- [ ] T031 [US2] On both phones, rerun 006 quickstart Q-11 to Q-15 and Q-23 with the new model in
  airplane mode. Q-13 now expects the mistake to be signalled before the pause when two more words
  follow (D-3). Record results in quickstart.md › Device results.

**Checkpoint**: accuracy holds (US2 independently testable against the baseline).

---

## Phase 5: User Story 3 - Move to the new model after updating (Priority: P2)

**Goal**: the old model is deleted on the first launch after updating, the new download shows its
size and free-space need, and it resumes and unpacks safely.

**Independent Test**: spec US3 › Independent Test, i.e. quickstart D-10 to D-12.

- [X] T032 [P] [US3] Implement `static Future<void> removeOtherVersions({Future<Directory> Function()? supportRoot})`
  in `lib/features/memorization/asr_model.dart` (research R7):
  - list `<support>/asr/` and delete every directory not named `asrModelVersion`, comparing by
    name as `_deleteOtherVersions` does;
  - return quietly when the folder is missing;
  - catch and ignore every error;
  - make `_deleteOtherVersions` call it.
- [X] T033 [US3] Call it after the first frame in `lib/main.dart` (in `runMathani()`, after
  `runApp`): `if (!kIsWeb) WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(AsrModel.removeOtherVersions()));`.
  Add a comment citing specs/007 FR-004. This differs from the plan's `app.dart`: `main.dart`
  already owns the startup work and the web check.
  **Done** in `lib/main.dart`, skipped on the web build.

- [X] T034 [P] [US3] Test in `test/unit/asr_model_test.dart`:
  - with `asr/asr-tarteel-tiny-v1/encoder.int8.onnx` and `asr/asr-khatma-v1/tokens.txt` in a temp
    support root, `removeOtherVersions` deletes only the first folder;
  - with no `asr` folder, it completes;
  - a read-only (undeletable) folder does not throw.
- [X] T035 [US3] Use the right sizes in the UI:
  - `lib/features/memorization/range_sheet.dart`:
    - the free-space check (line ~115) uses `_model.requiredBytes - _model.downloadedBytes`;
    - the size shown before downloading stays `totalBytes`, the download size;
  - `lib/features/recitation/downloads_screen.dart`: the memorization model row shows
    `model.diskBytes` when `state == ready`, and `downloadedBytes` otherwise.
  - Update or add widget assertions in the existing range-sheet and downloads tests (find them
    with `grep -rn "Memorization model\|memorizationModel" test`).
  **Done**; no existing widget test covered these sizes, so `asr_model_test` checks
  `requiredBytes` and `diskBytes`.

- [ ] T036 [US3] Device scenarios D-10 to D-12 on both reference phones. Record them in
  quickstart.md › Device results.

**Checkpoint**: updating users move to the new model cleanly (US3 independently testable).

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T037 [P] Update the credits in `lib/features/settings/about_section.dart`:
  - in `registerAssetLicences`, replace `(['Tarteel Whisper tiny (Quran)'], 'assets/licences/LICENSE-tarteel-whisper.txt')`
    with `(['Khatma FastConformer (NVIDIA FastConformer-Hybrid PCD Large, ar)'], 'assets/licences/LICENSE-khatma-model.txt')`;
  - delete `assets/licences/LICENSE-tarteel-whisper.txt`;
  - check the About screen's model credit text, if any, in `lib/app/l10n/app_ar.arb` and
    `app_en.arb`, and update it (FR-012).
- [X] T038 [P] Delete `tool/export_asr_model.py` (Principle IV: no dormant code). Rewrite
  `tool/README.md` › "Memorization model" for `tool/export_khatma_model.py`:
  - the venv and pip lines from quickstart › Export;
  - what the tool writes;
  - the release name `asr-khatma-v1`;
  - pin both download and unpacked hashes in `asr_model.dart`;
  - never replace files in a published release.
- [X] T039 [P] Update `docs/licences.md`:
  - replace the Tarteel model row (line ~48) and the release name (line ~41) with the Khatma
    model: NVIDIA CC BY 4.0, Tilawa MIT, state the changes, `LICENSE-khatma-model.txt`, and
    `NOTICE.txt` in the release;
  - check `docs/store/privacy.md` needs no change: still on the device, same host.
- [X] T040 [P] Update `specs/006-reciters-memorization/contracts/memorization-engine.md` with a
  short note at the top: "Superseded in part by specs/007 contracts/live-recognition.md (model,
  recogniser API, matcher rules 4–7, 10, 11)". Do not rewrite 006's history.
- [ ] T041 Run `integration_test/paging_perf_test.dart` with `WITH_MEMORIZATION` on both phones
  while live passes run, at 60 fps (FR-011, SC-008). Record the result in quickstart.md › Device
  results.
- [ ] T042 **Spike S3** (battery), per quickstart › Spikes on the Galaxy A15: 15 minutes reciting
  continuously, ≤ 10% (SC-008). Record in research R8. If it fails, raise `livePassEvery` or lower
  threads and rerun T025's latency check.
- [ ] T043 Run `dart run tool/size_check.dart` and report the growth in the PR description. About
  0 MB is expected (SC-010).
- [ ] T044 Run D-13 and D-14 from quickstart.md on both phones, and confirm cold start is unchanged
  (≤ 2 s) with the post-frame clean-up.
- [X] T045 Run `flutter analyze` and `flutter test test/unit test/widget`, and fix every finding.
- [X] T046 Add a `docs/release.md` entry for the next version: "Memorization uses the Khatma model
  and shows each word as it is recited; after updating, memorization downloads a new model
  (≈ 108 MB)". Include the size measurement from T043.
- [ ] T047 Release checklist (quickstart.md › Release checklist):
  - every box ticked;
  - S1–S3 results present in research.md;
  - test recordings in `build/asr/check/` deleted.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**:
  - T003 must run **before** Phase 2 changes the code;
  - T004 (S1) gates Phase 2;
  - T006 gates the pinned hashes in T009.
- **Foundational (Phase 2)**: blocks US1 and US2.
- **US1 (Phase 3)** and **US2 (Phase 4)**:
  - they can proceed in parallel after Phase 2;
  - US2's T027 reuses T019's live harness, so start T027 after T019;
  - US2's measurements are final only once US1's live rules (T020) are in, because the shipped
    path is live plus pause.
- **US3 (Phase 5)**: needs only T009 (asr_model). It can run in parallel with US1 and US2.
- **Polish (Phase 6)**: after the stories. T042 (S3) needs T021 and T022.

### User Story Dependencies

- **US1 (P1)**: after Phase 2. No dependency on US2 or US3.
- **US2 (P1)**: after Phase 2. Its final numbers need T020 (US1).
- **US3 (P2)**: after T009. Independent of US1 and US2.

### Within Each User Story

- Tests T016–T019 are written before T020–T022 and fail first.
- Matcher (T020), then recogniser (T021), then controller (T022, T023).
- Desktop run (T024), then phones (T025, T026).

### Parallel Opportunities

- Phase 1: T002 and T005 alongside T001.
- Phase 2: T007/T008 alongside T009/T010. T011 alongside T012 (different files); T013 after T012.
- US1: T016, T017, T018 and T019 are all in different files.
- US3: T032/T034 alongside US1 work.
- Polish: T037, T038, T039 and T040.

---

## Parallel Example: User Story 1

```text
Task: "T016 Live-rule tests in test/unit/recitation_matcher_test.dart"
Task: "T017 Overlapping live passes property test in test/widget/recitation_matcher_quran_test.dart"
Task: "T018 Controller live tests in test/widget/memorization_session_test.dart"
Task: "T019 Live recogniser desktop test in test/unit/speech_recogniser_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1: export, S1, publish, and the **baseline**.
2. Phase 2: Khatma with pause-based reveal (the app is shippable here: same behaviour, new
   model).
3. Phase 3: live reveal, then S2 on the phones.
4. **Stop and validate**: D-1 to D-9 on both phones.

### Incremental Delivery

1. Setup + Foundational: Khatma replaces Whisper, pause-based.
2. US1: live word-by-word reveal (the MVP the owner asked for).
3. US2: accuracy confirmed against the baseline and M5.
4. US3: clean migration for updating users (needed before a store release).
5. Polish: credits, docs, battery (S3), size, release notes.

US3 must be done before any store release, because without it updating readers keep the old
model's 64.5 MB on disk.
