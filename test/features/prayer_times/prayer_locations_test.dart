import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_controller.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_repository.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';

import 'prayer_setup_test.dart' show Store, Locations;

PrayerController placeController(
  Store store, {
  PrayerNotificationAdapter? notifications,
}) => PrayerController(
  repository: PrayerRepository(store),
  locationClient: Locations(),
  calculator: PrayerCalculator(
    jsonDecode(File('assets/prayer/ramadan_intervals.json').readAsStringSync())
        as Map<String, dynamic>,
  ),
  notifications: notifications ?? const NoPrayerNotifications(),
  clock: () => DateTime.utc(2026, 10, 29, 12),
);
Future<String> addPlace(
  PrayerController c,
  String label, {
  String city = 'Cairo',
  String country = 'EG',
  String zone = 'Africa/Cairo',
  double latitude = 30.0444,
  double longitude = 31.2357,
}) async {
  await c.choose({
    'city': city,
    'countryCode': country,
    'latitude': latitude,
    'longitude': longitude,
    'timezoneId': zone,
    'source': 'manual',
  });
  await c.confirmCandidate(label: label);
  return c.state.locations.last.id;
}

class Queue extends NoPrayerNotifications {
  int cancellations = 0;
  bool fail = false;
  @override
  Future<void> cancelAll() async {
    if (fail) throw const PrayerException(PrayerFailure.schedulePartial);
    cancellations++;
  }
}

void main() {
  test('enabled reminders require explicit activation and deletion can disable them', () async {
    final store = Store(), queue = Queue();
    final c = placeController(store, notifications: queue);
    addTearDown(c.dispose);
    await c.initialize();
    final home = await addPlace(c, 'Home');
    final work = await addPlace(c, 'Work');
    final snapshot = jsonDecode(store.data!) as Map<String, dynamic>;
    snapshot['reminders'] = ReminderPreferences(
      enabledPrayers: {PrayerKind.fajr},
      qiyamEnabled: true,
    ).toJson();
    store.data = jsonEncode(snapshot);
    await c.initialize();
    await c.activateLocation(work);
    expect(c.failure, PrayerFailure.needsAttention);
    expect(c.state.activeLocationId, home);
    await c.activateLocation(work, confirmed: true);
    expect(c.state.activeLocationId, work);
    expect(c.state.reminders.enabledPrayers, {PrayerKind.fajr});
    expect(c.state.reminders.qiyamEnabled, isTrue);
    final before = store.data;
    queue.fail = true;
    await c.deleteLocation(work, disableReminders: true);
    expect(store.data, before);
    queue.fail = false;
    await c.deleteLocation(work, disableReminders: true);
    expect(c.state.reminders.anyEnabled, isFalse);
    expect(c.state.activeLocationId, isNull);
    expect(c.state.locations.single.id, home);
    await c.initialize();
    expect(c.viewedLocationId, home);
    expect(c.state.activeLocationId, isNull);
    await addPlace(c, 'Another place');
    expect(
      c.state.activeLocationId,
      isNull,
      reason: 'Adding must not undo an explicit reminder-location disable',
    );
  });
  test('three places persist; viewing and duplicate cities do not change active location', () async {
    final store = Store();
    final persisted = placeController(store);
    addTearDown(persisted.dispose);
    await persisted.initialize();
    final home = await addPlace(persisted, 'Home');
    final work = await addPlace(persisted, 'Work');
    final sydney = await addPlace(
      persisted,
      'Sydney',
      city: 'Sydney',
      country: 'AU',
      zone: 'Australia/Sydney',
      latitude: -33.8688,
      longitude: 151.2093,
    );
    expect(persisted.state.activeLocationId, home);
    expect(persisted.viewedLocationId, sydney);
    expect(persisted.schedule!.timezoneId, 'Australia/Sydney');
    final revision = persisted.state.revision;
    persisted.viewLocation(work);
    expect(persisted.state.revision, revision);
    expect(persisted.state.locations.map((p) => p.id).toSet(), hasLength(3));
    final restarted = placeController(store);
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(restarted.state.locations, hasLength(3));
    expect(restarted.viewedLocationId, home);
  });
  test(
    'rename validates before writes and leaves reminder generation alone',
    () async {
      final store = Store();
      final subject = placeController(store);
      addTearDown(subject.dispose);
      await subject.initialize();
      final id = await addPlace(subject, 'Home');
      final generation = subject.state.generation, writes = store.writes;
      await subject.renameLocation(id, '  ');
      expect(subject.failure, PrayerFailure.needsAttention);
      expect(store.writes, writes);
      await subject.renameLocation(id, 'Work\nRoom');
      expect(store.writes, writes);
      await subject.renameLocation(id, '  Work  ');
      expect(subject.state.locations.single.label, 'Work');
      expect(subject.state.generation, generation);
    },
  );
  test('active deletion requires replacement or explicit disable; cancels old queue', () async {
    final queue = Queue();
    final subject = placeController(Store(), notifications: queue);
    addTearDown(subject.dispose);
    await subject.initialize();
    final a = await addPlace(subject, 'Home');
    final b = await addPlace(subject, 'Work');
    final generation = subject.state.generation;
    await subject.deleteLocation(a);
    expect(subject.failure, PrayerFailure.needsAttention);
    expect(subject.state.locations, hasLength(2));
    await subject.deleteLocation(a, replacementId: b);
    expect(subject.state.activeLocationId, b);
    expect(subject.state.generation, greaterThan(generation));
    expect(queue.cancellations, greaterThan(0));
    await subject.deleteLocation(b, disableReminders: true);
    expect(subject.state.locations, isEmpty);
    expect(subject.state.reminders.anyEnabled, isFalse);
    expect(subject.viewedLocation, isNull);
  });
  test(
    'clear removes snapshot only after queue cancellation succeeds',
    () async {
      final store = Store(), queue = Queue();
      final c = placeController(store, notifications: queue);
      addTearDown(c.dispose);
      await c.initialize();
      await addPlace(c, 'Home');
      final snapshot = store.data;
      await c.clearPrayerData();
      expect(store.data, snapshot);
      queue.fail = true;
      await c.clearPrayerData(confirmed: true);
      expect(store.data, snapshot);
      queue.fail = false;
      await c.clearPrayerData(confirmed: true);
      expect(store.data, isNull);
      expect(c.state.locations, isEmpty);
    },
  );
  test('failed persistence retains viewed and active schedules', () async {
    final store = FailingWriteStore();
    final c = placeController(store);
    addTearDown(c.dispose);
    await c.initialize();
    final a = await addPlace(c, 'Home');
    final b = await addPlace(c, 'Work');
    store.fail = true;
    await c.activateLocation(b, confirmed: true);
    expect(c.state.activeLocationId, a);
    expect(c.viewedLocationId, b);
    expect(c.failure, PrayerFailure.secureStorageUnavailable);
  });
}

class FailingWriteStore extends Store {
  bool fail = false;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('unavailable');
    await super.write(value);
  }
}
