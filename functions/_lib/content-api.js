// GET /api/mutashabihat (specs/011 contracts/content-api.md): the latest published content for
// the apps, served from the edge cache. D1 is asked for the current version about once a minute.
import { editorStore } from './editor-store.js';

const currentTtlMs = 60 * 1000;
const cacheKey = (name) => new Request(`https://get.mthani.app/__mutashabihat/${name}`);
const etagOf = (n) => `"v${n}"`;

const problem = (status, error, extra = {}) =>
  new Response(JSON.stringify({ error }), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...extra },
  });

async function currentNumber(store, cache, now) {
  const hit = await cache.match(cacheKey('current'));
  if (hit) {
    const { n, at } = await hit.json();
    if (now - at < currentTtlMs) return n;
  }
  const n = (await store.currentNumber()) ?? null;
  await cache.put(cacheKey('current'), new Response(JSON.stringify({ n, at: now }), {
    headers: { 'Cache-Control': 'public, max-age=60' },
  }));
  return n;
}

export async function serveContent(request, env, { cache, now = () => Date.now() }) {
  // No database yet: the editor is not set up, so nothing is published and apps keep their copy.
  if (!env.DB) return problem(404, 'notPublished');
  try {
    const store = editorStore(env.DB, now);
    const n = await currentNumber(store, cache, now());
    if (n === null) return problem(404, 'notPublished');
    const etag = etagOf(n);
    const common = { ETag: etag, 'Cache-Control': 'public, max-age=300' };
    const asked = (request.headers.get('If-None-Match') ?? '').replace(/^W\//, '');
    if (asked === etag) return new Response(null, { status: 304, headers: common });

    let hit = await cache.match(cacheKey(`v${n}`));
    if (!hit) {
      const row = await store.content(n);
      if (!row) return problem(503, 'unavailable', { 'Retry-After': '600' });
      hit = new Response(row.content, {
        headers: {
          ...common,
          'Content-Type': 'text/markdown; charset=utf-8',
          'X-Content-Version': String(row.number),
          'X-Content-Format': String(row.format),
          'X-Content-SHA256': row.sha256,
          'Cache-Control': 'public, max-age=31536000, immutable', // the cache copy; a version never changes
        },
      });
      await cache.put(cacheKey(`v${n}`), hit.clone());
    }
    const headers = new Headers(hit.headers);
    headers.set('Cache-Control', common['Cache-Control']);
    return new Response(hit.body, { status: 200, headers });
  } catch {
    return problem(503, 'unavailable', { 'Retry-After': '600' });
  }
}
