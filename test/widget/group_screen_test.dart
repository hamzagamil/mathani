// The group khatma screens (specs/014 Story 5, contracts/group-ui.md).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/features/khatma/group/group_controller.dart';
import 'package:mathani/features/khatma/group/group_screen.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/features/khatma/khatma_screen.dart';
import 'package:mathani/features/reader/reader_screen.dart';
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

  Future<void> open(WidgetTester tester, {bool terms = true}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    khatma = await openTestKhatma(tester, reader);
    server = FakeGroupServer();
    code = server.seed(title: 'Family');
    server.takeAs(code, 1, 'k-yusuf', 'Yusuf');
    groups = await openTestGroups(tester, khatma, server, termsAccepted: terms);
    setPhone(tester);
    await tester.pumpWidget(MathaniApp(controller: reader, khatma: khatma, groups: groups));
    await settleKhatma(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    groups.dispose();
    khatma.dispose();
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> openGroup(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(ReaderScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => GroupScreen(code: code)));
    await settleKhatma(tester);
  }

  testWidgets('the header, all parts with names, and Take with the name prompt', (tester) async {
    await open(tester);
    await openGroup(tester);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('29 free · 1 taken · 0 read'), findsOneWidget);
    expect(find.text('All parts'), findsOneWidget);
    expect(find.textContaining('Yusuf'), findsOneWidget);
    await tester.tap(find.text('Take this part').first);
    await settleKhatma(tester);
    expect(find.text('Your name will be seen by everyone who has the link.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Maryam');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Take this part')));
    await settleKhatma(tester);
    expect(server.khatmas[code]!.holder[2], isNotNull);
    expect(find.text('My parts'), findsOneWidget);
    expect(find.textContaining('(you)'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Done offline: read here, waiting to be sent; then sent', (tester) async {
    await open(tester);
    await openGroup(tester);
    await tester.runAsync(() => groups.take(code, 2, name: 'Maryam'));
    await settleKhatma(tester);
    server.offline = true;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Done'));
    await settleKhatma(tester);
    expect(find.text('Waiting to be sent'), findsOneWidget);
    server.offline = false;
    await tester.runAsync(groups.sendWaiting);
    await settleKhatma(tester);
    expect(find.text('Waiting to be sent'), findsNothing);
    expect(server.khatmas[code]!.readAt[2], isNotNull);
    await close(tester);
  });

  testWidgets('just taken by someone else, and the poll every 20 seconds', (tester) async {
    await open(tester);
    await openGroup(tester);
    server.takeAs(code, 2, 'k-other', 'Other');
    await tester.runAsync(() => groups.take(code, 2, name: 'Me').catchError((_) {}));
    await settleKhatma(tester);
    expect(find.textContaining('Other'), findsOneWidget, reason: 'the list is fresh');
    server.takeAs(code, 3, 'k-third', 'Third');
    final before = server.requests;
    await tester.pump(const Duration(seconds: 21));
    await settleKhatma(tester);
    expect(server.requests, greaterThan(before));
    expect(find.textContaining('Third'), findsOneWidget);
    await close(tester);
  });

  testWidgets('gone: the message and Remove from the list', (tester) async {
    await open(tester);
    await tester.runAsync(() => groups.open(code));
    server.khatmas.remove(code);
    await openGroup(tester);
    expect(find.text('This khatma no longer exists.'), findsOneWidget);
    await tester.tap(find.text('Remove from the list'));
    await settleKhatma(tester);
    expect(groups.kept, isEmpty);
    await close(tester);
  });

  testWidgets('the Khatma screen lists kept khatmas and the reader\'s parts', (tester) async {
    await open(tester);
    await tester.runAsync(() => groups.open(code));
    await tester.runAsync(() => groups.take(code, 7, name: 'Maryam'));
    Navigator.of(tester.element(find.byType(ReaderScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => const KhatmaScreen()));
    await settleKhatma(tester);
    await tester.scrollUntilVisible(find.text('Group khatmas'), 200);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('0 of 30 read'), findsOneWidget);
    expect(find.textContaining('Juz 7 · Pages 121 to 141'), findsOneWidget);
    expect(find.text('Start a group khatma'), findsOneWidget);
    expect(find.text('Open a link or code'), findsOneWidget);
    await close(tester);
  });
}
