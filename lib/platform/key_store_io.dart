import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/user_repository.dart';
import '../features/khatma/group/group_key.dart';

/// Phones: the key in the platform's secure storage (constitution: sensitive data). On iPhone it
/// is "after first unlock, this device only", and a key left in the Keychain by an earlier
/// install is removed on the first launch, so deleting the app loses the key (spec Assumptions).
KeyStore keyStore(UserRepository user) => SecureKeyStore(user);

class SecureKeyStore implements KeyStore {
  SecureKeyStore(this._user, {FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  static const _name = 'mathani.group.key';
  static const installedKey = 'group.installed';
  final UserRepository _user;
  final FlutterSecureStorage _storage;
  Future<void>? _checked;

  /// The first time on this install: forget a key from an earlier one.
  Future<void> _checkInstall() => _checked ??= () async {
        if (await _user.readPreference(installedKey) != null) return;
        await _storage.delete(key: _name);
        await _user.writePreference(installedKey, '1');
      }();

  @override
  Future<String?> read() async {
    await _checkInstall();
    return _storage.read(key: _name);
  }

  @override
  Future<String> create() async {
    final existing = await read();
    if (existing != null) return existing;
    final key = newDeviceKey();
    await _storage.write(key: _name, value: key);
    return key;
  }

  @override
  Future<void> delete() => _storage.delete(key: _name);
}
