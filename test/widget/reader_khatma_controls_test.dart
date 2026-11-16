// The khatma on the reading screen (specs/014 contracts/khatma-ui-and-reminders.md › The reading
// screen): the toolbar's order and fit, pages left in the header, the Done row, and Undo.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/features/khatma/khatma_controller.dart';
import 'package:mathani/features/khatma/khatma_models.dart';
import 'package:mathani/features/memorization/memorization_controller.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_memorization.dart';
import '../support/fake_recitation.dart';
import '../support/harness.dart';
import '../support/khatma_support.dart';

void main() {
  late ReaderController reader;
  late KhatmaController khatma;

  Future<void> open(WidgetTester tester, {double width = 412, bool full = false}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(twoPages: false));
    khatma = await openTestKhatma(tester, reader, start: const MarksPlan(8));
    setPhone(tester, width: width, height: 800);
    if (full) {
      final (recitation, _, _) = openTestRecitation(reader);
      final memorization = MemorizationController(
        reader: reader,
        model: ReadyAsrModel(),
        recogniser: FakeSpeechRecogniser.new,
        mic: FakeMicSource.new,
      );
      await tester.pumpWidget(MathaniApp(
          controller: reader, khatma: khatma, recitation: recitation, memorization: memorization));
    } else {
      await tester.pumpWidget(MathaniApp(controller: reader, khatma: khatma));
    }
    reader.jumpToPage(1);
    await settleKhatma(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    khatma.dispose();
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> showControls(WidgetTester tester) async {
    if (find.byIcon(MathaniIcons.khatma).hitTestable().evaluate().isEmpty) {
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await settleKhatma(tester, 2);
    }
  }

  testWidgets('the toolbar order: index, search, listen, memorize, khatma, bookmark, settings',
      (tester) async {
    await open(tester, full: true);
    await showControls(tester);
    final icons = [
      MathaniIcons.index,
      MathaniIcons.search,
      MathaniIcons.play,
      MathaniIcons.memorize,
      MathaniIcons.khatma,
      MathaniIcons.bookmark,
      MathaniIcons.settings,
    ];
    final xs = [for (final i in icons) tester.getCenter(find.byIcon(i)).dx];
    // English, left to right.
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThan(xs[i - 1]), reason: '${icons[i]} after ${icons[i - 1]}');
    }
    await close(tester);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('seven buttons at 320 wide on ${platform.name}', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      await open(tester, width: 320, full: true);
      await showControls(tester);
      final scrolls = find.ancestor(
          of: find.byIcon(MathaniIcons.khatma),
          matching: find.byWidgetPredicate(
              (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal));
      final min = platform == TargetPlatform.iOS ? 44.0 : 48.0;
      for (final icon in [MathaniIcons.index, MathaniIcons.khatma, MathaniIcons.settings]) {
        final button = find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton));
        expect(tester.getSize(button).width, greaterThanOrEqualTo(min));
      }
      // 7 × 44 = 308 fits 320; 7 × 48 = 336 does not, so Android scrolls.
      expect(scrolls, platform == TargetPlatform.iOS ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('pages left, the Done row on the last page, and Undo', (tester) async {
    await open(tester);
    await showControls(tester);
    expect(find.textContaining('21 pages left'), findsOneWidget);
    expect(find.text("Today's wird ends on this page"), findsNothing);

    reader.jumpToPage(21);
    await settleKhatma(tester);
    await showControls(tester);
    expect(find.textContaining('1 page left'), findsOneWidget);
    expect(find.text("Today's wird ends on this page"), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await settleKhatma(tester);
    expect(khatma.currentWird!.number, 2);
    expect(find.text("Today's wird is done"), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settleKhatma(tester);
    expect(khatma.currentWird!.number, 1);

    reader.jumpToPage(300);
    await settleKhatma(tester);
    await showControls(tester);
    expect(find.textContaining('pages left'), findsNothing);
    await close(tester);
  });
}
