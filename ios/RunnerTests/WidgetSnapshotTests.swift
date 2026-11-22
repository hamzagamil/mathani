import XCTest

/// specs/017 contracts/widget-snapshot.md › Validation and the next-prayer rule (T024, T026).
final class WidgetSnapshotTests: XCTestCase {
  static let day: Int64 = 86_400_000

  static func entry(_ kind: String, _ at: Int64) -> String {
    "{\"kind\":\"\(kind)\",\"atUtc\":\(at),\"name\":\"\(kind.capitalized)\",\"time\":\"t\(at)\"}"
  }

  /// Two days of five prayers from `start`.
  static func json(v: Int = 1, start: Int64 = 1_000_000, entries: String? = nil) -> String {
    let kinds = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
    let list = entries ?? (0..<2).flatMap { d in
      kinds.enumerated().map { i, k in entry(k, start + Int64(d) * day + Int64(i + 1) * 3_600_000) }
    }.joined(separator: ",")
    return """
      {"v":\(v),"madeAtUtc":5,"lang":"en","rtl":false,
       "labels":{"next":"Next prayer","a11yNext":"Next prayer: {name} at {time}"},
       "prayer":{"place":"Cairo","validUntilUtc":\(start + day + 5 * 3_600_000 + 60_000),
         "days":[{"startUtc":\(start),"label":"Today"},{"startUtc":\(start + day),"label":"Monday"}],
         "entries":[\(list)]},
       "quran":{"mode":"wird","title":"Today's wird","line1":"From Al-Baqarah 142","line2":"to Al-Baqarah 202",
         "progress":{"percent":41,"pagesRead":248,"pagesTotal":604,"text":"41%","todayRead":false,"paused":false},
         "link":"mathani-widget://khatma/read","futureField":true}}
      """
  }

  static func date(_ ms: Int64) -> Date { Date(timeIntervalSince1970: TimeInterval(ms) / 1000) }

  func testDecodesTheContractAndIgnoresUnknownFields() throws {
    let s = try XCTUnwrap(WidgetSnapshot.decode(Self.json()))
    XCTAssertEqual(s.label("next"), "Next prayer")
    XCTAssertEqual(s.label("missing"), "")
    XCTAssertEqual(s.prayer?.place, "Cairo")
    XCTAssertEqual(s.prayer?.entries.count, 10)
    XCTAssertEqual(s.quran?.progress?.percent, 41)
    XCTAssertNil(s.khatma)
  }

  func testRejectsNewerVersionsBrokenTextAndDisorder() {
    XCTAssertNil(WidgetSnapshot.decode(Self.json(v: 2)))
    XCTAssertNil(WidgetSnapshot.decode("{"))
    XCTAssertNil(WidgetSnapshot.decode(Self.json(entries: Self.entry("fajr", 20) + "," + Self.entry("dhuhr", 10))))
    XCTAssertNil(WidgetSnapshot.decode(Self.json(entries: Self.entry("fajr", 20) + "," + Self.entry("dhuhr", 20))))
  }

  func testNextChangesExactlyAtEachPrayer() throws {
    let p = try XCTUnwrap(WidgetSnapshot.decode(Self.json())?.prayer)
    let dhuhr = p.entries[1].date
    XCTAssertEqual(p.next(after: dhuhr.addingTimeInterval(-0.001))?.kind, "dhuhr")
    XCTAssertEqual(p.next(after: dhuhr)?.kind, "asr")
    XCTAssertNil(p.next(after: p.entries.last!.date))
    XCTAssertFalse(p.isExpired(at: p.validUntil.addingTimeInterval(-1)))
    XCTAssertTrue(p.isExpired(at: p.validUntil))
  }

  func testDayOfAMomentHasThatDaysPrayers() throws {
    let p = try XCTUnwrap(WidgetSnapshot.decode(Self.json())?.prayer)
    let second = p.day(of: Self.date(1_000_000 + Self.day + 1))
    XCTAssertEqual(second.label, "Monday")
    XCTAssertEqual(second.entries.count, 5)
    XCTAssertEqual(second.entries.first, p.entries[5])
  }

  func testWatchCopyDecodesWithKhatma() throws {
    let watch = """
      {"v":1,"madeAtUtc":9,"lang":"ar","rtl":true,"labels":{"khatma":"الختمة"},"prayer":null,
       "khatma":{"percent":41,"todayRead":true,"paused":false,"text":"٤١٪"}}
      """
    let s = try XCTUnwrap(WidgetSnapshot.decode(watch))
    XCTAssertTrue(s.rtl)
    XCTAssertEqual(s.khatma?.todayRead, true)
    XCTAssertEqual(s.khatma?.fraction ?? 0, 0.41, accuracy: 0.0001)
    XCTAssertNil(s.prayer)
  }
}
