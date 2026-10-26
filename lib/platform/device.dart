// Device facts on every platform (specs/008 contracts/web-platform.md › DeviceFacts): the
// platform channel on phones, browser APIs on the web. Both define `DeviceChannel` with the same
// members.
export 'device_io.dart' if (dart.library.js_interop) 'device_web.dart';

/// Whether the device is online, and whether its connection is metered
/// (specs/004-ayah-recitations/contracts/audio-storage.md › Platform channel).
enum NetworkState { none, unmetered, metered }

/// What a browser offers memorization (specs/008 research R10). [deviceMemoryGb] is null where
/// the browser does not report it (all but Chromium).
typedef WebSupport = ({bool wasmSimd, bool audioWorklet, bool opfs, int? deviceMemoryGb});
