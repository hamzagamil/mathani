import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/onboarding/onboarding_controller.dart';
import 'package:mathani/features/onboarding/onboarding_steps.dart';
import 'package:mathani/shared/reader_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/harness.dart';

/// Readers updating from 1.3.0: they see the onboarding once, and keep everything (specs/005
/// SC-009, research R2).
void main() {
  testWidgets('a 1.3.0 database: onboarding once, with the saved choices, and nothing lost',
      (tester) async {
    final reader = (await tester.runAsync(() => openTestReader(onboarded: false)))!;
    // Leave user.db as 1.3.0 would: preferences without onboarding_done, a stale hint flag, a
    // reading position on Al-Mulk and a bookmark.
    final (anchor, prefs) = (await tester.runAsync(() async {
      final db = await openDatabase('${await getDatabasesPath()}/user.db');
      await db.delete('preferences');
      for (final (k, v) in [
        ('theme', 'night'),
        ('reciter', 'minshawy'),
        ('layout', 'mushaf'),
        ('controls_hint_shown', 'true'),
      ]) {
        await db.insert('preferences', {'key': k, 'value': v});
      }
      await reader.user.saveAnchor(const AyahRef(67, 1));
      await reader.user.addBookmark(const AyahRef(67, 1), 562);
      return reader.user.loadStartup();
    }))!;
    expect(prefs.onboardingDone, isFalse, reason: 'no row yet: the onboarding shows');
    expect(prefs.theme, ThemePref.night);
    expect(prefs.reciter, 'minshawy');

    final updated =
        ReaderController(quran: reader.quran, user: reader.user, anchor: anchor, preferences: prefs);
    final onboarding = OnboardingController(reader: updated);
    expect(onboarding.step, OnboardingStep.language);
    expect(updated.page, 562);

    onboarding.skip();
    expect(updated.preferences.onboardingDone, isTrue);
    expect(updated.preferences.theme, ThemePref.night);
    expect(updated.preferences.reciter, 'minshawy');
    expect(updated.anchor, const AyahRef(67, 1));
    expect(updated.page, 562);
    expect(reader.user.bookmarks.single.ref, const AyahRef(67, 1));

    final (_, saved) = (await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return reader.user.loadStartup();
    }))!;
    expect(saved.onboardingDone, isTrue, reason: 'never again');

    onboarding.dispose();
    await tester.runAsync(() async {
      updated.didChangeAppLifecycleState(AppLifecycleState.paused);
      reader.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    updated.dispose();
    await tester.pump(const Duration(seconds: 2));
  });
}
