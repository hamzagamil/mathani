// The recited ayah is highlighted in the Mushaf (both letterings) and the flowing layout, and
// the basmala line when the basmala is recited (specs/004 FR-012, contracts/recitation-playback
// › Highlight).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/app/theme/app_theme.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/reader/mushaf_page_renderer.dart';
import 'package:mathani/features/recitation/recitation_controller.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/fake_recitation.dart';
import '../support/harness.dart';

void main() {
  late ReaderController reader;
  late RecitationController recitation;

  Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> pumpApp(WidgetTester tester, {required Lettering lettering}) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader();
      await reader.quran.basmalaPageOf(2, printed: true);
      await reader.quran.basmalaPageOf(2, printed: false);
    });
    reader.updatePreferences(
        reader.preferences.copyWith(language: LanguagePref.ar, lettering: lettering));
    (recitation, _, _) = openTestRecitation(reader);
    tester.view.physicalSize = const Size(780, 1690);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MathaniApp(controller: reader, recitation: recitation));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await recitation.stop();
    await settle(tester, 2);
    await tester.pumpWidget(const SizedBox());
    recitation.dispose();
    await tester.pump(const Duration(seconds: 2));
  }

  /// The renderer of the page on screen.
  MushafPageRenderer pageRenderer(WidgetTester tester) => tester
      .widgetList<MushafPageRenderer>(find.byType(MushafPageRenderer))
      .firstWhere((r) => r.page.number == reader.page);

  RenderMushafPage pageRender(WidgetTester tester) => find
      .byType(MushafPageRenderer)
      .evaluate()
      .firstWhere((e) => (e.widget as MushafPageRenderer).page.number == reader.page)
      .renderObject! as RenderMushafPage;

  /// A rounded rect painted in [color], after any other drawing.
  bool rrectIn(Color color, Symbol method, List<dynamic> args) =>
      method == #drawRRect && (args[1] as Paint).color.toARGB32() == color.toARGB32();

  for (final lettering in Lettering.values) {
    testWidgets('the recited ayah is painted behind its words (${lettering.name} lettering)',
        (tester) async {
      await pumpApp(tester, lettering: lettering);
      final colors = MathaniColors.forBrightness(Brightness.light);
      for (final ref in [const AyahRef(2, 3), const AyahRef(3, 1), const AyahRef(114, 6)]) {
        await tester.runAsync(() => recitation.playFrom(ref));
        await settle(tester);
        final item = recitation.recited!;
        expect(reader.page, item.isBasmala ? reader.page : reader.quran.pageOf(ref));
        final renderer = pageRenderer(tester);
        if (item.isBasmala) {
          expect(renderer.recitedBasmala, ref.surah);
          expect(renderer.recited, isNull);
        } else {
          expect(renderer.recited, ref);
          expect(renderer.recitedBasmala, isNull);
        }
        expect(renderer.palette.recited, colors.recited);
        expect(pageRender(tester), paints..something((m, a) => rrectIn(colors.recited, m, a)));
      }
      await finish(tester);
    });
  }

  testWidgets('the jump highlight and selection draw over the recited highlight', (tester) async {
    await pumpApp(tester, lettering: Lettering.builtin);
    await tester.runAsync(() => recitation.playFrom(const AyahRef(2, 5)));
    await settle(tester);
    reader.select(const AyahRef(2, 5));
    await settle(tester, 2);
    final colors = MathaniColors.forBrightness(Brightness.light);
    // Recited first, selection on top.
    expect(
        pageRender(tester),
        paints
          ..something((m, a) => rrectIn(colors.recited, m, a))
          ..something((m, a) => rrectIn(colors.selected, m, a)));
    reader.select(null);
    await finish(tester);
  });

  testWidgets('the flowing layout shades the recited ayah and the recited basmala row',
      (tester) async {
    await pumpApp(tester, lettering: Lettering.builtin);
    reader.updatePreferences(reader.preferences.copyWith(layout: ReadingLayout.flowing));
    await settle(tester);
    final colors = MathaniColors.forBrightness(Brightness.light);

    await tester.runAsync(() => recitation.playFrom(const AyahRef(67, 3)));
    await settle(tester);
    bool shaded(Color c) => tester.widgetList<RichText>(find.byType(RichText)).any((t) {
          var found = false;
          t.text.visitChildren((span) {
            if (span is TextSpan && span.style?.backgroundColor == c) found = true;
            return !found;
          });
          return found;
        });
    expect(shaded(colors.recited), isTrue);

    await tester.runAsync(() => recitation.playFrom(const AyahRef(67, 1)));
    await settle(tester);
    expect(
      tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).any((d) =>
          d.decoration is BoxDecoration && (d.decoration as BoxDecoration).color == colors.recited),
      isTrue,
      reason: 'the basmala row is shaded',
    );
    await finish(tester);
  });
}
