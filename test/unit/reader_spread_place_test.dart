import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

/// The reader's page while two facing pages show (specs/012 FR-010, data-model.md › Reader's
/// page): kept when on the spread, else the selected or highlighted ayah's page on it, else the
/// right-hand page.
void main() {
  late ReaderController reader;
  late int notified;

  Future<void> open(WidgetTester tester, int page) async {
    reader = (await tester.runAsync(openTestReader))!;
    reader.jumpToPage(page);
    notified = 0;
    reader.addListener(() => notified++);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1)); // the scheduled save
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  }

  testWidgets('a page already on the spread is kept, with no notification', (tester) async {
    await open(tester, 50);
    final anchor = reader.anchor;
    reader.onMushafSpreadShown(49);
    expect(reader.page, 50);
    expect(reader.anchor, anchor);
    expect(notified, 0);
    reader.onMushafSpreadShown(50 - 1);
    expect(notified, 0);
    await close(tester);
  });

  testWidgets('a new spread: the right-hand page and its first ayah', (tester) async {
    await open(tester, 50);
    reader.onMushafSpreadShown(51);
    expect(reader.page, 51);
    expect(reader.anchor, reader.quran.firstAyahOnPage(51).ref);
    expect(notified, 1);
    await close(tester);
  });

  testWidgets('the selected ayah on the new spread holds the place', (tester) async {
    await open(tester, 50);
    final onLeft = reader.quran.firstAyahOnPage(52).ref;
    reader.select(onLeft);
    reader.onMushafSpreadShown(51);
    expect(reader.page, 52);
    expect(reader.anchor, onLeft);
    await close(tester);
  });

  testWidgets('a highlighted ayah elsewhere does not', (tester) async {
    await open(tester, 50);
    reader.jumpTo(reader.quran.firstAyahOnPage(10).ref); // highlighted, on page 10
    reader.onMushafSpreadShown(51);
    expect(reader.page, 51);
    expect(reader.anchor, reader.quran.firstAyahOnPage(51).ref);
    await tester.pump(ReaderController.highlightDuration);
    await close(tester);
  });

  testWidgets('the place is saved after a turn', (tester) async {
    await open(tester, 50);
    reader.onMushafSpreadShown(101);
    await close(tester);
    final (anchor, _) = (await tester.runAsync(reader.user.loadStartup))!;
    expect(anchor, reader.quran.firstAyahOnPage(101).ref);
  });
}
