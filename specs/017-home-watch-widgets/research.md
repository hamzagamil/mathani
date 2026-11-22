# Research: Home Screen and Watch Widgets

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Date**: 2026-11-22

The platform survey (what each OS allows) is in [research-platforms.md](research-platforms.md).
This file records the decisions taken for the plan.

## R1. One snapshot, localized in Dart

- **Decision**: Dart builds one `WidgetSnapshot` (data-model.md) holding display-ready strings:
  prayer names, times formatted with the app's numerals, the place name, surah/juz/page labels, and
  all labels ("Next", "Today's wird is done", "Open Mathani to update"…). It also holds raw UTC
  instants for timelines and countdowns. Native code only lays the snapshot out.
- **Rationale**: The app's language and numerals can differ from the system's (FR-005). Dart
  already has the calculator, the Quran index and the l10n strings, so formatting them once keeps
  all four surfaces identical to the app with no copied logic.
- **Alternatives**: Recomputing prayer times natively (a second calculator on four platforms, with
  drift risk); passing raw data and localizing natively (four copies of l10n and numerals).
- **Native strings are still needed** for the widget picker name, description and preview
  (system language), and for the "no snapshot yet" state.

## R2. Prayer horizon and the "Open Mathani to update" state

- **Decision**: The snapshot holds the five prayers for today plus 7 more days (40 entries) as UTC
  instants, plus each day's label. Every timeline (iOS widget, Apple Watch, Wear complication and
  tile) ends with an entry at the last Isha + 1 minute of day 8 that shows "Open Mathani to update"
  (FR-008). The Android phone widget computes the same thing from the stored list at each redraw.
- **Rationale**: This meets FR-011 and FR-018 (≥ 7 days). 40 entries fit iOS timeline limits and
  the watch transfer limits (R5, R6).
- **Travel**: times are instants for the place shown, and the place name is always displayed. When
  the place follows the device location and the time zone changes, the app refreshes the snapshot
  on its next resume, as Prayer Times does (spec edge case).

## R3. Android phone widgets: RemoteViews, not Glance

- **Decision**: Use classic `AppWidgetProvider` + RemoteViews XML layouts. Use responsive layouts
  through `RemoteViews(Map<SizeF, RemoteViews>)` on API 31+ and size buckets from
  `onAppWidgetOptionsChanged` below that. The countdown uses `setChronometerCountDown` (API 24).
  Colors are the app's own paper-and-navy palette (light and night), so the widgets look like
  Mathani; on API 31+ the corners follow the launcher's radius.
- **Rationale**: Glance pulls in the Compose runtime (roughly 1 MB or more after R8), which alone
  could break SC-009. Two small layouts per widget do not need it. RemoteViews supports every API
  level Mathani does.
- **Alternatives**: Jetpack Glance (nicer code, size cost); `home_widget` package (only a data
  bridge, and the app already writes its own channels).
- **Known limitation**: the Chronometer formats digits with the system locale. When the app uses
  Arabic-Indic numerals but the system uses Western digits (or the reverse), only the live
  countdown differs; the prayer time itself uses the app's numerals. Recorded and accepted.

## R4. Adding Xcode targets from a Windows workstation

- **Decision**: A Ruby script `tool/ios/add_widget_targets.rb` uses the `xcodeproj` gem (shipped
  with CocoaPods on GitHub macOS runners). It adds the three targets, their Info.plists and
  entitlements (App Group `group.com.mthani.app`), the "Embed Foundation Extensions" and "Embed
  Watch Content" phases, the deployment targets and the bundle ids. A `workflow_dispatch` workflow
  `ios-add-targets.yml` runs it once on the feature branch and commits the result. Swift sources
  are written on Windows and compiled in CI.
- **CI**: a new `ios` job in `ci.yml` (macOS) runs `flutter build ios --no-codesign --simulator`
  and `xcodebuild test` for `RunnerTests`, so Swift errors fail the pull request, not the release.
- **Rationale**: Hand-editing `project.pbxproj` breaks easily (ids, build phases). XcodeGen would
  replace the file Flutter's tooling manages.
- **Bundle ids**: `com.mthani.app.widgets`, `com.mthani.app.watchkitapp`,
  `com.mthani.app.watchkitapp.widgets`. There are two App Groups: `group.com.mthani.app` (iPhone
  app + widget extension) and `group.com.mthani.app.watch` (watch app + watch widgets). The owner
  creates the ids, both groups and three App Store profiles in the developer portal, adds the
  group to the existing app id's profile, and adds the profiles as secrets. `ios-release.yml` and
  `ExportOptions.plist` gain the mappings.

## R5. Apple Watch

- **Decision**: A single-target SwiftUI watch app (watchOS 10.0+) embedded in the iPhone app, plus
  a watch widget extension with:
  - **Prayer**: `accessoryCircular` (countdown ring to the next prayer), `accessoryCorner`,
    `accessoryInline`, and `accessoryRectangular`, which is the Smart Stack card: the next prayer
    large and the rest of today's times in a compact row, falling back to next and following at
    large text sizes.
  - **Khatma**: `accessoryCircular` and `accessoryCorner` as a progress gauge, with a check mark
    when today's wird is read.
  The app is one screen: today's five times, the next marked, the place name (FR-021).
- **Data**: the iPhone side calls `WCSession.updateApplicationContext` with the watch copy. This
  keeps only the latest, is delivered when the watch is next reachable, and survives the app not
  running. When a complication is on the face (`isComplicationEnabled`) and prayer data changed,
  it also calls `transferCurrentComplicationUserInfo` for a prompt update (system budget about
  50 a day; content changes are rare). The watch app writes the copy to its App Group and calls
  `WidgetCenter.reloadAllTimelines()`.
- **Relevance**: the card gives a `TimelineEntryRelevance` that rises in the 30 minutes before each
  prayer, so the Smart Stack shows it then.
- **watchOS 10.0**: this is the Smart Stack's first version, and it runs on Series 4 and later. If
  Xcode 27 refuses a 10.0 deployment target, use its lowest allowed value and update the spec's
  Assumptions.
- **Alternatives**: no watch app (impossible for complications); a fuller app (rejected in
  clarification Q1).

## R6. Wear OS: module, data and identifiers

- **Decision**: A native Kotlin module `android/wear` with the **same applicationId**
  `com.mthani.app` and the same signing key. Both are required for the Data Layer to pair the two
  apps and for Play to put them in one listing. Settings:
  - minSdk 30 (Wear OS 3), targetSdk 36.
  - `<uses-feature android:name="android.hardware.type.watch"/>` and
    `com.google.android.wearable.standalone = false`: it needs the phone, which matches the spec.
  - versionCode `1_000_000 + phone build number`, so it never collides with the phone's codes.
  The phone side `WearSync` puts a `DataItem` at `/mathani/widgets` (urgent) with the watch copy.
  The watch's `WearableListenerService` stores it and requests complication and tile updates.
- **Rationale**: A Flutter Wear app would still need native complications and tiles, and would
  carry the Flutter engine (about 5 MB or more) for one screen. Compose for Wear OS is small and
  is the platform's way to build watch UI.
- **Phone dependency**: `play-services-wearable` is the supported Data Layer client. Firebase
  already brings `play-services-basement`/`tasks`, so the extra size is small (R13). On phones
  without Play services (none of Mathani's store installs), `WearSync` does nothing.

## R7. Wear OS glance surface: tile now, Wear Widget later

- **Decision**: Build a **tile** with `androidx.wear.tiles` + ProtoLayout, plus complication data
  sources. The tile uses a timeline with one entry per prayer (validity windows), so it changes on
  time. Wear OS 7 still shows tiles.
- **Rationale**: Remote Compose (behind Wear Widgets) was 1.0.0-alpha21 in October 2026. A release
  that must ship on both watches together (FR-024) should not depend on an alpha library. Moving
  to a Wear Widget later is a separate, small feature (Google provides a migration guide and
  a single service for both protocols).
- **Complications**: `SuspendingComplicationDataSourceService` returns a
  `ComplicationDataTimeline`:
  - **Prayer**: `SHORT_TEXT` with a `TimeDifferenceComplicationText` countdown and the prayer name
    as title, and `LONG_TEXT`. No `RANGED_VALUE`: a value fixed between timeline entries would
    stand still between prayers.
  - **Khatma**: `RANGED_VALUE` (progress) and `SHORT_TEXT`.
  The update period is 0; updates are pushed when data arrives.

## R8. Tap destinations

- **Decision**: All widgets open links with the private scheme `mathani-widget://`:
  `prayer`, `mushaf/<page>`, `khatma`, `khatma/read` (contracts/widget-surfaces.md).
  - **iOS**: `widgetURL` / `Link` → `SceneDelegate` → the existing `app.mathani/device` channel
    `link` method.
  - **Android**: an explicit `PendingIntent` to `MainActivity` with a `link` extra, which reuses
    `noteOpenIntent`.
  `WidgetLinkHost` routes them after the first frame, the same way `GroupLinkHost` does. Group
  link parsing ignores this scheme.
- **Watch taps** open the watch app's own screen (FR-021). They never open the phone.
- **Rationale**: This reuses the link path that announcements (specs/015) and group links
  (specs/014) already use. A custom scheme cannot be confused with web links.

## R9. When the snapshot is rebuilt

- **Decision**: `WidgetSync` rebuilds and sends the snapshot (debounced 2 s, and only if the JSON
  hash changed) when any of these happen:
  - `PrayerController` place, method or schedule changes;
  - `KhatmaController` changes;
  - the reader settles on a new page;
  - language or numerals change;
  - the app resumes, or pauses (flush);
  - the prayer alert refill (specs/009) runs, which already happens on every resume and daily.
- **Rationale**: This covers FR-005 (≤ 1 minute after a settings change) and keeps iOS reloads
  within budget (they happen only on real changes).

## R10. Lock screen

- **iOS 16+**: the Prayer widget offers `accessoryCircular`, `accessoryRectangular` and
  `accessoryInline`; the Khatma widget offers `accessoryCircular` and `accessoryRectangular`.
  Rendering follows `widgetRenderingMode` (vibrant/tinted). This code sits behind
  `@available(iOS 16, *)`, and iOS 17's `containerBackground` behind a helper, so iOS 15 still
  builds.
- **Android**: `android:widgetCategory="home_screen|keyguard"`. The layouts already work at small
  sizes; a tap on the lock screen asks to unlock first (the system's rule). Nothing private is
  shown (FR-003).

## R11. Store requirements

- **App Store**: the watch app goes in the same submission. It needs watch screenshots, and App
  Review expects the watch app to do something useful on its own, which today's times do.
  Privacy labels are unchanged.
- **Google Play**: the owner opts in to the Wear OS form factor. The Wear bundle uploads to the
  same release as the phone bundle. Wear OS screenshots are required. The app must pass the Wear
  OS app quality checks: round screens, ambient handling of the screen, a working tile and
  complication. The Data safety form is unchanged.

## R12. Usage statistics

- **Decision**: Add one event to the allowed list of specs/016: `widgets_present`, with
  parameters `kinds` (a sorted, comma-joined subset of `prayer, quran, khatma`) and
  `surface` (`phone`). It is sent at most once a day on resume, from
  `WidgetCenter.getCurrentConfigurations` on iOS and `AppWidgetManager.getAppWidgetIds` on Android.
  Watch placement is not counted: there is no reliable phone-side API.
- **Rationale**: This measures SC-007 with no identifiers and nothing about content.

## R13. Size

- **Expected**: Android phone +0.3 to 0.6 MB (layouts, providers, `play-services-wearable`); iOS
  +0.3 to 0.6 MB for the widget extension. The watch app is delivered to the watch and is not
  part of the iPhone's thinned download (check in App Store Connect's size report). The Wear
  bundle is separate.
- **Gate**: `tool/size_check.dart android` on CI; iOS from the release build. Anything over 1 MB
  is called out (Principle IV).

## R14. Reference devices

- **Phones**: Galaxy A15 and iPhone SE (2nd gen), as before. Add an Android 16 QPR1+ phone or
  emulator for the lock screen.
- **Watches**: Apple Watch simulator on watchOS 10 and the latest watchOS, and a Wear OS emulator
  on Wear OS 4 (API 33) and the latest. Add a real Apple Watch and a real Galaxy or Pixel Watch
  before release. The owner names the real devices in docs/release.md.
