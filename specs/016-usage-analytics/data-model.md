# Data Model: Usage Analytics

Nothing new is stored in `user.db`. The analytics library keeps its own app-instance id and an
event queue in the app's private storage (or a first-party cookie and IndexedDB on the web).

## UsageScreen (enum)

The fixed screen names of [contracts/usage-events.md](contracts/usage-events.md). Each value's
`wire` name is snake_case.

## UsageSetting (enum)

The fixed setting names of the contract, each with its `wire` name. Values are passed as an
`Enum` (its `name`), an `int`, a `bool`, or a catalogue id (reciter, athan sound).

## UsageSink (interface)

- `void screen(String name)`
- `void event(String name, Map<String, Object> parameters)`

Implementations: `NoUsage` (tests, before start, debug), `FirebaseUsage` (phones and web). The
`Usage` facade is the only caller; it owns the names and parameters.

## FirebaseUsage state

| State | Meaning |
| --- | --- |
| `waiting` | Before the first frame: events are queued (at most 50; older ones dropped) |
| `on` | Firebase ready, collection enabled: queue flushed, events sent as they come |
| `off` | Not a release build, not get.mthani.app on the web, or Firebase failed: queue dropped, events ignored |

Transitions: `waiting → on` after `firebaseReady()` succeeds in a release build; `waiting → off`
otherwise. No transition back.

## Relationships

- Shares the Firebase app with announcements (`firebaseReady()`), never their push token.
- Reads `ReaderPreferences` diffs and prayer settings changes to emit `setting_changed`.
