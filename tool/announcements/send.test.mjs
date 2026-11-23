// Writing and sending (specs/018 Story 1, FR-004 to FR-013).
import test from 'node:test';
import assert from 'node:assert/strict';

import { environment, fakeGoogle, message, owner } from './support.mjs';

const NOW = Date.UTC(2026, 10, 23, 12);

test('a valid message is stored and sent once, as the 015 contract describes', async () => {
  const { call, google } = owner({ now: () => NOW });
  const r = await call({ method: 'POST', body: message({ title: '  عنوان  ', body: ' نص ' }) });
  assert.equal(r.status, 201);
  assert.equal(r.body.status, 'sent');
  assert.equal(r.body.message, 'projects/mthani/messages/1');
  assert.equal(r.body.title, 'عنوان');
  assert.equal(r.body.body, 'نص');
  assert.equal(r.body.sentBy, 'owner@example.com');
  assert.equal(r.body.createdAt, NOW);
  assert.equal(google.sends.length, 1);
  assert.deepEqual(JSON.parse(google.sends[0].body), {
    message: {
      topic: 'all',
      notification: { title: 'عنوان', body: 'نص' },
      android: { ttl: '86400s', notification: { channel_id: 'announcements_v1' } },
      apns: { headers: { 'apns-expiration': String(NOW / 1000 + 86400) } },
    },
  });
});

test('each audience goes to its topic', async () => {
  for (const audience of ['all', 'lang_ar', 'lang_en']) {
    const { call, google } = owner();
    await call({ method: 'POST', body: message({ audience }) });
    assert.equal(JSON.parse(google.sends[0].body).message.topic, audience);
  }
});

test('fields outside the rules → 422 with the field, nothing stored or sent', async () => {
  const { call, google } = owner();
  const bad = [
    [{ title: '' }, 'title'], [{ title: '    ' }, 'title'], [{ title: 'a'.repeat(66) }, 'title'],
    [{ body: '' }, 'body'], [{ body: ' \n ' }, 'body'], [{ body: 'ب'.repeat(241) }, 'body'],
    [{ title: 5 }, 'title'], [{ audience: 'lang_fr' }, 'audience'], [{ audience: undefined }, 'audience'],
    [{ requestId: undefined }, 'requestId'], [{ requestId: 42 }, 'requestId'], [{ requestId: 'short' }, 'requestId'],
  ];
  for (const [over, field] of bad) {
    const r = await call({ method: 'POST', body: message(over) });
    assert.equal(r.status, 422, JSON.stringify(over));
    assert.deepEqual(r.body, { error: 'invalid', field });
  }
  assert.equal(google.calls.length, 0);
  assert.equal((await call()).body.announcements.length, 0);
});

test('limits count code points: 65 and 240 Arabic characters with marks pass', async () => {
  const { call } = owner();
  const title = 'بِ'.repeat(32) + 'ب'; // 65 code points
  const body = 'سَ'.repeat(120); // 240 code points
  assert.equal((await call({ method: 'POST', body: message({ title, body }) })).status, 201);
  assert.equal((await call({ method: 'POST', body: message({ title: title + 'ب' }) })).status, 422);
});

test('the same requestId twice sends once and returns the stored row', async () => {
  const { call, google } = owner();
  const body = message();
  const first = await call({ method: 'POST', body });
  const second = await call({ method: 'POST', body });
  assert.equal(first.status, 201);
  assert.equal(second.status, 200);
  assert.deepEqual(second.body, first.body);
  assert.equal(google.sends.length, 1);
  assert.equal((await call()).body.announcements.length, 1);
});

test('two requests with one requestId at the same time send once', async () => {
  const { call, google } = owner();
  const body = message();
  const [a, b] = await Promise.all([call({ method: 'POST', body }), call({ method: 'POST', body })]);
  assert.deepEqual([a.status, b.status].sort(), [200, 201]);
  assert.equal(google.sends.length, 1);
});

test('a failed send is recorded with its status (201)', async () => {
  const google = fakeGoogle();
  google.fcm = { status: 400, body: { error: { status: 'INVALID_ARGUMENT', message: 'bad' } } };
  const { call } = owner({ google });
  const r = await call({ method: 'POST', body: message() });
  assert.equal(r.status, 201);
  assert.equal(r.body.status, 'rejected');
  assert.match(r.body.detail, /INVALID_ARGUMENT/);
});

test('without the secret: notConfigured, no call to Google, and GET says so', async () => {
  const { call, google } = owner({ env: environment({ configured: false }) });
  assert.equal((await call()).body.configured, false);
  const r = await call({ method: 'POST', body: message() });
  assert.equal(r.status, 201);
  assert.equal(r.body.status, 'notConfigured');
  assert.equal(google.calls.length, 0);
});

test('10 sends an hour, then 429 with when it resets; failures and old rows do not count', async () => {
  let now = NOW;
  const google = fakeGoogle();
  const { call } = owner({ google, now: () => now });
  // One send two hours ago does not count.
  now = NOW - 120 * 60_000;
  await call({ method: 'POST', body: message() });
  // A failed send does not count.
  now = NOW - 50 * 60_000;
  google.fcm = { status: 503, body: {} };
  await call({ method: 'POST', body: message() });
  google.fcm = null;
  for (let i = 0; i < 10; i += 1) {
    now = NOW - (40 - i) * 60_000;
    assert.equal((await call({ method: 'POST', body: message() })).status, 201);
  }
  now = NOW;
  const stored = (await call()).body;
  assert.equal(stored.limit.used, 10);
  assert.equal(stored.limit.retryAt, NOW - 40 * 60_000 + 3_600_000);
  const r = await call({ method: 'POST', body: message() });
  assert.equal(r.status, 429);
  assert.deepEqual(r.body, { error: 'limit', retryAt: NOW - 40 * 60_000 + 3_600_000 });
  assert.equal((await call()).body.announcements.length, 12);
  now = NOW + 20 * 60_000 + 1;
  assert.equal((await call({ method: 'POST', body: message() })).status, 201);
});

test('GET reports configured and the limit without calling Google', async () => {
  const { call, google } = owner();
  const r = await call();
  assert.deepEqual(r.body, { configured: true, limit: { perHour: 10, used: 0, retryAt: null }, announcements: [] });
  assert.equal(google.calls.length, 0);
});
