import SwiftUI
import WidgetKit

struct QuranTimelineEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot?
}

/// One entry: the Quran widget changes only when the app sends a new snapshot.
struct QuranProvider: TimelineProvider {
  func placeholder(in context: Context) -> QuranTimelineEntry { QuranTimelineEntry(date: Date(), snapshot: nil) }

  func getSnapshot(in context: Context, completion: @escaping (QuranTimelineEntry) -> Void) {
    completion(QuranTimelineEntry(date: Date(), snapshot: WidgetSnapshot.load(suite: WidgetSnapshot.phoneSuite)))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<QuranTimelineEntry>) -> Void) {
    let entry = QuranTimelineEntry(date: Date(), snapshot: WidgetSnapshot.load(suite: WidgetSnapshot.phoneSuite))
    completion(Timeline(entries: [entry], policy: .never))
  }
}

/// The iPhone Quran widget (specs/017 User Story 2): today's wird, or where the reader stopped.
struct QuranWidget: Widget {
  static let kind = "quran"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: QuranProvider()) { QuranWidgetView(entry: $0) }
      .configurationDisplayName(Text("widget.quran.name"))
      .description(Text("widget.quran.description"))
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct QuranWidgetView: View {
  let entry: QuranTimelineEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    content
      .foregroundColor(WidgetPalette.ink(scheme))
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .widgetBackground(WidgetPalette.background(scheme))
      .snapshotLocale(entry.snapshot)
      .widgetURL(URL(string: entry.snapshot?.quran?.link ?? "mathani-widget://mushaf/1"))
  }

  @ViewBuilder private var content: some View {
    if let q = entry.snapshot?.quran {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          if q.mode == "wirdDone" {
            Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
          }
          Text(q.title).font(.subheadline.bold()).lineLimit(2)
        }
        .foregroundColor(WidgetPalette.accent(scheme))
        if !q.line1.isEmpty { Text(q.line1).font(.headline).lineLimit(1).minimumScaleFactor(0.7) }
        if !q.line2.isEmpty && !typeSize.isAccessibilitySize {
          Text(q.line2).font(.subheadline).foregroundColor(WidgetPalette.muted(scheme)).lineLimit(1)
        }
        if family == .systemMedium, let p = q.progress, !typeSize.isAccessibilitySize {
          ProgressView(value: p.fraction).tint(WidgetPalette.accent(scheme)).padding(.top, 6)
          Text(p.text).font(.caption).foregroundColor(WidgetPalette.muted(scheme)).lineLimit(1)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel([q.title, q.line1, q.line2].filter { !$0.isEmpty }.joined(separator: ", "))
    } else {
      WidgetMessage(text: NSLocalizedString("widget.setup", comment: ""))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
