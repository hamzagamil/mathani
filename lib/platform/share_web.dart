import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:share_plus/share_plus.dart';

/// Whether the browser has a share sheet (Safari, Chrome on Android; not Firefox on desktop).
bool get canShareText => globalContext.getProperty<JSObject>('navigator'.toJS).has('share');

Future<void> shareText(String text) => SharePlus.instance.share(ShareParams(text: text));
