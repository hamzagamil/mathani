import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_repository.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_controller.dart';

class Store implements PrayerSnapshotStore {
  String? data;
  bool broken = false;
  int writes = 0;
  @override
  Future<String?> read() async {
    if (broken) throw StateError('unavailable');
    return data;
  }

  @override
  Future<void> write(String value) async {
    writes++;
    data = value;
  }

  @override
  Future<void> delete() async {
    data = null;
  }
}

class Locations implements PrayerLocationClient {
  @override
  Future<Map<String, dynamic>> resolve(
    Map<String, dynamic> candidate,
    String language,
  ) async => candidate;
  int accesses = 0;
  @override
  Future<Map<String, dynamic>> approximate(String language) async {
    accesses++;
    return {
      'city': 'Cairo',
      'countryCode': 'EG',
      'latitude': 30.0444,
      'longitude': 31.2357,
      'timezoneId': 'Africa/Cairo',
      'source': 'ip',
      'approximate': true,
      'requiresConfirmation': true,
    };
  }

  @override
  Future<Map<String, dynamic>> detect(String language) async {
    accesses++;
    throw const PrayerException(PrayerFailure.locationDenied);
  }

  @override
  Future<List<Map<String, dynamic>>> search(String q, String language) async =>
      [];
  @override
  void cancelSearch() {}
  @override
  void dispose() {}
}

void main() {
  final calendar = jsonDecode(
    File('assets/prayer/ramadan_intervals.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  PrayerController controller(Store store, Locations locations) =>
      PrayerController(
        repository: PrayerRepository(store),
        locationClient: locations,
        calculator: PrayerCalculator(calendar),
      );
  test(
    'loading never accesses location; denied detection preserves setup',
    () async {
      final source = Locations();
      final c = controller(Store(), source);
      await c.initialize();
      expect(source.accesses, 0);
      await c.detect('en');
      expect(c.failure, PrayerFailure.locationDenied);
      expect(c.state.activeLocationId, isNull);
    },
  );
  test('IP cannot activate or persist before explicit confirmation; saved place survives restart', () async {
    final store = Store();
    final c = controller(store, Locations());
    await c.initialize();
    await c.approximate('en');
    expect(c.candidate, isNotNull);
    expect(c.state.locations, isEmpty);
    expect(store.writes, 0);
    await c.confirmCandidate();
    expect(c.state.activeLocation!.source, LocationSource.ip);
    expect(c.state.activeLocation!.approximate, isTrue);
    expect(
      (await PrayerRepository(store).load()).locations.single.timezoneId,
      'Africa/Cairo',
    );
  });
  test(
    'unreadable snapshot cannot be overwritten; session recovery explicit',
    () async {
      final store = Store()
        ..data = 'ciphertext-not-a-snapshot'
        ..broken = true;
      final r = PrayerRepository(store);
      await expectLater(r.load(), throwsA(isA<PrayerException>()));
      await expectLater(r.save(PrayerState()), throwsA(isA<PrayerException>()));
      expect(store.writes, 0);
      r.useSessionOnly();
      await r.save(PrayerState());
      expect(store.data, 'ciphertext-not-a-snapshot');
      expect(r.sessionOnly, isTrue);
    },
  );
  test('location label/coordinate bounds and unique IDs are enforced', () {
    SavedLocation p(String id, String label, {double latitude = 30}) =>
        SavedLocation(
          id: id,
          label: label,
          latitude: latitude,
          longitude: 31,
          timezoneId: 'Africa/Cairo',
          source: LocationSource.manual,
          confirmedAtUtc: DateTime.utc(2026),
        );
    expect(() => p('a', 'x' * 81), throwsFormatException);
    expect(() => p('a', ''), throwsFormatException);
    expect(() => p('a', 'City', latitude: 91), throwsFormatException);
    expect(
      () => PrayerState(locations: [p('a', 'Home'), p('a', 'Other')]),
      throwsFormatException,
    );
    expect(
      () => ReminderPreferences(enabledPrayers: {PrayerKind.sunrise}),
      throwsFormatException,
    );
  });
  test('future versions fail safely without overwriting', () async {
    final store = Store()
      ..data = jsonEncode({
        'schemaVersion': 2,
        'revision': 0,
        'locations': [],
        'activeLocationId': null,
        'reminders': ReminderPreferences().toJson(),
      });
    await expectLater(
      PrayerRepository(store).load(),
      throwsA(isA<PrayerException>()),
    );
    expect(store.writes, 0);
  });
}
