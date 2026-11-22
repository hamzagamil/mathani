# Tasks: Home Screen and Watch Widgets

**Input**: Design documents from `specs/017-home-watch-widgets/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included. The plan names `flutter test` fixtures, Kotlin JVM tests and XCTest.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on unfinished tasks)
- **[Story]**:
  - US1: prayer widget on the phone home screen
  - US2: Quran (continue reading / wird) widget
  - US3: lock screen
  - US4: next prayer on the watch
  - US5: khatma progress on the watch
- **Owner** marks a step only the owner can do in a console. It is listed so nothing waits
  silently.

## Phase 1: Setup

- [X] T001 **Owner**: in the Apple developer portal, create the app ids `com.mthani.app.widgets`, `com.mthani.app.watchkitapp` and `com.mthani.app.watchkitapp.widgets`, and the App Groups `group.com.mthani.app` and `group.com.mthani.app.watch`. Add `group.com.mthani.app` to `com.mthani.app` and the widgets id, and `group.com.mthani.app.watch` to both watch ids. Create three App Store profiles, regenerate the `com.mthani.app` profile, and store them as GitHub secrets `IOS_WIDGETS_PROFILE_BASE64`, `IOS_WATCH_PROFILE_BASE64`, `IOS_WATCH_WIDGETS_PROFILE_BASE64`, updating `IOS_APPSTORE_PROFILE_BASE64` (research R4). Write these steps in `docs/release.md` first.
- [ ] T002 **Owner**: in the Play Console, opt the Mathani app in to the Wear OS form factor (Advanced settings › Form factors) (research R11). Record it in `docs/release.md`. *Status 2026-11-22: Wear OS form factor added. Play lists three steps before the opt-in: upload Wear OS screenshots for all store listings (T064), release a Wear OS bundle to a testing track (after T055), then "Opt-in to Wear OS and agree to the review policy", which stays locked until the first two are done.*
- [X] T003 Write `tool/ios/add_widget_targets.rb` with the `xcodeproj` gem. It is idempotent: it exits if the targets exist. It opens `ios/Runner.xcodeproj` and adds:
  - **`MathaniWidgets`**: app-extension, iOS 15.0, bundle id `com.mthani.app.widgets`, sources `ios/MathaniWidgets/**` + `ios/Shared/**`, Info.plist `NSExtensionPointIdentifier = com.apple.widgetkit-extension`, entitlements with `group.com.mthani.app`, embedded in Runner via "Embed Foundation Extensions".
  - **`MathaniWatch`**: watchOS single-target app, watchOS 10.0, bundle id `com.mthani.app.watchkitapp`, `WKCompanionAppBundleIdentifier = com.mthani.app`, sources `ios/MathaniWatch/**` + `ios/Shared/**`, entitlements `group.com.mthani.app.watch`, embedded in Runner via "Embed Watch Content" (`$(CONTENTS_FOLDER_PATH)/Watch`).
  - **`MathaniWatchWidgets`**: watchOS widget extension, watchOS 10.0, bundle id `com.mthani.app.watchkitapp.widgets`, sources `ios/MathaniWatchWidgets/**` + `ios/Shared/**`, entitlements `group.com.mthani.app.watch`, embedded in MathaniWatch.

  Set `DEVELOPMENT_TEAM = YJBH85NYZU`, `SWIFT_VERSION = 6.0`, `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` from `$(FLUTTER_BUILD_NAME)`/`$(FLUTTER_BUILD_NUMBER)`, and manual signing with the profile names from T001 for Release.
- [X] T004 Create placeholder sources so the targets build:
  - `ios/Shared/WidgetSnapshot.swift` (empty `enum WidgetShared {}`);
  - `ios/MathaniWidgets/MathaniWidgetsBundle.swift` (`@main WidgetBundle` with no widgets yet);
  - `ios/MathaniWatch/MathaniWatchApp.swift` (`@main App` with an empty `List`);
  - `ios/MathaniWatchWidgets/MathaniWatchWidgetsBundle.swift`;
  - entitlements files `ios/MathaniWidgets/MathaniWidgets.entitlements`, `ios/MathaniWatch/MathaniWatch.entitlements`, `ios/MathaniWatchWidgets/MathaniWatchWidgets.entitlements`;
  - add `group.com.mthani.app` to `ios/Runner/Runner.entitlements`.
- [X] T005 Create `.github/workflows/ios-add-targets.yml`: `workflow_dispatch` on `macos-latest`, `gem install xcodeproj` if missing, run `ruby tool/ios/add_widget_targets.rb`, then commit `ios/Runner.xcodeproj/project.pbxproj` to the dispatching branch with the message `chore(ios): add widget and watch targets` (no AI attribution lines). Run it on the feature branch after T003–T004 are pushed.
- [X] T006 Add an `ios` job to `.github/workflows/ci.yml` (`runs-on: xcode-27`, same Flutter setup): run `flutter pub get`, `flutter build ios --simulator --no-codesign --debug`, then `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:RunnerTests CODE_SIGNING_ALLOWED=NO`, and `xcodebuild -scheme MathaniWatch -destination 'generic/platform=watchOS Simulator' build CODE_SIGNING_ALLOWED=NO`.
- [X] T007 Update `.github/workflows/ios-release.yml` to decode and install the three new profiles next to the existing one. Update `ios/ExportOptions.plist` `provisioningProfiles` with the four bundle ids → profile names.
- [X] T008 Create the Wear module `android/wear/build.gradle.kts`:
  - `com.android.application` + Kotlin + Compose compiler;
  - namespace `app.mathani.wear`, applicationId `com.mthani.app`, minSdk 30, targetSdk 36;
  - versionCode `1_000_000 + flutterVersionCode` read from `local.properties`/pubspec like `:app`, versionName from pubspec;
  - the same release signing config as `android/app/build.gradle.kts` (`key.properties`), R8 on;
  - dependencies: `androidx.wear.compose:compose-material3`, `androidx.activity:activity-compose`, `androidx.wear.tiles:tiles`, `androidx.wear.protolayout:protolayout{,-material3,-expression}`, `androidx.wear.watchface:watchface-complications-data-source-ktx`, `com.google.android.gms:play-services-wearable`, `kotlinx-coroutines-play-services`; test: `junit`.

  Add `include(":wear")` to `android/settings.gradle.kts`.
- [X] T009 Create `android/wear/src/main/AndroidManifest.xml`:
  - `<uses-feature android:name="android.hardware.type.watch"/>`;
  - `<meta-data android:name="com.google.android.wearable.standalone" android:value="false"/>`;
  - an empty `MainActivity` (exported, launcher);
  - app label strings in `android/wear/src/main/res/values/strings.xml` and `values-ar/strings.xml`;
  - the Mathani icon copied as `android/wear/src/main/res/mipmap-*/ic_launcher.png` (round-safe).
- [X] T010 Add a `wear` job (or steps in the `android` job) to `.github/workflows/ci.yml`: run `cd android && ./gradlew :wear:testReleaseUnitTest :wear:bundleRelease :app:testDebugUnitTest`, and upload `android/wear/build/outputs/bundle/release/*.aab` as an artifact.

## Phase 2: Foundational (blocks all stories)

- [X] T011 Create `lib/features/widgets/widget_snapshot.dart` with immutable `WidgetSnapshot`, `WidgetLabels`, `PrayerBlock`, `PrayerEntry`, `WidgetDay`, `QuranBlock`, `KhatmaProgress`, and `WatchCopy` with `toJson()` exactly as in contracts/widget-snapshot.md:
  - `v: 1`; `lang` is `ar` | `en`; `rtl` is true for Arabic;
  - `prayer` is "Null when no place is set";
  - `quran.mode` is one of `wird` | `wirdDone` | `continue` | `start`;
  - `place` is 1–80 chars.

  Add `WidgetSnapshot.build({required PrayerController prayer, required KhatmaController khatma, required ReaderController reader, required AppLocalizations l10n, required Numerals numerals, required DateTime nowUtc})`. For now it fills only `labels` (from `lib/app/l10n` and new ARB keys in T012), `lang`, `rtl` and `madeAtUtc`, with `prayer: null` and `quran.mode: start`; US1 and US2 fill the blocks. Also add `WatchCopy.from(WidgetSnapshot)`. It asserts the JSON is at most 16 KB.
- [X] T012 [P] Add the label strings to `lib/app/l10n/app_en.arb` and `app_ar.arb` (keys prefixed `widget`): `widgetNext`, `widgetIn` (with a `{left}` placeholder, split into prefix/suffix by the builder), `widgetTodayWirdDone`, `widgetContinueReading`, `widgetStartReading`, `widgetSetPlace` ("Set your place in Prayer Times"), `widgetSetPlaceWatch` ("Set a place in Mathani on your phone"), `widgetOpenToUpdate` ("Open Mathani to update"), `widgetKhatma`, `widgetNoKhatma`, `widgetTodaysWird`, `widgetWirdFrom`, `widgetWirdTo`, `widgetPageJuz`, `widgetProgress` ("{percent}% · {read} of {total} pages"), `widgetA11yNext` ("{name} at {time}, {left}"). Then run `flutter gen-l10n`.
- [X] T013 [P] Create `lib/platform/home_widgets.dart` (conditional import like `lib/platform/share.dart`), `home_widgets_io.dart` and `home_widgets_web.dart`, with `HomeWidgets.update(String snapshot, String watch)`, `Future<List<String>> placed()` and `clear()` over `MethodChannel('app.mathani/widgets')`. It ignores `MissingPluginException`/`PlatformException`. The web version does nothing and returns `[]`.
- [X] T014 Create `lib/features/widgets/widget_sync.dart`, a `WidgetSync` that:
  - listens to `PrayerController`, `KhatmaController`, `ReaderController` and the language/numerals settings;
  - rebuilds through `WidgetSnapshot.build` with a 2 s debounce, plus at once on `AppLifecycleState.paused` and `resumed`;
  - sends only when the JSON's SHA-256 (`package:crypto`, already a dependency) differs from the last one sent (research R9);
  - has an injectable clock, sink and debounce duration for tests.

  Start it in `lib/main.dart` in the existing post-frame callback, never before `runApp` (Principle III).
- [X] T015 Create `lib/features/widgets/widget_link_host.dart` with `WidgetLink.parse(String)` for `mathani-widget://prayer`, `mathani-widget://mushaf/<page>` (1–604), `mathani-widget://khatma/read` and `mathani-widget://khatma`, returning null for anything else. Add a `WidgetLinkHost` widget, mounted next to `GroupLinkHost` in `lib/app/app.dart`, that listens to `AppLinks.instance.links` and `takeLink()`. After the first frame it opens Prayer Times (the place setup sheet when no place is set), jumps the reader to a page, does the Khatma screen's "Read" action, or pushes the Khatma screen. During a memorization session it waits until the session ends, as `GroupLinkHost` does (contracts/widget-surfaces.md › Links).
- [X] T016 Make `GroupCode.parse` in `lib/features/khatma/group/` (used by `group_link_host.dart`) return null for the `mathani-widget` scheme, so group links never react to widget links. In `lib/platform/app_links_io.dart`, keep a link that arrives before any listener (as `deliver` does) so that a launch from a widget is not lost.
- [X] T017 [P] Create `ios/Runner/WidgetBridge.swift`, a `FlutterPlugin` on channel `app.mathani/widgets`, registered from `ios/Runner/AppDelegate.swift`:
  - **`update`**: write `snapshot` to `UserDefaults(suiteName: "group.com.mthani.app")` key `widgetSnapshot`. Only if its SHA-256 (CryptoKit) differs from `widgetSnapshotHash`, store the hash and call `WidgetCenter.shared.reloadAllTimelines()` (iOS 14+). Keep `watch` for US4 (a no-op hook for now).
  - **`placed`**: `WidgetCenter.shared.getCurrentConfigurations`, mapped to kinds `prayer`/`quran`/`khatma` by widget `kind` string.
  - **`clear`**: remove both keys and reload.
- [X] T018 [P] Register the URL scheme `mathani-widget` in `CFBundleURLTypes` of `ios/Runner/Info.plist`. In `ios/Runner/SceneDelegate.swift` (`scene(_:openURLContexts:)` and the launch options in `scene(_:willConnectTo:)`), forward URLs with that scheme to the existing `app.mathani/device` channel as `link`, or keep them for `takeLink`.
- [X] T019 [P] Create `android/app/src/main/kotlin/app/mathani/mathani/widgets/SnapshotStore.kt`: it reads and writes `SharedPreferences("mathani_widget_snapshot")` keys `snapshot` and `hash` (SHA-256 hex). Add `Snapshot.kt` with an `org.json` parser into data classes matching data-model.md. Show the not set up state (`null`) when `v` is greater than 1, when `entries` are not ascending with unique `atUtc`, or when parsing fails. Add `nextEntry(entries, nowMs)` = "the first entry with `atUtc > t`" and `isExpired(prayer, nowMs) = nowMs >= validUntilUtc`.
- [X] T020 Create `android/app/src/main/kotlin/app/mathani/mathani/widgets/WidgetsPlugin.kt` on channel `app.mathani/widgets`, registered in `MainActivity.kt` like `PrayerNotificationsPlugin`:
  - **`update`**: store, and if the hash changed, call `WidgetRefresher.refreshAll(context)` (a stub until US1/US2); keep `watch` for US4.
  - **`placed`**: `AppWidgetManager.getAppWidgetIds` per provider class.
  - **`clear`**.
- [X] T021 In `android/app/src/main/kotlin/app/mathani/mathani/MainActivity.kt`, deliver an intent with action `app.mathani.OPEN_WIDGET` and a `link` extra to Dart as a `link` on the `app.mathani/device` channel (cold start: `takeLink`; warm: `onNewIntent`), reusing the existing link path.
- [X] T022 [P] Create `ios/Shared/WidgetSnapshot.swift`: `Codable` structs matching contracts/widget-snapshot.md, plus `static func load(suite:) -> WidgetSnapshot?`, which returns nil when `v > 1` or entries are not ascending/unique. Add `func nextEntry(after: Date)` and `isExpired(at:)`, implementing the same rules as T019.
- [X] T023 [P] Tests in `test/features/widgets/widget_link_test.dart`: all four links parse; page 0, 605, other schemes and garbage return null. Tests in `test/features/widgets/widget_sync_test.dart` with a fake sink and clock: debounce, sending on pause, no send when the hash is unchanged, and a send after a language change within 2 s.
- [X] T024 [P] Kotlin tests `android/app/src/test/kotlin/app/mathani/mathani/widgets/SnapshotTest.kt`: parse the contract example, reject `v: 2` and unordered entries, check `nextEntry` at, just before and just after an `atUtc`, and check `isExpired`. Swift tests `ios/RunnerTests/WidgetSnapshotTests.swift` cover the same cases for `ios/Shared/WidgetSnapshot.swift` (add `ios/Shared` to the RunnerTests target in T003's script).

**Checkpoint**: the app sends a snapshot (labels only) to both phones, and widget links open the right screens when sent with `adb shell am start` / `xcrun simctl openurl`.

## Phase 3: User Story 1 - Next prayer on the home screen (P1) 🎯 MVP

**Goal**: small and medium Prayer widgets on iPhone and Android that move on at each prayer time
without the app.

**Independent Test**: quickstart scenarios 1–6.

### Tests for User Story 1

- [X] T025 [P] [US1] Tests in `test/features/widgets/widget_snapshot_prayer_test.dart`, with fixtures for Cairo, London (DST change on 2026-03-29) and Mecca:
  - `entries` has "exactly 40 items, ascending, each `atUtc` unique";
  - "Sunrise is excluded";
  - `days` has 8 items;
  - `validUntilUtc` = last `atUtc` + 60 s;
  - names and times match `PrayerController` for the same place and method;
  - Friday Dhuhr is named Jumu'ah (specs/015);
  - Arabic uses the app's numerals;
  - `prayer` is null with no place;
  - the built JSON is ≤ 16 KB.
- [X] T026 [P] [US1] Swift tests in `ios/RunnerTests/PrayerTimelineTests.swift`: the timeline builder (T029) produces one entry per prayer from now, plus a final `openToUpdate` entry at `validUntilUtc`, with policy `.never`. It gives a not set up entry for a nil prayer block, and drops entries already in the past.
- [X] T027 [P] [US1] Kotlin tests in `android/app/src/test/kotlin/app/mathani/mathani/widgets/WidgetAlarmsTest.kt`: the next alarm time is the next `atUtc` (or `validUntilUtc` after the last), there is no alarm when expired or no snapshot, and the medium layout's highlighted row index is correct.

### Implementation for User Story 1

- [X] T028 [US1] Fill `PrayerBlock` in `WidgetSnapshot.build` (`lib/features/widgets/widget_snapshot.dart`):
  - use `services.calculator.schedule` for today plus 7 days at `prayer.state.currentPlace` with its method;
  - the five prayers per day (no sunrise) as UTC ms;
  - names from the existing prayer copy (`lib/features/prayer_times/prayer_copy.dart`), with Jumu'ah on Fridays;
  - times formatted in the place's time zone (`prayer_time_zones.dart`) with the app's numerals;
  - day labels;
  - `validUntilUtc`.

  Make `WidgetSync` also rebuild when the prayer alert refill runs (`lib/features/prayer_times/prayer_alerts.dart` hub).
- [X] T029 [US1] Create `ios/Shared/PrayerTimeline.swift`: `func prayerEntries(snapshot:now:) -> [PrayerEntryModel]` and the `TimelineProvider` `PrayerProvider` (placeholder, snapshot, timeline with `.never` policy) in `ios/MathaniWidgets/PrayerWidget.swift`, reading `WidgetSnapshot.load(suite: "group.com.mthani.app")`.
- [X] T030 [US1] Write the SwiftUI views in `ios/MathaniWidgets/PrayerWidget.swift`:
  - **systemSmall**: place, `labels.next`, name, time, `Text(entry.nextDate, style: .timer)` with `.environment(\.locale, Locale(identifier: lang))`.
  - **systemMedium**: day label + five rows with the next highlighted.
  - **States**: not set up / `openToUpdate`.
  - **RTL**: `layoutDirection` from `rtl`.
  - **Large text**: the dynamic type fallback (the small widget shows name + time only at accessibility sizes).
  - **Accessibility**: `accessibilityLabel` from `labels.a11yNext`.
  - **Tap**: `widgetURL(URL("mathani-widget://prayer"))`.
  - **Backgrounds**: `containerBackground` behind an `if #available(iOS 17, *)` helper.

  Kind string `"prayer"`. Register it in `MathaniWidgetsBundle.swift`, with `configurationDisplayName`/`description` from `ios/MathaniWidgets/Localizable.xcstrings` (en, ar) and `supportedFamilies([.systemSmall, .systemMedium])`.
- [X] T031 [P] [US1] Write the Android layouts:
  - `android/app/src/main/res/layout/widget_prayer_small.xml` (place, next label, name, time, `Chronometer` with `android:countDown="true"`);
  - `widget_prayer_medium.xml` (place/day + five rows);
  - `widget_prayer_message.xml` (Mathani mark + one line);
  - colors in `res/values/widget_colors.xml` and `values-v31/` using `@android:color/system_accent1_*`/`system_neutral1_*`, plus `values-night`;
  - corners via `@android:dimen/system_app_widget_background_radius` on v31.
- [X] T032 [P] [US1] Write `android/app/src/main/res/xml/widget_prayer_info.xml`:
  - `minWidth`/`minHeight` 110dp, `targetCellWidth="2" targetCellHeight="2"`;
  - `resizeMode="horizontal|vertical"`, `maxResizeWidth` for 4×2;
  - `widgetCategory="home_screen"` (keyguard added in US3);
  - `updatePeriodMillis="0"`;
  - `previewLayout`/`previewImage`, `description="@string/widget_prayer_description"`.

  Add the picker strings `widget_prayer_name`/`widget_prayer_description` and the no-snapshot text in `res/values/widget_strings.xml` and `values-ar/widget_strings.xml`.
- [X] T033 [US1] Create `android/app/src/main/kotlin/app/mathani/mathani/widgets/PrayerWidgetProvider.kt`:
  - **Updates**: `onUpdate`/`onAppWidgetOptionsChanged` build the RemoteViews from `SnapshotStore`.
  - **Sizes**: on API 31+, `RemoteViews(mapOf(SizeF(110f,110f) to small, SizeF(250f,110f) to medium))`; below, pick by `OPTION_APPWIDGET_MIN_WIDTH`.
  - **Countdown**: `setChronometerCountDown(true)` + `setChronometer(id, SystemClock.elapsedRealtime() + (atUtc - now), null, true)`.
  - **Layout**: RTL via `setInt(root, "setLayoutDirection", …)`, and the message layout for not set up / expired.
  - **Accessibility**: `setContentDescription` from `labels.a11yNext`.
  - **Tap**: an immutable `PendingIntent` to `MainActivity` with action `app.mathani.OPEN_WIDGET` and `link=mathani-widget://prayer`.

  Register the receiver in `android/app/src/main/AndroidManifest.xml` with the `APPWIDGET_UPDATE` filter and the `@xml/widget_prayer_info` meta-data.
- [X] T034 [US1] Create `android/app/src/main/kotlin/app/mathani/mathani/widgets/WidgetAlarms.kt` and `WidgetRefresher.kt`:
  - **`refreshAll`** updates all provider ids, then schedules one alarm (request code distinct from prayer alerts) at the next `atUtc` or at `validUntilUtc`. Use `setExactAndAllowWhileIdle` when `PrayerNotificationsPlugin.exact(context)`, otherwise `setWindow(RTC, t, 60_000)`, accepting the delay noted in research R3.
  - **`WidgetTickReceiver`** handles the alarm, `ACTION_TIME_CHANGED`, `ACTION_TIMEZONE_CHANGED`, `ACTION_DATE_CHANGED`, `ACTION_LOCALE_CHANGED` and `BOOT_COMPLETED` (the app already holds the boot permission for prayer alerts) by calling `refreshAll`.

  Register it in the manifest (not exported, except for the system broadcasts it needs).
- [X] T035 [US1] Make `WidgetsPlugin.update` in `android/app/src/main/kotlin/app/mathani/mathani/widgets/WidgetsPlugin.kt` (T020) call `WidgetRefresher.refreshAll` when the hash changes. Do not call it from `PrayerAlarmReceiver`: widget redraws have their own alarm (T034), so the two stay uncoupled.

**Checkpoint**: US1 passes quickstart 1–6 on both phones. This is the MVP.

## Phase 4: User Story 2 - Continue reading or today's wird (P1)

**Goal**: small and medium Quran widgets that open the right page in one tap.

**Independent Test**: quickstart scenarios 7–9.

### Tests for User Story 2

- [X] T036 [P] [US2] Tests in `test/features/widgets/widget_snapshot_quran_test.dart`:
  - `start` when never read;
  - `continue` with surah/"Page 23 · Juz 2" and link `mathani-widget://mushaf/23`;
  - `wird` with from/to and link `mathani-widget://khatma/read`;
  - `wirdDone` with link `mathani-widget://khatma`;
  - a paused khatma gives `continue` + `progress.paused`;
  - `percent` is 0–100 and matches `pagesRead`/`pagesTotal`;
  - group khatma readings never appear in the JSON (FR-003).

### Implementation for User Story 2

- [X] T037 [US2] Fill `QuranBlock` in `WidgetSnapshot.build` from `KhatmaController` (`isActive`, `isPaused`, `currentWird`, `todayRead`, `pagesRead`, `pagesTotal`) and `ReaderController.page`/header ayah, using the Quran index for surah names and juz, and the app's numerals. Make sure `WidgetSync` listens to the reader's settled page (`onMushafPageShown`) through the debounce.
- [X] T038 [P] [US2] Create `ios/MathaniWidgets/QuranWidget.swift` (kind `"quran"`, systemSmall/systemMedium):
  - title/line1/line2, and a progress bar + `progress.text` on medium;
  - a check mark for `wirdDone`;
  - `widgetURL` from `quran.link`;
  - RTL, the large-text fallback and the accessibility label;
  - the timeline is a single entry with `.never` (it changes only with a snapshot reload).

  Add it to the bundle and to `Localizable.xcstrings`.
- [X] T039 [P] [US2] Create the Android layouts `res/layout/widget_quran_small.xml` and `widget_quran_medium.xml` (with a `ProgressBar` styled for widgets), `res/xml/widget_quran_info.xml` (same sizing rules as T032), and the picker strings in both `widget_strings.xml` files.
- [X] T040 [US2] Create `android/app/src/main/kotlin/app/mathani/mathani/widgets/QuranWidgetProvider.kt`, mirroring T033: responsive sizes, the message state when there is no snapshot, and a `PendingIntent` with `link = quran.link` (unique request code per link so the extras are not merged). Register it in the manifest and include it in `WidgetRefresher.refreshAll`.

**Checkpoint**: US1 + US2 cover all phone home screen widgets.

## Phase 5: User Story 3 - Lock screen (P2)

**Goal**: lock screen widgets on iPhone (iOS 16+) and Android phones that offer it.

**Independent Test**: quickstart scenarios 10–11.

- [X] T041 [US3] In `ios/MathaniWidgets/PrayerWidget.swift`, add the `@available(iOS 16, *)` families:
  - `accessoryCircular` (`Gauge` from the previous `atUtc` to the next, with a short name and time);
  - `accessoryRectangular` (name, time, timer);
  - `accessoryInline` ("Asr 3:12 PM").

  Use `widgetRenderingMode`-aware styling, and build `supportedFamilies` conditionally so iOS 15 still gets only the home screen families.
- [X] T042 [US3] Create `ios/MathaniWidgets/KhatmaWidget.swift` (kind `"khatma"`, iOS 16+ only, wrapped in `if #available` in the bundle):
  - `accessoryCircular`: a `percent` gauge with a check when `todayRead`;
  - `accessoryRectangular`: `progress.text` + the done label or the wird start;
  - no khatma: the Mathani mark + `labels.noKhatma`, linking to `mathani-widget://khatma`;
  - otherwise `widgetURL(quran.link)`.

  Add it to `Localizable.xcstrings`.
- [X] T043 [P] [US3] Change `widgetCategory` to `home_screen|keyguard` in `android/app/src/main/res/xml/widget_prayer_info.xml` and `widget_quran_info.xml`. Check that the small layouts fit the lock screen hub's cell, and that a tap goes through the system unlock (no `showWhenLocked` on `MainActivity`).
- [X] T044 [US3] Check that the lock screen content is limited to prayer names, times and progress: no `quran.line1/line2` on iOS accessory families (they could show the reading place on a locked phone). Document this in `contracts/widget-surfaces.md` if it is narrowed further.

## Phase 6: User Story 4 - Next prayer on the watch (P2)

**Goal**: prayer complications, a glance card and the one-screen watch app on Apple Watch and Wear
OS together (FR-024).

**Independent Test**: quickstart scenarios 15–18.

### Tests for User Story 4

- [X] T045 [P] [US4] Tests in `test/features/widgets/watch_copy_test.dart`: `WatchCopy.from` keeps `prayer` whole, keeps only `percent`, `todayRead`, `paused` and `text` of the khatma, carries the watch labels subset (including `setPlaceWatch`), never carries `quran.line1/line2` or the reading place, and stays ≤ 16 KB.
- [X] T046 [P] [US4] Kotlin tests in `android/wear/src/test/kotlin/app/mathani/wear/PrayerTimelineTest.kt`: the complication timeline entries from a copy (one per prayer, the countdown target is the next `atUtc`, a final expired entry at `validUntilUtc`), the tile timeline validity windows, and a newer `madeAtUtc` replacing an older one while an older one is ignored.

### Implementation for User Story 4

- [X] T047 [US4] iPhone side in `ios/Runner/WidgetBridge.swift` + `ios/Runner/AppDelegate.swift`: activate `WCSession` at launch if supported. On `update`, if `isPaired && isWatchAppInstalled`, call `updateApplicationContext(["watch": json])`. When the prayer or khatma part changed and `isComplicationEnabled` and `remainingComplicationUserInfoTransfers > 0`, also call `transferCurrentComplicationUserInfo` (contracts/watch-sync.md).
- [X] T048 [US4] Create `ios/MathaniWatch/WatchStore.swift`: a `WCSessionDelegate` that, on `didReceiveApplicationContext`/`didReceiveUserInfo` and at launch from `receivedApplicationContext`, keeps the copy only if `madeAtUtc` is newer, saves it to `UserDefaults(suiteName: "group.com.mthani.app.watch")` and calls `WidgetCenter.shared.reloadAllTimelines()`. Decode with `ios/Shared/WidgetSnapshot.swift` (add a `WatchCopy` struct there).
- [X] T049 [US4] Write `ios/MathaniWatch/MathaniWatchApp.swift` + `TodayView.swift`: one `List` with the place name and today's five times (the day from `days` containing now), the next one marked, `layoutDirection` from `rtl`, and the `setPlaceWatch`/`openToUpdate` message when there are no valid times. No other screens (FR-021).
- [X] T050 [US4] Create `ios/MathaniWatchWidgets/WatchPrayerWidget.swift` (kind `"watchPrayer"`), using `PrayerTimeline.swift` with the watch suite:
  - `accessoryCircular` (gauge + short name), `accessoryCorner`, `accessoryInline`;
  - `accessoryRectangular` (the Smart Stack card: the next prayer large plus today's other times in a compact row, falling back to next + following at accessibility sizes);
  - `TimelineEntryRelevance` rising in the 30 minutes before each prayer;
  - no place → the Mathani mark / `setPlaceWatch`;
  - tapping opens the watch app (the default).
- [X] T051 [US4] Phone side for Wear in `android/app/src/main/kotlin/app/mathani/mathani/widgets/WearSync.kt`: on `update`, if `GoogleApiAvailability` reports success, `PutDataMapRequest.create("/mathani/widgets")` with `watch` and `madeAtUtc`, `.setUrgent()`, `Wearable.getDataClient(context).putDataItem`. Failures are logged and ignored. Add `com.google.android.gms:play-services-wearable` to `android/app/build.gradle.kts` with a comment citing research R6.
- [X] T052 [US4] Create `android/wear/src/main/kotlin/app/mathani/wear/CopyStore.kt` (`SharedPreferences("mathani_watch_copy")`, parse, newer-wins, `nextEntry`, `isExpired`) and `SnapshotListenerService.kt` (`WearableListenerService`, `onDataChanged` for path `/mathani/widgets` → store → `ComplicationDataSourceUpdateRequester.create(…).requestUpdateAll()` for each source + `TileService.getUpdater(this).requestUpdate(PrayerTileService::class.java)`). Add a first-run fallback that reads `DataClient.getDataItems(Uri.parse("wear://*/mathani/widgets"))`. Declare the service in the manifest with the `DATA_CHANGED` filter, `wear` scheme and `pathPrefix="/mathani/widgets"`.
- [X] T053 [US4] Create `android/wear/src/main/kotlin/app/mathani/wear/MainActivity.kt`: Compose for Wear `AppScaffold` + `TransformingLazyColumn`. It shows the place, today's five times with the next marked, RTL from the copy, and the message states. Ambient-safe (no animation), round-screen padding.
- [X] T054 [US4] Create `android/wear/src/main/kotlin/app/mathani/wear/PrayerComplicationService.kt` (`SuspendingComplicationDataSourceService`):
  - types `SHORT_TEXT` (`TimeDifferenceComplicationText` to the next `atUtc`, title = name), `LONG_TEXT` and `RANGED_VALUE` (elapsed between prayers);
  - returns a `ComplicationDataTimeline` with one entry per prayer and a final `openToUpdate` entry;
  - `NoDataComplicationData` with the Mathani icon when there is no place;
  - preview data;
  - tap → `MainActivity`.

  Declare it in the manifest with `SUPPORTED_TYPES`, `UPDATE_PERIOD_SECONDS=0` and the icon.
- [X] T055 [US4] Create `android/wear/src/main/kotlin/app/mathani/wear/PrayerTileService.kt` (`androidx.wear.tiles.TileService` + ProtoLayout Material3):
  - the place, today's five times with the next highlighted, and the countdown;
  - a `Timeline` with one entry per prayer and validity windows so the highlight moves on time;
  - a final `openToUpdate` entry;
  - the message state;
  - clicking opens `MainActivity`.

  Declare it in the manifest with the tile preview image and label strings (en, ar).
- [X] T056 [US4] Add a Wear bundle step to the release process in `docs/release.md` (`./gradlew :wear:bundleRelease`, upload to the same Play release as the phone bundle under the Wear OS form factor, versionCode rule `1_000_000 + build`), and the Apple Watch screenshots/watch app note for App Store submission (research R11).

**Checkpoint**: both watches show the next prayer from the phone's data and keep working with the
phone away.

## Phase 7: User Story 5 - Khatma progress on the watch (P3)

**Goal**: a khatma complication on both watches.

**Independent Test**: quickstart scenario 19.

- [X] T057 [P] [US5] Create `ios/MathaniWatchWidgets/WatchKhatmaWidget.swift` (kind `"watchKhatma"`): `accessoryCircular` and `accessoryCorner` with a `percent` gauge, a check when `todayRead`, and the neutral Mathani mark when `khatma` is null. Register it in `MathaniWatchWidgetsBundle.swift`.
- [X] T058 [P] [US5] Create `android/wear/src/main/kotlin/app/mathani/wear/KhatmaComplicationService.kt`: `RANGED_VALUE` (0–100 `percent`, with a check icon when `todayRead`) and `SHORT_TEXT` (`percent` text); `NoDataComplicationData` with the Mathani icon when there is no khatma; tap → `MainActivity`. Declare it in the manifest and request its update in `SnapshotListenerService` (T052).
- [X] T059 [US5] Make sure a change in `todayRead` or `percent` counts as a "khatma changed" for the prompt complication transfer in `ios/Runner/WidgetBridge.swift` (T047). Add a Kotlin test case for the khatma complication data to `android/wear/src/test/kotlin/app/mathani/wear/PrayerTimelineTest.kt`.

## Phase 8: Polish & Cross-Cutting

- [X] T060 Add `widgets_present` to the allowed list in `lib/features/analytics/usage.dart` and `specs/016-usage-analytics/contracts/usage-events.md`:
  - `kinds` is a sorted comma-joined subset of `prayer,quran,khatma`, or `none`;
  - `surface` is `phone`;
  - send it at most once per calendar day on resume, from `HomeWidgets.placed()` (last-sent day in the existing settings store);
  - add a test in `test/features/analytics/`.
- [ ] T061 [P] Accessibility and appearance pass on all widget layouts: light/dark, iOS 18 tinted and clear, Android dynamic colors, the largest text (fallback layouts, no clipping), and VoiceOver/TalkBack reading one sentence (quickstart 12–13). Fix the views in `ios/MathaniWidgets/`, `ios/MathaniWatchWidgets/`, `android/app/src/main/res/layout/widget_*.xml` and `android/wear/`.
- [ ] T062 [P] Widget picker previews: on Android, `previewLayout` (API 31+) and `previewImage` PNGs in `android/app/src/main/res/drawable-nodpi/widget_*_preview.png`; on iOS, the placeholder entries in the providers in both languages; and the Wear tile preview image.
- [X] T063 Run the size checks (`tool/size_check.dart android` on CI; the iOS thinned size from the release build in App Store Connect) and record the growth in the plan's "Size" section in `specs/017-home-watch-widgets/plan.md`. Call out anything over 1 MB in review (Principle IV, SC-009).
- [X] T064 [P] Update `docs/store/` listings: a widgets line in the description (en, ar), plus new Apple Watch and Wear OS screenshots. Check that `docs/store/privacy.md` needs no change: no new data is collected or shared.
- [ ] T065 Run every scenario in `specs/017-home-watch-widgets/quickstart.md` on the reference phones and watches. Record the results, the devices used and the battery check (SC-006) in `docs/release.md`.
- [X] T066 Update `specs/009-prayer-times/spec.md` Assumptions ("home-screen widgets" out of scope → "delivered by specs/017").

## Dependencies & Execution Order

- **Setup (T001–T010)**: T001/T002 are owner steps that can run any time before the first signed
  build. T003–T005 must land before any Swift work compiles in CI. T008–T009 come before Wear
  work.
- **Foundational (T011–T024)**: blocks all stories. T011 → T012 (labels) can overlap. Native
  plugins T017–T022 run in parallel with the Dart tasks.
- **US1 (T025–T035)** and **US2 (T036–T040)**: both need only Phase 2 and can run in parallel
  (different files). US2's providers reuse `WidgetRefresher` from T034, so do T034 before T040.
- **US3 (T041–T044)**: needs the US1 Prayer widget (T030, T033) and the US2 Quran block (T037)
  for the khatma accessory.
- **US4 (T045–T056)**: needs Phase 2 and the US1 prayer block (T028, T029). Apple Watch
  (T047–T050) and Wear (T051–T055) run in parallel; both must be done before release (FR-024).
- **US5 (T057–T059)**: needs US4's sync (T047–T048, T051–T052) and the US2 progress (T037).
- **Polish (T060–T066)**: after the stories it touches.

## Parallel Examples

```text
Phase 2: T013 (Dart platform pair) ‖ T017 (iOS bridge) ‖ T018 (iOS URL scheme) ‖ T019 (Android store) ‖ T022 (Swift model)
US1:     T025 ‖ T026 ‖ T027 (tests), then T030 (iOS views) ‖ T031–T033 (Android layouts and provider)
US2:     T038 (iOS) ‖ T039 (Android layouts), after T037
US4:     Apple Watch track T047 → T048 → T049 ‖ T050  ‖  Wear track T051 → T052 → T053 ‖ T054 ‖ T055
US5:     T057 ‖ T058
```

## Implementation Strategy

1. **MVP**: Setup (except the Wear parts) + Phase 2 + US1. The Prayer widget on both phones is a
   shippable release on its own (quickstart 1–6).
2. **Phone complete**: + US2 + US3, a second release if wanted (all phone widgets).
3. **Watches**: US4 + US5 together on Apple Watch and Wear OS, released as one, never one watch
   without the other (FR-024).
4. **Polish**: analytics, accessibility, previews, size and store work before each release that
   includes new surfaces.

## Implementation notes (2026-11-22)

Where the build differs from the task text:

- **T004**: the real Swift sources were written at once instead of placeholders.
- **T006**: the existing `ios` CI job already builds the app; a step was added for the Swift tests
  and the watch app build.
- **T010**: the Wear bundle is built to `build/wear/outputs/bundle/release/` (the project puts every
  module's build folder under the root `build/`).
- **T016**: `GroupCode.parse` already returns null for widget links (now covered by a test). The
  launch link is handed over only once, so a `LinkSplitter` shares it between `WidgetLinkHost` and
  `GroupLinkHost`.
- **T021**: widget taps use `ACTION_VIEW` with a `mathani-widget://` data URI on an explicit intent,
  which `DeviceChannel.noteLink` already handles, rather than a separate `OPEN_WIDGET` action.
- **T031**: the Android widgets use the app's own palette, not the system's dynamic colours.
- **T043**: `home_screen|keyguard` was set when the widget info files were created.
- **T054**: the Wear prayer complication offers `SHORT_TEXT` and `LONG_TEXT` only; a
  `RANGED_VALUE` fixed between timeline entries would stand still between prayers.
- **T055**: the Wear tile has no countdown; the highlight moves at each prayer through its timeline.

Still open:

- **T002**: Play's "Opt-in to Wear OS" step opens after the Wear screenshots (T064) and a Wear bundle
  on a testing track.
- **T061**, **T062**: need the widgets on real screens. The Android preview layouts (API 31+) and the
  iOS placeholders are in; the pre-Android-12 preview images and the Wear tile preview screenshot
  are not.
- **T065**: the quickstart on the reference phones and watches.
