// gzip decompression on every platform (specs/008 contracts/web-platform.md › lib/platform/):
// dart:io on phones and in tests, the browser's DecompressionStream on the web.
export 'gunzip_io.dart' if (dart.library.js_interop) 'gunzip_web.dart';
