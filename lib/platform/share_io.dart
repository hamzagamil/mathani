import 'package:share_plus/share_plus.dart';

/// Phones always have a share sheet.
bool get canShareText => true;

Future<void> shareText(String text) => SharePlus.instance.share(ShareParams(text: text));
