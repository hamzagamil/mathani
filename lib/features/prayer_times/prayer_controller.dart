import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'prayer_calculator.dart';
import 'prayer_models.dart';
import 'prayer_repository.dart';
import 'prayer_services.dart';
import 'prayer_time_zones.dart';

class PrayerController extends ChangeNotifier {
  PrayerController({
    required this.repository,
    required this.locationClient,
    required this.calculator,
    this.clock = prayerNow,
  });
  final PrayerRepository repository;
  final PrayerLocationClient locationClient;
  final PrayerCalculator calculator;
  final PrayerClock clock;
  PrayerState state = PrayerState();
  Map<String, dynamic>? candidate;
  List<Map<String, dynamic>> results = [];
  PrayerFailure? failure;
  bool busy = false, initialized = false, _disposed = false;
  bool searching = false;
  int _searchVersion = 0;
  DailyPrayerSchedule? schedule;
  PrayerEvent? _next;
  bool get sessionOnly => repository.sessionOnly;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    searching = false;
    failure = null;
    _notify();
    try {
      await action();
    } on PrayerException catch (e) {
      failure = e.reason;
    } on FormatException {
      failure = PrayerFailure.needsAttention;
    } on Object {
      failure = PrayerFailure.providerUnavailable;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> initialize() => _run(() async {
    state = await repository.load();
    initialized = true;
    refresh();
  });
  void refresh() {
    final location = state.activeLocation;
    if (location == null) {
      schedule = null;
      _next = null;
      _notify();
      return;
    }
    final local = tz.TZDateTime.from(
      clock(),
      prayerTimeZone(location.timezoneId),
    );
    schedule = calculator.schedule(
      location,
      DateTime.utc(local.year, local.month, local.day),
    );
    _next = calculator.nextPrayer(location, clock());
    _notify();
  }

  PrayerEvent? get nextPrayer {
    if (state.activeLocation == null) return null;
    if (_next?.dueAtUtc?.isAfter(clock()) != true) {
      _next = calculator.nextPrayer(state.activeLocation!, clock());
    }
    return _next;
  }

  Future<void> approximate(String language) => _run(() async {
    locationClient.cancelSearch();
    _searchVersion++;
    results = [];
    candidate = await locationClient.approximate(language);
    candidate = {
      ...candidate!,
      'source': 'ip',
      'approximate': true,
      'requiresConfirmation': true,
    };
  });
  Future<void> detect(String language) => _run(() async {
    locationClient.cancelSearch();
    _searchVersion++;
    results = [];
    candidate = await locationClient.detect(language);
  });
  Future<void> search(String q, String language) async {
    final token = ++_searchVersion;
    candidate = null;
    failure = null;
    results = [];
    searching = q.trim().length >= 2;
    _notify();
    try {
      final found = await locationClient.search(q, language);
      if (token == _searchVersion && !_disposed) {
        results = found;
        searching = false;
        _notify();
      }
    } on PrayerException catch (e) {
      if (token == _searchVersion && !_disposed) {
        failure = e.reason;
        searching = false;
        _notify();
      }
    } on Object {
      if (token == _searchVersion && !_disposed) {
        failure = PrayerFailure.providerUnavailable;
        searching = false;
        _notify();
      }
    }
  }

  Future<void> choose(Map<String, dynamic> place, {String language = 'en'}) =>
      _run(() async {
        locationClient.cancelSearch();
        _searchVersion++;
        candidate = place['timezoneId'] == null
            ? await locationClient.resolve(place, language)
            : Map.of(place);
        results = [];
      });
  void discardCandidate() {
    candidate = null;
    failure = null;
    _notify();
  }

  Future<void> confirmCandidate({String? label}) => _run(() async {
    final c = candidate;
    if (c == null || !initialized) {
      throw const PrayerException(PrayerFailure.needsAttention);
    }
    final city = c['city'] as String? ?? '';
    final country = c['countryCode'] as String? ?? '';
    final source = LocationSource.values.firstWhere(
      (v) => v.name == c['source'],
    );
    final id = base64UrlEncode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final location = SavedLocation(
      id: id,
      label:
          label ??
          (city.isNotEmpty
              ? city
              : [
                  (c['latitude'] as num).toStringAsFixed(3),
                  (c['longitude'] as num).toStringAsFixed(3),
                ].join(', ')),
      city: city,
      region: c['region'] as String? ?? '',
      countryCode: country,
      latitude: (c['latitude'] as num).toDouble(),
      longitude: (c['longitude'] as num).toDouble(),
      timezoneId: c['timezoneId'] as String,
      source: source,
      approximate: c['approximate'] as bool? ?? false,
      accuracyMeters: (c['accuracyMeters'] as num?)?.toDouble(),
      geonamesId: c['placeId'] as String?,
      confirmedAtUtc: clock(),
      calculation: CalculationPreferences(
        method: CalculationPreferences.suggestion(country),
      ),
    );
    final updated = PrayerState(
      revision: state.revision + 1,
      locations: [...state.locations, location],
      activeLocationId: id,
      reminders: state.reminders,
    );
    await repository.save(updated);
    if (_disposed) return;
    state = updated;
    candidate = null;
    refresh();
  });
  Future<void> useSessionOnly() => _run(() async {
    repository.useSessionOnly();
    state = await repository.load();
    initialized = true;
    refresh();
  });
  @override
  void dispose() {
    _disposed = true;
    _searchVersion++;
    locationClient.dispose();
    super.dispose();
  }
}
