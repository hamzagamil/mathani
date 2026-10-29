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
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import 'prayer_models.dart';
import 'prayer_services.dart';
import 'prayer_time_zones.dart';

class PrayerCalculator {
  static DateTime? qiyamStart(DateTime? maghrib, DateTime? followingFajr) {
    if (maghrib == null ||
        followingFajr == null ||
        !followingFajr.isAfter(maghrib)) {
      return null;
    }
    final instant =
        maghrib.toUtc().millisecondsSinceEpoch +
        followingFajr.difference(maghrib).inMilliseconds * 2 ~/ 3;
    return DateTime.fromMillisecondsSinceEpoch(
      ((instant + 30000) ~/ 60000) * 60000,
      isUtc: true,
    );
  }

  PrayerCalculator(this.calendar, {this.clock = prayerNow});
  final Map<String, dynamic> calendar;
  final PrayerClock clock;
  static Future<PrayerCalculator> load() async => PrayerCalculator(
    Map<String, dynamic>.from(
      jsonDecode(
        await rootBundle.loadString('assets/prayer/ramadan_intervals.json'),
      ) as Map,
    ),
  );

  adhan.PrayerTimes _calculate(SavedLocation place, DateTime day) {
    final solar = SolarTime(
      day,
      adhan.Coordinates(place.latitude, place.longitude),
    );
    final latitude = place.latitude * math.pi / 180;
    final declination = solar.solar.declination! * math.pi / 180;
    final sunriseCos =
        (math.sin(-50 / 60 * math.pi / 180) -
            math.sin(latitude) * math.sin(declination)) /
        (math.cos(latitude) * math.cos(declination));
    // 2.0.1 substitutes a finite hour angle outside the acos domain. Reject
    // polar days explicitly rather than presenting that result as a sunrise.
    if (!sunriseCos.isFinite || sunriseCos.abs() > 1) {
      throw const PrayerException(PrayerFailure.calculationUnavailable);
    }
    final c = place.calculation;
    final p = switch (c.method) {
      PrayerMethod.muslimWorldLeague =>
        adhan.CalculationMethodParameters.muslimWorldLeague(),
      PrayerMethod.egyptian => adhan.CalculationMethodParameters.egyptian(),
      PrayerMethod.karachi => adhan.CalculationMethodParameters.karachi(),
      PrayerMethod.ummAlQura => adhan.CalculationMethodParameters.ummAlQura(),
      PrayerMethod.northAmerica =>
        adhan.CalculationMethodParameters.northAmerica(),
    };
    p.madhab = c.madhhab == PrayerMadhhab.hanafi
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
    final result = adhan.PrayerTimes(
      date: day,
      coordinates: adhan.Coordinates(place.latitude, place.longitude),
      calculationParameters: p,
    );
    final coordinates = adhan.Coordinates(place.latitude, place.longitude);
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
    bool unreachable(double angle) =>
        ((math.sin(-angle * math.pi / 180) -
                    math.sin(latitude) * math.sin(declination)) /
                (math.cos(latitude) * math.cos(declination)))
            .abs() >
        1;
    if (unreachable(p.fajrAngle) ||
        result.fajr.isBefore(earliestFajr) ||
        !result.fajr.isBefore(result.sunrise)) {
      result.fajr = DateTime.fromMillisecondsSinceEpoch(
        (earliestFajr.millisecondsSinceEpoch / 60000).round() * 60000,
        isUtc: true,
      );
    }
    if (p.ishaInterval == 0 &&
        (unreachable(p.ishaAngle) ||
            result.isha.isAfter(latestIsha) ||
            !result.isha.isAfter(result.sunset))) {
      result.isha = DateTime.fromMillisecondsSinceEpoch(
        (latestIsha.millisecondsSinceEpoch / 60000).round() * 60000,
        isUtc: true,
      );
    }
    // Use solar declination at Asr, not midnight, for the shadow angle. Keep
    // the pinned library's independent Meeus solver and all method offsets.
    var hours = result.asr.difference(day).inSeconds / 3600;
    for (var i = 0; i < 3; i++) {
      final jd = Astronomical.julianDay(day.year, day.month, day.day, hours);
      final decl = SolarCoordinates(jd).declination!;
      final shadow =
          c.asrFactor + math.tan((place.latitude - decl).abs() * math.pi / 180);
      final angle = math.atan(1 / shadow) * 180 / math.pi;
      hours = solar.hourAngle(angle, true);
    }
    if (!hours.isFinite) {
      throw const PrayerException(PrayerFailure.calculationUnavailable);
    }
    result.asr = day.add(Duration(minutes: (hours * 60).round()));
    return result;
  }

  DailyPrayerSchedule schedule(SavedLocation location, DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final fingerprint = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'place': location.toJson(),
              'date': day.toIso8601String(),
              'calculator': 'adhan_dart-2.0.1',
              'timezone': '0.11.2',
              'ramadan': calendar['sourceVersion'],
              'convention': 1,
            }),
          ),
        )
        .toString();
    DailyPrayerSchedule unavailable(String reason) => DailyPrayerSchedule(
      locationId: location.id,
      localDate: day,
      timezoneId: location.timezoneId,
      fingerprint: fingerprint,
      generatedAtUtc: clock(),
      events: [
        for (final kind in PrayerKind.values.take(6))
          PrayerEvent(
            kind,
            null,
            availability: PrayerAvailability.unavailable,
            reason: reason,
          ),
      ],
      qiyamReason: reason,
    );
    try {
      if (location.calculation.conventionVersion != 1) {
        return unavailable('conventionOutOfRange');
      }
      final t = _calculate(location, day);
      final next = _calculate(location, day.add(const Duration(days: 1)));
      final values = {
        PrayerKind.fajr: t.fajr,
        PrayerKind.sunrise: t.sunrise,
        PrayerKind.dhuhr: t.dhuhr,
        PrayerKind.asr: t.asr,
        PrayerKind.maghrib: t.maghrib,
        PrayerKind.isha: t.isha,
      };
      // Flag an explicit night-fraction cap rather than every high-latitude time.
      final fraction =
          location.calculation.highLatitudeRule ==
              HighLatitudeRule.middleOfNight
          ? 0.5
          : 1 / 7;
      final night = next.sunrise.difference(t.sunset).inSeconds;
      final cap = night * fraction;
      bool adjusted(PrayerKind k, DateTime value) {
        if (k == PrayerKind.isha) {
          return (value.difference(t.sunset).inSeconds - cap).abs() < 60;
        }
        if (k == PrayerKind.fajr) {
          final prior = _calculate(
            location,
            day.subtract(const Duration(days: 1)),
          );
          final priorNight = t.sunrise.difference(prior.sunset).inSeconds;
          return (t.sunrise.difference(value).inSeconds - priorNight * fraction)
                  .abs() <
              60;
        }
        return false;
      }

      return DailyPrayerSchedule(
        locationId: location.id,
        localDate: day,
        timezoneId: location.timezoneId,
        fingerprint: fingerprint,
        generatedAtUtc: clock(),
        followingFajrUtc: next.fajr.toUtc(),
        qiyamUtc: qiyamStart(t.maghrib.toUtc(), next.fajr.toUtc()),
        events: [
          for (final e in values.entries)
            PrayerEvent(
              e.key,
              e.value.toUtc(),
              availability: adjusted(e.key, e.value)
                  ? PrayerAvailability.adjusted
                  : PrayerAvailability.available,
              adjustmentLabel: adjusted(e.key, e.value)
                  ? location.calculation.highLatitudeRule.name
                  : null,
            ),
        ],
      );
    } on PrayerException catch (e) {
      return unavailable(e.reason.name);
    } on Object {
      return unavailable('calculationUnavailable');
    }
  }

  PrayerEvent? nextPrayer(SavedLocation location, DateTime now) {
    final local = tz.TZDateTime.from(now, prayerTimeZone(location.timezoneId));
    for (var offset = 0; offset < 3; offset++) {
      final day = DateTime.utc(local.year, local.month, local.day + offset);
      final candidates =
          schedule(location, day).events
              .where(
                (e) =>
                    dailyPrayers.contains(e.kind) &&
                    e.dueAtUtc != null &&
                    e.dueAtUtc!.isAfter(now),
              )
              .toList()
            ..sort((a, b) => a.dueAtUtc!.compareTo(b.dueAtUtc!));
      if (candidates.isNotEmpty) return candidates.first;
    }
    return null;
  }
}
