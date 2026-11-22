import 'package:flutter/widgets.dart';

import '../../data/models.dart';

/// Usage statistics (specs/016): the allowed-events list. Every screen, action and parameter the
/// app sends is defined in this file (contracts/usage-events.md); nothing else is ever sent.
/// No method takes free text, a page, an ayah, a place or anything a reader typed (FR-004,
/// FR-009). String values are only catalogue ids (reciters, athan sounds).
abstract interface class UsageSink {
  void screen(String name);
  void event(String name, Map<String, Object> parameters);
}

/// Tests, and every build until main installs the real sink.
class NoUsage implements UsageSink {
  const NoUsage();
  @override
  void screen(String name) {}
  @override
  void event(String name, Map<String, Object> parameters) {}
}

/// The screens reported as `screen_view` (FR-002).
enum UsageScreen {
  reader('reader'),
  surahIndex('index'),
  search('search'),
  settings('settings'),
  prayerTimes('prayer_times'),
  khatma('khatma'),
  wirdList('wird_list'),
  khatmaComplete('khatma_complete'),
  groupKhatma('group_khatma'),
  downloads('downloads'),
  memorizationResult('memorization_result'),
  onboarding('onboarding'),
  mutashabihat('mutashabihat'),
  reciters('reciters');

  const UsageScreen(this.wire);
  final String wire;
}

/// The settings reported by `setting_changed`.
enum UsageSetting {
  layout('layout'),
  theme('theme'),
  fontSize('font_size'),
  keepScreenOn('keep_screen_on'),
  language('language'),
  lettering('lettering'),
  reciter('reciter'),
  mistakeSignal('mistake_signal'),
  twoPages('two_pages'),
  announcements('announcements'),
  prayerMethod('prayer_method'),
  asr('asr'),
  highLatitude('high_latitude'),
  athanSound('athan_sound'),
  athanLength('athan_length');

  const UsageSetting(this.wire);
  final String wire;
}

/// The only way to report usage. Calls are fire-and-forget and never throw.
abstract final class Usage {
  static UsageSink sink = const NoUsage();

  /// Every action name, for the tests.
  static const actions = {
    'recitation_started',
    'surah_download_started',
    'memorization_started',
    'search',
    'bookmark_added',
    'khatma_started',
    'wird_completed',
    'group_khatma_started',
    'group_khatma_joined',
    'prayer_alert_changed',
    'announcement_opened',
    'onboarding_completed',
    'setting_changed',
    'widgets_present',
  };

  /// Widget kinds `widgets_present` may name (specs/017 contracts/widget-surfaces.md › Usage).
  static const widgetKinds = {'prayer', 'quran', 'khatma'};

  static void screen(UsageScreen screen) => _safe(() => sink.screen(screen.wire));

  static void recitationStarted({required String reciter}) =>
      _event('recitation_started', {'reciter': reciter});

  static void surahDownloadStarted({required String reciter}) =>
      _event('surah_download_started', {'reciter': reciter});

  /// [outcome] is the start outcome (started, unsupported, no microphone…).
  static void memorizationStarted(Enum outcome) =>
      _event('memorization_started', {'outcome': outcome.name});

  static void search() => _event('search', const {});
  static void bookmarkAdded() => _event('bookmark_added', const {});
  static void khatmaStarted() => _event('khatma_started', const {});
  static void wirdCompleted() => _event('wird_completed', const {});

  /// [parts] is the group's division (30, 60…), not a part number.
  static void groupKhatmaStarted({required int parts}) =>
      _event('group_khatma_started', {'parts': parts});

  static void groupKhatmaJoined() => _event('group_khatma_joined', const {});

  /// [prayer] is a prayer or reminder kind (fajr … duha).
  static void prayerAlertChanged(Enum prayer, {required bool on}) =>
      _event('prayer_alert_changed', {'prayer': prayer.name, 'on': '$on'});

  static void announcementOpened({required bool hasLink}) =>
      _event('announcement_opened', {'has_link': '$hasLink'});

  static void onboardingCompleted() => _event('onboarding_completed', const {});

  /// Which kinds of Mathani widgets are on the phone (specs/017 SC-007): a sorted list of known
  /// kinds, or `none`. Anything else is dropped.
  static void widgetsPresent(Iterable<String> kinds) {
    final known = kinds.where(widgetKinds.contains).toSet().toList()..sort();
    _event('widgets_present', {
      'kinds': known.isEmpty ? 'none' : known.join(','),
      'surface': 'phone',
    });
  }

  /// [value] is an enum (its name), a bool, an int, or a catalogue id for [UsageSetting.reciter]
  /// and [UsageSetting.athanSound].
  static void settingChanged(UsageSetting setting, Object value) {
    final Object? wire = switch (value) {
      Enum() => value.name,
      bool() => '$value',
      int() => value,
      String() when setting == UsageSetting.reciter || setting == UsageSetting.athanSound => value,
      _ => null, // anything else could be free text: never sent
    };
    if (wire == null) {
      debugPrint('Usage: a value of this type is not allowed for ${setting.wire}');
      return;
    }
    _event('setting_changed', {'setting': setting.wire, 'value': wire});
  }

  /// One `setting_changed` per reader setting that differs (research R6).
  static void preferencesChanged(ReaderPreferences before, ReaderPreferences after) {
    void check(UsageSetting s, Object a, Object b) {
      if (a != b) settingChanged(s, b);
    }

    check(UsageSetting.layout, before.layout, after.layout);
    check(UsageSetting.theme, before.theme, after.theme);
    check(UsageSetting.fontSize, before.flowFontSize, after.flowFontSize);
    check(UsageSetting.keepScreenOn, before.keepScreenOn, after.keepScreenOn);
    check(UsageSetting.language, before.language, after.language);
    check(UsageSetting.lettering, before.lettering, after.lettering);
    check(UsageSetting.reciter, before.reciter, after.reciter);
    check(UsageSetting.mistakeSignal, before.mistakeSignal, after.mistakeSignal);
    check(UsageSetting.twoPages, before.twoPages, after.twoPages);
    check(UsageSetting.announcements, before.announcements, after.announcements);
  }

  static void _event(String name, Map<String, Object> parameters) =>
      _safe(() => sink.event(name, parameters));

  static void _safe(void Function() f) {
    try {
      f();
    } on Object catch (e) {
      debugPrint('Usage: $e');
    }
  }
}

/// Reports `screen_view` for a tracked screen when its route is pushed and when it is visible
/// again after a page above it is popped (research R4).
final RouteObserver<ModalRoute<Object?>> usageRouteObserver = _UsageRouteObserver();

class _UsageRouteObserver extends RouteObserver<ModalRoute<Object?>> {
  /// Closing a sheet or a dialog does not count as a new view of the screen below.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) super.didPop(route, previousRoute);
  }
}

/// [ScreenTracking] for a stateless screen: wraps what its build returns.
class TrackedScreen extends StatefulWidget {
  const TrackedScreen(this.screen, {super.key, required this.child});
  final UsageScreen screen;
  final Widget child;

  @override
  State<TrackedScreen> createState() => _TrackedScreenState();
}

class _TrackedScreenState extends State<TrackedScreen> with ScreenTracking<TrackedScreen> {
  @override
  UsageScreen get usageScreen => widget.screen;

  @override
  Widget build(BuildContext context) => widget.child;
}

mixin ScreenTracking<T extends StatefulWidget> on State<T> implements RouteAware {
  UsageScreen get usageScreen;

  ModalRoute<Object?>? _usageRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || identical(route, _usageRoute)) return;
    if (_usageRoute != null) usageRouteObserver.unsubscribe(this);
    _usageRoute = route;
    usageRouteObserver.subscribe(this, route); // calls didPush
  }

  @override
  void dispose() {
    usageRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() => Usage.screen(usageScreen);

  @override
  void didPopNext() => Usage.screen(usageScreen);

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}
