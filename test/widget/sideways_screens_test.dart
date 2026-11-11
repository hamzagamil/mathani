// Every screen stays usable on a phone turned sideways: nothing overflows (specs/013 FR-013,
// research R7). The Mushaf page's own sideways layout is in sideways_page_test.dart.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/index/goto_sheet.dart';
import 'package:mathani/features/index/index_screen.dart';
import 'package:mathani/features/memorization/memorization_controller.dart';
import 'package:mathani/features/memorization/range_sheet.dart';
import 'package:mathani/features/mutashabihat/similar_sheet.dart';
import 'package:mathani/features/onboarding/onboarding_controller.dart';
import 'package:mathani/features/prayer_times/prayer_alerts.dart';
import 'package:mathani/features/prayer_times/prayer_controller.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_times_screen.dart';
import 'package:mathani/features/reader/ayah_actions.dart';
import 'package:mathani/features/reader/reader_screen.dart';
import 'package:mathani/features/recitation/downloads_screen.dart';
import 'package:mathani/features/recitation/reciter_sheet.dart';
import 'package:mathani/features/search/search_screen.dart';
import 'package:mathani/features/settings/settings_screen.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_memorization.dart';
import '../support/fake_recitation.dart';
import '../support/harness.dart';
import '../support/prayer_fakes.dart';

const sideways = Size(780, 360);

void main() {
  Future<void> settle(WidgetTester tester, [int rounds = 5]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  void setScreen(WidgetTester tester, double textScale) {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = sideways * 2
      ..padding = const FakeViewPadding(left: 44 * 2, right: 44 * 2, bottom: 20 * 2);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  }

  void expectNoOverflow(WidgetTester tester, String where) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$where: $error');
  }

  for (final language in [LanguagePref.ar, LanguagePref.en]) {
    for (final textScale in [1.0, 1.3]) {
      final tag = '${language.name}, text ×$textScale';

      testWidgets('the reader, its screens and its sheets ($tag)', (tester) async {
        late ReaderController reader;
        await tester.runAsync(() async {
          await loadAppFonts();
          reader = await openTestReader(similar: quickstartMutashabihat());
        });
        reader.updatePreferences(reader.preferences.copyWith(language: language));
        final (recitation, _, _) = openTestRecitation(reader);
        final memorization = MemorizationController(
          reader: reader,
          model: ReadyAsrModel(),
          recogniser: FakeSpeechRecogniser.new,
          mic: FakeMicSource.new,
        );
        setScreen(tester, textScale);
        await tester.pumpWidget(MathaniApp(
            controller: reader, recitation: recitation, memorization: memorization));
        await settle(tester);
        expectNoOverflow(tester, 'Mushaf layout');

        BuildContext context() => tester.element(find.byType(ReaderScreen));
        Future<void> close(String where) async {
          await settle(tester, 2);
          expectNoOverflow(tester, where);
          Navigator.of(context()).pop();
          await settle(tester, 2);
          expectNoOverflow(tester, 'after $where');
        }

        Future<void> screen(String where, Widget widget) async {
          Navigator.of(context()).push(MaterialPageRoute<void>(builder: (_) => widget));
          await close(where);
        }

        await screen('index', const IndexScreen());
        await screen('index, ajza', const IndexScreen(initialTab: 1));
        await screen('search', const SearchScreen());
        await screen('settings', const SettingsScreen());
        await screen('downloads', const DownloadsScreen());

        showGoToSheet(context());
        await close('go-to sheet');
        showAyahActions(context(), const AyahRef(2, 35));
        await close('ayah actions');
        showSimilarSheet(context(), const AyahRef(2, 35));
        await close('similar ayat, two groups');
        showSimilarSheet(context(), const AyahRef(55, 13));
        await close('similar ayat, large group');
        showReciterSheet(context());
        await close('reciter sheet');
        showMemorizeSheet(context());
        await close('memorize sheet');

        // The recitation bar docked under the page, then the flowing layout with it.
        await tester.runAsync(() => recitation.playFrom(const AyahRef(2, 3)));
        await settle(tester);
        expectNoOverflow(tester, 'Mushaf layout with the recitation bar');
        reader.updatePreferences(reader.preferences.copyWith(layout: ReadingLayout.flowing));
        await settle(tester);
        expectNoOverflow(tester, 'flowing layout with the recitation bar');
        await recitation.stop();
        await settle(tester, 2);
        expectNoOverflow(tester, 'flowing layout');

        await tester.pump(const Duration(seconds: 3)); // let the reading position save
        await tester.pumpWidget(const SizedBox());
        recitation.dispose();
        await tester.pump(const Duration(seconds: 2));
      });

      testWidgets('the onboarding ($tag)', (tester) async {
        late ReaderController reader;
        await tester.runAsync(() async {
          await loadAppFonts();
          reader = await openTestReader(onboarded: false);
        });
        reader.updatePreferences(reader.preferences.copyWith(language: language));
        final (recitation, _, _) = openTestRecitation(reader);
        final onboarding = OnboardingController(reader: reader, recitation: recitation);
        setScreen(tester, textScale);
        const device = MethodChannel('app.mathani/device');
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
            device, (call) async => call.method == 'networkState' ? 'unmetered' : null);
        addTearDown(() => messenger.setMockMethodCallHandler(device, null));
        await tester.pumpWidget(
            MathaniApp(controller: reader, recitation: recitation, onboarding: onboarding));
        await settle(tester);
        // Every step, to the end of the tour: the main button moves on.
        for (var step = 0; step < 30 && onboarding.phase != OnboardingPhase.none; step++) {
          expectNoOverflow(tester, 'onboarding ${onboarding.phase.name}, step $step');
          onboarding.next();
          await settle(tester, 2);
        }
        expectNoOverflow(tester, 'after the onboarding');
        await recitation.stopPreview();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        recitation.dispose();
        await tester.pump(const Duration(seconds: 2));
      });

      testWidgets('the prayer times ($tag)', (tester) async {
        setScreen(tester, textScale);
        final (h, c) = (await tester.runAsync(() async {
          final p = place(cairoResult());
          final h = Harness(
              stored: jsonEncode(PrayerState(
                      places: [p], current: p.id, alerts: AlertSettings())
                  .toJson()));
          final c = PrayerController(hub: h.hub, clock: () => h.clock);
          await c.initialize();
          return (h, c);
        }))!;
        await tester.pumpWidget(PrayerScope(
          alerts: h.hub,
          child: MaterialApp(
            locale: Locale(language.name),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: PrayerTimesScreen(controller: c),
          ),
        ));
        await tester.pump();
        await tester.pump();
        expectNoOverflow(tester, 'prayer times');
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
