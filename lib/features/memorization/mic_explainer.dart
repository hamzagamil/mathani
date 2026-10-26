// Why memorization needs the microphone, before the system asks (specs/006 FR-010,
// contracts/memorization-ui.md › Microphone explainer).
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../platform/device.dart';
import '../../shared/mathani_icons.dart';

/// True when the reader chose Continue: the system prompt comes next.
Future<bool> showMicExplainer(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final colors = MathaniColors.of(context);
  final ok = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(MathaniIcons.mic, size: 32, color: colors.accentInk),
            const SizedBox(height: Space.s3),
            Text(l10n.micExplainerTitle,
                textAlign: TextAlign.center, style: TypeScale.titleLg.copyWith(color: colors.ink)),
            const SizedBox(height: Space.s2),
            Text(l10n.micExplainerBody,
                textAlign: TextAlign.center, style: TypeScale.body.copyWith(color: colors.inkMuted)),
            const SizedBox(height: Space.s4),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.micExplainerContinue),
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}

/// «لا يمكن بدء الحفظ دون الميكروفون.», with a way to the system settings where the
/// microphone can be allowed again. A page cannot open the browser's settings, so in a browser
/// it says where to allow it instead (specs/008 FR-023).
void showMicDenied(BuildContext context, {DeviceChannel device = const DeviceChannel()}) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(kIsWeb ? l10n.micDeniedBrowser : l10n.micDenied),
      duration: const Duration(seconds: kIsWeb ? 10 : 6),
      action: kIsWeb
          ? null
          : SnackBarAction(label: l10n.openSystemSettings, onPressed: device.openAppSettings),
    ));
}
