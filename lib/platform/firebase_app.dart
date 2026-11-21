import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

Future<bool>? _ready;

/// Starts Firebase once, for announcements (specs/015) and usage statistics (specs/016 research
/// R7): two concurrent `initializeApp` calls would fail. False when the platform is not
/// configured or Firebase cannot start (offline web, blocked script); tried again on the next
/// call.
Future<bool> firebaseReady() async {
  final ok = await (_ready ??= _start());
  if (!ok) _ready = null;
  return ok;
}

Future<bool> _start() async {
  final FirebaseOptions options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    return false;
  }
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    return true;
  } on Object catch (e) {
    if (kDebugMode) debugPrint('Firebase unavailable: $e');
    return false;
  }
}
