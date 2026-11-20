// Placeholder until the owner runs `flutterfire configure` for Android and iOS, which replaces
// this file with the project's options (specs/015 research R6, R11). Until then announcements
// stay inactive: `currentPlatform` throws, as the generated file does for a platform that is
// not configured, and the app carries on without them.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase is not configured: run `flutterfire configure` (specs/015 quickstart).',
  );
}
