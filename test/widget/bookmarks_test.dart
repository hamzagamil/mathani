// US3 bookmarks (quickstart scenario 6).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/data/user_repository.dart';
import 'package:mathani/shared/mathani_icons.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  testWidgets('three bookmarks (one twice), persisted, newest first; open and delete',
      (tester) async {
    late ReaderController reader;
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
      await reader.user.addBookmark(const AyahRef(2, 255), 42);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await reader.user.addBookmark(const AyahRef(18, 1), 293);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await reader.user.addBookmark(const AyahRef(2, 255), 42); // duplicate: no-op
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await reader.user.addBookmark(const AyahRef(36, 1), 440);
    });
    expect(reader.user.bookmarks.map((b) => b.ref),
        [const AyahRef(36, 1), const AyahRef(18, 1), const AyahRef(2, 255)]);

    // "Restart": a new repository on the same database sees the same bookmarks.
    final reopened = await tester.runAsync(UserRepository.open);
    expect(reopened!.bookmarks.length, 3);

    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MathaniApp(controller: reader));
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await settle();
    await tapToolbar(tester, MathaniIcons.index);
    await settle();
    await tester.tap(find.text('Bookmarks'));
    await settle();
    expect(find.byIcon(MathaniIcons.bookmarked), findsNWidgets(3));

    await tester.tap(find.byIcon(MathaniIcons.delete).first); // removes 36:1 (newest)
    await settle();
    expect(reader.user.bookmarks.length, 2);

    await tester.tap(find.textContaining('ayah 1')); // Al-Kahf 18:1
    await settle();
    expect(reader.anchor, const AyahRef(18, 1));

    // The header toggle shows this page as bookmarked, and removes it.
    expect(find.byIcon(MathaniIcons.bookmarked), findsOneWidget);
    await tapToolbar(tester, MathaniIcons.bookmarked);
    await settle();
    expect(reader.user.bookmarks.map((b) => b.ref), [const AyahRef(2, 255)]);
  });
}
