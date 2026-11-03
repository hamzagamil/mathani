import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../features/prayer_times/prayer_models.dart';
import '../features/prayer_times/prayer_services.dart';
import 'api_base.dart';

/// The endpoints' `source` names, as the app calls them (contracts/location-api.md).
const _sources = {'device': 'location', 'manual': 'search', 'ip': 'estimate'};

/// A place from the endpoints with rounded coordinates and the app's source name.
Map<String, dynamic> _normalized(Map<String, dynamic> place) => {
  ...place,
  if (place['latitude'] is num)
    'latitude': roundCoordinate((place['latitude'] as num).toDouble()),
  if (place['longitude'] is num)
    'longitude': roundCoordinate((place['longitude'] as num).toDouble()),
  'source': _sources[place['source']] ?? place['source'],
};

class PrayerLocationService implements PrayerLocationClient {
  PrayerLocationService({Uri? baseUri}) : baseUri = baseUri ?? apiBase();
  final Uri baseUri;
  http.Client? _search;
  final _client = http.Client();
  int _searchGeneration = 0;
  bool _disposed = false;
  DateTime? _retryAfter;

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    http.Client? client,
  }) async {
    if (_disposed) {
      throw const PrayerException(PrayerFailure.locationUnavailable);
    }
    if (_retryAfter?.isAfter(DateTime.now()) ?? false) {
      throw const PrayerException(PrayerFailure.rateLimited);
    }
    try {
      final uri = baseUri.resolve(path).replace(queryParameters: query);
      final response = body == null
          ? await (client ?? _client)
                .get(uri)
                .timeout(const Duration(seconds: 10))
          : await _client
                .post(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(body),
                )
                .timeout(const Duration(seconds: 10));
      final decoded = Map<String, dynamic>.from(
        jsonDecode(response.body) as Map,
      );
      if (response.statusCode == 429) {
        final seconds =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
        _retryAfter = DateTime.now().add(
          Duration(seconds: seconds.clamp(1, 3600)),
        );
      }
      if (response.statusCode != 200) {
        final code = (decoded['error'] as Map?)?['code'];
        throw PrayerException(switch (code) {
          'rateLimited' => PrayerFailure.rateLimited,
          'locationUnavailable' => PrayerFailure.locationUnavailable,
          'timezoneUnresolved' => PrayerFailure.timezoneUnresolved,
          _ => PrayerFailure.providerUnavailable,
        });
      }
      return decoded;
    } on PrayerException {
      rethrow;
    } on http.ClientException {
      throw const PrayerException(PrayerFailure.offline);
    } on TimeoutException {
      throw const PrayerException(PrayerFailure.providerUnavailable);
    } on Object {
      throw const PrayerException(PrayerFailure.providerUnavailable);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> search(
    String query,
    String language,
  ) async {
    cancelSearch();
    final token = _searchGeneration;
    final trimmed = query.trim();
    if (trimmed.length < 2 || trimmed.length > 80) return [];
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (_disposed || token != _searchGeneration) return [];
    final client = http.Client();
    _search = client;
    try {
      final result = await _request(
        '/api/prayer-places',
        query: {'q': trimmed, 'lang': language},
        client: client,
      );
      if (_disposed || token != _searchGeneration) return [];
      return (result['places'] as List)
          .map((v) => _normalized(Map<String, dynamic>.from(v as Map)))
          .toList();
    } finally {
      client.close();
      if (identical(_search, client)) _search = null;
    }
  }

  @override
  void cancelSearch() {
    _searchGeneration++;
    _search?.close();
    _search = null;
  }

  /// Coordinates are rounded to about 1 km before they leave the phone (R4).
  @override
  Future<Map<String, dynamic>> resolve(
    double latitude,
    double longitude,
    String language, {
    String source = 'manual',
  }) async => _normalized(
    await _request(
      '/api/prayer-resolve',
      body: {
        'latitude': roundCoordinate(latitude),
        'longitude': roundCoordinate(longitude),
        'source': source,
        'lang': language,
      },
    ),
  );

  @override
  Future<Map<String, dynamic>> approximate(String language) async =>
      _normalized(await _request('/api/prayer-location'));

  /// Approximate (city-level) accuracy only; never precise or background (FR-006).
  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.low,
    timeLimit: Duration(seconds: 15),
  );

  @override
  Future<Map<String, dynamic>> detect(String language) async {
    final Position position;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const PrayerException(PrayerFailure.locationUnavailable);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PrayerException(PrayerFailure.locationDenied);
      }
      position = await Geolocator.getCurrentPosition(
        locationSettings: _settings,
      );
    } on PrayerException {
      rethrow;
    } on Object {
      throw const PrayerException(PrayerFailure.locationUnavailable);
    }
    return resolve(
      position.latitude,
      position.longitude,
      language,
      source: 'device',
    );
  }

  @override
  Future<bool> canLocate() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } on Object {
      return false;
    }
  }

  @override
  Future<({double latitude, double longitude})?> passivePosition() async {
    try {
      if (!await canLocate()) return null;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: _settings,
      );
      return (
        latitude: roundCoordinate(p.latitude),
        longitude: roundCoordinate(p.longitude),
      );
    } on Object {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancelSearch();
    _client.close();
  }
}
