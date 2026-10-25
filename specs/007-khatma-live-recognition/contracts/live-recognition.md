# Contract: Live Recognition with Khatma

Changes to the [006 memorization engine](../../006-reciters-memorization/contracts/memorization-engine.md).
Anything not named here stays as 006 defines it: the microphone, privacy rule (R16), device
gate, controller phases, signals, scoring and UI. Research: [R1–R10](../research.md).

```text
record (PCM16 16 kHz mono)
  → MicSource: Float32 samples; drops samples during the mistake tone           (unchanged)
  → speech isolate:
      Silero VAD: is the reader speaking? where does a pause end a stretch?      (unchanged settings)
      audio since the anchor
      live pass while speaking  ─┐  sherpa-onnx OfflineRecognizer, raw-audio CTC (Khatma, int8)
      pause pass at a pause     ─┘  → pieces + times → words → clean (R6) → Heard
  → MemorizationController:
      live: hold back the last word → RecitationMatcher(hearing: live) → commit(new anchor)
      pause: RecitationMatcher(hearing: pause)
```

## AsrModel (`asr_model.dart`)

```dart
const asrModelVersion = 'asr-khatma-v1';

typedef AsrFile = ({
  String name,            // as served; a name ending in .gz is unpacked on the device
  int bytes, String sha256,                 // the download
  int? unpackedBytes, String? unpackedSha256, // set for .gz files: the file kept
});

class AsrModel extends ChangeNotifier {
  // As 006, plus:
  int get diskBytes;                       // space used once ready (Settings › Downloads)
  int get requiredBytes;                   // free space needed to download and unpack (≈ 240 MB)
  static Future<void> removeOtherVersions({Future<Directory> Function()? supportRoot});
}
```

| File (served) | Kept as | Notes |
| --- | --- | --- |
| `model.int8.onnx.gz` | `model.int8.onnx` | 107,497,463 B → 133,342,218 B; both SHA-256 pinned (T001) |
| `tokens.txt` | same | 1025 lines: pieces 0–1023, `<blk> 1024` |
| `silero_vad.onnx` | same | Same bytes and SHA-256 as `asr-tarteel-tiny-v1` |

- **Download**: as 006 (one file at a time, `Range` resume from `.part`, hash check, rename).
- **Unpack**: once a `.gz` passes its check, it is decompressed on a background isolate
  (`Isolate.run`, `gzip.decoder` streamed to `<name>.part` while hashing). The result must match
  `unpackedBytes` and `unpackedSha256`, otherwise it is deleted and the error is `damaged`. Then
  the `.gz` is deleted. A `.gz` that was checked but not yet unpacked (the app closed while
  unpacking) is unpacked on the next `download()` without fetching it again.
- **State**: `ready` when every kept file exists with its expected size. `partial` when any
  `.part` or checked `.gz` exists. `totalBytes` stays the download size, which is the size shown
  before downloading.
- **Free space**: the precondition sheet checks `requiredBytes`, not `totalBytes`.
- **`removeOtherVersions()`** (FR-004, R7): deletes every directory under `<app support>/asr/`
  except `asrModelVersion`. `app.dart` calls it unawaited after the first frame. It never throws:
  errors are ignored and retried on the next launch.

## SpeechRecogniser (`speech_recogniser.dart`)

```dart
enum Hearing { live, pause }

/// One word heard: cleaned (R6) and normalised, and where it starts and ends in the session's
/// audio (endSample: where its last piece was heard).
class HeardWord { final String text; final int startSample; final int endSample; }

/// The words of one pass.
class Heard {
  final int pass;              // increasing; a commit names the pass it answers
  final Hearing hearing;
  final List<HeardWord> words; // may be empty; only words from the anchor on
  final int windowStart;       // the anchor the pass heard from
  final int endSample;         // the last sample decoded
}

abstract class SpeechRecogniser {
  Future<void> load(String modelDir);   // ≤ 3 s on the reference phones (R8); once per app run
  void accept(Float32List samples);
  Stream<Heard> get heard;
  /// After a live Heard: drop audio before [fromSample] and allow the next live pass.
  /// Ignored when [pass] is not the latest live pass.
  void commit(int pass, int fromSample);
  void flush();                         // on pause/end: a pause pass over what is held
  void reset();                         // drop held audio without decoding
  Future<void> dispose();
}
```

`Segment` and `forcedSplit` are removed.

**Model** (R2): `OfflineModelConfig(omnilingual: OfflineOmnilingualAsrCtcModelConfig(model:
'$dir/model.int8.onnx'), tokens: '$dir/tokens.txt', numThreads: 2 | 4)`. Threads follow 006's
rule; S2 may change it. sherpa-onnx normalises each window to zero mean and unit variance and
reads every output frame.

**Isolate state**: `anchor` (sample index), the audio from up to `liveContext` before it to now,
the latest `pass`, `awaitingCommit`, `lastPassMs`, `liveSuspended`, and the VAD.

**Context** (desktop live run, research R5): every pass decodes from up to `liveContext` = 3 s
before the anchor, never before the last `reset()`, and sends only the words that start at or
after `anchor − anchorTolerance` (0.12 s). Windows of one or two seconds made the model cut and
invent words.

**Live passes**: a pass starts when every one of these holds:

| Condition | Value |
| --- | --- |
| The VAD detects speech (`isDetected()`) | — |
| Not `awaitingCommit` and not `liveSuspended` | — |
| New audio since the previous pass | ≥ `livePassEvery` = 0.5 s |
| Time since the previous pass ended | ≥ `lastPassMs` (duty ≤ about 50%) |

- **What a pass does**: decodes `anchor − context → now`, with no silence added, and emits
  `Heard(live)`. It then sets `awaitingCommit` until `commit` arrives.
- **Slow device**: a pass that takes longer than `liveSlowPass` = 2 s sets `liveSuspended` until
  the next pause (FR-010).
- **Long hold**: when the held audio passes `maxHeld` = 20 s, the pass is still a live pass. On
  its commit, the isolate keeps at most the last 1 s, wherever the controller put the anchor.

**Pause passes**: the VAD ends a segment (a pause of `vadMinSilence` 0.5 s), or `flush()` is
called. The isolate then decodes `anchor − context → segment end`, with no silence added (S1:
added silence enters the per-feature statistics and shifts words), and emits `Heard(pause)`. It
sets `anchor` to the segment end and clears `awaitingCommit` and `liveSuspended`. The VAD's 12 s
soft limit no longer cuts anything: a segment ended by it is treated as speech continuing, not
as a pause. On the desktop the VAD ended a recitation about 1.3 s after the voice stopped, and it
takes digital zeros for speech: tests feed room noise.

**Words from pieces**: each piece that starts with a space or `▁` starts a word. A word's
`startSample` is the window start, plus its first piece's timestamp × `khatmaFrameScale` (4: the
reported 20 ms frames are Khatma's 80 ms frames) × 16000, minus `anchorMargin` = 0.16 s, never
before the window start. Cleaning follows research R6.

**Fake**: `FakeSpeechRecogniser` emits scripted `Heard`s and records `commit` calls.

## RecitationMatcher (`recitation_matcher.dart`)

```dart
enum Hearing { live, pause }   // the same enum, from a pure-Dart file the matcher can import

MatchEvents accept(List<String> tokens, {required Hearing hearing, bool startsOnMatched = false});

class MatchEvents {
  // As 006, plus:
  final int lastMatchedToken;  // index in tokens of the last token matched to a word (forward
                               // or back); -1 if none
  final bool droppedRest;      // the tokens after a mistake were dropped, also when rule 11
                               // kept it from being declared again
}
```

Rule changes. 006's rule numbers are kept; "final segment" in 006 now means `Hearing.pause`.

| Rule | Change |
| --- | --- |
| 4, 5 (wrong, missed, added) | **Pause**: unchanged, except that a word of this ayah said again is never read as a word said *instead of* the expected one (it is a repeat). **Live**: declared only when (a) the reading that explains it lines up at least `liveMistakeRun` = 2 tokens and (b) `livePassesForMistake` = 2 live passes in a row found it at the same word: the model hears short words differently from one window to the next. |
| 2 (going back) | **Live**: a jump back on one token waits for more words, unless it repeats the last word matched; one common word could go back anywhere. |
| 6 (unclear twice) | Pause only. Live passes neither count unclear words nor set `_pendingHeard`. |
| 7 (provisional) | **Replaced**: a live pass waits (stops) at a token it cannot judge yet, until at least `liveMistakeRun` tokens follow it; with them and still no explanation, it goes on past it as a pause pass does. |
| **10 (new)** | At `cursor == 1` of ayah *k* > 0, tokens matching the last words of ayah *k−1*, in order, are a repeat: no mistake, no progress. Covers a window starting on the word that completed the previous ayah, and readers who link ayat. |
| **11 (new)** | Within one stretch of speech (its live passes and the pause pass that closes it), a mistake at the same ayah and position as the last mistake declared in that stretch is not declared again. A pause pass can start before the controller's last commit reaches the isolate, so it may re-hear words a live pass already judged. |
| **12 (new)** | With `startsOnMatched` (the pass was decoded from the start of the last word matched), the first tokens that read that word, or its last part, are consumed as that word, even when it looks like the next one («الله» before «والله» in 2:207). |

**Tests added to the property test over all 6,236 ayat**:
- **Clean recitation**: each ayah's own words, fed as overlapping live passes (growing windows,
  each starting on the last matched word, last word held back), then one pause pass, complete it
  with 0 mistakes.
- **One word dropped, swapped or added**: the same feed declares exactly one mistake, of the
  right kind and position, and no word after it is revealed. The simulated reader stops at the
  signal, as 006's test drops the rest of a pause pass.
- Result (2026-10-25): 115,914 mutations, 0 failed, for both the pause feed and the live feed.

## MemorizationController (`memorization_controller.dart`)

- **On `Heard(live)`**:
  1. `tokens` = the words' text without the last `liveHoldBack` = 1 word, unless nothing was
     heard after it for `wordEndGap` = 0.4 s (`endSample − last.endSample`): a finished word,
     often the last of an ayah, is used before the VAD notices the pause.
  2. `e = matcher.accept(tokens, hearing: live, startsOnMatched: heard.windowStart is one of
     the last 4 word anchors committed)`.
  3. Then commit:
     - `e.mistakes` not empty or `e.droppedRest`: `commit(pass, heard.endSample)`, so
       everything heard so far is used.
     - else `e.lastMatchedToken ≥ 0`: `commit(pass, used[e.lastMatchedToken].startSample)`, which
       is remembered as a word anchor.
     - else `commit(pass, heard.windowStart)`, so nothing moves and the next pass may start.
  4. Apply the events as in 006 (`_apply`: signal, `_syncWords`, page follow, end).
- **On `Heard(pause)`**: `matcher.accept(all words, hearing: pause, startsOnMatched: …)`, then
  `_apply`.
- **Session start** resets the recogniser, which outlives sessions, so a session hears only
  itself.
- **Reveals stay monotonic**: `_syncWords` only adds words to the revealed and hinted sets.
  The matcher's cursor may go back on a repeat; nothing is hidden again (FR-007).
- **Silence pause**: the 30 s timer is re-armed by any `Heard` with at least one word.
- **Next word / Show this ayah during a pass**: unchanged calls. A later pass that hears the
  hinted word sees it as a repeat (rule 2), so it neither counts twice nor skips a word.
- **`livePassesToAgree`** = 1 (R5): when set to 2, a word is used only once two consecutive live
  passes have heard the same word at the same position. It is off unless S2 finds false reveals.

## Constants

S1 and S2 tune these, then they are fixed in code:

| Name | Value | Where |
| --- | --- | --- |
| `livePassEvery` | 0.5 s | recogniser |
| `liveSlowPass` | 2 s | recogniser |
| `maxHeld` | 20 s | recogniser |
| `anchorMargin` | 0.16 s | speech_words |
| `khatmaFrameScale` | 4 | speech_words (R2) |
| `liveContext` | 3 s | recogniser |
| `anchorTolerance` | 0.12 s | recogniser |
| `liveHoldBack` | 1 word | controller |
| `wordEndGap` | 0.4 s | controller |
| `livePassesToAgree` | 1 | controller |
| `liveMistakeRun` | 2 tokens | matcher |
| `livePassesForMistake` | 2 passes | matcher |
| `vadThreshold`, `vadMinSilence`, `vadMinSpeech` | 0.25, 0.5 s, 0.25 s | unchanged from 006 |
| `vadMaxSpeech` | 12 s | kept for the VAD; no longer splits |

Removed: `maxPiece`, `forcedSplitOverlap` and `tailSilence`, all of which were Whisper-specific.
`tailPad` was planned and dropped after S1: added silence shifts words.
