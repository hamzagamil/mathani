// specs/010 US2 in the flowing layout: a linked ayah is in the mutashabih colour, its end marker
// tells screen readers, and text positions (used by right-click, specs/008) do not move.
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathani/app/app.dart';
import 'package:mathani/app/theme/app_theme.dart';
import 'package:mathani/data/models.dart';
import 'package:mathani/features/mutashabihat/mutashabihat_content.dart';
import 'package:mathani/features/reader/flowing_view.dart';
import 'package:mathani/shared/reader_state.dart';

import '../support/harness.dart';

void main() {
  late ReaderController reader;

  Future<void> settle(WidgetTester tester, [int rounds = 10]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('a linked ayah is coloured and announced; positions are unchanged', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.runAsync(() async {
      await loadAppFonts();
      reader = await openTestReader(similar: parseMutashabihat('## 2:35 7:19\nشرح').$1);
    });
    reader.updatePreferences(
      reader.preferences.copyWith(language: LanguagePref.ar, layout: ReadingLayout.flowing),
    );
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MathaniApp(controller: reader));
    await settle(tester);
    reader.jumpTo(const AyahRef(2, 35), highlight: false);
    await settle(tester);

    final colors = MathaniColors.forBrightness(Brightness.light);
    final words35 = (await tester.runAsync(() => reader.quran.wordsOf(const AyahRef(2, 35))))!;
    final words36 = (await tester.runAsync(() => reader.quran.wordsOf(const AyahRef(2, 36))))!;
    final text35 = flowingAyahText(words35, reader.quran.font);
    final text36 = flowingAyahText(words36, reader.quran.font);

    // The paragraph holding 2:35. Plain text without semantics labels: what is laid out.
    final paragraph = tester
        .widgetList<RichText>(
          find.byWidgetPredicate((w) => w is RichText && w.textAlign == TextAlign.justify),
        )
        .firstWhere((r) => r.text.toPlainText(includeSemanticsLabels: false).contains(text35));
    final spans = (paragraph.text as TextSpan).children!.cast<TextSpan>();
    final linked = spans
        .where((s) => s.toPlainText(includeSemanticsLabels: false) == text35)
        .single;
    expect(linked.style?.color, colors.similar);
    final neighbour = spans
        .where((s) => s.toPlainText(includeSemanticsLabels: false) == text36)
        .single;
    expect(neighbour.style?.color, isNot(colors.similar));

    // The end marker's label is a node of the paragraph, not of a widget: walk the tree.
    final labels = <String>[];
    void collect(SemanticsNode n) {
      labels.add(n.label);
      n.visitChildren((c) {
        collect(c);
        return true;
      });
    }

    collect(tester.renderObject(find.byWidget(paragraph)).debugSemantics!);
    expect(labels.where((l) => l == 'الآية ٣٥، لها متشابه'), hasLength(1));
    expect(labels.where((l) => l.contains('لها متشابه')), hasLength(1), reason: 'only 2:35');

    // A right-click inside 2:36, just after the split span, still finds 2:36.
    final plain = paragraph.text.toPlainText(includeSemanticsLabels: false);
    final render = tester.renderObject<RenderParagraph>(find.byWidget(paragraph));
    final at = plain.indexOf(text36) + 4;
    final local =
        render.getOffsetForCaret(TextPosition(offset: at), Rect.zero) +
        Offset(0, render.preferredLineHeight / 2);
    await tester.tapAt(render.localToGlobal(local), buttons: kSecondaryButton);
    await settle(tester, 4);
    expect(reader.selected, const AyahRef(2, 36));
    semantics.dispose();
  });
}
