import SwiftUI
import WidgetKit

/// One moment of the prayer timeline with the snapshot it came from.
struct PrayerTimelineEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot?
  let state: PrayerState
  var relevance: TimelineEntryRelevance?
}

/// The prayer timeline from a snapshot in an App Group: shared by the iPhone and watch widgets
/// (specs/017 research R2, R5).
struct PrayerProvider: TimelineProvider {
  let suite: String

  func placeholder(in context: Context) -> PrayerTimelineEntry {
    PrayerTimelineEntry(date: Date(), snapshot: nil, state: .notSetUp)
  }

  func getSnapshot(in context: Context, completion: @escaping (PrayerTimelineEntry) -> Void) {
    let snapshot = WidgetSnapshot.load(suite: suite)
    let now = Date()
    let first = prayerMoments(snapshot, now: now).first ?? PrayerMoment(date: now, state: .notSetUp)
    completion(PrayerTimelineEntry(date: now, snapshot: snapshot, state: first.state))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerTimelineEntry>) -> Void) {
    let snapshot = WidgetSnapshot.load(suite: suite)
    let entries = prayerMoments(snapshot, now: Date()).map {
      PrayerTimelineEntry(date: $0.date, snapshot: snapshot, state: $0.state, relevance: relevance($0))
    }
    // A new snapshot from the app reloads it; nothing to poll (research R9).
    completion(Timeline(entries: entries, policy: .never))
  }

  /// Higher in the 30 minutes before a prayer, so the Smart Stack shows the card then (R5).
  private func relevance(_ moment: PrayerMoment) -> TimelineEntryRelevance? {
    guard case let .next(next, _, _, _) = moment.state else { return nil }
    let soon = next.date.addingTimeInterval(-30 * 60)
    return moment.date >= soon
      ? TimelineEntryRelevance(score: 1, duration: next.date.timeIntervalSince(moment.date))
      : TimelineEntryRelevance(score: 0.2)
  }
}

/// The small prayer widgets of the lock screen and the watch face (contracts/widget-surfaces.md).
@available(iOS 16.0, watchOS 9.0, *)
struct PrayerAccessoryView: View {
  let entry: PrayerTimelineEntry
  let family: WidgetFamily

  var body: some View {
    Group {
      switch entry.state {
      case .notSetUp, .expired:
        Image(systemName: "book.closed")
          .accessibilityLabel(entry.snapshot?.label(entry.state == .expired ? "openToUpdate" : "setPlace") ?? "")
      case let .next(next, previous, _, _):
        if let s = entry.snapshot { view(s, next: next, previous: previous) }
      }
    }
  }

  @ViewBuilder private func view(_ s: WidgetSnapshot, next: PrayerEntry, previous: PrayerEntry?) -> some View {
    let start = previous?.date ?? next.date.addingTimeInterval(-3 * 3600)
    switch family {
    case .accessoryInline:
      Text("\(next.name) \(next.time)")
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 0) {
        Text(s.prayer?.place ?? "").font(.caption2).lineLimit(1).widgetAccentableIfAvailable()
        Text("\(next.name) \(next.time)").font(.headline).lineLimit(1).minimumScaleFactor(0.7)
        Countdown(snapshot: s, target: next.date).font(.caption)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(prayerAccessibility(s, next))
    default:
      // Circular (and the watch corner): a ring of the time between the two prayers, which
      // WidgetKit moves by itself.
      ProgressView(timerInterval: start...max(next.date, start.addingTimeInterval(60)), countsDown: false) {
        Text(next.name)
      } currentValueLabel: {
        Text(next.name).minimumScaleFactor(0.4).lineLimit(1)
      }
      .progressViewStyle(.circular)
      .accessibilityLabel(prayerAccessibility(s, next))
    }
  }
}

extension View {
  @ViewBuilder func widgetAccentableIfAvailable() -> some View {
    if #available(iOS 16.0, watchOS 9.0, *) { widgetAccentable() } else { self }
  }
}
