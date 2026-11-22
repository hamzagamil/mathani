import 'package:flutter/services.dart';

/// The `app.mathani/widgets` channel (specs/017 contracts/widget-snapshot.md). A missing or
/// failing native side never reaches the reader.
class HomeWidgets {
  const HomeWidgets();
  static const _channel = MethodChannel('app.mathani/widgets');

  /// Stores [snapshot] for the phone's widgets and sends [watch] to a paired watch.
  Future<void> update(String snapshot, String watch) async {
    try {
      await _channel.invokeMethod<void>('update', {'snapshot': snapshot, 'watch': watch});
    } on MissingPluginException {
      /* tests, or a platform without widgets */
    } on PlatformException {
      /* the next change sends again */
    }
  }

  /// Kinds of Mathani widgets on the phone now: `prayer`, `quran`, `khatma`.
  Future<List<String>> placed() async {
    try {
      return (await _channel.invokeListMethod<String>('placed')) ?? const [];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// Back to the "not set up" state, after the app's data is reset.
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      /* nothing to clear */
    } on PlatformException {
      /* nothing to clear */
    }
  }
}
