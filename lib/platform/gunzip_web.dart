import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

/// Inflates gzip-compressed [gz] with the browser's DecompressionStream (dart:io's gzip is not
/// available in browsers).
Future<Uint8List> gunzip(Uint8List gz) async {
  final stream = _Response(gz.toJS).body.pipeThrough(_DecompressionStream('gzip'));
  final buffer = await _Response(stream).arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

/// Inflates a gzip stream as it arrives: chunks are written into a DecompressionStream while its
/// output is read, so a large file never sits in memory whole. Bad gzip is a [FormatException].
Stream<List<int>> gunzipStream(Stream<List<int>> gz) async* {
  final decompress = _DecompressionStream('gzip');
  final writer = decompress.writable.getWriter();
  final reader = decompress.readable.getReader();
  final feeding = () async {
    try {
      await for (final chunk in gz) {
        await writer.write((chunk is Uint8List ? chunk : Uint8List.fromList(chunk)).toJS).toDart;
      }
      await writer.close().toDart;
    } on Object {
      // The reader reports the failure.
    }
  }();
  try {
    while (true) {
      final step = await reader.read().toDart;
      if (step.done) break;
      yield (step.value! as JSUint8Array).toDart;
    }
  } on Object catch (e) {
    throw FormatException('Not gzip: $e');
  } finally {
    await feeding;
  }
}

@JS('Response')
extension type _Response._(JSObject _) implements JSObject {
  external factory _Response(JSAny body);
  external _ReadableStream get body;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type _ReadableStream._(JSObject _) implements JSObject {
  external _ReadableStream pipeThrough(JSObject transform);
  external _Reader getReader();
}

extension type _WritableStream._(JSObject _) implements JSObject {
  external _Writer getWriter();
}

extension type _Reader._(JSObject _) implements JSObject {
  external JSPromise<_Step> read();
}

extension type _Step._(JSObject _) implements JSObject {
  external bool get done;
  external JSAny? get value;
}

extension type _Writer._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> write(JSUint8Array chunk);
  external JSPromise<JSAny?> close();
}

@JS('DecompressionStream')
extension type _DecompressionStream._(JSObject _) implements JSObject {
  external factory _DecompressionStream(String format);
  external _ReadableStream get readable;
  external _WritableStream get writable;
}
