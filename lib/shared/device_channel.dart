import 'package:flutter/services.dart';

/// Whether the device is online, and whether its connection is metered
/// (specs/004-ayah-recitations/contracts/audio-storage.md › Platform channel).
enum NetworkState { none, unmetered, metered }

/// Network type, free storage and backup exclusion, from a small platform channel implemented
/// in MainActivity.kt and AppDelegate.swift (research R8). Where the channel is missing (tests,
/// the browser preview) it reports an unmetered connection and ample storage.
class DeviceChannel {
  const DeviceChannel();

  static const _channel = MethodChannel('app.mathani/device');

  Future<NetworkState> networkState() async {
    try {
      return switch (await _channel.invokeMethod<String>('networkState')) {
        'none' => NetworkState.none,
        'metered' => NetworkState.metered,
        _ => NetworkState.unmetered,
      };
    } on MissingPluginException {
      return NetworkState.unmetered;
    } on PlatformException {
      return NetworkState.unmetered;
    }
  }

  Future<int> freeBytes() async {
    try {
      return await _channel.invokeMethod<int>('freeBytes') ?? 1 << 40;
    } on MissingPluginException {
      return 1 << 40;
    } on PlatformException {
      return 1 << 40;
    }
  }

  /// Keeps [path] (a directory) out of iCloud backups. A no-op on Android.
  Future<void> excludeFromBackup(String path) async {
    try {
      await _channel.invokeMethod<void>('excludeFromBackup', {'path': path});
    } on MissingPluginException {
      // Not available: nothing to exclude from.
    } on PlatformException {
      // Best effort: the files stay in the backup.
    }
  }
}
