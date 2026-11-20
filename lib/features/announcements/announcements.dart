import 'dart:async';

import 'package:flutter/foundation.dart';

/// Push messages on each platform (specs/015 contracts/announcements.md).
abstract interface class AnnouncementsPlatform {
  /// Starts the push service; false when it is unavailable (web, desktop, not configured, or
  /// it failed). Safe to call more than once.
  Future<bool> start();
  Future<void> subscribe(Set<String> topics);
  Future<void> unsubscribe(Set<String> topics);

  /// Asks for notification permission if it was never asked.
  Future<void> requestPermission();

  /// The `link` of each tapped announcement, including the one that launched the app.
  Stream<String> get openedLinks;
}

/// No push service: web, desktop and tests.
class NoAnnouncements implements AnnouncementsPlatform {
  const NoAnnouncements();
  @override
  Future<bool> start() async => false;
  @override
  Future<void> subscribe(Set<String> topics) async {}
  @override
  Future<void> unsubscribe(Set<String> topics) async {}
  @override
  Future<void> requestPermission() async {}
  @override
  Stream<String> get openedLinks => const Stream.empty();
}

/// The hosts whose links an announcement may open, as for Universal Links and App Links.
const announcementLinkHosts = {
  'mthani.app',
  'www.mthani.app',
  'get.mthani.app',
};

/// A Mathani link, or null: anything else only opens the app (research R8).
String? mathaniLink(String? raw) {
  final uri = raw == null ? null : Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'https') return null;
  return announcementLinkHosts.contains(uri.host.toLowerCase())
      ? uri.toString()
      : null;
}

/// Keeps the topic subscriptions in line with the Announcements setting and the app's
/// language (research R7), and hands tapped Mathani links on. Idle until [start], which runs
/// after the first frame (Principle III).
class Announcements {
  Announcements({
    required this.platform,
    required this.enabled,
    required this.language,
    required this.readTopics,
    required this.writeTopics,
    required this.onLink,
  });

  final AnnouncementsPlatform platform;
  final bool Function() enabled;

  /// `ar` or `en`: the app's language as shown.
  final String Function() language;

  /// The topics last subscribed to, kept so that turning the setting off, or a language change
  /// between launches, unsubscribes the old ones.
  final Future<String?> Function() readTopics;
  final Future<void> Function(String topics) writeTopics;
  final void Function(String link) onLink;

  static const all = 'all';
  static const languageTopics = {'lang_ar', 'lang_en'};

  bool? _wasEnabled;
  String? _wasLanguage;
  Future<void>? _sync;
  bool _again = false;
  StreamSubscription<String>? _links;

  Set<String> get _wanted => enabled() ? {all, 'lang_${language()}'} : const {};

  Future<void> start() {
    _wasEnabled = enabled();
    _wasLanguage = language();
    return sync();
  }

  /// Call on every reader change; acts only when the setting or the language changed. Turning
  /// the setting on asks for permission (FR-016: never at start-up).
  void preferencesChanged() {
    final was = _wasEnabled;
    if (was == null) return; // not started yet
    final now = enabled(), lang = language();
    if (now == was && lang == _wasLanguage) return;
    _wasEnabled = now;
    _wasLanguage = lang;
    if (!was && now) {
      unawaited(platform.requestPermission().catchError((Object _) {}));
    }
    unawaited(sync());
  }

  /// Merged when calls overlap; failures are retried on the next call.
  Future<void> sync() {
    if (_sync != null) {
      _again = true;
      return _sync!;
    }
    return _sync = () async {
      try {
        do {
          _again = false;
          await _syncOnce();
        } while (_again);
      } on Object catch (e) {
        if (kDebugMode) debugPrint('Announcements: $e');
      } finally {
        _sync = null;
      }
    }();
  }

  Future<void> _syncOnce() async {
    final wanted = _wanted;
    final stored = _parse(await readTopics());
    if (wanted.isEmpty && stored.isEmpty) return;
    if (!await platform.start()) return;
    _links ??= platform.openedLinks.listen((raw) {
      final link = mathaniLink(raw);
      if (link != null) onLink(link);
    });
    final stale = stored.difference(wanted);
    if (stale.isNotEmpty) await platform.unsubscribe(stale);
    // Every start, so a refreshed token keeps its topics; subscribing twice is harmless.
    if (wanted.isNotEmpty) await platform.subscribe(wanted);
    await writeTopics((wanted.toList()..sort()).join(','));
  }

  static Set<String> _parse(String? raw) => {
    for (final t in (raw ?? '').split(','))
      if (t == all || languageTopics.contains(t)) t,
  };
}
