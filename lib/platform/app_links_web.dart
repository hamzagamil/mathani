import 'package:web/web.dart' as web;

import '../features/khatma/group/group_link_host.dart';

/// Group khatma links in browsers (specs/014 research R16): Pages serves the app for /k/<code>;
/// the app reads the code from its address once, then sets the address back to /.
class AppLinks implements LinkSource {
  AppLinks._();
  static final instance = AppLinks._();
  bool _taken = false;

  @override
  Future<String?> takeLink() async {
    if (_taken) return null;
    _taken = true;
    final location = web.window.location;
    if (!location.pathname.startsWith('/k/')) return null;
    final link = location.href;
    web.window.history.replaceState(null, '', '/');
    return link;
  }

  @override
  Stream<String> get links => const Stream.empty();
}
