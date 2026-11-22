import Foundation

/// What a prayer widget shows from a moment on (specs/017 research R2).
enum PrayerState: Equatable {
  /// No snapshot yet, or no place set.
  case notSetUp
  /// The 7 days of times ran out: "Open Mathani to update" (FR-008).
  case expired
  /// The next prayer, the one before it (for the ring), and the next prayer's day.
  case next(PrayerEntry, previous: PrayerEntry?, dayLabel: String, day: [PrayerEntry])
}

struct PrayerMoment: Equatable {
  let date: Date
  let state: PrayerState
}

/// One moment now, one at each later prayer time, and the end of the times. WidgetKit switches
/// between them on time without the app (FR-011), so the timeline needs no reload policy.
func prayerMoments(_ snapshot: WidgetSnapshot?, now: Date) -> [PrayerMoment] {
  guard let block = snapshot?.prayer else { return [PrayerMoment(date: now, state: .notSetUp)] }
  func state(at moment: Date) -> PrayerState {
    if block.isExpired(at: moment) { return .expired }
    guard let next = block.next(after: moment) else { return .expired }
    let day = block.day(of: next.date)
    return .next(next, previous: block.previous(before: next), dayLabel: day.label, day: day.entries)
  }
  var moments = [PrayerMoment(date: now, state: state(at: now))]
  for entry in block.entries where entry.date > now {
    moments.append(PrayerMoment(date: entry.date, state: state(at: entry.date)))
  }
  if block.validUntil > now {
    moments.append(PrayerMoment(date: block.validUntil, state: .expired))
  }
  return moments
}

/// The screen-reader sentence (FR-006).
func prayerAccessibility(_ snapshot: WidgetSnapshot, _ entry: PrayerEntry) -> String {
  snapshot.label("a11yNext")
    .replacingOccurrences(of: "{name}", with: entry.name)
    .replacingOccurrences(of: "{time}", with: entry.time)
}
