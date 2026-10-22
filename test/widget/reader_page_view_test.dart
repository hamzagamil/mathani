// Full-screen paper page: controls on tap, immersive reading, one-time hint
// (specs/002-print-like-mushaf-page/contracts/reader-page-view.md).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

const _hint = 'اضغط على الصفحة لإظهار الأدوات';

void main() {
  late ReaderController reader;
  late List<String> uiModes;

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
    });
    reader.updatePreferences(reader.preferences.copyWith(language: LanguagePref.ar));
    tester.view.physicalSize = const Size(780, 1690);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    uiModes = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') uiModes.add('${call.arguments}');
      return null;
    });
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MathaniApp(controller: reader));
    await settle(tester);
  }

  /// The toolbar is reachable (visible and on screen).
  bool controlsShown(WidgetTester tester) =>
      find.byIcon(MathaniIcons.index).hitTestable().evaluate().isNotEmpty;

  Future<void> turnPage(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(300, 0)); // left → right = next page
    await settle(tester);
  }

  Future<void> tapPage(WidgetTester tester) async {
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await settle(tester, 2);
  }

  testWidgets('controls show on open, hide on a page turn and toggle on tap', (tester) async {
    await pumpApp(tester);
    expect(controlsShown(tester), isTrue, reason: 'shown when the reader opens');

    await turnPage(tester);
    expect(controlsShown(tester), isFalse, reason: 'a page turn hides them');
    expect(uiModes.last, contains('immersiveSticky'));
    expect(find.text(_hint), findsOneWidget, reason: 'first hide shows the hint once');
    expect(reader.preferences.controlsHintShown, isTrue);

    await tapPage(tester);
    expect(controlsShown(tester), isTrue, reason: 'a tap shows them');
    expect(uiModes.last, contains('edgeToEdge'));

    await tapPage(tester);
    expect(controlsShown(tester), isFalse, reason: 'a second tap hides them');

    // The hint never comes back.
    await tester.pump(const Duration(seconds: 5));
    await settle(tester, 2);
    await tapPage(tester);
    await turnPage(tester);
    expect(find.text(_hint), findsNothing);
  });

  testWidgets('selection and long-press keep their meaning', (tester) async {
    await pumpApp(tester);
    await turnPage(tester);
    expect(controlsShown(tester), isFalse);

    reader.select(const AyahRef(2, 6));
    await settle(tester, 2);
    await tapPage(tester);
    expect(reader.selected, isNull, reason: 'a tap clears the selection');
    expect(controlsShown(tester), isFalse, reason: '...and leaves the controls alone');

    // The printed page font loads in the background; long-press needs the page drawn.
    for (var i = 0; i < 30 && find.byType(MushafPageRenderer).evaluate().isEmpty; i++) {
      await settle(tester, 1);
    }
    await tester.longPressAt(tester.getCenter(find.byType(PageView)));
    await settle(tester, 3);
    expect(find.byType(BottomSheet), findsOneWidget, reason: 'long-press opens the ayah actions');
    expect(controlsShown(tester), isFalse);
  });

  testWidgets('with a screen reader on, the controls stay', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester);
    await turnPage(tester);
    expect(controlsShown(tester), isTrue);
    expect(uiModes.where((m) => m.contains('immersive')), isEmpty);
  });

  testWidgets('the flowing layout keeps its bars; leaving restores the system bars', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(MathaniIcons.flowing));
    await settle(tester);
    expect(find.byType(AppBar).hitTestable(), findsOneWidget);
    expect(controlsShown(tester), isTrue);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await settle(tester, 2);
    expect(controlsShown(tester), isTrue, reason: 'flowing has no tap-to-show');
    expect(uiModes.isEmpty || uiModes.last.contains('edgeToEdge'), isTrue);
    await tester.pump(const Duration(seconds: 3)); // let the reading position save
    await settle(tester, 2);
  });
}
