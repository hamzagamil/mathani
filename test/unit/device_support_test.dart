import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/memorization/device_support.dart';
import 'package:mathani/shared/device_channel.dart';

/// The memorization device gate (specs/006 T039, research R15) and the channel's defaults.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.mathani/device');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  void answer(Map<String, Object?> support) => messenger.setMockMethodCallHandler(
      channel, (call) async => call.method == 'deviceSupport' ? support : null);

  test('64-bit with enough memory is supported', () async {
    answer({'arm64': true, 'ramBytes': 3 * 1024 * 1024 * 1024});
    expect(await memorizationSupport(const DeviceChannel()), isNull);
  });

  test('a phone sold with 3 GB (2.8 GiB reported) is supported; 2 GB is not', () async {
    answer({'arm64': true, 'ramBytes': 2800 * 1024 * 1024});
    expect(await memorizationSupport(const DeviceChannel()), isNull);
    answer({'arm64': true, 'ramBytes': 1900 * 1024 * 1024});
    expect(await memorizationSupport(const DeviceChannel()), Unsupported.lowMemory);
  });

  test('32-bit is not supported, whatever the memory', () async {
    answer({'arm64': false, 'ramBytes': 8 * 1024 * 1024 * 1024});
    expect(await memorizationSupport(const DeviceChannel()), Unsupported.not64Bit);
  });

  test('without the channel the device counts as supported and actions do nothing', () async {
    expect(await memorizationSupport(const DeviceChannel()), isNull);
    await const DeviceChannel().openAppSettings();
    await const DeviceChannel().playMistakeTone();
  });
}
