import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../shared/numerals.dart';
import 'prayer_controller.dart';
import 'prayer_copy.dart';
import 'prayer_models.dart';

/// Calculation settings of the viewed place (Story 2). Each change is saved at once and the
/// schedule behind updates.
Future<void> showPrayerCalculation(
  BuildContext context,
  PrayerController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => CalculationSheet(controller: controller),
);

class CalculationSheet extends StatelessWidget {
  const CalculationSheet({super.key, required this.controller});
  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = controller;
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final place = c.viewedPlace;
          if (place == null) return const SizedBox.shrink();
          final s = place.calculation;
          final suggested = CalculationSettings.suggestion(place.countryCode);
          void update(CalculationSettings next) =>
              unawaited(c.updateCalculation(place.id, next));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.prayerCalculationSettings,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: l.prayerCancel,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(place.name, style: theme.textTheme.titleMedium),
                ),
              ),
              if (c.failure != null) Text(prayerFailureMessage(l, c.failure!)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  children: [
                    _Heading(l.prayerMethod),
                    RadioGroup<PrayerMethod>(
                      groupValue: s.method,
                      onChanged: (m) {
                        if (m != null) update(s.copyWith(method: m));
                      },
                      child: Column(
                        children: [
                          for (final m in PrayerMethod.values)
                            RadioListTile<PrayerMethod>(
                              value: m,
                              title: Text(prayerMethodName(l, m)),
                              subtitle: m == suggested
                                  ? Text(l.prayerSuggestedMethod)
                                  : null,
                            ),
                        ],
                      ),
                    ),
                    const Divider(),
                    _Heading(l.prayerAsrSetting),
                    RadioGroup<AsrSetting>(
                      groupValue: s.asr,
                      onChanged: (a) {
                        if (a != null) update(s.copyWith(asr: a));
                      },
                      child: Column(
                        children: [
                          for (final a in AsrSetting.values)
                            RadioListTile<AsrSetting>(
                              value: a,
                              title: Text(prayerAsrName(l, a)),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l.prayerAsrNote,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const Divider(),
                    _Heading(l.prayerHighLatitude),
                    RadioGroup<HighLatitudeRule>(
                      groupValue: s.highLatitudeRule,
                      onChanged: (r) {
                        if (r != null) update(s.copyWith(highLatitudeRule: r));
                      },
                      child: Column(
                        children: [
                          RadioListTile<HighLatitudeRule>(
                            value: HighLatitudeRule.middleOfNight,
                            title: Text(l.prayerMiddleNight),
                            subtitle: Text(l.prayerMiddleNightNote),
                          ),
                          RadioListTile<HighLatitudeRule>(
                            value: HighLatitudeRule.seventhOfNight,
                            title: Text(l.prayerSeventhNight),
                            subtitle: Text(l.prayerSeventhNightNote),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    _Heading(l.prayerOffsets),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l.prayerOffsetsNote,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    for (final kind in dailyPrayers)
                      _OffsetRow(
                        label: prayerName(l, kind),
                        value: s.offset(kind),
                        locale: locale,
                        l: l,
                        onChanged: (v) => update(
                          s.copyWith(offsets: {...s.offsets, kind: v}),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

/// −30..+30 minutes in steps of one; holding a button repeats (FR-015).
class _OffsetRow extends StatefulWidget {
  const _OffsetRow({
    required this.label,
    required this.value,
    required this.locale,
    required this.l,
    required this.onChanged,
  });
  final String label;
  final int value;
  final Locale locale;
  final AppLocalizations l;
  final ValueChanged<int> onChanged;
  @override
  State<_OffsetRow> createState() => _OffsetRowState();
}

class _OffsetRowState extends State<_OffsetRow> {
  Timer? _repeat;
  late int _value = widget.value;

  @override
  void didUpdateWidget(_OffsetRow old) {
    super.didUpdateWidget(old);
    if (_repeat == null) _value = widget.value;
  }

  void _step(int delta) {
    final next = (_value + delta).clamp(-30, 30);
    if (next == _value) return;
    setState(() => _value = next);
    widget.onChanged(next);
  }

  void _hold(int delta) {
    _repeat?.cancel();
    _repeat = Timer.periodic(
      const Duration(milliseconds: 150),
      (_) => _step(delta),
    );
  }

  void _release() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  Widget _button(IconData icon, String tooltip, int delta, bool enabled) =>
      GestureDetector(
        onLongPressStart: enabled ? (_) => _hold(delta) : null,
        onLongPressEnd: (_) => _release(),
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: enabled ? () => _step(delta) : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final text = _value == 0
        ? l.prayerNoOffset
        : l.prayerOffsetMinutes(
            signedMinutes(_value).replaceAllMapped(
              RegExp(r'\d+'),
              (m) => formatNumber(int.parse(m[0]!), widget.locale),
            ),
          );
    return ListTile(
      title: Text(widget.label),
      subtitle: Semantics(liveRegion: true, child: Text(text)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(
            Icons.remove,
            l.prayerEarlier(widget.label),
            -1,
            _value > -30,
          ),
          _button(Icons.add, l.prayerLater(widget.label), 1, _value < 30),
        ],
      ),
    );
  }
}
