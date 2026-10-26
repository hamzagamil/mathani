// Choosing what to recite (specs/006 FR-009, contracts/memorization-ui.md › Range sheet): a surah
// and its ayat, the current page by default; then the model, the microphone and the session.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../data/models.dart';
import '../../platform/supported_browsers.dart';
import '../../shared/mathani_icons.dart';
import '../../shared/numerals.dart';
import '../../shared/reader_state.dart';
import '../recitation/download_queue.dart';
import 'asr_model.dart';
import 'device_support.dart';
import 'memorization_controller.dart';
import 'mic_explainer.dart';

/// The range on [page] by default: its ayat of the surah it starts with.
MemorizationRange pageRange(ReaderController reader, int page) {
  final quran = reader.quran;
  final head = quran.firstAyahOnPage(page);
  final onPage = quran.ayahsStartingOnPage(page).where((a) => a.surah == head.surah);
  return MemorizationRange(head.surah, head.ayah, onPage.isEmpty ? head.ayah : onPage.last.ayah);
}

/// From [ref] to the end of its page (the long-press default).
MemorizationRange rangeFrom(ReaderController reader, AyahRef ref) {
  final onPage = reader.quran
      .ayahsStartingOnPage(reader.quran.pageOf(ref))
      .where((a) => a.surah == ref.surah && a.ayah >= ref.ayah);
  return MemorizationRange(ref.surah, ref.ayah, onPage.isEmpty ? ref.ayah : onPage.last.ayah);
}

/// Opens the range sheet; Start begins the session.
Future<void> showMemorizeSheet(BuildContext context, {AyahRef? from}) async {
  final memorization = MemorizationScope.read(context);
  if (memorization == null) return;
  final reader = ReaderScope.read(context);
  final initial = from == null ? pageRange(reader, reader.page) : rangeFrom(reader, from);
  final range = await showModalBottomSheet<MemorizationRange>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _RangeSheet(controller: memorization, initial: initial),
  );
  if (range == null || !context.mounted) return;
  final outcome = await memorization.start(range, explain: () => showMicExplainer(context));
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  switch (outcome) {
    case StartOutcome.started:
      break;
    case StartOutcome.micDenied || StartOutcome.micPermanentlyDenied:
      showMicDenied(context, device: memorization.device);
    case StartOutcome.unsupportedDevice:
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.memorizeUnsupported)));
    case StartOutcome.needsModel:
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.memorizeModelNeeded(_modelSize(context, memorization.model)))));
  }
}

String _modelSize(BuildContext context, AsrModel model) =>
    formatSize(AppLocalizations.of(context), Localizations.localeOf(context), model.totalBytes);

class _RangeSheet extends StatefulWidget {
  const _RangeSheet({required this.controller, required this.initial});
  final MemorizationController controller;
  final MemorizationRange initial;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late int _surah = widget.initial.surah;
  late int _from = widget.initial.from;
  late int _to = widget.initial.to;
  Unsupported? _unsupported;
  bool _checked = false;
  bool _failed = false;

  AsrModel get _model => widget.controller.model;

  @override
  void initState() {
    super.initState();
    _model.refresh();
    memorizationSupport(widget.controller.device).then((u) {
      if (mounted) {
        setState(() {
          _unsupported = u;
          _checked = true;
        });
      }
    });
  }

  int _ayahCount(ReaderController reader) => reader.quran.surahList[_surah - 1].ayahCount;

  void _setFrom(int v, int max) => setState(() {
        _from = v.clamp(1, max);
        if (_to < _from) _to = _from; // From past To moves To with it
      });

  void _setTo(int v, int max) => setState(() {
        _to = v.clamp(1, max);
        if (_from > _to) _from = _to;
      });

  Future<void> _download() async {
    setState(() => _failed = false);
    final ok = await confirmDownload(
        // Room to download and unpack (specs/007 research R4); the size shown is the download.
        context, widget.controller.device, () async => _model.requiredBytes - _model.downloadedBytes);
    if (!ok) return;
    try {
      await _model.download();
    } on AsrModelException {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reader = ReaderScope.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    final english = locale.languageCode == 'en';
    final quran = reader.quran;
    final max = _ayahCount(reader);
    String n(int v) => formatNumber(v, locale);

    final Widget body;
    if (_unsupported != null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s4),
        child: Column(
          children: [
            Text(l10n.memorizeUnsupported,
                textAlign: TextAlign.center, style: TypeScale.titleSm.copyWith(color: colors.ink)),
            const SizedBox(height: Space.s2),
            Text(
              switch (_unsupported) {
                Unsupported.not64Bit => l10n.memorizeUnsupported64,
                Unsupported.browser => l10n.memorizationBrowserUnsupported(supportedBrowserNames),
                _ => l10n.memorizeUnsupportedMemory,
              },
              textAlign: TextAlign.center,
              style: TypeScale.body.copyWith(color: colors.inkMuted),
            ),
          ],
        ),
      );
    } else {
      final fromPage = quran.pageOf(AyahRef(_surah, _from));
      final toPage = quran.pageOf(AyahRef(_surah, _to));
      final count = _to - _from + 1;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              final r = pageRange(reader, quran.pageOf(AyahRef(v, 1)));
              _surah = v;
              _from = r.surah == v ? r.from : 1;
              _to = r.surah == v ? r.to : 1;
            }),
          ),
          const SizedBox(height: Space.s3),
          Row(
            children: [
              Expanded(
                child: _AyahStepper(
                  label: l10n.memorizeFrom,
                  value: _from,
                  max: max,
                  onChanged: (v) => _setFrom(v, max),
                ),
              ),
              const SizedBox(width: Space.s3),
              Expanded(
                child: _AyahStepper(
                  label: l10n.memorizeTo,
                  value: _to,
                  max: max,
                  onChanged: (v) => _setTo(v, max),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s2),
          Text(
            l10n.memorizeSummary(
              l10n.ayahCount(count, n(count)),
              fromPage == toPage ? l10n.memorizePage(n(fromPage)) : l10n.memorizePages(n(fromPage), n(toPage)),
            ),
            style: TypeScale.caption.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: Space.s3),
          ListenableBuilder(
            listenable: _model,
            builder: (context, _) => _modelRow(context),
          ),
        ],
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            Space.s4, 0, Space.s4, Space.s4 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.memorizeTitle, style: TypeScale.titleLg.copyWith(color: colors.ink)),
            const SizedBox(height: Space.s3),
            if (!_checked) const Center(child: CircularProgressIndicator()) else body,
            if (_checked && _unsupported == null)
              ListenableBuilder(
                listenable: _model,
                builder: (context, _) => FilledButton.icon(
                  icon: const Icon(MathaniIcons.mic),
                  label: Text(l10n.memorizeStart),
                  onPressed: _model.state == AsrModelState.ready
                      ? () => Navigator.of(context).pop(MemorizationRange(_surah, _from, _to))
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The one-time model download, when it is not on the device yet.
  Widget _modelRow(BuildContext context) {
    if (_model.state == AsrModelState.ready) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final locale = Localizations.localeOf(context);
    final downloading = _model.state == AsrModelState.downloading;
    final fraction = _model.totalBytes == 0 ? 0.0 : _model.downloadedBytes / _model.totalBytes;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.memorizeModelNeeded(_modelSize(context, _model)),
                  style: TypeScale.body.copyWith(color: colors.ink)),
              if (_failed) ...[
                const SizedBox(height: Space.s2),
                Text(l10n.memorizeModelFailed, style: TypeScale.caption.copyWith(color: colors.mistake)),
              ],
              const SizedBox(height: Space.s2),
              if (downloading) ...[
                LinearProgressIndicator(value: fraction),
                const SizedBox(height: Space.s1),
                Text(l10n.memorizeModelDownloading(formatNumber((fraction * 100).floor(), locale)),
                    style: TypeScale.caption.copyWith(color: colors.inkMuted)),
              ] else
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  // Filled: it is the step to take; an outlined button here read as disabled
                  // next to the disabled Start button.
                  child: FilledButton.icon(
                    icon: const Icon(MathaniIcons.download),
                    label: Text(l10n.download),
                    onPressed: _download,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An ayah number in 1..[max]: minus and plus, or typed directly.
class _AyahStepper extends StatefulWidget {
  const _AyahStepper({required this.label, required this.value, required this.max, required this.onChanged});
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  State<_AyahStepper> createState() => _AyahStepperState();
}

class _AyahStepperState extends State<_AyahStepper> {
  late final _text = TextEditingController(text: '${widget.value}');

  @override
  void didUpdateWidget(_AyahStepper old) {
    super.didUpdateWidget(old);
    if (int.tryParse(_text.text) != widget.value) _text.text = '${widget.value}';
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(MathaniIcons.minus),
          tooltip: '${widget.label} −',
          onPressed: widget.value > 1 ? () => widget.onChanged(widget.value - 1) : null,
        ),
        Expanded(
          child: TextField(
            controller: _text,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: widget.label, hintText: l10n.ayahField),
            onSubmitted: (s) => widget.onChanged(int.tryParse(s) ?? widget.value),
            onTapOutside: (_) {
              widget.onChanged(int.tryParse(_text.text) ?? widget.value);
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        IconButton(
          icon: const Icon(MathaniIcons.plus),
          tooltip: '${widget.label} +',
          onPressed: widget.value < widget.max ? () => widget.onChanged(widget.value + 1) : null,
        ),
      ],
    );
  }
}
