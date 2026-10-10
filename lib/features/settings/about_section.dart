import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../app/version.dart';
import '../../shared/mathani_icons.dart';

/// Registers the bundled font and icon licences so the licences page lists them.
void registerAssetLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final (packages, asset) in const [
      (['IBM Plex Sans Arabic'], 'assets/fonts/OFL-IBMPlexSansArabic.txt'),
      (['Amiri Quran'], 'assets/fonts/OFL-AmiriQuran.txt'),
      (['Lucide icons'], 'assets/fonts/LICENSE-Lucide.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks(packages, await rootBundle.loadString(asset));
    }
  });
}

/// Wraps [s] in a left-to-right isolate (U+2066 … U+2069) so it keeps its order in RTL text.
String _ltr(String s) => '${String.fromCharCode(0x2066)}$s${String.fromCharCode(0x2069)}';

/// Version, sources with the attributions their licences require, and the licences page.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  static final _tanzil = Uri.parse('https://tanzil.net');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = MathaniColors.of(context);
    final caption = TypeScale.caption.copyWith(color: colors.inkMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Image.asset('assets/images/mark_navy.png', width: 32, color: colors.ink),
          title: Text(l10n.appName),
          // Isolated left-to-right so + and dots keep their order in Arabic.
          subtitle: Text(l10n.versionLabel(_ltr(appVersion)), style: caption),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s4, 0),
          child: Text(l10n.sourcesTitle, style: TypeScale.titleSm.copyWith(color: colors.accentInk)),
        ),
        // Tanzil CC BY 3.0: name the source and link to tanzil.net.
        ListTile(
          title: Text(l10n.tanzilCredit),
          subtitle: Text('https://tanzil.net', style: caption.copyWith(color: colors.secondary)),
          trailing: const Icon(MathaniIcons.externalLink),
          onTap: () => launchUrl(_tanzil, mode: LaunchMode.externalApplication),
        ),
        ListTile(title: Text(l10n.qulCredit)),
        ListTile(title: Text(l10n.kfgqpcCredit)),
        ListTile(
          title: Text(l10n.licencesButton),
          trailing: const Icon(MathaniIcons.forward),
          onTap: () => showLicensePage(
            context: context,
            applicationName: l10n.appName,
            applicationVersion: appVersion,
          ),
        ),
      ],
    );
  }
}
