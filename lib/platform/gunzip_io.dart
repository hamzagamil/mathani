import 'dart:io' show gzip;
import 'dart:typed_data';

/// Inflates gzip-compressed [gz].
Future<Uint8List> gunzip(Uint8List gz) async => Uint8List.fromList(gzip.decode(gz));

/// Inflates a gzip stream as it arrives.
Stream<List<int>> gunzipStream(Stream<List<int>> gz) => gz.transform(gzip.decoder);
