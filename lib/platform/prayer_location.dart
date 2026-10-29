import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../features/prayer_times/prayer_services.dart';

class PrayerLocationService implements PrayerLocationClient {
  PrayerLocationService({Uri? baseUri}) : baseUri = baseUri ?? _defaultBase();
  final Uri baseUri;
  http.Client? _search;
  final _client = http.Client();
  int _searchGeneration = 0;
  bool _disposed = false;
  DateTime? _retryAfter;
  static Uri _defaultBase() {
    const override = String.fromEnvironment('PRAYER_API_BASE');
    final uri = override.isNotEmpty
        ? Uri.parse(override)
        : Uri.parse(kIsWeb ? Uri.base.origin : 'https://get.mthani.app');
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' &&
            ['localhost', '127.0.0.1'].contains(uri.host))) {
      throw ArgumentError('Prayer API must use HTTPS');
    }
    return uri;
  }

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
      throw const PrayerException(PrayerFailure.providerUnavailable);
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
          .map((v) => Map<String, dynamic>.from(v as Map))
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

  @override
  Future<Map<String, dynamic>> resolve(
    Map<String, dynamic> candidate,
    String language,
  ) => _request(
    '/api/prayer-resolve',
    body: {
      'latitude': candidate['latitude'],
      'longitude': candidate['longitude'],
      'source': candidate['source'] ?? 'manual',
      'lang': language,
    },
  );
  @override
  Future<Map<String, dynamic>> approximate(String language) =>
      _request('/api/prayer-location');
  @override
  Future<Map<String, dynamic>> detect(String language) async {
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
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final result = await resolve({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'source': 'device',
      }, language);
      return {
        ...result,
        'accuracyMeters': position.accuracy,
        'approximate': position.accuracy > 1000,
      };
    } on PrayerException {
      rethrow;
    } on Object {
      throw const PrayerException(PrayerFailure.locationUnavailable);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancelSearch();
    _client.close();
  }
}
