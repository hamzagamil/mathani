// Dates of the personal khatma (specs/014 FR-027, research R11).
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/khatma/khatma_models.dart';

void main() {
  final start = CalendarDay.parse('2026-03-01');

  test('calendar days: text, arithmetic, and the day of a local time', () {
    expect(start.toString(), '2026-03-01');
    expect(start.addDays(30).toString(), '2026-03-31');
    expect(CalendarDay.parse('2026-12-31').addDays(1), CalendarDay.parse('2027-01-01'));
    expect(CalendarDay.parse('2028-03-01').daysSince(CalendarDay.parse('2028-02-28')), 2);
    expect(CalendarDay.tryParse('2026-02-30'), isNull);
    expect(CalendarDay.tryParse('26-2-3'), isNull);
    // A wird read after midnight counts for the new day.
    expect(CalendarDay.of(DateTime(2026, 3, 2, 0, 15)), CalendarDay.parse('2026-03-02'));
    expect(CalendarDay.of(DateTime(2026, 3, 1, 23, 59)), start);
  });

  test('the planned finish is the start date plus the wirds, minus one', () {
    expect(plannedFinishFor(start, 30), CalendarDay.parse('2026-03-30'));
    expect(plannedFinishFor(start, 1), start);
  });

  test('on the sixth day with 3 of 30 read, none today: two days after the plan', () {
    final today = start.addDays(5);
    final expected = expectedFinish(today: today, startDate: start, unread: 27, todayRead: false);
    expect(expected.daysSince(plannedFinishFor(start, 30)), 2);
  });

  test('a wird read today counts from tomorrow', () {
    final today = start.addDays(5);
    expect(expectedFinish(today: today, startDate: start, unread: 26, todayRead: true),
        expectedFinish(today: today, startDate: start, unread: 27, todayRead: false));
  });

  test('two wirds read in one day move the finish one day earlier', () {
    final today = start.addDays(5);
    final one = expectedFinish(today: today, startDate: start, unread: 26, todayRead: true);
    final two = expectedFinish(today: today, startDate: start, unread: 25, todayRead: true);
    expect(one.daysSince(two), 1);
  });

  test('before the start date: from the start date', () {
    final today = start.addDays(-3);
    expect(expectedFinish(today: today, startDate: start, unread: 30, todayRead: false),
        plannedFinishFor(start, 30));
  });

  test('plans and the reminder setting read back what they wrote', () {
    for (final plan in [const MarksPlan(8), const SevenPlan(), const DaysPlan(29)]) {
      expect(KhatmaPlan.tryDecode(plan.encode()), plan);
    }
    expect(const MarksPlan(8).encode(), '{"kind":"marks","quarters":8}');
    expect(KhatmaPlan.tryDecode('{"kind":"marks","quarters":3}'), isNull);
    expect(KhatmaPlan.tryDecode('{"kind":"days","days":605}'), isNull);
    expect(KhatmaPlan.tryDecode('nonsense'), isNull);
    const r = ReminderSetting(on: true, hour: 5, minute: 30);
    expect(r.encode(), '{"on":true,"time":"05:30"}');
    expect(ReminderSetting.decode(r.encode()), r);
    expect(ReminderSetting.decode(null), ReminderSetting.off);
    expect(ReminderSetting.decode('{"on":true,"time":"25:00"}'), ReminderSetting.off);
  });
}
