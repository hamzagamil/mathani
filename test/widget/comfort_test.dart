// US4 comfortable reading (quickstart scenarios 7–10).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/data/user_repository.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  late ReaderController reader;
  final key = GlobalKey();

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 200));
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

  testWidgets('layout toggle keeps the same ayah both ways (FR-003, SC-010)', (tester) async {
    await pumpApp(tester);
    const target = AyahRef(3, 92); // mid-page ayah, start of juz 4
    reader.jumpTo(target, highlight: false);
    await settle(tester);
    final mushafPage = reader.page;

    await tapToolbar(tester, MathaniIcons.flowing); // to flowing
    await settle(tester, 10);
    expect(reader.layout, ReadingLayout.flowing);
    expect(reader.page, mushafPage);
    expect(reader.anchor, target);
    await shoot(tester, 'flowing_24_ar');

    await tapToolbar(tester, MathaniIcons.mushaf); // back to Mushaf pages
    await settle(tester);
    expect(reader.layout, ReadingLayout.mushaf);
    expect(reader.page, mushafPage);
    expect(reader.anchor, target);

    // A second round trip must not drift.
    await tapToolbar(tester, MathaniIcons.flowing);
    await settle(tester, 10);
    expect(reader.anchor, target);
    await tapToolbar(tester, MathaniIcons.mushaf);
    await settle(tester);
    expect(reader.anchor, target);
  });

  testWidgets('flowing text size 18 and 34 (FR-017)', (tester) async {
    await pumpApp(tester);
    reader.updatePreferences(reader.preferences.copyWith(layout: ReadingLayout.flowing));
    reader.jumpTo(const AyahRef(2, 255), highlight: false);
    for (final size in [18, 34]) {
      reader.updatePreferences(reader.preferences.copyWith(flowFontSize: size));
      await settle(tester, 10);
      expect(reader.anchor, const AyahRef(2, 255), reason: 'size $size keeps the ayah');
      await shoot(tester, 'flowing_${size}_ar');
    }
  });

  testWidgets('settings persist and apply live; language switches immediately', (tester) async {
    await pumpApp(tester, language: LanguagePref.en);
    expect(find.textContaining('Al-Faatiha'), findsOneWidget);
    await tapToolbar(tester, MathaniIcons.settings);
    await settle(tester);
    await shoot(tester, 'settings_en');

    await tester.tap(find.text('Night'));
    await tester.tap(find.text('Keep screen on'));
    await settle(tester);
    await tester.tap(find.text('العربية'));
    await settle(tester);
    expect(find.text('الإعدادات'), findsOneWidget); // interface is Arabic now
    await shoot(tester, 'settings_ar_night');

    final reopened = await tester.runAsync(UserRepository.open);
    final (_, prefs) = (await tester.runAsync(reopened!.loadStartup))!;
    expect(prefs.theme, ThemePref.night);
    expect(prefs.keepScreenOn, isTrue);
    expect(prefs.language, LanguagePref.ar);
  });
}
