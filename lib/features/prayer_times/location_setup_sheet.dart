import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import 'prayer_controller.dart';
import 'prayer_copy.dart';
import 'prayer_services.dart';

/// Prayer Times before a place is set: no permission is asked until a button is tapped (FR-006).
class PrayerFirstTime extends StatelessWidget {
  const PrayerFirstTime({super.key, required this.controller});
  final PrayerController controller;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = controller;
    final language = Localizations.localeOf(context).languageCode;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l.prayerFirstTimeTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l.prayerLocationWhy),
        const SizedBox(height: 24),
        if (c.busy) const LinearProgressIndicator(),
        if (c.failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(prayerFailureMessage(l, c.failure!)),
            ),
          ),
        FilledButton.icon(
          onPressed: c.busy || c.locationFailure == PrayerFailure.locationDenied
              ? null
              : () => c.useMyLocation(language),
          icon: const Icon(Icons.my_location),
          label: Text(l.prayerUseMyLocation),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: c.busy ? null : () => showPrayerSearch(context, c),
          icon: const Icon(Icons.search),
          label: Text(l.prayerSearchCity),
        ),
      ],
    );
  }
}

/// City search, with the internet-based estimate as a "Suggested" first row (FR-007, FR-008).
Future<void> showPrayerSearch(
  BuildContext context,
  PrayerController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => PrayerSearchSheet(controller: controller),
).whenComplete(controller.cancelSearch);

class PrayerSearchSheet extends StatefulWidget {
  const PrayerSearchSheet({super.key, required this.controller});
  final PrayerController controller;
  @override
  State<PrayerSearchSheet> createState() => _PrayerSearchSheetState();
}

class _PrayerSearchSheetState extends State<PrayerSearchSheet> {
  final query = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(
      widget.controller.loadSuggestion(
        Localizations.localeOf(context).languageCode,
      ),
    );
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> _choose(Map<String, dynamic> place, String language) async {
    final c = widget.controller;
    await c.choosePlace(place, language);
    if (mounted && c.failure == null) Navigator.pop(context);
  }

  static String _where(Map<String, dynamic> place) => [
    place['region'],
    place['countryCode'],
  ].whereType<String>().where((v) => v.isNotEmpty).join(', ');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = widget.controller;
    final language = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final suggestion = c.suggestion;
            final typed = query.text.trim().length >= 2;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: query,
                          autofocus: true,
                          maxLength: 80,
                          decoration: InputDecoration(
                            labelText: l.prayerSearchCity,
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                            counterText: '',
                          ),
                          onChanged: (q) => unawaited(c.search(q, language)),
                        ),
                      ),
                      IconButton(
                        tooltip: l.prayerCancel,
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                if (c.busy || c.searching) const LinearProgressIndicator(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      if (suggestion != null && !typed)
                        ListTile(
                          leading: const Icon(Icons.near_me_outlined),
                          title: Text(
                            l.prayerSuggested(
                              [suggestion['city'], suggestion['countryCode']]
                                  .whereType<String>()
                                  .where((v) => v.isNotEmpty)
                                  .join(', '),
                            ),
                          ),
                          subtitle: Text(l.prayerEstimateNote),
                          onTap: c.busy
                              ? null
                              : () => _choose(suggestion, language),
                        ),
                      if (c.failure != null)
                        ListTile(
                          title: Semantics(
                            liveRegion: true,
                            child: Text(prayerFailureMessage(l, c.failure!)),
                          ),
                          subtitle: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: () => c.search(query.text, language),
                              child: Text(l.prayerRetry),
                            ),
                          ),
                        )
                      else if (typed &&
                          c.results.isEmpty &&
                          !c.searching &&
                          !c.busy)
                        ListTile(title: Text(l.prayerNoResults)),
                      for (final place in c.results)
                        ListTile(
                          title: Text(place['city'] as String? ?? ''),
                          subtitle: Text(_where(place)),
                          onTap: c.busy ? null : () => _choose(place, language),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          l.prayerGeoNamesAttribution,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
