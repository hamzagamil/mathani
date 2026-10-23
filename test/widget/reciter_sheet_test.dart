// The reciter sheet (specs/004 contracts/recitation-ui.md › Reciter sheet) and Settings ›
// Recitations › Reciter.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/features/recitation/reciter_sheet.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

void main() {
  late ReaderController reader;
  late RecitationController recitation;

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> pumpApp(WidgetTester tester, LanguagePref language) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: language));
    (recitation, _, _) = openTestRecitation(reader);
    tester.view.physicalSize = const Size(780, 1690);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MathaniApp(controller: reader, recitation: recitation));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await recitation.stop();
    await tester.pumpWidget(const SizedBox());
    recitation.dispose();
    await tester.runAsync(() async {
      reader.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> openSheet(WidgetTester tester, {DownloadedSurah? downloaded}) async {
    final context = tester.element(find.byType(Scaffold).first);
    showReciterSheet(context, downloaded: downloaded);
    await settle(tester, 3);
  }

  testWidgets('Arabic: both reciters in order, Murattal, a check on the current one; picking '
      'one saves it', (tester) async {
    await pumpApp(tester, LanguagePref.ar);
    await openSheet(tester);
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect([for (final t in tiles) (t.title! as Text).data],
        ['محمود خليل الحصري', 'محمد صديق المنشاوي']);
    expect(find.text('مرتّل'), findsNWidgets(2));
    expect(find.byIcon(MathaniIcons.check), findsOneWidget);
    expect(tiles.first.selected, isTrue);

    await tester.tap(find.text('محمد صديق المنشاوي'));
    await settle(tester);
    expect(find.byType(ListTile), findsNothing, reason: 'the sheet closes');
    expect(reader.preferences.reciter, 'minshawy');
    await finish(tester);
  });

  testWidgets('English: English names, with the Arabic name always shown', (tester) async {
    await pumpApp(tester, LanguagePref.en);
    await openSheet(tester);
    expect(find.text('Mahmoud Khalil Al-Husary'), findsOneWidget);
    expect(find.text('محمود خليل الحصري · Murattal'), findsOneWidget);
    expect(find.text('Mohamed Siddiq El-Minshawi'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a reciter whose current surah is downloaded is marked', (tester) async {
    await pumpApp(tester, LanguagePref.ar);
    await openSheet(tester, downloaded: (r, s) => r == 'minshawy');
    expect(find.byIcon(MathaniIcons.downloaded), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Settings › Recitations › Reciter shows the reciter and opens the sheet',
      (tester) async {
    await pumpApp(tester, LanguagePref.ar);
    await tapToolbar(tester, MathaniIcons.settings);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('القارئ'), 200);
    expect(find.text('التلاوات'), findsOneWidget);
    expect(find.text('محمود خليل الحصري'), findsOneWidget);
    await tester.tap(find.text('القارئ'));
    await settle(tester);
    expect(find.text('اختر القارئ'), findsOneWidget);
    await finish(tester);
  });
}
