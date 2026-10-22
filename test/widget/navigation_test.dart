// US2 navigation (quickstart scenario 5): index tabs, go-to validation, ≤3 taps to targets.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  late ReaderController reader;
  final key = GlobalKey();

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> shoot(WidgetTester tester, String name) => tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/screenshots').createSync(recursive: true);
        File('build/screenshots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });

  Future<void> pumpApp(WidgetTester tester, {LanguagePref language = LanguagePref.ar}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: language));
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(key: key, child: MathaniApp(controller: reader)));
    await settle(tester);
  }

  testWidgets('surah in 2 taps: index → Al-Kahf', (tester) async {
    await pumpApp(tester);
    await tapToolbar(tester, MathaniIcons.index);
    await settle(tester);
    await shoot(tester, 'index_surahs_ar');
    await tester.scrollUntilVisible(find.textContaining('الكهف'), 500);
    await tester.tap(find.textContaining('الكهف'));
    await settle(tester);
    expect(reader.pageHead.surah, 18);
    expect(reader.page, reader.quran.surahList[17].startPage);
  });

  testWidgets('juz and quarter in 3 taps: index → Ajza\' → row', (tester) async {
    await pumpApp(tester);
    await tapToolbar(tester, MathaniIcons.index);
    await settle(tester);
    await tester.tap(find.text('الأجزاء'));
    await settle(tester);
    await shoot(tester, 'index_ajza_ar');
    await tester.tap(find.textContaining('ربع الحزب ١ ·'));
    await settle(tester);
    final q2 = reader.quran.divisionList.firstWhere(
        (d) => d.kind == DivisionKind.hizbQuarter && d.number == 2);
    expect(reader.anchor, q2.start);
  });

  testWidgets('go-to rejects page 605 and 2:300, accepts page 300 and 2:255', (tester) async {
    await pumpApp(tester);
    await tapToolbar(tester, MathaniIcons.index);
    await settle(tester);
    await tester.tap(find.byIcon(MathaniIcons.goTo));
    await settle(tester);

    await tester.enterText(find.byType(TextField), '605');
    await tester.tap(find.text('انتقل'));
    await settle(tester);
    expect(find.text('اكتب رقم صفحة من ١ إلى ٦٠٤.'), findsOneWidget);
    await shoot(tester, 'goto_error_ar');

    await tester.enterText(find.byType(TextField), '٣٠٠'); // Eastern Arabic digits accepted
    await tester.tap(find.text('انتقل'));
    await settle(tester);
    expect(reader.page, 300);

    // The surah field defaults to the current surah; start from Al-Baqarah.
    reader.jumpTo(const AyahRef(2, 1), highlight: false);
    await settle(tester);
    await tapToolbar(tester, MathaniIcons.index);
    await settle(tester);
    await tester.tap(find.byIcon(MathaniIcons.goTo));
    await settle(tester);
    await tester.tap(find.text('سورة وآية'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '300');
    await tester.tap(find.text('انتقل'));
    await settle(tester);
    expect(find.text('اكتب رقم آية من ١ إلى ٢٨٦.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '255');
    await tester.tap(find.text('انتقل'));
    await settle(tester);
    expect(reader.anchor, const AyahRef(2, 255));
  });
}
