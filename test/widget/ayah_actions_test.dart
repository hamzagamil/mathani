// US5 (quickstart scenario 11): long-press an ayah in both layouts, copy it, bookmark it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/features/recitation/recited_item.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

void main() {
  late ReaderController reader;
  String? clipboard;

  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
  });

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar));
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MathaniApp(controller: reader));
    await settle(tester);
  }

  testWidgets('Mushaf: long-press selects the ayah under the finger; Copy uses the contract format',
      (tester) async {
    await pumpApp(tester);
    reader.jumpTo(const AyahRef(1, 1), highlight: false);
    await settle(tester);

    // Find a point on Al-Fatiha 1:2 via the renderer's own hit-testing.
    final box = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer).first);
    Offset? target;
    for (var y = 0.0; y < box.size.height && target == null; y += 6) {
      for (var x = box.size.width * 0.2; x < box.size.width * 0.8; x += 12) {
        if (box.ayahAt(Offset(x, y)) == const AyahRef(1, 2)) {
          target = box.localToGlobal(Offset(x, y));
          break;
        }
      }
    }
    expect(target, isNotNull);
    await tester.longPressAt(target!);
    await settle(tester);
    expect(reader.selected, const AyahRef(1, 2));

    await tester.tap(find.text('انسخ'));
    await settle(tester);
    final words = await tester.runAsync(() => reader.quran.wordsOf(const AyahRef(1, 2)));
    final text = [for (final w in words!) if (!w.isAyahEnd) w.text].join(' ');
    expect(clipboard, '﴿$text﴾\nسورة الفاتحة: ٢');
    expect(reader.selected, isNull); // selection clears when the sheet closes
  });

  testWidgets('Flowing: long-press opens actions; Bookmark saves the ayah', (tester) async {
    await pumpApp(tester);
    reader.updatePreferences(reader.preferences.copyWith(layout: ReadingLayout.flowing));
    reader.jumpTo(const AyahRef(1, 1), highlight: false);
    await settle(tester, 10);

    final quranParagraph = find.byWidgetPredicate(
        (w) => w is RichText && w.textAlign == TextAlign.justify); // the Quran text, not headers
    await tester.longPress(quranParagraph.first);
    await settle(tester);
    expect(find.text('احفظ'), findsOneWidget);
    await tester.tap(find.text('احفظ'));
    await settle(tester);
    expect(reader.user.bookmarks, hasLength(1));
  });

  testWidgets('Play from this ayah is the first action and starts the recitation there (specs/004)',
      (tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar));
    final (recitation, engine, _) = openTestRecitation(reader);
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MathaniApp(controller: reader, recitation: recitation));
    await settle(tester);
    reader.jumpTo(const AyahRef(1, 1), highlight: false);
    await settle(tester);

    final box = tester.renderObject<RenderMushafPage>(find.byType(MushafPageRenderer).first);
    Offset? target;
    for (var y = 0.0; y < box.size.height && target == null; y += 6) {
      for (var x = box.size.width * 0.2; x < box.size.width * 0.8; x += 12) {
        if (box.ayahAt(Offset(x, y)) == const AyahRef(1, 3)) {
          target = box.localToGlobal(Offset(x, y));
          break;
        }
      }
    }
    await tester.longPressAt(target!);
    await settle(tester);

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((tiles.first.title! as Text).data, 'تشغيل من هذه الآية');
    expect([for (final t in tiles) (t.title! as Text).data].sublist(1, 4),
        ['انسخ', 'شارك', 'احفظ']);

    await tester.tap(find.text('تشغيل من هذه الآية'));
    await settle(tester);
    expect(recitation.session!.item, const RecitedItem.ayah(1, 3));
    expect(engine.playing, isTrue);
    expect(find.byType(ListTile), findsNothing, reason: 'the sheet closes');

    await recitation.stop();
    await settle(tester, 2);
    await tester.pumpWidget(const SizedBox());
    recitation.dispose();
    await tester.pump(const Duration(seconds: 2));
  });
}
