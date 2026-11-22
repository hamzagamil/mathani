import SwiftUI
import WidgetKit

/// The khatma progress widget of the iPhone lock screen (specs/017 User Story 3), iOS 16 and later.
/// On iOS 15 it lists no families, so it is never offered.
struct KhatmaWidget: Widget {
  static let kind = "khatma"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: QuranProvider()) { KhatmaWidgetView(entry: $0) }
    .configurationDisplayName(Text("widget.khatma.name"))
    .description(Text("widget.khatma.description"))
    .supportedFamilies(Self.families)
  }

  static var families: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) { return [.accessoryCircular, .accessoryRectangular] }
    return []
  }
}

struct KhatmaWidgetView: View {
  let entry: QuranTimelineEntry
  var body: some View {
    if #available(iOSApplicationExtension 16.0, *) {
      KhatmaAccessoryView(entry: entry).widgetBackground(Color.clear)
    }
  }
}

/// Progress only: never the reading place or the wird's ayat on a locked phone (FR-003, T044).
@available(iOSApplicationExtension 16.0, *)
struct KhatmaAccessoryView: View {
  let entry: QuranTimelineEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    let s = entry.snapshot
    let progress = s?.quran?.progress
    Group {
      if let progress, let s {
        switch family {
        case .accessoryRectangular:
          VStack(alignment: .leading, spacing: 1) {
            Text(s.label("khatma")).font(.caption2).widgetAccentable()
            if progress.todayRead {
              Label(s.label("todayWirdDone"), systemImage: "checkmark").font(.headline).lineLimit(1)
            }
            Text(progress.text).font(.caption).lineLimit(2)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        default:
          Gauge(value: progress.fraction) {
            Text(s.label("khatma"))
          } currentValueLabel: {
            if progress.todayRead {
              Image(systemName: "checkmark")
            } else {
              Text("\(progress.percent)")
            }
          }
          .gaugeStyle(.accessoryCircularCapacity)
        }
      } else {
        Image(systemName: "book.closed").accessibilityLabel(s?.label("noKhatma") ?? "")
      }
    }
    .snapshotLocale(s)
    .widgetURL(URL(string: progress == nil ? "mathani-widget://khatma" : (s?.quran?.link ?? "mathani-widget://khatma")))
  }
}
