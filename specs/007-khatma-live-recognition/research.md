# Research: Khatma Recogniser and Live Word-by-Word Reveal

Feature 006's memorization engine is the starting point: [006 research](../006-reciters-memorization/research.md)
R6–R16 and the [006 engine contract](../006-reciters-memorization/contracts/memorization-engine.md).
This file covers only what changes. Findings marked *measured* were taken on 2026-10-25 from the
Khatma package used by the Memorize-Ayah test project (`C:\Users\Hamza\Memorize-Ayah`).

## R1. What the Khatma model is

**Finding** (from the [model card](https://huggingface.co/adnanfet/khatma-model) and the test
project, research R11 there):
- It is **NVIDIA FastConformer-Hybrid PCD Large (ar)** (`stt_ar_fastconformer_hybrid_large_pcd_v1.0`),
  CTC head only, quantised to int4 and repacked. The test project found its weights match
  NVIDIA's within int4 precision: it is not a further fine-tune.
- The ONNX graph takes **raw 16 kHz audio** (`audio_signal` [batch, time], `length` [batch]) and
  computes the mel features inside the graph. Output: `log_probs` [batch, frames, 1025].
- Vocabulary: NVIDIA's 1024 SentencePiece pieces with the **blank last (1024)**. The repo ships no
  vocabulary; the test project used the line order of `tokens.txt` from
  [dev-ahmedhany/…-sherpa-ctc](https://huggingface.co/dev-ahmedhany/stt_ar_fastconformer_hybrid_large_pcd_v1.0-sherpa-ctc),
  which numbers the pieces 1–1024 and so only fits a blank at 0.
- Container "KFC1": a JSON header, the ONNX graph, then int4 weight blocks that rebuild the
  graph's external int8 file `tezine.bin` (154 matrices, `MatMulInteger` with per-row scales).
- Output is fully voweled Arabic, sometimes with punctuation (the model is trained for
  punctuation and diacritics).
- Licences: **CC BY 4.0** (NVIDIA, the model), and **MIT** (Tilawa project, the ONNX export Khatma
  started from). Both allow redistribution and commercial use with credit and a note of changes.

**Measured** (package 89,410,608 bytes, SHA-256 `67043116…dc9b9f`):

| Part | Bytes | gzip -9 |
| --- | --- | --- |
| ONNX graph (fp32 and int8 constants inline) | 38,454,702 | 29,821,802 |
| Rebuilt `tezine.bin` (int8) | 94,896,128 | 75,601,445 |
| **Unpacked total** | **133.4 MB** | **105.4 MB** |

## R2. Running it on the phone

**Decision** (revised by spike S1, 2026-10-25): run **Khatma's graph whole, features included**,
on the **`sherpa_onnx` 1.13.8 already in the app**, as a raw-audio CTC model
(`OfflineOmnilingualAsrCtcModelConfig`, the "omnilingual" type). No new dependency, no store-size
growth.

The maintainer tool (`tool/export_khatma_model.py`) converts the Khatma package once (R4):
1. **Unpack** KFC1 into the graph and int8 weights (a port of the test project's
   `khatmaPackage.ts`, checked by the same row-maximum property: every row reaches ±127).
2. **Compute `length` inside the graph** from the waveform's shape (`Shape(audio_signal)[1:2]`).
   sherpa-onnx feeds a raw-audio model one input. Nothing else in the graph changes.
3. **Embed the weights** in a single `.onnx` file (133.3 MB, under protobuf's 2 GB limit).
4. **Write `tokens.txt`** with the pieces numbered 0–1023 in the line order above, plus
   `<blk> 1024`. sherpa-onnx takes the blank from `<blk>`, and the vocabulary size from the
   output's shape (1025).

**How sherpa-onnx runs it** (from its 1.13.8 sources, `offline-omnilingual-asr-ctc-model.cc`):
- It normalises the waveform to zero mean and unit variance, then passes it as the only input.
  Khatma's per-feature normalisation makes its features nearly blind to that. Scaling the graph's
  log guard (2⁻²⁴) by 1–1600× to undo the gain changed nothing on the check set.
- It decodes **every output frame**.
- It reports token times with a 20 ms frame shift. Khatma's frames are 80 ms (8× subsampling), so
  the app multiplies the times by 4 (`khatmaFrameScale`).
- It writes each word-starting piece with a leading space instead of `▁`.

**Spike S1 results** (check set: the 8 Alafasy clips of 006 T040, 97 words):

| Route | Words matching the Quran text (similarity ≥ 0.75) | Agreement with Khatma's graph (matcher's similarity) |
| --- | --- | --- |
| Khatma's graph on raw audio (onnxruntime 1.31, reference) | 97 / 97 | — |
| **Raw-audio model in sherpa-onnx (chosen)** | **96 / 97** | **96 / 97 = 98.97%** (pass at 97%) |
| Preprocessor cut off, sherpa-onnx's NeMo CTC (first plan) | 94 / 97 | 94 / 97 |

- **Why the first plan failed**:
  - sherpa-onnx computes its own fbank. It correlates only 0.957 with NeMo's features (framing
    offset, per-frame pre-emphasis, edge padding).
  - Its NeMo path decodes only ⌊frames / 8⌋ output frames, which drops the last frame. «تكذبان»
    (55:13) came out «تكذب», which the matcher would not accept.
  - Padding the audio did not fix this reliably (0.04–0.5 s of silence, reflection or noise all
    shifted other words), because the padding enters the per-feature statistics.
- **What still differs**: in 2:255 (52 s), «بين» was heard «بي». Several differences are sherpa
  being closer to the text than the reference run (سنه, نوم, عنده, يؤوده).
- **Calling onnxruntime directly** through the copy sherpa-onnx ships is not possible on iOS:
  `SherpaOnnxC.framework` does not export `OrtGetApiBase`.

**Alternatives considered**:
- *A second ONNX Runtime (Flutter `onnxruntime` plugin) to run the Khatma graph as is*: a second
  copy of onnxruntime is about +10 MB per platform, and two runtimes for one feature breaks
  Principles IV and V.
- *Cut off the preprocessor and run it as a NeMo CTC model* (the first plan): fails S1 (above).
- *The 456 MB fp32 sherpa-onnx export of the same NVIDIA model (dev-ahmedhany), quantised
  ourselves*: same sherpa-onnx features and last-frame drop as the first plan, plus our own
  quantisation.
- *The sherpa-onnx RNNT (transducer) bundle of the same model*: transducers can carry common
  phrases forward from context (the export's own note: "won't emit «بسم الله» before «الرحمن
  الرحيم»" only holds for CTC). Rejected for mistake detection.

## R3. Live, or live-like?

**Finding**: neither the previous model nor Khatma is a streaming model. Both read a stretch of
audio at once. Khatma's NVIDIA base is an offline FastConformer with full context, not the
cache-aware streaming variant; the test project lists it as "streaming not confirmed" and makes
it live-like on its Live screen (`src/core/windowTrack.ts`: re-read the last 6 s every 0.6 s of
new audio). The true streaming candidates in the comparison (M2, M3) were not chosen.

CTC decodes a window in one pass with no text-generation loop, so re-reading audio often is
affordable. It also does not invent words at the cut edge the way Whisper tends to; a cut word
comes out as an unclear fragment.

**Decision**: live-like **re-reading with commit and trim** (R5), not a fixed 6 s window.

## R4. Packaging and download

**Decision**: release `asr-khatma-v1` on the project's GitHub Releases, as in 006 R9, with:

| File | Download | On the device |
| --- | --- | --- |
| `model.int8.onnx.gz` | **107.5 MB** (107,497,463 B, gzip -9; *measured* in S1) | `model.int8.onnx` **133.3 MB** (133,342,218 B) |
| `tokens.txt` | 13 KB | same |
| `silero_vad.onnx` | 0.6 MB (unchanged from 006) | same |

- **Download**: resumable with `Range` into `model.int8.onnx.gz.part`, hash checked, then
  **decompressed on a background isolate** with `dart:io`'s `gzip` into `model.int8.onnx.part`,
  whose size and SHA-256 are also pinned. Then rename and delete the `.gz`. Peak space ≈ 240 MB;
  the free-space check asks for that (`requiredBytes`).
- **Size shown to the reader**: the download size (≈ 108 MB). Settings › Downloads shows the
  space used on the device (≈ 134 MB).
- **The spec's "about 90 MB" assumption** is updated to ≈ 108 MB download and ≈ 134 MB on the
  device (spec Assumptions allowed the plan to confirm the size).

**Alternatives considered**:
- *Our own int4 package (≈ 88 MB) unpacked in Dart into one `.onnx`*: about 17 MB less to
  download, but the app would have to write a protobuf file with the weights placed at recorded
  offsets. That adds code with its own failure modes, for a one-time saving. Recorded as the next
  step if the owner wants the smaller download.
- *Plain `.onnx` (133 MB)*: 26 MB more for every reader.
- *The original Khatma `.bin` from Hugging Face*: needs graph surgery that cannot happen on the
  phone (R2), and we would not control availability (006 R9).

## R5. Live-like reveal: re-read, commit, trim

**Decision**: the speech isolate keeps the audio **since the anchor**: the start of the last word
the matcher accepted. While the voice activity detector says the reader is speaking, it decodes
that audio again whenever enough new audio has come in. The matcher takes the words heard and
the controller moves the anchor forward. At a pause, the rest is decoded once as before, with the
pause rules.

```text
audio:   |== committed (dropped) ==|w5|w6 w7 w8 w9 (still speaking)…
                                   ^ anchor = start of w5, the last word matched
live pass:  decode anchor→now → [w5 w6 w7 w8 w9?] → hold back the last word (may be cut)
            → matcher (live rules) → w6 w7 w8 revealed → anchor = start of w8
pause:      decode anchor→pause end → matcher (pause rules: today's 006 rules)
```

- **Why the window starts on an accepted word**: the window then never starts mid-word. The
  matcher already treats an earlier word as a repeat (006 rule 2), so the overlap costs nothing.
  Across an ayah boundary a new rule covers it (rule 10 in the [contract](./contracts/live-recognition.md)).
- **Word times**: sherpa-onnx returns each piece with its time (`OfflineRecognizerResult.tokens`
  and `timestamps`). A piece starting with a space (or `▁`) starts a word. The times are reported
  at 20 ms per frame but Khatma's frames are 80 ms, so they are multiplied by 4 (R2). The anchor
  sits a 0.16 s margin before the word's first piece.
- **Hold-back**: the last word of a live pass is not used. Its audio may be cut, and that
  covers the spec's "heard only partly" edge case. At a pause nothing is held back.
- **Mistakes while reciting**: in a live pass a mistake is declared only when **at least 2 words
  after it line up** inside the words used (FR-009). The pause rules stay as in 006. After a
  live mistake, everything heard so far is committed (dropped), just as a final segment drops
  its rest after a mistake. A mistake at the same word is not declared twice in one stretch of
  speech, so a reader who carries on for a moment after the signal is not signalled again.
- **Pacing**: the next pass starts once both of these hold:
  - at least 0.5 s of new speech has come in;
  - at least as much time as the previous pass took has passed, which keeps decoding to about
    half the time at most (battery, heat).
  If one pass takes over 2 s, live passes stop until the next pause, and the reader gets 006's
  pause-based reveal (FR-010). Audio held over 20 s without a commit is decoded as a live pass
  and committed except its last second, like 006's forced split.
- **Lock-step with the controller**: the isolate starts the next live pass only after the
  controller replies with the new anchor (`commit`). The matcher lives on the main isolate with
  the session state, and the round trip is well under a millisecond. Lock-step means a pass never
  decodes audio the matcher has already moved past.
- **Expected latency** (to be measured in S2): a word is revealed once the next word has begun
  (hold-back), plus up to one pacing step, plus one decode. Recited words last about 0.4–0.8 s.
  The test project measured a real-time factor of 0.1–0.2 on desktop, which puts a 3 s window at
  0.3–0.6 s. That makes FR-006's 1.5 s plausible on the Galaxy A15; S2 confirms it on both
  reference phones.

**Alternatives considered**:
- *The test project's fixed 6 s window with a second matcher (`WindowTracker`)*: proven in the
  test project, but it is a separate alignment engine beside the tuned 006 matcher (Principle V,
  "one way"), and a fixed window re-decodes words long since accepted.
- *Decode the whole utterance from its start on every pass*: simple, but the cost grows with the
  utterance (quadratic over a long ayah) and would break the battery target on long ayat.
- *Local agreement (a word is stable only when two passes agree)*: safer but adds one pass of
  delay to every word. It is kept as a tuning switch (`livePassesToAgree`, 1 by default) in case
  S2 finds false reveals.

### Desktop live run (T024, 2026-10-25)

The 8 Alafasy check clips were played at real time (100 ms chunks, then 2 s of room noise) through
the speech isolate on Windows, with a matcher answering every live pass as the controller does
(`test/unit/speech_recogniser_test.dart`). The design changed during the run:

| Step | Clean ayat completed with 0 mistakes | False alarms | Finding |
| --- | --- | --- | --- |
| Windows from the anchor only | 3 / 8 | 3 | 1–2 s windows: cut and invented words («عليهه», «لوساط», «قديريه») |
| + 3 s of context before the anchor (`liveContext`) | 7 / 8 | 1 | «من» heard «منن» in one pass, missing in the next: a false «missed» |
| + a live mistake needs 2 passes in a row (`livePassesForMistake`) | 7 / 8 | 0 | 2:255 stuck on its last word: the closing pass invented «درس» over digital silence |
| + room noise instead of zeros after the clip (test), finished last word used (`wordEndGap`) | **8 / 8** | **0** | — |

- **Old recogniser on the same clips** (baseline.md): 7 / 8.
- **Reveal delay** after each word ends (word ends from a whole-clip decode): median **0.55 s**,
  90th percentile **1.56 s**, max 2.2 s over 96 words. The spec's 1.5 s (SC-001) is borderline on
  the desktop; S2 measures it on the phones.
- **Live passes started before each clip ended**, on every clip. The longest window was 7.2 s, and
  2:255 (52 s) never held more than 5.4 s.
- **The VAD's pause** came about 1.3 s after the voice stopped, which is why `wordEndGap` lets a
  finished last word show without waiting for it. The VAD takes digital zeros for speech.
- **Matcher property test**: two more rules came from the live feed. Rule 12 (a window that
  starts on the last word matched hears it again, even when the next word looks alike) and the
  live wait at an unjudgeable token or a one-token jump back.

## R6. Cleaning the model's output

**Decision**: words are built from the pieces (R5). Each word is cleaned by removing
punctuation (Unicode categories P* and the Arabic marks `، ؛ ؟ ۔ ٪ ٭`), then by the existing
`normalizeArabic` (diacritics, alef forms, tatweel). Words that end up empty are dropped. The
006 normaliser does not strip punctuation, and Khatma writes some.

`kVariantPairs` (006 T037) was built from Whisper's spellings. S1 re-checks the Khatma
transcripts of the check set for new Uthmani-style spellings and adds pairs if needed.

## R7. Removing the previous model (FR-004)

**Decision**: `AsrModel.removeOtherVersions()` deletes every folder under `<app support>/asr/`
except the current version. It runs once, unawaited, after the first frame of each launch. It
costs one directory listing when there is nothing to delete, so cold start is unchanged. 006
already deletes other versions when a download starts; this makes it happen on launch too.
Settings › Downloads reads the current version only, so the old row disappears.

## R8. Memory, load time and device gate

- **Memory** (*estimated*): sherpa-onnx reads the 133 MB file into memory, then onnxruntime builds
  the session; peak ≈ 300–400 MB while loading, about 200 MB after. 006's gate (arm64, ≥ 3 GB
  RAM, R15) stays. The iPhone SE (2nd gen) has 3 GB and is the case to measure in S2.
- **Load time**: 006 targeted ≤ 1.5 s for a 64 MB model. The target becomes **≤ 3 s** on the
  reference phones, behind the existing "preparing" state. The model loads once per app run.
- **Threads**: as 006, 2 on 4-core devices and 4 on 6 or more. S2 compares 2 against 4 on the
  Galaxy A15 (2 big cores) for latency against battery.

## R9. Credits

**Decision**: the About screen and the licences page drop "Tarteel Whisper tiny (Quran)" and
`LICENSE-tarteel-whisper.txt`, and add:
- `assets/licences/LICENSE-khatma-model.txt`: the attribution to NVIDIA FastConformer-Hybrid PCD
  Large (ar), the CC BY 4.0 notice and link, Khatma's statement of changes, ours (preprocessor
  removed, weights embedded, metadata added, compressed), and Tilawa's MIT licence text.
- The release gets the same text as `NOTICE.txt`.
- `docs/licences.md` gets the row; `docs/store/privacy.md` needs no change (still on the device).

## R10. Accuracy checks against the comparison

- **Check set**: the Memorize-Ayah test recordings (Surah Al-Mulk, planned mistakes) exported as
  16 kHz mono float32, plus 006's S1 sets.
- **SC-004 (no regression)**: the same recordings go through the 006 path (Whisper, pause
  segments) and the new path, and both rates are compared.
- **SC-005**: mistakes caught and false alarms are compared with M5's rows in the test project's
  CSV export.
- Both run as the existing skipped-unless-present desktop test (`speech_recogniser_test.dart`),
  pointed at `build/asr/khatma-v1` and `build/asr/check`.

## Spikes (before implementation)

| Spike | Question | Pass |
| --- | --- | --- |
| **S1** Conversion | Does the converted model in sherpa-onnx (desktop) hear what the Khatma graph hears? | ≥ 97% of words agree as the matcher compares them; `tokens.txt` and blank confirmed; sizes measured. **Passed 2026-10-25** (98.97%, R2) |
| **S2** On the phones | Load time, memory, live-pass decode time and reveal latency, on the Galaxy A15 and iPhone SE 2 | Load ≤ 3 s; peak memory under the gate; SC-001 latency; decoding ≤ 50% of speech time |
| **S3** Battery | 15-minute session on the Galaxy A15 | ≤ 10% battery (SC-008) |

S1 failed for the first plan (NeMo CTC) and passed for the raw-audio route (R2). If S2 fails on latency, the knobs are threads,
pacing and hold-back. If it fails on memory, the iPhone SE 2 drops below the gate, and that is
reported to the owner.
