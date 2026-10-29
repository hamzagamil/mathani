import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'prayer_models.dart';
import 'prayer_services.dart';

class SecurePrayerSnapshotStore implements PrayerSnapshotStore {
  SecurePrayerSnapshotStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: false,
              storageNamespace: 'mathani_prayer',
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );
  static const key = 'mathani.prayer.snapshot.v1';
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete() => _storage.delete(key: key);
}

/// Dedicated ciphertext snapshot. Never opens or migrates user.db.
class PrayerRepository {
  PrayerRepository(this._store);
  final PrayerSnapshotStore _store;
  Future<void> _tail = Future<void>.value();
  bool _loaded = false, _sessionOnly = false;
  PrayerState? _session;
  bool get sessionOnly => _sessionOnly;
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace stack) {});
    return result;
  }

  Future<PrayerState> load() => _serial(() async {
    if (_sessionOnly) return _session ?? PrayerState();
    _loaded = false;
    try {
      final raw = await _store.read();
      final state = raw == null
          ? PrayerState()
          : PrayerState.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
      _loaded = true;
      return state;
    } on FormatException {
      throw const PrayerException(PrayerFailure.needsAttention);
    } on Object {
      throw const PrayerException(PrayerFailure.secureStorageUnavailable);
    }
  });

  /// Explicit recovery; never overwrites unreadable encrypted persistent data.
  void useSessionOnly() {
    _sessionOnly = true;
    _loaded = true;
    _session = PrayerState();
  }

  Future<void> save(PrayerState state) => _serial(() async {
    if (!_loaded) {
      throw const PrayerException(PrayerFailure.secureStorageUnavailable);
    }
    if (_sessionOnly) {
      _session = state;
      return;
    }
    try {
      await _store.write(jsonEncode(state.toJson()));
    } on Object {
      throw const PrayerException(PrayerFailure.secureStorageUnavailable);
    }
  });
  Future<void> delete() => _serial(() async {
    if (_sessionOnly) {
      _session = PrayerState();
      return;
    }
    try {
      await _store.delete();
      _loaded = true;
    } on Object {
      throw const PrayerException(PrayerFailure.secureStorageUnavailable);
    }
  });
}
