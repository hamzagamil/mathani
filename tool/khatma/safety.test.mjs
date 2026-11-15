// Safety and order (specs/014 Story 6): reports, the organiser's tools, blocks, limits, and names
// that leave no copy behind (SC-019).
import test from 'node:test';
import assert from 'node:assert/strict';

import { hashKey } from '../../functions/_lib/khatma-store.js';
import { allText, key, server } from './support.mjs';

const DAY = 24 * 60 * 60 * 1000;

test('a report: 202, with copies of the title and name and the poster', async () => {
  const s = server();
  const k = await s.start({ title: 'Family' });
  const taken = await s.take(k.code, 1, 2, 'Rude Name');
  const id = taken.body.parts[0].holder;
  const r = await s.call(`/${k.code}/report`, { method: 'POST', as: 3, body: { participant: id } });
  assert.equal(r.status, 202);
  const row = s.db.raw.prepare('SELECT * FROM reports').get();
  assert.equal(row.title, 'Family');
  assert.equal(row.name, 'Rude Name');
  assert.equal(row.poster, await hashKey(key(2)));
  assert.equal(row.reporter, await hashKey(key(3)));
  const whole = await s.call(`/${k.code}/report`, { method: 'POST', as: 3, body: {} });
  assert.equal(whole.status, 202);
  assert.equal(s.db.raw.prepare('SELECT poster FROM reports WHERE participant IS NULL').get().poster,
    await hashKey(key(1)), 'the whole khatma was posted by its organiser');
});

test('reports: 10 a day for one key, then 429', async () => {
  const s = server();
  const k = await s.start();
  for (let i = 0; i < 10; i++) {
    assert.equal((await s.call(`/${k.code}/report`, { method: 'POST', as: 3, body: {} })).status, 202);
  }
  const over = await s.call(`/${k.code}/report`, { method: 'POST', as: 3, body: {} });
  assert.equal(over.status, 429);
  assert.deepEqual(over.body, { error: 'limit', which: 'reports' });
  s.advance(DAY + 1);
  assert.equal((await s.call(`/${k.code}/report`, { method: 'POST', as: 3, body: {} })).status, 202);
});

test('the organiser removes a participant: name gone, parts free, cannot rejoin', async () => {
  const s = server();
  const k = await s.start();
  const taken = await s.take(k.code, 1, 2, 'Removed One');
  await s.take(k.code, 2, 2);
  const id = taken.body.parts[0].holder;
  const notOrganiser = await s.call(`/${k.code}/participants/${id}/remove`, { method: 'POST', as: 3 });
  assert.equal(notOrganiser.status, 403);
  assert.deepEqual(notOrganiser.body, { error: 'organiser' });
  const r = await s.call(`/${k.code}/participants/${id}/remove`, { method: 'POST', as: 1 });
  assert.equal(r.status, 200);
  assert.equal(r.body.parts[0].state, 'free');
  assert.equal(r.body.parts[1].state, 'free');
  assert.ok(!allText(s.db).some((t) => t.includes('Removed One')), 'SC-019');
  const again = await s.take(k.code, 3, 2);
  assert.equal(again.status, 403);
  assert.deepEqual(again.body, { error: 'removed' });
});

test('the organiser deletes the khatma: gone for everyone, no names left', async () => {
  const s = server();
  const k = await s.start({ name: 'Organiser Name', title: 'Deleted Title' });
  await s.take(k.code, 1, 2, 'Someone Else');
  assert.equal((await s.call(`/${k.code}`, { method: 'DELETE', as: 2 })).status, 403);
  assert.equal((await s.call(`/${k.code}`, { method: 'DELETE', as: 1 })).status, 204);
  assert.equal((await s.call(`/${k.code}`)).status, 404);
  const left = allText(s.db);
  for (const name of ['Organiser Name', 'Deleted Title', 'Someone Else']) {
    assert.ok(!left.some((t) => t.includes(name)), name);
  }
});

test('leaving leaves no copy of the name (SC-019)', async () => {
  const s = server();
  const k = await s.start();
  await s.take(k.code, 1, 2, 'Leaving Person');
  await s.call(`/${k.code}/leave`, { method: 'POST', as: 2 });
  assert.ok(!allText(s.db).some((t) => t.includes('Leaving Person')));
});

test('a blocked key is refused on start, take, assign and report', async () => {
  const s = server();
  const k = await s.start();
  s.db.raw.prepare('INSERT INTO blocks (key_hash, blocked_at) VALUES (?, 0)').run(await hashKey(key(1)));
  s.db.raw.prepare('INSERT INTO blocks (key_hash, blocked_at) VALUES (?, 0)').run(await hashKey(key(5)));
  const start = await s.call('', { method: 'POST', as: 5, body: { title: 'T', name: 'N', division: 30, terms: 1 } });
  assert.deepEqual(start.body, { error: 'blocked' });
  assert.deepEqual((await s.take(k.code, 1, 5)).body, { error: 'blocked' });
  const assign = await s.call(`/${k.code}/parts/2/assign`, { method: 'POST', as: 1, body: { name: 'Gran' } });
  assert.deepEqual(assign.body, { error: 'blocked' });
  const report = await s.call(`/${k.code}/report`, { method: 'POST', as: 5, body: {} });
  assert.deepEqual(report.body, { error: 'blocked' });
  // Reading still works.
  assert.equal((await s.call(`/${k.code}`, { as: 5 })).status, 200);
});

test('limits: 5 open khatmas organised, 20 started in a day, 2,000 in a day overall', async () => {
  const s = server();
  for (let i = 0; i < 5; i++) await s.start({ as: 1 });
  const sixth = await s.call('', { method: 'POST', as: 1, body: { title: 'T', name: 'N', division: 30, terms: 1 } });
  assert.equal(sixth.status, 429);
  assert.deepEqual(sixth.body, { error: 'limit', which: 'organised' });

  // Completed ones do not count as open, but every start that day counts toward 20.
  const t = server();
  for (let i = 0; i < 20; i++) {
    const k = await t.start({ as: 2 });
    t.db.raw.prepare('UPDATE khatmas SET completed_at = 1 WHERE code = ?').run(k.code);
  }
  const twentyFirst = await t.call('', { method: 'POST', as: 2, body: { title: 'T', name: 'N', division: 30, terms: 1 } });
  assert.deepEqual(twentyFirst.body, { error: 'limit', which: 'started' });

  const u = server();
  const insert = u.db.raw.prepare(
    "INSERT INTO khatmas (code, title, division, organiser, version, created_at, changed_at) VALUES (?, 'T', 30, 'x', 1, ?, ?)");
  for (let i = 0; i < 2000; i++) insert.run(`C${String(i).padStart(15, '0')}`, u.now(), u.now());
  const busy = await u.call('', { method: 'POST', as: 3, body: { title: 'T', name: 'N', division: 30, terms: 1 } });
  assert.deepEqual(busy.body, { error: 'limit', which: 'busy' });
});

test('30 days after completion, or 90 without a change, it answers gone', async () => {
  const s = server();
  const k = await s.start();
  s.db.raw.prepare('UPDATE khatmas SET completed_at = ? WHERE code = ?').run(s.now(), k.code);
  s.advance(29 * DAY);
  await s.call(`/${k.code}/report`, { method: 'POST', as: 2, body: {} }); // reading does not extend it
  assert.equal((await s.call(`/${k.code}`)).status, 200);
  s.advance(2 * DAY);
  assert.equal((await s.call(`/${k.code}`)).status, 404);
});
