import SwiftUI
import WidgetKit

/// The app's colours (lib/app/theme/tokens.dart), light and dark.
enum WidgetPalette {
  static func background(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 0x16 / 255, green: 0x26 / 255, blue: 0x3F / 255)
      : Color(red: 0xFB / 255, green: 0xF6 / 255, blue: 0xF0 / 255)
  }
  static func ink(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 0xED / 255, green: 0xE4 / 255, blue: 0xD3 / 255)
      : Color(red: 0x18 / 255, green: 0x31 / 255, blue: 0x59 / 255)
  }
  static func muted(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 0xA7 / 255, green: 0xAE / 255, blue: 0xBD / 255)
      : Color(red: 0x4C / 255, green: 0x54 / 255, blue: 0x66 / 255)
  }
  static func accent(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 0xD9 / 255, green: 0xBD / 255, blue: 0x82 / 255)
      : Color(red: 0x75 / 255, green: 0x57 / 255, blue: 0x28 / 255)
  }
  static func highlight(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 0x2B / 255, green: 0x2B / 255, blue: 0x26 / 255)
      : Color(red: 0xEA / 255, green: 0xDC / 255, blue: 0xC0 / 255)
  }
}

extension View {
  /// The widget background: `containerBackground` from iOS 17 and watchOS 10, a plain background
  /// before (research R10).
  @ViewBuilder func widgetBackground(_ color: Color) -> some View {
    if #available(iOS 17.0, watchOS 10.0, *) {
      containerBackground(color, for: .widget)
    } else {
      background(color)
    }
  }

  /// The snapshot's language and direction, so text and the live timer match the app (FR-005).
  func snapshotLocale(_ snapshot: WidgetSnapshot?) -> some View {
    environment(\.locale, snapshot?.locale ?? .current)
      .environment(\.layoutDirection, (snapshot?.rtl ?? false) ? .rightToLeft : .leftToRight)
  }
}

/// "in 1:05:00": the snapshot's words around WidgetKit's live timer.
struct Countdown: View {
  let snapshot: WidgetSnapshot
  let target: Date

  var body: some View {
    HStack(spacing: 0) {
      Text(snapshot.label("inPrefix"))
      Text(target, style: .timer).monospacedDigit()
      Text(snapshot.label("inSuffix"))
    }
    .lineLimit(1)
  }
}

/// The Mathani mark and one line, for widgets with nothing to show yet.
struct WidgetMessage: View {
  let text: String
  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: "book.closed")
        .font(.title2)
        .accessibilityHidden(true)
      Text(text)
        .font(.footnote)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.8)
    }
  }
}
