// Screen readers and large text through the onboarding (specs/005 FR-019, FR-024; quickstart
// Q-15, Q-16).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/onboarding/onboarding_controller.dart';
import 'package:mathani/features/onboarding/onboarding_steps.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

void main() {
  late ReaderController reader;
  late RecitationController recitation;
  late OnboardingController onboarding;

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> pumpApp(WidgetTester tester,
      {Size size = const Size(390, 845), ReadingLayout layout = ReadingLayout.mushaf}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader(onboarded: false);
    });
    reader.updatePreferences(
        reader.preferences.copyWith(language: LanguagePref.ar, layout: layout));
    (recitation, _, _) = openTestRecitation(reader);
    onboarding = OnboardingController(reader: reader, recitation: recitation);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
        MathaniApp(controller: reader, recitation: recitation, onboarding: onboarding));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await recitation.stop();
    await tester.pumpWidget(const SizedBox());
    onboarding.dispose();
    recitation.dispose();
    await tester.runAsync(() async {
      reader.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(seconds: 2));
  }

  /// Labels of every semantics node a screen reader can activate.
  List<String> tappable(WidgetTester tester) {
    final labels = <String>[];
    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.hasAction(SemanticsAction.tap)) labels.add(data.label);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    return labels;
  }

  testWidgets('choices are radio buttons; a sample button names its reciter', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    expect(tester.getSemantics(find.text('العربية')),
        isSemantics(isInMutuallyExclusiveGroup: true, isChecked: true, isButton: true));
    expect(tester.getSemantics(find.text('English')),
        isSemantics(isInMutuallyExclusiveGroup: true, isChecked: false, isButton: true));
    while (onboarding.step != OnboardingStep.reciter) {
      onboarding.next();
    }
    await settle(tester);
    // Screen readers read an icon button's tooltip as its name.
    for (final (search, name) in [('الحصري', 'محمود خليل الحصري'), ('المنشاوي', 'محمد صديق المنشاوي')]) {
      await searchReciters(tester, search);
      final tooltip = 'استمع إلى مقطع, $name';
      expect(tester.getSemantics(find.byTooltip(tooltip)),
          isSemantics(tooltip: tooltip, isButton: true, hasTapAction: true));
    }
    semantics.dispose();
    await finish(tester);
  });

  testWidgets('under a hint, a screen reader reaches only the card', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    while (onboarding.phase != OnboardingPhase.buttons) {
      onboarding.next();
    }
    await settle(tester);
    expect(tappable(tester).toSet(), {'تخطَّ', 'السابق', 'التالي'});
    expect(find.bySemanticsLabel(RegExp('٤ من ٧')), findsOneWidget);
    semantics.dispose();
    await finish(tester);
  });

  for (final layout in ReadingLayout.values) {
    testWidgets('double text size on a small phone (${layout.name}): every step lays out and '
        'Skip stays reachable', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, size: const Size(320, 568), layout: layout);
      while (onboarding.step != null) {
        expect(find.text('تخطَّ').hitTestable(), findsOneWidget, reason: '${onboarding.step}');
        onboarding.next();
        await settle(tester, 4);
      }
      await finish(tester);
    });
  }
}
