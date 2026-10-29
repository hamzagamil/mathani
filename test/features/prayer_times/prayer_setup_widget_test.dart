import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/prayer_times/prayer_calculator.dart';
import 'package:mathani/features/prayer_times/prayer_controller.dart';
import 'package:mathani/features/prayer_times/prayer_repository.dart';
import 'package:mathani/features/prayer_times/prayer_times_screen.dart';

import 'prayer_setup_test.dart' show Store, Locations;

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('setup remains usable at 320px and large text in $language', (
      tester,
    ) async {
      tester.view.resetPhysicalSize();
      await tester.binding.setSurfaceSize(const Size(320, 568));
      final calendar = jsonDecode(
        File('assets/prayer/ramadan_intervals.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final source = Locations();
      final c = PrayerController(
        repository: PrayerRepository(Store()),
        locationClient: source,
        calculator: PrayerCalculator(calendar),
        clock: () => DateTime.utc(2026, 10, 29, 12),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: PrayerTimesScreen(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        c.initialized,
        isTrue,
        reason: c.failure?.name ?? 'controller was not initialized',
      );
      expect(c.busy, isFalse);
      expect(source.accesses, 0);
      final label = language == 'en' ? 'Choose location' : 'اختيار الموقع';
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextField),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
      await tester.binding.setSurfaceSize(null);
    });
  }
}
