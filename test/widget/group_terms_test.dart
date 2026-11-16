// Safety on the device (specs/014 Story 6): terms first, reporting hides at once, organiser
// tools only for the organiser, refused names keep the text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/features/khatma/group/group_controller.dart';
import 'package:mathani/features/khatma/group/group_screen.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/features/reader/reader_screen.dart';
import 'package:mathani/shared/mathani_icons.dart';
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

  Future<void> open(WidgetTester tester, {bool terms = false}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    khatma = await openTestKhatma(tester, reader);
    server = FakeGroupServer();
    code = server.seed(title: 'Family');
    server.takeAs(code, 1, 'k-rude', 'Rude Name');
    groups = await openTestGroups(tester, khatma, server, termsAccepted: terms);
    setPhone(tester);
    await tester.pumpWidget(MathaniApp(controller: reader, khatma: khatma, groups: groups));
    await settleKhatma(tester);
    Navigator.of(tester.element(find.byType(ReaderScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => GroupScreen(code: code)));
    await settleKhatma(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    groups.dispose();
    khatma.dispose();
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('the terms come before the first take; Cancel saves nothing', (tester) async {
    await open(tester);
    await tester.tap(find.text('Take this part').first);
    await settleKhatma(tester);
    expect(find.text('Before you take part'), findsOneWidget);
    expect(find.textContaining('support@mthani.app'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settleKhatma(tester);
    expect(groups.termsAccepted, isFalse);
    await tester.tap(find.text('Take this part').first);
    await settleKhatma(tester);
    await tester.tap(find.text('I agree'));
    await settleKhatma(tester);
    expect(groups.termsAccepted, isTrue);
    expect(find.text('Your name will be seen by everyone who has the link.'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a name with a link keeps the text and says why', (tester) async {
    await open(tester, terms: true);
    await tester.tap(find.text('Take this part').first);
    await settleKhatma(tester);
    await tester.enterText(find.byType(TextField), 'www.spam.com');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Take this part')));
    await settleKhatma(tester);
    expect(find.text('Links and addresses are not allowed.'), findsOneWidget);
    expect(find.text('www.spam.com'), findsOneWidget);
    await close(tester);
  });

  testWidgets('report a name: hidden here at once, Report sent', (tester) async {
    await open(tester, terms: true);
    await tester.tap(find.byTooltip('Report'));
    await settleKhatma(tester);
    await tester.tap(find.text('Report a name'));
    await settleKhatma(tester);
    await tester.tap(find.text('Rude Name'));
    await settleKhatma(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Report'));
    await settleKhatma(tester);
    expect(find.text('Report sent.'), findsOneWidget);
    expect(find.textContaining('Rude Name'), findsNothing);
    expect(find.textContaining('hidden'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a reader who is not the organiser has no organiser menu', (tester) async {
    await open(tester, terms: true);
    expect(find.byIcon(MathaniIcons.more), findsNothing);
    await tester.tap(find.byTooltip('Report'));
    await settleKhatma(tester);
    expect(find.text('Delete the khatma'), findsNothing);
    expect(find.text('Edit the title or the finish date'), findsNothing);
    await close(tester);
  });
}
