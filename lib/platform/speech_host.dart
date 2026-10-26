// The memorization engine's platform parts (specs/008 contracts/web-platform.md › Speech worker):
// the recogniser (sherpa-onnx in an isolate on phones, its WebAssembly build in a Web Worker in
// browsers) and the model unpack (a background isolate on phones, the browser's streaming
// decompressor on the web).
export 'speech_host_io.dart' if (dart.library.js_interop) 'speech_host_web.dart';

/// How unpacking a downloaded `.gz` model file ended (specs/007 research R4).
enum UnpackResult {
  done,

  /// The `.gz` is not what was published: download it again.
  badDownload,

  /// The unpacked file does not match its pinned size and hash.
  badResult,
  noSpace,
}
