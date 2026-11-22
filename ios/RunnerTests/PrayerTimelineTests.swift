import XCTest

/// specs/017 research R2: one moment per prayer from now, then "Open Mathani to update" (T026).
final class PrayerTimelineTests: XCTestCase {
  private let snapshot = WidgetSnapshot.decode(WidgetSnapshotTests.json())!

  func testOneMomentNowOnePerLaterPrayerAndTheEnd() {
    let p = snapshot.prayer!
    let now = p.entries[1].date.addingTimeInterval(-60)  // a minute before Dhuhr
    let moments = prayerMoments(snapshot, now: now)
    // Now, Dhuhr … second Isha (9 entries), the end of the times.
    XCTAssertEqual(moments.count, 1 + 9 + 1)
    XCTAssertEqual(moments.first?.date, now)
    guard case let .next(next, previous, label, day) = moments[0].state else { return XCTFail() }
    XCTAssertEqual(next.kind, "dhuhr")
    XCTAssertEqual(previous?.kind, "fajr")
    XCTAssertEqual(label, "Today")
    XCTAssertEqual(day.count, 5)
    XCTAssertEqual(moments.last?.state, .expired)
    XCTAssertEqual(moments.last?.date, p.validUntil)
  }

  func testAtEachPrayerTheFollowingOneIsNext() {
    let p = snapshot.prayer!
    let moments = prayerMoments(snapshot, now: p.entries[0].date.addingTimeInterval(-1))
    let atDhuhr = moments.first { $0.date == p.entries[1].date }!
    guard case let .next(next, _, _, _) = atDhuhr.state else { return XCTFail() }
    XCTAssertEqual(next.kind, "asr")
    // After the first day's Isha, tomorrow's Fajr, on tomorrow's day.
    let atIsha = moments.first { $0.date == p.entries[4].date }!
    guard case let .next(fajr, _, label, _) = atIsha.state else { return XCTFail() }
    XCTAssertEqual(fajr, p.entries[5])
    XCTAssertEqual(label, "Monday")
  }

  func testPastMomentsAreDroppedAndExpiredIsKept() {
    let p = snapshot.prayer!
    XCTAssertEqual(prayerMoments(snapshot, now: p.validUntil).map(\.state), [.expired])
    XCTAssertEqual(prayerMoments(nil, now: Date()).map(\.state), [.notSetUp])
  }

  func testAccessibilitySentence() {
    let e = snapshot.prayer!.entries[2]
    XCTAssertEqual(prayerAccessibility(snapshot, e), "Next prayer: Asr at \(e.time)")
  }
}
