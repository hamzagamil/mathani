{{flutter_js}}
{{flutter_build_config}}

// Engine settings (specs/008 research R1). Fallback fonts (for a character none of the bundled
// fonts has) come from this site's copy in font-fallback/, never from Google (FR-027). The
// engine asks for `<base>notosansarabic/v28/<file>.woff2` and the like, as Google lays them out.
const config = {
  fontFallbackBaseUrl: 'font-fallback/',
};

// Loads the WebAssembly build where the browser supports it, the JavaScript build elsewhere.
_flutter.loader.load({
  config: config,
  onEntrypointLoaded: async function (engineInitializer) {
    // With onEntrypointLoaded the settings must be passed again here, or they are dropped.
    const appRunner = await engineInitializer.initializeEngine(config);
    await appRunner.runApp();
    // After the app starts, so registering never delays the first frame (research R9). Private
    // windows in Firefox have no service workers: the app then works without offline use.
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('sw.js').then(function () {
        return navigator.serviceWorker.ready;
      }).then(function (registration) {
        // What this visit loaded before the worker existed: the app build and engine variant
        // this browser uses, the database and fonts. The worker keeps them for offline use.
        var urls = performance.getEntriesByType('resource').map(function (e) { return e.name; });
        registration.active.postMessage({ type: 'loaded', urls: urls });
      }).catch(function () {});
    }
  },
});
