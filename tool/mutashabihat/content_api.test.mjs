// GET /api/mutashabihat (specs/011 contracts/content-api.md).
import test from 'node:test';
import assert from 'node:assert/strict';
import { serveContent } from '../../functions/_lib/content-api.js';
import { dispatch } from '../../functions/_lib/editor-api.js';
import { parse, sha256Hex } from '../../functions/_lib/mutashabihat-content.js';
import { accessKeys, environment, memoryCache, request, shippedMarkdown } from './support.mjs';

const keys = accessKeys();

test('nothing published, then a version, 304, and a newer version after the minute', async () => {
  const env = environment();
  const cache = memoryCache();
  let clock = 10_000;
  const get = (etag) =>
    serveContent(request('/api/mutashabihat', { headers: etag ? { 'If-None-Match': etag } : {} }), env,
      { cache, now: () => clock });
  const editor = (path, body, method = 'POST') =>
    dispatch(request(`/api/editor/${path}`, { method, body, token: keys.sign({ email: env.OWNER_EMAIL }) }), env,
      { fetchCerts: keys.fetchCerts, now: () => clock });

  const none = await get();
  assert.equal(none.status, 404);
  assert.deepEqual(await none.json(), { error: 'notPublished' });

  clock += 61_000;
  assert.equal((await editor('import', { markdown: shippedMarkdown() })).status, 201);
  const v1 = await get();
  assert.equal(v1.status, 200);
  assert.equal(v1.headers.get('content-type'), 'text/markdown; charset=utf-8');
  assert.equal(v1.headers.get('etag'), '"v1"');
  assert.equal(v1.headers.get('x-content-version'), '1');
  assert.equal(v1.headers.get('x-content-format'), '1');
  assert.equal(v1.headers.get('cache-control'), 'public, max-age=300');
  const body = await v1.text();
  assert.equal(v1.headers.get('x-content-sha256'), await sha256Hex(body));
  assert.equal(parse(body).version, 1);
  assert.equal(parse(body).groups.length, 72);

  const same = await get('"v1"');
  assert.equal(same.status, 304);
  assert.equal(await same.text(), '');

  // Publish v2: served once the cached current number is older than a minute.
  const groups = await (await editor('groups', undefined, 'GET')).json();
  const g = groups.groups[0];
  await editor(`groups/${g.id}`, { ayat: g.ayat, note: g.note, explanation: 'جديد', revision: g.revision }, 'PUT');
  await editor('publish', { expect: [g.id] });
  assert.equal((await get('"v1"')).status, 304, 'within the minute');
  clock += 61_000;
  const v2 = await get('"v1"');
  assert.equal(v2.status, 200);
  assert.equal(v2.headers.get('etag'), '"v2"');
  assert.equal((await get('W/"v2"')).status, 304);
});

test('storage trouble: 503 with Retry-After', async () => {
  const broken = { prepare() { throw new Error('down'); } };
  const r = await serveContent(request('/api/mutashabihat'), { ...environment(), DB: broken }, { cache: memoryCache() });
  assert.equal(r.status, 503);
  assert.equal(r.headers.get('retry-after'), '600');
  // Before the database exists nothing is published.
  assert.equal((await serveContent(request('/api/mutashabihat'), {}, { cache: memoryCache() })).status, 404);
});
