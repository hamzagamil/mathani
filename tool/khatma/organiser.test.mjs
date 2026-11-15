// For people who do not use the link (specs/014 Story 7): typed names, marking any part, and
// changing the title and the finish date.
import test from 'node:test';
import assert from 'node:assert/strict';

import { server } from './support.mjs';

test('assign: a typed name holds a free part; taken; invalid; organiser only', async () => {
  const s = server();
  const k = await s.start();
  const r = await s.call(`/${k.code}/parts/4/assign`, { method: 'POST', as: 1, body: { name: 'Grandmother' } });
  assert.equal(r.status, 200);
  const holder = r.body.participants.find((p) => p.id === r.body.parts[3].holder);
  assert.equal(holder.name, 'Grandmother');
  assert.equal(holder.typed, true);
  const row = s.db.raw.prepare('SELECT key_hash FROM participants WHERE id = ?').get(holder.id);
  assert.equal(row.key_hash, null);
  assert.equal((await s.call(`/${k.code}/parts/4/assign`, { method: 'POST', as: 1, body: { name: 'Other' } })).body.error, 'taken');
  assert.equal((await s.call(`/${k.code}/parts/5/assign`, { method: 'POST', as: 1, body: { name: 'www.x.com' } })).status, 422);
  assert.equal((await s.call(`/${k.code}/parts/5/assign`, { method: 'POST', as: 2, body: { name: 'Uncle' } })).body.error, 'organiser');
});

test('the organiser marks any taken part read and not read, also after completion', async () => {
  const s = server();
  const k = await s.start();
  await s.take(k.code, 1, 2);
  const read = await s.call(`/${k.code}/parts/1/read`, { method: 'POST', as: 1, body: { read: true } });
  assert.equal(read.body.parts[0].state, 'read');
  const unread = await s.call(`/${k.code}/parts/1/read`, { method: 'POST', as: 1, body: { read: false } });
  assert.equal(unread.body.parts[0].state, 'taken');
  for (let n = 1; n <= 30; n++) {
    if (n > 1) await s.call(`/${k.code}/parts/${n}/assign`, { method: 'POST', as: 1, body: { name: `Name ${n}` } });
    await s.call(`/${k.code}/parts/${n}/read`, { method: 'POST', as: 1, body: { read: true } });
  }
  const complete = (await s.call(`/${k.code}`)).body;
  assert.ok(complete.completedAt);
  const reopened = await s.call(`/${k.code}/parts/7/read`, { method: 'POST', as: 1, body: { read: false } });
  assert.equal(reopened.status, 200);
  assert.equal(reopened.body.completedAt, null);
});

test('a read part with no name: the organiser marks it not read and it is free', async () => {
  const s = server();
  const k = await s.start();
  await s.take(k.code, 1, 2);
  await s.call(`/${k.code}/parts/1/read`, { method: 'POST', as: 2, body: { read: true } });
  await s.call(`/${k.code}/leave`, { method: 'POST', as: 2 });
  const r = await s.call(`/${k.code}/parts/1/read`, { method: 'POST', as: 1, body: { read: false } });
  assert.equal(r.body.parts[0].state, 'free');
});

test('patch: the title and the finish date; checked; organiser only', async () => {
  const s = server();
  const k = await s.start();
  const r = await s.call(`/${k.code}`, { method: 'PATCH', as: 1, body: { title: 'Ramadan khatma', finishDate: '2026-03-20' } });
  assert.equal(r.status, 200);
  assert.equal(r.body.title, 'Ramadan khatma');
  assert.equal(r.body.finishDate, '2026-03-20');
  const cleared = await s.call(`/${k.code}`, { method: 'PATCH', as: 1, body: { finishDate: null } });
  assert.equal(cleared.body.finishDate, null);
  assert.equal((await s.call(`/${k.code}`, { method: 'PATCH', as: 1, body: { title: '' } })).body.problem.kind, 'empty');
  assert.equal((await s.call(`/${k.code}`, { method: 'PATCH', as: 2, body: { title: 'Mine' } })).body.error, 'organiser');
});

test('a typed name can be reported and removed like any other', async () => {
  const s = server();
  const k = await s.start();
  const r = await s.call(`/${k.code}/parts/2/assign`, { method: 'POST', as: 1, body: { name: 'Typed' } });
  const id = r.body.parts[1].holder;
  assert.equal((await s.call(`/${k.code}/report`, { method: 'POST', as: 3, body: { participant: id } })).status, 202);
  const removed = await s.call(`/${k.code}/participants/${id}/remove`, { method: 'POST', as: 1 });
  assert.equal(removed.body.parts[1].state, 'free');
});
