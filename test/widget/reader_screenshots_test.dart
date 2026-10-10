// Renders the reader on a 360×780 phone to build/screenshots/ for visual review, and checks
// the basic US1 behaviour (FR-004, FR-006, FR-008).
//   flutter test test/widget/reader_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  late ReaderController reader;

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screenshots').createSync(recursive: true);
      File('build/screenshots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<GlobalKey> pumpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: MathaniApp(controller: reader)));
    // Page data loads asynchronously from SQLite.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    return key;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('reader opens on Al-Fatiha and renders pages', (tester) async {
    final key = await pumpApp(tester);
    expect(reader.page, 1);
    expect(find.textContaining('الفاتحة'), findsOneWidget);
    await shoot(tester, key, 'p001_light_en');

    reader.jumpTo(const AyahRef(2, 255));
    await settle(tester);
    expect(reader.page, reader.quran.pageOf(const AyahRef(2, 255)));
    await shoot(tester, key, 'p042_ayat_alkursi_highlight');

    reader.jumpTo(const AyahRef(9, 1), highlight: false);
    await settle(tester);
    await shoot(tester, key, 'p187_tawbah');

    reader.updatePreferences(reader.preferences.copyWith(theme: ThemePref.night));
    reader.jumpTo(const AyahRef(114, 1), highlight: false);
    await settle(tester);
    await shoot(tester, key, 'p604_night');
  });

  testWidgets('swiping from left to right moves to the next page (FR-004)', (tester) async {
    await pumpApp(tester);
    reader.jumpTo(const AyahRef(1, 1), highlight: false);
    await settle(tester);
    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await settle(tester);
    expect(reader.page, 2);
  });
}
