import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../data/quran_repository.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import '../reader/flowing_view.dart' show flowingAyahText, flowingTextStyle;
import '../search/arabic_normalizer.dart';
import 'mutashabihat_content.dart';
import 'shared_wording.dart';

/// The overlay of «عرض المتشابه» (specs/010 contracts/mutashabihat-ui.md › Overlay): [ref] and
/// its similar ayat in the top two thirds, the owner's explanation in the bottom third. The ayah
/// stays selected while it is open.
Future<void> showSimilarSheet(BuildContext context, AyahRef ref) async {
  final reader = ReaderScope.read(context);
  final groups = reader.similar.groupsOf(ref);
  if (groups.isEmpty) return;
  reader.select(ref);
  // Several groups: each tab is named by the wording the ayah shares with that group
  // (specs/013 FR-016). The selection above is the feedback while the words load.
  List<String>? labels;
  if (groups.length > 1) {
    final locale = Localizations.localeOf(context);
    labels = await similarTabLabels(reader.quran, ref, groups, (n) => formatNumber(n, locale));
    if (!context.mounted) {
      reader.select(null);
      return;
    }
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: MathaniColors.of(context).surfaceRaised,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: SimilarSheet(ayah: ref, groups: groups, labels: labels),
    ),
  );
  reader.select(null);
}

/// The text of each of [ref]'s tabs, one per group in [groups] (specs/013 research R8): the
/// wording [ref] shares with the group's other ayat, or [number] of the tab when there is none.
Future<List<String>> similarTabLabels(QuranRepository quran, AyahRef ref,
    List<MutashabihGroup> groups, String Function(int n) number) async {
  Future<List<String>> words(AyahRef a) async => [
        for (final w in await quran.wordsOf(a))
          if (!w.isAyahEnd) w.text,
      ];
  final (pressed, others) = await (
    words(ref),
    Future.wait([
      for (final g in groups)
        Future.wait([
          for (final a in g.ayat)
            if (a != ref) words(a),
        ]),
    ]),
  ).wait;
  return tabLabels(pressed: pressed, groups: others, key: normalizeArabic, number: number);
}

@visibleForTesting
class SimilarSheet extends StatefulWidget {
  const SimilarSheet({super.key, required this.ayah, required this.groups, this.labels});

  /// The long-pressed ayah, shown first.
  final AyahRef ayah;

  /// Its groups, in file order (FR-011).
  final List<MutashabihGroup> groups;

  /// The text of each group's tab, when there are several groups (specs/013).
  final List<String>? labels;

  @override
  State<SimilarSheet> createState() => _SimilarSheetState();
}

class _SimilarSheetState extends State<SimilarSheet> {
  int _group = 0;

  void _select(int group) => setState(() => _group = group);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final group = widget.groups[_group];
    final ayat = [widget.ayah, for (final a in group.ayat) if (a != widget.ayah) a];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.s4, 0, Space.s2, 0),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l10n.similarTitle,
                      style: TypeScale.titleSm.copyWith(color: colors.accentInk)),
                ),
              ),
              IconButton(
                icon: const Icon(MathaniIcons.close),
                tooltip: l10n.similarClose,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        // Several groups: one chip each, in file order (FR-011), named by the wording the
        // pressed ayah shares with the group, or by its number when it shares none (specs/013).
        if (widget.groups.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s2),
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: Space.s2,
                children: [
                  for (var i = 0; i < widget.groups.length; i++)
                    _tab(context, i, constraints.maxWidth),
                ],
              ),
            ),
          ),
        // Two thirds for the ayat, one third for the explanation; each scrolls on its own
        // (FR-006 to FR-008). Keyed by group, so switching starts both at the top.
        Expanded(
          flex: 2,
          child: ListView.builder(
            key: ValueKey(('ayat', _group)),
            padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s3),
            itemCount: ayat.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: Space.s2),
              child: _AyahCard(ref: ayat[i], pressed: i == 0),
            ),
          ),
        ),
        Divider(height: 1, color: colors.line),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(('explanation', _group)),
            padding: const EdgeInsets.all(Space.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, p) in group.explanation.split('\n\n').indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : Space.s3),
                    child: Text(
                      p,
                      textDirection: TextDirection.rtl,
                      style: TypeScale.body.copyWith(color: colors.ink),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

extension on _SimilarSheetState {
  Widget _tab(BuildContext context, int i, double maxWidth) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final number = formatNumber(i + 1, locale);
    final label = widget.labels != null && i < widget.labels!.length ? widget.labels![i] : number;
    final isNumber = label == number;
    return Semantics(
      label: isNumber ? l10n.similarGroup(number) : label,
      excludeSemantics: true,
      selected: i == _group,
      button: true,
      child: ChoiceChip(
        label: ConstrainedBox(
          // The chip's own padding and tick take the rest of the row.
          constraints: BoxConstraints(maxWidth: math.max(48, maxWidth - 72)),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: isNumber ? null : TextDirection.rtl,
            style: isNumber ? null : const TextStyle(fontFamily: TypeScale.quranFamily),
          ),
        ),
        selected: i == _group,
        onSelected: (_) => _select(i),
      ),
    );
  }
}

/// One ayah of the group. The pressed ayah is marked and does nothing on tap; any other opens
/// in the Mushaf with the usual brief highlight (FR-009).
class _AyahCard extends StatefulWidget {
  const _AyahCard({required this.ref, required this.pressed});
  final AyahRef ref;
  final bool pressed;

  @override
  State<_AyahCard> createState() => _AyahCardState();
}

class _AyahCardState extends State<_AyahCard> {
  late final Future<List<Word>> _words = ReaderScope.read(context).quran.wordsOf(widget.ref);

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.read(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    final surah = reader.quran.surahList[widget.ref.surah - 1];
    final reference = l10n.bookmarkTitle(
      locale.languageCode == 'ar' ? surah.nameAr : surah.nameTranslit,
      formatNumber(widget.ref.ayah, locale),
    );

    final content = Padding(
      padding: const EdgeInsets.all(Space.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.pressed) ...[
                Text(l10n.similarThisAyah,
                    style: TypeScale.label.copyWith(color: colors.accentInk)),
                const SizedBox(width: Space.s2),
              ],
              Expanded(
                child: Text(reference,
                    style: TypeScale.caption.copyWith(color: colors.inkMuted)),
              ),
            ],
          ),
          FutureBuilder(
            future: _words,
            builder: (context, snapshot) => Text(
              snapshot.hasData ? flowingAyahText(snapshot.data!, reader.quran.font).trimRight() : '',
              textDirection: TextDirection.rtl,
              style: flowingTextStyle(colors, reader.preferences.flowFontSize.toDouble()),
            ),
          ),
        ],
      ),
    );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));
    if (widget.pressed) {
      return Material(color: colors.selected, shape: shape, child: content);
    }
    return Semantics(
      button: true,
      label: l10n.similarOpenAyah(reference),
      child: Material(
        color: colors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            reader.jumpTo(widget.ref);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: content,
          ),
        ),
      ),
    );
  }
}
