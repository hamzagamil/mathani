// The endpoints of Story 5 (specs/014 contracts/group-api.md › Endpoints): start, read, take,
// give back, mark, leave, and two callers taking one part (SC-015).
import test from 'node:test';
import assert from 'node:assert/strict';

import { codePattern } from '../../functions/_lib/khatma-store.js';
import { server } from './support.mjs';

test('start: 30 or 60 free parts, the organiser, a random code', async () => {
  const s = server();
  const k = await s.start({ finishDate: '2026-03-06' });
  assert.match(k.code, codePattern);
  assert.equal(k.division, 30);
  assert.equal(k.parts.length, 30);
  assert.deepEqual(k.counts, { free: 30, taken: 0, read: 0 });
  assert.equal(k.you.role, 'organiser');
  assert.equal(k.participants.length, 1);
  assert.equal(k.organiser, k.participants[0].id);
  assert.equal(k.finishDate, '2026-03-06');
  const sixty = await s.start({ as: 2, division: 60 });
  assert.equal(sixty.parts.length, 60);
  assert.notEqual(sixty.code, k.code);
});

test('start: a bad division or finish date is invalid', async () => {
  const s = server();
  const bad = await s.call('', { method: 'POST', as: 1, body: { title: 'T', name: 'N', division: 40, terms: 1 } });
  assert.equal(bad.status, 422);
  assert.deepEqual(bad.body.problem, { field: 'division', kind: 'value' });
  const date = await s.call('', { method: 'POST', as: 1,
    body: { title: 'T', name: 'N', division: 30, finishDate: '06/03/2026', terms: 1 } });
  assert.deepEqual(date.body.problem, { field: 'finishDate', kind: 'value' });
});

test('read: anyone; you depends on the key; ETag and 304', async () => {
  const s = server();
  const k = await s.start();
  const anonymous = await s.call(`/${k.code}`);
  assert.equal(anonymous.status, 200);
  assert.equal(anonymous.body.you.role, 'viewer');
  assert.equal(anonymous.headers.get('ETag'), `"v${k.version}"`);
  const same = await s.call(`/${k.code}`, { headers: { 'If-None-Match': `"v${k.version}"` } });
  assert.equal(same.status, 304);
  assert.equal(same.body, null);
  assert.equal((await s.call(`/${k.code}`, { as: 1 })).body.you.role, 'organiser');
});

test('take: a name the first time; taken; complete', async () => {
  const s = server();
  const k = await s.start();
  const noName = await s.call(`/${k.code}/parts/7/take`, { method: 'POST', as: 2, body: { terms: 1 } });
  assert.equal(noName.status, 422);
  const taken = await s.take(k.code, 7, 2, 'Maryam');
  assert.equal(taken.status, 200);
  assert.equal(taken.body.parts[6].state, 'taken');
  assert.equal(taken.body.you.role, 'participant');
  assert.equal(taken.body.participants.find((p) => p.id === taken.body.parts[6].holder).name, 'Maryam');
  assert.ok(taken.body.version > k.version);
  // The name is not asked again.
  assert.equal((await s.call(`/${k.code}/parts/8/take`, { method: 'POST', as: 2, body: {} })).status, 200);
  const again = await s.take(k.code, 7, 3);
  assert.equal(again.status, 409);
  assert.equal(again.body.error, 'taken');
  assert.equal(again.body.snapshot.parts[6].state, 'taken');
  assert.equal((await s.take(k.code, 31, 3)).status, 404);
});

test('two callers taking one part at once: exactly one holds it, 50 times (SC-015)', async () => {
  for (let i = 0; i < 50; i++) {
    const s = server();
    const k = await s.start();
    const [a, b] = await Promise.all([s.take(k.code, 5, 2), s.take(k.code, 5, 3)]);
    assert.deepEqual([a.status, b.status].sort(), [200, 409]);
    const holders = s.db.raw.prepare('SELECT holder FROM parts WHERE code = ? AND number = 5').all(k.code);
    assert.equal(holders.length, 1);
    assert.ok(holders[0].holder);
  }
});

test('release: the holder or the organiser; not someone else; not a read part', async () => {
  const s = server();
  const k = await s.start();
  await s.take(k.code, 3, 2);
  const other = await s.call(`/${k.code}/parts/3/release`, { method: 'POST', as: 3 });
  assert.equal(other.status, 409);
  assert.equal(other.body.error, 'notYours');
  const mine = await s.call(`/${k.code}/parts/3/release`, { method: 'POST', as: 2 });
  assert.equal(mine.body.parts[2].state, 'free');
  await s.take(k.code, 4, 2);
  await s.call(`/${k.code}/parts/4/read`, { method: 'POST', as: 2, body: { read: true } });
  const read = await s.call(`/${k.code}/parts/4/release`, { method: 'POST', as: 2 });
  assert.equal(read.body.error, 'read');
  await s.take(k.code, 5, 3);
  const freed = await s.call(`/${k.code}/parts/5/release`, { method: 'POST', as: 1 });
  assert.equal(freed.body.parts[4].state, 'free', 'the organiser frees a part (FR-062)');
});

test('read and undo; complete with the last part; a holder cannot undo then', async () => {
  const s = server();
  const k = await s.start();
  for (let n = 1; n <= 30; n++) await s.take(k.code, n, 2);
  const one = await s.call(`/${k.code}/parts/1/read`, { method: 'POST', as: 2, body: { read: true } });
  assert.equal(one.body.parts[0].state, 'read');
  assert.ok(one.body.parts[0].readAt);
  const undo = await s.call(`/${k.code}/parts/1/read`, { method: 'POST', as: 2, body: { read: false } });
  assert.equal(undo.body.parts[0].state, 'taken');
  // Sending a mark twice sets the same state (research R18).
  await s.call(`/${k.code}/parts/1/read`, { method: 'POST', as: 2, body: { read: true } });
  const twice = await s.call(`/${k.code}/parts/1/read`, { method: 'POST', as: 2, body: { read: true } });
  assert.equal(twice.status, 200);
  let last;
  for (let n = 2; n <= 30; n++) {
    last = await s.call(`/${k.code}/parts/${n}/read`, { method: 'POST', as: 2, body: { read: true } });
  }
  assert.ok(last.body.completedAt);
  assert.deepEqual(last.body.counts, { free: 0, taken: 0, read: 30 });
  const locked = await s.call(`/${k.code}/parts/30/read`, { method: 'POST', as: 2, body: { read: false } });
  assert.equal(locked.status, 409);
  assert.equal(locked.body.error, 'complete');
  assert.equal((await s.take(k.code, 1, 3)).body.error, 'complete');
});

test('leave: name gone, unread parts free, read parts kept with no name', async () => {
  const s = server();
  const k = await s.start();
  await s.take(k.code, 1, 2, 'Yusuf');
  await s.take(k.code, 2, 2);
  await s.call(`/${k.code}/parts/1/read`, { method: 'POST', as: 2, body: { read: true } });
  const left = await s.call(`/${k.code}/leave`, { method: 'POST', as: 2 });
  assert.equal(left.status, 204);
  const after = (await s.call(`/${k.code}`)).body;
  assert.equal(after.parts[0].state, 'read');
  assert.equal(after.parts[0].holder, null);
  assert.equal(after.parts[1].state, 'free');
  assert.ok(!after.participants.some((p) => p.name === 'Yusuf'));
  const organiser = await s.call(`/${k.code}/leave`, { method: 'POST', as: 1 });
  assert.equal(organiser.status, 409);
  assert.equal(organiser.body.error, 'organiser');
});

test('a khatma past its lifetime is gone', async () => {
  const s = server();
  const k = await s.start();
  s.advance(91 * 24 * 60 * 60 * 1000);
  assert.equal((await s.call(`/${k.code}`)).status, 404);
});
