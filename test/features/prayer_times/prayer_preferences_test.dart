import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/prayer_times/calculation_sheet.dart';
import 'package:mathani/features/prayer_times/locations_sheet.dart';
import 'package:mathani/features/prayer_times/prayer_copy.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_services.dart';

import 'prayer_locations_test.dart' show placeController, addPlace;
import 'prayer_setup_test.dart' show Store;

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      'calculation controls expose every choice at large text in $language',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final store = Store();
        final controller = placeController(store);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
        });
        await controller.initialize();
        final id = await addPlace(controller, 'Home');
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showPrayerCalculation(context, controller),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(CalculationSheet)),
        );
        Future<void> choose(Finder field, String label) async {
          if (field.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              field,
              120,
              scrollable: find.byType(Scrollable).last,
            );
          }
          await Scrollable.ensureVisible(tester.element(field), alignment: 0.2);
          await tester.pumpAndSettle();
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(label).last);
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        for (final method in PrayerMethod.values) {
          await choose(
            find.byType(DropdownButtonFormField<PrayerMethod>),
            prayerMethodName(l, method),
          );
        }
        for (final madhhab in PrayerMadhhab.values) {
          await choose(
            find.byType(DropdownButtonFormField<PrayerMadhhab>),
            prayerMadhhabName(l, madhhab),
          );
        }
        await choose(
          find.byType(DropdownButtonFormField<HighLatitudeRule>),
          l.prayerSeventhNight,
        );
        expect(store.writes, 1, reason: 'Editing is a draft until Save');
        await tester.tap(find.text(l.prayerSave));
        await tester.pumpAndSettle();
        expect(controller.state.locations.single.id, id);
        expect(
          controller.viewedLocation!.calculation.method,
          PrayerMethod.northAmerica,
        );
        expect(
          controller.viewedLocation!.calculation.madhhab,
          PrayerMadhhab.hanbali,
        );
        expect(
          controller.viewedLocation!.calculation.highLatitudeRule,
          HighLatitudeRule.seventhOfNight,
        );
      },
    );
  }
  testWidgets(
    'rename validation and active deletion require explicit confirmation',
    (tester) async {
      final store = Store();
      final c = placeController(store);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
      });
      await c.initialize();
      await addPlace(c, 'Home');
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPrayerLocations(context, c),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), ' ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.writes, 1);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Work');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(c.viewedLocation!.label, 'Work');
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete location'));
      await tester.pumpAndSettle();
      expect(c.state.locations, hasLength(1));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.state.locations, hasLength(1));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete and turn off reminders'));
      await tester.pumpAndSettle();
      expect(c.state.locations, isEmpty);
      expect(c.state.reminders.anyEnabled, isFalse);
    },
  );
  test('all five methods, four labels and both high latitude rules persist per place', () async {
    final store = Store();
    final subject = placeController(store);
    addTearDown(subject.dispose);
    await subject.initialize();
    final home = await addPlace(subject, 'Home');
    final second = await addPlace(subject, 'Work');
    for (final method in PrayerMethod.values) {
      for (final madhhab in PrayerMadhhab.values) {
        for (final rule in HighLatitudeRule.values) {
          final previous = subject.state.generation;
          await subject.updateCalculation(
            second,
            CalculationPreferences(
              method: method,
              madhhab: madhhab,
              highLatitudeRule: rule,
            ),
          );
          expect(subject.failure, isNull);
          expect(
            subject.viewedLocation!.calculation.asrFactor,
            madhhab == PrayerMadhhab.hanafi ? 2 : 1,
          );
          expect(subject.schedule!.locationId, second);
          expect(subject.state.activeLocationId, home);
          expect(subject.state.generation, greaterThanOrEqualTo(previous));
        }
      }
    }
    final restarted = placeController(store);
    addTearDown(restarted.dispose);
    await restarted.initialize();
    final saved = restarted.state.locations.last.calculation;
    expect(saved.method, PrayerMethod.northAmerica);
    expect(saved.madhhab, PrayerMadhhab.hanbali);
    expect(saved.highLatitudeRule, HighLatitudeRule.seventhOfNight);
    expect(
      restarted.state.locations.first.calculation.method,
      PrayerMethod.egyptian,
    );
  });
  test(
    'regional suggestions are overridable; invalid convention never commits',
    () async {
      expect(
        [
          'EG',
          'SA',
          'PK',
          'BD',
          'US',
          'CA',
          'AU',
        ].map(CalculationPreferences.suggestion),
        [
          PrayerMethod.egyptian,
          PrayerMethod.ummAlQura,
          PrayerMethod.karachi,
          PrayerMethod.karachi,
          PrayerMethod.northAmerica,
          PrayerMethod.northAmerica,
          PrayerMethod.muslimWorldLeague,
        ],
      );
      final store = Store();
      final c = placeController(store);
      addTearDown(c.dispose);
      await c.initialize();
      final id = await addPlace(c, 'Home');
      expect(c.viewedLocation!.calculation.madhhab, PrayerMadhhab.shafii);
      expect(
        c.viewedLocation!.calculation.highLatitudeRule,
        HighLatitudeRule.middleOfNight,
      );
      await c.updateCalculation(
        id,
        const CalculationPreferences(
          method: PrayerMethod.karachi,
          madhhab: PrayerMadhhab.maliki,
        ),
      );
      final raw = store.data, generation = c.state.generation;
      await c.updateCalculation(
        id,
        const CalculationPreferences(conventionVersion: 999),
      );
      expect(c.failure, PrayerFailure.needsAttention);
      expect(store.data, raw);
      expect(c.state.generation, generation);
      await c.detect('en');
      expect(c.viewedLocation!.calculation.madhhab, PrayerMadhhab.maliki);
    },
  );
}
