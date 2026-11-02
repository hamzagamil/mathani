# Store Privacy Answers

Mathani collects no data (FR-027). It has no account, no analytics, no crash reporting and no
ads. Bookmarks, reading position and preferences stay in an on-device database that is deleted
with the app.

**Network use (since specs/004, recitations; specs/006, more reciters and memorization).** The
app's only network requests are for recitation audio, after the reader plays a recitation or
downloads a surah, and for the memorization model, once, when the reader downloads it:

- **Hosts**:
  - `everyayah.com` (CDN) and its mirror `mirrors.quranicaudio.com`, for ayah-by-ayah MP3 files;
  - `download.quranicaudio.com` (Quran.com Foundation) and `audio-cdn.tarteel.ai` (Tarteel), for
    recitations recorded one surah per file, fetched one ayah at a time with an HTTP `Range`
    header;
  - `github.com` (GitHub Releases, which redirects to its file storage), for the memorization
    model files.

  All over HTTPS.
- **What is sent**: the file path (reciter and ayah number) and the default `User-Agent`. No
  cookies, account, device or advertising identifier, analytics or crash data. The servers see
  the IP address any HTTPS request carries; the app does not collect or store anything about the
  reader.
- **Stored on the device**: recently played ayat (a cache of at most 100 MB, clearable in
  Settings), surahs the reader downloads, and the memorization model (61.5 MB, deletable in
  Settings › Downloads). All stay in the app's private storage, excluded from iCloud backup, and
  are deleted with the app.

**Microphone (since specs/006, memorization).** The microphone is used only while a memorization
session is listening, after the reader starts it and reads the explanation, and it stops when the
session pauses or ends. The audio goes straight from the microphone to the recognition model
running on the device. It is never written to storage, never sent anywhere, and nothing about it is
kept: a session's score is shown once and discarded. `test/unit/memorization_privacy_test.dart`
keeps network and file-writing code out of the memorization folder, except the model download,
which never sees audio.

The other outbound actions are opening https://tanzil.net and https://everyayah.com in the
system browser when the reader taps an attribution link in About.

## Apple App Store: App Privacy

- **Data collection**: "No, we do not collect data from this app." The audio requests fetch
  content; nothing about the user is collected, linked or used for tracking. Microphone audio is
  processed only on the device and not sent off it, so under Apple's definition it is not
  collected ("data that is processed only on device is not collected"). **To check before the
  1.4 release**: the answers stay "Data Not Collected"; the microphone needs no data type.
- **Resulting label**: Data Not Collected.
- **Tracking**: none. `ios/Runner/PrivacyInfo.xcprivacy` sets `NSPrivacyTracking` to false, with
  no tracking domains and no collected data types.
- **Required-reason APIs** declared in `ios/Runner/PrivacyInfo.xcprivacy`:
  - `NSPrivacyAccessedAPICategoryDiskSpace`, reason `E174.1`: free space is checked before a
    surah download (AppDelegate.swift).
  - `NSPrivacyAccessedAPICategoryFileTimestamp`, reason `C617.1`: modification times of the
    app's own cached recordings decide which to delete first.

  Flutter and the plugins (sqflite, share_plus, url_launcher, wakelock_plus, just_audio,
  audio_service, audio_session, path_provider) ship their own privacy manifests.
- **Microphone**: `NSMicrophoneUsageDescription` in Info.plist, in Arabic and English
  (`InfoPlist.strings`): «يستخدم مثاني الميكروفون أثناء جلسة الحفظ فقط ليتابع تلاوتك على جهازك.
  لا يُسجَّل صوتك ولا يغادر الجهاز.» App Review notes: "The microphone is used only in
  memorization mode, which the user starts; speech is recognised on the device and never leaves
  it."
- **Background mode**: `UIBackgroundModes` = `audio`, so a recitation keeps playing with the
  screen locked. App Review notes: "Plays Quran recitations the user starts; playback stops when
  the user stops it."

## Google Play: Data safety

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | No |
| Is all of the user data collected by your app encrypted in transit? | Not applicable (no data collected; audio is fetched over HTTPS) |
| Do you provide a way for users to request that their data is deleted? | Not applicable (no data collected; uninstalling removes on-device data) |
| Resulting section | "No data collected" and "No data shared with third parties" |
| Audio (Voice or sound recordings), since specs/006 | Not collected: processed only on the device and never sent off it, which Google Play does not count as collection. **To check before the 1.4 release**; no data type is declared |

## Permissions

Android requests one runtime permission, `RECORD_AUDIO` (since specs/006), the first time the
reader starts memorization and after the app's own explanation sheet. Refusing it only means
memorization can't start. The install-time permissions are:

| Permission | Why |
| --- | --- |
| `INTERNET` | Stream and download recitations |
| `ACCESS_NETWORK_STATE` | Tell the reader they are offline, and ask before a download on mobile data |
| `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Keep a recitation playing with the screen off, with its media notification; only while a recitation is on |

The media notification is exempt from Android 13's notification permission, so there is no
prompt. The Play Console's foreground-service declaration: type `mediaPlayback`, "plays Quran
recitations the user starts, with media controls in the notification".

The `<queries>` entry in `AndroidManifest.xml` only lets the app open https links in the browser.
iOS asks for the microphone, through `NSMicrophoneUsageDescription`, the first time the reader
starts memorization (since specs/006). It requests nothing else.

## Privacy policy

### Prayer times (specs/009)

**Not yet in a store release.** Before the first release with prayer times, the answers above, the
permissions table and the published policy must be updated as listed here. None of it has been
changed in the store consoles yet.

What the feature does with data:

- **Location**: approximate (city-level) only, asked when the reader taps "Use my location";
  never precise or in the background. Android declares only `ACCESS_COARSE_LOCATION`; iOS uses
  when-in-use authorization with `NSLocationDefaultAccuracyReduced`. Coordinates are rounded to
  2 decimal places (about 1 km) before they are saved or sent.
- **Sent off the phone**:
  - Rounded coordinates go to Mathani's server (`get.mthani.app`, Cloudflare Pages Functions) and
    on to GeoNames, to find the place name and time zone. This happens once when a place is set,
    and again only when "My location" has moved more than 10 km.
  - City search text goes the same way.
  - The internet-based suggestion reads the city that Cloudflare derives from the connection.
  - The server keeps and logs nothing (`functions/_lib/prayer-location.js`; responses are
    `no-store`).
- **Kept on the phone**: saved places (city-level), calculation and alert settings in `user.db`.
  The Android alert list is a derived copy, excluded from backups. Everything is deleted with the
  app, or with "Delete all prayer data".
- **Notifications**: local only, with no push service, account or server. Android uses exact
  alarms (Alarms & reminders access, asked in context) and restores them after a reboot. The full
  athan plays from a `mediaPlayback` foreground service started by the alarm.

Answers to change, for the product owner to confirm:

| Where | Change |
| --- | --- |
| Apple App Privacy | Coarse Location is used for App Functionality, not linked to identity, not used for tracking. It is processed in real time only, so Apple's "not collected" rule may still apply. Decide, and add the purpose to the review notes. |
| Google Play Data safety | Approximate location: collected, processed ephemerally, for app functionality, optional. GeoNames acts as a service provider, which is not "sharing". |
| Android permissions table | Add `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM` and `RECEIVE_BOOT_COMPLETED`. Extend the `mediaPlayback` foreground-service declaration with "plays the athan at prayer time when the reader chose full athan". |
| Published policy | Replace "on-device storage only" with the location lookup above. |

Both stores require a privacy-policy URL even when no data is collected. The page is
https://mthani.app/privacypolicy (`privacypolicy.html` in the landing site). It states the above:
no data collected, on-device storage only, recitation audio and the memorization model fetched
with no identifiers from the hosts listed here, and the microphone used only during memorization,
on the device, never recorded or sent. Updating the published page is an owner action before
the 1.4 submission.
