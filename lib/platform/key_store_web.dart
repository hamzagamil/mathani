import '../data/user_repository.dart';
import '../features/khatma/group/group_key.dart';

/// Browsers have no secure storage: the key is a row in the site's own database. This is the
/// exception the plan records (specs/014 Complexity Tracking).
KeyStore keyStore(UserRepository user) => PreferenceKeyStore(user);

class PreferenceKeyStore implements KeyStore {
  PreferenceKeyStore(this._user);
  static const name = 'group.key';
  final UserRepository _user;

  @override
  Future<String?> read() => _user.readPreference(name);

  @override
  Future<String> create() async {
    final existing = await read();
    if (existing != null) return existing;
    final key = newDeviceKey();
    await _user.writePreference(name, key);
    return key;
  }

  @override
  Future<void> delete() => _user.deletePreference(name);
}
