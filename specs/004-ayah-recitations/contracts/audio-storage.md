# Contract: Audio Fetching, Cache and Downloads

How ayah files reach the device. Research: R5, R6, R7, R8. Data: [data-model](../data-model.md).

## Paths

| Use | Path |
| --- | --- |
| Recent cache | `getApplicationCacheDirectory()/recitations/<reciter>/<SSS><AAA>.mp3` |
| Downloads | `getApplicationSupportDirectory()/recitations/<reciter>/<SSS>/<AAA>.mp3` |
| Downloaded basmala | `getApplicationSupportDirectory()/recitations/<reciter>/basmala.mp3` |
| In progress | the target path + `.part` |

iOS: the downloads directory is marked `isExcludedFromBackup`. A `.part` file is never played,
and stale `.part` files are deleted at startup.

## Resolve: `AyahFetcher.resolve(reciter, item) → File`

The player only ever receives a `File` that passed `valid()`, which means it exists and its
length equals the catalogue `bytes` (for 1:1 when the item is a basmala).

1. If the downloaded file (or `basmala.mp3`) is valid, return it.
2. If the cache file is valid, touch its modification time and return it.
3. If `networkState() == none`, throw `offline`.
4. Otherwise `GET` the primary URL into the cache `.part` with a 15 s connect and idle timeout.
   On failure or a size mismatch, try once on the mirror. Then rename the file and return it, or
   throw `fetchFailed`.

Resolve calls for the same file share one in-flight request. Prefetch (3 items ahead) is
cancelled when the session's position or reciter changes.

## Cache limit

After each write to the cache, if its total exceeds **100 MB**, delete the least recently
modified files until it is at or below 90 MB. The files of the current and next 3 items are never
deleted. Settings › "Clear recent recitations" deletes the whole cache directory (except files
in use) and shows the space freed. It never touches downloads (FR-034).

## Downloads: `DownloadQueue`

| Operation | Behaviour |
| --- | --- |
| `sizeOf(reciter, surah)` | `surahDownloadBytes` minus the valid files already saved. No network. |
| `enqueue(reciter, surah)` | Preconditions are checked by the UI (see below). Adds the surah to the FIFO queue. If the surah is already complete or queued, does nothing. |
| `cancel(reciter, surah)` | Removes the surah from the queue, or stops it. Keeps valid files, so the surah shows as `stopped` (partial). |
| `delete(reciter, surah)` | Cancels the surah, deletes its directory, and updates state at once (FR-033, SC-012). |
| `deleteAll(reciter)` | Removes everything under `recitations/<reciter>`, including `basmala.mp3`. |
| `states` | `ValueListenable<Map<(reciter, surah), SurahDownload>>`, built by scanning on first use (on a background isolate), then updated in memory. |

Rules:
- **Order**: the files of a surah download in ayah order, with `basmala.mp3` first if needed. At
  most **2** requests run at a time across the whole queue. A recitation's prefetch always takes
  priority over downloads.
- **Already cached**: an ayah in the recent cache is copied, not downloaded again.
- **Progress**: `savedBytes / totalBytes`, updated at most 4 times a second.
- **Interruptions**: on a network loss, a failure after the mirror, or `ENOSPC`, the surah goes
  to `stopped` and the queue stops, with a reason the UI shows. The reader resumes it.
  `AppLifecycleState.resumed` restarts a queue that was stopped only by suspension.
- **Damage**: a file that fails `valid()` at play time is deleted, and its surah becomes partial
  (edge case "damaged recording").

## Preconditions (checked in the UI before `enqueue`)

1. `networkState() == none`: the message «لا يوجد اتصال بالإنترنت» / "No internet connection".
   The download does not start.
2. `freeBytes() < sizeOf + 50 MB`: the message «المساحة غير كافية: تحتاج {size}» / "Not enough
   storage: {size} needed". The download does not start.
3. `networkState() == metered`: a confirmation dialog «أنت على بيانات الجوال. تنزيل {size}؟» /
   "You're on mobile data. Download {size}?" with Download / Cancel.

## Platform channel `app.mathani/device`

| Method | Returns | Android | iOS |
| --- | --- | --- | --- |
| `networkState` | `'none' \| 'unmetered' \| 'metered'` | `ConnectivityManager` active network capabilities: none if there is no network or it is not `VALIDATED`; metered unless `NOT_METERED` | `NWPathMonitor` (started at launch): `.satisfied`? (`isExpensive \|\| isConstrained` → metered) : none |
| `freeBytes` | int | `StatFs(filesDir).availableBytes` | `volumeAvailableCapacityForImportantUsage` of the support directory |
| `excludeFromBackup(path)` | void | no-op | sets `isExcludedFromBackup` on the directory |

Tests use a fake channel. When the channel is unavailable, `networkState` is `unmetered` and
`freeBytes` is `1 << 40`.
