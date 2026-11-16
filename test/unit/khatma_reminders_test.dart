// What the daily reminder schedules (specs/014 contracts/khatma-ui-and-reminders.md › The
// reminder, N1 to N11; research R8).
import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/features/khatma/khatma_models.dart';
import 'package:mathani/features/khatma/khatma_reminder_platform.dart';
import 'package:mathani/features/khatma/khatma_reminders.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';
import '../support/khatma_support.dart';

class FakeReminders implements KhatmaReminderPlatform {
  ReminderPermission permission = ReminderPermission.granted;
  bool? exact;
  List<KhatmaReminder> pending = const [];
  int replaces = 0;
  final cleared = <int>[];
  final taps = StreamController<void>.broadcast();

  @override
  Future<ReminderStatus> status() async => ReminderStatus(permission, exactAlarms: exact);
  @override
  Future<ReminderStatus> requestPermission() async {
    if (permission == ReminderPermission.notDetermined) permission = ReminderPermission.granted;
    return status();
  }

  @override
  Future<void> openSettings() async {}
  @override
  Future<int> replace(List<KhatmaReminder> reminders) async {
    replaces++;
    pending = List.of(reminders);
    return pending.length;
  }

  @override
  Future<void> clearDelivered(List<int> ids) async => cleared.addAll(ids);
  @override
  Stream<void> get opened => taps.stream;
  @override
  Future<bool> takeLaunchOpen() async => false;
}

void main() {
  late ReaderController reader;
  late KhatmaController khatma;
  late KhatmaReminders reminders;
  late FakeReminders platform;
  late DateTime now;

  Future<void> open(WidgetTester tester,
      {String at = '2026-03-01 04:00', KhatmaPlan? start = const MarksPlan(8)}) async {
    now = DateTime.parse(at);
    reader = (await tester.runAsync(openTestReader))!;
    khatma = await openTestKhatma(tester, reader, now: () => now, start: start);
    platform = FakeReminders();
    reminders = KhatmaReminders(
      khatma: khatma,
      platform: platform,
      l10n: () => lookupAppLocalizations(const Locale('en')),
      clock: () => now,
    );
    await tester.runAsync(() => khatma.setReminder(const ReminderSetting(on: true, hour: 5, minute: 30)));
  }

  Future<void> sync(WidgetTester tester) => tester.runAsync(reminders.sync).then((_) {});

  Future<void> close(WidgetTester tester) async {
    reminders.dispose();
    khatma.dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  List<String> days() => [
        for (final r in platform.pending) CalendarDay.of(r.atUtc.toLocal()).toString(),
      ];

  testWidgets('N1: ten reminders, today and the nine days after, at 05:30', (tester) async {
    await open(tester);
    await sync(tester);
    expect(platform.pending, hasLength(10));
    expect(days().first, '2026-03-01');
    expect(days().last, '2026-03-10');
    for (final r in platform.pending) {
      final local = r.atUtc.toLocal();
      expect((local.hour, local.minute), (5, 30));
    }
    expect(platform.pending.first.title, "Today's wird");
    expect(platform.pending.first.body, 'Juz 1 · Pages 1 to 21');
    expect(platform.pending[2].body, 'Juz 3 · Pages 42 to 62');
    // One id per day, so a rebuild never doubles one.
    expect(platform.pending.map((r) => r.id).toSet(), hasLength(10));
    await close(tester);
  });

  testWidgets('N2: after the time, the first is tomorrow', (tester) async {
    await open(tester, at: '2026-03-01 06:00');
    await sync(tester);
    expect(days().first, '2026-03-02');
    expect(platform.pending.length, inInclusiveRange(9, 10));
    await close(tester);
  });

  testWidgets('N3 and N4: today read removes today; Undo puts it back', (tester) async {
    await open(tester);
    await sync(tester);
    await tester.runAsync(khatma.markRead);
    await sync(tester);
    expect(days().first, '2026-03-02');
    expect(platform.pending.first.body, 'Juz 2 · Pages 22 to 41');
    expect(platform.cleared, contains(KhatmaReminders.idFor(CalendarDay.parse('2026-03-01'))));
    await tester.runAsync(khatma.undo);
    await sync(tester);
    expect(days().first, '2026-03-01');
    await close(tester);
  });

  testWidgets('N5: withheld while a page of the current wird is on screen', (tester) async {
    await open(tester);
    reader.jumpToPage(10);
    await tester.pump();
    await sync(tester);
    expect(days().first, '2026-03-02');
    reader.jumpToPage(300);
    await tester.pump();
    await sync(tester);
    expect(days().first, '2026-03-01');
    await close(tester);
  });

  testWidgets('N6: paused, ended or no khatma: none', (tester) async {
    await open(tester);
    await tester.runAsync(khatma.pause);
    await sync(tester);
    expect(platform.pending, isEmpty);
    await tester.runAsync(khatma.resume);
    await sync(tester);
    expect(platform.pending, hasLength(10));
    await tester.runAsync(khatma.end);
    await sync(tester);
    expect(platform.pending, isEmpty);
    await close(tester);
  });

  testWidgets('N7: a start date in three days', (tester) async {
    await open(tester, start: null);
    await tester.runAsync(() => khatma.start(const MarksPlan(8),
        startAyah: 1, startDate: CalendarDay.parse('2026-03-04')));
    await sync(tester);
    expect(days().first, '2026-03-04');
    expect(platform.pending.first.body, startsWith('Juz 1 ·'));
    await close(tester);
  });

  testWidgets('N8: no khatma, an unread group part: ten, naming it', (tester) async {
    await open(tester, start: null);
    reminders.heldParts = () => const [HeldPartReminder(title: 'Family', partName: 'Juz 7')];
    await sync(tester);
    expect(platform.pending, hasLength(10));
    expect(platform.pending.first.body, 'Your part in «Family»: Juz 7');
    await close(tester);
  });

  testWidgets('N9: notifications refused: none, the setting kept', (tester) async {
    await open(tester);
    platform.permission = ReminderPermission.denied;
    await sync(tester);
    expect(platform.pending, isEmpty);
    expect(khatma.reminder.on, isTrue);
    expect(reminders.status?.permission, ReminderPermission.denied);
    await close(tester);
  });

  testWidgets('N10: a new time replaces them all', (tester) async {
    await open(tester);
    await sync(tester);
    await tester.runAsync(() => reminders.setTime(21, 0));
    for (final r in platform.pending) {
      expect(r.atUtc.toLocal().hour, 21);
    }
    expect(platform.pending, hasLength(10));
    await close(tester);
  });

  testWidgets('turning on asks for permission at that moment (FR-020)', (tester) async {
    await open(tester);
    await tester.runAsync(() => khatma.setReminder(ReminderSetting.off));
    platform.permission = ReminderPermission.notDetermined;
    await sync(tester);
    expect(platform.pending, isEmpty);
    await tester.runAsync(() => reminders.turnOn());
    expect(platform.permission, ReminderPermission.granted);
    expect(platform.pending, hasLength(10));
    await close(tester);
  });

  testWidgets('calls made while one runs are merged, and nothing unchanged is sent again',
      (tester) async {
    await open(tester);
    await tester.runAsync(() => Future.wait([reminders.sync(), reminders.sync(), reminders.sync()]));
    expect(platform.replaces, lessThanOrEqualTo(2));
    final before = platform.replaces;
    await sync(tester);
    expect(platform.replaces, before);
    await close(tester);
  });
}
