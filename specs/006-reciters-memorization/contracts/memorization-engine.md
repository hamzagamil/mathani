# Contract: Memorization Engine

How a reader's voice becomes revealed ayat, a score and a review. Research: R6–R16. Everything
in this contract runs on the device. No audio leaves the device, and none is written to storage
(FR-019).

```text
record (PCM16 16 kHz mono)
  → MicSource: Float32 samples; drops samples during the mistake tone
  → SpeechSegmenter: Silero VAD; segment ends on a 0.5 s pause or at 12 s with 1 s overlap
  → Recogniser: sherpa-onnx OfflineRecognizer, Whisper tiny int8, lang ar, on an isolate
  → normalizeArabic + split → tokens
  → RecitationMatcher: pure Dart; reference words from ayahs.search_text
  → MemorizationController: session state, signals, page follow; MemorizationScope
```

## Files (`lib/features/memorization/`)

| File | Responsibility | Pure Dart? |
| --- | --- | --- |
| `asr_model.dart` | Model files, pinned hashes, download/verify/delete, `AsrModelState` | no (`dart:io`) |
| `device_support.dart` | arm64 and RAM gate (R15), through the device channel | no |
| `mic_source.dart` | `record` stream → `Float32List`, start/stop, tone gating | no |
| `speech_recogniser.dart` | VAD + sherpa-onnx on a long-lived isolate; `Stream<Segment>` | no |
| `recitation_matcher.dart` | Alignment, mistakes, completion | **yes** |
| `memorization_score.dart` | `SessionResult` from progress | **yes** |
| `memorization_controller.dart` | Session phases, wiring, signals, lifecycle | no (Flutter) |
| `memorization_bar.dart`, `range_sheet.dart`, `result_screen.dart`, `mic_explainer.dart` | UI ([memorization-ui](./memorization-ui.md)) | no |

Rule (R16, enforced by `test/unit/memorization_privacy_test.dart`): no file in the folder
except `asr_model.dart` may import `dart:io`'s `HttpClient`, `File` write APIs or
`path_provider`. `asr_model.dart` never sees audio.

## AsrModel

```dart
enum AsrModelState { absent, partial, downloading, ready }

class AsrModel extends ChangeNotifier {
  AsrModelState get state;
  int get downloadedBytes; int get totalBytes;      // for progress and the size shown
  Future<void> download();                          // resumable; verifies SHA-256; notifies
  void cancel();
  Future<void> delete();                            // frees the files at once
  String get modelDir;                              // valid only when ready
}
```

- **Before downloading**: the network and free-space checks reuse `DeviceChannel.networkState()`
  and `freeBytes()`, with the same sheet as surah downloads (004 FR-028).
- **While downloading**: one file at a time, `Range` resume from `.part`, rename after the hash
  matches. A wrong hash deletes the part and fails with a retry message.
- **Where it runs**: only while the app runs, as for 004 downloads.

## SpeechRecogniser

```dart
class Segment { final String text; final bool forcedSplit; }

abstract class SpeechRecogniser {
  Future<void> load(String modelDir);               // ≤ 1.5 s on reference phones; once per app run
  void accept(Float32List samples);                 // from MicSource
  Stream<Segment> get segments;                     // one per VAD segment, decoded
  void flush();                                     // on pause/end: decode what is buffered
  void reset();                                     // drop buffered audio without decoding
  Future<void> dispose();
}
```

- **Isolate**: decoding runs on a background isolate so the UI thread never blocks (Principle
  III). Samples are sent as transferable typed data.
- **VAD**: Silero, threshold **0.25** (chanted elongations score low as speech; R8),
  `min_silence_duration` 0.5 s, `min_speech_duration` 0.25 s, `max_speech_duration` 12 s.
  sherpa-onnx treats the maximum as soft, so a segment ended by it is **held** and joined to what
  follows until a pause, as long as 25 s is not exceeded. Audio over 25 s is decoded in 25 s pieces
  that overlap by 1 s; all but the last are `forcedSplit`.
- **Decoding**: 2 s of silence is appended to each piece, or Whisper drops the last word (R8).
- **Whisper**: language `ar`, task `transcribe`, no initial prompt (R8). Threads: 2 on 4-core
  devices, 4 on 6 or more cores.
- **Memory**: the model is loaded on first use and released when memorization is closed and the
  app goes to the background.
- **Fake** for tests: `FakeSpeechRecogniser` emits scripted `Segment`s.

## RecitationMatcher (pure Dart)

```dart
class RefWord { final int wordId; final int position; final String form; }  // form: normalised imla'i

class RecitationMatcher {
  RecitationMatcher(List<List<RefWord>> ayat, {MatchTuning tuning});
  int get ayahIndex;                       // expected ayah within the range
  int get cursor;                          // next word position (1-based) in the expected ayah
  MatchEvents accept(List<String> tokens, {required bool finalSegment});
  void hintNextWord();                     // marks cursor as hinted, advances
  void revealRest();                       // completes the expected ayah as revealed
}

class MatchEvents {
  final List<int> matchedPositions;        // advanced this call
  final List<AyahMistake> mistakes;        // declared this call (see data-model)
  final bool ayahCompleted;                // expected ayah is fully matched
}
```

`MatchTuning` sets the thresholds; S1 tunes them and they are then fixed as constants:

| Setting | Start value | Meaning |
| --- | --- | --- |
| `θ_match` | 0.75 | Similarity at which a token matches a word |
| `θ_unsure` | 0.55 | Below `θ_match` but at least this: unclear; never advances, never a mistake on its own |
| `lookBack` | whole ayah | How far back a restart may jump without counting as a mistake |
| `lookAhead` | 3 | How far forward a skip is recognised as "missed" |

`similarity` is `1 − levenshtein(a, b) / max(|a|, |b|)` on normalised forms. It is also tried on
two adjacent tokens joined against one word, and on one token against two adjacent words joined.
Orthographic variants are applied to both sides first, from `kVariantPairs` (built in T-match
from a diff of the Uthmani and imla'i text).

Rules (each one is a unit test):
1. A token matching the word at `cursor` advances the cursor by one.
2. A token matching an earlier word of the ayah moves the cursor back to just after it. No
   mistake (FR-014).
3. At the start of the range, or at `cursor == 1`, tokens matching the isti'adha or basmala are
   consumed without effect, unless the expected words are those words (1:1, 27:30).
4. On a **final** segment, an unmatched token followed by tokens that match words
   `cursor+1..cursor+lookAhead` is a **wrong** word at `cursor` when the counts line up, and
   otherwise a **missed** word at `cursor`. The cursor stays at the wrong or missed word
   (Clarification Q1).
5. On a **final** segment, unmatched tokens followed by a match at `cursor` are **added** before
   `cursor`.
6. Unclear tokens persisting across two consecutive final segments at the same `cursor` become
   **wrong**.
7. Provisional segments (`finalSegment: false`) may advance but never declare mistakes. The
   recogniser only emits final segments today; the flag keeps the rule explicit.
8. `ayahCompleted` is true only when every position is matched or hinted, in order (FR-014,
   FR-017). Then the next ayah becomes expected and `cursor = 1`.
9. Tokens after the last ayah of the range are ignored.

**Property test** over all 6,236 ayat: feeding the ayah's own normalised words as tokens
completes it with 0 mistakes. Dropping, swapping or adding one word declares exactly one
mistake of the right kind and position.

## MemorizationController

```dart
class MemorizationController extends ChangeNotifier {
  MemorizationPhase get phase;            // preparing | listening | paused | ended
  PauseReason? get pauseReason;
  MemorizationRange? get range;
  AyahRef? get expected;
  AyahProgress progressOf(AyahRef ref);
  bool isHidden(int wordId);              // the renderers call this per word
  bool isHinted(int wordId);

  Future<StartOutcome> start(MemorizationRange range);  // gate → model → mic permission → listen
  void pause(); Future<void> resume(); void end();       // ≤ 100 ms to visible state change
  void nextWord(); void showAyah();
  SessionResult? get result;              // set when phase == ended
}

enum StartOutcome { started, unsupportedDevice, needsModel, micDenied, micPermanentlyDenied }
```

**Start sequence**:
1. Stop the recitation (feature 004).
2. Check the device gate.
3. Check that the model is `ready`.
4. Request the microphone (after the explainer).
5. Configure the audio session (`playAndRecord`, `measurement`).
6. Load the recogniser.
7. Start the mic.
8. Set `phase = listening`.

Any failure returns a `StartOutcome`, and the UI shows the matching message
([memorization-ui](./memorization-ui.md)).

**On `MatchEvents`**:
- `mistakes` non-empty: mark the expected ayah's number, then signal according to
  `preferences.mistakeSignal`: `HapticFeedback.vibrate()`, or `DeviceChannel.playMistakeTone()`
  with mic gating for 270 ms, or nothing (R12).
- `ayahCompleted`: reveal (notify once). If the next expected ayah is on another page, follow
  it with the reader's `jumpTo` (FR-018).
- After the last ayah: `end()`.

**Pauses** (R14): an interruption, the app going to the background, the input route being lost,
or 30 s without a segment → `pause()` with the reason. The mic stops at once. `resume()`
restarts the mic and keeps the matcher state.

**`end()`**:
1. Stop the mic and call `flush()`; the last segment is still matched, but only if it arrives
   within 1.5 s.
2. Compute `SessionResult` (data-model).
3. Restore the playback audio session.
4. Set `phase = ended`.

**Scope**: `MemorizationScope` (an `InheritedNotifier`) sits beside `RecitationScope` in
`app.dart`. It is created lazily and holds no state while no session exists.

## Device channel additions (`app.mathani/device`)

| Method | Returns | iOS | Android |
| --- | --- | --- | --- |
| `deviceSupport` | `{"arm64": bool, "ramBytes": int}` | `ProcessInfo.physicalMemory`; always arm64 | `Build.SUPPORTED_64_BIT_ABIS`, `ActivityManager.MemoryInfo.totalMem` |
| `openAppSettings` | void | `UIApplication.openSettingsURLString` | `ACTION_APPLICATION_DETAILS_SETTINGS` |
| `playMistakeTone` | void | `AudioServicesPlaySystemSound(mistake.caf)` | `ToneGenerator(STREAM_NOTIFICATION, 50).startTone(TONE_PROP_BEEP, 120)` |

Where the channel is missing (tests, web preview): `deviceSupport` reports supported,
`openAppSettings` does nothing, and `playMistakeTone` does nothing.
