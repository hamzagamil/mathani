# Research: Ayah-by-Ayah Recitations

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-24

Measurements were taken on 2026-10-24 from the Windows development machine with `curl` HEAD
requests against the live servers, and from the pub.dev API.

## R1. Where the recordings come from (FR-001 to FR-003, FR-024)

**Finding**: EveryAyah (https://everyayah.com, run by the Quran.com Foundation and served from
BunnyCDN) is the standard source of ayah-by-ayah Murattal audio. Quran.com uses it for its own
apps: its API (`/api/v4/recitations/6/by_ayah/1:1`) points Al-Husary at
`mirrors.quranicaudio.com/everyayah/Husary_64kbps/001001.mp3`. For El-Minshawi it points at
`verses.quran.com/Minshawi/Murattal/mp3/001001.mp3`, which is byte-identical to EveryAyah's
`Minshawy_Murattal_128kbps` file (79,540 bytes).

| Recording | Folder | Bitrate | Whole Quran | Al-Baqarah | Al-Kahf | Al-Mulk | Al-Ikhlas |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Al-Husary, Murattal | `Husary_64kbps` | 64 kbps | 1.23 GB | ≈ 96 MB | 22.9 MB | 5.3 MB | 0.2 MB |
| Al-Husary, Murattal | `Husary_128kbps` | 128 kbps | 2.47 GB | ≈ 190 MB | ≈ 45 MB | 10.7 MB | 0.4 MB |
| El-Minshawi, Murattal | `Minshawy_Murattal_128kbps` | 128 kbps | 1.67 GB | ≈ 131 MB | 33.5 MB | 6.6 MB | 0.2 MB |

Whole-Quran sizes come from each folder's `000_versebyverse.zip`. Surah sizes are sums of each
ayah's `Content-Length`. Figures marked ≈ are extrapolated because a few requests were throttled
(see R6). El-Minshawi has no lower bitrate on EveryAyah (`Minshawy_Murattal_64kbps` and `_48kbps`
return 404).

URL scheme: `<base>/<SSS><AAA>.mp3` with zero-padded surah and ayah, for example
`https://everyayah.com/data/Husary_64kbps/002255.mp3`. Responses are `audio/mpeg` with
`Accept-Ranges: bytes`, `Cache-Control: max-age=25600000` and `Access-Control-Allow-Origin: *`.
Files were last modified in January 2023, so the set is stable.

**Decision**: use EveryAyah, with `mirrors.quranicaudio.com/everyayah` as the fallback host:
- **Al-Husary**: `Husary_64kbps`. This is the file Quran.com serves, at half the data of 128 kbps.
  Speech at 64 kbps is clear, and it halves download sizes (Al-Baqarah ≈ 96 MB, not ≈ 190 MB).
- **El-Minshawi**: `Minshawy_Murattal_128kbps`, the only Murattal bitrate available.

**Licence**: EveryAyah's site states no terms. Its only contact is the Quran.com help desk
(https://quran.zendesk.com/hc/en-us). Permission to stream and download these files in a free
app, and the attribution wording, is a new dependency **D4** in `docs/licences.md`, with a
request draft in `docs/permissions/everyayah-request.md`. The spec says the feature does not ship
without it. While D4 is pending, development and testing use the same URLs.

**Alternatives considered**:
- *QUL (qul.tarteel.ai) recitation datasets*: the same recordings plus word timings. Word timing is
  out of scope, and QUL's licence is already unconfirmed (D2).
- *Hosting a copy ourselves*: we would control the URLs, but it needs the same permission, plus
  1.2–2.5 GB per reciter of storage and egress paid by the project. Spec 002 dropped self-hosting
  for the same reason. We can revisit if D4 requires it.
- *Al-Husary at 128 kbps*: no audible benefit for speech at double the data and storage.

## R2. Basmala and file conventions (FR-008)

**Finding**: EveryAyah has no `<SSS>000.mp3` for surahs 2–114 (`002000.mp3` is 404).
`001000.mp3` exists (43 KB) and is the isti'adha, not the basmala. Apps that use EveryAyah play
the reciter's **Al-Fatiha ayah 1** (`001001.mp3`, the recited basmala) before ayah 1 of every
surah except At-Tawbah.

**Decision**: the basmala item is the reciter's `001001.mp3`. It plays before ayah 1 of surahs 2–8
and 10–114. In Al-Fatiha it is ayah 1 itself. At-Tawbah has none.

**Check (V-1)**: confirm by listening that `002001.mp3` for both reciters does **not** already
begin with the basmala. If it did, the basmala would play twice. `002001` is 80 KB (≈ 10 s) for
Al-Husary 64 kbps, which fits «الم» recited with full madd. Quickstart Q-3 confirms this on 10
surahs per reciter.

## R3. Audio engine (FR-007, FR-009, FR-011, FR-017)

**Decision**: **`just_audio` 0.10.6** (published 2026-06-29). It uses ExoPlayer/Media3 on Android
and AVQueuePlayer on iOS, supports both of our minimum OS versions, and its playlist preloads and
plays the next item without a gap. It depends on `audio_session` 0.2.4, which handles phone
calls, other apps' audio and headphone unplugging. `handleInterruptions: true` pauses on all of
them, resumes after a transient interruption, and stays paused after unplugging (FR-017).

The audio session is configured with `AudioSessionConfiguration.music()`: long-form playback
that follows the system media volume. On iOS this is the `playback` category, which, like other
Quran and podcast apps, plays with the silent switch on.

**Gapless (FR-009)**: the controller keeps a short **sliding playlist**: the previous item, the
current one and up to three ready next items. It appends items as their files are ready and trims
old ones. ExoPlayer and AVQueuePlayer preload the next item, so the added gap stays within
FR-009's 150 ms (measured in Q-4).

**Alternatives considered**:
- *`audioplayers`*: smaller on Android (it uses MediaPlayer), but it has no gapless playlist,
  so each ayah switch adds a decoder start, typically 100–300 ms.
- *Platform channels written by us*: two native players, session and interruption handling.
  That is far more code than the dependency, against Principle V.

## R4. Background playback and lock screen (FR-015, FR-016)

**Decision**: **`audio_service` 0.18.19** (2026-06-29). One `AudioHandler` wraps the player and
forwards play, pause, next, previous and stop from the lock screen, notification, headset buttons,
Bluetooth, CarPlay and Android Auto to `RecitationController`. That way next and previous follow
our ayah order, not the playlist window. It publishes a `MediaItem` for each ayah: the title is
the surah and ayah number in the interface language, the artist is the reciter, and the artwork
is the app icon.

Platform setup:
- **Android**: `MainActivity` extends `AudioServiceActivity`. The manifest adds the
  `AudioService` service (`foregroundServiceType="mediaPlayback"`) and `MediaButtonReceiver`, and
  the permissions `INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `FOREGROUND_SERVICE` and
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK`. These are all install-time permissions with no prompt.
  The media notification is exempt from Android 13's `POST_NOTIFICATIONS` runtime permission,
  so the app still asks for nothing.
- **iOS**: `UIBackgroundModes` = `audio`. Now Playing and remote commands come from
  `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` through the plugin. No permission prompt.

The foreground service starts with playback and stops when playback stops (FR-015: nothing keeps
running once stopped). `androidStopForegroundOnPause: true` lets the system reclaim the service
while paused.

**Alternatives considered**: *`just_audio_background`* is simpler to wire, but it is still
`0.0.1-beta.17` (May 2025), and its next and previous only move within the loaded playlist. It
cannot go back past the sliding window or follow our basmala rules.

## R5. Streaming, prefetch and the recent-ayat cache (FR-018 to FR-021, SC-001)

**Decision**: the player **always plays local files**. A small `AyahFetcher` makes sure the file
for an item exists before the item enters the playlist:
1. If the surah is downloaded (R7), it uses that file.
2. Otherwise it uses the **recent cache** (`<cache dir>/recitations/<reciter>/<SSS><AAA>.mp3`).
3. Otherwise it downloads the file into the cache. It writes to a `.part` file, checks the size
   against the catalogue (R6), then renames it.

The fetcher works up to **3 ayat ahead** of the current one. It never skips: if the next file is
not ready when the current ayah ends, the player waits on that ayah and shows loading. If the
fetch fails twice (primary host, then mirror), playback pauses on that ayah with the retry
message (FR-020).

The cache is LRU, capped at **100 MB**, roughly 7 hours of Al-Husary or 5 hours of El-Minshawi.
It is trimmed after each write, and a Settings action clears it. Downloads (R7) are a separate
directory and never count toward the cap (FR-034).

**Latency (SC-001)**: only the first ayah of a session waits for a whole file. The average ayah
is 197 KB (Al-Husary 64 kbps) or 267 KB (El-Minshawi), about 0.2 s on a 10 Mbps 4G link plus
connection setup. The longest ayah, 2:282, is 2.1 MB and 2.8 MB, about 2–2.5 s. So the 2 s
target holds for well over 95% of starting ayat, and the loading state covers the rest.

**Alternatives considered**:
- *Stream URLs directly in the player*: the first sound arrives sooner on long ayat, but we
  cannot guarantee "never skip" (ExoPlayer and AVQueuePlayer skip or stall on failed items in
  different ways). It also needs a separate cache layer for FR-021.
- *`LockCachingAudioSource`*: still marked experimental in just_audio, and it has different
  failure behaviour on the two platforms.

## R6. Recitation catalogue and integrity (FR-002, FR-028, FR-031, SC-003)

**Finding**: requesting 16 files at once from EveryAyah's CDN gave throttled responses on 2–5%
of requests. At 4 at a time there were no failures in 110 requests.

**Decision**: a build tool, `tool/build_recitation_manifest.dart`, requests every ayah file of
each reciter (6,236 per reciter), 4 at a time with retries. For each it records the `Content-Length`
and checks that the response is `200 audio/mpeg`. It **fails if any ayah is missing**, which is
the automated half of SC-003. Results are written to `tool/sources/recitations/<reciter>.json`,
pinned by hash in `sources.lock.json`. `tool/build_quran_db.dart` loads them into two new tables
in `quran.db` (contract: [recitation-catalogue](./contracts/recitation-catalogue.md)), about 12.5
thousand small rows.

The byte sizes give:
- the exact **download size** of any surah before downloading (FR-028), with no network call;
- a **completeness check** for every cached or downloaded file: a file whose size differs from
  the catalogue is damaged and is never played (FR-031).

**Alternatives considered**:
- *SHA-256 per file*: stronger, but it would mean downloading 2.9 GB to build it and add about
  400 KB to the store download. Size checks catch truncation, the realistic failure mode.
- *Requesting sizes at runtime*: 286 requests before Al-Baqarah's size could be shown, and none
  offline.

## R7. Per-surah downloads (FR-027 to FR-034)

**Decision**: downloads use the same fetcher code with a different target directory:
`<app support dir>/recitations/<reciter>/<SSS>/<AAA>.mp3`. The app support directory is not
cleared by the OS and is excluded from iCloud backup.

**State comes from the disk; no database table.** A surah is:
- **complete** when every ayah file exists with its catalogue size;
- **partial** when some files exist;
- **absent** when none do.

A resumed download therefore fetches only the missing or wrong-size files (SC-011: at most one
ayah of repeated data, the one in progress). The queue lives in memory. After a restart, partial
surahs show "Resume". Checking one surah takes at most 286 `stat` calls; all 114 per reciter are
checked once on a background isolate when the downloads screen opens, then kept up to date
in memory.

- **Concurrency**: 2 files at a time, below the throttling level in R6. While a recitation
  streams, its prefetch comes first.
- **Background**: downloads run in the app's process only. They keep going while the app is open
  and while a recitation keeps the app alive. They pause when the OS suspends the app, and resume
  from the queue when it returns. No background-transfer service is used, per FR-030 and
  Principle IV.
- **Storage check** (FR-028): free space ≥ remaining bytes + 50 MB headroom before starting.
- **Mobile data** (FR-028): if the network is metered, a confirmation shows before the download
  starts.

## R8. Network type and free space (FR-028, SC-008)

**Decision**: one small platform channel, `app.mathani/device`, with two methods:
- `networkState()` returns `none`, `unmetered` or `metered`. Android uses
  `ConnectivityManager.getNetworkCapabilities` (`NET_CAPABILITY_VALIDATED`, `NOT_METERED`). iOS
  uses `NWPathMonitor` (`status`, `isExpensive || isConstrained`), started once and read
  synchronously.
- `freeBytes()`: Android uses `StatFs(filesDir).availableBytes`. iOS uses
  `volumeAvailableCapacityForImportantUsage`.

That is about 40 lines of Kotlin and Swift. `networkState() == none` lets "play" fail within
1 second offline (SC-008) instead of waiting for a socket timeout.

**Alternatives considered**: *`connectivity_plus` plus a disk-space plugin*: two dependencies
(with their own manifests and privacy manifests) for two values. `connectivity_plus` also reports
"mobile" rather than "metered", which is wrong for metered Wi-Fi hotspots.

## R9. Following the recitation in the reader (FR-012 to FR-014)

**Decision**: a new `RecitationController` (a `ChangeNotifier`, beside `ReaderController`)
exposes the recited item: an ayah, or the basmala of a surah. The renderer and flowing view paint
it with a new palette colour, `recited`, using the same per-ayah word-range highlight as selection
and jumps. A basmala item highlights that surah's basmala line.

- **Following**: on each new item, if following is on, the controller calls
  `reader.jumpTo(ref, highlight: false)` and records the resulting `jumpSerial`.
- **Leaving follow mode** (FR-014): following turns off in three cases:
  - in the Mushaf layout, the page view settles on a page other than the recited item's page;
  - in the flowing layout, the reader starts a scroll (a drag, not an `ensureVisible`);
  - in either layout, `jumpSerial` changes to a value the controller didn't produce (index,
    search, go-to, bookmarks).

  Swipes and scrolls don't change `jumpSerial`, so the serial alone can't detect them. A layout
  switch increments the serial too, but the controller recognises it and follows again in the
  new layout. When following is off, the player shows «العودة إلى التلاوة» / "Back to
  recitation", which jumps to the recited item and turns following back on.
- **Flowing layout**: a new `ensureVisible` path. It scrolls only when the recited ayah is not
  fully on screen, and places it a third of the way down, so it doesn't jump on every ayah.

In the printed lettering (spec 002) a surah's header and basmala can sit at the foot of the
previous page. Following uses the page that actually holds the basmala line in the current
lettering.

## R10. Player placement (FR-010)

**Decision**: while a session exists (playing, paused, loading or error), a **recitation bar**
(56 dp plus the bottom safe area) is the reader's bottom bar (`Scaffold.bottomNavigationBar`) in
both layouts, so snack bars float above it rather than covering it. In the
Mushaf layout it stays visible when the tap-to-show controls are hidden. The Mushaf view's
available height shrinks by the bar's height, so `PageGeometry` refits the page **once**, when the
bar appears and when it goes away. On tall phones this only takes from the margins. On short
phones the text block shrinks by at most the bar's share of the height. No Quran text is ever
covered. When the toolbar is shown, it sits above the bar.

**Alternatives considered**:
- *Drawing the player over the page's footer band*: on short phones it would cover the last line.
- *A floating button*: it hides the ayah being recited, and it has no room for the surah and ayah
  or the "back to recitation" action.

## R11. Size and privacy impact (SC-007, FR-023)

**Size**: `just_audio` brings Media3 ExoPlayer on Android. After Android's release
code shrinking that is expected to be about 1–1.5 MB. `audio_service` and `audio_session` add `androidx.media` and Dart code, and
the catalogue tables add about 0.1 MB compressed. iOS uses system frameworks, so it is expected
to grow by less than 0.5 MB. The Android increase is likely just over 1 MB, which **must be called
out in review** (Principle IV, SC-007) with the measured `tool/size_check.dart` result. It is
listed in Complexity Tracking.

**Privacy**: requests go to EveryAyah's CDN with no cookies, account, device ID or analytics, and
the default `User-Agent`. Nothing about the reader is sent beyond what any HTTPS request carries
(IP address, the file requested). The app still collects no data, so the App Store label stays
"Data Not Collected" and Google Play's Data safety form stays "No data collected". However,
`docs/store/privacy.md` must be updated: the app now makes network calls, requests install-time
permissions on Android, and declares the audio background mode on iOS. The published privacy
policy must name the audio host.
