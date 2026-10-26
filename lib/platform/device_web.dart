import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'device.dart' show NetworkState, WebSupport;

/// Device facts in a browser (specs/008 research R16). Until each story fills its part in, a
/// member answers as the phone channel does when it is missing: online and unmetered, ample
/// storage, and actions that do nothing.
bool _keepAsked = false;

/// The mistake tone (research R11).
const mistakeToneHz = 880.0;
const mistakeToneMs = 120;

/// The smallest module using a SIMD instruction: valid only where WebAssembly SIMD is supported.
final _simdProbe = Uint8List.fromList([
  0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 96, 0, 1, 123, 3, 2, 1, 0, 10, 10, 1, 8, 0, 65, 0, 253, //
  15, 253, 98, 11,
]);

class DeviceChannel {
  const DeviceChannel();

  /// Offline when the browser says so; metered only where it can tell (Chromium on Android
  /// reports cellular or Data Saver), so elsewhere downloads do not ask first (research R16).
  Future<NetworkState> networkState() async {
    final navigator = _navigator;
    if (!navigator.onLine) return NetworkState.none;
    final connection = navigator.connection;
    if (connection != null && (connection.type == 'cellular' || (connection.saveData ?? false))) {
      return NetworkState.metered;
    }
    return NetworkState.unmetered;
  }

  Future<int> freeBytes() async => 1 << 40;

  /// Browsers have no backups to keep files out of.
  Future<void> excludeFromBackup(String path) async {}

  /// Phones only: browsers answer through [webSupport].
  Future<({bool arm64, int ramBytes})> deviceSupport() async => (arm64: true, ramBytes: 1 << 40);

  /// What memorization needs from the browser (research R10): WebAssembly SIMD, AudioWorklet
  /// for the microphone, the private file system for the model, and the memory where reported.
  Future<WebSupport?> webSupport() async {
    bool has(String name) => globalContext.has(name);
    final storage = _navigator.storage as JSObject?;
    final memory = (_navigator as JSObject).getProperty<JSNumber?>('deviceMemory'.toJS);
    return (
      wasmSimd: _webAssembly.validate(_simdProbe.toJS),
      audioWorklet: has('AudioWorkletNode'),
      opfs: storage != null && storage.has('getDirectory'),
      deviceMemoryGb: memory?.toDartDouble.floor(),
    );
  }

  /// Asks the browser once per page load to keep this site's data under storage pressure
  /// (specs/008 FR-014): called on the first bookmark and the first download, so Firefox's prompt
  /// comes in context. Browsers remember the answer.
  Future<void> keepBrowserData() async {
    if (_keepAsked) return;
    _keepAsked = true;
    try {
      final storage = _navigator.storage;
      if (!(await storage.persisted().toDart).toDart) await storage.persist().toDart;
    } on Object {
      // Not offered by this browser: data stays best-effort.
    }
  }

  /// A page cannot open the browser's settings; the explainer shows the steps instead.
  Future<void> openAppSettings() async {}

  /// A short sine through Web Audio, at the phone tone's pitch and length (research R11).
  Future<void> playMistakeTone() async {
    try {
      final audio = _AudioContext();
      final tone = audio.createOscillator()..frequency.value = mistakeToneHz;
      final gain = audio.createGain();
      final now = audio.currentTime;
      final end = now + mistakeToneMs / 1000;
      gain.gain
        ..setValueAtTime(0.0001, now)
        ..exponentialRampToValueAtTime(0.5, now + 0.01)
        ..exponentialRampToValueAtTime(0.0001, end);
      tone.connect(gain);
      gain.connect(audio.destination);
      tone
        ..start(now)
        ..stop(end);
      tone.onended = (() => audio.close()).toJS;
    } on Object {
      // No audio output: the mistake still shows on the page.
    }
  }
}

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external bool get onLine;
  external _Connection? get connection;
  external _Storage get storage;
}

@JS('WebAssembly')
external _WebAssembly get _webAssembly;

extension type _WebAssembly._(JSObject _) implements JSObject {
  external bool validate(JSUint8Array bytes);
}

@JS('AudioContext')
extension type _AudioContext._(JSObject _) implements JSObject {
  external factory _AudioContext();
  external double get currentTime;
  external JSObject get destination;
  external _Oscillator createOscillator();
  external _Gain createGain();
  external JSPromise<JSAny?> close();
}

extension type _Param._(JSObject _) implements JSObject {
  external set value(double v);
  external void setValueAtTime(double value, double time);
  external void exponentialRampToValueAtTime(double value, double time);
}

extension type _Oscillator._(JSObject _) implements JSObject {
  external _Param get frequency;
  external void connect(JSObject node);
  external void start(double when);
  external void stop(double when);
  external set onended(JSFunction f);
}

extension type _Gain._(JSObject _) implements JSObject {
  external _Param get gain;
  external void connect(JSObject node);
}

extension type _Storage._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> persisted();
  external JSPromise<JSBoolean> persist();
}

extension type _Connection._(JSObject _) implements JSObject {
  external String? get type;
  external bool? get saveData;
}
