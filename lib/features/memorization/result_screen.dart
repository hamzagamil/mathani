// The result of a memorization session (specs/006 FR-023 to FR-026, contracts/memorization-ui.md
// › Result screen): the score, the counts and a review of the range. Never saved (FR-026).
import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/quran_text.dart';
import '../../shared/reader_state.dart';
import '../reader/flowing_view.dart' show flowingTextStyle;
import 'memorization_controller.dart';
import 'memorization_score.dart';
import 'recitation_matcher.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.controller, required this.range, required this.result});
  final MemorizationController controller;
  final MemorizationRange range;
  final SessionResult result;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<List<Word>>? _words;

  @override
  void initState() {
    super.initState();
    final quran = ReaderScope.read(context).quran;
    Future.wait([
      for (var a = widget.range.from; a <= widget.range.to; a++)
        quran.wordsOf(AyahRef(widget.range.surah, a)),
    ]).then((w) {
      if (mounted) setState(() => _words = w);
    });
  }

  /// Back to reading at the last page of the session (FR-025, US3-4).
  void _done() {
    final reader = ReaderScope.read(context);
    final reached = widget.result.review.lastIndexWhere((p) => p.outcome != AyahOutcome.notReached);
    final last = widget.range.refAt(reached < 0 ? 0 : reached);
    widget.controller.close();
    Navigator.of(context).pop();
    reader.jumpToPage(reader.quran.pageOf(last));
  }

  Future<void> _tryAgain() async {
    final controller = widget.controller;
    final range = widget.range;
    Navigator.of(context).pop();
    await controller.start(range);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    final result = widget.result;
    final score = result.score;
    String n(int v) => formatNumber(v, locale);
    final c = result.counts;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n.resultTitle),
          actions: [
            IconButton(icon: const Icon(MathaniIcons.close), tooltip: l10n.resultDone, onPressed: _done),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(Space.s4),
          children: [
            Semantics(
              label: score == null ? '—' : '${n(score)} ${l10n.resultOutOf}',
              excludeSemantics: true,
              child: Column(children: [
                Text(
                  score == null ? '—' : n(score),
                  style: TypeScale.display.copyWith(fontSize: 64, color: colors.accentInk),
                ),
                if (score != null)
                  Text(l10n.resultOutOf, style: TypeScale.body.copyWith(color: colors.inkMuted)),
              ]),
            ),
            const SizedBox(height: Space.s3),
            Text(
              [
                l10n.resultNoMistake(n(c[AyahOutcome.noMistake]!)),
                l10n.resultCorrected(n(c[AyahOutcome.corrected]!)),
                l10n.resultHinted(n(c[AyahOutcome.hinted]!)),
                l10n.resultRevealedCount(n(c[AyahOutcome.revealed]!)),
                l10n.resultNotReachedCount(n(c[AyahOutcome.notReached]!)),
              ].join(' · '),
              textAlign: TextAlign.center,
              style: TypeScale.body.copyWith(color: colors.ink),
            ),
            const SizedBox(height: Space.s1),
            Text(
              l10n.resultReached(n(result.reached), l10n.ayahCount(widget.range.length, n(widget.range.length))),
              textAlign: TextAlign.center,
              style: TypeScale.caption.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: Space.s4),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(MathaniIcons.tryAgain),
                  label: Text(l10n.resultTryAgain),
                  onPressed: _tryAgain,
                ),
              ),
              const SizedBox(width: Space.s3),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(MathaniIcons.check),
                  label: Text(l10n.resultDone),
                  onPressed: _done,
                ),
              ),
            ]),
            const SizedBox(height: Space.s4),
            Divider(color: colors.line),
            if (_words == null)
              const Padding(padding: EdgeInsets.all(Space.s4), child: Center(child: CircularProgressIndicator()))
            else
              for (var i = 0; i < widget.range.length; i++)
                _ReviewAyah(ayah: widget.range.from + i, words: _words![i], progress: result.review[i]),
          ],
        ),
      ),
    );
  }
}

/// One ayah of the review: missed and wrong words underlined, added words marked with a caret,
/// hinted words in the hint colour; revealed and unreached ayat tagged.
class _ReviewAyah extends StatelessWidget {
  const _ReviewAyah({required this.ayah, required this.words, required this.progress});
  final int ayah;
  final List<Word> words;
  final AyahProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final reader = ReaderScope.of(context);
    final base = flowingTextStyle(colors, 22);
    final notReached = progress.outcome == AyahOutcome.notReached;
    final byPosition = {for (final m in progress.mistakes) m.position: m};

    final spans = <InlineSpan>[];
    for (final w in words) {
      if (w.isAyahEnd) {
        spans.add(TextSpan(text: '${ayahEndGlyphs(w.text, reader.quran.font)} '));
        continue;
      }
      final mistake = byPosition[w.position];
      if (mistake?.kind == MistakeKind.added) {
        // Something was said before this word that is not in the ayah.
        spans.add(TextSpan(
          text: '‸ ',
          style: TextStyle(color: colors.mistake),
          semanticsLabel: l10n.resultAdded,
        ));
      }
      final marked = mistake != null && mistake.kind != MistakeKind.added;
      spans.add(TextSpan(
        text: '${w.text} ',
        style: marked
            ? TextStyle(
                decoration: TextDecoration.underline,
                decorationColor: colors.mistake,
                decorationThickness: 2,
                color: colors.mistake,
              )
            : progress.hints.contains(w.position)
                ? TextStyle(color: colors.hint)
                : null,
        semanticsLabel: !marked
            ? null
            : mistake.kind == MistakeKind.wrong && mistake.heard != null
                ? '${w.text}، ${l10n.resultWrong(mistake.heard!)}'
                : '${w.text}، ${l10n.resultMissed}',
      ));
    }

    final tag = switch (progress.outcome) {
      AyahOutcome.revealed => l10n.resultRevealed,
      AyahOutcome.notReached => progress.unfinished ? l10n.resultNotFinished : l10n.resultNotReached,
      _ => null,
    };
    return Opacity(
      opacity: notReached ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tag != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s2, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(tag, style: TypeScale.caption.copyWith(color: colors.inkMuted)),
                ),
              ),
            RichText(
              textAlign: TextAlign.justify,
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.noScaling,
              text: TextSpan(style: base, children: spans),
            ),
          ],
        ),
      ),
    );
  }
}
