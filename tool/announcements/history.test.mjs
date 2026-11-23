// What has been sent (specs/018 Story 3, FR-014, FR-015).
import test from 'node:test';
import assert from 'node:assert/strict';

import { fakeGoogle, message, owner } from './support.mjs';

test('history lists every attempt newest first with every field', async () => {
  let now = 1_000_000;
  const google = fakeGoogle();
  const { call } = owner({ google, now: () => now });
  await call({ method: 'POST', body: message({ title: 'one', audience: 'lang_ar' }) });
  now += 1000;
  google.fcm = { status: 503, body: {} };
  await call({ method: 'POST', body: message({ title: 'two', link: 'https://mthani.app/' }) });
  google.fcm = null;
  now += 1000;
  await call({ method: 'POST', body: message({ title: 'three', ttl: 3600 }) });
  const list = (await call()).body.announcements;
  assert.deepEqual(list.map((a) => a.title), ['three', 'two', 'one']);
  assert.deepEqual(Object.keys(list[1]).sort(),
    ['audience', 'body', 'createdAt', 'detail', 'id', 'link', 'message', 'sentBy', 'status', 'title', 'ttl']);
  assert.equal(list[1].status, 'unavailable');
  assert.equal(list[1].link, 'https://mthani.app/');
  assert.equal(list[1].message, null);
  assert.equal(list[2].audience, 'lang_ar');
  assert.equal(list[0].ttl, 3600);
});

test('at most 100 rows; a row still sending is shown as sending', async () => {
  const { call, env } = owner();
  const insert = env.DB.prepare(
    'INSERT INTO announcements (request_id, audience, title, body, ttl, sent_by, created_at, status) ' +
    "VALUES (?, 'all', ?, 'b', 86400, 'owner@example.com', ?, ?)");
  for (let i = 0; i < 105; i += 1) {
    await insert.bind(`request-${i}`, `t${i}`, 1000 + i, i === 104 ? 'sending' : 'sent').run();
  }
  const list = (await call()).body.announcements;
  assert.equal(list.length, 100);
  assert.equal(list[0].title, 't104');
  assert.equal(list[0].status, 'sending');
  assert.equal(list[99].title, 't5');
});
