# Contract: Phone → Watch Sync

The watch copy (data-model.md › WatchCopy) is JSON, at most 16 KB, built by Dart and passed as
`watch` in the `update` channel call (widget-snapshot.md). The phone never receives anything back.

## Apple Watch (WatchConnectivity)

| Step | Side | Call |
| --- | --- | --- |
| Activate | iPhone `AppDelegate`, at launch | `WCSession.default.activate()` when `WCSession.isSupported()` |
| Send latest | iPhone, on `update` | `updateApplicationContext(["watch": json])` when `isPaired && isWatchAppInstalled` |
| Prompt complication | iPhone, on `update` when `prayer` or `khatma` changed and `isComplicationEnabled` | `transferCurrentComplicationUserInfo(["watch": json])`; skipped when `remainingComplicationUserInfoTransfers == 0` |
| Receive | Watch app `WCSessionDelegate` (`didReceiveApplicationContext`, `didReceiveUserInfo`) | Keep it if `madeAtUtc` is newer than the stored one; write it to `UserDefaults(suiteName: "group.com.mthani.app.watch")`; `WidgetCenter.shared.reloadAllTimelines()` |
| Watch launch | Watch app | Reads `receivedApplicationContext` if newer than the stored copy |

## Wear OS (Wearable Data Layer)

| Step | Side | Call |
| --- | --- | --- |
| Send latest | Phone `WearSync`, on `update` | `PutDataMapRequest.create("/mathani/widgets")`, with `watch` = json and `madeAtUtc`, `.setUrgent()`, then `DataClient.putDataItem`. Skipped when the phone has no Play services. |
| Receive | Watch `SnapshotListenerService : WearableListenerService`, `onDataChanged` for path `/mathani/widgets` | Keep it if newer; store it in `SharedPreferences("mathani_watch_copy")`; `ComplicationDataSourceUpdateRequester.requestUpdateAll()` for both sources; `TileService.getUpdater(ctx).requestUpdate(PrayerTileService::class.java)` |
| Watch launch | Wear app or a service with no stored copy | `DataClient.getDataItems(Uri("wear://*/mathani/widgets"))` to read the last item |

Manifest (wear): the listener has an intent filter for `com.google.android.gms.wearable.DATA_CHANGED`
with `wear` scheme and path prefix `/mathani/widgets`.

## Guarantees

- Delivery is eventual. The spec target is ≤ 15 minutes after the watch is next in range (FR-019,
  SC-005).
- The watch works from its stored copy for the full horizon (FR-018). It never computes times.
- Nothing about group khatmas or bookmarks is in the copy (FR-003).
