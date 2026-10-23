# Store Privacy Answers

Mathani collects no data (FR-027). It has no account, no analytics, no crash reporting and no
ads. Bookmarks, reading position and preferences stay in an on-device database that is deleted
with the app.

**Network use (since specs/004, recitations).** The app's only network requests are for
recitation audio, and only after the reader plays a recitation or downloads a surah:

- **Hosts**: `everyayah.com` (CDN) and its mirror `mirrors.quranicaudio.com`, for ayah-by-ayah MP3
  files over HTTPS.
- **What is sent**: the file path (reciter and ayah number) and the default `User-Agent`. No
  cookies, account, device or advertising identifier, analytics or crash data. The servers see
  the IP address any HTTPS request carries; the app does not collect or store anything about the
  reader.
- **Stored on the device**: recently played ayat (a cache of at most 100 MB, clearable in
  Settings) and surahs the reader downloads. Both stay in the app's private storage and are
  deleted with the app.

The other outbound actions are opening https://tanzil.net and https://everyayah.com in the
system browser when the reader taps an attribution link in About.

## Apple App Store: App Privacy

- **Data collection**: "No, we do not collect data from this app." The audio requests fetch
  content; nothing about the user is collected, linked or used for tracking.
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

## Permissions

Android requests no runtime permissions. The install-time permissions are:

| Permission | Why |
| --- | --- |
| `INTERNET` | Stream and download recitations |
| `ACCESS_NETWORK_STATE` | Tell the reader they are offline, and ask before a download on mobile data |
| `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Keep a recitation playing with the screen off, with its media notification; only while a recitation is on |

The media notification is exempt from Android 13's notification permission, so there is no
prompt. The Play Console's foreground-service declaration: type `mediaPlayback`, "plays Quran
recitations the user starts, with media controls in the notification".

The `<queries>` entry in `AndroidManifest.xml` only lets the app open https links in the browser.
iOS requests no permissions and uses no usage-description keys.

## Privacy policy

Both stores require a privacy-policy URL even when no data is collected. Publish a short page
stating the above: no data collected, on-device storage only, recitation audio fetched from
EveryAyah (everyayah.com and mirrors.quranicaudio.com) with no identifiers. This is an owner
action before submission.
