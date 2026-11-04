// Two facing pages on wide screens, one page elsewhere (specs/012-foldable-two-page).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/features/reader/paper_sheet.dart';
import 'package:mathani/features/settings/settings_screen.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

/// Screens in logical pixels (research R1).
const duoOpen = Size(890, 626);
const duoFolded = Size(466, 678);
const duoSplitView = Size(445, 626);
const zFoldOpen = Size(750, 832);
const zFoldFolded = Size(412, 915);
const iPhone16 = Size(393, 852);
const iPhoneSE = Size(375, 667);

void main() {
  late ReaderController reader;
  late List<MethodCall> platformCalls;

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  void setScreen(WidgetTester tester, Size size) {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = size * 3
      ..padding = const FakeViewPadding(top: 24 * 3, bottom: 20 * 3);
  }

  /// The pages drawn on screen, right to left.
  List<int> shownPages(WidgetTester tester) {
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final shown = <(double, int)>[];
    for (final e in find.byType(MushafPageRenderer).evaluate()) {
      final rect = tester.getRect(find.byWidget(e.widget));
      if (rect.left >= -1 && rect.right <= width + 1) {
        shown.add((rect.left, (e.widget as MushafPageRenderer).page.number));
      }
    }
    shown.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final s in shown) s.$2];
  }

  /// Waits for the pages on screen to draw (the printed page fonts load in the background).
  Future<void> waitForPages(WidgetTester tester, int count) async {
    for (var i = 0; i < 40 && shownPages(tester).length < count; i++) {
      await settle(tester, 1);
    }
  }

  Finder rendererOf(int page) => find.byWidgetPredicate(
      (w) => w is MushafPageRenderer && w.page.number == page);

  PaperSheet sheetOf(WidgetTester tester, int page) => tester.widget<PaperSheet>(
      find.ancestor(of: rendererOf(page), matching: find.byType(PaperSheet)).first);

  Future<void> pumpApp(WidgetTester tester, Size size,
      {LanguagePref language = LanguagePref.en, int page = 50}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: language));
    reader.jumpToPage(page);
    resetOrientationSync();
    setScreen(tester, size);
    addTearDown(tester.view.reset);
    platformCalls = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      platformCalls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MathaniApp(controller: reader));
    await settle(tester);
  }

  /// A swipe across 40% of the view: left to right turns forward.
  Future<void> fling(WidgetTester tester, double direction) async {
    final width = tester.getSize(find.byType(PageView)).width;
    await tester.fling(find.byType(PageView), Offset(0.4 * width * direction, 0), 2000);
    await settle(tester);
  }

  Future<void> flingForward(WidgetTester tester) => fling(tester, 1);
  Future<void> flingBack(WidgetTester tester) => fling(tester, -1);

  Future<void> leave(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3)); // let the reading position save
    await settle(tester, 2);
  }

  group('User Story 1: two facing pages', () {
    testWidgets('odd on the right, the same size, bindings in the middle', (tester) async {
      await pumpApp(tester, duoOpen);
      await waitForPages(tester, 2);
      expect(shownPages(tester), [49, 50]);
      final right = tester.getRect(rendererOf(49)), left = tester.getRect(rendererOf(50));
      expect(right.left, greaterThan(left.left));
      expect(right.size, left.size);
      expect(sheetOf(tester, 49).bindingOnRight, isFalse, reason: 'inner edge: its left');
      expect(sheetOf(tester, 50).bindingOnRight, isTrue, reason: 'inner edge: its right');
      await leave(tester);
    });

    testWidgets('a swipe turns two pages', (tester) async {
      await pumpApp(tester, duoOpen);
      await flingForward(tester);
      await waitForPages(tester, 2);
      expect(shownPages(tester), [51, 52]);
      expect(reader.page, 51);
      await flingBack(tester);
      await flingBack(tester);
      await waitForPages(tester, 2);
      expect(shownPages(tester), [47, 48]);
      await leave(tester);
    });

    testWidgets('the first and last spreads have no blank page', (tester) async {
      await pumpApp(tester, duoOpen, page: 1);
      await waitForPages(tester, 2);
      expect(shownPages(tester), [1, 2]);
      reader.jumpToPage(604);
      await settle(tester);
      await waitForPages(tester, 2);
      expect(shownPages(tester), [603, 604]);
      await leave(tester);
    });

    testWidgets('an open Z Fold held upright shows two pages too', (tester) async {
      await pumpApp(tester, zFoldOpen);
      await waitForPages(tester, 2);
      expect(shownPages(tester), [49, 50]);
      await leave(tester);
    });

    testWidgets('Android: portrait on phones, any orientation on large screens', (tester) async {
      await pumpApp(tester, zFoldFolded);
      List<Object?> orientations() => [
            for (final c in platformCalls)
              if (c.method == 'SystemChrome.setPreferredOrientations') c.arguments,
          ];
      expect(orientations(), [
        ['DeviceOrientation.portraitUp'],
      ]);
      setScreen(tester, zFoldOpen);
      await settle(tester, 2);
      expect(orientations().last, isEmpty, reason: 'unlocked when open');
      expect(orientations(), hasLength(2));
      setScreen(tester, zFoldOpen);
      await settle(tester, 2);
      expect(orientations(), hasLength(2), reason: 'only a change is sent');
      await leave(tester);
    });
  });

  group('User Story 2: folding keeps the place', () {
    testWidgets('fold and open at the same page', (tester) async {
      await pumpApp(tester, duoOpen, page: 77);
      await waitForPages(tester, 2);
      expect(shownPages(tester), [77, 78]);
      final anchor = reader.anchor;

      setScreen(tester, duoFolded);
      await settle(tester);
      await waitForPages(tester, 1);
      expect(shownPages(tester), [77]);
      expect(reader.page, 77);
      expect(reader.anchor, anchor);

      setScreen(tester, duoOpen);
      await settle(tester);
      await waitForPages(tester, 2);
      expect(shownPages(tester), [77, 78]);
      expect(reader.anchor, anchor);
      await leave(tester);
    });

    testWidgets('an ayah selected on the left page is the page shown when folded', (tester) async {
      await pumpApp(tester, duoOpen, page: 77);
      reader.select(reader.quran.firstAyahOnPage(78).ref);
      await settle(tester, 2);
      setScreen(tester, duoFolded);
      await settle(tester);
      await waitForPages(tester, 1);
      expect(shownPages(tester), [78]);
      expect(reader.page, 78);
      await leave(tester);
    });

    testWidgets('a fold during a drag leaves no half-turned page', (tester) async {
      await pumpApp(tester, duoOpen, page: 77);
      final gesture = await tester.startGesture(tester.getCenter(find.byType(PageView)));
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();
      setScreen(tester, duoFolded);
      await settle(tester);
      await gesture.up();
      await settle(tester);
      await waitForPages(tester, 1);
      expect(shownPages(tester), [77]);
      final rect = tester.getRect(rendererOf(77));
      expect(rect.left, greaterThanOrEqualTo(0));
      await leave(tester);
    });

    testWidgets('the setting shows only where two pages fit, and keeps the place', (tester) async {
      await pumpApp(tester, duoOpen, page: 77);
      await tester.pumpWidget(MathaniApp(controller: reader));
      Navigator.of(tester.element(find.byType(PageView)))
          .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      await settle(tester);
      final row = find.text('Two pages when there is room');
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).last);
      expect(row, findsOneWidget);
      await tester.tap(row);
      await settle(tester, 2);
      expect(reader.preferences.twoPages, isFalse);
      Navigator.of(tester.element(row)).pop();
      await settle(tester);
      await waitForPages(tester, 1);
      expect(shownPages(tester), [77], reason: 'one page, at the same page');

      reader.updatePreferences(reader.preferences.copyWith(twoPages: true));
      await settle(tester);
      await waitForPages(tester, 2);
      expect(shownPages(tester), [77, 78]);
      await leave(tester);
    });
  });

  group('User Story 3: both pages work', () {
    testWidgets('header shows both page numbers', (tester) async {
      await pumpApp(tester, duoOpen);
      expect(find.text('Juz 3 · Pages 49–50'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('header in Arabic', (tester) async {
      await pumpApp(tester, duoOpen, language: LanguagePref.ar);
      expect(find.textContaining('صفحة ٤٩–٥٠'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('bookmark looks at both pages', (tester) async {
      await pumpApp(tester, duoOpen);
      await tester.runAsync(
          () => reader.user.addBookmark(reader.quran.firstAyahOnPage(50).ref, 50));
      await settle(tester, 2);
      expect(find.byIcon(MathaniIcons.bookmarked), findsOneWidget);
      await tapToolbar(tester, MathaniIcons.bookmarked);
      await settle(tester, 2);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await settle(tester, 2);
      expect(reader.user.bookmarksOnPage(49), isEmpty);
      expect(reader.user.bookmarksOnPage(50), isEmpty);
      expect(find.byIcon(MathaniIcons.bookmark), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // the snack bar over the toolbar goes
      await settle(tester, 2);

      await tapToolbar(tester, MathaniIcons.bookmark);
      await settle(tester, 2);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await settle(tester, 2);
      expect(reader.user.bookmarksOnPage(reader.page), hasLength(1));
      await leave(tester);
    });

    testWidgets('long-press on the left page acts on an ayah there', (tester) async {
      await pumpApp(tester, duoOpen);
      await waitForPages(tester, 2);
      await tester.longPressAt(tester.getCenter(rendererOf(50)));
      await settle(tester, 3);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(reader.quran.pageOf(reader.selected!), 50);
      await leave(tester);
    });

    testWidgets('a jump to the other page of the spread does not turn', (tester) async {
      await pumpApp(tester, duoOpen);
      await waitForPages(tester, 2);
      final index = tester.widget<PageView>(find.byType(PageView)).controller!.page;
      final target = reader.quran.firstAyahOnPage(50).ref;
      reader.jumpTo(target);
      await settle(tester, 3);
      expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, index);
      expect(shownPages(tester), [49, 50]);
      expect(reader.page, 50);
      expect(reader.highlighted, target);

      reader.jumpTo(reader.quran.firstAyahOnPage(52).ref);
      await settle(tester, 3);
      await waitForPages(tester, 2);
      expect(shownPages(tester), [51, 52]);
      await leave(tester);
    });

    testWidgets('a tap on either page toggles the controls', (tester) async {
      await pumpApp(tester, duoOpen);
      await waitForPages(tester, 2);
      bool shown() => find.byIcon(MathaniIcons.index).hitTestable().evaluate().isNotEmpty;
      expect(shown(), isTrue);
      await tester.tapAt(tester.getCenter(rendererOf(50)));
      await settle(tester, 2);
      expect(shown(), isFalse);
      await tester.tapAt(tester.getCenter(rendererOf(49)));
      await settle(tester, 2);
      expect(shown(), isTrue);
      await leave(tester);
    });
  });

  group('User Story 4: phones see no change', () {
    for (final (name, size) in [
      ('iPhone 16', iPhone16),
      ('iPhone SE', iPhoneSE),
      ('folded Duo', duoFolded),
      ('open Duo in Split View', duoSplitView),
    ]) {
      testWidgets('one page on $name, and no two-pages setting', (tester) async {
        await pumpApp(tester, size);
        await waitForPages(tester, 1);
        expect(shownPages(tester), [50]);
        expect(find.text('Juz 3 · Page 50'), findsOneWidget);
        await flingForward(tester);
        await waitForPages(tester, 1);
        expect(shownPages(tester), [51], reason: 'a swipe turns one page');
        Navigator.of(tester.element(find.byType(PageView)))
            .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
        await settle(tester);
        expect(find.text('Two pages when there is room', skipOffstage: false), findsNothing);
        await leave(tester);
      });
    }

    testWidgets('iOS: the orientation is never changed', (tester) async {
      await pumpApp(tester, duoOpen);
      expect(platformCalls.where((c) => c.method == 'SystemChrome.setPreferredOrientations'),
          isEmpty);
      await leave(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
