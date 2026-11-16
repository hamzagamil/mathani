// The mark where a wird ends (specs/014 FR-010, research R5): the ayah-end sign in the khatma
// colour and a triangle in the end-side margin; no word moves; screen readers hear it; nothing
// while memorizing. Goldens are tagged `golden` (font rasterisation differs by platform);
// regenerate with `flutter test --tags golden --update-goldens test/widget/wird_end_mark_test.dart`.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/app/theme/app_theme.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/features/khatma/khatma_models.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';
import '../support/khatma_support.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final b in Brightness.values) {
    test('the khatma colour has 3:1 contrast on the page ($b)', () {
      final c = MathaniColors.forBrightness(b);
      expect(_contrast(c.khatmaMark, c.surface), greaterThanOrEqualTo(3));
    });
  }

  group('page 62, the end of wird 3 of a juz a day', () {
    late ReaderController reader;
    late KhatmaController khatma;
    var memorizing = false;

    Future<RenderMushafPage> page62(WidgetTester tester) async {
      await settleKhatma(tester);
      return tester.renderObject<RenderMushafPage>(find.byWidgetPredicate(
          (w) => w is MushafPageRenderer && w.page.number == 62));
    }

    Future<int> open(WidgetTester tester, {ThemePref theme = ThemePref.day}) async {
      memorizing = false;
      await tester.runAsync(() async {
        await loadAppFonts();
        reader = await openTestReader();
      });
      reader.updatePreferences(reader.preferences.copyWith(theme: theme, twoPages: false));
      khatma = await openTestKhatma(tester, reader,
          start: const MarksPlan(8), isMemorizing: () => memorizing);
      await tester.runAsync(khatma.markRead);
      await tester.runAsync(khatma.markRead);
      expect(khatma.currentWird!.number, 3);
      setPhone(tester, width: 375, height: 760);
      reader.jumpToPage(62);
      await tester.pumpWidget(MathaniApp(controller: reader, khatma: khatma));
      await settleKhatma(tester);
      return reader.quran.ayahAt(const AyahRef(3, 92)).lastWordId;
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      khatma.dispose();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('the sign, the triangle in the margin, and no word moved', (tester) async {
      final endWord = await open(tester);
      final colors = MathaniColors.forBrightness(Brightness.light);
      var box = await page62(tester);
      expect(box.tintOfWord(endWord), colors.khatmaMark);
      final triangles = box.endMarkRects;
      expect(triangles, hasLength(1));
      final block = box.geometry!.textBlock;
      expect(triangles.single.right, lessThanOrEqualTo(block.left), reason: 'in the margin');
      final marked = box.ayahRect(const AyahRef(3, 92));
      final first = box.ayahRect(const AyahRef(3, 93));

      // The same page with no khatma: every word in the same place.
      await tester.runAsync(khatma.end);
      box = await page62(tester);
      expect(box.endMarkRects, isEmpty);
      expect(box.tintOfWord(endWord), isNull);
      expect(box.ayahRect(const AyahRef(3, 92)), marked);
      expect(box.ayahRect(const AyahRef(3, 93)), first);
      await close(tester);
    });

    testWidgets('screen readers hear where the wird ends', (tester) async {
      await open(tester);
      final handle = tester.ensureSemantics();
      await settleKhatma(tester);
      expect(find.bySemanticsLabel(RegExp("End of today's wird at ayah 92")), findsWidgets);
      handle.dispose();
      await close(tester);
    });

    testWidgets('nothing during memorization', (tester) async {
      final endWord = await open(tester);
      memorizing = true;
      khatma.notifyListeners();
      final box = await page62(tester);
      expect(box.endMarkRects, isEmpty);
      expect(box.tintOfWord(endWord), isNull);
      await close(tester);
    });

    for (final theme in [ThemePref.day, ThemePref.night]) {
      testWidgets('golden, ${theme.name}', (tester) async {
        await open(tester, theme: theme);
        await settleKhatma(tester);
        await expectLater(
          find.byWidgetPredicate((w) => w is MushafPageRenderer && w.page.number == 62),
          matchesGoldenFile('goldens/wird_end_62_${theme.name}.png'),
        );
        await close(tester);
      }, tags: ['golden']);
    }
  });
}
