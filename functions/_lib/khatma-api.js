// /api/khatma/* (specs/014 contracts/group-api.md): the rules every request follows, then the
// endpoints. The key travels in X-Mathani-Key; the server works with its SHA-256 only.
import { hashKey, khatmaStore } from './khatma-store.js';

const keyPattern = /^[A-Za-z0-9_-]{43}$/;
const maxBody = 2048;

const json = (status, body, headers = {}) =>
  new Response(body == null ? null : JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'private, no-store',
      ...headers,
    },
  });

export async function dispatch(request, env, { now } = {}) {
  const db = env.KHATMA_DB;
  if (!db) return json(503, { error: 'unavailable' });
  const store = khatmaStore(db, now);
  const method = request.method;
  const write = method !== 'GET' && method !== 'HEAD';

  const rawKey = request.headers.get('X-Mathani-Key');
  if (rawKey != null && !keyPattern.test(rawKey)) return json(401, { error: 'key' });
  if (write && rawKey == null) return json(401, { error: 'key' });
  const keyHash = rawKey == null ? null : await hashKey(rawKey);

  let body = {};
  if (write) {
    const origin = request.headers.get('Origin');
    if (origin && origin !== new URL(request.url).origin) return json(403, { error: 'origin' });
    const text = await request.text();
    if (new TextEncoder().encode(text).length >= maxBody) return json(413, { error: 'size' });
    if (text) {
      if (!(request.headers.get('Content-Type') ?? '').startsWith('application/json')) {
        return json(415, { error: 'json' });
      }
      try {
        body = JSON.parse(text);
      } catch {
        return json(400, { error: 'json' });
      }
      if (body === null || typeof body !== 'object' || Array.isArray(body)) return json(400, { error: 'json' });
    }
  }

  const path = new URL(request.url).pathname.replace(/^\/api\/khatma\/?/, '').split('/').filter(Boolean)
    .map(decodeURIComponent);
  const [code, a, b, c] = path;
  const route = [method, code ? ':code' : '', a ?? '', b ? ':id' : '', c ?? ''].filter(Boolean).join(' ');

  let result;
  switch (route) {
    case 'POST':
      result = await store.create(body, keyHash);
      break;
    case 'GET :code': {
      const k = await store.khatma(code);
      if (!k) return json(404, { error: 'gone' });
      const etag = `"v${k.version}"`;
      if (request.headers.get('If-None-Match') === etag) {
        return new Response(null, { status: 304, headers: { ETag: etag, 'Cache-Control': 'private, no-store' } });
      }
      return json(200, await store.snapshot(code, keyHash), { ETag: etag });
    }
    case 'POST :code parts :id take':
      result = await store.take(code, b, body, keyHash);
      break;
    case 'POST :code parts :id release':
      result = await store.release(code, b, keyHash);
      break;
    case 'POST :code parts :id read':
      result = await store.markRead(code, b, body, keyHash);
      break;
    case 'POST :code parts :id assign':
      result = await store.assign(code, b, body, keyHash);
      break;
    case 'POST :code leave':
      result = await store.leave(code, keyHash);
      break;
    case 'POST :code participants :id remove':
      result = await store.removeParticipant(code, b, keyHash);
      break;
    case 'PATCH :code':
      result = await store.patch(code, body, keyHash);
      break;
    case 'DELETE :code':
      result = await store.remove(code, keyHash);
      break;
    case 'POST :code report':
      result = await store.report(code, body, keyHash);
      break;
    default:
      return json(404, { error: 'notFound' });
  }
  if (result.status === 204 || result.status === 202) return json(result.status, null);
  const headers = result.body?.version ? { ETag: `"v${result.body.version}"` } : {};
  return json(result.status, result.body, headers);
}
