import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/khatma/group/group_client.dart';
import 'package:mathani/features/khatma/group/group_controller.dart';
import 'package:mathani/features/khatma/group/group_key.dart';
import 'package:mathani/features/khatma/group/group_repository.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/features/khatma/khatma_models.dart';
import 'package:mathani/features/khatma/khatma_repository.dart';
import 'package:mathani/shared/reader_state.dart';

import 'fake_group_server.dart';

/// A loaded khatma controller on [reader]'s database (specs/014), with the date fixed by [now].
Future<KhatmaController> openTestKhatma(
  WidgetTester tester,
  ReaderController reader, {
  DateTime Function()? now,
  bool Function()? isMemorizing,
  KhatmaPlan? start,
}) async {
  final clock = now ?? () => DateTime(2026, 3, 1, 9);
  final khatma = KhatmaController(
    repository: KhatmaRepository.of(reader.user),
    reader: reader,
    clock: clock,
    isMemorizing: isMemorizing,
    keepBrowserData: () async {},
  );
  await tester.runAsync(khatma.load);
  if (start != null) {
    await tester.runAsync(
        () => khatma.start(start, startAyah: 1, startDate: CalendarDay.of(clock())));
  }
  return khatma;
}

/// Lets database work and timers run, and frames be drawn.
Future<void> settleKhatma(WidgetTester tester, [int rounds = 4]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// A phone screen of [width] × [height] logical pixels, with system calls answered.
void setPhone(WidgetTester tester, {double width = 412, double height = 915}) {
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = Size(width * 2, height * 2);
  addTearDown(tester.view.reset);
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

/// A group controller on [khatma], talking to [server] (specs/014 release B).
Future<GroupController> openTestGroups(
  WidgetTester tester,
  KhatmaController khatma,
  FakeGroupServer server, {
  Duration pollEvery = const Duration(seconds: 20),
  bool termsAccepted = true,
}) async {
  final groups = GroupController(
    client: GroupClient(base: Uri.parse('https://get.mthani.app'), keys: MemoryKeyStore(), client: server.client),
    repository: GroupRepository(khatma.reader.user),
    khatma: khatma,
    pollEvery: pollEvery,
  );
  await tester.runAsync(groups.load);
  if (termsAccepted) await tester.runAsync(groups.acceptTerms);
  return groups;
}
