// How long a message may still be delivered (specs/018 Story 4, FR-007).
import test from 'node:test';
import assert from 'node:assert/strict';

import { message, owner } from './support.mjs';

const NOW = Date.UTC(2026, 10, 23, 12);

test('each allowed period sets the Android TTL and the APNs expiry', async () => {
  for (const ttl of [3600, 86400, 604800, 2419200]) {
    const { call, google } = owner({ now: () => NOW });
    const r = await call({ method: 'POST', body: message({ ttl }) });
    assert.equal(r.body.ttl, ttl);
    const sent = JSON.parse(google.sends[0].body).message;
    assert.equal(sent.android.ttl, `${ttl}s`);
    assert.equal(sent.apns.headers['apns-expiration'], String(NOW / 1000 + ttl));
  }
});

test('no period → 1 day', async () => {
  const { call } = owner();
  assert.equal((await call({ method: 'POST', body: message() })).body.ttl, 86400);
});

test('other periods → 422 ttl', async () => {
  const { call, google } = owner();
  for (const ttl of [0, 1800, '86400', 2419201, -3600]) {
    const r = await call({ method: 'POST', body: message({ ttl }) });
    assert.deepEqual(r.body, { error: 'invalid', field: 'ttl' }, String(ttl));
  }
  assert.equal(google.calls.length, 0);
});
