@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';
import 'package:mathani/platform/prayer_notifications.dart';

class SilentAudio implements PrayerAudio {
  @override
  Future<void> play(ScheduledReminder reminder) async {}
  @override
  Future<void> preview(AthanRecording recording) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  test('real browser binding queries support without prompting or claiming background alarms', () async {
    final adapter = prayerNotifications(
      audio: SilentAudio(),
      playFromUser: (_) async {},
      notificationTitle: 'Mathani',
      notificationBody: (_) => 'Prayer reminder',
      onDelivery: (_) {},
    ) as PrayerPageNotifications;
    final capability = await adapter.capabilities();
    expect(capability.permissionStatus, 'notRequired');
    expect(capability.backgroundModes, isEmpty);
    expect(capability.exactAlarmAccess, false);
    expect(capability.scheduledThroughUtc, isNull);
    expect(
      adapter.notificationPermission,
      anyOf('default', 'granted', 'denied', 'unsupported'),
    );
    await adapter.dispose();
  });
}
