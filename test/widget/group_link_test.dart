// Opening a group khatma from a link (specs/014 FR-046, contracts/group-ui.md › Opening a link).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/khatma/group/group_controller.dart';
import 'package:mathani/features/khatma/group/group_link_host.dart';
import 'package:mathani/features/khatma/group/group_screen.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/features/khatma/khatma_screen.dart';
import 'package:mathani/shared/reader_state.dart';
import 'package:mathani/app/theme/app_theme.dart';

import '../support/fake_group_server.dart';
import '../support/harness.dart';
import '../support/khatma_support.dart';

class FakeLinks implements LinkSource {
  FakeLinks([this.first]);
  String? first;
  final controller = StreamController<String>.broadcast();
  @override
  Future<String?> takeLink() async {
    final f = first;
    first = null;
    return f;
  }

  @override
  Stream<String> get links => controller.stream;
}

void main() {
  late ReaderController reader;
  late KhatmaController khatma;
  late GroupController groups;
  late FakeGroupServer server;
  late String code;

  Future<void> open(WidgetTester tester, FakeLinks links) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    khatma = await openTestKhatma(tester, reader);
    server = FakeGroupServer();
    code = server.seed(title: 'Family');
    groups = await openTestGroups(tester, khatma, server);
    setPhone(tester);
    await tester.pumpWidget(ReaderScope(
      controller: reader,
      child: KhatmaScope(
        controller: khatma,
        child: GroupScope(
          controller: groups,
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: GroupLinkHost(source: links, child: const Scaffold(body: Text('reader'))),
          ),
        ),
      ),
    ));
    await settleKhatma(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    groups.dispose();
    khatma.dispose();
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('the link the app was opened with opens the khatma over the Khatma screen', (tester) async {
    final links = FakeLinks();
    links.first = 'https://get.mthani.app/k/PLACEHOLDER';
    await open(tester, links);
    // The code is only known after the server seeded it: send it as a link while running.
    links.controller.add('https://get.mthani.app/k/$code');
    await settleKhatma(tester);
    expect(find.byType(GroupScreen), findsOneWidget);
    expect(find.text('Family'), findsWidgets);
    Navigator.of(tester.element(find.byType(GroupScreen))).pop();
    await settleKhatma(tester);
    expect(find.byType(KhatmaScreen), findsOneWidget);
    await close(tester);
  });

  testWidgets('a code with hyphens works too; anything else is ignored', (tester) async {
    final links = FakeLinks();
    await open(tester, links);
    links.controller.add('https://example.com/nothing');
    await settleKhatma(tester);
    expect(find.byType(GroupScreen), findsNothing);
    links.controller.add('${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8, 12)}-${code.substring(12)}');
    await settleKhatma(tester);
    expect(find.byType(GroupScreen), findsOneWidget);
    await close(tester);
  });
}
