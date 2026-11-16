// Choosing what the recitation repeats: off, the ayah, the page, the surah or a range of ayat, and
// how many times. Opened from the bar's repeat button, or from an ayah's actions for a range that
// starts there.
import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/number_stepper.dart';
import '../../shared/reader_state.dart';
import 'recitation_controller.dart';

/// How many times a span is recited when the reader first sets a number.
const defaultRepeatTimes = 3;

/// [ref] to the last ayah of its surah that begins on its page.
AyahRange rangeToPageEnd(ReaderController reader, AyahRef ref) {
  final onPage = reader.quran
      .ayahsStartingOnPage(reader.quran.pageOf(ref))
      .where((a) => a.surah == ref.surah && a.ayah >= ref.ayah);
  return AyahRange(ref, onPage.isEmpty ? ref : onPage.last.ref);
}

typedef _Choice = ({RecitationRepeat mode, int? times, AyahRange? range});

/// Opens the repeat sheet. With [from] (an ayah's actions) it opens on a range starting at [from].
/// Choosing a range plays it from its start unless the recitation is already inside it.
Future<void> showRepeatSheet(BuildContext context, RecitationController recitation,
    {AyahRef? from}) async {
  final reader = ReaderScope.read(context);
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _RepeatSheet(recitation: recitation, reader: reader, from: from),
  );
  if (choice == null) return;
  recitation.setRepeat(choice.mode, times: choice.times, range: choice.range);
  final range = choice.range;
  if (range == null) return;
  final s = recitation.session;
  final inside = s != null && s.status != RecitationStatus.ended && range.contains(s.item.ref);
  if (!inside) await recitation.playFrom(range.from);
}

class _RepeatSheet extends StatefulWidget {
  const _RepeatSheet({required this.recitation, required this.reader, this.from});
  final RecitationController recitation;
  final ReaderController reader;
  final AyahRef? from;

  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  late RecitationRepeat _mode;
  late int _times;
  late bool _endless;
  late int _surah;
  late int _from;
  late int _to;

  @override
  void initState() {
    super.initState();
    final c = widget.recitation;
    _mode = widget.from != null ? RecitationRepeat.range : c.repeat;
    _times = c.repeatTimes ?? defaultRepeatTimes;
    _endless = c.repeat == RecitationRepeat.off || c.repeatTimes == null;
    final kept = c.repeatRange;
    final range = widget.from != null || kept == null || kept.from.surah != kept.to.surah
        ? rangeToPageEnd(widget.reader, widget.from ?? _here())
        : kept;
    _surah = range.from.surah;
    _from = range.from.ayah;
    _to = range.to.ayah;
  }

  /// The ayah being recited, or the reader's place.
  AyahRef _here() {
    final s = widget.recitation.session;
    if (s != null) return AyahRef(s.item.surah, s.item.isBasmala ? 1 : s.item.ayah);
    return widget.reader.quran.firstAyahOnPage(widget.reader.page).ref;
  }

  int get _ayahCount => widget.reader.quran.surahList[_surah - 1].ayahCount;

  void _done() {
    final range = _mode == RecitationRepeat.range
        ? AyahRange(AyahRef(_surah, _from), AyahRef(_surah, _to))
        : null;
    Navigator.of(context).pop<_Choice>(
        (mode: _mode, times: _endless ? null : _times, range: range));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final english = Localizations.localeOf(context).languageCode == 'en';
    final quran = widget.reader.quran;
    final max = _ayahCount;
    final range = _mode == RecitationRepeat.range;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            Space.s4, 0, Space.s4, Space.s4 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.repeatTitle, style: TypeScale.titleLg.copyWith(color: colors.ink)),
            const SizedBox(height: Space.s3),
            SegmentedButton<RecitationRepeat>(
              showSelectedIcon: false,
              segments: [
                for (final (mode, label) in [
                  (RecitationRepeat.off, l10n.repeatOffShort),
                  (RecitationRepeat.ayah, l10n.repeatAyahShort),
                  (RecitationRepeat.page, l10n.repeatPageShort),
                  (RecitationRepeat.surah, l10n.repeatSurahShort),
                  (RecitationRepeat.range, l10n.repeatRangeShort),
                ])
                  ButtonSegment(
                    value: mode,
                    label: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.fade),
                  ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            if (range) ...[
              const SizedBox(height: Space.s4),
              DropdownButtonFormField<int>(
                initialValue: _surah,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.surahField),
                items: [
                  for (final s in quran.surahList)
                    DropdownMenuItem(
                      value: s.number,
                      child: Text('${s.number}. ${english ? s.nameTranslit : s.nameAr}'),
                    ),
                ],
                onChanged: (v) => setState(() {
                  if (v == null || v == _surah) return;
                  final r = rangeToPageEnd(widget.reader, AyahRef(v, 1));
                  _surah = v;
                  _from = r.from.ayah;
                  _to = r.to.ayah;
                }),
              ),
              const SizedBox(height: Space.s3),
              Row(children: [
                Expanded(
                  child: NumberStepper(
                    label: l10n.memorizeFrom,
                    hint: l10n.ayahField,
                    value: _from,
                    max: max,
                    onChanged: (v) => setState(() {
                      _from = v.clamp(1, max);
                      if (_to < _from) _to = _from; // From past To moves To with it
                    }),
                  ),
                ),
                const SizedBox(width: Space.s3),
                Expanded(
                  child: NumberStepper(
                    label: l10n.memorizeTo,
                    hint: l10n.ayahField,
                    value: _to,
                    max: max,
                    onChanged: (v) => setState(() {
                      _to = v.clamp(1, max);
                      if (_from > _to) _from = _to;
                    }),
                  ),
                ),
              ]),
            ],
            if (_mode != RecitationRepeat.off) ...[
              const SizedBox(height: Space.s4),
              Row(children: [
                FilterChip(
                  label: Text(l10n.repeatEndless),
                  selected: _endless,
                  onSelected: (v) => setState(() => _endless = v),
                ),
                const SizedBox(width: Space.s3),
                if (!_endless)
                  Expanded(
                    child: NumberStepper(
                      label: l10n.repeatTimes,
                      value: _times,
                      max: maxRepeatTimes,
                      onChanged: (v) => setState(() => _times = v.clamp(1, maxRepeatTimes)),
                    ),
                  ),
              ]),
              const SizedBox(height: Space.s2),
              Text(
                _endless
                    ? l10n.repeatEndlessHelp
                    : range
                        ? l10n.repeatRangeHelp
                        : l10n.repeatEachHelp,
                style: TypeScale.caption.copyWith(color: colors.inkMuted),
              ),
            ],
            const SizedBox(height: Space.s4),
            FilledButton.icon(
              icon: Icon(range ? MathaniIcons.play : MathaniIcons.check),
              label: Text(range ? l10n.repeatPlayRange : l10n.repeatDone),
              onPressed: _done,
            ),
          ],
        ),
      ),
    );
  }
}
