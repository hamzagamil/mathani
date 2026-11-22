import SwiftUI
import WidgetKit

/// The iPhone prayer widget (specs/017 User Stories 1 and 3): home screen from iOS 15, lock
/// screen from iOS 16.
struct PrayerWidget: Widget {
  static let kind = "prayer"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: PrayerProvider(suite: WidgetSnapshot.phoneSuite)) {
      PrayerWidgetView(entry: $0)
    }
    .configurationDisplayName(Text("widget.prayer.name"))
    .description(Text("widget.prayer.description"))
    .supportedFamilies(Self.families)
  }

  static var families: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) {
      return [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
    }
    return [.systemSmall, .systemMedium]
  }
}

extension WidgetFamily {
  /// The lock screen families; none before iOS 16.
  var isAccessory: Bool {
    if #available(iOSApplicationExtension 16.0, *) {
      switch self {
      case .accessoryCircular, .accessoryRectangular, .accessoryInline: return true
      default: return false
      }
    }
    return false
  }
}

struct PrayerWidgetView: View {
  let entry: PrayerTimelineEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    content
      .snapshotLocale(entry.snapshot)
      .widgetURL(URL(string: "mathani-widget://prayer"))
  }

  @ViewBuilder private var content: some View {
    if #available(iOSApplicationExtension 16.0, *), family.isAccessory {
      PrayerAccessoryView(entry: entry, family: family)
        .widgetBackground(Color.clear)
    } else {
      system
        .foregroundColor(WidgetPalette.ink(scheme))
        .padding(family == .systemMedium ? 14 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetBackground(WidgetPalette.background(scheme))
    }
  }

  @ViewBuilder private var system: some View {
    switch entry.state {
    case .notSetUp:
      WidgetMessage(text: entry.snapshot?.label("setPlace") ?? NSLocalizedString("widget.setup", comment: ""))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .expired:
      WidgetMessage(text: entry.snapshot?.label("openToUpdate") ?? "")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case let .next(next, _, dayLabel, day):
      if let snapshot = entry.snapshot {
        if family == .systemMedium && !typeSize.isAccessibilitySize {
          medium(snapshot, next: next, dayLabel: dayLabel, day: day)
        } else {
          small(snapshot, next: next)
        }
      }
    }
  }

  /// Place, next prayer, its time and the time left; name and time only at the largest text.
  private func small(_ s: WidgetSnapshot, next: PrayerEntry) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(s.prayer?.place ?? "").font(.caption).foregroundColor(WidgetPalette.muted(scheme)).lineLimit(1)
      if !typeSize.isAccessibilitySize {
        Text(s.label("next")).font(.caption).foregroundColor(WidgetPalette.accent(scheme)).lineLimit(1)
      }
      Text(next.name).font(.title2.bold()).lineLimit(1).minimumScaleFactor(0.7)
      Text(next.time).font(.headline).lineLimit(1)
      if !typeSize.isAccessibilitySize {
        Countdown(snapshot: s, target: next.date).font(.caption).foregroundColor(WidgetPalette.muted(scheme))
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(prayerAccessibility(s, next))
  }

  /// The day of the next prayer, with it highlighted and its countdown.
  private func medium(_ s: WidgetSnapshot, next: PrayerEntry, dayLabel: String, day: [PrayerEntry]) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(s.prayer?.place ?? "").font(.subheadline.bold()).lineLimit(1)
        Text(dayLabel).font(.caption).foregroundColor(WidgetPalette.muted(scheme)).lineLimit(1)
        Spacer(minLength: 4)
        Countdown(snapshot: s, target: next.date).font(.caption).foregroundColor(WidgetPalette.accent(scheme))
      }
      ForEach(day, id: \.self) { e in
        HStack {
          Text(e.name).lineLimit(1)
          Spacer()
          Text(e.time).monospacedDigit().lineLimit(1)
        }
        .font(.subheadline)
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(e == next ? WidgetPalette.highlight(scheme) : Color.clear)
        )
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(prayerAccessibility(s, next))
  }
}
