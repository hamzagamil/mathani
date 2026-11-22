import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/analytics/usage.dart';
import 'package:mathani/features/prayer_times/prayer_models.dart';

class FakeSink implements UsageSink {
  final screens = <String>[];
  /// `[name, parameters]`, so the matcher compares the maps' contents.
  final events = <List<Object>>[];

  @override
  void screen(String name) => screens.add(name);

  @override
  void event(String name, Map<String, Object> parameters) => events.add([name, parameters]);
}

final _wire = RegExp(r'^[a-z][a-z0-9_]{0,39}$');

void main() {
  late FakeSink sink;
  setUp(() => Usage.sink = sink = FakeSink());
  tearDown(() => Usage.sink = const NoUsage());

  test('every screen, setting and action name is short snake_case and unique', () {
    final screens = UsageScreen.values.map((s) => s.wire).toList();
    final settings = UsageSetting.values.map((s) => s.wire).toList();
    for (final n in [...screens, ...settings, ...Usage.actions]) {
      expect(n, matches(_wire));
    }
    expect(screens.toSet(), hasLength(screens.length));
    expect(settings.toSet(), hasLength(settings.length));
  });

  test('actions send only their listed parameters', () {
    Usage.recitationStarted(reciter: 'husary');
    Usage.memorizationStarted(PrayerKind.fajr); // any enum: its name only
    Usage.prayerAlertChanged(PrayerKind.duha, on: true);
    Usage.announcementOpened(hasLink: false);
    Usage.groupKhatmaStarted(parts: 30);
    Usage.search();
    expect(sink.events, [
      ['recitation_started', {'reciter': 'husary'}],
      ['memorization_started', {'outcome': 'fajr'}],
      ['prayer_alert_changed', {'prayer': 'duha', 'on': 'true'}],
      ['announcement_opened', {'has_link': 'false'}],
      ['group_khatma_started', {'parts': 30}],
      ['search', <String, Object>{}],
    ]);
    for (final [name, _] in sink.events) {
      expect(Usage.actions, contains(name));
    }
  });

  test('widgets_present names only known kinds, sorted (specs/017 SC-007)', () {
    Usage.widgetsPresent(['quran', 'prayer', 'quran']);
    Usage.widgetsPresent(const []);
    Usage.widgetsPresent(['Cairo', 'khatma']);
    expect(sink.events, [
      ['widgets_present', {'kinds': 'prayer,quran', 'surface': 'phone'}],
      ['widgets_present', {'kinds': 'none', 'surface': 'phone'}],
      ['widgets_present', {'kinds': 'khatma', 'surface': 'phone'}],
    ]);
    expect(Usage.actions, contains('widgets_present'));
  });

  test('a settings change logs exactly the changed fields', () {
    const before = ReaderPreferences();
    final after = before.copyWith(theme: ThemePref.night, flowFontSize: 26, twoPages: !before.twoPages);
    Usage.preferencesChanged(before, after);
    expect(sink.events, [
      ['setting_changed', {'setting': 'theme', 'value': 'night'}],
      ['setting_changed', {'setting': 'font_size', 'value': 26}],
      ['setting_changed', {'setting': 'two_pages', 'value': '${!before.twoPages}'}],
    ]);
    sink.events.clear();
    Usage.preferencesChanged(after, after);
    expect(sink.events, isEmpty);
  });

  test('internal flags are not settings', () {
    const before = ReaderPreferences();
    Usage.preferencesChanged(before, before.copyWith(onboardingDone: true, similarIntroSeen: true));
    expect(sink.events, isEmpty);
  });

  test('free text is refused; catalogue ids only for the reciter and athan sound', () {
    Usage.settingChanged(UsageSetting.theme, 'any text'); // refused, not sent, never throws
    Usage.settingChanged(UsageSetting.reciter, 'minshawi');
    expect(sink.events, [
      ['setting_changed', {'setting': 'reciter', 'value': 'minshawi'}],
    ]);
  });

  testWidgets('screens report when pushed and when a page above them is popped, not a sheet', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      navigatorObservers: [usageRouteObserver],
      home: const TrackedScreen(UsageScreen.reader, child: SizedBox()),
    ));
    expect(sink.screens, ['reader']);
    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const TrackedScreen(UsageScreen.settings, child: SizedBox()),
    ));
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(sink.screens, ['reader', 'settings', 'reader']);
    unawaited(showModalBottomSheet<void>(
      context: nav.currentContext!,
      builder: (_) => const SizedBox(height: 10),
    ));
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(sink.screens, ['reader', 'settings', 'reader']);
  });
}

void unawaited(Future<void> f) {}
