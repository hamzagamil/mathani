// The onboarding's preference steps, skip and gesture stops (specs/005-app-onboarding/contracts/
// onboarding-ui.md › OnboardingScreen).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/onboarding/onboarding_controller.dart';
import 'package:mathani/features/onboarding/onboarding_screen.dart';
import 'package:mathani/features/onboarding/onboarding_steps.dart';
import 'package:mathani/features/onboarding/tour_illustration.dart';
import 'package:mathani/features/reader/reader_screen.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

const _device = MethodChannel('app.mathani/device');

void main() {
  late ReaderController reader;
  late RecitationController recitation;
  late FakeAudioEngine engine;
  late OnboardingController onboarding;

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    LanguagePref language = LanguagePref.ar,
    ReaderPreferences Function(ReaderPreferences p)? seed,
    Size size = const Size(390, 845),
    String network = 'unmetered',
  }) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader(onboarded: false);
    });
    final prefs = reader.preferences.copyWith(language: language);
    reader.updatePreferences(seed?.call(prefs) ?? prefs);
    (recitation, engine, _) = openTestRecitation(reader);
    onboarding = OnboardingController(reader: reader, recitation: recitation);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    messenger.setMockMethodCallHandler(
        _device, (call) async => call.method == 'networkState' ? network : null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(_device, null);
    });
    await tester.pumpWidget(
        MathaniApp(controller: reader, recitation: recitation, onboarding: onboarding));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await recitation.stopPreview();
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

  /// Taps, then lets the step animation run: it starts on the frame after the rebuild, and the
  /// page takes taps again on the frame after it ends.
  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await settle(tester, 4);
  }

  /// The first of the reciter rows named [text] (a reciter's Murattal recording), found by search.
  Future<void> tapFirst(WidgetTester tester, String text) async {
    await searchReciters(tester, text);
    await tester.tap(find.descendant(of: find.byType(ListView), matching: find.text(text)).first);
    await settle(tester, 4);
  }

  Future<void> next(WidgetTester tester) => tapText(tester, 'التالي');

  group('frame', () {
    testWidgets('a first run opens on the onboarding; Next and Back move between steps',
        (tester) async {
      await pumpApp(tester);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(ReaderScreen), findsNothing);
      expect(find.text('الخطوة ١ من ٤'), findsOneWidget);
      expect(find.text('السابق'), findsNothing, reason: 'no Back on the first step');

      await next(tester);
      expect(onboarding.step, OnboardingStep.theme);
      expect(find.text('الخطوة ٢ من ٤'), findsOneWidget);
      await tapText(tester, 'السابق');
      expect(onboarding.step, OnboardingStep.language);
      await finish(tester);
    });

    testWidgets('English progress', (tester) async {
      await pumpApp(tester, language: LanguagePref.en);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('Skip is on screen on every step, on a small phone', (tester) async {
      await pumpApp(tester, size: const Size(320, 568));
      while (onboarding.phase != OnboardingPhase.buttons) {
        expect(find.text('تخطَّ').hitTestable(), findsOneWidget, reason: '${onboarding.step}');
        await next(tester);
      }
      await finish(tester);
    });

    testWidgets('system back goes to the previous step', (tester) async {
      await pumpApp(tester);
      await next(tester);
      await tester.binding.handlePopRoute();
      await settle(tester, 2);
      expect(onboarding.step, OnboardingStep.language);
      await finish(tester);
    });

    testWidgets('without an onboarding the app opens on the reader', (tester) async {
      await tester.runAsync(() async {
        await loadAppFonts();
        reader = await openTestReader(onboarded: false);
      });
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
      await tester.pumpWidget(MathaniApp(controller: reader));
      await settle(tester);
      expect(find.byType(ReaderScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        reader.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(seconds: 2));
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('setup steps', () {
    testWidgets('language switches text and direction in place', (tester) async {
      await pumpApp(tester);
      expect(find.text('حسب الجهاز (English)'), findsOneWidget,
          reason: 'the device choice names what it gives');
      await tapText(tester, 'English');
      expect(onboarding.step, OnboardingStep.language);
      expect(reader.preferences.language, LanguagePref.en);
      expect(find.text('Choose the app language'), findsOneWidget);
      expect(
          Directionality.of(tester.element(find.text('Choose the app language'))), TextDirection.ltr);
      await tapText(tester, 'العربية');
      expect(find.text('اختر لغة التطبيق'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('اختر لغة التطبيق'))), TextDirection.rtl);
      await finish(tester);
    });

    testWidgets('theme applies at once, with a preview', (tester) async {
      await pumpApp(tester);
      await next(tester);
      expect(find.byType(TourIllustration), findsOneWidget);
      await tapText(tester, 'ليلي');
      expect(reader.preferences.theme, ThemePref.night);
      expect(Theme.of(tester.element(find.text('ليلي'))).brightness, Brightness.dark);
      await finish(tester);
    });

    testWidgets('each step opens on the current value', (tester) async {
      await pumpApp(tester, seed: (p) => p.copyWith(theme: ThemePref.night));
      final semantics = tester.ensureSemantics();
      await next(tester);
      expect(tester.getSemantics(find.text('ليلي')), isSemantics(isChecked: true));
      expect(tester.getSemantics(find.text('نهاري')), isSemantics(isChecked: false));
      semantics.dispose();
      await finish(tester);
    });

    testWidgets('flowing adds the text size step, which sets the size of a real ayah',
        (tester) async {
      await pumpApp(tester, language: LanguagePref.en);
      await tapText(tester, 'Next');
      await tapText(tester, 'Next');
      await tapText(tester, 'Flowing text');
      expect(reader.layout, ReadingLayout.flowing);
      expect(find.text('Step 3 of 5'), findsOneWidget);
      await tapText(tester, 'Next');
      expect(onboarding.step, OnboardingStep.textSize);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect((slider.min, slider.max), (18, 34));
      await tester.drag(find.byType(Slider), const Offset(120, 0));
      await settle(tester, 2);
      final size = reader.preferences.flowFontSize;
      expect(size, greaterThan(24));
      final quran = tester.widget<Text>(find.byWidgetPredicate(
          (w) => w is Text && w.style?.fontFamily == 'QuranText'));
      expect(quran.style!.fontSize, size.toDouble());
      expect(quran.data, contains('ٱلْحَمْدُ'));
      await finish(tester);
    });

    testWidgets('reciter: listed, the current one selected; choosing saves it',
        (tester) async {
      await pumpApp(tester);
      final semantics = tester.ensureSemantics();
      for (var i = 0; i < 3; i++) {
        await next(tester);
      }
      expect(onboarding.step, OnboardingStep.reciter);
      // A reciter's other recordings share the name; Murattal, first in the catalogue, comes first.
      expect(tester.getSemantics(find.text('محمود خليل الحصري').first), isSemantics(isChecked: true));
      await tapFirst(tester, 'محمد صديق المنشاوي');
      expect(reader.preferences.reciter, 'minshawy');
      expect(find.text('تحتاج المقاطع إلى اتصال بالإنترنت، ويمكنك الاختيار دونها.'), findsNothing);
      semantics.dispose();
      await finish(tester);
    });

    testWidgets('a sample plays and stops from its button', (tester) async {
      await pumpApp(tester);
      for (var i = 0; i < 3; i++) {
        await next(tester);
      }
      await tester.tap(find.byTooltip('استمع إلى مقطع, محمود خليل الحصري'));
      await settle(tester, 2);
      expect(recitation.preview?.status, PreviewStatus.playing);
      expect(engine.playing, isTrue);
      await tester.tap(find.byTooltip('أوقف المقطع, محمود خليل الحصري'));
      await settle(tester, 2);
      expect(recitation.preview, isNull);
      await finish(tester);
    });

    testWidgets('offline: a note, and the samples are disabled; choosing still works',
        (tester) async {
      await pumpApp(tester, network: 'none');
      for (var i = 0; i < 3; i++) {
        await next(tester);
      }
      expect(find.text('تحتاج المقاطع إلى اتصال بالإنترنت، ويمكنك الاختيار دونها.'), findsOneWidget);
      final buttons = tester.widgetList<IconButton>(find.byWidgetPredicate(
          (w) => w is IconButton && (w.tooltip ?? '').startsWith('استمع إلى مقطع')));
      expect(buttons, isNotEmpty); // the rows in view of the long list
      expect(buttons.every((b) => b.onPressed == null), isTrue);
      await tapFirst(tester, 'محمد صديق المنشاوي');
      expect(reader.preferences.reciter, 'minshawy');
      await finish(tester);
    });
  });

  group('skip', () {
    testWidgets('Skip on the first screen opens the reader on page 1 with the defaults',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('تخطَّ'));
      await tester.pump();
      expect(find.byType(ReaderScreen), findsOneWidget, reason: 'at once');
      await settle(tester);
      expect(reader.page, 1);
      expect(reader.preferences.onboardingDone, isTrue);
      expect(reader.preferences.theme, ThemePref.system);
      expect(reader.layout, ReadingLayout.mushaf);
      await finish(tester);
    });

    for (final steps in [1, 2, 3]) {
      testWidgets('Skip on setup step ${steps + 1} lands on the reader', (tester) async {
        await pumpApp(tester);
        for (var i = 0; i < steps; i++) {
          await next(tester);
        }
        await tapText(tester, 'تخطَّ');
        expect(find.byType(ReaderScreen), findsOneWidget);
        await finish(tester);
      });
    }

    testWidgets('choices before Skip are kept', (tester) async {
      await pumpApp(tester);
      await next(tester);
      await tapText(tester, 'ليلي');
      await tapText(tester, 'تخطَّ');
      expect(reader.preferences.theme, ThemePref.night);
      await finish(tester);
    });

    testWidgets('Skip during a sample stops it', (tester) async {
      await pumpApp(tester);
      for (var i = 0; i < 3; i++) {
        await next(tester);
      }
      await tester.tap(find.byTooltip('استمع إلى مقطع, محمود خليل الحصري'));
      await settle(tester, 2);
      expect(recitation.preview, isNotNull);
      await tapText(tester, 'تخطَّ');
      expect(recitation.preview, isNull);
      expect(engine.playing, isFalse);
      await finish(tester);
    });

    testWidgets('after Skip, the next launch opens on the reader', (tester) async {
      await pumpApp(tester);
      await tapText(tester, 'تخطَّ');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      final (anchor, saved) = (await tester.runAsync(reader.user.loadStartup))!;
      expect(saved.onboardingDone, isTrue);
      final relaunched = ReaderController(
          quran: reader.quran, user: reader.user, anchor: anchor, preferences: saved);
      final again = OnboardingController(reader: relaunched);
      await tester.pumpWidget(MathaniApp(controller: relaunched, onboarding: again));
      await settle(tester);
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      again.dispose();
      relaunched.dispose();
      await finish(tester);
    });
  });

  group('gesture stops', () {
    testWidgets('after the preferences, three gesture stops for the Mushaf layout',
        (tester) async {
      await pumpApp(tester);
      for (var i = 0; i < 4; i++) {
        await next(tester);
      }
      expect(onboarding.step, OnboardingStep.turnPages);
      expect(find.text('قلّب الصفحات'), findsOneWidget);
      expect(find.text('١ من ٧'), findsOneWidget);
      expect(find.text('اسحب الصفحة لتقلبها كما تقلّب صفحات المصحف المطبوع.'), findsOneWidget);
      await next(tester);
      expect(find.text('انقر على الصفحة لإظهار أدوات التحكم أو إخفائها.'), findsOneWidget);
      expect(find.text('٢ من ٧'), findsOneWidget);
      await next(tester);
      expect(find.text('خيارات الآية'), findsOneWidget);
      expect(find.text('٣ من ٧'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('the flowing layout gets its own texts', (tester) async {
      await pumpApp(tester, seed: (p) => p.copyWith(layout: ReadingLayout.flowing));
      for (var i = 0; i < 5; i++) {
        await next(tester);
      }
      expect(onboarding.step, OnboardingStep.turnPages);
      expect(find.text('مرّر الشاشة لتتابع القراءة؛ النص متصل من سورة إلى أخرى.'), findsOneWidget);
      await next(tester);
      expect(find.textContaining('تبقى أدوات التحكم'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('the illustration is hidden from screen readers and still when animations are off',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpApp(tester);
      for (var i = 0; i < 4; i++) {
        await next(tester);
      }
      expect(onboarding.step, OnboardingStep.turnPages);
      expect(
          find.ancestor(of: find.byType(CustomPaint), matching: find.byType(ExcludeSemantics)),
          findsWidgets);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);
      await finish(tester);
    });
  });
}
