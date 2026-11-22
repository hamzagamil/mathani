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

  @ViewBuilder private func content(now: Date) -> some View {
    if let snapshot, let block = snapshot.prayer, !block.isExpired(at: now), let next = block.next(after: now) {
      let day = block.day(of: next.date)
      List {
        Section {
          ForEach(day.entries, id: \.self) { e in
            HStack {
              Text(e.name).fontWeight(e == next ? .bold : .regular)
              Spacer()
              Text(e.time).monospacedDigit()
            }
            .foregroundColor(e == next ? .accentColor : .primary)
            .accessibilityElement(children: .combine)
          }
        } header: {
          VStack(alignment: .leading) {
            Text(block.place).lineLimit(1)
            Text(day.label).font(.caption2)
          }
        } footer: {
          Countdown(snapshot: snapshot, target: next.date)
        }
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
