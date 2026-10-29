import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import 'prayer_controller.dart';
import 'prayer_copy.dart';
import 'prayer_models.dart';

Future<void> showPrayerCalculation(
  BuildContext context,
  PrayerController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => CalculationSheet(controller: controller),
);

class CalculationSheet extends StatefulWidget {
  const CalculationSheet({super.key, required this.controller});
  final PrayerController controller;
  @override
  State<CalculationSheet> createState() => _CalculationSheetState();
}

class _CalculationSheetState extends State<CalculationSheet> {
  late final SavedLocation place = widget.controller.viewedLocation!;
  late CalculationPreferences preferences = place.calculation;
  bool saving = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = widget.controller;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.prayerCalculationSettings,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: l.prayerCancel,
                  onPressed: saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Text(
                  place.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(l.prayerCalculationExplanation),
                const SizedBox(height: 16),
                Text(
                  '${l.prayerSuggestedMethod}: ${prayerMethodName(l, CalculationPreferences.suggestion(place.countryCode))}',
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PrayerMethod>(
                  initialValue: preferences.method,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.prayerMethod,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final method in PrayerMethod.values)
                      DropdownMenuItem(
                        value: method,
                        child: Text(
                          prayerMethodName(l, method),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(
                          () =>
                              preferences = preferences.copyWith(method: value),
                        ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PrayerMadhhab>(
                  initialValue: preferences.madhhab,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.prayerMadhhab,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final madhhab in PrayerMadhhab.values)
                      DropdownMenuItem(
                        value: madhhab,
                        child: Text(prayerMadhhabName(l, madhhab)),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(
                          () => preferences = preferences.copyWith(
                            madhhab: value,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(l.prayerAsrExplanation),
                const SizedBox(height: 16),
                DropdownButtonFormField<HighLatitudeRule>(
                  initialValue: preferences.highLatitudeRule,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.prayerHighLatitude,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: HighLatitudeRule.middleOfNight,
                      child: Text(l.prayerMiddleNight),
                    ),
                    DropdownMenuItem(
                      value: HighLatitudeRule.seventhOfNight,
                      child: Text(l.prayerSeventhNight),
                    ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(
                          () => preferences = preferences.copyWith(
                            highLatitudeRule: value,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                if (c.failure != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(prayerFailureMessage(l, c.failure!)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() => saving = true);
                        await c.updateCalculation(place.id, preferences);
                        if (!context.mounted) return;
                        if (c.failure == null) {
                          Navigator.pop(context);
                        } else {
                          setState(() => saving = false);
                        }
                      },
                child: Text(l.prayerSave),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
