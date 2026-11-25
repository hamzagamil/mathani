import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../features/analytics/usage.dart';
import 'firebase_app.dart';

enum _State { waiting, on, off }

/// Usage statistics through Firebase Analytics on phones and the web (specs/016 research R1, R2,
/// R7, R8). The only file that talks to the analytics library.
class FirebaseUsage implements UsageSink {
  FirebaseUsage();

  /// Collection in debug or profile builds, for DebugView checks (quickstart Manual 2).
  static const _debug = bool.fromEnvironment('USAGE_DEBUG');
  static const _maxQueued = 50;

  /// The web sends this instead of the page's address, which can hold a group khatma code.
  static const _webLocation = 'https://get.mthani.app/';

  /// The web app's production addresses, the only ones that collect (FR-013).
  static const _webHosts = {'get.mthani.app', 'read.mthani.app'};

  final _queue = <void Function(FirebaseAnalytics)>[];
  var _state = _State.waiting;
  FirebaseAnalytics? _analytics;

  @override
  void screen(String name) =>
      _add((a) => a.logScreenView(screenName: name, screenClass: name));

  @override
  void event(String name, Map<String, Object> parameters) =>
      _add((a) => a.logEvent(name: name, parameters: parameters));

  void _add(Future<void> Function(FirebaseAnalytics) send) {
    switch (_state) {
      case _State.waiting:
        _queue.add((a) => _fire(send, a));
        if (_queue.length > _maxQueued) _queue.removeAt(0);
      case _State.on:
        _fire(send, _analytics!);
      case _State.off:
        break;
    }
  }

  void _fire(Future<void> Function(FirebaseAnalytics) send, FirebaseAnalytics a) {
    unawaited(send(a).catchError((Object e) {
      if (kDebugMode) debugPrint('Usage not sent: $e');
    }));
  }

  /// After the first frame (FR-019). Collection is on only in release builds, and on the web
  /// only on the production hosts (FR-013); the native default is off, so other builds send nothing.
  Future<void> start() async {
    if (_state != _State.waiting) return;
    final wanted = (kReleaseMode || _debug) && (!kIsWeb || _webHosts.contains(Uri.base.host));
    // On the web, starting the library at all sends a hit, so it is left alone when unwanted.
    if ((kIsWeb && !wanted) || !await firebaseReady()) return _stop();
    try {
      final analytics = kIsWeb
          ? FirebaseAnalytics.instanceFor(
              app: Firebase.app(),
              webOptions: const {
                'config': {
                  'send_page_view': false,
                  'page_location': _webLocation,
                  'page_referrer': '',
                },
              },
            )
          : FirebaseAnalytics.instance;
      await analytics.setAnalyticsCollectionEnabled(wanted);
      if (!wanted) return _stop();
      _analytics = analytics;
      _state = _State.on;
      for (final send in _queue) {
        send(analytics);
      }
      _queue.clear();
    } on Object catch (e) {
      if (kDebugMode) debugPrint('Usage unavailable: $e');
      _stop();
    }
  }

  void _stop() {
    _state = _State.off;
    _queue.clear();
  }
}
