---

description: "Task list for all available reciters and memorization mode"
---

# Tasks: All Available Reciters and Memorization Mode

**Input**: Design documents from `specs/006-reciters-memorization/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Included. The plan and quickstart list the unit and widget tests. Several spec rules
can only be held by automated checks:
- never reveal an unrecited ayah (SC-006);
- the score rule (SC-008);
- the 004 catalogue staying unchanged (FR-006);
- QUL clips covering their files exactly (R18).

**Organization**: grouped by user story (US1 reciters, US2 memorization, US3 score).
- **Release gates**: release is gated on **D4** (Quran.com Foundation) and **D2** (QUL / Tarteel).
- **Owner approval**: the ≈ +11 MB size growth of US2 needs the owner's approval (Principle IV).
- **Accuracy gate**: US2's UI work is gated on spike S1 (T035).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US3)

## Path Conventions

Single Flutter project at the repository root: `lib/`, `test/`, `tool/`, `integration_test/`,
`android/`, `ios/`, `docs/`.
- New memorization code: `lib/features/memorization/`.
- Reciter changes: `lib/features/recitation/`, `lib/data/` and `tool/`.

## Shared conventions

- **Tests**:
  - Tests that need the real Quran data use `openTestReader()` and `loadAppFonts()` from
    `test/support/harness.dart` inside `testWidgets`, wrapping database work in
    `tester.runAsync(...)`.
  - HTTP tests use the localhost server in `test/support/fake_audio_server.dart`. Extend it rather
    than adding a second one.
  - The device channel is faked with
    `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler`.
  - No test reaches EveryAyah, QUL, the CDNs or GitHub.
- **Named constants**: numbers from research and contracts are named constants, each defined in
  one place:

  | Constant | Value | Defined in |
  | --- | --- | --- |
  | `maxPackedSize` | 16,777,215 (2²⁴ − 1) | `tool/src/recitations.dart` |
  | `frameProbeBytes` | 4,096 | `tool/src/mp3_frames.dart` |
  | `headerProbeBytes` | 131,072 | `tool/src/mp3_frames.dart` |
  | `thetaMatch` | 0.75 (tuned in T035, then fixed) | `recitation_matcher.dart` |
  | `thetaUnsure` | 0.55 (tuned in T035, then fixed) | `recitation_matcher.dart` |
  | `lookAhead` | 3 words | `recitation_matcher.dart` |
  | `vadThreshold` | 0.5 | `speech_recogniser.dart` |
  | `vadMinSilence` | 0.5 s | `speech_recogniser.dart` |
  | `vadMinSpeech` | 0.25 s | `speech_recogniser.dart` |
  | `vadMaxSpeech` | 12 s | `speech_recogniser.dart` |
  | `forcedSplitOverlap` | 1 s | `speech_recogniser.dart` |
  | `silencePause` | 30 s | `memorization_controller.dart` |
  | `endFlushWait` | 1.5 s | `memorization_controller.dart` |
  | `toneGate` | 270 ms (120 ms tone + 150 ms) | `mic_source.dart` |
  | `mistakeLineDuration` | 3 s | `memorization_bar.dart` |
  | `minRamBytes` | 3 GiB | `device_support.dart` |
  | `asrModelVersion` | `tarteel-tiny-v1` | `asr_model.dart` |

- **Privacy rule** (R16, FR-019): no file in `lib/features/memorization/` except
  `asr_model.dart` may import `HttpClient`, use `File` write APIs, or import `path_provider`.
  Audio samples never leave memory.
- **State before platform**: session state changes (`listening`, `paused`, and so on) are set and
  notified **before** awaiting plugin calls, so controls react within 100 ms (FR-021).
- **No startup cost**: nothing here may run before the first reader frame. That includes the
  model check, the recogniser and the device gate (Principle III).

---

## Phase 1: Setup

- [X] T001 Run `flutter analyze` and `flutter test` from the repository root and confirm both pass (baseline). Run `flutter build appbundle --release --analyze-size` and `dart run tool/size_check.dart android <analyze-size.json>`, and record the Android download size in `specs/006-reciters-memorization/tasks.md` › Notes as the size baseline for SC-010.
- [X] T002 [P] Add icons to `lib/shared/mathani_icons.dart`: `memorize` (Lucide `brain`), `hint` (`lightbulb`), `reveal` (`eye`), `mic` (`mic`), `search` (`search`) if missing. Look up each codepoint in lucide-static 1.48.0 `font/info.json` (the version of `assets/fonts/Lucide.ttf`). Re-subset `assets/fonts/Lucide.ttf` the same way the existing glyphs were added. Check each glyph renders in `test/widget/recitation_icons_test.dart` (extend it).
- [X] T003 [P] Widen the permission requests (research R17):
  - `docs/permissions/everyayah-request.md`: list the 43 EveryAyah folders and the 5 `download.quranicaudio.com` surah recordings from `contracts/reciter-catalogue.md` › Rows.
  - `docs/permissions/qul-request.md`: add the use of QUL's ayah timings for the 7 `qul_surah` recitations, and streaming/download of the 3 `audio-cdn.tarteel.ai` recordings (`alnufais`, `minshawy_children`, `salimi`) as per-ayah byte ranges.
  - `docs/licences.md`: update rows D2 and D4 to name specs/006. Add one row per new recording to the Recitations table (licence **Unconfirmed**, requirement "**Dependency D4**" or "**D2**").

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the catalogue schema, the reciter model and the preferences every story reads.

**⚠️ CRITICAL**: no user story work can begin until this phase is complete.

- [X] T004 Change `tool/src/recitations.dart` (data-model › Recording sizes):
  - **Schema**: replace the `recitation_files` schema with `recitation_sizes (reciter TEXT NOT NULL REFERENCES reciters(id), surah INTEGER NOT NULL, sizes BLOB NOT NULL, range_start INTEGER, PRIMARY KEY (reciter, surah)) WITHOUT ROWID`. Add columns to `reciters`: `source TEXT NOT NULL` (`everyayah` | `qul_ayah` | `qul_surah`), `file_pattern TEXT NOT NULL`, `basmala_in_ayah1 INTEGER NOT NULL DEFAULT 0`. Make `mirror_url` nullable.
  - **Writing**: `writeRecitationTables` drops `recitation_files` if present and writes one row per reciter and surah. `sizes` holds the ayat's sizes as 3-byte little-endian integers in ayah order, so `length(sizes) == 3 × ayahCount(surah)`. `range_start` is NULL for ayah sources.
  - **Checks**, each failing with a message and exit 1:
    - every size satisfies `0 < size ≤ maxPackedSize`;
    - ids are unique and match `^[a-z0-9_]+$`;
    - `style` ∈ {`murattal`, `mujawwad`, `muallim`};
    - `base_url` + `file_pattern` is unique;
    - `qul_surah` rows have `basmala_in_ayah1 = 1`;
    - for `qul_surah`, `range_start + Σ sizes == file length` from the manifest.
  - `ReciterDefinition` gains `source`, `filePattern`, `basmalaInAyah1`, `qulId` (nullable), and a nullable `mirrorUrl`. Existing JSON without the new keys reads as `everyayah`, `{sss}{aaa}.mp3` and 0.
- [X] T005 Add `"source":"everyayah","file_pattern":"{sss}{aaa}.mp3","basmala_in_ayah1":0` to the two existing rows of `tool/recitations.json`. Run `dart run tool/add_recitations.dart` and confirm it prints 2 reciters and 228 surah rows.
- [X] T006 Update `lib/data/models.dart` `Reciter`:
  - add `source` (enum `RecitationSource { everyayah, qulAyah, qulSurah }`), `filePattern`, `basmalaInAyah1`; make `mirrorUrl` nullable;
  - `style` becomes an enum `RecitationStyle { murattal, mujawwad, muallim }`;
  - `urlFor(surah, ayah, {mirror})` follows `contracts/reciter-catalogue.md` › Repository API. For `qulSurah` it returns `base_url` + `/` + `file_pattern` with `{sss}` = 3-digit surah and `{s}` = surah, ignoring `ayah`. A `base_url` ending in `/` keeps the host's double slash.
- [X] T007 Update `lib/data/quran_repository.dart`:
  - `reciters` reads the new columns;
  - `recordingBytes(reciter, surah)` reads `recitation_sizes.sizes` and decodes 3-byte LE integers, cached per (reciter, surah) as today;
  - new `clipRange(reciter, surah, ayah)` returns `(start, endExclusive)` = `(range_start + Σ sizes[1..a−1], start + sizes[a])` for `qulSurah`, and null otherwise;
  - `surahDownloadBytes` adds the basmala (1:1) only when `!basmalaInAyah1`.

  Keep every query off the startup path.
- [X] T008 [P] Add `mistakeSignal` to `ReaderPreferences` in `lib/data/models.dart`: enum `MistakeSignal { vibrate, sound, none }`, default `vibrate`, with `copyWith`. Persist it in `lib/data/user_repository.dart` under key `mistake_signal` with values `vibrate` | `sound` | `none`; an unknown value reads as `vibrate`.
- [X] T009 [P] Write `test/unit/recitation_sizes_test.dart`:
  - for `husary` and `minshawy`, `recordingBytes` returns exactly the values of the 004 manifests (`tool/sources/recitations/<id>.json`, or a committed fixture of 3 surahs if `tool/sources` is absent in CI) for all 114 surahs;
  - every `sizes` blob length is `3 × ayahCount`;
  - `clipRange` is null for ayah sources.

  Also extend `test/unit/` preferences coverage, with a new `test/unit/mistake_signal_pref_test.dart`: default `vibrate`, a round trip of all three values, and an unknown value reading as `vibrate`.

**Checkpoint**: `flutter test` passes; the app plays Al-Husary and El-Minshawi exactly as in 1.4.0.

---

## Phase 3: User Story 1 - Choose from every available reciter (Priority: P1) 🎯 MVP

**Goal**: 51 reciters from EveryAyah and QUL, searchable, each with all of feature 004's
behaviour. The 7 QUL surah recitations play as byte-range ayah clips (R18).

**Independent Test**: spec US1. Search «العفاسي» and "Alafasy", play page 50 across the page
break, download Al-Mulk and play it offline. Repeat with a teaching recording, a Mujawwad
recording and Bandar Baleela (quickstart Q-1 to Q-8).

### Tests for User Story 1

- [X] T010 [P] [US1] Write `test/unit/mp3_frames_test.dart` for `tool/src/mp3_frames.dart` (T014), using generated byte fixtures:
  - ID3v2 length (10-byte header + synchsafe size);
  - CBR accepted when 40 sampled frames share bitrate and sample rate, and rejected with mixed bitrates or a `Xing` header;
  - `frameStartAtOrAfter(bytes, offset)` finds the right frame at 44.1 kHz with padding bits varying (417/418-byte frames at 128 kbps) and at 48 kHz (no padding).
- [X] T011 [P] [US1] Write `test/unit/clip_range_test.dart`: for a `qul_surah` fixture database (2 surahs), clips are contiguous, the first starts at `range_start`, the last ends at the file length, and `recordingBytes` equals the clip lengths.
- [X] T012 [P] [US1] Write `test/unit/ayah_fetcher_range_test.dart` against `test/support/fake_audio_server.dart` (extend it to honour `Range` and to misbehave on demand). For a `qulSurah` reciter:
  - the request carries `Range: bytes=<start>-<end−1>`;
  - a `206` with `Content-Range: bytes <start>-<end−1>/<total>` and the expected length is saved as `<reciter>/<SSS><AAA>.mp3`;
  - a `200`, a wrong `Content-Range` or a wrong total is retried and never saved;
  - no mirror is tried.

  For ayah sources, behaviour is unchanged (run the existing `ayah_fetcher_test.dart`).
- [X] T013 [P] [US1] Write `test/widget/reciter_list_test.dart` with a 51-row fixture:
  - rows sorted by name in the interface language;
  - typing «عفاسي» or "alafasy" leaves 1 row within one frame;
  - «الحصري» matches all four Al-Husary entries, and «حصري» (no ال) still matches;
  - an empty result shows «لا يوجد قارئ بهذا الاسم»;
  - the chosen reciter is visible when the sheet opens;
  - each row is ≥ 48 dp high;
  - the style label is shown.

  Also extend `test/unit/recited_item_order_test.dart`: with `basmalaItems: false`, `startItem(AyahRef(2,1))` is ayah 2:1 and `next` never yields a basmala item.

### Implementation for User Story 1

- [X] T014 [P] [US1] Write `tool/src/mp3_frames.dart` (pure Dart, no Flutter), per research R18 and R19:
  - `id3Length(Uint8List head)`;
  - `FrameInfo? parseFrameHeader(Uint8List b, int i)` (MPEG-1 Layer III: bitrate, sample rate, padding, frame length = `144000 × kbps / sampleRate + padding`);
  - `CbrInfo checkCbr(Uint8List head, int audioStart)`, which checks 40 frames and rejects `Xing`/`VBRI`;
  - `int frameStartAtOrAfter(Uint8List window, int windowOffset, int target, CbrInfo cbr)`, which returns the first offset ≥ target where three consecutive valid headers of the CBR bitrate begin.

  Make T010 pass.
- [X] T015 [US1] Extend `tool/build_recitation_manifest.dart` with the `qul_surah` source (contracts/reciter-catalogue.md › Build; research R19):
  1. **Timings**: read `tool/sources/qul-recitations/<qul_id>.json`, checking its SHA-256 against `tool/sources.lock.json` key `qul-recitations/<qul_id>.json`. Accept QUL's "Download json" shape (`"S:A": {"timestamp_from", "timestamp_to", …}`) and the preview-API shape (`"time_from"`). Require all 114 surahs, each ayah present, and `timestamp_from` strictly increasing within a surah.
  2. **Per surah**: HEAD `urlFor(s)` for `Content-Length`; GET `Range: bytes=0-<headerProbeBytes−1>` for `id3Length` and `checkCbr`. The surah fails unless the file is CBR.
  3. **Per ayah `a > 1`**: the predicted offset is `audioStart + floor(c(a) × kbps / 8)`, with `c(a) = (timestamp_to(a−1) + timestamp_from(a)) / 2`, or `timestamp_from(a)` if `timestamp_to(a−1) ≥ timestamp_from(a)` (research R18). GET a `frameProbeBytes` window starting one frame before it and take `frameStartAtOrAfter`. For `a = 1` the start is `audioStart`. Sizes are the differences of consecutive starts, and the last ayah ends at `Content-Length`.
  4. **Output**: write `tool/sources/recitations/<id>.json` as `{"reciter","range_start":{"1":…},"files":{"1:1":…}}` and lock its SHA-256.

  Use the existing retry and backoff (`manifestBackoff`) and `manifestConcurrency`. Add `--skip-existing`, which skips reciters whose manifest already matches the lock. Fail the reciter (exit 1, listing failures) on any check failure.
- [X] T016 [US1] Write all 51 rows of `tool/recitations.json` from `contracts/reciter-catalogue.md` › Rows, in table order (EveryAyah first, then QUL), with `sort` = row number:
  - **EveryAyah rows**: `source: "everyayah"`, `file_pattern: "{sss}{aaa}.mp3"`, `basmala_in_ayah1: 0`, `base_url: "https://everyayah.com/data/<folder>"`, `mirror_url: "https://mirrors.quranicaudio.com/everyayah/<folder>"`.
  - **QUL rows**: `mirror_url: null`, `qul_id` as listed. `qul_ayah` (alnufais) uses `{sss}{aaa}.mp3` and `basmala_in_ayah1: 0`; `qul_surah` rows use their listed `file_pattern` and `basmala_in_ayah1: 1`.
  - **Short names**: `short_ar`/`short_en` is the common short name (for example «العفاسي» / "Alafasy"), with « · » plus the style label only when the reciter has more than one entry (research R3).
  - **Names**: use the draft names exactly, marking the file for owner review in T024.
- [X] T017 [US1] Download the 7 QUL timing JSONs (QUL ids 314, 346, 368, 388, 420, 421, 572) from each recitation's page ("Download json"; a free QUL account) into `tool/sources/qul-recitations/<qul_id>.json`, and add their SHA-256 values to `tool/sources.lock.json`. For each JSON, note in `research.md` › R18 whether ayah 1's first word starts ≥ 2,000 ms after the file start in surahs 2–114. If it does for all 7 reciters, raise splitting the basmala into its own clip as a follow-up. *(Manual step for the maintainer.)*
- [X] T018 [US1] Run `dart run tool/build_recitation_manifest.dart --skip-existing` (about 3 h; resumable). For every reciter that fails, remove its row from `tool/recitations.json` and record the reason in `research.md` › R0 or R1. Then run `dart run tool/add_recitations.dart` and `dart run tool/verify_quran.dart`. Confirm the output `quran.db: 51 reciters, 5814 surah rows` (or the reduced count) and that T009 still passes.
- [X] T019 [US1] Add the byte-range path to `lib/features/recitation/ayah_fetcher.dart` (contracts/reciter-catalogue.md › Fetching QUL surah clips):
  - When `reciter.source == qulSurah`, `_get` sends `Range: bytes=<start>-<endExclusive−1>` from `quran.clipRange(...)`.
  - It accepts only a `206` whose `Content-Range` is `bytes <start>-<endExclusive−1>/<total>` and whose body length is `endExclusive − start`. Anything else is a failure that goes through the existing retry path.
  - Skip the mirror loop when `mirrorUrl == null`.
  - The `.part` → rename flow, `isValid` and the cache are unchanged.

  Make T012 pass.
- [X] T020 [US1] Skip the basmala item for `basmalaInAyah1` reciters:
  - `RecitedOrder` in `lib/features/recitation/recited_item.dart` gains `basmalaItems` (default true); when false, `startItem` and `next` never return `RecitedItem.basmala`.
  - `lib/features/recitation/recitation_controller.dart` builds its order with `basmalaItems: !reciter.basmalaInAyah1`, and rebuilds it on `setReciter`.
  - `lib/features/recitation/download_queue.dart` skips the basmala file when `basmalaInAyah1`.

  Make the T013 order test pass, and confirm the existing recitation tests still pass.
- [X] T021 [US1] Rewrite `lib/features/recitation/reciter_sheet.dart` as a `DraggableScrollableSheet` (initial 0.6, max 0.95) holding a public `ReciterList` widget (contracts/reciter-catalogue.md › Reciter list):
  - **Search field**: placeholder `searchReciters`, with a clear button. Filter on the start of any word of `nameAr`/`shortAr` after `normalizeArabic` (from `lib/features/search/arabic_normalizer.dart`, also dropping a leading «ال» from words), or of `nameEn`/`shortEn` case-insensitively.
  - **List**: `ListView.builder`, sorted by name in the interface language, opening scrolled to the chosen reciter.
  - **Rows**: as today, plus the style label (`styleMurattal`, `styleMujawwad`, `styleMuallim`). Empty result: `noReciterFound`.
  - Keep the `showReciterSheet(context, {downloaded})` signature and `chooseReciter`.

  Make T013 pass.
- [X] T022 [P] [US1] Use `ReciterList` in the onboarding reciter step: replace the `for (final r in reader.quran.reciters)` loop in `lib/features/onboarding/setup_steps.dart` with an embedded `ReciterList` in a bounded-height box. Keep the existing preview behaviour (`test/unit/reciter_preview_test.dart` still passes) and update `test/widget/onboarding_screen_test.dart` for the search field.
- [X] T023 [P] [US1] Add strings to `lib/app/l10n/app_ar.arb` and `app_en.arb`, then run `flutter gen-l10n`:
  - `searchReciters` «ابحث عن قارئ» / "Search reciters";
  - `noReciterFound` «لا يوجد قارئ بهذا الاسم» / "No reciter with this name";
  - `styleMurattal` «مرتّل» / "Murattal";
  - `styleMujawwad` «مجوّد» / "Mujawwad";
  - `styleMuallim` «معلّم» / "Teaching";
  - the new attribution text (T025).

  Replace the hard-coded `l10n.murattal` uses with the style label.
- [ ] T024 [US1] **V-1 listening and names** (quickstart Q-3, Q-7):
  - **Ayah reciters**: for each of the 49 new reciters, play 1:1, 2:1, 9:1 and 2:286. Confirm the voice, the style, and no doubled basmala.
  - **QUL surah reciters**: also confirm the basmala is heard once at the start of ayah 1 of Al-Baqarah and An-Nas, and is absent in At-Tawbah.
  - **Fixes**: correct `style` for `tablawi` and `ayman_sowaid` if needed. The owner reviews every `name_ar`.
  - **Recording**: rebuild with T018's commands after any change, and record the results in `research.md` › R2.
- [X] T025 [US1] Update `lib/features/settings/about_section.dart` and the `recitationAttribution` strings to credit QUL (qul.tarteel.ai) and EveryAyah (everyayah.com) with links, and the reciters generally («وجميع القرّاء المذكورين في قائمة القرّاء» / "and all reciters in the reciter list"), as FR-007 requires.
- [ ] T026 [US1] Device check on both reference phones: quickstart Q-1 to Q-8 in `specs/006-reciters-memorization/quickstart.md`. Record results in `specs/006-reciters-memorization/tasks.md` › Notes. Q-6 and Q-7 must show the highlight in time with the voice for QUL surah reciters and no cut words at boundaries. Before US1 ships without US2, also run `flutter build appbundle --release --analyze-size` and `dart run tool/size_check.dart android <json>`. Record the growth (expected ≈ 0.8 MB, catalogue only) and confirm 60 fps scrolling of the 51-row reciter list, as the constitution's Development Workflow requires for list and catalogue changes.

**Checkpoint**: US1 is shippable alone once D4 and D2 are granted.

---

## Phase 4: User Story 2 - Recite from memory and see each ayah appear (Priority: P1)

**Goal**: on-device memorization. Range sheet, hidden page, word-level matching with resume from
the wrong word, hints, reveal and mistake signals (FR-008 to FR-022).

**Independent Test**: spec US2, with the network off. Al-Fatiha 1–7 recited correctly. In
Al-Ikhlas, a skipped word in ayah 2 is corrected from that word, and a Next word hint is used in
ayah 3. Then deny the microphone.

### Spikes and model (gate)

- [X] T027 [US2] Spike S2 (size, research R7): on a branch, add `sherpa_onnx: 1.13.8` and `record: 7.1.2` to `pubspec.yaml` (exact versions; not 2.0.0) with a minimal call that loads `OfflineRecognizer`. Measure:
  - **Android**: `flutter build appbundle --release --analyze-size` and `tool/size_check.dart`;
  - **iOS**: an Xcode archive App Store size report on a Mac.

  Check whether `libsherpa-onnx-cxx-api.so` can be excluded with `packaging { jniLibs { excludes += ... } }` in `android/app/build.gradle` without breaking the C API. Write the measured growth into `plan.md` › Complexity Tracking, and **ask the owner to approve it** before T036 merges.
- [X] T028 [US2] Write `tool/export_asr_model.py` (maintainer tool, research R8):
  - convert `tarteel-ai/whisper-tiny-ar-quran` (and, behind `--model`, `whisper-base-ar-quran`) with sherpa-onnx's Whisper export script;
  - quantise to int8;
  - write `encoder.int8.onnx`, `decoder.int8.onnx` and `tokens.txt` into `build/asr/<version>/`, and copy `silero_vad.onnx` from the sherpa-onnx release;
  - print each file's size and SHA-256.

  Add a usage note to `tool/README.md`.
- [X] T029 [US2] Run T028 for tiny and base. Upload tiny's four files to a GitHub release `asr-tarteel-tiny-v1` on `hamzagamil/mathani`, and record sizes and hashes in Notes. *(Manual: needs the owner's GitHub access.)*
- [ ] T030 [US2] Record the S1 test sets per `specs/006-reciters-memorization/quickstart.md` › Prerequisites, with the mistakes CSV (`surah, ayah, kind, position`). Volunteers give written consent; the files are kept off the repository and any cloud storage. *(Manual.)*

### Tests for User Story 2

- [X] T031 [P] [US2] Write `test/unit/recitation_matcher_test.dart` for `RecitationMatcher` (contracts/memorization-engine.md › Rules 1–9), with one test per rule:
  - advance;
  - backtrack within the ayah without a mistake;
  - isti'adha/basmala prefix ignored, except at 1:1 and 27:30;
  - **missed** (skip detected via the next `lookAhead` words) and **wrong** (substitution) at `cursor` on final segments only, with the cursor staying on the word;
  - **added** before `cursor`;
  - unclear tokens becoming **wrong** after two final segments;
  - provisional segments never declaring mistakes;
  - completion only when all positions are matched or hinted;
  - tokens after the range ignored;
  - `hintNextWord` and `revealRest`.

  Add the **property test** over all 6,236 ayat, using `ayahs.search_text` from the test reader:
  - an ayah's own words complete it with 0 mistakes;
  - dropping, swapping or inserting one word yields exactly one mistake of the right kind and position.
- [X] T032 [P] [US2] Write `test/unit/memorization_controller_test.dart` with `FakeSpeechRecogniser` (scripted `Segment`s) and a fake device channel:
  - the start sequence and each `StartOutcome` (`unsupportedDevice`, `needsModel`, `micDenied`, `micPermanentlyDenied`);
  - state changes notified before awaits;
  - pause reasons (`user`, `silence` after `silencePause`, `interruption`, `background`, `routeLost`), with the mic stopped on each;
  - resume keeping matcher state;
  - Q1 resume from the wrong word;
  - the mistake signal by preference (`vibrate` calls `HapticFeedback.vibrate`, `sound` calls `playMistakeTone`, `none` calls neither, and the on-screen mark is always set);
  - a follow jump when the next ayah is on another page;
  - `end()` flushing within `endFlushWait`.
- [X] T033 [P] [US2] Write `test/unit/asr_model_test.dart` against the localhost server:
  - absent → downloading → ready;
  - resume from `.part` with `Range`;
  - a hash mismatch deletes the part and fails;
  - `delete()` frees the files;
  - a version folder change makes `ready` false.

  Write `test/unit/memorization_privacy_test.dart`, which reads every file in `lib/features/memorization/` except `asr_model.dart` and fails on `HttpClient`, `path_provider`, `writeAsBytes`, `writeAsString`, `openWrite` or `File(` (R16).
- [X] T034 [P] [US2] Write `test/widget/hidden_page_test.dart`:
  - on page 50, with ayat 3–5 of the range hidden, their words are not painted (golden), and the ayah-end markers, surah headers and text outside the range are painted;
  - revealing ayah 3 does not change any word's position (compare `LineReport` placements before and after);
  - a hinted word paints in `hint`, and a mistake marker in `mistake`;
  - semantics read «الآية ٥، مخفية»;
  - the same in the flowing layout, with hidden words transparent and line breaks identical.

  Add day and night goldens under `test/widget/goldens/`. Write `test/widget/range_sheet_test.dart`:
  - defaults from a page (FR-009: the surah where the page starts, its first and last ayah starting on the page) and from a long-press (that ayah to the last ayah of its page);
  - `to < from` is impossible;
  - the model row is shown when not ready, and Start is disabled.

  Write `test/widget/memorization_bar_test.dart`:
  - mic indicator, progress and the four buttons ≥ 48 dp;
  - the mistake line for `mistakeLineDuration` as a live region;
  - each paused reason's text.

### Spike S1 (gate for the rest of US2)

- [ ] T035 [US2] Spike S1 (research R8, R11; quickstart › Spikes):
  - **Build**: on T027's spike branch (which already has `sherpa_onnx` and `record`), implement T037–T040 far enough to run, and run them in a debug harness screen on both reference phones over both test sets (T030), for tiny and base. T037–T040 are **completed in place** after S1 passes, not rewritten.
  - **Measure**: SC-004 (≥ 95% of correct ayat revealed with no false mistake), SC-005 (≥ 95% of mistakes detected), SC-006 (0 false reveals) and SC-007 (≥ 95% of reveals ≤ 1 s); plus peak memory and model load time.
  - **Tune**: adjust `thetaMatch`, `thetaUnsure` and `kVariantPairs`, then fix them as constants.
  - **Gate**: set `minRamBytes` from the slowest passing phone.
  - **Record**: the results and the chosen model go in `research.md` › R8.
  - **If neither model passes, stop and report to the owner** (spec assumptions); do not continue with T041–T052.

### Implementation for User Story 2

- [X] T036 [US2] Merge the `sherpa_onnx: 1.13.8` and `record: 7.1.2` additions from T027's branch into `pubspec.yaml` (after the T027 approval). Run `flutter pub get` and `flutter analyze`.
  - **Android**: add `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` to `android/app/src/main/AndroidManifest.xml`.
  - **iOS**: add `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist`, with localised `ios/Runner/ar.lproj/InfoPlist.strings` and `en.lproj/InfoPlist.strings`, using the text in research R16.
- [ ] T037 [P] [US2] Write `lib/features/memorization/recitation_matcher.dart` (pure Dart; no Flutter imports), exactly as contracts/memorization-engine.md › RecitationMatcher:
  - `RefWord` and `MatchEvents`;
  - `MatchTuning` with `thetaMatch`, `thetaUnsure`, `lookAhead`;
  - similarity is `1 − levenshtein/maxLen`, also tried joining two tokens or two reference words;
  - `kVariantPairs`, applied to both sides before comparing.

  Build `kVariantPairs` by diffing `normalizeArabic(text_uthmani)` against the imla'i search words for all 6,236 ayat, with a one-off script in `tool/`; commit the resulting const list. Reference words come from `ayahs.search_text` split on spaces, mapped to Uthmani word ids via `words.search_offset`. Add `QuranRepository.memorizationWords(surah, from, to)` returning `List<List<RefWord>>` in `lib/data/quran_repository.dart`. Make T031 pass.
- [X] T038 [P] [US2] Write `lib/features/memorization/asr_model.dart` (contracts/memorization-engine.md › AsrModel):
  - **Files and states**: pinned file names, sizes and SHA-256 from T029, and the URL base `https://github.com/hamzagamil/mathani/releases/download/asr-tarteel-tiny-v1/`. The folder is `<app support>/asr/<asrModelVersion>/`, excluded from backup via `DeviceChannel.excludeFromBackup`. States `absent | partial | downloading | ready`, derived from the files.
  - **Download**: one file at a time with `Range` resume from `.part`; verify SHA-256 with `package:crypto`, moved from `dev_dependencies` to `dependencies` in `pubspec.yaml` (pure Dart, already in the lock file; add one line to `plan.md` › Complexity Tracking); then rename.
  - **Before downloading**: reuse `startSurahDownload`'s precondition sheet logic from `lib/features/recitation/download_queue.dart` (network state, mobile-data confirm, free space). Extract it into a shared function rather than copying it.

  Make T033 pass.
- [X] T039 [P] [US2] Extend the device channel with `deviceSupport`, `openAppSettings` and `playMistakeTone` (contracts/memorization-engine.md › Device channel additions):
  - **Dart**: `lib/shared/device_channel.dart`, with missing-plugin defaults (supported, no-op, no-op);
  - **Android**: `android/app/src/main/kotlin/app/mathani/mathani/MainActivity.kt` (`Build.SUPPORTED_64_BIT_ABIS`, `ActivityManager.MemoryInfo.totalMem`, `ACTION_APPLICATION_DETAILS_SETTINGS`, `ToneGenerator(AudioManager.STREAM_NOTIFICATION, 50).startTone(ToneGenerator.TONE_PROP_BEEP, 120)`);
  - **iOS**: `ios/Runner/AppDelegate.swift` (`ProcessInfo.processInfo.physicalMemory`, `UIApplication.openSettingsURLString`, `AudioServicesPlaySystemSound` with a bundled `ios/Runner/mistake.caf`, a 120 ms 880 Hz tone of about 3 KB added to the Runner target).

  Write `lib/features/memorization/device_support.dart`, which is supported when arm64 and `ramBytes ≥ minRamBytes`, with the reason for the message.
- [X] T040 [US2] Write `lib/features/memorization/mic_source.dart` and `lib/features/memorization/speech_recogniser.dart` (contracts/memorization-engine.md › SpeechRecogniser; research R10):
  - **Mic**: `record` `startStream(RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1, androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition), iosConfig: IosRecordConfig(manageAudioSession: false)))`. Convert PCM16 to `Float32List`. `stop()` stops the stream (no pause). `gate(Duration)` drops samples while the tone plays.
  - **Recogniser**: a long-lived isolate holding sherpa-onnx `VoiceActivityDetector` (Silero; `vadThreshold`, `vadMinSilence`, `vadMinSpeech`, `vadMaxSpeech`, keeping `forcedSplitOverlap`) and `OfflineRecognizer` (Whisper int8; language `ar`; task `transcribe`; **no initial prompt**; threads 2 on ≤ 4 cores, else 4).
  - **API**: `load(modelDir)`, `accept`, `segments`, `flush`, `reset`, `dispose`.
  - **Fake**: add `FakeSpeechRecogniser` in `test/support/fake_memorization.dart`.
- [X] T041 [US2] Write `lib/features/memorization/memorization_controller.dart` and `MemorizationScope` (contracts/memorization-engine.md › MemorizationController):
  - **Start sequence** (steps 1–8): stop the recitation via `RecitationScope`; check the gate, the model and the mic permission (after the explainer, T044); configure `AudioSession` (`playAndRecord`, mode `measurement`, `defaultToSpeaker`, `allowBluetooth`); load the recogniser; start the mic; set `listening`.
  - **Segments**: normalise segments with `normalizeArabic`, split them, and pass them to the matcher.
  - **On mistakes**: mark, then signal by `preferences.mistakeSignal`, gating the mic for `toneGate` when sound.
  - **On completion**: reveal, notifying once; follow with the reader's `jumpTo` when the next ayah is on another page.
  - **Pauses**: on `AudioSession` interruptions, `AppLifecycleState.inactive`/`paused`, input route loss, and `silencePause` without a segment.
  - **End**: `end()` stops the mic, flushes within `endFlushWait`, builds the result (T050), and restores the playback audio session.
  - **Queries**: expose `isHidden(wordId)`, `isHinted(wordId)`, `hasMistake(AyahRef)` and `expected`.
  - **Scope**: create `MemorizationScope` lazily in `lib/app/app.dart`, beside `RecitationScope`.

  Make T032 pass.
- [X] T042 [US2] Hide words in `lib/features/reader/mushaf_page_renderer.dart` (research R13):
  - new config fields `hidden`/`hinted` (`bool Function(int wordId)?`) and `mistakeAyat` (`Set<AyahRef>`);
  - skip painting hidden non-ayah-end words while keeping their placement;
  - paint hinted words in `palette.hint` and ayah-end glyphs of mistake ayat in `palette.mistake`;
  - pulse the expected ayah's marker in `accent` unless `MediaQuery.disableAnimations`;
  - add these fields to the repaint comparison, so repainting happens only when they change.

  Pass the controller's predicates through `lib/features/reader/mushaf_view.dart`. Add `hint` and `mistake` to `MushafPalette`, and add tokens in `lib/app/theme/tokens.dart` and `app_theme.dart` for day and night per contracts/memorization-ui.md › Theme tokens, with ≥ 3:1 contrast checked in a test.
- [X] T043 [US2] Hide words in `lib/features/reader/flowing_view.dart`: hidden words use a transparent colour in their `TextSpan` (identical line breaks), hinted words `colors.hint`, and mistake ayah numbers `colors.mistake`. Exclude hidden text from semantics with a `semanticsLabel` of «الآية N، مخفية» per hidden ayah. Keep the expected ayah in view on follow, as for the recitation. Make T034 pass for both layouts.
- [X] T044 [P] [US2] Write `lib/features/memorization/range_sheet.dart` and `lib/features/memorization/mic_explainer.dart` (contracts/memorization-ui.md › Range sheet, Microphone explainer):
  - **Range sheet**: a surah picker reusing the go-to sheet's surah list from `lib/features/index/goto_sheet.dart`; From/To steppers clamped to 1..ayahCount, with From > To moving To; the summary line; the model row with Download and progress (T038); the unsupported-device message (T039); Start enabled only when ready.
  - **Explainer**: shown once, before the first system prompt; a «فتح الإعدادات» button calls `openAppSettings` when permanently denied.

  Make the range-sheet part of T034 pass.
- [X] T045 [P] [US2] Write `lib/features/memorization/memorization_bar.dart` (contracts/memorization-ui.md › Memorization bar):
  - mic indicator («يستمع» with a red dot, semantics "Microphone on");
  - «الآية ٣ من ٧»;
  - Pause/Resume, «الكلمة التالية», «أظهر الآية», «إنهاء» at 48 dp;
  - the paused reason text;
  - the mistake line «خطأ — تابع من الكلمة» for `mistakeLineDuration` in a `Semantics(liveRegion: true)`;
  - «عُد إلى الآية» when the expected ayah is off-screen.

  Make the bar part of T034 pass.
- [X] T046 [US2] Wire the reading screen in `lib/features/reader/reader_screen.dart` and `lib/features/reader/ayah_actions.dart` (contracts/memorization-ui.md › Entry points and Reading screen during a session):
  - add the Memorize toolbar button beside Listen, and «احفظ من هذه الآية» in ayah actions;
  - while a session exists: dock `MemorizationBar` in place of the recitation bar, hide Listen, and disable ayah actions for range ayat;
  - announce reveals («ظهرت الآية ٥») with `SemanticsService.announce`.
- [X] T047 [P] [US2] Add every memorization string in contracts/memorization-ui.md (entry points, range sheet, model row with size, explainer, denial, bar, paused reasons, unsupported device, Settings and Downloads rows, the tour hint) to `lib/app/l10n/app_ar.arb` and `app_en.arb`, with Arabic as source text. Run `flutter gen-l10n`.
- [X] T048 [P] [US2] Settings and Downloads:
  - in `lib/features/settings/settings_screen.dart`, add the «التنبيه عند الخطأ» row with Vibrate (default), Sound and None, saved through T008;
  - in `lib/features/recitation/downloads_screen.dart`, add the «نموذج الحفظ» row with size and delete (disabled while a session exists), freeing storage within 1 s. Extend `test/widget/downloads_screen_test.dart`.
- [X] T049 [P] [US2] Add the Memorize hint to the button tour in `lib/features/onboarding/button_tour.dart` («اختبر حفظك: تلُ من ذاكرتك وتظهر الآيات كلما أتممتها»), and update `test/widget/button_tour_test.dart` and `tour_replay_test.dart`.

**Checkpoint**: US2 works offline on both phones (quickstart Q-10 to Q-23, except result-specific checks).

---

## Phase 5: User Story 3 - Get a score for my session (Priority: P2)

**Goal**: the result screen with score, counts, review and Try again (FR-023 to FR-026).

**Independent Test**: spec US3. Al-Mulk 1–10, with ayat 1–4 correct, a correction in 5, a hint in
6, ayah 7 revealed, 8 correct, then End. Score 72; counts and marks match.

### Tests for User Story 3

- [X] T050 [P] [US3] Write `test/unit/memorization_score_test.dart` for `lib/features/memorization/memorization_score.dart`:
  - User Story 3's example gives `(5×1 + 0.5 + 0.25 + 0) / 8 × 100 = 71.875 → 72`;
  - quickstart Q-12 gives 69;
  - weakest-outcome precedence (`revealed` > `hinted` > `corrected`);
  - an ayah ended mid-recitation counts as `notReached`;
  - `score == null` when `reached == 0`;
  - rounding is half away from zero (`.round()`).
- [X] T051 [P] [US3] Write `test/widget/result_screen_test.dart`:
  - score «٧٢» with «من ١٠٠», or «—»;
  - the counts line and «بلغت ٨ من ١٠ آيات»;
  - review marks: missed/wrong underlined in `mistake`, added caret, hinted words in `hint`, «أُظهرت» and «لم تُبلغ» tags;
  - Try again starts a new session on the same range;
  - Done returns to reading at the last page of the session;
  - nothing persisted (no `user.db` writes).

### Implementation for User Story 3

- [X] T052 [US3] Write `lib/features/memorization/memorization_score.dart` (pure Dart): `SessionResult.from(Map<AyahRef, AyahProgress>)` per data-model › Session Result, with `score = round(100 × (1·noMistake + 0.5·corrected + 0.25·hinted + 0·revealed) / reached)` and `null` when `reached == 0`. Use it from `MemorizationController.end()`. Make T050 pass.
- [X] T053 [US3] Write `lib/features/memorization/result_screen.dart` (contracts/memorization-ui.md › Result screen):
  - a full-screen route pushed on `phase == ended`;
  - score, counts, reached;
  - the review list in flowing style using `AyahProgress.mistakes` and `hints` (the heard form of a wrong word only in semantics);
  - Try again (`start(range)` again) and Done (pop and `jumpTo` the last session page);
  - the result is discarded on close (FR-026).

  Make T051 pass.
- [ ] T054 [US3] Device check: quickstart Q-11 and Q-12 results, plus spec US3's example on both phones. Record in `specs/006-reciters-memorization/tasks.md` › Notes.

**Checkpoint**: all three stories work independently.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T055 [P] Licences: add `assets/licences/` texts for sherpa-onnx (Apache-2.0), the Tarteel models (Apache-2.0, with notice), onnxruntime (MIT) and `record` (MIT). Register them in `registerAssetLicences()` in `lib/features/settings/about_section.dart`, list them in `pubspec.yaml` assets, and add rows to `docs/licences.md`.
- [X] T056 [P] Privacy: update `docs/store/privacy.md` and the privacy policy:
  - microphone used during memorization only;
  - audio processed on device, not collected (Apple and Google definitions);
  - new hosts `download.quranicaudio.com`, `audio-cdn.tarteel.ai` and GitHub Releases, with no identifiers.

  Note the App Privacy and Data safety answers to change before release.
- [ ] T057 Add a `WITH_MEMORIZATION` variant to `integration_test/paging_perf_test.dart` that starts a session with `FakeSpeechRecogniser` and pages 20 times. Confirm 60 fps on both phones (SC-010) and that cold start is unchanged (≤ 2 s).
- [X] T058 Size report: run `flutter build appbundle --release --analyze-size` and `dart run tool/size_check.dart android <json>`, plus the iOS archive. Write the growth by part (sherpa-onnx/onnxruntime, catalogue, `record`, code) into `plan.md` › Complexity Tracking and the PR description (Principle IV).
- [ ] T059 Run the full quickstart on both reference phones and the API 24 emulator (Q-1 to Q-23, including Q-19 unsupported device, Q-20 screen readers, Q-21 largest font and night, and Q-23 0 bytes sent during a session), plus the SC-009 usability test with 10 readers. Record results in `specs/006-reciters-memorization/tasks.md` › Notes.
- [ ] T060 Delete the S1 test-set recordings (T030) and confirm in `specs/006-reciters-memorization/tasks.md` › Notes. Record the chosen model and tuned thresholds in `research.md` › R8 and R11.
- [ ] T061 Run `flutter analyze` and `flutter test` from the repository root (`analysis_options.yaml`, `test/`); both must pass. Run `/speckit-analyze` over `specs/006-reciters-memorization/` for spec, plan and tasks consistency.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: after Setup. **Blocks all stories.**
- **US1 (Phase 3)**: after Phase 2. Independent of US2 and US3. T017 and T018 are long or manual;
  start them early.
- **US2 (Phase 4)**: after Phase 2.
  - T027–T030 can start at once, in parallel with US1.
  - T035 (S1) needs T028–T030 and minimal T037–T040.
  - **T041–T049 wait for T035 to pass and for T027's owner approval.**
- **US3 (Phase 5)**: after US2's controller (T041). The score (T050, T052) can be written any
  time after Phase 2, since it is pure Dart.
- **Polish (Phase 6)**: after the stories to be released.

### Within each story

- Tests first (they should fail), then implementation.
- **US1**: T014 → T015 → T017 → T018; T019 and T020 after T007; T021 → T022; T024 after T018.
- **US2**: T037–T040 start in T035 and are finished after it; T036 → T040 → T041; T037–T039 in parallel; T042 and T043 before T046; T044, T045,
  T047, T048 and T049 in parallel after T041.

### Parallel Opportunities

- Phase 1: T002 and T003.
- Phase 2: T008 and T009 alongside T004–T007.
- US1: T010–T013 together; T014 with T016; T022, T023 and T025 after T021.
- US2: T031–T034 together; T037, T038 and T039 together; T044, T045, T047, T048 and T049
  together.
- US3: T050 and T051 together.
- Across stories: US1 (catalogue run, UI) and US2 (spikes, matcher) can proceed in parallel once
  Phase 2 is done.

---

## Parallel Example: User Story 1

```text
T010 mp3_frames_test   T011 clip_range_test   T012 ayah_fetcher_range_test   T013 reciter_list_test
then: T014 mp3_frames.dart  ∥  T016 recitations.json (51 rows)
```

## Parallel Example: User Story 2

```text
T031 matcher tests  ∥  T032 controller tests  ∥  T033 model + privacy tests  ∥  T034 widget tests
T037 recitation_matcher.dart  ∥  T038 asr_model.dart  ∥  T039 device channel + device_support.dart
after T041: T044 range sheet  ∥  T045 bar  ∥  T047 strings  ∥  T048 settings/downloads  ∥  T049 tour
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 and Phase 2.
2. Phase 3 (US1): 51 reciters, QUL clips, searchable list.
3. **Stop and validate**: quickstart Q-1 to Q-8 on both phones.
4. Ship once D4 and D2 are granted. US1 adds no dependency and about 0.8 MB.

### Incremental Delivery

1. US1, as above.
2. In parallel: the US2 gates (S2 size approval, model export, S1 accuracy).
3. US2 once S1 passes: memorization without the result screen is usable but incomplete.
4. US3 straight after: the score and review complete the request. Ship US2 and US3 together.

---

## Notes

- [P] tasks touch different files and have no dependencies on incomplete tasks.
- Manual steps that need the owner: T017 (QUL account), T024 (Arabic names), T027 (size
  approval), T029 (GitHub release), T030 (consent and recordings), the D2 and D4 requests (T003).
- Record here: the size baseline (T001), S2 growth (T027), model hashes (T029), S1 results
  (T035), device checks (T026, T054, T059) and test-set deletion (T060).

## Implementation notes

- **T001 baseline** (2026-10-24): `flutter analyze` clean; `flutter test` 237 passed. The size
  reference for SC-010 is the committed `docs/size_baseline.json`: Android **140.21 MB**
  (147,020,116 B). A local `appbundle --analyze-size` build (arm64) measured 140.24 MB, but it ran
  while Phase 2 edits were landing, so it is not used as the reference. The first release build
  failed because the generated plugin registrant still listed `integration_test` after
  `flutter test`. `flutter pub get` before building fixed it.
- **T003**: `docs/licences.md` lists the 41 further EveryAyah folders as one row that points to
  the table in `docs/permissions/everyayah-request.md`, rather than 41 rows, so the folder list
  has one source. The QUL recordings have their own rows.
- **T004**: QUL surah manifests also record each surah file's length (`file_bytes`). The build
  uses it to check that `range_start + Σ sizes == file length` (contracts/reciter-catalogue.md
  check).
- **T005**: `quran.db` shrank by 213 KB (5,668,864 → 5,455,872 B) with the packed sizes for
  the two reciters.
- **T009**: written as `test/widget/recitation_sizes_test.dart` and
  `test/unit/mistake_signal_pref_test.dart`. The first needs the harness, so it is a widget test.
  It compares all 114 surahs when `tool/sources/recitations/` is present, and otherwise the
  committed sample `test/fixtures/recitation_sizes_004.json` (surahs 1, 67, 114).
  `flutter test`: 240 passed.
- **T014**: some QUL surah files are MPEG-2 Layer III (Khalid Al-Jalil's Al-Fatiha is 144 kbps at
  24 kHz, while his Al-Baqarah is MPEG-1 at 96 kbps), so `tool/src/mp3_frames.dart` reads MPEG-1,
  2 and 2.5 Layer III and checks CBR per file. It also finds the first frame after padding that
  follows the ID3 tag.
- **T017**: QUL's "Download json" needs a sign-in, which this session cannot do. The timings were
  fetched instead from QUL's public preview API
  (`/api/v1/audio/surah_segments/<audio_id>`, the endpoint its own player uses) and saved in the
  download shape (`timestamp_from`/`timestamp_to`). They are pinned in `tool/sources.lock.json`
  with `--record-qul`. Audio ids: 314→168, 346→88, 368→122, 388→160, 420→170, 421→172, 572→179.
  The maintainer can replace them with the official downloads; the tool reads both shapes.
  **Minshawi with children (314) has no timings for surah 33 and 3 out-of-order ayat, so the
  build drops it (FR-002).**
- **T015 check**: for Khalid Al-Jalil (surahs 2, 67 and 112), every clip boundary is within one
  frame (≤ 26 ms) of the cut time, and a clip start read from the CDN begins with an MPEG frame
  sync (`ff fb`).
- **T019**: `ClipRange` returns `(start, end, total)`; `QuranRepository.surahFileBytes` gives
  `total`. The fetcher requires `206` with exactly `Content-Range: bytes start-(end−1)/total`.
- **T020**: `RecitedOrder.basmalaItems` is a function of the current reciter, not a fixed bool,
  because the reciter can change during a session. On `setReciter`, a basmala item becomes ayah 1
  for a reciter whose basmala is part of it.
- **T021**: the list is sorted by name, so the 004 sheet test now checks name order and selects
  through search. Tests no longer assume two reciters.
- **T025**: two credits. EveryAyah/quranicaudio (`recitationAttribution`, reworded), and QUL
  (`qulRecitationsCredit`, linking to qul.tarteel.ai).
- **T031**: rule tests in `test/unit/recitation_matcher_test.dart` (17). The property test is in
  `test/widget/recitation_matcher_quran_test.dart`: 6,236 ayat plus 115,914 drop/swap/insert
  mutations, **100% exact**. Getting there needed four changes to the matcher design:
  - competing readings (going back, wrong, missed, added) are scored by how many following
    words line up, and a tie goes to going back (no mistake);
  - joined readings need ≥ 0.9 similarity, or a dropped short word hides in the join;
  - an Uthmani word that is several imla'i words (يَبْنَؤُمَّ «يا ابن ام») is split into parts;
    mistakes and hints are reported at the Uthmani position;
  - a skip on to the next ayah is a missed word.

  `MatchEvents.completed` lists every ayah completed in a segment, since short ayat can be
  recited in one breath.
- **T037 (partial)**: `recitation_matcher.dart` and `QuranRepository.memorizationWords` are done
  and tested. `kVariantPairs` is a short starting list. The list built from the Uthmani/imla'i
  diff waits for S1, because which spellings matter depends on what the recogniser writes.
- **T011**: written with a fixture copy of `quran.db` holding one `qul_surah` reciter (surahs 1
  and 112). Clips are contiguous from `range_start` to the file length, and the download size
  counts no separate basmala.
- **T027 (approved by the owner on 2026-10-24; the iOS figure moves to T058, which needs a Mac)**: two release bundles from the same working
  tree (`--target-platform android-arm64 --analyze-size`), one with `sherpa_onnx: 1.13.8` +
  `record: 7.1.2` and one without:

  | Part | With | Without | Growth |
  | --- | --- | --- | --- |
  | Common (assets, Dart, resources) | 132.08 MB | 132.05 MB | +0.03 MB |
  | arm64-v8a native | 21.81 MB | 12.26 MB | **+9.56 MB** (`libonnxruntime.so` 7.59, `libsherpa-onnx-c-api.so` 1.83) |
  | armeabi-v7a native | 8.73 MB | 0.02 MB | +8.70 MB |
  | x86_64 native | 10.71 MB | 0.03 MB | +10.69 MB |
  | **One arm64 phone** (Play splits by ABI) | 153.90 MB | 144.31 MB | **+9.59 MB** |
  | `tool/size_check.dart` (all ABIs in base) | 169.19 MB | 140.22 MB | +28.98 MB (FAIL > 1 MB) |

  The plugin ships prebuilt libraries for all three ABIs, even when Flutter builds arm64 only.
  `size_check` adds them up, but a phone downloads one set. `libsherpa-onnx-cxx-api.so` is not in
  the bundle, so the `jniLibs` exclusion has nothing to remove. No `OfflineRecognizer` call was
  added: the native libraries are packaged whether Dart calls them or not, so the Dart growth
  (+0.03 MB) is the only part a call would change. The packages are removed again (`pubspec.yaml`
  and `pubspec.lock` equal HEAD). US1 alone: 140.22 MB, +0.01 MB on the 140.21 MB baseline. iOS
  needs a Mac archive.
- **T036**: `record: 7.1.2` and `sherpa_onnx: 1.13.8` are in `pubspec.yaml` (exact versions, with a
  comment). `flutter pub get` and `flutter analyze` pass.
- **T028**: `tool/export_asr_model.py` runs sherpa-onnx's own export script (v1.13.8, SHA-256
  pinned) on an openai-whisper model rebuilt from the Hugging Face checkpoint. Dimensions are read
  from the weights' shapes. Torch ≥ 2.9 needs `dynamo=False`, because the script targets the
  TorchScript exporter. The tool also quantises the decoder's token embedding (research R8): the
  decoder shrinks from 89.8 to 50.0 MB. Python 3.12 was installed for the current user (`py -3.12`);
  usage is in `tool/README.md`.
- **T029**: release <https://github.com/hamzagamil/mathani/releases/tag/asr-tarteel-tiny-v1>
  (not marked latest), with `NOTICE.txt`, the Apache-2.0 and Silero VAD (MIT) licences, and
  `SHA256SUMS`. Download and `Range` (206) were checked from the public URLs. Pin in
  `asr_model.dart`:

  | File | Bytes | SHA-256 |
  | --- | --- | --- |
  | `encoder.int8.onnx` | 12,926,471 | `30c1c6f988f395cc212c92795c2c9d7589a65b4909a70c72515667af73501b17` |
  | `decoder.int8.onnx` | 50,015,755 | `7cbd0e65cd3348c3577280d85d80383798300ce8c0c3dd7953cdab69bbee5538` |
  | `tokens.txt` | 866,987 | `febeed8e568f92d9ca984580bc2e6b605b867dc5ba4486f9646de381b44a8226` |
  | `silero_vad.onnx` | 643,854 | `9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6` |

  Total 64,453,067 B (61.5 MiB, shown as «٦١٫٥ م.ب» by `formatSize`), against the plan's estimate of ≈ 40 MB, which
  counted one byte per parameter. Spec, plan and UI contract are updated. Base (for S1 only, not
  uploaded) is in `build/asr/tarteel-base-v1`: encoder 29,104,807 B and decoder 77,550,880 B,
  108.2 MB in total. The export is not byte-for-byte reproducible (the encoder's hash changes
  between runs), so the release files are the reference.
- **T033**: `test/unit/asr_model_test.dart` (7 tests) runs against a localhost server inside the
  test, with a fake device channel that records the backup exclusion. A server that ignores
  `Range` sends the whole file, which replaces the part. A missing file fails as `failed`.
- **T038**: `AsrModel.refresh()` reads the state from the files (sizes only; hashes are checked
  on download). `download()` throws `AsrModelException(failed | damaged | noSpace)` and keeps what
  was verified. A new version's download deletes the old version's folder. The precondition
  checks moved from `startSurahDownload` into `confirmDownload(context, device, size)` in
  `download_queue.dart`, with the same order and messages. A live check against the published
  release resumed `tokens.txt` from a 300 KB part across GitHub's redirect and verified it.
  Found while testing: `Directory.list()` joins paths with `\` on Windows, so folders are
  compared by name.
- **T036 (completed later)**: `RECORD_AUDIO` in `AndroidManifest.xml`, and
  `NSMicrophoneUsageDescription` in `Info.plist` with Arabic and English `InfoPlist.strings`
  (text from R16). These were missed when T036 was first marked.
- **T039**: Dart `deviceSupport()`, `openAppSettings()` and `playMistakeTone()` (missing-plugin
  defaults: supported, no-op, no-op). Kotlin and Swift as in the contract. `ios/Runner/mistake.caf`
  (3.9 KB: 120 ms, 880 Hz, 16 kHz, 10 ms fades) is added to the Runner target's resources in
  `project.pbxproj`. `device_support.dart`: `minRamBytes` is **2.5 GiB**, because a phone sold
  with 3 GB reports about 2.7–2.9 GiB. S1 confirms or raises it. `flutter build apk --debug`
  compiles the Kotlin. **The Swift is not compiled yet (no Mac): check it in the first iOS build.**
  Tests: `test/unit/device_support_test.dart` (4).
- **T040**:
  - `mic_source.dart`: `record` with `recorder.ios?.manageAudioSession(false)`. Our
    `audio_session` config is play-and-record, measurement mode, default-to-speaker and
    Bluetooth, and goes back to `.music()` on stop. `IosRecordConfig` has no `manageAudioSession`
    field in record 7.1.2; it is a method on `recorder.ios`. It does have
    `allowHapticsAndSystemSoundsDuringRecording`, which is **set to true**: iOS would otherwise
    mute the vibration and the system-sound mistake tone while recording (R12). `Pcm16Decoder`
    carries a sample split across chunks.
  - `speech_recogniser.dart`: sherpa-onnx on a long-lived isolate (`initBindings` inside it),
    with samples sent as `TransferableTypedData`.
  - Findings from decoding EveryAyah clips through the whole chain (contract updated):
    - Silero at 0.5 missed 6.6 s of chanted speech over 8 clips, and at 0.25 it missed 1.9 s, so
      `vadThreshold` is 0.25.
    - `max_speech_duration` is soft (25.8 s segments at 12; 39 s at 20). Forced segments are held
      until a pause, and anything over 25 s is decoded in overlapping pieces.
  - `RecitationMatcher` gained a (2 tokens, 2 words) joined reading for a misplaced space
    («وسعكر سيه»). The property test stays at 100% (115,914 mutations).
  - `test/unit/speech_recogniser_test.dart`: PCM tests, plus a maintainer smoke test that runs when
    `build/asr/tarteel-tiny-v1` and `build/asr/check/*.f32` exist. It decodes 8 Alafasy ayat
    through the isolate, VAD and matcher: 7 of 8 complete with no mistake. The miss is 2:255
    word 46, «يئوده» heard as «يأوله» (left for S1's variant list).
  - On Windows desktop tests, System32's onnxruntime 1.17 shadows the bundled one. The worker
    preloads the bundled DLL when given `nativeLibraryDir`; the phones bundle their own.
  - `FakeSpeechRecogniser` is in `test/support/fake_memorization.dart`.
- **T055**: `assets/licences/` holds ONNX Runtime (MIT), the Tarteel model (Apache-2.0, with the
  changes stated) and Silero VAD (MIT). They are registered in `registerAssetLicences()`, listed
  as a folder in `pubspec.yaml`, and given rows in `docs/licences.md` › Memorization.
  `sherpa_onnx` (Apache-2.0) and `record` (MIT) are not added again: Flutter already collects
  their package `LICENSE` files into the licences page. Test:
  `test/widget/asset_licences_test.dart`.
- **T018**: the build ran about 3 h (resumed with `--skip-existing`). Five reciters failed, were
  removed from `tool/recitations.json` and are recorded in research R0: `ayyoub`,
  `minshawy_children`, `mostafa_ismail`, `husary_ijazah`, `salimi`. `add_recitations.dart`:
  `quran.db: 46 reciters, 5244 surah rows`. `verify_quran.dart`: PASS. The tests follow the
  real catalogue:
  - `reciter_preference_test`: the 004 reciters first, 46 in all.
  - `reciter_list_test`: Husary has 3 recordings; the scroll test uses Al-Dosari.
  - The onboarding tests find reciters through the search field. The list builds only the rows
    in view, and a reciter's recordings share one name.

  Fixed while doing this:
  - `ReciterList` dropped `prototypeItem`. At double text size, wrapped names overflowed rows
    fixed to the prototype's height (onboarding_a11y_test). The list now jumps near the chosen
    row, then `Scrollable.ensureVisible` brings it into view.
  - A sample button's name includes its style unless it is Murattal, so screen readers can tell
    «الحصري · مجوّد» from «الحصري».

  `version_test` fails because `pubspec.yaml` is at `1.4.0+7` and `lib/app/version.dart` at
  `+6`. That change was not part of this work.
- **US2/US3 UI built before S1 (owner decision, 2026-10-24)**: the owner chose to build and show
  memorization now, without waiting for the S1 accuracy gate. T035 (S1) stays open, and its
  results may still change thresholds and the variant list.
  - **Controller** (`memorization_controller.dart`): the contract's start sequence, with segments
    normalised into the matcher. Mistakes signal by preference (vibrate, sound with mic gating,
    or none). Reveals follow the next ayah's page. The session pauses on silence (30 s), on
    leaving the app, on audio interruptions and when the headset is unplugged. `end()` flushes
    for 1.5 s and builds the `SessionResult`; `close()` clears it after Done.
  - **Hiding**: the Mushaf renderer skips painting hidden words and tints hinted words and the
    expected/mistake ayah-end marks with a `srcIn` colour filter, without relayout.
    `WordMarks` repaints only when the controller's revision changes. The flowing view draws
    hidden words transparent, so line breaks are identical, and reads hidden ayat as
    «الآية N، مخفية». Range ayat have no long-press actions during a session. The expected
    ayah's marker is accent-coloured **without the pulse** (not done).
  - **UI**: Memorize toolbar button, «احفظ من هذه الآية», range sheet (surah, From/To steppers
    with direct entry, summary, model download row, unsupported message), microphone explainer
    and denial with Open Settings, bar, result screen with review, Settings «التنبيه عند الخطأ»,
    the Downloads model row with delete, and the tour hint (the tour now has 8 stops).
  - **Explainer**: shown whenever the microphone is not yet allowed, before asking. The contract's
    "first time only" is not tracked, so a denied reader sees it again.
  - **Tests**: `test/widget/memorization_session_test.dart` (3): a full Al-Ikhlas session (hidden
    words, reveals, an added word, a hint, score 69, Done back to page 604), End mid-range
    (unfinished and not-reached tags), and microphone refusal.
  - **Emulator (API 36, x86_64)**: the 2 GB default AVD shows «الحفظ غير متاح على هذا الجهاز —
    يحتاج ذاكرة ٣ غيغابايت على الأقل» (gate works). With 4 GB, the model downloaded from the
    release (all four files verified), and a session started and listened. The input lag of the
    software-rendered emulator made scripted recitation impractical, so the voice path still
    needs a real phone.
  - **Matcher behaviour seen in the tests**: a stray word at the end of a segment, followed by the
    right word in the next segment, is not a mistake (boundary noise). After a mistake, the rest
    of that segment is not matched; the reader repeats from the word, as Q1 says.
- **Word-by-word reveal (owner request, 2026-10-25)**: with a recogniser of medium accuracy, the
  reader needs to see which word was not recognised. Each word is now revealed as soon as it is
  recited, not when its ayah is complete; after a mistake, the first hidden word is the one to say
  again. Spec FR-012, FR-014 and FR-015 are updated. The controller reads revealed and hinted
  words from the matcher's state (cursor and tallies), not from `MatchEvents.matched`, whose
  second field is a part index from `accept()` but a word position from `hintNextWord()`.
  Scoring is unchanged. Test: the Al-Ikhlas session checks that «قل هو» shows exactly those two
  words, and that after a mistake the word to repeat stays hidden.
- **T056**: `docs/store/privacy.md` covers the new hosts (`download.quranicaudio.com`,
  `audio-cdn.tarteel.ai`, GitHub Releases), the model on the device, the microphone (on-device
  only, not collected under Apple's or Google's definition), `RECORD_AUDIO` and
  `NSMicrophoneUsageDescription`. The App Privacy ("Data Not Collected") and Data safety ("No data
  collected") answers stay, to be checked before the 1.4 release. The policy page
  (`Mathani-landing/privacypolicy.html`, Arabic and English) is updated locally: internet use,
  downloads on the device, and the microphone. It had still said the app never goes online,
  which was wrong since 004. **Publishing it to mthani.app/privacypolicy is the owner's step.**
- **T057 (code only)**: `--dart-define=WITH_MEMORIZATION=true` starts a session on Al-Baqarah 1–25
  with a silent recogniser and no microphone, then pages 20 times (`mushaf_paging_with_memorization`).
  Profile mode does not run on emulators, so the 60 fps check needs the reference phones.
- **T058**: release bundle, arm64, `--analyze-size`, against the pre-006 tree from S2:

  | Part | Growth |
  | --- | --- |
  | arm64-v8a native (sherpa-onnx, onnxruntime, record) | +9.88 MB |
  | Common (catalogue in quran.db, code, licences, mistake tone) | +0.64 MB |
  | **One arm64 phone** | **+10.52 MB** (154.83 MB) |
  | `size_check` (all ABIs in base) | +29.73 MB, 169.94 MB against 140.21 MB |

  iOS: the CI `.ipa` artifact grew from 160.18 MB (1.4.0+6) to 170.99 MB (1.4.0+8), so +10.8 MB.
  Both are within the plan's ≈ +11 MB, which the owner approved.
