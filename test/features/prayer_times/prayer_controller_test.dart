import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mathani/features/prayer_times/prayer_controller.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';

import '../../support/prayer_fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  final now = DateTime.utc(2026, 3, 15, 8);

  Future<(Harness, PrayerController)> start([PrayerState? s]) async {
    final h = Harness(
      stored: s == null ? null : jsonEncode(s.toJson()),
      now: now,
    );
    final c = PrayerController(hub: h.hub, clock: () => h.clock);
    await c.initialize();
    return (h, c);
  }

  group('Story 1: setting the first place', () {
    test('Use my location sets My location as current', () async {
      final (h, c) = await start();
      await c.useMyLocation('en');
      expect(c.state.current, myLocationKey);
      expect(c.state.myLocation!.city, 'Cairo');
      expect(c.state.myLocation!.source, PlaceSource.location);
      expect(c.state.myLocation!.calculation.method, PrayerMethod.egyptian);
      expect(c.viewedPlace!.id, c.state.myLocation!.id);
      expect(c.schedule!.events, hasLength(6));
      expect(h.store.value, isNotNull);
    });

    test('a refusal is not asked again in the session (FR-018)', () async {
      final (h, c) = await start();
      h.location.detectFailure = PrayerFailure.locationDenied;
      await c.useMyLocation('en');
      await c.useMyLocation('en');
      expect(h.location.detects, 1);
      expect(c.failure, PrayerFailure.locationDenied);
      expect(c.state.isSetUp, isFalse);
    });

    test(
      'the estimate is suggested only when location cannot be used',
      () async {
        final (h, c) = await start();
        h.location.granted = true;
        await c.loadSuggestion('en');
        expect(c.suggestion, isNull);
        h.location.granted = false;
        await c.loadSuggestion('en');
        expect(c.suggestion!['source'], 'estimate');
        await c.choosePlace(c.suggestion!, 'en');
        expect(c.state.currentPlace!.source, PlaceSource.estimate);
      },
    );

    test('the first searched place becomes current; a later one is saved '
        'without moving alerts (FR-010)', () async {
      final (h, c) = await start();
      await c.choosePlace(cairoResult(), 'en');
      final cairo = c.state.currentPlace!;
      await c.choosePlace(londonResult(), 'en');
      expect(c.state.places, hasLength(2));
      expect(c.state.currentPlace!.id, cairo.id);
      expect(c.viewedPlace!.city, 'London');
      expect(c.viewingCurrent, isFalse);
    });

    test('a result without a time zone is resolved first', () async {
      final (h, c) = await start();
      await c.choosePlace({...londonResult(), 'timezoneId': null}, 'en');
      expect(h.location.resolves, 1);
    });

    test('day navigation; the countdown is on today only', () async {
      final (h, c) = await start();
      await c.choosePlace(cairoResult(), 'en');
      final today = c.viewedDate!;
      expect(c.nextPrayer, isNotNull);
      c.changeDay(1);
      expect(c.viewedDate, today.add(const Duration(days: 1)));
      expect(c.nextPrayer, isNull);
      c.changeDay(0);
      expect(c.viewedDate, today);
    });
  });

  group('Story 2: calculation', () {
    test(
      'choosing a method marks it chosen and bumps the generation',
      () async {
        final (h, c) = await start();
        await c.choosePlace(cairoResult(), 'en');
        final p = c.state.currentPlace!;
        final generation = c.state.generation;
        await c.updateCalculation(
          p.id,
          p.calculation.copyWith(
            method: PrayerMethod.muslimWorldLeague,
            offsets: {PrayerKind.isha: 30},
          ),
        );
        final s = c.state.currentPlace!.calculation;
        expect(s.methodChosen, isTrue);
        expect(s.offset(PrayerKind.isha), 30);
        expect(c.state.generation, generation + 1);
      },
    );

    test('settings belong to one place (FR-016)', () async {
      final (h, c) = await start();
      await c.choosePlace(cairoResult(), 'en');
      await c.choosePlace(londonResult(), 'en');
      final london = c.state.places.last;
      await c.updateCalculation(
        london.id,
        london.calculation.copyWith(asr: AsrSetting.hanafi),
      );
      expect(c.state.places.first.calculation.asr, AsrSetting.standard);
      expect(c.state.places.last.calculation.asr, AsrSetting.hanafi);
    });
  });

  group('Story 3: places', () {
    Future<(Harness, PrayerController)> three() async {
      final (h, c) = await start();
      await c.choosePlace(cairoResult(), 'en');
      await c.choosePlace(londonResult(), 'en');
      await c.useMyLocation('en');
      return (h, c);
    }

    test('Use this place moves alerts; viewing does not', () async {
      final (h, c) = await three();
      final london = c.state.places.last;
      c.viewPlace(london.id);
      expect(c.state.current, myLocationKey);
      await c.usePlace(london.id);
      expect(c.state.current, london.id);
    });

    test(
      'deleting the current place needs a replacement or alerts off',
      () async {
        final (h, c) = await three();
        final cairo = c.state.places.first;
        await c.usePlace(cairo.id);
        await c.setPrayerAlert(PrayerKind.fajr, true);
        await c.deletePlace(cairo.id);
        expect(
          c.state.placeById(cairo.id),
          isNotNull,
          reason: 'no choice made',
        );
        await c.deletePlace(cairo.id, replacementId: c.state.places.last.id);
        expect(c.state.placeById(cairo.id), isNull);
        expect(c.state.current, c.state.places.last.id);
        expect(c.state.alerts.prayers, {PrayerKind.fajr});
        await c.deletePlace(c.state.places.last.id, alertsOff: true);
        expect(c.state.current, myLocationKey);
        expect(c.state.alerts.any, isFalse);
      },
    );

    test('deleting the last place returns to setup and stops alerts', () async {
      final (h, c) = await start();
      await c.choosePlace(cairoResult(), 'en');
      await c.setPrayerAlert(PrayerKind.fajr, true);
      await c.deletePlace(c.state.places.single.id, alertsOff: true);
      expect(c.state.isSetUp, isFalse);
      expect(h.alerts.pending, isEmpty);
    });

    test('renaming keeps 1–80 characters', () async {
      final (h, c) = await start();
      await c.choosePlace(cairoResult(), 'en');
      final id = c.state.places.single.id;
      await c.renamePlace(id, '  Home  ');
      expect(c.state.places.single.name, 'Home');
      await c.renamePlace(id, '');
      expect(c.state.places.single.name, 'Home');
    });

    test('delete all keeps nothing and cancels alerts', () async {
      final (h, c) = await three();
      await c.setPrayerAlert(PrayerKind.fajr, true);
      await c.deleteAllPrayerData();
      expect(c.state.isSetUp, isFalse);
      expect(h.store.value, isNull);
      expect(h.alerts.pending, isEmpty);
    });
  });

  group('Story 4: alerts', () {
    test('the first alert asks for permission, once (FR-018)', () async {
      final (h, c) = await start();
      await c.choosePlace(cairoResult(), 'en');
      await c.setPrayerAlert(PrayerKind.fajr, true);
      await c.setPrayerAlert(PrayerKind.isha, true);
      expect(h.alerts.requests, 1);
      expect(h.alerts.pending.map((a) => a.kind).toSet(), {
        PrayerKind.fajr,
        PrayerKind.isha,
      });
    });

    test('a refusal keeps the choices', () async {
      final (h, c) = await start();
      await c.choosePlace(cairoResult(), 'en');
      h.alerts.permission = NotificationPermission.denied;
      await c.setPrayerAlert(PrayerKind.fajr, true);
      expect(c.state.alerts.prayers, {PrayerKind.fajr});
      expect(h.alerts.permission, NotificationPermission.denied);
    });

    test('Qiyam is separate from prayer alerts (Story 6)', () async {
      final (h, c) = await start();
      await c.choosePlace(cairoResult(), 'en');
      await c.setPrayerAlert(PrayerKind.dhuhr, true);
      await c.setQiyam(true);
      expect(c.nextQiyam, isNotNull);
      await c.setQiyam(false);
      expect(c.state.alerts.prayers, {PrayerKind.dhuhr});
      expect(h.alerts.pending.any((a) => a.kind == PrayerKind.qiyam), isFalse);
    });

    test(
      'only listed sounds can be chosen; preview pauses Quran first',
      () async {
        final (h, c) = await start();
        await c.choosePlace(cairoResult(), 'en');
        await c.setSound('unknown');
        expect(c.state.alerts.sound, toneSound);
        await c.setSound(silentSound);
        expect(c.state.alerts.sound, silentSound);
        final playing = c.preview(toneSound);
        await Future<void>.delayed(Duration.zero);
        expect(h.quranPauses, 1);
        expect(h.memorizationPauses, 1);
        expect(c.services.player.playing.value, toneSound);
        await c.stopSound();
        await playing;
        expect(c.services.player.playing.value, isNull);
      },
    );
  });
}
