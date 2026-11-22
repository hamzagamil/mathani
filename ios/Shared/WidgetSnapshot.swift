import Foundation

/// The widget snapshot Dart builds (specs/017 contracts/widget-snapshot.md), and the watch copy
/// (contracts/watch-sync.md), which has `khatma` instead of `quran`. Compiled into the iPhone
/// widget extension, the watch app, the watch widget extension and RunnerTests.
struct WidgetSnapshot: Codable, Equatable {
  static let version = 1
  /// App Group of the iPhone app and its widgets.
  static let phoneSuite = "group.com.mthani.app"
  /// App Group of the watch app and its widgets.
  static let watchSuite = "group.com.mthani.app.watch"
  static let key = "widgetSnapshot"

  let v: Int
  let madeAtUtc: Int64
  let lang: String
  let rtl: Bool
  let labels: [String: String]
  let prayer: PrayerBlock?
  let quran: QuranBlock?
  /// Watch copy only.
  let khatma: KhatmaProgress?

  func label(_ key: String) -> String { labels[key] ?? "" }

  var locale: Locale { Locale(identifier: lang) }

  /// Nil for a newer version, broken JSON, or prayer times out of order: widgets then show the
  /// "not set up" state rather than wrong times.
  static func decode(_ data: Data) -> WidgetSnapshot? {
    guard let s = try? JSONDecoder().decode(WidgetSnapshot.self, from: data), s.v == version
    else { return nil }
    if let p = s.prayer, !p.isValid { return nil }
    return s
  }

  static func decode(_ text: String) -> WidgetSnapshot? { decode(Data(text.utf8)) }

  static func load(suite: String) -> WidgetSnapshot? {
    guard let text = UserDefaults(suiteName: suite)?.string(forKey: key) else { return nil }
    return decode(text)
  }
}

struct PrayerEntry: Codable, Hashable {
  let kind: String
  let atUtc: Int64
  let name: String
  let time: String

  var date: Date { Date(timeIntervalSince1970: TimeInterval(atUtc) / 1000) }
}

struct WidgetDay: Codable, Equatable {
  let startUtc: Int64
  let label: String

  var date: Date { Date(timeIntervalSince1970: TimeInterval(startUtc) / 1000) }
}

struct PrayerBlock: Codable, Equatable {
  let place: String
  let entries: [PrayerEntry]
  let days: [WidgetDay]
  let validUntilUtc: Int64

  var validUntil: Date { Date(timeIntervalSince1970: TimeInterval(validUntilUtc) / 1000) }

  /// Ascending with unique instants (contracts/widget-snapshot.md › Validation).
  var isValid: Bool {
    guard !entries.isEmpty else { return false }
    return zip(entries, entries.dropFirst()).allSatisfy { $0.atUtc < $1.atUtc }
  }

  /// The first entry after `now`: the one rule every platform uses.
  func next(after now: Date) -> PrayerEntry? { entries.first { $0.date > now } }

  /// The entry before `next`, for the ring of time elapsed between prayers.
  func previous(before next: PrayerEntry) -> PrayerEntry? {
    guard let i = entries.firstIndex(of: next), i > 0 else { return nil }
    return entries[i - 1]
  }

  func isExpired(at now: Date) -> Bool { now >= validUntil }

  /// The place's day that contains `moment`, with its prayers (at most five).
  func day(of moment: Date) -> (label: String, entries: [PrayerEntry]) {
    guard let start = days.last(where: { $0.date <= moment }) else { return ("", []) }
    let end = days.first(where: { $0.date > start.date })?.date ?? .distantFuture
    return (start.label, Array(entries.filter { $0.date >= start.date && $0.date < end }.prefix(5)))
  }
}

struct KhatmaProgress: Codable, Equatable {
  let percent: Int
  let pagesRead: Int?
  let pagesTotal: Int?
  let text: String
  let todayRead: Bool
  let paused: Bool

  var fraction: Double { Double(min(max(percent, 0), 100)) / 100 }
}

struct QuranBlock: Codable, Equatable {
  let mode: String
  let title: String
  let line1: String
  let line2: String
  let progress: KhatmaProgress?
  let link: String
}
