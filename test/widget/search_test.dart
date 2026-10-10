// US6 search (quickstart scenario 12).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/search/search_index.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  late ReaderController reader;
  final key = GlobalKey();

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('search without diacritics, count, highlight, open; no-results message',
      (tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });

    // Search speed on the full corpus (SC-006 budget is 1 s on the reference phone).
    final index = (await tester.runAsync(() => SearchIndex.load(reader.quran)))!;
    final watch = Stopwatch()..start();
    final direct = index.search('الرحمن الرحيم');
    watch.stop();
    expect(direct.hits, isNotEmpty);
    expect(direct.hits.first.ayah.ref, const AyahRef(1, 1));
    expect(watch.elapsedMilliseconds, lessThan(300));

    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar));
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(key: key, child: MathaniApp(controller: reader)));
    await settle(tester);

    await tester.tap(find.byIcon(MathaniIcons.search));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'الرحمن الرحيم');
    await settle(tester);
    expect(find.textContaining(RegExp('نتيجة|نتائج|نتيجتان')), findsWidgets); // result count
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screenshots').createSync(recursive: true);
      File('build/screenshots/search_ar.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.tap(find.textContaining('سورة الفاتحة').first);
    await settle(tester);
    expect(reader.anchor, const AyahRef(1, 1));

    await tester.tap(find.byIcon(MathaniIcons.search));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'زززز');
    await settle(tester);
    expect(find.text('لا توجد نتائج.'), findsOneWidget);
  });
}
