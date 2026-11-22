# Contract: Widget Snapshot and the `app.mathani/widgets` Channel

Fields and rules: [data-model.md](../data-model.md). This file fixes the wire format and the
channel calls.

## Channel `app.mathani/widgets` (Dart → native)

| Method | Arguments | Result | Native behaviour |
| --- | --- | --- | --- |
| `update` | `{ "snapshot": String (JSON), "watch": String (JSON) }` | `null` | Store `snapshot`. Reload widgets **only if** its SHA-256 differs from the stored one. Send `watch` to the watch side (contracts/watch-sync.md). Android: also reschedule the redraw alarms. |
| `placed` | none | `List<String>` of kinds (`prayer`, `quran`, `khatma`) currently on the phone | iOS: `WidgetCenter.getCurrentConfigurations`. Android: `AppWidgetManager.getAppWidgetIds` per provider. |
| `clear` | none | `null` | Remove the stored snapshot and reload. This leaves the not set up state; used when the app's data is reset. |

The web build implements nothing (`home_widgets_web.dart` is a no-op). `MissingPluginException`
is ignored in Dart.

## Storage

| Platform | Where | Key |
| --- | --- | --- |
| iOS app + widget extension | `UserDefaults(suiteName: "group.com.mthani.app")` | `widgetSnapshot` (String), `widgetSnapshotHash` |
| Android phone | `SharedPreferences("mathani_widget_snapshot")` | `snapshot`, `hash` |

## JSON (v1) example (shortened)

```json
{
  "v": 1,
  "madeAtUtc": 1795412400000,
  "lang": "en",
  "rtl": false,
  "labels": {
    "next": "Next", "inPrefix": "in ", "inSuffix": "",
    "todayWirdDone": "Today's wird is done", "continueReading": "Continue reading",
    "startReading": "Start reading", "setPlace": "Set your place in Prayer Times",
    "setPlaceWatch": "Set a place in Mathani on your phone",
    "openToUpdate": "Open Mathani to update", "khatma": "Khatma", "noKhatma": "No khatma",
    "a11yNext": "{name} at {time}, {left}"
  },
  "prayer": {
    "place": "Cairo",
    "validUntilUtc": 1796097660000,
    "days": [{ "startUtc": 1795384800000, "label": "Today" }],
    "entries": [
      { "kind": "fajr", "atUtc": 1795403100000, "name": "Fajr", "time": "4:45 AM" },
      { "kind": "dhuhr", "atUtc": 1795427400000, "name": "Dhuhr", "time": "11:30 AM" }
    ]
  },
  "quran": {
    "mode": "wird",
    "title": "Today's wird",
    "line1": "From Al-Baqarah 142",
    "line2": "to Al-Baqarah 202",
    "progress": { "percent": 41, "pagesRead": 248, "pagesTotal": 604,
                  "text": "41% · 248 of 604 pages", "todayRead": false, "paused": false },
    "link": "mathani-widget://khatma/read"
  }
}
```

## Validation (both sides)

- `entries` is ascending with unique `atUtc`. Dart asserts this; native readers that find it
  broken show the not set up state rather than wrong times.
- The snapshot is at most 16 KB. Strings are within the lengths in data-model.md.
- Unknown fields are ignored (forward compatible within `v: 1`).
