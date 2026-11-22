import SwiftUI
import WidgetKit

/// Mathani's watch face complications and Smart Stack card (specs/017 User Stories 4 and 5).
/// They read the copy the watch app keeps; a tap opens the watch app (FR-021).
@main
struct MathaniWatchWidgetsBundle: WidgetBundle {
  var body: some Widget {
    WatchPrayerWidget()
    WatchKhatmaWidget()
  }
}

struct WatchPrayerWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "watchPrayer", provider: PrayerProvider(suite: WidgetSnapshot.watchSuite)) {
      WatchPrayerView(entry: $0)
    }
    .configurationDisplayName(Text("widget.prayer.name"))
    .description(Text("widget.prayer.description"))
    .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
  }
}

struct WatchPrayerView: View {
  let entry: PrayerTimelineEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    Group {
      if family == .accessoryRectangular {
        card
      } else if family == .accessoryCorner {
        corner
      } else {
        PrayerAccessoryView(entry: entry, family: family)
      }
    }
    .snapshotLocale(entry.snapshot)
    .widgetBackground(Color.clear)
  }

  /// The Smart Stack card: the next prayer large and today's other times (contracts/widget-surfaces.md).
  @ViewBuilder private var card: some View {
    switch entry.state {
    case .notSetUp:
      Text(entry.snapshot?.label("setPlaceWatch") ?? NSLocalizedString("widget.setup", comment: ""))
        .font(.caption)
    case .expired:
      Text(entry.snapshot?.label("openToUpdate") ?? "").font(.caption)
    case let .next(next, _, _, day):
      if let s = entry.snapshot {
        VStack(alignment: .leading, spacing: 1) {
          HStack {
            Text(next.name).font(.headline).widgetAccentable()
            Spacer(minLength: 2)
            Text(next.time).font(.headline).monospacedDigit()
          }
          Countdown(snapshot: s, target: next.date).font(.caption2)
          if !typeSize.isAccessibilitySize {
            Text(day.filter { $0 != next }.map { "\($0.name) \($0.time)" }.joined(separator: " · "))
              .font(.caption2)
              .lineLimit(2)
              .minimumScaleFactor(0.7)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(prayerAccessibility(s, next))
      }
    }
  }

  @ViewBuilder private var corner: some View {
    switch entry.state {
    case let .next(next, previous, _, _):
      let start = previous?.date ?? next.date.addingTimeInterval(-3 * 3600)
      Text(next.time)
        .widgetCurvesContent()
        .widgetLabel {
          ProgressView(timerInterval: start...max(next.date, start.addingTimeInterval(60)), countsDown: false) {
            Text(next.name)
          }
        }
    default:
      Image(systemName: "book.closed")
    }
  }
}

struct WatchKhatmaEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot?
}

struct WatchKhatmaProvider: TimelineProvider {
  func placeholder(in context: Context) -> WatchKhatmaEntry { WatchKhatmaEntry(date: Date(), snapshot: nil) }
  func getSnapshot(in context: Context, completion: @escaping (WatchKhatmaEntry) -> Void) {
    completion(WatchKhatmaEntry(date: Date(), snapshot: WidgetSnapshot.load(suite: WidgetSnapshot.watchSuite)))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<WatchKhatmaEntry>) -> Void) {
    let entry = WatchKhatmaEntry(date: Date(), snapshot: WidgetSnapshot.load(suite: WidgetSnapshot.watchSuite))
    completion(Timeline(entries: [entry], policy: .never))
  }
}

/// Khatma progress on the watch face (specs/017 User Story 5).
struct WatchKhatmaWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "watchKhatma", provider: WatchKhatmaProvider()) { WatchKhatmaView(entry: $0) }
      .configurationDisplayName(Text("widget.khatma.name"))
      .description(Text("widget.khatma.description"))
      .supportedFamilies([.accessoryCircular, .accessoryCorner])
  }
}

struct WatchKhatmaView: View {
  let entry: WatchKhatmaEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    Group {
      if let s = entry.snapshot, let k = s.khatma {
        if family == .accessoryCorner {
          Image(systemName: k.todayRead ? "checkmark" : "book")
            .widgetLabel {
              Gauge(value: k.fraction) { Text(s.label("khatma")) }
            }
        } else {
          Gauge(value: k.fraction) {
            Text(s.label("khatma"))
          } currentValueLabel: {
            if k.todayRead { Image(systemName: "checkmark") } else { Text("\(k.percent)") }
          }
          .gaugeStyle(.accessoryCircularCapacity)
          .accessibilityLabel("\(s.label("khatma")): \(k.text)")
        }
      } else {
        // The neutral mark when there is no khatma.
        Image(systemName: "book.closed")
          .accessibilityLabel(entry.snapshot?.label("noKhatma") ?? "")
      }
    }
    .snapshotLocale(entry.snapshot)
    .widgetBackground(Color.clear)
  }
}
