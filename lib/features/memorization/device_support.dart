// Whether this phone can run memorization (specs/006 research R15, FR-028).
import '../../shared/device_channel.dart';

/// "At least 3 GB" as sold: a phone sold with 3 GB reports about 2.7–2.9 GiB of total memory, so
/// the gate is 2.5 GiB. Confirmed or raised from the slowest phone that passes spike S1 (T035).
const minRamBytes = 5 * 1024 * 1024 * 1024 ~/ 2;

/// Why memorization is unavailable, for the message.
enum Unsupported { not64Bit, lowMemory }

/// Null when memorization can run on this device.
Future<Unsupported?> memorizationSupport(DeviceChannel device) async {
  final s = await device.deviceSupport();
  if (!s.arm64) return Unsupported.not64Bit;
  if (s.ramBytes < minRamBytes) return Unsupported.lowMemory;
  return null;
}
