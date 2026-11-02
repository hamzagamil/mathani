import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../../app/l10n/app_localizations.dart';
import 'prayer_controller.dart';
import 'prayer_copy.dart';
import 'prayer_models.dart';
import 'prayer_services.dart';
import 'prayer_time_zones.dart';

/// The Alerts sheet (Story 4–6; contracts › Screens). Closing it stops a preview.
Future<void> showPrayerAlerts(
  BuildContext context,
  PrayerController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .9,
    child: AlertsSheet(controller: controller),
  ),
).whenComplete(controller.stopSound);

class AlertsSheet extends StatefulWidget {
  const AlertsSheet({super.key, required this.controller});
  final PrayerController controller;
  @override
  State<AlertsSheet> createState() => _AlertsSheetState();
}

class _AlertsSheetState extends State<AlertsSheet> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.controller.hub.refill());
  }

  /// Back from the phone's settings: show the new permission state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.hub.refill());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([
        c,
        c.hub,
        c.services.player.playing,
        c.services.downloads,
      ]),
      builder: (context, _) => _content(context, c),
    );
  }

  Widget _content(BuildContext context, PrayerController c) {
    final l = AppLocalizations.of(context), theme = Theme.of(context);
    final s = c.state, alerts = s.alerts, place = s.currentPlace;
    final status = c.hub.status;
    final playing = c.services.player.playing.value;
    final catalogue = c.services.catalogue;
    final recording = catalogue.byId(alerts.sound);
    final editable = !c.busy && place != null;
    final android = !kIsWeb && c.hub.target == TargetPlatform.android;
    final ios = !kIsWeb && c.hub.target == TargetPlatform.iOS;
    String local(DateTime t) =>
        DateFormat.jm(l.localeName)
            .format(tz.TZDateTime.from(t, prayerTimeZone(place!.timezoneId)));
    final qiyam = c.nextQiyam;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(l.prayerAlerts, style: theme.textTheme.titleLarge),
              ),
              IconButton(
                tooltip: l.prayerCancel,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        if (playing != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton.icon(
              onPressed: c.stopSound,
              icon: const Icon(Icons.stop),
              label: Text(l.prayerAthanStop),
            ),
          ),
        if (c.busy) const LinearProgressIndicator(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            children: [
              if (place != null)
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(l.prayerAlertsFollow(place.name)),
                ),
              ..._statusLines(c, l, status, android),
              if (kIsWeb)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l.prayerWebLimit),
                  subtitle: _action(
                    l.prayerMobileApps,
                    () => launchUrl(Uri.parse('https://mthani.app')),
                  ),
                ),
              if (c.failure != null)
                ListTile(title: Text(prayerFailureMessage(l, c.failure!))),
              for (final kind in dailyPrayers)
                SwitchListTile(
                  key: ValueKey('alert-${kind.name}'),
                  title: Text(prayerName(l, kind)),
                  value: alerts.prayers.contains(kind),
                  onChanged: editable
                      ? (on) => c.setPrayerAlert(kind, on)
                      : null,
                ),
              const Divider(),
              _Heading(l.prayerSound),
              for (final sound in catalogue.soundChoices)
                _SoundRow(
                  name: prayerSoundName(l, catalogue, sound),
                  subtitle: catalogue.byId(sound)?.reciter,
                  selected: alerts.sound == sound,
                  playing: playing == sound,
                  canPreview: sound != silentSound,
                  l: l,
                  onSelect: editable ? () => c.setSound(sound) : null,
                  onPreview: () => c.preview(sound),
                  onStop: c.stopSound,
                ),
              if (recording != null) ...[
                const Divider(),
                _Heading(l.prayerAthanLength),
                RadioGroup<AthanLength>(
                  groupValue: alerts.athan,
                  onChanged: (v) {
                    if (v != null && editable) c.setAthanLength(v);
                  },
                  child: Column(
                    children: [
                      RadioListTile<AthanLength>(
                        value: AthanLength.opening,
                        title: Text(l.prayerAthanOpening),
                      ),
                      RadioListTile<AthanLength>(
                        value: AthanLength.full,
                        title: Text(l.prayerAthanFull),
                        subtitle: Text(
                          kIsWeb
                              ? l.prayerFullWeb
                              : ios
                              ? l.prayerFullIos
                              : l.prayerFullAndroid,
                        ),
                      ),
                    ],
                  ),
                ),
                if (alerts.athan == AthanLength.full)
                  _download(c, l, recording),
              ],
              const Divider(),
              SwitchListTile(
                key: const ValueKey('alert-qiyam'),
                title: Text(l.prayerQiyam),
                subtitle: Text(
                  qiyam == null
                      ? l.prayerQiyamUnavailable
                      : '${l.prayerQiyamUpcoming(local(qiyam))}\n${l.prayerQiyamExplanation}',
                ),
                isThreeLine: qiyam != null,
                value: alerts.qiyam,
                onChanged: editable ? c.setQiyam : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _statusLines(
    PrayerController c,
    AppLocalizations l,
    AlertStatus? status,
    bool android,
  ) {
    if (status == null || !c.state.alerts.any) return const [];
    return [
      if (status.notifications == NotificationPermission.denied)
        ListTile(
          leading: const Icon(Icons.notifications_off_outlined),
          title: Semantics(
            liveRegion: true,
            child: Text(l.prayerNotificationsDenied),
          ),
          subtitle: kIsWeb
              ? null
              : _action(l.prayerOpenSettings, c.openSettings),
        ),
      if (android && status.exactAlarms == false)
        ListTile(
          leading: const Icon(Icons.alarm_off_outlined),
          title: Semantics(liveRegion: true, child: Text(l.prayerExactOff)),
          subtitle: _action(
            l.prayerAllow,
            () => c.openSettings(exactAlarms: true),
          ),
        ),
    ];
  }

  Widget _download(
    PrayerController c,
    AppLocalizations l,
    AthanRecording recording,
  ) {
    final downloads = c.services.downloads;
    return switch (downloads.status(recording)) {
      DownloadStatus.ready => ListTile(
        leading: const Icon(Icons.download_done),
        title: Text(l.prayerAudioReady),
      ),
      DownloadStatus.downloading => ListTile(
        title: Text(l.prayerAudioDownloading),
        subtitle: LinearProgressIndicator(value: downloads.progress(recording)),
      ),
      final status => ListTile(
        leading: const Icon(Icons.download_outlined),
        title: Text(
          status == DownloadStatus.failed
              ? l.prayerAudioFailed
              : l.prayerFullNotDownloaded,
        ),
        subtitle: _action(
          status == DownloadStatus.failed ? l.prayerRetry : l.prayerDownload,
          c.busy ? null : c.downloadFull,
        ),
      ),
    };
  }
}

/// An action under a status line: beside it, large text would leave the line no room (FR-032).
Widget _action(String label, VoidCallback? onPressed) => Align(
  alignment: AlignmentDirectional.centerStart,
  child: TextButton(onPressed: onPressed, child: Text(label)),
);

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

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.playing,
    required this.canPreview,
    required this.l,
    required this.onSelect,
    required this.onPreview,
    required this.onStop,
  });
  final String name;
  final String? subtitle;
  final bool selected, playing, canPreview;
  final AppLocalizations l;
  final VoidCallback? onSelect, onPreview, onStop;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
    ),
    title: Text(name),
    subtitle: subtitle == null ? null : Text(subtitle!),
    selected: selected,
    onTap: onSelect,
    trailing: !canPreview
        ? null
        : IconButton(
            tooltip: playing ? l.prayerAthanStop : l.prayerPreview(name),
            icon: Icon(playing ? Icons.stop : Icons.play_arrow),
            onPressed: playing ? onStop : onPreview,
          ),
  );
}
