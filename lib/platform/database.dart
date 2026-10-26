// The databases on every platform (specs/008 contracts/web-platform.md › lib/platform/): files
// through sqflite on phones; SQLite compiled to WebAssembly, stored in IndexedDB, in browsers
// (research R4).
export 'database_io.dart' if (dart.library.js_interop) 'database_web.dart';
