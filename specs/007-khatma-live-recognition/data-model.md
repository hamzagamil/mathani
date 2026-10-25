# Data Model: Khatma Recogniser and Live Word-by-Word Reveal

No database change. Nothing new is persisted except the model files. Session data stays in
memory as in [006's data model](../006-reciters-memorization/data-model.md).

## Recognition model (files)

`<app support>/asr/asr-khatma-v1/`, excluded from backup (006 R9).

| File | Bytes | SHA-256 | Source |
| --- | --- | --- | --- |
| `model.int8.onnx` | 133,342,218 | `2f7be830…88bc88` | Unpacked from `model.int8.onnx.gz` (107,497,463 B, `40c4f173…9c27`) |
| `tokens.txt` | 12,858 | `9b938381…20074` | Written by the export tool |
| `silero_vad.onnx` | 643,854 | `9e2449e1…1fd6` | Unchanged from 006 |

**States** (`AsrModelState`, unchanged): absent → downloading → ready. A partial download or a
checked `.gz` not yet unpacked is `partial`, which resumes.

**Validation**:
- Every download is checked against its pinned size and SHA-256.
- Every unpacked file is checked against its pinned unpacked size and SHA-256.
- A mismatch deletes the file and reports `damaged`.

**Migration**: on each launch, `asr/asr-tarteel-tiny-v1/` and any other version folder is
deleted (FR-004). There are no other traces of the old model: no preference or database row
refers to it.

## Heard / HeardWord (in memory, between isolates)

| Field | Type | Rule |
| --- | --- | --- |
| `Heard.pass` | int | Increases by 1 for each live or pause pass in an app run |
| `Heard.hearing` | `live` \| `pause` | `live` while speech continues; `pause` at a VAD pause or `flush()` |
| `Heard.words` | `List<HeardWord>` | In order; cleaned and normalised; never contains empty text |
| `Heard.windowStart` | int | The anchor the pass heard from; words before it (context) are not sent |
| `Heard.endSample` | int | The last sample index decoded; ≥ every `startSample` |
| `HeardWord.text` | String | `normalizeArabic` of the word with punctuation removed (research R6) |
| `HeardWord.startSample` | int | Session sample index (16 kHz); the start of its first piece − `anchorMargin`; ≥ `windowStart − anchorTolerance` |
| `HeardWord.endSample` | int | Where its last piece was heard; `Heard.endSample − endSample ≥ wordEndGap` marks a finished word |

`Heard` replaces 006's `Segment`. No audio crosses back to the main isolate: only words and
sample indexes do (privacy rule, 006 R16).

## Live follow state (speech isolate, in memory)

| Field | Meaning | Changes |
| --- | --- | --- |
| `anchor` | Sample index the next pass decodes from | `commit(pass, from)` moves it forward (never back). A pause pass sets it to the segment end. `reset()` sets it to now. |
| held audio | Samples from up to `liveContext` before `anchor` to now | Trimmed when `anchor` moves; at most `liveContext` + `maxHeld` + 1 s; cleared by `reset()` |
| `awaitingCommit` | A live `Heard` is waiting for its commit | Set on a live pass; cleared by its commit, a pause pass or `reset()` |
| `lastPassMs` | Wall time of the previous pass | Sets the earliest start of the next live pass |
| `liveSuspended` | Live passes stopped until the next pause | Set when a pass takes over `liveSlowPass` |

**State transitions** for one stretch of speech:

```text
silence ──VAD speech──▶ speaking ──every livePassEvery (paced)──▶ live pass ──Heard(live)──▶ awaiting commit
   ▲                        ▲                                                                  │
   │                        └───────────────────────── commit(pass, from) ◀───────────────────┘
   └──── pause pass: Heard(pause), anchor = segment end ◀── VAD pause or flush()
```

## Matcher additions (pure Dart, in memory)

| Item | Type | Rule |
| --- | --- | --- |
| `Hearing` | enum `live`, `pause` | Replaces `finalSegment` |
| `MatchEvents.lastMatchedToken` | int | Index of the last token matched to a word, forward or back; −1 if none |
| last mistake in the stretch | `(ayah, position)?` | Set when a mistake is declared; cleared after each pause pass (rule 11) |
| live suspect | `(ayah, position)?` and a count | A mistake one live pass found; declared when the next pass finds it too (`livePassesForMistake`); cleared by any pass that does not |
| `MatchEvents.droppedRest` | bool | The rest of the pass was dropped after a mistake, declared or not (rule 11) |

## Word verdicts (unchanged sets, new rule)

006's controller sets stay as they are: range words, revealed words, hinted words and
mistake ayat. The new rule (FR-007) is that **words are only ever added** to the revealed and
hinted sets during a session. The matcher's cursor may move back on a repeat, but that never
hides a word.
