// The device key of the group khatma (specs/014 research R15): 32 random bytes, made the first
// time the reader starts, joins or reports, never before (FR-065). It proves which parts are the
// reader's; the server keeps only its hash.
import 'dart:convert';
import 'dart:math';

/// Where the key is kept: the platform's secure storage on phones, the site's data in browsers.
abstract interface class KeyStore {
  /// The key, or null when none was made on this device.
  Future<String?> read();

  /// Makes and keeps a new key, or returns the one already kept.
  Future<String> create();

  Future<void> delete();
}

/// A new key: 32 random bytes as 43 base64url characters.
String newDeviceKey([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => r.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// A key kept in memory, for tests.
class MemoryKeyStore implements KeyStore {
  MemoryKeyStore([this.key]);
  String? key;

  @override
  Future<String?> read() async => key;

  @override
  Future<String> create() async => key ??= newDeviceKey();

  @override
  Future<void> delete() async => key = null;
}
