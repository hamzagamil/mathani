# Store Privacy Answers

Mathani v1 collects no data (FR-027). It has no account, no analytics, no crash reporting, no
ads and no network calls. Bookmarks, reading position and preferences stay in an on-device
database that is deleted with the app. The only outbound action is opening https://tanzil.net in
the system browser when the reader taps the attribution link.

## Apple App Store: App Privacy

- **Data collection**: "No, we do not collect data from this app."
- **Resulting label**: Data Not Collected.
- **Tracking**: none. `ios/Runner/PrivacyInfo.xcprivacy` sets `NSPrivacyTracking` to false, with
  no tracking domains and no collected data types.
- **Required-reason APIs**: none in app code. Flutter and the plugins (sqflite, share_plus,
  url_launcher, wakelock_plus) ship their own privacy manifests.

## Google Play: Data safety

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | No |
| Is all of the user data collected by your app encrypted in transit? | Not applicable (no data collected) |
| Do you provide a way for users to request that their data is deleted? | Not applicable (no data collected; uninstalling removes on-device data) |
| Resulting section | "No data collected" and "No data shared with third parties" |

## Permissions

Android requests no permissions. The `<queries>` entry in `AndroidManifest.xml` only lets the app
open https links in the browser. iOS requests no permissions and uses no usage-description keys.

## Privacy policy

Both stores require a privacy-policy URL even when no data is collected. Publish a short page
stating the above (no data collected, on-device storage only, no third parties). This is an owner
action before submission.
