import 'dart:async';
import 'dart:convert';

import '../../data/user_repository.dart';
import 'prayer_models.dart';

/// Where the prayer JSON lives. [UserPrayerStateStore] in the app; a map in tests.
abstract interface class PrayerStateStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// The `prayer.state` row of user.db's `preferences` table (research R6).
class UserPrayerStateStore implements PrayerStateStore {
  UserPrayerStateStore(this._user);
  final UserRepository _user;
  @override
  Future<String?> read() => _user.readPreference(UserRepository.prayerStateKey);
  @override
  Future<void> write(String value) =>
      _user.writePreference(UserRepository.prayerStateKey, value);
  @override
  Future<void> delete() =>
      _user.deletePreference(UserRepository.prayerStateKey);
}

/// Loads and saves [PrayerState]. A missing, unreadable or newer-schema value loads as "not set
/// up" and is left untouched until the next [save], so an older app never destroys newer data.
class PrayerRepository {
  PrayerRepository(this._store);
  final PrayerStateStore _store;
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<PrayerState> load() => _serial(() async {
    final raw = await _store.read();
    if (raw == null) return PrayerState();
    try {
      return PrayerState.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      return PrayerState();
    }
  });

  Future<void> save(PrayerState state) =>
      _serial(() => _store.write(jsonEncode(state.toJson())));

  Future<void> delete() => _serial(_store.delete);
}

/// In-memory store, for tests.
class MemoryPrayerStateStore implements PrayerStateStore {
  MemoryPrayerStateStore([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> delete() async => value = null;
}
