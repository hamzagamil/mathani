// Fakes for the prayer-times tests (specs/009): no network, location, notifications or audio.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show TargetPlatform;

import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/prayer_times/athan_catalogue.dart';
import 'package:mathani/features/prayer_times/athan_player.dart';
import 'package:mathani/features/prayer_times/prayer_alerts.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_repository.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';
import 'package:mathani/platform/file_store.dart';

PrayerCalculator testCalculator() => PrayerCalculator(
  jsonDecode(File('assets/prayer/ramadan_intervals.json').readAsStringSync())
      as Map<String, dynamic>,
);

AppLocalizations english() => lookupAppLocalizations(const Locale('en'));

Map<String, dynamic> cairoResult({String source = 'search'}) => {
  'city': 'Cairo',
  'region': 'Cairo',
  'countryCode': 'EG',
  'latitude': 30.0444,
  'longitude': 31.2357,
  'timezoneId': 'Africa/Cairo',
  'source': source,
};

Map<String, dynamic> londonResult({String source = 'search'}) => {
  'city': 'London',
  'region': 'England',
  'countryCode': 'GB',
  'latitude': 51.5074,
  'longitude': -0.1278,
  'timezoneId': 'Europe/London',
  'source': source,
};

Place place(
  Map<String, dynamic> result, {
  String id = 'p1',
  CalculationSettings? calculation,
}) => Place.fromResult(result, id: id, calculation: calculation);

class FakeLocation implements PrayerLocationClient {
  Map<String, dynamic> detected = cairoResult(source: 'location');
  Map<String, dynamic> resolved = cairoResult(source: 'location');
  Map<String, dynamic>? estimate = cairoResult(source: 'estimate');
  List<Map<String, dynamic>> found = [cairoResult()];
  ({double latitude, double longitude})? position;
  PrayerFailure? detectFailure;
  bool granted = false;
  int detects = 0, resolves = 0, estimates = 0;

  @override
  Future<bool> canLocate() async => granted;
  @override
  Future<Map<String, dynamic>> detect(String language) async {
    detects++;
    if (detectFailure != null) throw PrayerException(detectFailure!);
    return detected;
  }

  @override
  Future<({double latitude, double longitude})?> passivePosition() async =>
      granted ? position : null;
  @override
  Future<Map<String, dynamic>> resolve(
    double latitude,
    double longitude,
    String language, {
    String source = 'manual',
  }) async {
    resolves++;
    return resolved;
  }

  @override
  Future<List<Map<String, dynamic>>> search(String q, String language) async =>
      found;
  @override
  Future<Map<String, dynamic>> approximate(String language) async {
    estimates++;
    final e = estimate;
    if (e == null) throw const PrayerException(PrayerFailure.offline);
    return e;
  }

  @override
  void cancelSearch() {}
  @override
  void dispose() {}
}

class FakeAlerts implements PrayerAlertPlatform {
  NotificationPermission permission = NotificationPermission.notDetermined;
  bool? exactAlarms;
  int requests = 0, cancels = 0;
  final replaced = <List<Alert>>[];
  final generations = <int>[];
  final controller = StreamController<PrayerPlatformEvent>.broadcast();
  AlertOpened? launch;

  List<Alert> get pending => replaced.isEmpty ? const [] : replaced.last;

  @override
  Future<AlertStatus> status() async =>
      AlertStatus(permission, exactAlarms: exactAlarms);
  @override
  Future<AlertStatus> requestPermission() async {
    requests++;
    // The system prompt appears only once; a refusal stays a refusal.
    if (permission == NotificationPermission.notDetermined) {
      permission = NotificationPermission.granted;
    }
    return status();
  }

  @override
  Future<void> openSettings({bool exactAlarms = false}) async {}
  @override
  Future<int> replace(List<Alert> alerts, int generation) async {
    replaced.add(alerts);
    generations.add(generation);
    return alerts.length;
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
    replaced.add(const []);
  }

  @override
  Stream<PrayerPlatformEvent> get events => controller.stream;
  @override
  Future<AlertOpened?> takeLaunchOpen() async => launch;
}

class FakePort implements AthanPlaybackPort {
  final played = <AthanSource>[];
  int stops = 0;
  Completer<void>? _current;
  @override
  Future<void> play(AthanSource source) {
    played.add(source);
    return (_current = Completer<void>()).future;
  }

  @override
  Future<void> stop() async {
    stops++;
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) c.complete();
  }
}

class Harness {
  Harness({
    String? stored,
    DateTime? now,
    AthanCatalogue? catalogue,
    this.target,
  }) : store = MemoryPrayerStateStore(stored),
       clock = now ?? DateTime.utc(2026, 3, 15, 8),
       catalogue = catalogue ?? AthanCatalogue(const []);
  final MemoryPrayerStateStore store;
  final location = FakeLocation();
  final alerts = FakeAlerts();
  final port = FakePort();
  final AthanCatalogue catalogue;
  final TargetPlatform? target;
  DateTime clock;
  int quranPauses = 0, memorizationPauses = 0;

  late final hub = PrayerAlerts(
    store: store,
    l10n: english,
    pauseQuran: () => quranPauses++,
    pauseMemorization: () => memorizationPauses++,
    clock: () => clock,
    platform: target,
    services: () async {
      final downloads = AthanDownloads(files: NoFiles());
      return PrayerServices(
        calculator: testCalculator(),
        catalogue: catalogue,
        downloads: downloads,
        player: AthanPlayer(
          catalogue: catalogue,
          downloads: downloads,
          pauseQuran: () => quranPauses++,
          pauseMemorization: () => memorizationPauses++,
          port: port,
        ),
        platform: alerts,
        location: location,
      );
    },
  );
}

/// Nothing is ever downloaded in these tests.
class NoFiles implements FileStore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Object?>.error(const FileSystemException('none'));
}
