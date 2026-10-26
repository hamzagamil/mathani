import 'package:flutter/services.dart';

import 'device.dart' show NetworkState, WebSupport;

/// Network type, free storage and backup exclusion, from a small platform channel implemented
/// in MainActivity.kt and AppDelegate.swift (research R8), plus what memorization needs (specs/006
/// contracts/memorization-engine.md › Device channel additions). Where the channel is missing
/// (tests) it reports an unmetered connection, ample storage and a supported
/// device, and the actions do nothing.
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

  /// Whether the processor is 64-bit (always on iOS 15) and the device's total memory.
  Future<({bool arm64, int ramBytes})> deviceSupport() async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('deviceSupport');
      return (arm64: r?['arm64'] as bool? ?? true, ramBytes: r?['ramBytes'] as int? ?? 1 << 40);
    } on MissingPluginException {
      return (arm64: true, ramBytes: 1 << 40);
    } on PlatformException {
      return (arm64: true, ramBytes: 1 << 40);
    }
  }

  /// Browsers only: app data on phones is the app's own (specs/008 FR-014).
  Future<void> keepBrowserData() async {}

  /// Null on phones: browsers only (specs/008 research R10).
  Future<WebSupport?> webSupport() async => null;

  /// Opens the app's page in the system Settings, where the microphone can be allowed.
  Future<void> openAppSettings() => _invoke('openAppSettings');

  /// A short tone that the silent switch or ringer mode mutes (research R12).
  Future<void> playMistakeTone() => _invoke('playMistakeTone');

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Not available: nothing to do.
    } on PlatformException {
      // Best effort.
    }
  }
}
