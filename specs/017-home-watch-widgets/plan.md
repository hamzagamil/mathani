# Implementation Plan: Home Screen and Watch Widgets

**Branch**: `017-home-watch-widgets` | **Date**: 2026-11-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/017-home-watch-widgets/spec.md`

## Summary

The Flutter app builds one **widget snapshot** (contracts/widget-snapshot.md): already-localized
text for the next 7 days of prayers, the personal khatma's wird and progress, and the last reading
place. It hands the snapshot to native code over a new `app.mathani/widgets` channel whenever one
of these changes. Every widget reads only that snapshot. Flutter cannot draw widgets on any of the
four platforms, so each surface is native:

- **iPhone**: one WidgetKit extension (SwiftUI) with the Prayer, Quran and Khatma progress
  widgets for the home screen (iOS 15+) and lock screen (iOS 16+). Each prayer is a timeline
  entry, so the widget moves on at each prayer time without the app running.
- **Android phone**: two `AppWidgetProvider`s with RemoteViews XML layouts (no Glance, research
  R3), resizable from small to medium, allowed on the lock screen. An alarm at each prayer time
  redraws them.
- **Apple Watch**: a one-screen SwiftUI watch app (today's times, FR-021) that contains a watch
  widget extension (complications and a Smart Stack card). The iPhone sends a smaller watch copy
  of the snapshot with WatchConnectivity.
- **Wear OS**: a new `android/wear` Kotlin module, published in the same Play listing. It has a
  one-screen Compose app, complication data sources with a timeline, and a **tile** (stable API,
  shown by Wear OS 7 too; Wear Widgets wait until Remote Compose leaves alpha, research R7). The
  phone sends the watch copy over the Wearable Data Layer.

A tap on any widget opens a `mathani-widget://` link that a small Dart host turns into navigation
(Prayer Times, the Mushaf at a page, or Khatma). There are no new Dart dependencies. The Android
phone app gains `play-services-wearable`. Apple Watch and Wear OS ship in the same release
(FR-024).

## Technical Context

**Language/Version**: Dart 3.13 / Flutter 3.47.7 (snapshot, sync, links); Swift 6 / SwiftUI with
Xcode 27 (iOS widget extension, watch app, watch widgets); Kotlin 2.4 with AGP 9.1 (Android
widgets, Wear OS module)

**Primary Dependencies**: none new in Dart. iOS: WidgetKit, WatchConnectivity (system). Android
phone: new `com.google.android.gms:play-services-wearable` (research R6). Wear module only:
`androidx.wear.tiles` + `androidx.wear.protolayout`,
`androidx.wear.watchface:watchface-complications-data-source-ktx`, Compose for Wear OS
(`androidx.wear.compose:compose-material3`), `play-services-wearable`

**Storage**: the snapshot JSON (≤ 16 KB) in an iOS App Group (`group.com.mthani.app`) and in
Android SharedPreferences (`mathani_widget_snapshot`). On the watches, the watch copy sits in the
watch app's own App Group or SharedPreferences. Nothing goes in `user.db`, and nothing is sent to a
server.

**Testing**: `flutter test` (snapshot builder fixtures across midnight, DST and time zones; sync
debounce; link host). Kotlin JVM unit tests (snapshot parsing, picking the next prayer, alarm
times, wear complication timeline). XCTest in `RunnerTests` (timeline builder), run on CI macOS.
Manual device checks in [quickstart.md](quickstart.md).

**Target Platform**: iOS 15.0+ (home screen widgets), iOS 16.0+ (lock screen widgets); Android
7.0 (API 24)+ phones, with lock screen placement where the system offers it (Android 16 QPR1+);
watchOS 10.0+ (Smart Stack and complications, research R5); Wear OS 3+ (API 30) for the
complication and tile

**Project Type**: mobile app (Flutter) with native widget extensions and two companion watch apps

**Performance Goals**: no cold-start change (snapshot work starts after the first frame,
Principle III); a snapshot build takes under 20 ms on the reference phones; widgets switch prayers
from precomputed timelines with no app wake-up (SC-002, SC-006)

**Constraints**: offline only, no network requests from widgets (FR-002); no group khatma or
bookmark text (FR-003); 7-day horizon (FR-011, FR-018); store growth ≤ 1 MB per phone platform
(SC-009); iOS reload budget (reload only when the snapshot really changed)

**Scale/Scope**: 3 Dart files plus a platform pair; 1 iOS widget extension (3 widgets), 1 watchOS
app, 1 watchOS widget extension (2 widgets); 2 Android providers; 1 Wear module (screen, 2
complication sources, 1 tile); 2 new CI jobs; owner console work (Apple identifiers and profiles,
Play Wear OS form factor)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
| --- | --- | --- |
| I. Parity | Phone widgets on iOS and Android with the same kinds and states. Apple Watch and Wear OS in the same release with the same complication, card and screen (FR-024). Android lock screen placement depends on the phone's system; Mathani's widgets allow it and work there, and nothing is missing on Mathani's side. Versions are stated above. | Pass |
| II. Mobile-first | Each widget is one tap target (larger than 44 pt / 48 dp). It supports light, dark, tinted and largest text with a shorter fallback layout, and gives one screen-reader sentence (FR-006). The watch screen is one list. | Pass |
| III. Performance | Nothing runs before `runApp`. The snapshot is built after the first frame, debounced by 2 s, and sent over an async channel. Widgets use timelines and alarms, never polling. | Pass |
| IV. Lean | No Dart dependency. RemoteViews instead of Glance (research R3). One phone dependency (`play-services-wearable`) justified below. Watch code ships only to watches. Size measured (research R13). | Pass, with justification |
| V. Simplicity | One snapshot and one channel for all surfaces. Text is localized in Dart once, and native code only lays it out. No configurable widgets (no intents or settings) in v1. | Pass |
| Store requirements | New App Store identifiers, App Group and profiles. Wear OS form factor in Play, with Wear quality rules (research R11). Privacy answers unchanged: no new data collected or shared. | Pass, owner completes the consoles |

## Project Structure

### Documentation (this feature)

```text
specs/017-home-watch-widgets/
├── spec.md, research-platforms.md
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/widget-snapshot.md, contracts/widget-surfaces.md, contracts/watch-sync.md
└── tasks.md (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/features/widgets/widget_snapshot.dart      # pure builder: controllers' state → WidgetSnapshot (+ watch copy)
lib/features/widgets/widget_sync.dart          # listens to Prayer/Khatma/Reader controllers and settings; debounce; sends on change
lib/features/widgets/widget_link_host.dart     # mathani-widget:// links → Prayer Times, Mushaf page, Khatma
lib/platform/home_widgets.dart (+ _io, _web)   # channel app.mathani/widgets; web is a no-op
lib/platform/app_links_io.dart                 # passes mathani-widget:// links through (group host ignores them)
lib/features/analytics/usage.dart              # + widgets_present (contracts/widget-surfaces.md › Usage)
lib/main.dart, lib/app/app.dart                # start WidgetSync after the first frame; mount WidgetLinkHost

ios/Runner/AppDelegate.swift, WidgetBridge.swift   # channel handler: App Group write, WidgetCenter reload, WCSession send
ios/Runner/Info.plist                          # CFBundleURLTypes mathani-widget
ios/Runner/SceneDelegate.swift                 # forwards mathani-widget:// URLs on the device channel
ios/MathaniWidgets/                            # iOS widget extension: Snapshot.swift, Timeline.swift, PrayerWidget, QuranWidget, KhatmaWidget, Localizable.xcstrings
ios/MathaniWatch/                              # watchOS app: one SwiftUI screen, WCSession receiver, store
ios/MathaniWatchWidgets/                       # watchOS widget extension: prayer + khatma complications, Smart Stack card
ios/Shared/                                    # Snapshot model and timeline code compiled into all three targets
ios/Runner.xcodeproj                           # 3 new targets (added by tool/ios/add_widget_targets.rb, research R4)
ios/ExportOptions.plist                        # profiles for the new bundle ids

android/app/src/main/kotlin/app/mathani/mathani/widgets/   # WidgetsPlugin, SnapshotStore, PrayerWidgetProvider, QuranWidgetProvider, WidgetAlarms, WearSync
android/app/src/main/res/layout/widget_*.xml, xml/widget_*_info.xml, values{,-ar}/widget_strings.xml
android/app/src/main/AndroidManifest.xml       # providers, alarm receiver, time/locale change receivers
android/wear/                                  # Wear OS module (built to build/wear/) (applicationId com.mthani.app): MainActivity (Compose), SnapshotListenerService, PrayerComplicationService, KhatmaComplicationService, PrayerTileService
android/settings.gradle.kts                    # include(":wear")

test/features/widgets/                         # snapshot, sync, link host tests
android/app/src/test/…, android/wear/src/test/… # JVM tests
.github/workflows/ci.yml                       # + iOS build job (macOS, unsigned) and :wear build/test
.github/workflows/ios-release.yml              # installs 3 more profiles
.github/workflows/ios-add-targets.yml          # one-time: runs the xcodeproj script and commits the result
tool/ios/add_widget_targets.rb                 # adds the targets, App Group, embedding
docs/release.md, docs/store/*                  # Wear bundle build and upload, watch screenshots, owner console steps
```

**Structure Decision**: Follows the pattern of specs/009 and specs/015: a Dart feature folder for
logic, a platform file per channel, and hand-written native plugins in the app's own Kotlin/Swift
rather than packages. Watch apps are new native targets because neither watch can run Flutter UI
for complications.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| 3 new Xcode targets (widget extension, watch app, watch widget extension) and Swift UI code | WidgetKit widgets and watch complications can only be native SwiftUI in their own targets (research-platforms.md) | No Flutter path exists; Live Activities and Controls do not give a watch face complication |
| New Gradle module `android/wear` with its own app | Wear OS complications and tiles must come from an app installed on the watch (research-platforms.md) | A Flutter Wear app still needs native complications/tiles and is larger (research R6) |
| New phone dependency `play-services-wearable` (~0.2–0.4 MB, measured in R13) | The only supported way to send data from the phone to a Wear OS watch | Network sync needs a server and an account, which the spec forbids (FR-002) |
| A Ruby/xcodeproj script and a one-time macOS workflow | The owner works on Windows; Xcode targets cannot be added reliably by hand-editing `project.pbxproj` | Hand edits are error-prone; XcodeGen would replace the whole project file the Flutter tooling expects |

## Post-design Constitution Check

Unchanged: **Pass**. The design adds no background work beyond redraws at prayer times (the
alarms the app already uses for athan, plus redraws). Text is localized once in Dart, so all four
surfaces match the app (FR-005). The only phone growth is the extension, the layouts and
`play-services-wearable`, which are measured before release.

## Size (T063, measured 2026-11-22)

- **Android phone** (arm64 download, `tool/size_check.dart android`): 173.04 MB. specs/016 measured
  172.93 MB just before this feature, so the widgets, their layouts and `play-services-wearable`
  add **about 0.11 MB**, within the 1 MB rule. The tool still reports +3.10 MB against the old
  1.4.0+9 baseline (169.94 MB), which predates specs/015 and specs/016; the baseline is the owner's
  to update.
- **Wear OS bundle**: 3.2 MB (`wear-release.aab`), downloaded only to watches.
- **iOS**: measured by CI once the targets are in the Xcode project (the widget extension is in the
  iPhone download; the watch app is delivered to the watch).
