// Frame performance while paging and scrolling (task T064, constitution III, SC-002).
// Profile mode on a reference device:
//   flutter drive --profile --driver=test_driver/perf_driver.dart \
//     --target=integration_test/paging_perf_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/data/quran_repository.dart';
import 'package:mathani/data/user_repository.dart';
import 'package:mathani/shared/reader_state.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('page through 50 Mushaf pages, then scroll the flowing layout', (tester) async {
    final (quran, user) = await (QuranRepository.open(), UserRepository.open()).wait;
    final (_, prefs) = await user.loadStartup();
    final reader = ReaderController(
      quran: quran,
      user: user,
      anchor: const AyahRef(2, 1),
      preferences: prefs.copyWith(layout: ReadingLayout.mushaf),
    );
    await tester.pumpWidget(MathaniApp(controller: reader));
    await tester.pumpAndSettle();

    await binding.watchPerformance(() async {
      for (var i = 0; i < 50; i++) {
        await tester.fling(find.byType(PageView), const Offset(400, 0), 1500);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'mushaf_paging');

    reader.updatePreferences(reader.preferences.copyWith(layout: ReadingLayout.flowing));
    await tester.pumpAndSettle();
    await binding.watchPerformance(() async {
      for (var i = 0; i < 20; i++) {
        await tester.fling(find.byType(CustomScrollView), const Offset(0, -600), 3000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'flowing_scroll');
  });
}
