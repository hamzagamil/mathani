// The personal khatma's models (specs/014 data-model.md). Plain Dart: no Flutter imports, so the
// rules built on them are unit tested without a device.
import 'dart:convert';

/// The state of a personal khatma. "Not started yet" is not stored: it is [active] with a start
/// date after today (data-model.md › khatmas).
enum KhatmaState { active, paused, finished }

/// Today's date, injected so tests can move it (research R11).
typedef Clock = DateTime Function();

/// A calendar day of the phone's clock, stored as `YYYY-MM-DD`. No time and no zone: "read
/// today" is one comparison, and a wird read after midnight counts for the new day.
class CalendarDay implements Comparable<CalendarDay> {
  const CalendarDay(this.year, this.month, this.day);

  factory CalendarDay.of(DateTime t) => CalendarDay(t.year, t.month, t.day);

  /// Parses `YYYY-MM-DD`; null for anything else.
  static CalendarDay? tryParse(String? text) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text ?? '');
    if (m == null) return null;
    final d = CalendarDay(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    final check = d._utc;
    return check.year == d.year && check.month == d.month && check.day == d.day ? d : null;
  }

  static CalendarDay parse(String text) =>
      tryParse(text) ?? (throw FormatException('Not a calendar day: $text'));

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// This day at local midnight, for formatting.
  DateTime get asDateTime => DateTime(year, month, day);

  CalendarDay addDays(int days) => CalendarDay.of(_utc.add(Duration(days: days)));

  /// Whole days from [other] to this day (positive when this day is later).
  int daysSince(CalendarDay other) => _utc.difference(other._utc).inDays;

  bool isBefore(CalendarDay other) => compareTo(other) < 0;
  bool isAfter(CalendarDay other) => compareTo(other) > 0;

  @override
  int compareTo(CalendarDay other) => _utc.compareTo(other._utc);

  @override
  bool operator ==(Object other) =>
      other is CalendarDay && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// How a personal khatma is divided (data-model.md › The plan). Stored as JSON in
/// `khatmas.plan`.
sealed class KhatmaPlan {
  const KhatmaPlan();

  /// The daily amounts by the Mushaf's marks, in quarter hizbs: a quarter, half a hizb, a hizb,
  /// a juz, two, three and ten ajza' (FR-002).
  static const markAmounts = [1, 2, 4, 8, 16, 24, 80];

  static const maxDays = 604;

  Map<String, Object> toJson();

  String encode() => jsonEncode(toJson());

  /// Reads a stored plan; null when it is not one this version knows.
  static KhatmaPlan? tryDecode(String? text) {
    if (text == null) return null;
    try {
      final j = jsonDecode(text);
      if (j is! Map) return null;
      return switch (j['kind']) {
        'marks' when markAmounts.contains(j['quarters']) => MarksPlan(j['quarters'] as int),
        'seven' => const SevenPlan(),
        'days' when j['days'] is int && (j['days'] as int) >= 1 && (j['days'] as int) <= maxDays =>
          DaysPlan(j['days'] as int),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }
}

/// [quarters] quarter hizbs a day, on the marks of the Ajza' index.
class MarksPlan extends KhatmaPlan {
  const MarksPlan(this.quarters) : assert(quarters > 0);
  final int quarters;

  @override
  Map<String, Object> toJson() => {'kind': 'marks', 'quarters': quarters};

  @override
  bool operator ==(Object other) => other is MarksPlan && other.quarters == quarters;

  @override
  int get hashCode => quarters.hashCode;
}

/// Seven days by whole surahs: «فمي بشوق».
class SevenPlan extends KhatmaPlan {
  const SevenPlan();

  @override
  Map<String, Object> toJson() => {'kind': 'seven'};

  @override
  bool operator ==(Object other) => other is SevenPlan;

  @override
  int get hashCode => 7;
}

/// A custom plan of [days] days, by whole pages spread evenly. "Pages a day" and "a finish date"
/// are turned into a number of days before they are stored.
class DaysPlan extends KhatmaPlan {
  const DaysPlan(this.days) : assert(days >= 1);
  final int days;

  @override
  Map<String, Object> toJson() => {'kind': 'days', 'days': days};

  @override
  bool operator ==(Object other) => other is DaysPlan && other.days == days;

  @override
  int get hashCode => days.hashCode;
}

/// A run of whole ayat, by ayah id (1 to 6236).
class WirdRange {
  const WirdRange(this.firstAyah, this.lastAyah) : assert(firstAyah <= lastAyah);
  final int firstAyah;
  final int lastAyah;

  @override
  bool operator ==(Object other) =>
      other is WirdRange && other.firstAyah == firstAyah && other.lastAyah == lastAyah;

  @override
  int get hashCode => Object.hash(firstAyah, lastAyah);

  @override
  String toString() => 'WirdRange($firstAyah–$lastAyah)';
}

/// One day's portion of a personal khatma (data-model.md › khatma_wirds).
class Wird {
  const Wird({
    required this.khatmaId,
    required this.number,
    required this.firstAyah,
    required this.lastAyah,
    this.readOn,
  });

  final int khatmaId;

  /// 1, 2, 3, … in Mushaf order.
  final int number;
  final int firstAyah;
  final int lastAyah;

  /// The day it was marked as read; null while unread.
  final CalendarDay? readOn;

  bool get isRead => readOn != null;

  WirdRange get range => WirdRange(firstAyah, lastAyah);

  Wird withReadOn(CalendarDay? day) => Wird(
        khatmaId: khatmaId,
        number: number,
        firstAyah: firstAyah,
        lastAyah: lastAyah,
        readOn: day,
      );

  @override
  bool operator ==(Object other) =>
      other is Wird &&
      other.khatmaId == khatmaId &&
      other.number == number &&
      other.firstAyah == firstAyah &&
      other.lastAyah == lastAyah &&
      other.readOn == readOn;

  @override
  int get hashCode => Object.hash(khatmaId, number, firstAyah, lastAyah, readOn);
}

/// One personal khatma: the one in progress, or a finished one, which is a record entry
/// (data-model.md › khatmas).
class Khatma {
  const Khatma({
    required this.id,
    required this.state,
    required this.plan,
    required this.startAyah,
    required this.startDate,
    required this.plannedFinish,
    required this.placePage,
    required this.wirdCount,
    required this.createdAt,
    this.pausedOn,
    this.finishedOn,
  });

  final int id;
  final KhatmaState state;
  final KhatmaPlan plan;

  /// Ayah id of the start point, 1 to 6236.
  final int startAyah;
  final CalendarDay startDate;
  final CalendarDay plannedFinish;

  /// The day a pause began, while paused.
  final CalendarDay? pausedOn;

  /// The khatma place: a page of the current wird, 1 to 604.
  final int placePage;

  /// Number of wirds, kept for the record.
  final int wirdCount;

  /// The day the last wird was read.
  final CalendarDay? finishedOn;

  /// Milliseconds since the epoch.
  final int createdAt;

  /// Days from the start date to the finish date, both counted (Story 8).
  int? get days => finishedOn == null ? null : finishedOn!.daysSince(startDate) + 1;

  Khatma copyWith({
    KhatmaState? state,
    KhatmaPlan? plan,
    CalendarDay? plannedFinish,
    CalendarDay? Function()? pausedOn,
    int? placePage,
    int? wirdCount,
    CalendarDay? Function()? finishedOn,
  }) =>
      Khatma(
        id: id,
        state: state ?? this.state,
        plan: plan ?? this.plan,
        startAyah: startAyah,
        startDate: startDate,
        plannedFinish: plannedFinish ?? this.plannedFinish,
        pausedOn: pausedOn == null ? this.pausedOn : pausedOn(),
        placePage: placePage ?? this.placePage,
        wirdCount: wirdCount ?? this.wirdCount,
        createdAt: createdAt,
        finishedOn: finishedOn == null ? this.finishedOn : finishedOn(),
      );

  @override
  bool operator ==(Object other) =>
      other is Khatma &&
      other.id == id &&
      other.state == state &&
      other.plan == plan &&
      other.startAyah == startAyah &&
      other.startDate == startDate &&
      other.plannedFinish == plannedFinish &&
      other.pausedOn == pausedOn &&
      other.placePage == placePage &&
      other.wirdCount == wirdCount &&
      other.finishedOn == finishedOn &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, state, plan, startAyah, startDate, plannedFinish, pausedOn,
      placePage, wirdCount, finishedOn, createdAt);
}

/// The planned finish: the start date plus the number of wirds, minus one (research R11).
CalendarDay plannedFinishFor(CalendarDay startDate, int wirds) => startDate.addDays(wirds - 1);

/// The day the last wird is reached at one wird a day (FR-027): counting from today when today is
/// not read yet, from tomorrow when it is; before the start date, from the start date.
CalendarDay expectedFinish({
  required CalendarDay today,
  required CalendarDay startDate,
  required int unread,
  required bool todayRead,
}) {
  if (unread <= 0) return today;
  if (today.isBefore(startDate)) return startDate.addDays(unread - 1);
  return today.addDays(todayRead ? unread : unread - 1);
}

/// The daily reminder (data-model.md › The reminder setting): `{"on": true, "time": "05:30"}`.
/// Missing means off. It belongs to the reader, not to one khatma (FR-025).
class ReminderSetting {
  const ReminderSetting({this.on = false, this.hour = 5, this.minute = 30})
      : assert(hour >= 0 && hour < 24 && minute >= 0 && minute < 60);

  static const off = ReminderSetting();

  final bool on;
  final int hour;
  final int minute;

  String get time => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String encode() => jsonEncode({'on': on, 'time': time});

  /// Reads the stored value; [off] when it is missing or not understood.
  static ReminderSetting decode(String? text) {
    if (text == null) return off;
    try {
      final j = jsonDecode(text);
      if (j is! Map) return off;
      final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch('${j['time']}');
      final hour = m == null ? 5 : int.parse(m[1]!);
      final minute = m == null ? 30 : int.parse(m[2]!);
      if (hour > 23 || minute > 59) return off;
      return ReminderSetting(on: j['on'] == true, hour: hour, minute: minute);
    } on FormatException {
      return off;
    }
  }

  ReminderSetting copyWith({bool? on, int? hour, int? minute}) => ReminderSetting(
        on: on ?? this.on,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderSetting && other.on == on && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(on, hour, minute);
}

/// What a reading is: the personal khatma's current wird, or a group part the reader holds.
enum ReadingKind { wird, groupPart }

/// Something the reader is reading in the Mushaf (data-model.md › In memory): it has a place, its
/// end is marked, the header shows its pages left, and a Done row shows on its last page.
class Reading {
  const Reading({
    required this.key,
    required this.kind,
    required this.firstAyah,
    required this.lastAyah,
    required this.firstPage,
    required this.lastPage,
    required this.place,
    this.title,
    this.partNumber,
  });

  /// Unique among the readings: `wird`, or `group:<code>:<n>`.
  final String key;
  final ReadingKind kind;
  final int firstAyah;
  final int lastAyah;
  final int firstPage;
  final int lastPage;

  /// The page where the reader will continue.
  final int place;

  /// For a group part: the khatma's title and the part's number.
  final String? title;
  final int? partNumber;

  /// Pages of this reading from [page] to its end, both counted (contracts/wird-division.md,
  /// rule 7).
  int pagesLeftFrom(int page) => lastPage - page + 1;

  bool containsPage(int page) => page >= firstPage && page <= lastPage;
}
