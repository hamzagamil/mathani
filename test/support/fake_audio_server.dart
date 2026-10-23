import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:mathani/data/models.dart';

/// A localhost stand-in for EveryAyah (specs/004 tests). Serves `/primary/<SSS><AAA>.mp3` and
/// `/mirror/<SSS><AAA>.mp3` with zero bytes of a deterministic size per ayah, and can be told to
/// fail, truncate or hold requests.
class FakeAudioServer {
  FakeAudioServer._(this._server) {
    _server.listen(_handle);
  }

  static Future<FakeAudioServer> start() async =>
      FakeAudioServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;

  /// Paths requested, in order.
  final requests = <String>[];
  HttpHeaders? lastHeaders;

  /// Every request answers 404.
  bool failAll = false;

  /// The primary host sends half the bytes.
  bool truncatePrimary = false;

  /// When set, requests wait for it to complete before answering.
  Completer<void>? hold;

  /// Paths that answer 404, e.g. `/primary/068000.mp3`.
  final failPaths = <String>{};

  /// Added to every answer, so concurrency can be observed.
  Duration delay = Duration.zero;

  int get port => _server.port;

  /// Size of each recording; by default small and distinct per ayah. Tests that use the real
  /// catalogue set it to the catalogue's sizes.
  int Function(int surah, int ayah) sizes = (s, a) => 1000 + s * 7 + a * 3;

  int sizeOf(int surah, int ayah) => sizes(surah, ayah);

  Reciter reciter({String id = 'test'}) => Reciter(
        id: id,
        nameAr: 'قارئ',
        nameEn: 'Reciter',
        shortAr: 'قارئ',
        shortEn: 'Reciter',
        style: 'murattal',
        baseUrl: 'http://127.0.0.1:$port/primary',
        mirrorUrl: 'http://127.0.0.1:$port/mirror',
        bitrateKbps: 64,
        sort: 1,
      );

  /// Requests being answered now, and the most at once.
  int inFlight = 0;
  int maxInFlight = 0;

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests.add(path);
    lastHeaders = request.headers;
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      await _answer(request, path);
    } finally {
      inFlight--;
    }
  }

  Future<void> _answer(HttpRequest request, String path) async {
    await hold?.future;
    await Future<void>.delayed(delay);
    final match = RegExp(r'/(primary|mirror)/(\d{3})(\d{3})\.mp3$').firstMatch(path);
    if (failAll || match == null || failPaths.contains(path)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    var size = sizeOf(int.parse(match.group(2)!), int.parse(match.group(3)!));
    if (truncatePrimary && match.group(1) == 'primary') size ~/= 2;
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('audio', 'mpeg')
      ..contentLength = size
      ..add(Uint8List(size));
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}
