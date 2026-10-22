// Driver for integration_test/store_screenshots_test.dart: saves each screenshot as
// build/screenshots/<name>.png.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final file = File('build/screenshots/$name.png')..createSync(recursive: true);
        file.writeAsBytesSync(bytes);
        return true;
      },
    );
