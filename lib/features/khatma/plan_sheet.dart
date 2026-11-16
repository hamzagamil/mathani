import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/quran_repository.dart';
import 'khatma_controller.dart';
import 'khatma_division.dart';
import 'khatma_format.dart';
import 'khatma_models.dart';

/// What the reader chose in the plan sheet.
class PlanChoice {
  const PlanChoice(this.plan, {required this.startAyah, required this.startDate});
  final KhatmaPlan plan;
  final int startAyah;
  final CalendarDay startDate;
}

/// Opens the plan sheet (contracts/khatma-ui-and-reminders.md › Plan sheet). With [changing], it
/// has no start fields and divides from the khatma place (FR-030). [initial] is preselected
/// (FR-036). [currentPage] is the page on the reading screen, for "Start from this page".
Future<PlanChoice?> showPlanSheet(
  BuildContext context, {
  required KhatmaController controller,
  KhatmaPlan? initial,
  bool changing = false,
  int? currentPage,
}) =>
    showModalBottomSheet<PlanChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => PlanSheet(
        controller: controller,
        initial: initial,
        changing: changing,
        currentPage: currentPage,
      ),
    );

enum _Kind { marks, seven, days, pagesPerDay, finishDate }

enum _From { beginning, thisPage, juz, surah, page }

class PlanSheet extends StatefulWidget {
  const PlanSheet({
    super.key,
    required this.controller,
    this.initial,
    this.changing = false,
    this.currentPage,
  });

  final KhatmaController controller;
  final KhatmaPlan? initial;
  final bool changing;
  final int? currentPage;

  @override
  State<PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<PlanSheet> {
  late _Kind _kind;
  int _quarters = 8;
  final _days = TextEditingController(text: '30');
  final _pagesPerDay = TextEditingController(text: '20');
  CalendarDay? _finish;

  _From _from = _From.beginning;
  int _juz = 1;
  int _surah = 1;
  final _page = TextEditingController(text: '1');
  late CalendarDay _startDate = widget.controller.today;
  bool _later = false;

  QuranIndex get _index => widget.controller.index;
  QuranRepository get _quran => widget.controller.quran;

  @override
  void initState() {
    super.initState();
    switch (widget.initial) {
      case MarksPlan(:final quarters):
        _kind = _Kind.marks;
        _quarters = quarters;
      case SevenPlan():
        _kind = _Kind.seven;
      case DaysPlan(:final days):
        _kind = _Kind.days;
        _days.text = '$days';
      case null:
        _kind = _Kind.marks;
    }
  }

  @override
  void dispose() {
    _days.dispose();
    _pagesPerDay.dispose();
    _page.dispose();
    super.dispose();
  }

  int? _parse(TextEditingController c, int max) {
    final v = int.tryParse(c.text.trim());
    return v == null || v < 1 || v > max ? null : v;
  }

  /// The start point's ayah id, or null while a field is not valid.
  int? get _startAyah {
    if (widget.changing) return widget.controller.changePlanStartAyah;
    return switch (_from) {
      _From.beginning => 1,
      _From.thisPage => _index.firstAyahOn(widget.currentPage ?? 1),
      _From.juz => _index.juzStarts[_juz - 1],
      _From.surah => _index.surahStarts[_surah - 1],
      _From.page => switch (_parse(_page, QuranRepository.pageCount)) {
          null => null,
          final p => _index.firstAyahOn(p),
        },
    };
  }

  CalendarDay get _firstDay => widget.changing ? widget.controller.changePlanFirstDay : _startDate;

  KhatmaPlan? _planFor(int startAyah) => switch (_kind) {
        _Kind.marks => MarksPlan(_quarters),
        _Kind.seven => const SevenPlan(),
        _Kind.days => switch (_parse(_days, KhatmaPlan.maxDays)) {
            null => null,
            final d => DaysPlan(d),
          },
        _Kind.pagesPerDay => switch (_parse(_pagesPerDay, QuranRepository.pageCount)) {
            null => null,
            final p => DaysPlan(daysForPagesPerDay(_index, startAyah, p)),
          },
        _Kind.finishDate => switch (_finish) {
            null => null,
            final f => switch (daysUntil(_firstDay, f)) {
                null => null,
                final d => DaysPlan(d),
              },
          },
      };

  Future<CalendarDay?> _pickDate(CalendarDay initial, CalendarDay first) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first.asDateTime : initial.asDateTime,
      firstDate: first.asDateTime,
      lastDate: first.addDays(KhatmaPlan.maxDays * 2).asDateTime,
    );
    return picked == null ? null : CalendarDay.of(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final f = KhatmaFormat.of(context, _quran);
    final startAyah = _startAyah;
    final plan = startAyah == null ? null : _planFor(startAyah);
    final summary = plan == null ? null : _preview(startAyah!, plan);

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s1),
          child: Semantics(
            header: true,
            child: Text(text, style: TypeScale.titleSm.copyWith(color: colors.accentInk)),
          ),
        );

    Widget option({
      required bool selected,
      required String title,
      String? trailing,
      required VoidCallback onTap,
    }) =>
        Semantics(
          selected: selected,
          inMutuallyExclusiveGroup: true,
          child: ListTile(
            selected: selected,
            leading: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? colors.accentInk : colors.inkMuted,
            ),
            title: Text(title),
            trailing: trailing == null ? null : Text(trailing),
            onTap: onTap,
          ),
        );

    Widget numberField(TextEditingController c, int max) => Padding(
          padding: const EdgeInsets.fromLTRB(Space.s8 + Space.s6, 0, Space.s4, Space.s2),
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              errorText: _parse(c, max) == null
                  ? l10n.khatmaNumberRange(f.number(1), f.number(max))
                  : null,
            ),
          ),
        );

    final markDays = startAyah == null
        ? const <int, int>{}
        : {
            for (final q in KhatmaPlan.markAmounts)
              q: divide(_index, startAyah, MarksPlan(q)).length,
          };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s4),
            child: Text(
              widget.changing ? l10n.khatmaChangePlan : l10n.khatmaPlanTitle,
              style: TypeScale.titleLg.copyWith(color: colors.ink),
            ),
          ),
          if (widget.changing)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s4, Space.s1, Space.s4, 0),
              child: Text(
                l10n.khatmaFromPlace(f.number(_index.pageOf(startAyah ?? 1))),
                style: TypeScale.body.copyWith(color: colors.inkMuted),
              ),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                heading(l10n.khatmaDailyAmount),
                for (final q in KhatmaPlan.markAmounts)
                  option(
                    selected: _kind == _Kind.marks && _quarters == q,
                    title: f.amount(q),
                    trailing: markDays[q] == null ? null : f.days(markDays[q]!),
                    onTap: () => setState(() {
                      _kind = _Kind.marks;
                      _quarters = q;
                    }),
                  ),
                option(
                  selected: _kind == _Kind.seven,
                  title: l10n.khatmaSevenDays,
                  trailing: f.days(startAyah == null
                      ? 7
                      : divide(_index, startAyah, const SevenPlan()).length),
                  onTap: () => setState(() => _kind = _Kind.seven),
                ),
                heading(l10n.khatmaCustom),
                option(
                  selected: _kind == _Kind.days,
                  title: l10n.khatmaCustomDays,
                  onTap: () => setState(() => _kind = _Kind.days),
                ),
                if (_kind == _Kind.days) numberField(_days, KhatmaPlan.maxDays),
                option(
                  selected: _kind == _Kind.pagesPerDay,
                  title: l10n.khatmaCustomPages,
                  onTap: () => setState(() => _kind = _Kind.pagesPerDay),
                ),
                if (_kind == _Kind.pagesPerDay)
                  numberField(_pagesPerDay, QuranRepository.pageCount),
                option(
                  selected: _kind == _Kind.finishDate,
                  title: l10n.khatmaCustomDate,
                  trailing: _finish == null ? null : f.date(_finish!),
                  onTap: () async {
                    setState(() => _kind = _Kind.finishDate);
                    final d = await _pickDate(_finish ?? _firstDay.addDays(29), _firstDay);
                    if (d != null && mounted) setState(() => _finish = d);
                  },
                ),
                if (_kind == _Kind.finishDate && _finish != null && _finish!.isBefore(_firstDay))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s4),
                    child: Text(l10n.khatmaDateBeforeStart,
                        style: TypeScale.caption.copyWith(color: colors.mistake)),
                  ),
                if (!widget.changing) ...[
                  heading(l10n.khatmaStartFrom),
                  option(
                    selected: _from == _From.beginning,
                    title: l10n.khatmaFromBeginning,
                    onTap: () => setState(() => _from = _From.beginning),
                  ),
                  if (widget.currentPage != null)
                    option(
                      selected: _from == _From.thisPage,
                      title: l10n.khatmaFromThisPage(f.number(widget.currentPage!)),
                      onTap: () => setState(() => _from = _From.thisPage),
                    ),
                  option(
                    selected: _from == _From.juz,
                    title: l10n.khatmaFromJuz,
                    onTap: () => setState(() => _from = _From.juz),
                  ),
                  if (_from == _From.juz)
                    _Picker(
                      value: _juz,
                      count: 30,
                      label: (j) => l10n.juzLabel(f.number(j)),
                      onChanged: (j) => setState(() => _juz = j),
                    ),
                  option(
                    selected: _from == _From.surah,
                    title: l10n.khatmaFromSurah,
                    onTap: () => setState(() => _from = _From.surah),
                  ),
                  if (_from == _From.surah)
                    _Picker(
                      value: _surah,
                      count: 114,
                      label: (s) {
                        final surah = _quran.surahList[s - 1];
                        return '${f.number(s)}. ${f.arabic ? surah.nameAr : surah.nameTranslit}';
                      },
                      onChanged: (s) => setState(() => _surah = s),
                    ),
                  option(
                    selected: _from == _From.page,
                    title: l10n.khatmaFromPage,
                    onTap: () => setState(() => _from = _From.page),
                  ),
                  if (_from == _From.page) numberField(_page, QuranRepository.pageCount),
                  heading(l10n.khatmaStartOn),
                  option(
                    selected: !_later,
                    title: l10n.khatmaToday,
                    onTap: () => setState(() {
                      _later = false;
                      _startDate = widget.controller.today;
                    }),
                  ),
                  option(
                    selected: _later,
                    title: l10n.khatmaLaterDate,
                    trailing: _later ? f.date(_startDate) : null,
                    onTap: () async {
                      final today = widget.controller.today;
                      final d = await _pickDate(today.addDays(1), today.addDays(1));
                      if (d != null && mounted) {
                        setState(() {
                          _later = true;
                          _startDate = d;
                        });
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, Space.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (summary != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      f.summary(summary),
                      style: TypeScale.body.copyWith(color: colors.ink),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: Space.s2),
                FilledButton(
                  onPressed: plan == null
                      ? null
                      : () => Navigator.of(context).pop(
                          PlanChoice(plan, startAyah: startAyah!, startDate: _firstDay)),
                  child: Text(widget.changing ? l10n.khatmaChangePlan : l10n.khatmaStart),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  WirdPreview _preview(int startAyah, KhatmaPlan plan) =>
      previewOf(_index, divide(_index, startAyah, plan), _firstDay);
}

/// A drop-down of 1 to [count], for a juz or a surah.
class _Picker extends StatelessWidget {
  const _Picker({
    required this.value,
    required this.count,
    required this.label,
    required this.onChanged,
  });

  final int value;
  final int count;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.s8 + Space.s6, 0, Space.s4, Space.s2),
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 360,
          items: [
            for (var i = 1; i <= count; i++)
              DropdownMenuItem(value: i, child: Text(label(i), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
}
