// The rules every request follows (specs/014 contracts/group-api.md › Every request).
import test from 'node:test';
import assert from 'node:assert/strict';

import { server } from './support.mjs';

test('a write without a key, or with a malformed one, is refused', async () => {
  const s = server();
  const body = { title: 'T', name: 'N', division: 30, terms: 1 };
  assert.equal((await s.call('', { method: 'POST', body })).status, 401);
  const bad = await s.call('', { method: 'POST', body, as: 'short' });
  assert.equal(bad.status, 401);
  assert.deepEqual(bad.body, { error: 'key' });
});

test('a foreign Origin is refused', async () => {
  const s = server();
  const r = await s.call('', {
    method: 'POST', as: 1, origin: 'https://evil.example',
    body: { title: 'T', name: 'N', division: 30, terms: 1 },
  });
  assert.equal(r.status, 403);
  assert.deepEqual(r.body, { error: 'origin' });
});

test('a body of 2 KB or more is refused', async () => {
  const s = server();
  const r = await s.call('', { method: 'POST', as: 1, raw: JSON.stringify({ title: 'x'.repeat(2100) }),
    headers: { 'Content-Type': 'application/json' } });
  assert.equal(r.status, 413);
});

test('a body that is not JSON is refused', async () => {
  const s = server();
  const r = await s.call('', { method: 'POST', as: 1, raw: 'hello', headers: { 'Content-Type': 'text/plain' } });
  assert.equal(r.status, 415);
});

test('a malformed or unknown code is gone', async () => {
  const s = server();
  assert.deepEqual((await s.call('/not-a-code')).body, { error: 'gone' });
  assert.equal((await s.call('/0123456789ABCDEF')).status, 404);
});

test('responses are private and never stored', async () => {
  const s = server();
  const k = await s.start();
  const r = await s.call(`/${k.code}`);
  assert.equal(r.headers.get('Cache-Control'), 'private, no-store');
});

test('an older terms version is refused with the current one', async () => {
  const s = server();
  const r = await s.call('', { method: 'POST', as: 1, body: { title: 'T', name: 'N', division: 30, terms: 0 } });
  assert.equal(r.status, 422);
  assert.deepEqual(r.body, { error: 'terms', current: 1 });
});
