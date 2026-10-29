// Runs the same deterministic UI flows on a device/browser. These use scripted
// permission responses and a test store; physical permission/storage checks
// remain required in specs/009-prayer-times/validation/us1.md.
import 'package:integration_test/integration_test.dart';

import '../test/support/prayer_setup_scenarios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  prayerSetupScenarios();
}
