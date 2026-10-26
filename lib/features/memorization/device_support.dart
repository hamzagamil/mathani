// Whether this phone can run memorization (specs/006 research R15, FR-028).
import '../../platform/device.dart';
import '../../platform/speech_host.dart' show speechEngineAvailable;

/// "At least 3 GB" as sold: a phone sold with 3 GB reports about 2.7–2.9 GiB of total memory, so
/// the gate is 2.5 GiB. Confirmed or raised from the slowest phone that passes spike S1 (T035).
const minRamBytes = 5 * 1024 * 1024 * 1024 ~/ 2;

/// In browsers that report their memory (Chromium), at least this many GB (specs/008 research
/// R10). Browsers report it rounded down to 0.25, 0.5, 1, 2, 4 or 8. Confirmed by spike S2.
const webMinDeviceMemoryGb = 4;

/// Why memorization is unavailable, for the message.
enum Unsupported { not64Bit, lowMemory, browser }

/// Null when memorization can run on this device, or in this browser.
Future<Unsupported?> memorizationSupport(DeviceChannel device) async {
  final web = await device.webSupport();
  if (web != null) {
    if (!speechEngineAvailable) return Unsupported.browser;
    if (!web.wasmSimd || !web.audioWorklet || !web.opfs) return Unsupported.browser;
    final gb = web.deviceMemoryGb;
    return gb != null && gb < webMinDeviceMemoryGb ? Unsupported.lowMemory : null;
  }
  final s = await device.deviceSupport();
  if (!s.arm64) return Unsupported.not64Bit;
  if (s.ramBytes < minRamBytes) return Unsupported.lowMemory;
  return null;
}
