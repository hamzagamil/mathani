import 'dart:async';

import '../features/khatma/group/group_link_host.dart';

import 'package:flutter/services.dart';

/// Group khatma links on phones (specs/014 research R16): the native side reads Universal Links
/// and App Links and hands them over on the existing device channel.
class AppLinks implements LinkSource {
  AppLinks._();
  static final instance = AppLinks._();

  static const _channel = MethodChannel('app.mathani/device');
  final _links = StreamController<String>.broadcast();
  bool _listening = false;
  String? _pending;

  /// A link from inside the app: a tapped announcement (specs/015 research R8). Kept for
  /// [takeLink] if the link host is not listening yet, as after a launch from a notification.
  void deliver(String link) {
    if (_links.hasListener) {
      _links.add(link);
    } else {
      _pending = link;
    }
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'link' && call.arguments is String) _links.add(call.arguments as String);
    });
  }

  /// The link the app was opened with, once.
  @override
  Future<String?> takeLink() async {
    _listen();
    final pending = _pending;
    _pending = null;
    if (pending != null) return pending;
    try {
      return await _channel.invokeMethod<String>('takeLink');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Links that arrive while the app runs.
  @override
  Stream<String> get links {
    _listen();
    return _links.stream;
  }
}
