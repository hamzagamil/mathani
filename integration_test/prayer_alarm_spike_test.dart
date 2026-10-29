// G01 opt-in Android diagnostic; never evidence of locked/Doze/cold-process
// success until run on those real targets and recorded in android-headless.md.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathani/features/recitation/media_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (prayerAlarmSpikeEnabled &&
      WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
          prayerAlarmSpikeRoute) {
    await RecitationMediaHandler.initializePrayerAlarmSpike();
    return;
  }
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.mathani/prayer_alarm_spike');
  testWidgets(
    'G01 foreground exact alarm reaches the single handler and Stop consumes its token',
    (tester) async {
      if (defaultTargetPlatform != TargetPlatform.android ||
          !prayerAlarmSpikeEnabled) {
        markTestSkipped(
          'Android debug target and --dart-define=PRAYER_ALARM_SPIKE=true required',
        );
        return;
      }
      await RecitationMediaHandler.initializePrayerAlarmSpike();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Prayer audio startup diagnostic')),
          ),
        ),
      );
      final capabilities = await channel.invokeMapMethod<String, dynamic>(
        'capabilities',
      );
      if (capabilities?['exactAlarmAccess'] != true ||
          capabilities?['notificationsGranted'] != true) {
        markTestSkipped(
          'Grant Alarms & reminders and Notifications manually, then rerun',
        );
        return;
      }
      final event = await channel.invokeMapMethod<String, dynamic>('schedule', {
        'delayMs': 5000,
      });
      expect(event, isNotNull);
      Map<String, dynamic>? observed;
      final deadline = DateTime.now().add(const Duration(seconds: 18));
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        observed = await channel.invokeMapMethod<String, dynamic>(
          'inspect',
          event,
        );
        if (observed?['consumed'] == true) break;
      }
      expect(
        observed?['owner'],
        'appAudio',
        reason: 'A fallback is not proof of successful app-audio startup',
      );
      expect(observed?['state'], 'playing');
      expect(
        (observed!['startedAtMs'] as num) - (event!['dueAtMs'] as num),
        inInclusiveRange(0, 60000),
      );
      final engine = observed['engineId'];
      final stopped = await channel.invokeMapMethod<String, dynamic>(
        'stop',
        event,
      );
      expect(stopped?['audioStopped'], true);
      final handlerState = await channel.invokeMapMethod<String, dynamic>(
        'inspect',
        event,
      );
      expect(handlerState?['state'], 'cancelled');
      expect(handlerState?['engineId'], engine);
      // Stop is acknowledged by the player as well as the native ledger.
    },
  );
}
