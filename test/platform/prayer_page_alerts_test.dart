import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';
import 'package:mathani/platform/prayer_notifications_page.dart';

class _Port implements PrayerPagePort {
  @override
  bool active = true;
  @override
  bool notificationsSupported = true;
  @override
  String notificationPermission = 'default';
  final shown = <Alert>[];
  int requests = 0;
  final activity = StreamController<bool>.broadcast();
  @override
  Stream<bool> get activityChanges => activity.stream;
  @override
  Future<void> requestNotificationPermission() async {
    requests++;
    notificationPermission = 'granted';
  }

  @override
  void showNotification(Alert alert) => shown.add(alert);
}

void main() {
  final start = DateTime.utc(2026, 3, 15, 12);
  Alert alert(int id, int minutes) => Alert(
    id: id,
    kind: PrayerKind.dhuhr,
    atUtc: start.add(Duration(minutes: minutes)),
    title: 'Dhuhr',
    body: '12:05 PM · Cairo',
    sound: toneSound,
    generation: 1,
  );

  late _Port port;
  late DateTime now;
  late PageAlerts page;
  late List<Alert> due;
  setUp(() {
    port = _Port();
    now = start;
    due = [];
    page = PageAlerts(port: port, clock: () => now)..onDue = due.add;
  });
  tearDown(() => page.dispose());

  test('status never prompts; permission is asked only on request', () async {
    expect(
      (await page.status()).notifications,
      NotificationPermission.notDetermined,
    );
    expect(port.requests, 0);
    expect(
      (await page.requestPermission()).notifications,
      NotificationPermission.granted,
    );
  });

  test(
    'a due alert plays once, with a silent notification when allowed',
    () async {
      port.notificationPermission = 'granted';
      expect(await page.replace([alert(1, 1), alert(2, 60)], 1), 2);
      now = start.add(const Duration(minutes: 1, seconds: 5));
      await page.checkDue();
      await page.checkDue();
      expect(due.map((a) => a.id), [1]);
      expect(port.shown.map((a) => a.id), [1]);
    },
  );

  test(
    'without notification permission the in-page sound still plays',
    () async {
      port.notificationPermission = 'denied';
      await page.replace([alert(1, 1)], 1);
      now = start.add(const Duration(minutes: 2));
      await page.checkDue();
      expect(due, hasLength(1));
      expect(port.shown, isEmpty);
    },
  );

  test('missed while the page was hidden: dropped, not replayed', () async {
    await page.replace([alert(1, 1)], 1);
    port.active = false;
    now = start.add(const Duration(minutes: 2));
    await page.checkDue();
    port.active = true;
    await page.checkDue();
    expect(due, isEmpty);
  });

  test('more than 15 minutes late is missed', () async {
    await page.replace([alert(1, 1)], 1);
    now = start.add(const Duration(minutes: 17));
    await page.checkDue();
    expect(due, isEmpty);
  });

  test('replace and cancel drop old alerts', () async {
    await page.replace([alert(1, 1)], 1);
    await page.replace([alert(2, 2)], 2);
    now = start.add(const Duration(minutes: 3));
    await page.checkDue();
    expect(due.map((a) => a.id), [2]);
    await page.replace([alert(3, 5)], 3);
    await page.cancelAll();
    now = start.add(const Duration(minutes: 6));
    await page.checkDue();
    expect(due.map((a) => a.id), [2]);
  });
}
