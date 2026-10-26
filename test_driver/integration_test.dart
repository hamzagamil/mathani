// Runs integration_test/ in a browser (specs/008 T038):
//   flutter drive -d web-server --driver test_driver/integration_test.dart \
//     --target integration_test/app_flow_test.dart
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
