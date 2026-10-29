import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import 'prayer_controller.dart';
import 'prayer_copy.dart';

Future<void> showPrayerLocationSetup(
  BuildContext context,
  PrayerController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => PrayerLocationSetupSheet(controller: controller),
);

class PrayerLocationSetupSheet extends StatefulWidget {
  const PrayerLocationSetupSheet({super.key, required this.controller});
  final PrayerController controller;
  @override
  State<PrayerLocationSetupSheet> createState() =>
      _PrayerLocationSetupSheetState();
}

class _PrayerLocationSetupSheetState extends State<PrayerLocationSetupSheet> {
  final query = TextEditingController();
  final nameForm = GlobalKey<FormState>();
  String? label;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), c = widget.controller;
    final language = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.prayerAddLocation,
                        style: Theme.of(context).textTheme.titleLarge,
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (c.failure != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(prayerFailureMessage(l, c.failure!)),
                        ),
                      ),
                    if (c.candidate != null) ...[
                      if (c.candidate!['approximate'] == true)
                        Text(l.prayerApproximate),
                      Text(
                        [
                              c.candidate!['city'],
                              c.candidate!['region'],
                              c.candidate!['countryCode'],
                            ]
                            .whereType<String>()
                            .where((v) => v.isNotEmpty)
                            .join(', '),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (c.candidate!['city'] == null ||
                          c.candidate!['city'] == '')
                        Text(
                          [
                            c.candidate!['latitude'],
                            c.candidate!['longitude'],
                          ].join(', '),
                        ),
                      Text(
                        c.candidate!['timezoneId'] as String? ??
                            l.prayerUnavailable,
                      ),
                      const SizedBox(height: 12),
                      Form(
                        key: nameForm,
                        child: TextFormField(
                          key: ObjectKey(c.candidate),
                          maxLength: 80,
                          initialValue:
                              (c.candidate!['city'] as String?)?.isNotEmpty ==
                                  true
                              ? c.candidate!['city'] as String
                              : [
                                  (c.candidate!['latitude'] as num)
                                      .toStringAsFixed(3),
                                  (c.candidate!['longitude'] as num)
                                      .toStringAsFixed(3),
                                ].join(', '),
                          decoration: InputDecoration(
                            labelText: l.prayerLocationLabel,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) => prayerLabelError(l, value),
                          onSaved: (value) => label = value!.trim(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: c.busy
                            ? null
                            : () async {
                                if (!nameForm.currentState!.validate()) return;
                                nameForm.currentState!.save();
                                await c.confirmCandidate(label: label);
                                if (context.mounted &&
                                    c.failure == null &&
                                    c.candidate == null) {
                                  Navigator.pop(context);
                                }
                              },
                        child: Text(l.prayerConfirmLocation),
                      ),
                      TextButton(
                        onPressed: c.busy ? null : c.discardCandidate,
                        child: Text(l.prayerChangeLocation),
                      ),
                    ] else ...[
                      Text(l.prayerLocationDisclosure),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: c.busy ? null : () => c.detect(language),
                        icon: const Icon(Icons.my_location),
                        label: Text(l.prayerDetectLocation),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        enabled: !c.busy,
                        controller: query,
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: l.prayerSearchCity,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (q) => unawaited(c.search(q, language)),
                      ),
                      if (query.text.trim().length >= 2 &&
                          c.results.isEmpty &&
                          c.failure == null &&
                          !c.busy &&
                          !c.searching)
                        Text(l.prayerNoResults),
                      for (final place in c.results)
                        ListTile(
                          title: Text(place['city'] as String? ?? ''),
                          subtitle: Text(
                            [place['region'], place['countryCode']]
                                .whereType<String>()
                                .where((v) => v.isNotEmpty)
                                .join(', '),
                          ),
                          onTap: c.busy
                              ? null
                              : () => c.choose(place, language: language),
                        ),
                      const Divider(height: 32),
                      Text(l.prayerIpDisclosure),
                      OutlinedButton(
                        onPressed: c.busy
                            ? null
                            : () => c.approximate(language),
                        child: Text(l.prayerApproximateLocation),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.prayerGeoNamesAttribution,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
