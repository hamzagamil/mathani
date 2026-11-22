# Platform Research: Widgets on Phones and Watches

**Feature**: [spec.md](spec.md) | **Date**: 2026-11-22

The user asked for research on Android phone and watch widgets. This note covers all four
platforms so they can be compared. It feeds `/speckit-plan`; the spec itself stays free of
technical detail.

## Summary

| | iPhone | Android phone | Apple Watch | Wear OS watch |
|---|---|---|---|---|
| Where widgets show | Home screen, Today view, lock screen (iOS 16+), StandBy (iOS 17+) | Home screen; lock screen on some phones from Android 16 QPR1 | Watch face complications, Smart Stack (watchOS 10+) | Watch face complications, tiles; "Wear Widgets" from Wear OS 7 |
| Sizes | Small, medium, large; lock screen circular, rectangular, inline | Resizable grid cells (for example 2×1, 2×2, 4×2) | Circular, rectangular, corner, inline | Complication shapes (short text, ranged value…); full-screen tile, or small/large widget cards on Wear OS 7 |
| UI written in | SwiftUI (WidgetKit) | Kotlin: Jetpack Glance or RemoteViews | SwiftUI (WidgetKit) | Kotlin: complication data service; tiles (ProtoLayout) or Wear Widgets (Glance + Remote Compose) |
| Can Flutter draw it? | No. Flutter passes data; the widget is native | No. Same | No. Flutter does not run on watchOS | No. Complications and tiles are native |
| Needs app on the device? | Main app | Main app | **Yes, a watchOS app** that contains the widgets | **Yes, a Wear OS app** installed on the watch |
| Phone → widget data | Shared App Group storage | Shared preferences / files | WatchConnectivity from the iPhone | Wearable Data Layer from the phone |
| Live countdown without updates | Yes (timer text style) | Yes (Chronometer countdown, TextClock) | Yes (timer text) | Yes (time-based complication text) |

## iPhone

- **WidgetKit** has existed since iOS 14, so Mathani's iOS 15 minimum is fine for home screen
  widgets. Lock screen widgets need iOS 16, interactive buttons need iOS 17, tinted and clear
  home screens arrived in iOS 18 and iOS 26.
- Widgets are refreshed by **timelines**: the app gives a list of entries with the time each
  should show (for example one entry per prayer for 7 days). The system switches entries on time
  without running the app. Reloads are rationed (tens per day), so the timeline approach is the
  way to keep prayer widgets on time.
- iOS 18 added **Controls** (Control Center, lock screen, Action button). Not needed for v1.
- **Flutter**: the widget extension is written in SwiftUI. The `home_widget` package (used in
  Google's Flutter codelab) is a data bridge: Dart writes the snapshot into a shared App Group,
  and asks the widget to reload. Packages that render Flutter widgets into images exist but are
  young and add size; native SwiftUI is the safer choice.

## Apple Watch

- Watch complications and Smart Stack widgets are WidgetKit widgets built for watchOS (watchOS 9
  for complications, watchOS 10 for the Smart Stack). They must be shipped inside a **watchOS
  app**, so Apple Watch widgets mean adding a watch app target, however small.
- watchOS 26 lets **iPhone app Controls** appear on the watch without a watch app, and iPhone
  **Live Activities** show in the Smart Stack since watchOS 11. Neither gives a prayer
  complication on the watch face, so they do not replace a watch app for this feature.
- **Data**: the iPhone app sends the prayer schedule with WatchConnectivity (there is a channel
  reserved for complication updates). The watch keeps it and builds its own timeline, so it works
  with the iPhone away.
- **Relevance**: watchOS 26 lets widgets say when they are relevant (time, place), so a prayer
  card can rise in the Smart Stack near prayer time.

## Android phone

- **App widgets** work on every Android version Mathani supports (API 24+). Android 12 (API 31)
  brought the modern look: rounded corners, dynamic colours, responsive sizes, better picker
  previews. Android 15 added generated previews in the picker.
- **Jetpack Glance** is Google's current way to build widgets, with Compose-style code; it turns
  into RemoteViews underneath and supports old Android versions.
- **Updates**: the periodic update is at most every 30 minutes and is not exact. To change the
  prayer on time, the widget uses a countdown/clock view that ticks by itself, and the app
  schedules an alarm at each prayer time to redraw it (Mathani already schedules prayer alarms in
  specs/009). Battery saver and Doze can delay non-exact work.
- **Lock screen**: Google brought widgets to phone lock screens with Android 16 QPR1 (shown in a
  lock screen panel, sometimes only while charging or docked; the phone maker decides). Apps can
  keep a widget off the lock screen with the `not_keyguard` category. A widget that opens the app
  from the lock screen asks the user to unlock first. Samsung and other makers have their own lock
  screen widget rules; few phones have this yet, so it is "works where available".
- **Flutter**: same as iOS. `home_widget` passes the data; the widget is Kotlin (Glance).

## Wear OS watch

- Wear OS runs on Pixel Watch, Samsung Galaxy Watch 4 and later, and watches from other makers.
  Huawei, Xiaomi band/watch, Garmin and Fitbit trackers use other systems and are not covered.
- **A Wear OS app is needed**. It is a separate app module, published in the same Play listing
  as the phone app, and installed on the watch (the Play Store on the phone can offer it).
- **Complications**: a complication data service gives short text (for example "Asr 3:12"), a
  time-until countdown or a progress value. Users put it on any watch face that accepts it.
  Google recommends complications for one item checked many times a day, which fits the next
  prayer.
- **Tiles → Wear Widgets**: until 2026 the glance view was a full-screen **tile**. At Google I/O
  2026 Google announced **Wear Widgets** in Wear OS 7: small and large cards like the phone's 2×1
  and 2×2 widgets, built with Jetpack Glance and the new Remote Compose. One service can serve
  both: a widget on Wear OS 7, a tile on older watches (backwards compatible to Wear OS 4).
  Remote Compose was still in alpha in October 2026, so the plan should either use tiles
  (stable) now and move later, or accept an alpha library. Tiles are supported but will be phased
  out over time.
- **Data**: the phone app sends the schedule to the watch with the Wearable Data Layer (needs
  Google Play services on both devices). The watch keeps it and works with the phone away.
- **Flutter**: a Flutter app can run on Wear OS, but complications and tiles/widgets must be
  native Kotlin. A small native Wear OS app (Kotlin, Compose for Wear OS) is simpler and smaller
  than a Flutter one.

## What this means for the plan

1. **Phones first**: one shared "widget snapshot" written by the Flutter app; native widgets on
   each OS read it. Small size cost (well under 1 MB each).
2. **Both watches need a small native watch app**. This is the main cost. Decided 2026-11-22:
   the watch app is one screen with today's times (FR-021), and Apple Watch and Wear OS ship
   together (FR-024), so the Remote Compose alpha question must be settled in the plan (tiles now,
   or Wear Widgets on the alpha library).
3. **Prayer times as a schedule, not live**: every surface gets 7 days of times ahead so it
   changes on time without waking the app, which keeps battery use low (Principle IV).
4. **Parity**: Apple Watch and Wear OS need different code and testing; shipping Wear OS later
   would need a documented gap under constitution Principle I.

## Sources

- [What's New in Wear OS 7 (Android Developers Blog, May 2026)](https://android-developers.googleblog.com/2026/05/whats-new-wear-os-7.html)
- [Migrate from tiles to widgets (Wear OS docs)](https://developer.android.com/training/wearables/widgets/migration)
- [Wear OS user interfaces](https://developer.android.com/training/wearables/user-interfaces)
- [Remote Compose version status (GitHub issue, Oct 2026)](https://github.com/nikosavola/ClockifyWearOS/issues/24)
- [Widgets on lock screen FAQ (Android Developers Blog, Mar 2025)](https://android-developers.googleblog.com/2025/03/widgets-on-lock-screen-faq.html?hl=en)
- [Widgets on phone lock screens with Android 16 QPR1 (Android Central)](https://www.androidcentral.com/apps-software/google-is-bringing-widgets-to-phone-lock-screens-with-android-16-qpr1)
- [What's new in widgets, WWDC25](https://developer.apple.com/videos/play/wwdc2025/278/)
- [watchOS 26: iPhone controls on Apple Watch (iDownloadBlog)](https://www.idownloadblog.com/2025/06/16/watchos-26-iphone-controls-apple-watch-control-center-action-button-smart-stack-widget/)
- [watchOS 26 review (MacStories)](https://www.macstories.net/stories/watchos-26-the-macstories-review/4/)
- [Adding a Home Screen widget to your Flutter app (Google codelab)](https://codelabs.developers.google.com/flutter-home-screen-widgets)
