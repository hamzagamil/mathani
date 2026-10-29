import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_controller.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_repository.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';

import 'prayer_setup_test.dart' show Locations, Store;

class DelayedLocations extends Locations {
  final pending = <String, Completer<List<Map<String, dynamic>>>>{};
  @override
  Future<List<Map<String, dynamic>>> search(String q, String language) =>
      (pending[q] = Completer<List<Map<String, dynamic>>>()).future;
}

void main() {
  test(
    'a late old search cannot overwrite newer results or failure state',
    () async {
      final source = DelayedLocations();
      final calendar = jsonDecode(
        File('assets/prayer/ramadan_intervals.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final c = PrayerController(
        repository: PrayerRepository(Store()),
        locationClient: source,
        calculator: PrayerCalculator(calendar),
      );
      await c.initialize();
      final old = c.search('old', 'en'), latest = c.search('new', 'en');
      source.pending['new']!.complete([
        {'city': 'New'},
      ]);
      await latest;
      source.pending['old']!.completeError(
        const PrayerException(PrayerFailure.offline),
      );
      await old;
      expect(c.results.single['city'], 'New');
      expect(c.failure, isNull);
      expect(c.searching, isFalse);
      c.dispose();
    },
  );
  test(
    'a later failed read revokes prior write readiness without destroying data',
    () async {
      final store = Store(), r = PrayerRepository(Store());
      await r.load();
      final guarded = PrayerRepository(store);
      await guarded.load();
      store.broken = true;
      store.data = 'preserve';
      await expectLater(guarded.load(), throwsA(isA<PrayerException>()));
      await expectLater(
        guarded.save(PrayerState()),
        throwsA(isA<PrayerException>()),
      );
      expect(store.data, 'preserve');
      expect(store.writes, 0);
    },
  );
}
