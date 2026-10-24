# Research: All EveryAyah Reciters and Memorization Mode

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-24

Measured on 2026-10-24 from the Windows development machine: EveryAyah's own reciter list
(`https://everyayah.com/data/recitations.js`), `curl` HEAD requests against the live servers, the
pub.dev API, the Hugging Face API, and the package archives unpacked in a scratch folder. Figures
marked *estimated* are confirmed by spike S1 or S2 before the tasks that depend on them.

## R0. QUL as a source (owner request, plan run 2)

The owner asked to use QUL's recitations (Quranic Universal Library, https://qul.tarteel.ai) where
they can be streamed, because QUL lists more recitations than EveryAyah.

**Finding** (QUL's recitation index and each recitation's preview data, 2026-10-24):

| QUL recitations | Count | Usable for Mathani? |
| --- | --- | --- |
| Total listed | 133 | — |
| **Ayah by ayah** (one file per ayah) | 18 (16 distinct reciter + style) | All Hafs, complete in the probes. **But they are EveryAyah's own recordings**: El-Minshawi's and Alafasy's 2:282 files are byte-identical to EveryAyah's 128 kbps files (2,848,520 and 2,318,128 bytes), and Al-Husary is EveryAyah's 128 kbps set. One is new: **Ahmad Al-Nufais** (`audio-cdn.tarteel.ai/quran/alnufais/`) |
| **Surah by surah with ayah timings** | 47 | 45 after removing two with English translation mixed in. Each surah is one gapless MP3, with QUL's `time_from`/`time_to` for every ayah. The probes of 1, 2, 9, 18 and 114 were complete for all except Abu Bakr Dhaby, whose 002.mp3 is 404 |
| **Surah by surah without timings** | 68 | **No**: without ayah timings the app can't follow ayah by ayah (004 FR-007, FR-012). Many are also Taraweeh compilations, translations, or other narrations (Qalun, al-Susi, ad-Duri, Shu'bah) excluded by Q4 |

All hosts allow public streaming: `audio-cdn.tarteel.ai` (Cloudflare), `download.quranicaudio.com`
and `audio.qurancdn.com` (Quran.com Foundation, BunnyCDN). All three return `audio/mpeg`,
`Accept-Ranges: bytes` and long cache lifetimes, with no sign-in. QUL's licence tab says "We don't
have copyright information for this resource" for every recitation checked.

**Decision**: use QUL wherever it adds a recitation that can be followed ayah by ayah:
- **Al-Nufais**: QUL's ayah-by-ayah set.
- **Seven reciters or styles that exist on QUL only as timed surah files**: Minshawi with
  children, Mostafa Ismail (EveryAyah's set is incomplete), Al-Husary's Ijazah recording, Bandar
  Baleela, Khalid Al-Jalil, Hady Toure and Mansour Al-Salimi. They are played as ayah clips, as
  described in R18.

Where QUL's recording is the same as EveryAyah's, the EveryAyah folder at the lowest bitrate
≥ 64 kbps is used (R2). It is the same audio, at up to half the data, and `husary` keeps the files
readers have already downloaded (FR-006). The catalogue has a `source` column, so moving any entry
to QUL's copy is a one-row change.

**Result**: **51 entries** (43 from EveryAyah + 8 from QUL). This is every complete, followable
Hafs recitation across both libraries, one per reciter and style.

**Alternatives considered**:
- *QUL's ayah-by-ayah sets for everything they cover*: same recordings at 128 kbps, double the
  data, and existing `husary` downloads would no longer match.
- *Timed surah files for every reciter QUL has*: a second playback path for no new recitations.
- *Untimed surah files*: can't be followed ayah by ayah.

**Catalogue build results (T018, 2026-10-24)**: 46 of the 51 planned rows pass. These five are
left out of `tool/recitations.json` until their sources are fixed:

| Reciter | Source | Why |
| --- | --- | --- |
| `ayyoub` (Muhammad Ayyoub) | EveryAyah | 28:87 is missing on both hosts (FR-002 forbids skipping an ayah) |
| `minshawy_children` | QUL surah files | Surah 33 timings: 54 problems (ayat out of order, 33:23–25 without timing), as expected |
| `mostafa_ismail` | quranicaudio surah files + QUL timings | 74:55 starts past the end of its surah file |
| `husary_ijazah` | quranicaudio surah files + QUL timings | In 18 surahs (2, 3, 5, 6, 7, 9, 10, 11, …), the last ayah starts past the end of the file: the timings belong to a longer edition |
| `salimi` (Mansour Al-Salimi) | Tarteel surah files | Surahs 6, 43 and 45: no MPEG Layer III frame where the header probe expects one (not CBR as the others, or a damaged file) |

## R1. Which EveryAyah recordings are offered (FR-001, FR-002, SC-001)

**Finding**: `recitations.js` lists 79 recording sets. Six ayat (1:1, 2:282, 9:129, 18:110,
37:182, 114:6) were probed in each:

| Group | Sets | Outcome |
| --- | --- | --- |
| Translations (English, Persian, Urdu, Azerbaijani, Bosnian) and `MultiLanguage/Basfar_Walk` (Arabic with English) | 9 | Excluded: not recitations (FR-002) |
| Warsh (`warsh/…`, 3 sets) | 3 | Excluded: other narration (Clarification Q4) |
| `Mustafa_Ismail_48kbps` | 1 | Excluded: 2:282 and later probes are 404 (incomplete) |
| `Ibrahim_Akhdar_64kbps` | 1 | Every probe 404; his `_32kbps` set is complete and is used |
| Same recording at another bitrate, or the same reciter and style from a second source | 22 | One set per reciter and style is kept (R2) |
| **Kept** | **43** | One entry per reciter and style, 41 of them new |

Probes that timed out (`000`) were throttling, not missing files (R6 of feature 004); the
manifest tool retries them.

**Decision**: offer the 43 EveryAyah entries in
[contracts/reciter-catalogue.md](./contracts/reciter-catalogue.md) › *Rows*, plus the 8 QUL
entries of R0. The ids `husary` and `minshawy` and their folders stay as they are, so preferences and
downloads survive the update (FR-006). Each set is still checked ayah by ayah by
`tool/build_recitation_manifest.dart`. A set with any ayah missing fails the build and is dropped
from `tool/recitations.json` before release (FR-002); the plan expects 0–3 such drops.

**Alternatives considered**: offering every bitrate as its own entry (rejected: about 65 entries
that differ only in data use, against FR-001's one entry per style); including Warsh with a
warning (rejected by the owner, Q4).

## R2. One set per reciter and style

**Decision**: when a reciter and style exist in several sets, keep:
1. the existing set, for `husary` and `minshawy`;
2. otherwise the lowest bitrate **≥ 64 kbps** (speech is clear at 64 kbps, and it halves data and
   download sizes against 128 kbps, as R1 of feature 004 found);
3. otherwise the highest bitrate available (Ghamdi 40, Parhizgar 48, Mansoori 40, Akhdar 32,
   Al-Banna 32).

Duplicates dropped: `AbdulSamad_64kbps_QuranExplorer.Com` (the same Abdul Basit Murattal as
`Abdul_Basit_Murattal_64kbps`), `Menshawi_16kbps` and `_32kbps` (El-Minshawi Murattal at lower
quality than `minshawy`), and two of the three Al-Ajamy sets.

**Verification** (V-1, quickstart Q-3): listen to 1:1, 2:1, 9:1 and the last ayah of 2 for every
new entry. That confirms the right reciter and style, that ayah 1 does not repeat the basmala,
and the style label. Two labels are unconfirmed until heard: `Ayman_Sowaid_64kbps`, possibly a
teaching recording, and `Mohammad_al_Tablaway_64kbps`, Murattal or Mujawwad.

## R3. Style labels (FR-001, FR-003)

**Decision**: `style` takes three values: `murattal` (مرتّل), `mujawwad` (مجوّد) and `muallim`
(معلّم, "teaching": each ayah recited with repetitions for learners, as in
`Husary_Muallim_128kbps`). The list shows the label after the name. The reciter's short name, for
the recitation bar, gains the style only when the same reciter has more than one entry
(«الحصري · مجوّد»).

## R4. Catalogue size for 51 reciters (Principle IV, SC-007 of feature 004)

**Finding**: feature 004 stores one row per recording in `recitation_files`. That is 12,472 rows
for two reciters, and added 75 KB to the Android download. At 51 reciters it would be 318,036
rows and about 1.9 MB.

**Decision**: replace `recitation_files` with `recitation_sizes`:
- One row per reciter and surah, holding the sizes of that surah's ayat as a BLOB of
  little-endian 3-byte integers.
- For QUL surah-file reciters, the row also holds `range_start`: the byte where the surah's first
  audio frame begins (R18). The ayah sizes are then the exact lengths of each ayah's clip.
- The repository's `recordingBytes(reciter, surah)` keeps its signature and return value, so the
  download queue and the size checks do not change.

The total is 51 × 6,236 × 3 B ≈ 0.95 MB raw in 5,814 rows. Expected growth is **≈ 0.7–0.9 MB**
compressed, measured in T-size. The tool fails if any ayah is ≥ 16 MiB, which no 3-byte integer
could hold. The largest probed (2:282 in the Minshawi-with-children surah file, about 4× a normal
ayah) is well under it.

**Alternatives considered**: keeping row-per-file (about 2× the size); dropping per-file sizes
and trusting `Content-Length` at download time (rejected: offline integrity checks and download
sizes before starting need the sizes, FR-028 and FR-031 of feature 004); fetching manifests at
runtime (no host of our own, and download sizes would need a connection).

**Build time**: about 255,000 HEAD requests for EveryAyah and about 44,000 small range requests
for QUL surah files (R19), at 4 in flight. That takes roughly 3 hours once, and can be resumed per
reciter with `--reciter` or `--skip-existing`.

## R5. Reciter list at 51 entries (FR-003, FR-004, SC-002)

**Decision**: the reciter sheet becomes a `DraggableScrollableSheet` (opens at 0.6, max 0.95)
with a search field and a lazily built `ListView.builder`:
- It is sorted by name in the interface language.
- It opens scrolled to the chosen reciter.
- Search matches the start of any word of `name_ar`, `short_ar`, `name_en` or `short_en`.
  Arabic is compared after `normalizeArabic` (the search feature's normaliser: diacritics and
  أ/إ/آ/ٱ→ا, ة→ه, ى→ي); English is compared case-insensitively. Filtering 51 rows is far below
  the 100 ms budget, so there is no index.

The onboarding's reciter step (feature 005) shows the same list through the same widget.

## R6. On-device speech recognition for recitation (FR-013, FR-019, SC-004 to SC-007)

The owner's answer to Q2 requires that the voice is processed on the device only and that
memorization works with no connection.

**Options evaluated**:

| Option | On-device guarantee | Quran accuracy | Size | Verdict |
| --- | --- | --- | --- | --- |
| Platform recognisers (`SFSpeechRecognizer`, Android `SpeechRecognizer`) through `speech_to_text` 7.5.0 | iOS: only with `requiresOnDeviceRecognition`, and Arabic on-device support is not documented. Android: `createOnDeviceSpeechRecognizer` exists from API 31 only, and needs the Google app's offline Arabic pack. On API 24–30 the voice may go online. | General dictation, not tuned to recitation, elongation or waqf | 0 MB | **Rejected**: cannot guarantee FR-019 on most supported Android versions; unknown on iOS |
| `whisper_ggml` 2.8.1 (whisper.cpp; has a live PCM API) | Yes | Same models as below | Small native, but it depends on `ffmpeg_kit_flutter_new_min` (a large FFmpeg build) and requires **iOS 15.6** | **Rejected**: breaks iOS 15.0 support (FR-028) and ships FFmpeg we don't need |
| Own whisper.cpp FFI build | Yes | Same | ≈ 1.5–2.5 MB | **Fallback** if the owner rejects R7's size. About 300 lines of FFI and build scripts to maintain, plus our own VAD |
| **`sherpa_onnx` 1.13.8** (k2-fsa, Apache-2.0) + a Quran-tuned Whisper model | Yes. In-memory PCM, no network code paths | Whisper fine-tuned on recitation (R8) | ≈ +10 MB per platform (R7) | **Chosen** |

**Decision**: `sherpa_onnx` 1.13.8 (published 2026-09-11; 2.0.0 is one day old and is not
taken). It runs Whisper ONNX models offline and has Silero VAD built in. It takes audio as
in-memory `Float32List`, so the voice never touches disk. It supports Android API 21+ and
iOS 13.0+. It also runs CTC models, if a better recitation model appears later.

## R7. Size cost of the recogniser (Principle IV, SC-010)

**Finding** (from the 1.13.8 archives):
- **Android arm64**: `libonnxruntime.so` 22.2 MB, `libsherpa-onnx-c-api.so` 4.5 MB and
  `libsherpa-onnx-cxx-api.so` 0.4 MB, about 9.9 MB compressed. The app bundle ships one ABI per
  device.
- **iOS arm64**: `SherpaOnnxC.framework` is 26.4 MB, about 9.9 MB compressed.

**Estimated growth**: about **+10 MB** to the store download on each platform, plus the catalogue
change of R4 (+0.7 MB) and `record` (R10, about 0.1 MB). That is well over the 1 MB line. It is
**called out** in Complexity Tracking and must be approved by the owner in review. The model is
not bundled (R9).

**Mitigations checked**:
- The `cxx-api` library is unused (we use the C API through Dart FFI); T-size checks whether
  Gradle packaging can exclude it.
- The x86 and armeabi libraries never reach arm64 devices through the bundle.
- iOS has no on-demand resources for native code, so the framework is always installed.

## R8. Recognition model (FR-013, SC-004, SC-005)

**Finding**: Tarteel's Whisper fine-tunes on recitation, both licensed **Apache-2.0** on Hugging
Face:

| Model | Base | Reported WER | fp32 weights | int8 ONNX, measured (T029) |
| --- | --- | --- | --- | --- |
| `tarteel-ai/whisper-tiny-ar-quran` | Whisper tiny, 39 M params | 7.05% | 151 MB | 64.5 MB (61 MiB) with the VAD and tokens |
| `tarteel-ai/whisper-base-ar-quran` | Whisper base, 74 M params | 5.75% | 290 MB | 108.2 MB (103 MiB) with the VAD and tokens |

The card names no training data. Tarteel's public data is mostly professional reciters plus
crowd-sourced recitations. Accuracy on ordinary readers (women, children, accents) is the main
risk to SC-004.

**Decision**: start with **tiny** (int8), because it is half the download and about 3× faster.
Spike S1 measures both on the SC-004/SC-005 test sets on the iPhone SE 2 and Galaxy A15. Switch
to base only if tiny misses 95% and base reaches it. If neither reaches 95% with the matcher of
R11, stop and report to the owner, as the spec's assumption requires; the voice is not moved
online.

**Export**: `tool/export_asr_model.py` (Python, run once by a maintainer; not part of the app
build) converts the Hugging Face checkpoint with sherpa-onnx's Whisper export script, quantises
it to int8, and writes `encoder.int8.onnx`, `decoder.int8.onnx` and `tokens.txt`. Their SHA-256
values are pinned in `lib/features/memorization/asr_model.dart`.

Export findings (T028, T029):
- **Size**: sherpa-onnx quantises only a MatMul's weight in the second input, and its decoder
  computes the logits as `MatMul(embedding, xᵀ)`. That leaves the token embedding (51,865 × 384)
  in fp32: 80 of the 90 MB tiny decoder. The tool rewrites that node as the equal
  `Transpose(MatMul(xᵀ, embeddingᵀ))` and quantises the Gather too. The decoder drops to 50 MB,
  with the same transcripts on the check clips.
- **Hosting**: `huggingface.co` resets TLS connections on the maintainer's network. The tool
  downloads from a mirror (`--hf-endpoint https://hf-mirror.com`) and checks the checkpoint's
  SHA-256, which was read from Hugging Face's own API through another route.
- **Check**: decoding EveryAyah clips (Alafasy: 1:7, 36:1, 55:13, 67:1, 67:2, 103:3, 112:1)
  with sherpa-onnx 1.13.8 in Python gives the Uthmani text with diacritics. The whole recognised
  text of a 14 s ayah takes 1.2 s on the desktop CPU. Tiny and base agree on all of them.
- **Cut endings**: without trailing silence the last word is cut («الْعَزِيز» for «الْعَزِيزُ
  الْغَفُورُ», «أَحَ» for «أَحَدٌ»). `tail_paddings` does not change this. **2 s of zero samples
  appended to each segment** fixes every check clip, so the recogniser appends them (T040). A
  52 s ayah (2:255) is cut at Whisper's 30 s window, so segments must stay under 30 s (VAD
  `max_speech_duration`).

**Decoding settings**:
- language `ar`, task `transcribe`;
- greedy decoding (`tail_paddings` default), with 2 s of silence appended to each segment;
- **no initial prompt containing the expected ayah**, because biasing Whisper toward the
  expected text would hide real mistakes (SC-005) and could reveal ayat that were not recited
  (SC-006).

## R9. Getting the model onto the device (FR-019, constitution Principle IV)

**Decision**: the model is a **one-time download the first time memorization is opened**, not
part of the app:
- **Hosting**: GitHub Releases on the public project repository
  (`https://github.com/hamzagamil/mathani/releases/download/asr-tarteel-tiny-v1/<file>`). It is
  free, versioned, and Apache-2.0 allows redistribution with the licence and notice. Requests
  carry no identifiers (feature 004, FR-023).
- **Before the download**: the size is shown, mobile data asks first, and free space is checked,
  using the device channel and the same sheet pattern as surah downloads (feature 004, FR-028).
- **During the download**: resumable with HTTP `Range`, checked against the pinned SHA-256, and
  stored in the app support directory, excluded from backup.
- **Settings › Downloads** lists it as "Memorization model" with its size and a delete action.
- **After the download**, memorization needs no connection. This refines the spec's edge case
  about "a one-time system download": the download is ours, not the system's. The spec edge case
  is updated with this plan.

**Alternatives considered**:
- *Bundling the model*: +61.5 MB for every user, including those who never memorise (Principle
  IV).
- *Play Asset Delivery or iOS On-Demand Resources*: two store-specific paths, which the
  Simplicity principle rejects.
- *Hugging Face as host*: possible, but we would not control renames or availability.

## R10. Microphone capture (FR-010, FR-019, FR-020)

**Decision**: `record` 7.1.2 (MIT, published 2026-10-09; no native binaries beyond its plugin
code), `startStream` with PCM16, 16 kHz, mono:
- **Android**: audio source `VOICE_RECOGNITION`, no echo canceller.
- **iOS**: `manageAudioSession: false`. We set the session ourselves with `audio_session`: category
  `playAndRecord`, mode `measurement`, `defaultToSpeaker` and `allowBluetooth`, and restore the
  playback session when the memorization session ends.
- `hasPermission()` triggers the system prompt, and only after our explanation sheet (FR-010).
- Samples are converted to `Float32List` and passed straight to the VAD; they are never written
  to disk.
- The stream is stopped, not paused, whenever listening stops (FR-020): pause, end, a call, the
  app leaving the foreground, or 30 s of silence. A new stream is started on resume.

**Alternatives considered**: extending `app.mathani/device` with an EventChannel and native
capture (about 150 lines per platform, plus interruption handling that `record` already does).
Rejected for Simplicity; `record` is small and focused.

**Platform setup**:
- **Android**: `RECORD_AUDIO` in the manifest (a runtime permission).
- **iOS**: `NSMicrophoneUsageDescription` in Info.plist, localised in `ar.lproj` and `en.lproj`
  `InfoPlist.strings`.
- **"Open Settings"** when the permission was denied: iOS uses `UIApplication.openSettingsURLString`
  and Android `ACTION_APPLICATION_DETAILS_SETTINGS`, both through a new `openAppSettings` method
  on the device channel (about 5 lines each).

## R11. Following the recitation word by word (FR-013 to FR-017)

**Decision**: a pure-Dart `RecitationMatcher`, described in
[contracts/memorization-engine.md](./contracts/memorization-engine.md):

- **Reference words**: `ayahs.search_text`, split on spaces. These are the imla'i words already
  normalised for search (feature 001, R7). Their offsets map each one to its Uthmani word id
  through `words.search_offset`, so a word the matcher is waiting on is a word on the page.
- **Hypothesis**: each finished VAD segment is decoded, passed through `normalizeArabic`, and
  split into tokens.
- **Word comparison**: normalised Levenshtein similarity ≥ θ_match (start 0.75; tuned in S1).
  Also accepted: one ASR token against two reference words joined, or two tokens against one
  (Whisper splits and joins Arabic words differently from the imla'i text), and common
  Quran-orthography variants that `normalizeArabic` does not remove (for example
  هَٰذَا/هذا, الصلوٰة/الصلاة). The variants are tested on all 6,236 ayat in T-match.
- **Reader moves**:

  | What the reader does | How the matcher treats it |
  | --- | --- |
  | Recites the next word | Moves the cursor forward |
  | Goes back to an earlier word in the ayah (within the ayah) | Moves the cursor back; not a mistake (FR-014) |
  | Recites the isti'adha or basmala at the start of a range or an ayah | Ignored, unless it is the expected text (1:1, 27:30) |
  | Goes on to later words, skipping some | **Missed** at the cursor |
  | Says a different word, then continues from the next one | **Wrong** at the cursor |
  | Says extra words, then continues from the cursor | **Added** before the cursor |

  A mistake is declared only from a **finished** segment, never from a half-decoded one. That
  keeps ASR noise from flagging false mistakes.
- **After a mistake**: the cursor stays on the wrong word (Clarification Q1), and words before it
  stay recited.
- **Unclear tokens** (similarity between θ_unsure 0.55 and θ_match): they neither advance nor
  count as mistakes. If they persist across two segments, they count as "wrong". This trades a
  little latency for fewer false mistakes (SC-004).
- **Completion**: an ayah is complete only when every reference word has been matched in order.
  Hints count as matched.

**Latency** (SC-007): a VAD pause of 0.5 s ends a segment. Decoding takes about 0.15–0.3 s for a
5 s segment with tiny int8 on the A13 or Helio G99 (*estimated*; measured in S1). Matching is
under 5 ms. The total from the reader stopping to the ayah appearing is about 0.7–0.9 s. A long
breath with no pause is split by the VAD at 12 s, keeping 1 s of overlap. Words heard twice in
the overlap are treated as a repetition, which is never a mistake.

**Alternatives considered**: whole-ayah string comparison after the reader pauses (rejected:
Clarification Q1 needs word-level resume, and long ayat need early mistakes); phoneme-level
models (no licensed recitation model available on-device today).

## R12. Mistake signal (FR-015, Clarification Q5)

**Decision**:
- **Vibration**: `HapticFeedback.vibrate()`. It needs no permission on Android and is a short
  vibration on both platforms; on phones without a vibrator it does nothing.
- **Sound**: a short 120 ms tone played natively through a new `playMistakeTone` method on the
  device channel, so that silent mode is honoured on both platforms (spec edge case):
  - **iOS**: `AudioServicesPlaySystemSound` with a bundled `mistake.caf` (≈ 3 KB, in `Runner`).
    System sounds are muted by the silent switch, which a `playAndRecord` player would ignore.
  - **Android**: `ToneGenerator(STREAM_NOTIFICATION, 50)` with `TONE_PROP_BEEP`, which is silent
    when the ringer is silent or on vibrate. No asset is needed.

  While the tone plays, plus 150 ms, microphone samples are dropped, so the tone is never decoded
  as recitation.
- **Screen**: the ayah number turns the `mistake` colour and the bar shows «خطأ — تابع من
  الكلمة» / "Mistake — carry on from the word". The live region is announced to screen readers.
- **Setting**: `mistake_signal` = `vibrate` (default) | `sound` | `none`.

## R13. Hiding the text without moving it (FR-012, SC-010)

**Finding**: `RenderMushafPage` paints each word glyph at a placed position, and ayah-end glyphs
are separate words (`isAyahEnd`). `FlowingView` builds a `TextSpan` per ayah.

**Decision**:
- **Mushaf**: the renderer gains `hidden: bool Function(int wordId)?`. A hidden word is not
  painted, but keeps its place and width, so nothing reflows when it appears. Ayah-end glyphs,
  surah headers and basmala lines are always painted.
- **Flowing**: hidden words are drawn with a transparent colour, keeping the line breaks
  identical, and are excluded from semantics.
- **Hints**: a hinted word is painted in the `hint` colour; mistakes tint the ayah-end glyph.
- **Repaints**: the renderer repaints only when the revealed set changes, about once per ayah,
  which fits the 60 fps budget.
- **Screen readers**: page semantics list hidden ayat as «الآية ٥، مخفية» / "Ayah 5, hidden"
  instead of their text.

## R14. Interruptions and lifecycle (FR-020, FR-021, edge cases)

**Decision**: the session pauses, and the microphone stream stops, on any of:
- an `audio_session` interruption begin (call, Siri, alarm);
- `AppLifecycleState.inactive` or `.paused`;
- a route change that removes the input device;
- 30 s with no VAD speech.

Resume is always the reader's tap. Starting a session stops the recitation player (feature 004,
FR-011), and the Listen button is hidden while memorization is open. Nothing runs in the
background.

## R15. Devices that can run memorization (FR-028)

**Decision** (initial gate, confirmed in S1):
- arm64 (iOS: every device on iOS 15; Android: `Build.SUPPORTED_64_BIT_ABIS` not empty);
- at least 3 GB RAM (Android `ActivityManager.MemoryInfo.totalMem`; iOS
  `ProcessInfo.physicalMemory`), through the device channel.

Peak memory with tiny int8 is about 150–250 MB (*estimated*).

Below the gate, the menu entry shows «الحفظ غير متاح على هذا الجهاز» / "Memorization isn't
available on this device". The quickstart checks this message on the API 24 emulator set to
2 GB RAM. The gate behaves the same on both platforms, so there is no parity
gap; the devices excluded are listed in the release notes.

## R16. Privacy and store answers (FR-019, FR-029)

**Decision**:
- **Store answers**: "Audio data" is used on device only and not collected, under both Apple's
  definition and Google Play's (data processed only on device is not "collected").
  `docs/store/privacy.md` and the privacy policy are updated to say so.
- **New outbound host**: GitHub Releases, for the model only.
- **Microphone text** (Info.plist): «يستخدم مثاني الميكروفون أثناء جلسة الحفظ فقط ليتابع
  تلاوتك على جهازك. لا يُسجَّل صوتك ولا يغادر الجهاز.» / "Mathani uses the microphone only during a
  memorization session, to follow your recitation on your device. Your voice is not recorded and
  never leaves the device."
- **Review guard**: no code path in `lib/features/memorization/` may import `dart:io` HTTP or
  write files; the model download lives in `asr_model.dart`, which never touches audio. A unit
  test greps the folder for this rule.

## R17. Licences and dependencies

**Decision**:
- **D4** (Quran.com Foundation: EveryAyah and `download.quranicaudio.com`, `docs/licences.md`) is
  widened from "Al-Husary and El-Minshawi" to "the 43 EveryAyah recordings and the 5 QUL surah
  recordings served from quranicaudio, listed in specs/006". The request draft
  `docs/permissions/everyayah-request.md` is updated before it is sent.
- **D2** (QUL / Tarteel, `docs/permissions/qul-request.md`) is widened to cover:
  - using QUL's ayah timings for 7 recordings;
  - streaming and downloading the 3 recordings on `audio-cdn.tarteel.ai` (Al-Nufais,
    Minshawi with children, Al-Salimi);
  - serving them as per-ayah byte ranges (R18).

  QUL states no licence for these resources (R0).
- **D4 and D2 together block the store release.** A refused recording is removed by deleting its
  row.
- **Added to the licences table**: the Tarteel models (Apache-2.0; a notice, no permission
  needed), sherpa-onnx (Apache-2.0), `record` (MIT) and onnxruntime (MIT).
- **Licence texts** go in `assets/licences/` and are registered in `registerAssetLicences()`.

## R18. Playing QUL surah files as ayah clips (FR-005; 004 FR-007 to FR-021)

**Problem**: seven QUL entries (R0) exist only as one gapless MP3 per surah, from 1 MB to
242 MB. Feature 004's engine is built on one local file per ayah:
- fetch, then cache or download, then a sliding gapless playlist;
- "never skip an ayah";
- resumable per-ayah downloads.

A second, surah-level player would need its own cache, buffering, error handling and download
code.

**Finding**: every probed surah file of these reciters is **constant bitrate** (CBR):
- 128 kbps at 44.1 kHz: Minshawi with children, Mostafa Ismail, the Husary Ijazah, Bandar
  Baleela;
- 96 kbps at 44.1 kHz: Khalid Al-Jalil;
- 96 or 128 kbps at 48 kHz: Hady Toure, Al-Salimi.

In CBR every frame lasts the same time (26.12 ms at 44.1 kHz, 24 ms at 48 kHz). A timestamp
therefore maps to a frame, and the frame to a byte offset. All three hosts accept HTTP `Range`.

**Decision**: treat each ayah as the byte range `[start(a), start(a+1))` of its surah file. The
last ayah ends at the end of the file.
- `start(a)` is the offset of the first frame at or after the **cut time**
  `c(a) = (time_to(a−1) + time_from(a)) / 2`, the middle of the silence between ayat, or
  `time_from(a)` when there is no gap. For ayah 1 it is the first audio frame after the ID3 tag.
  The first frame of a clip, which may decode as silence, falls in that pause, so no recited sound
  is trimmed (004 FR-003).
- **Exact offsets come from the build** (R19). Each ayah's clip length is stored in
  `recitation_sizes`, and the surah's first-frame offset in `range_start`. So
  `start(a) = range_start + Σ sizes[1..a−1]`. No offset is guessed at runtime.
- **Fetching**: `AyahFetcher` requests `Range: bytes=start-end` for these reciters and writes
  the clip to the same per-ayah file, `<reciter>/<SSS><AAA>.mp3`. A clip of whole MP3 frames is
  a valid MP3, so everything after the fetch is unchanged: cache, downloads (a surah download is
  all its clips), size checks, gapless playlist, retry, "never skip". A `206` response with the
  expected `Content-Range` and length is required; anything else is a retry.
- **Basmala**: these files include the reciter's basmala at the start of ayah 1's span. QUL's
  `2:1` begins at 0 ms in Alafasy's file, for example. A new reciter flag `basmala_in_ayah1 = 1`
  makes the playlist skip the separate basmala item (004 FR-008, and risk R-3 of feature 004).
  While a surah's first ayah plays, the highlight is on ayah 1. The basmala line is not
  highlighted separately for these reciters, a small and documented difference. V-1 confirms by
  listening that each surah file begins with the basmala, except At-Tawbah.
- **Boundaries**: MP3's bit reservoir can make a clip's first frame decode as silence. Because the
  cut is mid-pause, that silence lands in the reciter's own pause, adding ≤ 26 ms (004 FR-009
  allows 150 ms).

**Alternatives considered**:
- *A second, surah-level player that streams whole files and maps the position to ayat*: about
  twice the code; per-ayah cache and resume lost; 100+ MB streams to manage.
- *Splitting and re-hosting the files*: needs our own hosting and permission to redistribute
  modified files.
- *Guessing offsets at runtime from the bitrate*: frame padding makes cumulative offsets drift
  by bytes. Exact offsets from the build are cheap.

## R19. Getting QUL's timings and offsets at build time

**Decision**: `tool/build_recitation_manifest.dart` gains a `qul_surah` source kind:
1. **Timings**: the maintainer downloads each recitation's JSON from its QUL page ("Download json",
   which needs a free QUL account) into `tool/sources/qul-recitations/<qul_id>.json`. It is
   pinned in `tool/sources.lock.json`, the same as the QUL layout databases. The tool also accepts
   the preview API's shape (`/api/v1/audio/surah_segments/<audio_id>`) for checks, but the build
   reads only pinned files. **The app never calls QUL.**
2. **Per surah**:
   1. HEAD for the size.
   2. A 128 KB range read for the ID3 length and the first frame header. The build fails unless
      the file is CBR and every sampled frame has the same bitrate and sample rate.
   3. For each ayah boundary, a 4 KB range read around the predicted offset, to find the exact
      frame start.

   That is about 6,300 small requests per reciter.
3. **Checks**: all 114 surahs and all 6,236 ayat timed, with `time_from` strictly increasing
   within a surah. Any failure **drops the reciter from the build** with a report, as for
   EveryAyah.

URL pattern per reciter: `file_pattern` with `{sss}` or `{s}`. The hosts use `001.mp3`, `1.mp3`
and an empty path segment (`…/bandar_baleela/complete//001.mp3`). The pattern stores the path
exactly as the host serves it.
