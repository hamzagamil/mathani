# Contract: Recitation Playback

The behaviour of `RecitationController`, the player and the system media integration. Research:
R2, R3, R4, R5, R9. Item order: [data-model › Recited item order](../data-model.md#recited-item-order).

## `RecitationController` (ChangeNotifier, provided by `RecitationScope`)

It is created at app start, next to `ReaderController`. It holds no audio resources until the
first `play`.

| Member | Behaviour |
| --- | --- |
| `session` | `RecitationSession?` (data model). `null` means no bar is shown. |
| `playFromPage(int page)` | Starts at the first ayah that **begins** on `page`. On page 1 that is 1:1. A page with no ayah starting on it starts at the first ayah shown on it. |
| `playFrom(AyahRef ref)` | Starts at `ref`, or at its basmala when `ref.ayah == 1` and the surah has one (FR-006, FR-008). |
| `pause()`, `resume()` | Update the state at once, before the platform call returns (FR-011). |
| `next()`, `previous()` | Move by the item order. They work while paused (and stay paused). Taps within 300 ms are merged. |
| `stop()` | Ends the session. Clears the highlight, hides the bar, stops the foreground service and cancels prefetch (FR-015). |
| `setReciter(String id)` | Saves the preference. During a session: resolves the **current item** with the new reciter, then restarts that item from its start. If that fails with `offline`, the session keeps its reciter and shows the message «{name} غير منزّل لهذه السورة» / "{name} isn't downloaded for this surah", and the preference is set back. |
| `returnToRecitation()` | Calls the follow jump (`_followJump`, see Following), then sets `following = true`. |
| `retry()` | Retries the item that failed. |

Starting a new `play*` while a session exists replaces the item and keeps the reciter.
`following` becomes `true` on every `play*`.

## States

```text
          play*                 file ready                 item ends
 (none) ───────► loading ──────────────────► playing ─────────────────► loading(next) / playing(next)
                   │  ▲                       │   ▲                       (next already ready:
          offline/ │  │ retry                 │   │ resume                  no state change, no gap)
       fetchFailed │  │                pause  ▼   │
                   ▼  │                     paused
                  error                                  114:6 ends
                                                  playing ─────────────► ended ──(3 s or stop)──► (none)
 any ──stop──► (none)
```

- **loading**: the current item's file is not resolved yet. The bar shows a spinner in place of
  the play button, and the text is still highlighted. If it takes longer than 15 s → `error
  fetchFailed`.
- **error**: playback is stopped on that item and **never moves past it** (FR-020). The bar shows
  the message and a Retry action. `next` and `previous` still work.
- A reconnect does not resume by itself. The reader taps Retry or Play (no surprise audio).

## Sequencing and the playlist

- The player's playlist is a sliding window: `[previous?, current, next ≤ 3]`, made only of
  resolved files. Each entry is tagged with its `RecitedItem`.
- When the player moves to the next entry, `session.item` changes in the same frame, and the
  fetcher refills the window.
- If the current entry ends and the next is not in the window, the player waits on the
  **current** item in `loading(next)` until the next file resolves. It never skips (FR-007).
- `next`, `previous`, `playFrom` and `setReciter` rebuild the window around the new current item.

## Following (FR-012 to FR-014)

- When `session.item` changes and `following` is true, the controller calls
  `reader.jumpTo(itemRef, highlight: false)` and saves `followSerial = reader.jumpSerial`.
  - Mushaf layout: the page changes only if the item is on another page. For a basmala item, that
    is the page holding the surah's basmala line in the active lettering.
  - Flowing layout: `FlowingView` handles a follow jump with `ensureVisible`. It scrolls only if
    the ayah is not fully visible, and places it at about one third from the top.
- `following` becomes false (playback continues) on any of these:
  - **Mushaf layout**: the page view settles (`onMushafPageShown`) on a page other than
    `recitedPage(item)`. For a basmala item that is the page holding its basmala line in the
    active lettering, which in the printed edition can be the page before ayah 1. A follow jump
    lands on that page, so it never triggers this.
  - **Flowing layout**: a scroll the reader starts, meaning a `ScrollStartNotification` with
    non-null `dragDetails`. `FlowingView` reports it with `recitation.onReaderScroll()`. Scrolls
    from `ensureVisible` have no drag details.
  - **Any layout**: `reader.jumpSerial` changes to a value the controller didn't produce (index,
    search, go-to, bookmarks). The controller keeps `_lastSeenSerial` and compares it on each
    reader notification.
- A layout switch also increments `jumpSerial` (`updatePreferences`). The controller ignores it
  when `preferences.layout` changed in the same notification, and re-issues a follow jump so the
  new layout opens on the recited item.
- Layout, language, theme and lettering changes keep `following` as it was (spec edge case).
- A follow page turn does not hide the reader controls. `MushafView` skips `onPageTurned` only
  for the page change caused by its own follow jump (a flag set around that `jumpToPage`), never
  for swipes.
- Every follow jump goes through one private `_followJump(item)`: it gets `recitedPage(item)`,
  calls `reader.jumpTo(item.ref, highlight: false)`, or `reader.jumpToPage(page)` for a basmala
  on another page, and records `followSerial`. Item changes, `returnToRecitation()`, the
  layout-switch re-jump and the return from background all use it.

## Highlight

- `RecitationController.recited` returns `RecitedItem?`. It is null when there is no session or
  the session has `ended`.
- The Mushaf renderer gets a third highlight, `recited`, drawn with `palette.recited` behind the
  words of that ayah, or the whole basmala line for a basmala item. Precedence when they overlap:
  selection > jump highlight > recited.
- The flowing view paints the ayah block's background with `recited`, and the basmala row for a
  basmala item.
- Repaint only when `recited` changes (once per ayah). It must not affect paging at 60 fps
  (SC-006).

## Audio session and interruptions (FR-017)

- `AudioSession.configure(AudioSessionConfiguration.music())` before the first play.
- `just_audio` with `handleInterruptions: true`:
  - Phone call, Siri or an alarm: pause, then resume when the interruption ends, if the platform
    says to resume.
  - Another app starts audio: pause, with no automatic resume.
  - Headphones or Bluetooth disconnect (`becomingNoisy`): pause, with no automatic resume.
- The system volume is never changed.

## System media controls (`audio_service`) (FR-015, FR-016)

- `AudioService.init` is called on the first `play`, not at app start (Principle III). Android
  notification channel: `app.mathani.recitation`, named «التلاوة» / "Recitation".
- `MediaItem` per item:
  - `title`: «سورة الملك · ١٢» / "Al-Mulk · 67:12". For a basmala: «سورة الملك · البسملة» /
    "Al-Mulk · Basmala".
  - `artist`: reciter name in the interface language. `album`: «مثاني» / "Mathani".
  - `artUri`: the app icon, bundled. `duration` from the player.
- Controls: previous, play/pause, next. Android compact view has all three. Stop: the
  notification's dismiss and `stop` both call `stop()`.
- Handler callbacks call the same controller methods as the bar, so behaviour is identical.
- `androidStopForegroundOnPause: true`. The service stops on `stop()` and when the session ends.
- On returning to the app, `session.item` is current. If `following` is true, the reader shows its
  page (User Story 3, scenario 3) because the follow jumps happened while in the background.

## End and lifecycle

- After 114:6 the session is `ended`: the bar shows «انتهت التلاوة» / "Recitation finished" for
  3 s, then the session ends.
- The app process ending (killed by the system) loses the session. On the next launch nothing
  plays (spec edge case).
- The session never starts by itself: no autoplay at launch, on reconnect or on headphones
  connecting.
