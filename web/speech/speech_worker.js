// The memorization speech worker (specs/008 research R10, contracts/web-platform.md › Speech
// worker). Recognition runs here, off the page's thread, on sherpa-onnx 1.13.8's own WebAssembly
// build: the files the sherpa_onnx_web package puts in the web build, the same version the phones
// run. They are loaded with importScripts (the package's own loader uses eval, which the site's
// Content-Security-Policy does not allow). The live-follow logic is the app's Dart code,
// compiled into speech_worker.dart.js (tool/web_deploy.mjs).
const sherpaBase = '../assets/packages/sherpa_onnx_web/assets/';
importScripts(
  sherpaBase + 'sherpa-onnx-wasm-web.js',
  sherpaBase + 'sherpa-onnx-asr.js',
  sherpaBase + 'sherpa-onnx-vad.js',
);

// The wrappers' classes are this worker's globals but not properties of `self`, so they are
// handed to the Dart side here.
self.mathaniSherpa = {
  // Resolves to the Emscripten module; the .wasm is fetched next to the glue.
  load: () => SherpaOnnx({ locateFile: (file) => sherpaBase + file }),
  createVad: (module, config) => new Vad(config, module),
  createRecognizer: (module, config) => new OfflineRecognizer(config, module),
};

importScripts('speech_worker.dart.js');
