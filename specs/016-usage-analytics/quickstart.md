# Quickstart: Usage Analytics

## Prerequisites

- Firebase project `mthani` with Android, iOS and web apps (`flutterfire configure --project=mthani
  --platforms=android,ios,web`), linked to GA4 property 539746070.
- In GA admin (owner): data retention 2 months, Google signals off, ads personalisation off.

## Automated

```powershell
flutter analyze
flutter test --exclude-tags web,golden
```

- `test/features/analytics/usage_test.dart`: every event and screen name is snake_case and at most
  40 characters; settings diffs log exactly the changed fields; the sink queues before start and
  drops when off.
- `test/features/analytics/usage_privacy_test.dart`: only `lib/platform/usage_firebase.dart`
  imports `firebase_analytics`; no `Usage` method takes a `String` other than catalogue ids.

## Manual 1: phones count (US1)

1. Install a release build (TestFlight or Play internal testing).
2. Open it; in GA › Reports › Realtime, a user appears under the platform within a few minutes.
3. Open it again the next day; the daily report counts one user per day.

## Manual 2: screens and actions (US2)

1. With a debug build, enable DebugView: Android `adb shell setprop debug.firebase.analytics.app
   com.mthani.app`; iOS launch argument `-FIRDebugEnabled`. (Debug builds keep collection off;
   for this check temporarily run a profile build with `--dart-define=USAGE_DEBUG=true`.)
2. Visit every screen in the contract and do each action once.
3. DebugView shows each `screen_view` name and action with only the listed parameters, and none of
   the "Never sent" items.

## Manual 3: disclosure (US3)

1. Settings › About shows the one-sentence privacy line and the policy link opens.
2. mthani.app/privacypolicy has the "Usage statistics" section; listings no longer say nothing is
   collected.

## Manual 4: web (US4)

1. Open https://get.mthani.app in a fresh profile; no banner appears.
2. Realtime shows a web user and `screen_view` `reader`.
3. A preview deployment (`*.mthani-web.pages.dev`) sends nothing (browser network tab shows no
   request to google-analytics.com).
