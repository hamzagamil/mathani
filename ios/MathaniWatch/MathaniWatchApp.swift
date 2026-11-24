import SwiftUI
import WatchConnectivity

/// Mathani on Apple Watch (specs/017 FR-021): one screen with today's prayer times. Everything
/// else stays on the iPhone.
@main
struct MathaniWatchApp: App {
  @StateObject private var store = WatchStore.shared

  init() { WatchStore.shared.activate() }

  var body: some Scene {
    WindowGroup {
      TodayView(snapshot: store.snapshot)
    }
    // Data from the iPhone can arrive while the app is not running.
    .backgroundTask(.watchConnectivity) {
      WatchStore.shared.activate()
      while WCSession.default.hasContentPending {
        try? await Task.sleep(nanoseconds: 200_000_000)
      }
    }
  }
}

/// Today's five prayers at the place, the next one marked (contracts/widget-surfaces.md › Watch).
struct TodayView: View {
  let snapshot: WidgetSnapshot?

  var body: some View {
    TimelineView(.everyMinute) { context in
      content(now: context.date)
    }
    .environment(\.locale, snapshot?.locale ?? .current)
    .environment(\.layoutDirection, (snapshot?.rtl ?? false) ? .rightToLeft : .leftToRight)
  }

  /// Mathani's gold (lib/app/theme/tokens.dart, accentInk in the dark theme).
  private static let gold = Color(red: 0xD9 / 255, green: 0xBD / 255, blue: 0x82 / 255)

  @ViewBuilder private func content(now: Date) -> some View {
    if let snapshot, let block = snapshot.prayer, !block.isExpired(at: now), let next = block.next(after: now) {
      let day = block.day(of: next.date)
      // Compact rows, so the five prayers fit on one screen.
      ScrollView {
        VStack(alignment: .leading, spacing: 4) {
          Text(block.place).font(.headline).lineLimit(1)
          Text(day.label).font(.caption2).foregroundColor(.secondary)
          ForEach(day.entries, id: \.self) { e in
            let isNext = e == next
            HStack {
              Text(e.name).fontWeight(isNext ? .bold : .regular)
              Spacer(minLength: 4)
              Text(e.time).monospacedDigit()
            }
            .font(.body)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundColor(isNext ? .black : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 8).fill(isNext ? Self.gold : Color.clear))
            .accessibilityElement(children: .combine)
          }
          Countdown(snapshot: snapshot, target: next.date)
            .font(.footnote)
            .foregroundColor(Self.gold)
            .padding(.top, 2)
        }
        .padding(.horizontal, 4)
      }
    } else {
      ScrollView {
        WidgetMessage(text: message(now: now))
          .padding()
      }
    }
  }

  private func message(now: Date) -> String {
    guard let snapshot else { return NSLocalizedString("widget.setup", comment: "") }
    if let block = snapshot.prayer, block.isExpired(at: now) { return snapshot.label("openToUpdate") }
    return snapshot.label("setPlaceWatch")
  }
}
