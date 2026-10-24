# Quickstart: All EveryAyah Reciters and Memorization Mode

How to build, test and check this feature end to end. Design: [plan](./plan.md),
[data model](./data-model.md), [contracts](./contracts/).

## Prerequisites

- Flutter 3.47.7 (pinned).
- **Reference phones** (feature 001): Galaxy A15 (Android 14) and iPhone SE 2nd gen (iOS 15+
  test build). Also an Android 7 emulator (API 24) with 2 GB RAM, for the unsupported-device
  message.
- **Speech test sets** (S1), kept outside the repository because they hold volunteers' voices:
  - **Correct**: at least 10 readers (men and women, varied ages) reciting correctly at least 200
    ayat in total, across short and long ayat.
  - **Mistakes**: the same readers with one deliberate mistake per ayah (missed, wrong or added
    word), at least 200 ayat, with a CSV of `surah, ayah, kind, position`.
  - Volunteers consent in writing. The files stay on the maintainer's machine and are deleted
    after S1 and the release checks.
- Python 3.11 with `sherpa-onnx`'s Whisper export requirements, once, for the model export.
- A free QUL account (qul.tarteel.ai), to download the timing JSON of the 7 QUL surah recitations
  (catalogue ids `minshawy_children`, `mostafa_ismail`, `husary_ijazah`, `bandar_baleela`,
  `khalid_jalil`, `hady_toure`, `salimi`; QUL ids in
  [reciter-catalogue](./contracts/reciter-catalogue.md) › Rows).

## Spikes (before the dependent tasks)

| Spike | What | Pass |
| --- | --- | --- |
| S1 | Tarteel tiny and base (int8) through sherpa-onnx with the matcher, on both phones, over both test sets | Tiny or base: ≥ 95% of correct ayat revealed with no false mistake (SC-004); ≥ 95% of mistakes detected (SC-005); 0 false reveals (SC-006); ≥ 95% of reveals within 1 s (SC-007). Record peak memory and model load time |
| S2 | `sherpa_onnx` 1.13.8 and `record` 7.1.2 added to a branch build; `size_check` on Android; Xcode archive size on iOS | Growth measured and written into Complexity Tracking; whether the unused `cxx-api` library can be excluded |

If S1 fails for both models, stop and report to the owner (spec assumptions). The voice is not
moved online.

## Build the catalogue (once; resumable)

1. From each QUL recitation page, use "Download json" and save the file as
   `tool/sources/qul-recitations/<qul_id>.json`. Add its SHA-256 to `tool/sources.lock.json`.
2. Run:

   ```text
   dart run tool/build_recitation_manifest.dart --skip-existing      # ~3 h the first time
   dart run tool/add_recitations.dart
   dart run tool/verify_quran.dart                                     # unchanged checks still pass
   ```

Expected output: `quran.db: 51 reciters, 5814 surah rows.` A reciter fails the run if any ayah
is missing or, for QUL surah files, any of these fails:
- the CBR check;
- the timing check;
- `range_start + Σ sizes == file length`.

Remove a failed reciter from `tool/recitations.json` and record the reason in research R0 or
R1.

## Export and publish the model (once per model version)

```text
python tool/export_asr_model.py --model tarteel-ai/whisper-tiny-ar-quran --out build/asr/tarteel-tiny-v1
```

1. Upload the four files to the GitHub release `asr-tarteel-tiny-v1`.
2. Paste their sizes and SHA-256 values into `lib/features/memorization/asr_model.dart`.

## Tests

```text
flutter test test/unit test/widget
```

**Unit tests**:
- `recitation_sizes_test`: 004 values unchanged for `husary` and `minshawy`; every row length is
  3 × ayahCount.
- `clip_range_test`: for a `qul_surah` fixture, clips are contiguous, start at `range_start`, and
  end at the file length.
- `mp3_frames_test`: ID3 length, CBR detection (Info/Xing, mixed bitrates rejected), and the
  frame start found at 44.1 kHz with padding and at 48 kHz.
- `ayah_fetcher_range_test`: against a localhost server, a `206` with the right `Content-Range`
  is accepted; a `200`, a wrong range or a wrong total length is retried and never saved; no
  mirror is tried; the basmala item is skipped for `basmalaInAyah1`.
- `reciter_search_test`: Arabic normalisation, partial names, English case.
- `recitation_matcher_test`: rules 1–9, plus the property test over all 6,236 ayat.
- `memorization_score_test`: User Story 3's example scores 72, weakest-outcome precedence, and
  "—" when nothing was reached.
- `memorization_controller_test`: with the fake recogniser, covers phases, pause reasons, Q1
  resume from the wrong word, hint and reveal, and end mid-ayah.
- `asr_model_test`: resume, hash mismatch and delete, against a localhost server.
- `memorization_privacy_test`: the import rule of R16.

**Widget tests**:
- `reciter_list_test`: 51 rows, search, and the chosen reciter in view.
- `range_sheet_test`: defaults from a page and from a long-press; `to < from` is impossible.
- `hidden_page_test`: hidden words are not painted, layout is identical before and after a
  reveal, and the semantics say "hidden".
- `memorization_bar_test`, `result_screen_test`.

**Goldens**: page 50 with ayat 3–5 hidden, 3 revealed, 4 hinted, and a mistake marker, in day
and night.

## Device scenarios

Run each on both reference phones unless marked.

**Reciters**

| # | Scenario | Expected |
| --- | --- | --- |
| Q-1 | Open the reciter list from the player; search «عفاسي», then "alafasy" | 1 row each time, filtered within 100 ms; 60 fps scrolling over 51 rows (SC-002) |
| Q-2 | Pick Alafasy; play page 50 across the page break; lock the phone | Feature 004 behaviour unchanged (US1-4) |
| Q-3 | **V-1**: for every new reciter, play 1:1, 2:1, 9:1 and 2:286. Owner checks the Arabic names | Right voice and style; no doubled basmala; names correct. Fix `recitations.json` if not |
| Q-4 | Download Al-Mulk for 5 random reciters; airplane mode; play each | 0 skipped or repeated ayat (SC-003) |
| Q-5 | Install 1.4.0 with El-Minshawi chosen and Al-Kahf downloaded; update | Choice and download kept (FR-006) |
| Q-6 | Bandar Baleela and Hady Toure (QUL surah clips): play page 50 across the page break, then Al-Kahf 1–20 | Highlight moves ayah by ayah in time with the voice; page turns; no skipped, repeated or cut words at ayah boundaries |
| Q-7 | For all 7 QUL surah reciters: play the start of Al-Baqarah, At-Tawbah and An-Nas | Basmala heard once inside ayah 1 (none in At-Tawbah); no separate basmala item; gaps at boundaries ≤ 150 ms by ear and in the player log |
| Q-8 | Download Al-Mulk for Khalid Al-Jalil; airplane mode; play; then delete | Plays offline with 0 skipped ayat; storage freed; the size shown before download matches the saved size |

**Memorization**

| # | Scenario | Expected |
| --- | --- | --- |
| Q-10 | First open: Memorize on page 50 | Range sheet with page default; model download row; mobile-data prompt on cellular |
| Q-11 | Download the model, then airplane mode; start Al-Fatiha 1–7; recite correctly | Explainer, then system prompt; each ayah appears ≤ 1 s after finishing; result 100 |
| Q-12 | Al-Ikhlas: skip a word in ayah 2, carry on from it; in ayah 3 tap Next word, finish | Mistake signalled (vibration), ayah 2 appears after the correction; one hinted word in 3; score (1 + 0.5 + 0.25 + 1) / 4 = 69 |
| Q-13 | Al-Baqarah 282 (long ayah): make a mistake in the first line | Signalled after the next pause, not at the end of the ayah |
| Q-14 | Recite with the isti'adha and basmala first; repeat a phrase; pause mid-ayah | No mistakes |
| Q-15 | Play a reciter from another phone next to the mic, without reciting | Nothing revealed (SC-006) |
| Q-16 | Incoming call, app to background, unplug headset mic, 30 s silence | Paused with the right reason; mic indicator off; resume works |
| Q-17 | Mistake alert set to Sound with the phone on silent; then to None | No tone on silent; mark on screen still shown; None gives only the mark |
| Q-18 | Deny the mic; deny permanently | Message; Open Settings opens the app's settings page |
| Q-19 | API 24 emulator, 2 GB RAM | "Memorization isn't available on this device"; reading and listening unaffected |
| Q-20 | VoiceOver and TalkBack: run Q-12 | Hidden ayat read as hidden; reveals and mistakes announced; all controls labelled |
| Q-21 | Largest system font, night theme | Bar and result readable; no clipping; tokens visible |
| Q-22 | Settings › Downloads: delete the model | Storage freed within 1 s; the range sheet asks to download again |
| Q-23 | During a session: check with the OS privacy indicator and a network monitor (Charles or Android's data-usage per app) | Mic indicator only while listening; **0 bytes** sent during a session (FR-019) |

**Usability** (SC-009): 10 readers who memorise start a session on ayat they choose, finish it
and read their score with no help. Target: 9 of 10.

## Performance and size gates

- `integration_test/paging_perf_test.dart` with `WITH_MEMORIZATION`: 60 fps paging with a session
  listening (SC-010).
- Cold start is unchanged (≤ 2 s). The model and recogniser load only when a session starts.
- `dart run tool/size_check.dart`: growth reported in the PR with its parts (R7). The owner
  approves it in review (Principle IV).

## Release checklist

- [ ] D4 request (Quran.com Foundation) widened to 43 EveryAyah and 5 quranicaudio recordings,
      and sent.
- [ ] D2 request (QUL / Tarteel) widened to the QUL timings and the 3 Tarteel-hosted recordings,
      and sent. Release is gated on both; a refused recording's row is removed.
- [ ] About screen credits QUL and EveryAyah (FR-007).
- [ ] `docs/licences.md`: Tarteel model, sherpa-onnx, onnxruntime, `record`; licence texts in the
      app's licences page.
- [ ] `docs/store/privacy.md`, privacy policy, App Privacy and Data safety answers updated (R16).
- [ ] Info.plist microphone text in Arabic and English.
- [ ] S1 results and the chosen model recorded in research R8.
- [ ] Test-set recordings deleted.
