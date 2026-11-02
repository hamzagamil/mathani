import 'dart:convert';
import 'dart:math' as math;

import 'package:adhan_dart/adhan_dart.dart' as adhan;
// Pinned 2.0.1 solver internals are needed for the verified polar/Asr fixes.
// ignore: implementation_imports
import 'package:adhan_dart/src/Astronomical.dart' show Astronomical;
// ignore: implementation_imports
import 'package:adhan_dart/src/SolarCoordinates.dart' show SolarCoordinates;
// ignore: implementation_imports
import 'package:adhan_dart/src/SolarTime.dart' show SolarTime;
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import 'prayer_models.dart';
import 'prayer_services.dart';
import 'prayer_time_zones.dart';

/// One day's raw times before the reader's offsets, with which ones the latitude rule moved.
typedef _Times = ({
  DateTime fajr,
  DateTime sunrise,
  DateTime dhuhr,
  DateTime asr,
  DateTime maghrib,
  DateTime isha,
  bool fajrCapped,
  bool ishaCapped,
});

/// Prayer times on the phone, no network (data model → DaySchedule; research R2).
class PrayerCalculator {
  PrayerCalculator(this.calendar);
  final Map<String, dynamic> calendar;

  static Future<PrayerCalculator> load() async => PrayerCalculator(
    Map<String, dynamic>.from(
      jsonDecode(
        await rootBundle.loadString('assets/prayer/ramadan_intervals.json'),
      ) as Map,
    ),
  );

  /// Maghrib + ⅔ × (next Fajr − Maghrib), rounded to the minute.
  static DateTime? qiyamStart(DateTime? maghrib, DateTime? followingFajr) {
    if (maghrib == null ||
        followingFajr == null ||
        !followingFajr.isAfter(maghrib)) {
      return null;
    }
    final instant =
        maghrib.toUtc().millisecondsSinceEpoch +
        followingFajr.difference(maghrib).inMilliseconds * 2 ~/ 3;
    return _minute(DateTime.fromMillisecondsSinceEpoch(instant, isUtc: true));
  }

  static DateTime _minute(DateTime t, {bool up = false}) {
    final ms = t.millisecondsSinceEpoch;
    final minutes = up ? (ms / 60000).ceil() : (ms / 60000).round();
    return DateTime.fromMillisecondsSinceEpoch(minutes * 60000, isUtc: true);
  }

  static adhan.CalculationParameters _parameters(PrayerMethod method) =>
      switch (method) {
        PrayerMethod.muslimWorldLeague =>
          adhan.CalculationMethodParameters.muslimWorldLeague(),
        PrayerMethod.egyptian => adhan.CalculationMethodParameters.egyptian(),
        PrayerMethod.ummAlQura => adhan.CalculationMethodParameters.ummAlQura(),
        PrayerMethod.karachi => adhan.CalculationMethodParameters.karachi(),
        PrayerMethod.isna => adhan.CalculationMethodParameters.northAmerica(),
        PrayerMethod.dubai => adhan.CalculationMethodParameters.dubai(),
        PrayerMethod.kuwait => adhan.CalculationMethodParameters.kuwait(),
        PrayerMethod.qatar => adhan.CalculationMethodParameters.qatar(),
        PrayerMethod.singapore => adhan.CalculationMethodParameters.singapore(),
        PrayerMethod.turkey => adhan.CalculationMethodParameters.turkiye(),
        PrayerMethod.moonsightingCommittee =>
          adhan.CalculationMethodParameters.moonsightingCommittee(),
      };

  _Times _calculate(Place place, DateTime day) {
    final coordinates = adhan.Coordinates(place.latitude, place.longitude);
    final solar = SolarTime(day, coordinates);
    final latitude = place.latitude * math.pi / 180;
    final declination = solar.solar.declination! * math.pi / 180;
    double hourAngleCos(double angle) =>
        (math.sin(angle * math.pi / 180) -
            math.sin(latitude) * math.sin(declination)) /
        (math.cos(latitude) * math.cos(declination));
    // 2.0.1 substitutes a finite hour angle outside the acos domain. Reject
    // polar days explicitly rather than presenting that result as a sunrise.
    final sunriseCos = hourAngleCos(-50 / 60);
    if (!sunriseCos.isFinite || sunriseCos.abs() > 1) {
      throw const PrayerException(PrayerFailure.calculationUnavailable);
    }
    final c = place.calculation;
    final p = _parameters(c.method);
    p.madhab = c.asr == AsrSetting.hanafi
        ? adhan.Madhab.hanafi
        : adhan.Madhab.shafi;
    p.highLatitudeRule = c.highLatitudeRule == HighLatitudeRule.middleOfNight
        ? adhan.HighLatitudeRule.middleOfTheNight
        : adhan.HighLatitudeRule.seventhOfTheNight;
    p.polarCircleResolution = adhan.PolarCircleResolution.unresolved;
    if (c.method == PrayerMethod.ummAlQura) {
      final stamp = day.toIso8601String().substring(0, 10);
      if (stamp.compareTo(calendar['coverageStart'] as String) < 0 ||
          stamp.compareTo(calendar['coverageEndExclusive'] as String) >= 0) {
        throw const PrayerException(PrayerFailure.conventionOutOfRange);
      }
      final tomorrow = day
          .add(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      final ramadan = (calendar['intervals'] as List).any(
        (v) =>
            tomorrow.compareTo(v['ramadanCivilStart'] as String) >= 0 &&
            tomorrow.compareTo(v['shawwalCivilStart'] as String) < 0,
      );
      if (ramadan) p.ishaInterval = 120;
    }
    final up = p.rounding == adhan.Rounding.up;
    int methodMinutes(adhan.Prayer prayer) => p.methodAdjustments[prayer] ?? 0;
    final result = adhan.PrayerTimes(
      date: day,
      coordinates: coordinates,
      calculationParameters: p,
    );
    final prior = adhan.PrayerTimes(
      date: day.subtract(const Duration(days: 1)),
      coordinates: coordinates,
      calculationParameters: p,
    );
    final following = adhan.PrayerTimes(
      date: day.add(const Duration(days: 1)),
      coordinates: coordinates,
      calculationParameters: p,
    );
    final fraction = c.highLatitudeRule == HighLatitudeRule.middleOfNight
        ? 0.5
        : 1 / 7;
    final earliestFajr = result.sunrise.subtract(
      Duration(
        seconds: (result.sunrise.difference(prior.sunset).inSeconds * fraction)
            .round(),
      ),
    );
    final latestIsha = result.sunset.add(
      Duration(
        seconds:
            (following.sunrise.difference(result.sunset).inSeconds * fraction)
                .round(),
      ),
    );
    bool unreachable(double angle) => hourAngleCos(-angle).abs() > 1;
    var fajr = result.fajr, isha = result.isha;
    var fajrCapped = false, ishaCapped = false;
    // The library's offsets are lost when a time is replaced, so they are added back (R2).
    if (unreachable(p.fajrAngle) ||
        result.fajr.isBefore(earliestFajr) ||
        !result.fajr.isBefore(result.sunrise)) {
      fajr = _minute(
        earliestFajr.add(Duration(minutes: methodMinutes(adhan.Prayer.fajr))),
        up: up,
      );
      fajrCapped = true;
    }
    if ((p.ishaInterval ?? 0) == 0 &&
        (unreachable(p.ishaAngle) ||
            result.isha.isAfter(latestIsha) ||
            !result.isha.isAfter(result.sunset))) {
      isha = _minute(
        latestIsha.add(Duration(minutes: methodMinutes(adhan.Prayer.isha))),
        up: up,
      );
      ishaCapped = true;
    }
    // Use solar declination at Asr, not midnight, for the shadow angle. Keep
    // the pinned library's independent Meeus solver and all method offsets.
    final asrFactor = c.asr == AsrSetting.hanafi ? 2 : 1;
    var hours = result.asr.difference(day).inSeconds / 3600;
    for (var i = 0; i < 3; i++) {
      final jd = Astronomical.julianDay(day.year, day.month, day.day, hours);
      final decl = SolarCoordinates(jd).declination!;
      final shadow =
          asrFactor + math.tan((place.latitude - decl).abs() * math.pi / 180);
      final angle = math.atan(1 / shadow) * 180 / math.pi;
      hours = solar.hourAngle(angle, true);
    }
    if (!hours.isFinite) {
      throw const PrayerException(PrayerFailure.calculationUnavailable);
    }
    final asr = _minute(
      day.add(
        Duration(
          seconds:
              (hours * 3600).round() + methodMinutes(adhan.Prayer.asr) * 60,
        ),
      ),
      up: up,
    );
    return (
      fajr: fajr.toUtc(),
      sunrise: result.sunrise.toUtc(),
      dhuhr: result.dhuhr.toUtc(),
      asr: asr,
      maghrib: result.maghrib.toUtc(),
      isha: isha.toUtc(),
      fajrCapped: fajrCapped,
      ishaCapped: ishaCapped,
    );
  }

  /// The schedule for [date] (a calendar date in the place's zone). Order of computation:
  /// library times, polar check, latitude cap, Asr correction, method offsets, the reader's
  /// offsets, then Qiyam from the adjusted Maghrib and next Fajr (data-model.md).
  DaySchedule schedule(Place place, DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    DaySchedule unavailable(String reason) => DaySchedule(
      placeId: place.id,
      localDate: day,
      timezoneId: place.timezoneId,
      events: [
        for (final kind in PrayerKind.values.take(6))
          PrayerEvent(
            kind,
            null,
            status: EventStatus.unavailable,
            reason: reason,
          ),
      ],
      qiyamUnavailableReason: reason,
    );
    final offsets = place.calculation;
    DateTime shifted(PrayerKind kind, DateTime t) =>
        t.add(Duration(minutes: offsets.offset(kind)));
    try {
      final t = _calculate(place, day);
      final values = {
        PrayerKind.fajr: (t.fajr, t.fajrCapped),
        PrayerKind.sunrise: (t.sunrise, false),
        PrayerKind.dhuhr: (t.dhuhr, false),
        PrayerKind.asr: (t.asr, false),
        PrayerKind.maghrib: (t.maghrib, false),
        PrayerKind.isha: (t.isha, t.ishaCapped),
      };
      final events = [
        for (final MapEntry(key: kind, value: (time, capped)) in values.entries)
          () {
            final adjustedBy = {
              if (capped) Adjustment.highLatitude,
              if (offsets.offset(kind) != 0) Adjustment.offset,
            };
            return PrayerEvent(
              kind,
              shifted(kind, time),
              status: adjustedBy.isEmpty
                  ? EventStatus.normal
                  : EventStatus.adjusted,
              adjustedBy: adjustedBy,
            );
          }(),
      ];
      DateTime? qiyam;
      String? qiyamReason;
      try {
        final next = _calculate(place, day.add(const Duration(days: 1)));
        qiyam = qiyamStart(
          shifted(PrayerKind.maghrib, t.maghrib),
          shifted(PrayerKind.fajr, next.fajr),
        );
        if (qiyam == null) qiyamReason = 'calculationUnavailable';
      } on PrayerException catch (e) {
        qiyamReason = e.reason.name;
      }
      return DaySchedule(
        placeId: place.id,
        localDate: day,
        timezoneId: place.timezoneId,
        events: events,
        qiyamUtc: qiyam,
        qiyamUnavailableReason: qiyamReason,
      );
    } on PrayerException catch (e) {
      return unavailable(e.reason.name);
    } on Object {
      return unavailable(PrayerFailure.calculationUnavailable.name);
    }
  }

  /// Today's date in the place's zone at [now].
  static DateTime localDay(Place place, DateTime now) {
    final local = tz.TZDateTime.from(now, prayerTimeZone(place.timezoneId));
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// The earliest available prayer after [now], up to 2 days ahead. Never sunrise.
  PrayerEvent? nextPrayer(Place place, DateTime now) {
    final today = localDay(place, now);
    for (var offset = 0; offset < 3; offset++) {
      final candidates =
          schedule(place, today.add(Duration(days: offset))).events
              .where(
                (e) =>
                    dailyPrayers.contains(e.kind) &&
                    e.atUtc != null &&
                    e.atUtc!.isAfter(now),
              )
              .toList()
            ..sort((a, b) => a.atUtc!.compareTo(b.atUtc!));
      if (candidates.isNotEmpty) return candidates.first;
    }
    return null;
  }
}
