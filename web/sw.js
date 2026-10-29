// Offline use for get.mthani.app (specs/008 research R9). tool/web_deploy.mjs stamps the version,
// the build id and the small shell list into this file.
//
// - Per build (cache `shell-<build>`): the small shell is precached; the app build and engine
//   files are cached when this browser uses them (it needs only one of the WebAssembly and
//   JavaScript builds, and one engine variant). The first visit loads them before this worker
//   exists, so the page reports what it loaded and they are cached then.
// - Across builds (cache `assets`): page fonts and the speech engine, cached as they are first
//   used and dropped only when their hash changes (asset-hashes.json).
// - Recordings and the recognition model are not handled here: the app writes them to the
//   browser's file system (research R7).
// - A new build waits until no tab uses the old one, then takes over on the next load (FR-019).
const VERSION = '__VERSION__';
const SHELL = `shell-${VERSION}-__BUILD__`;
const ASSETS = 'assets';
const PRECACHE = self.__PRECACHE;

const isAsset = (path) => path.startsWith('assets/') || path.startsWith('speech/');

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(SHELL).then((cache) => cache.addAll(PRECACHE)));
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith('shell-') && name !== SHELL) await caches.delete(name);
    }
    // Drop assets whose content changed in this build.
    try {
      const hashes = await assetHashes();
      const cache = await caches.open(ASSETS);
      for (const request of await cache.keys()) {
        const stored = (await cache.match(request)).headers.get('x-mathani-hash');
        if (stored !== hashes[pathOf(request.url)]) await cache.delete(request);
      }
    } catch (e) {
      // Offline while activating: the assets are checked again next time.
    }
    await self.clients.claim();
  })());
});

// The page lists the same-origin files it loaded before this worker controlled it.
self.addEventListener('message', (event) => {
  if (event.data?.type !== 'loaded' || !Array.isArray(event.data.urls)) return;
  event.waitUntil(Promise.all(event.data.urls.map(async (url) => {
    const u = new URL(url);
    if (u.origin !== self.location.origin) return;
    const path = pathOf(url);
    if (path.startsWith('api/prayer-')) return;
    const cacheName = isAsset(path) ? ASSETS : SHELL;
    if (await caches.match(url, { cacheName })) return;
    try {
      await keep(cacheName, new Request(url), path, await fetch(url));
    } catch (e) {
      // Offline now: cached on its next use.
    }
  })));
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (url.pathname.startsWith('/api/prayer-')) return;
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;
  if (request.headers.has('range')) return;
  if (request.mode === 'navigate') {
    // The page is cached as `./`: Netlify answers /index.html with a redirect to /.
    event.respondWith(fetch(request).catch(async () =>
      (await caches.match('./', { cacheName: SHELL })) ?? Response.error()));
    return;
  }
  const path = pathOf(request.url);
  event.respondWith(cacheFirst(isAsset(path) ? ASSETS : SHELL, request, path));
});

function pathOf(url) {
  return new URL(url).pathname.replace(/^\//, '');
}

async function cacheFirst(cacheName, request, path) {
  const hit = await caches.match(request, { cacheName });
  if (hit) return hit;
  const response = await fetch(request);
  await keep(cacheName, request, path, response.clone());
  return response;
}

/** Stores a successful response; assets carry their build hash for the activate check. */
async function keep(cacheName, request, path, response) {
  if (path.startsWith('api/prayer-') || response.headers.get('cache-control')?.includes('no-store')) return;
  if (!response.ok || path === 'sw.js' || path === 'asset-hashes.json') return;
  const cache = await caches.open(cacheName);
  if (cacheName !== ASSETS) return cache.put(request, response);
  const hash = (await assetHashes())[path];
  if (!hash) return;
  const headers = new Headers(response.headers);
  headers.set('x-mathani-hash', hash);
  await cache.put(request, new Response(await response.arrayBuffer(), { status: 200, headers }));
}

let hashesOnce;
function assetHashes() {
  hashesOnce ??= fetch('asset-hashes.json', { cache: 'no-cache' })
    .then((r) => r.json())
    .catch(() => ({}));
  return hashesOnce;
}
