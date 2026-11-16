// The Mushaf page on a phone turned sideways: full width, scrolling (specs/013 User Story 2,
// contracts/reader-ui.md › The scrolling page).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/reader/flowing_view.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/features/reader/mushaf_view.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

const upright = Size(360, 780);
const sideways = Size(780, 360);
const duoOpen = Size(890, 626);

void main() {
  late ReaderController reader;
  RecitationController? recitation;

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// A phone with a status bar upright, and a camera cut-out on each side when sideways.
  void setScreen(WidgetTester tester, Size size) {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = size * 2
      ..padding = size.width > size.height && size.height < 600
          ? const FakeViewPadding(left: 44 * 2, right: 44 * 2, bottom: 20 * 2)
          : const FakeViewPadding(top: 24 * 2, bottom: 20 * 2);
  }

  Future<void> pumpApp(WidgetTester tester, Size size,
      {int page = 50, bool withRecitation = false}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(
        reader.preferences.copyWith(language: LanguagePref.ar, lettering: Lettering.builtin));
    reader.jumpToPage(page);
    recitation = withRecitation ? openTestRecitation(reader).$1 : null;
    setScreen(tester, size);
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MathaniApp(controller: reader, recitation: recitation));
    await settle(tester);
  }

  Future<void> leave(WidgetTester tester) async {
    await recitation?.stop();
    await tester.pump(const Duration(seconds: 3)); // let the reading position save
    await settle(tester, 2);
    if (recitation != null) {
      await tester.pumpWidget(const SizedBox());
      recitation!.dispose();
      await tester.pump(const Duration(seconds: 2));
    }
  }

  Finder rendererOf(int page) =>
      find.byWidgetPredicate((w) => w is MushafPageRenderer && w.page.number == page);

  RenderMushafPage boxOf(WidgetTester tester, int page) =>
      tester.renderObject<RenderMushafPage>(rendererOf(page));

  Finder scrollViewOf(int page) =>
      find.ancestor(of: rendererOf(page), matching: find.byType(SingleChildScrollView));

  ScrollPosition positionOf(WidgetTester tester, int page) => tester
      .state<ScrollableState>(
          find.descendant(of: scrollViewOf(page), matching: find.byType(Scrollable)).first)
      .position;

  /// Where [rect] of [page]'s renderer is on the screen.
  Rect onScreen(WidgetTester tester, int page, Rect rect) =>
      rect.shift(boxOf(tester, page).localToGlobal(Offset.zero));

  Future<void> fling(WidgetTester tester, double direction) async {
    final width = tester.getSize(find.byType(PageView)).width;
    await tester.fling(find.byType(PageView), Offset(0.4 * width * direction, 0), 2000);
    await settle(tester);
  }

  /// The last ayah with a word on [page].
  Future<AyahRef> lastAyahOf(WidgetTester tester, int page) async {
    final lines = (await tester.runAsync(() => reader.quran.page(page)))!.lines;
    return lines.lastWhere((l) => l.words.isNotEmpty).words.last.ref;
  }

  testWidgets('sideways, the text is at least 1.7 times its upright size (SC-003)',
      (tester) async {
    await pumpApp(tester, upright);
    final before = boxOf(tester, 50).geometry!.textBlock.width;
    final beforeFont = boxOf(tester, 50).geometry!.fontSize;
    final overGapBefore = boxOf(tester, 50).lineReports.where((l) => l.overGap).length;
    expect(boxOf(tester, 50).wordFontSizes, {beforeFont});
    expect(scrollViewOf(50), findsNothing);
    setScreen(tester, sideways);
    await settle(tester);
    final box = boxOf(tester, 50);
    expect(box.geometry!.textBlock.width / before, greaterThanOrEqualTo(1.7));
    expect(box.allLinesFit, isTrue);
    // The words themselves are larger, not the same words spread over a wider line.
    expect(box.wordFontSizes, {box.geometry!.fontSize});
    expect(box.geometry!.fontSize / beforeFont, greaterThanOrEqualTo(1.7));
    expect(box.lineReports.where((l) => l.overGap).length, lessThanOrEqualTo(overGapBefore));
    // Inside the safe areas: nothing under the camera cut-outs.
    final page = tester.getRect(rendererOf(50));
    expect(page.left, greaterThanOrEqualTo(44));
    expect(page.right, lessThanOrEqualTo(sideways.width - 44));
    await leave(tester);
  });

  testWidgets('the page scrolls from its details at the top to its number, and stops (FR-008)',
      (tester) async {
    await pumpApp(tester, sideways);
    final position = positionOf(tester, 50);
    final viewport = tester.getRect(scrollViewOf(50));
    expect(position.pixels, 0);
    expect(position.maxScrollExtent, greaterThan(viewport.height));
    final details = boxOf(tester, 50).pageDetails!;
    expect(viewport.contains(onScreen(tester, 50, details.surahRect).center), isTrue);

    await tester.drag(scrollViewOf(50), const Offset(0, -5000));
    await settle(tester, 2);
    expect(position.pixels, position.maxScrollExtent);
    expect(viewport.contains(onScreen(tester, 50, details.pageRect).center), isTrue);

    await tester.drag(scrollViewOf(50), const Offset(0, 5000));
    await settle(tester, 2);
    expect(position.pixels, 0);
    await leave(tester);
  });

  testWidgets('a sideways swipe turns the page, which starts at its top (FR-009)',
      (tester) async {
    await pumpApp(tester, sideways);
    await tester.drag(scrollViewOf(50), const Offset(0, -300));
    await settle(tester, 2);
    expect(positionOf(tester, 50).pixels, greaterThan(100));

    await fling(tester, 1);
    expect(reader.page, 51);
    expect(positionOf(tester, 51).pixels, 0);
    await fling(tester, -1);
    expect(reader.page, 50);
    expect(positionOf(tester, 50).pixels, 0, reason: 'a page turned back to starts at its top');
    await leave(tester);
  });

  testWidgets('turning the phone keeps the page (FR-010)', (tester) async {
    await pumpApp(tester, upright, page: 300);
    setScreen(tester, sideways);
    await settle(tester);
    expect(reader.page, 300);
    expect(positionOf(tester, 300).pixels, 0);
    await tester.drag(scrollViewOf(300), const Offset(0, -300));
    await settle(tester, 2);
    setScreen(tester, upright);
    await settle(tester);
    expect(reader.page, 300);
    expect(boxOf(tester, 300).wordFontSizes, {boxOf(tester, 300).geometry!.fontSize},
        reason: 'back to the upright size');
    expect(scrollViewOf(300), findsNothing);
    expect(tester.getRect(rendererOf(300)).height, lessThanOrEqualTo(upright.height));
    expect(tester.takeException(), isNull);
    await leave(tester);
  });

  testWidgets('a long press after scrolling picks the ayah under the finger (FR-012)',
      (tester) async {
    await pumpApp(tester, sideways);
    final ref = await lastAyahOf(tester, 50);
    await tester.drag(scrollViewOf(50), const Offset(0, -5000));
    await settle(tester, 2);
    final rect = onScreen(tester, 50, boxOf(tester, 50).ayahRect(ref)!);
    await tester.longPressAt(Offset(rect.left + 6, rect.bottom - 6));
    await settle(tester, 2);
    expect(reader.selected, ref);
    await leave(tester);
  });

  testWidgets('an ayah the app jumps to is brought on screen (FR-011)', (tester) async {
    await pumpApp(tester, sideways);
    final ref = await lastAyahOf(tester, 50);
    expect(boxOf(tester, 50).ayahRect(const AyahRef(1, 1)), isNull);
    reader.jumpTo(ref);
    await settle(tester, 3);
    final viewport = tester.getRect(scrollViewOf(50));
    final rect = onScreen(tester, 50, boxOf(tester, 50).ayahRect(ref)!);
    expect(positionOf(tester, 50).pixels, greaterThan(0));
    expect(rect.top, greaterThanOrEqualTo(viewport.top));
    expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));

    // From another page: the page appears with the ayah on screen.
    final far = await lastAyahOf(tester, 300);
    reader.jumpTo(far);
    await settle(tester);
    expect(reader.page, 300);
    final farRect = onScreen(tester, 300, boxOf(tester, 300).ayahRect(far)!);
    final farViewport = tester.getRect(scrollViewOf(300));
    expect(farRect.top, greaterThanOrEqualTo(farViewport.top));
    expect(farRect.bottom, lessThanOrEqualTo(farViewport.bottom + 0.5));
    await leave(tester);
  });

  testWidgets('the recited ayah is brought on screen (FR-011)', (tester) async {
    await pumpApp(tester, sideways, withRecitation: true);
    final ref = await lastAyahOf(tester, 50);
    await tester.runAsync(() => recitation!.playFrom(ref));
    await settle(tester);
    expect(reader.page, 50);
    final viewport = tester.getRect(scrollViewOf(50));
    final rect = onScreen(tester, 50, boxOf(tester, 50).ayahRect(ref)!);
    expect(rect.top, greaterThanOrEqualTo(viewport.top));
    expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
    await leave(tester);
  });

  testWidgets('a scroll by the reader hides the controls; following does not', (tester) async {
    await pumpApp(tester, sideways);
    final search = find.byIcon(MathaniIcons.search);
    expect(search.hitTestable(), findsOneWidget);
    reader.jumpTo(await lastAyahOf(tester, 50));
    await settle(tester, 3);
    expect(search.hitTestable(), findsOneWidget, reason: 'a follow scroll keeps the controls');

    await tester.drag(scrollViewOf(50), const Offset(0, 120));
    await settle(tester, 2);
    expect(search.hitTestable(), findsNothing);
    await tester.pump(const Duration(seconds: 2)); // the highlight ends
    await leave(tester);
  });

  testWidgets('where two pages fit, nothing scrolls, with the setting on and off (FR-015)',
      (tester) async {
    await pumpApp(tester, duoOpen);
    expect(find.descendant(of: find.byType(PageView), matching: find.byType(SingleChildScrollView)),
        findsNothing);
    reader.updatePreferences(reader.preferences.copyWith(twoPages: false));
    await settle(tester);
    expect(find.descendant(of: find.byType(PageView), matching: find.byType(SingleChildScrollView)),
        findsNothing);
    expect(tester.getRect(rendererOf(reader.page)).height, lessThanOrEqualTo(duoOpen.height));
    await leave(tester);
  });

  testWidgets('the flowing layout is not a scrolling page', (tester) async {
    await pumpApp(tester, sideways);
    expect(scrollsPage(tester.element(find.byType(MushafView))), isTrue);
    reader.updatePreferences(reader.preferences.copyWith(layout: ReadingLayout.flowing));
    await settle(tester);
    expect(scrollsPage(tester.element(find.byType(FlowingView))), isFalse);
    expect(tester.takeException(), isNull);
    await leave(tester);
  });
}
