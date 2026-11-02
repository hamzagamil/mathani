// Prayer Times on a device (specs/009 T065): search → schedule → one alert with the tone →
// pending alerts → delete the place → none pending. Location, the place service and the alert
// platform are scripted, so this checks the app's flow on real hardware, not the OS permission
// prompts or delivery timing; those are the manual quickstart scenarios (validation/).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathani/app/l10n/app_localizations.dart';
import 'package:mathani/features/prayer_times/prayer_alerts.dart';
import 'package:mathani/features/prayer_times/prayer_controller.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';
import 'package:mathani/features/prayer_times/prayer_times_screen.dart';

import '../test/support/prayer_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search, schedule, one alert, delete', (tester) async {
    final h = Harness();
    final c = PrayerController(hub: h.hub, clock: () => h.clock);
    await c.initialize();
    await tester.pumpWidget(
      PrayerScope(
        alerts: h.hub,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: PrayerTimesScreen(controller: c),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Search for a city'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), 'Cairo');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cairo').last);
    await tester.pump(const Duration(seconds: 1));
    expect(c.state.currentPlace?.city, 'Cairo');
    expect(find.text('Fajr'), findsWidgets);

    await c.setPrayerAlert(PrayerKind.fajr, true);
    expect(h.alerts.pending, isNotEmpty);
    expect(h.alerts.pending.every((a) => a.sound == toneSound), isTrue);

    await c.deletePlace(c.state.places.single.id, alertsOff: true);
    expect(h.alerts.pending, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
