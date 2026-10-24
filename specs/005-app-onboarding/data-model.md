# Data Model: Onboarding

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)

The feature adds one stored value. Everything else is transient state or fixed content.

## Stored

### Preference `onboarding_done` (user.db › `preferences`)

| Key | Value | Default | Meaning |
| --- | --- | --- | --- |
| `onboarding_done` | `'true'` / `'false'` | `false` when the row is missing | The first-run onboarding was finished or skipped (FR-002). |

- Parsed in `UserRepository._parsePreferences` like `keep_screen_on`: anything but `'true'` is
  `false`. Written by `savePreferences` with the other keys.
- Exposed as `ReaderPreferences.onboardingDone` (`bool`, default `false`), with `copyWith`.
- **No schema change**; `user.db` stays at version 1.

**Removed**: `ReaderPreferences.controlsHintShown` and the `controls_hint_shown` key (research
R2). Existing rows are left in place and ignored.

**Values the onboarding sets**: these preferences already exist, from features 001 and 004, and
keep their keys, ranges and defaults.

| Preference | Values | Default |
| --- | --- | --- |
| `language` | `system`, `ar`, `en` | `system` |
| `theme` | `system`, `day`, `night` | `system` |
| `layout` | `mushaf`, `flowing` | `mushaf` |
| `flow_font_size` | 18–34 | 24 |
| `reciter` | a reciter id in `quran.db` | `husary` |

## Transient

### OnboardingStep (enum)

```text
language · theme · layout · textSize · reciter          (kind: setup)
turnPages · controls · ayahActions                       (kind: gesture)
surahIndex · search · player · settings                       (kind: button)
```

### Step sequence

A pure function of the current state. It is recomputed whenever its inputs change: the layout
can change on the layout step, which adds or removes `textSize`.

```text
steps(flowing, hasReciters, hasPlayer, replay) =
  (replay ? [] : [language, theme, layout] + (flowing ? [textSize] : []) + (hasReciters ? [reciter] : []))
  + [turnPages, controls, ayahActions]
  + [surahIndex, search] + (hasPlayer ? [player] : []) + [settings]
```

| Input | Source |
| --- | --- |
| `flowing` | `reader.preferences.layout == ReadingLayout.flowing` |
| `hasReciters` | `RecitationScope` present and `quran.reciters` not empty |
| `hasPlayer` | `RecitationScope` present |
| `replay` | started from Settings |

**Progress shown to the reader**:
- setup steps: "Step *i* of *n*", counting setup steps only;
- tour stops (gesture and button): "*i* of *n*", counting tour stops only.

On a typical first run, setup has 4 steps (Mushaf layout) or 5 (flowing), and the tour has 7
stops.

**Validation**: The layout step is the only place the layout can change during setup. When it
changes there, the current step stays `layout`, and the step after it becomes `textSize`
(flowing) or the next one (Mushaf).

### OnboardingController state

| Field | Type | Notes |
| --- | --- | --- |
| `step` | `OnboardingStep?` | null: not onboarding. At launch it is `language` if `!onboardingDone`, otherwise null. |
| `replay` | `bool` | true when started from Settings. |
| `phase` | derived | `none` (step null), `setup`, `gestures` or `buttons`, from `step`'s kind. |
| `holdsReader` | derived | `phase == buttons`. Views skip page jumps while it is true. |

**State transitions**:

```text
           launch, onboardingDone == false                    Settings › See the tour again
                       │                                                 │
                       ▼                                                 ▼
   ┌──── setup (language → … → reciter) ── next ──▶ gestures (turnPages → controls → ayahActions)
   │            ▲            │                         │        ▲
   │          back         skip                      next     back
   │            │            │                         ▼        │
   │            └────────────┤                   buttons (surahIndex → search → player → settings)
   │                         │                         │
   │                         ▼                       done / skip
   └──────────────────▶  none ◀────────────────────────┘
                 (first run: onboardingDone := true; replay: unchanged)
```

- `next` on the last step does the same as `done`.
- `back` on the first setup step is not handled by the controller: the system back leaves the
  app (Android), and `onboardingDone` stays false.
- `back` on the first replay stop does the same as `skip`.
- Leaving the `reciter` step by any route calls `recitation.stopPreview()`.

### ReciterPreview (RecitationController)

| Field | Type | Notes |
| --- | --- | --- |
| `reciterId` | `String` | the reciter whose sample is loading or playing |
| `status` | `loading` · `playing` · `unavailable` | `unavailable`: offline, failed, or not started within 5 s |

```text
null ──previewReciter(r)──▶ loading ──file ready──▶ playing ──WindowCompleted / stopPreview()──▶ null
                               │
                               └──offline / failure / 5 s──▶ unavailable ──stopPreview() / another sample──▶ …
```

- Never persisted.
- Not created while a `RecitationSession` exists.
- Never creates one.

## Fixed content

### Tour stop

| Field | Notes |
| --- | --- |
| `step` | one of the gesture or button steps |
| title, body | strings in Arabic and English. `turnPages` and `controls` have separate Mushaf and flowing bodies ([onboarding-ui](./contracts/onboarding-ui.md) › Strings). |
| visual | gesture stops: a `TourIllustration` variant. Button stops: the target key in `TourTargets`. |
