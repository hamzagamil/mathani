// The place rules P1 to P11 (specs/014 contracts/khatma-ui-and-reminders.md › The place), with one
// page, two facing pages, and the flowing layout (a page from the top ayah, like one page).
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/khatma/reading_tracker.dart';

/// A wird on pages 42 to 62, its place on page 50, page 50 on screen.
ReadingTracker wird({int place = 50}) =>
    ReadingTracker(firstPage: 42, lastPage: 62, place: place)..onJump(place, place);

TrackResult turn(ReadingTracker t, int page, {bool spread = false}) {
  final right = page.isOdd ? page : page - 1;
  return spread
      ? t.onMove(right, right + 1, byReader: true)
      : t.onMove(page, page, byReader: true);
}

void main() {
  test('P1: turning forward from the place moves it', () {
    final t = wird();
    expect(turn(t, 51), TrackResult.moved);
    expect(t.place, 51);
  });

  test('P2: turning back from the place moves it', () {
    final t = wird();
    turn(t, 49);
    expect(t.place, 49);
  });

  test('P3: a jump elsewhere and pages turned there leave the place', () {
    final t = wird();
    t.onMove(440, 440, byReader: false);
    turn(t, 441);
    expect(t.place, 50);
  });

  test('P4: a jump to another page of the wird leaves the place', () {
    final t = wird();
    t.onMove(42, 42, byReader: false);
    expect(t.place, 50);
    turn(t, 43);
    expect(t.place, 50);
  });

  test('P5: after a jump, the place follows once the reader reaches it', () {
    final t = wird();
    t.onMove(45, 45, byReader: false);
    for (var p = 46; p <= 49; p++) {
      turn(t, p);
      expect(t.place, 50);
    }
    turn(t, 50);
    expect(t.following, isTrue);
    turn(t, 51);
    expect(t.place, 51);
  });

  test('P6: a recitation moving the page is a jump', () {
    final t = wird();
    t.onMove(51, 51, byReader: false);
    expect(t.place, 50);
  });

  test('P7: turning past the last page passes the end', () {
    final t = wird(place: 62);
    expect(turn(t, 63), TrackResult.passedEnd);
  });

  test('P8: with two facing pages, turning past the pair that holds the end', () {
    final t = ReadingTracker(firstPage: 42, lastPage: 62, place: 61)..onJump(61, 62);
    expect(t.following, isTrue);
    expect(turn(t, 63, spread: true), TrackResult.passedEnd);
  });

  test('two facing pages: the place is the first of the two', () {
    final t = ReadingTracker(firstPage: 42, lastPage: 62, place: 49)..onJump(49, 50);
    turn(t, 51, spread: true);
    expect(t.place, 51);
    // A wird that starts on the left page of a pair: the place stays inside the wird.
    final u = ReadingTracker(firstPage: 62, lastPage: 82, place: 62)..onJump(61, 62);
    turn(u, 63, spread: true);
    expect(u.place, 63);
  });

  test('P9: during memorization moves are jumps, so nothing changes', () {
    final t = wird();
    for (final p in [51, 52, 63]) {
      expect(t.onMove(p, p, byReader: false), TrackResult.none);
    }
    expect(t.place, 50);
  });

  test('P10: back before the first page, then forward into the wird', () {
    final t = wird(place: 43);
    turn(t, 42);
    turn(t, 41);
    turn(t, 40);
    expect(t.place, 42);
    turn(t, 41);
    turn(t, 42);
    turn(t, 43);
    expect(t.place, 43);
  });

  test('P11: a group part is never read by turning past it', () {
    final t = ReadingTracker(firstPage: 121, lastPage: 141, place: 141, marksOnPass: false)
      ..onJump(141, 141);
    expect(turn(t, 142), isNot(TrackResult.passedEnd));
    expect(t.place, 141);
  });
}
