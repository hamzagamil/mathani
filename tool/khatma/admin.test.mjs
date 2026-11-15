// The owner's endpoints (specs/014 contracts/group-api.md › Owner endpoints), behind the editor's
// Access check, for OWNER_EMAIL only.
import test from 'node:test';
import assert from 'node:assert/strict';

import { dispatch as editor } from '../../functions/_lib/editor-api.js';
import { hashKey } from '../../functions/_lib/khatma-store.js';
import { accessKeys, environment, request } from '../mutashabihat/support.mjs';
import { key, server } from './support.mjs';

const keys = accessKeys();

function owner(s) {
  const env = { ...environment(), KHATMA_DB: s.db };
  return async (path, { method = 'GET', body, as = 'owner@example.com' } = {}) => {
    const r = await editor(request(`/api/editor/khatma/${path}`, { method, body, token: keys.sign({ email: as }) }),
      env, { fetchCerts: keys.fetchCerts, now: s.now });
    const text = await r.text();
    return { status: r.status, body: text ? JSON.parse(text) : null };
  };
}

async function reported() {
  const s = server();
  const k = await s.start({ title: 'Reported Title' });
  const taken = await s.take(k.code, 1, 2, 'Bad Name');
  const id = taken.body.parts[0].holder;
  await s.call(`/${k.code}/report`, { method: 'POST', as: 3, body: { participant: id } });
  return { s, k, id, call: owner(s) };
}

test('reports are listed, open first, with whether the khatma exists', async () => {
  const { call, k } = await reported();
  const r = await call('reports');
  assert.equal(r.status, 200);
  assert.equal(r.body.reports.length, 1);
  assert.equal(r.body.reports[0].name, 'Bad Name');
  assert.equal(r.body.reports[0].code, k.code);
  assert.equal(r.body.reports[0].exists, true);
  assert.equal(r.body.reports[0].resolvedAt, null);
});

test('only the owner: an editor is refused', async () => {
  const { s } = await reported();
  // An editor listed for the Mutashabihat editor is still not the owner.
  const env = { ...environment(), KHATMA_DB: s.db };
  await env.DB.prepare("INSERT INTO editors (email, added_by, added_at) VALUES ('ed@example.com', 'owner@example.com', 1)").run().catch(() => {});
  const r = await owner(s)('reports', { as: 'ed@example.com' });
  assert.ok(r.status === 403, `status ${r.status}`);
});

test('resolve: remove the name and block its poster', async () => {
  const { s, k, call } = await reported();
  const id = (await call('reports')).body.reports[0].id;
  const r = await call(`reports/${id}/resolve`, { method: 'POST', body: { action: 'name', block: true } });
  assert.equal(r.status, 200);
  assert.equal(r.body.action, 'name');
  assert.equal(r.body.blocked, true);
  assert.ok(r.body.resolvedAt);
  const snap = (await s.call(`/${k.code}`)).body;
  assert.equal(snap.parts[0].state, 'free');
  assert.ok(!snap.participants.some((p) => p.name === 'Bad Name'));
  assert.ok(s.db.raw.prepare('SELECT 1 FROM blocks WHERE key_hash = ?').get(await hashKey(key(2))));
  assert.deepEqual((await s.take(k.code, 2, 2)).body, { error: 'blocked' });
});

test('resolve: remove the whole khatma', async () => {
  const { s, k, call } = await reported();
  const id = (await call('reports')).body.reports[0].id;
  const r = await call(`reports/${id}/resolve`, { method: 'POST', body: { action: 'khatma', block: false } });
  assert.equal(r.body.exists, false);
  assert.equal((await s.call(`/${k.code}`)).status, 404);
});

test('resolve: dismiss changes nothing but the report', async () => {
  const { s, k, call } = await reported();
  const id = (await call('reports')).body.reports[0].id;
  const r = await call(`reports/${id}/resolve`, { method: 'POST', body: { action: 'none' } });
  assert.equal(r.body.action, 'none');
  assert.equal((await s.call(`/${k.code}`)).body.parts[0].state, 'taken');
  assert.equal((await call(`reports/${id}/resolve`, { method: 'POST', body: { action: 'other' } })).status, 422);
  assert.equal((await call('reports/999/resolve', { method: 'POST', body: { action: 'none' } })).status, 404);
});
