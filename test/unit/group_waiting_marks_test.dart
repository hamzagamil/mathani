// Group khatma state on the device (specs/014 FR-053 to FR-055, research R18): the kept copy,
// marks made offline and sent later, a refused mark, and the parts given to the reader as readings.
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/features/khatma/group/group_client.dart';
import 'package:mathani/features/khatma/group/group_controller.dart';
import 'package:mathani/features/khatma/group/group_key.dart';
import 'package:mathani/features/khatma/group/group_models.dart';
import 'package:mathani/features/khatma/group/group_repository.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_group_server.dart';
import '../support/harness.dart';
import '../support/khatma_support.dart';

void main() {
  late ReaderController reader;
  late KhatmaController khatma;
  late GroupController groups;
  late FakeGroupServer server;
  late String code;

  Future<void> open(WidgetTester tester) async {
    reader = (await tester.runAsync(openTestReader))!;
    khatma = await openTestKhatma(tester, reader);
    server = FakeGroupServer();
    code = server.seed();
    groups = GroupController(
      client: GroupClient(base: Uri.parse('https://get.mthani.app'), keys: MemoryKeyStore(), client: server.client),
      repository: GroupRepository(reader.user),
      khatma: khatma,
    );
    await tester.runAsync(groups.load);
  }

  Future<void> close(WidgetTester tester) async {
    groups.dispose();
    khatma.dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<T?> run<T>(WidgetTester tester, Future<T> Function() f) => tester.runAsync(f);

  testWidgets('no request at all before a group khatma is opened (SC-012)', (tester) async {
    await open(tester);
    expect(server.requests, 0);
    expect(groups.groupReadings, isEmpty);
    await close(tester);
  });

  testWidgets('take: the part becomes a reading with its own place (FR-052)', (tester) async {
    await open(tester);
    await run(tester, () => groups.open(code));
    await run(tester, () => groups.take(code, 7, name: 'Maryam'));
    expect(groups.lastName, 'Maryam');
    final reading = groups.groupReadings.single;
    expect(reading.partNumber, 7);
    expect((reading.firstPage, reading.lastPage), (121, 141));
    expect(reading.title, 'Family');
    expect(khatma.readings.single.key, reading.key);
    expect(khatma.endMarksOn(141), isNotEmpty);
    await close(tester);
  });

  testWidgets('Done offline: read here at once, waiting, sent when back (FR-053, SC-017)', (tester) async {
    await open(tester);
    await run(tester, () => groups.open(code));
    await run(tester, () => groups.take(code, 7, name: 'Maryam'));
    server.offline = true;
    await run(tester, () => groups.markRead(code, 7));
    expect(groups.isPending(code, 7), isTrue);
    expect(groups.shown(code).parts[6].state, PartState.read);
    expect(groups.groupReadings, isEmpty, reason: 'a read part is no longer a reading');
    expect(server.khatmas[code]!.readAt[7], isNull);
    server.offline = false;
    await run(tester, groups.sendWaiting);
    expect(groups.isPending(code, 7), isFalse);
    expect(server.khatmas[code]!.readAt[7], isNotNull);
    // Sending twice is harmless.
    await run(tester, groups.sendWaiting);
    await close(tester);
  });

  testWidgets('a waiting mark for a part freed meanwhile is dropped, and the reader told', (tester) async {
    await open(tester);
    await run(tester, () => groups.open(code));
    await run(tester, () => groups.take(code, 7, name: 'Maryam'));
    server.offline = true;
    await run(tester, () => groups.markRead(code, 7));
    server.khatmas[code]!.holder[7] = null; // the organiser freed it
    server.offline = false;
    await run(tester, groups.sendWaiting);
    expect(groups.isPending(code, 7), isFalse);
    expect(groups.lostPart(code), isTrue);
    expect(groups.shown(code).parts[6].state, PartState.free);
    await close(tester);
  });

  testWidgets('offline: the kept copy opens at once (FR-055); taking needs a connection', (tester) async {
    await open(tester);
    await run(tester, () => groups.open(code));
    server.offline = true;
    final s = await run(tester, () => groups.open(code));
    expect(s!.title, 'Family');
    Object? error;
    await run(tester, () async {
      try {
        await groups.take(code, 8, name: 'X');
      } catch (e) {
        error = e;
      }
    });
    expect(error, isA<GroupFailure>().having((f) => f.kind, 'kind', GroupFailureKind.offline));
    await close(tester);
  });

  testWidgets('just taken by someone else: the list is fresh', (tester) async {
    await open(tester);
    await run(tester, () => groups.open(code));
    server.takeAs(code, 9, 'other', 'Yusuf');
    Object? error;
    await run(tester, () async {
      try {
        await groups.take(code, 9, name: 'Maryam');
      } catch (e) {
        error = e;
      }
    });
    expect(error, isA<GroupFailure>().having((f) => f.kind, 'kind', GroupFailureKind.taken));
    expect(groups.keptOf(code)!.snapshot.parts[8].state, PartState.taken);
    await close(tester);
  });

  testWidgets('kept across restarts, and gone when the server says so', (tester) async {
    await open(tester);
    await run(tester, () => groups.open(code));
    final again = GroupController(
      client: GroupClient(base: Uri.parse('https://get.mthani.app'), keys: MemoryKeyStore(), client: server.client),
      repository: GroupRepository(reader.user),
      khatma: khatma,
    );
    await run(tester, again.load);
    expect(again.kept.single.code, code);
    server.khatmas.remove(code);
    await run(tester, () => again.refresh(code).catchError((_) {}));
    expect(again.isGone(code), isTrue);
    await run(tester, () => again.forget(code));
    expect(again.kept, isEmpty);
    again.dispose();
    await close(tester);
  });
}
