// /api/editor/* (specs/011 contracts/editor-api.md): sign-in, editing, publishing, editors and
// restore, against the real schema in node:sqlite.
import test from 'node:test';
import assert from 'node:assert/strict';
import { dispatch } from '../../functions/_lib/editor-api.js';
import { parse } from '../../functions/_lib/mutashabihat-content.js';
import { accessKeys, environment, request, shippedMarkdown } from './support.mjs';

const keys = accessKeys();
const owner = 'owner@example.com';

function app() {
  const env = environment();
  let clock = 1_000;
  const call = async (path, { method = 'GET', body, as = owner, origin, token } = {}) => {
    const t = token === undefined && as ? keys.sign({ email: as }) : token;
    const response = await dispatch(request(`/api/editor/${path}`, { method, body, token: t, origin }), env,
      { fetchCerts: keys.fetchCerts, now: () => ++clock });
    const text = await response.text();
    return { status: response.status, body: text ? JSON.parse(text) : null, headers: response.headers };
  };
  return { env, call };
}

async function imported() {
  const a = app();
  const r = await a.call('import', { method: 'POST', body: { markdown: shippedMarkdown() } });
  assert.equal(r.status, 201);
  return a;
}

const find = async (a, ayat) => (await a.call('groups')).body.groups.find((g) => g.ayat === ayat);

// --- Sign-in and import (T013) -------------------------------------------------------------------

test('sign-in: no token 401, a stranger 403, the owner allowed; nothing is cached', async () => {
  const { call } = app();
  assert.equal((await call('me', { as: null })).status, 401);
  const stranger = await call('me', { as: 'someone@example.com' });
  assert.equal(stranger.status, 403);
  assert.deepEqual(stranger.body, { error: 'notAnEditor', email: 'someone@example.com' });
  const me = await call('me');
  assert.deepEqual(me.body, { email: owner, isOwner: true });
  assert.equal(me.headers.get('cache-control'), 'private, no-store');
});

test('without the database: 503', async () => {
  const response = await dispatch(request('/api/editor/me'), { ...environment(), DB: undefined });
  assert.equal(response.status, 503);
});

test('import: the shipped file becomes version 1 with 72 published groups, once', async () => {
  const a = await imported();
  const { groups, published } = (await a.call('groups')).body;
  assert.equal(groups.length, 72);
  assert.ok(groups.every((g) => g.status === 'published' && g.revision === 1 && g.id.length === 12));
  assert.equal(published.number, 1);
  assert.deepEqual(published.summary, { added: 72, changed: 0, removed: 0 });
  assert.equal((await a.call('import', { method: 'POST', body: { markdown: shippedMarkdown() } })).status, 409);
  // The notes survive (FR-007).
  assert.equal((await find(a, '2:18 2:171')).note, 'البقرة ١٨');
});

test('writes: another origin is refused; the owner alone imports', async () => {
  const a = app();
  const cross = await a.call('import', { method: 'POST', body: { markdown: 'x' }, origin: 'https://evil.example' });
  assert.equal(cross.status, 403);
  await a.call('editors', { method: 'POST', body: { email: 'ed@example.com' } });
  const byEditor = await a.call('import', { method: 'POST', body: { markdown: shippedMarkdown() }, as: 'ed@example.com' });
  assert.equal(byEditor.status, 403);
});

// --- Edit and publish (T021) ---------------------------------------------------------------------

test('edit an explanation, then publish it', async () => {
  const a = await imported();
  const g = await find(a, '2:35 7:19');
  const saved = await a.call(`groups/${g.id}`, {
    method: 'PUT', body: { ayat: g.ayat, note: g.note, explanation: 'شرح جديد', revision: g.revision },
  });
  assert.equal(saved.status, 200);
  assert.equal(saved.body.status, 'changed');
  assert.equal(saved.body.revision, 2);

  const stale = await a.call(`groups/${g.id}`, {
    method: 'PUT', body: { ayat: g.ayat, note: g.note, explanation: 'آخر', revision: 1 },
  });
  assert.equal(stale.status, 409);
  assert.equal(stale.body.group.updatedBy, owner);

  assert.equal((await a.call(`groups/${g.id}`, {
    method: 'PUT', body: { ayat: g.ayat, explanation: '  ', revision: 2 },
  })).status, 422);

  const draft = (await a.call('publish')).body;
  assert.deepEqual(draft.changes.map((c) => [c.id, c.status, c.updatedBy]), [[g.id, 'changed', owner]]);
  assert.deepEqual(draft.problems, []);

  assert.equal((await a.call('publish', { method: 'POST', body: { expect: [] } })).status, 409);
  const v2 = await a.call('publish', { method: 'POST', body: { expect: [g.id] } });
  assert.equal(v2.status, 201);
  assert.equal(v2.body.number, 2);
  assert.deepEqual(v2.body.summary, { added: 0, changed: 1, removed: 0 });
  assert.equal((await find(a, '2:35 7:19')).status, 'published');
  assert.equal((await a.call('publish', { method: 'POST', body: { expect: [] } })).status, 400);

  const content = (await a.env.DB.prepare('SELECT content FROM versions WHERE number = 2').first()).content;
  const parsed = parse(content);
  assert.equal(parsed.version, 2);
  assert.equal(parsed.groups.length, 72);
  assert.ok(parsed.groups.some((x) => x.explanation === 'شرح جديد'));
});

test('a publish blocked by a broken group changes nothing', async () => {
  const a = await imported();
  // A row that would fail the checks can only come from outside the API; publish still refuses it.
  await a.env.DB.prepare("UPDATE groups SET ayat = '2:35' WHERE rowid = 1").run();
  const id = (await a.env.DB.prepare('SELECT id FROM groups WHERE rowid = 1').first()).id;
  const draft = (await a.call('publish')).body;
  assert.equal(draft.problems[0].id, id);
  const r = await a.call('publish', { method: 'POST', body: { expect: draft.changes.map((c) => c.id) } });
  assert.equal(r.status, 422);
  assert.equal((await a.call('versions')).body.versions.length, 1);
});

// --- Add, change and remove groups (T030) -------------------------------------------------------

test('create, refuse bad input, delete, undelete, discard', async () => {
  const a = await imported();
  const created = await a.call('groups', { method: 'POST', body: { ayat: '٢:٣٠, 7:11', note: 'ملاحظة', explanation: 'شرح' } });
  assert.equal(created.status, 201);
  assert.equal(created.body.ayat, '2:30 7:11');
  assert.equal(created.body.status, 'added');

  const missing = await a.call('groups', { method: 'POST', body: { ayat: '2:300 2:1', explanation: 'x' } });
  assert.equal(missing.status, 422);
  assert.equal(missing.body.problems[0].kind, 'noSuchAyah');
  assert.match(missing.body.problems[0].message, /2:300/);
  assert.equal((await a.call('groups', { method: 'POST', body: { ayat: '2:30', explanation: 'x' } })).body.problems[0].kind,
    'tooFewAyat');
  assert.equal((await a.call('groups', { method: 'POST', body: { ayat: '2:30 2:31', note: 'a\nb', explanation: 'x' } })).status,
    422);

  const g = await find(a, '2:18 2:171');
  const removed = await a.call(`groups/${g.id}`, { method: 'DELETE', body: { revision: g.revision } });
  assert.equal(removed.body.status, 'removed');
  const back = await a.call(`groups/${g.id}/undelete`, { method: 'POST', body: { revision: removed.body.revision } });
  assert.equal(back.body.status, 'published');
  const gone = await a.call(`groups/${g.id}`, { method: 'DELETE', body: { revision: back.body.revision } });

  // A deleted group that was never published disappears.
  const discarded = await a.call(`groups/${created.body.id}`, { method: 'DELETE', body: { revision: 1 } });
  assert.equal(discarded.body.status, 'discarded');
  assert.equal((await a.call('groups')).body.groups.some((x) => x.id === created.body.id), false);

  const fresh = await a.call('groups', { method: 'POST', body: { ayat: '2:58 7:161', explanation: 'شرح' } });
  const draft = (await a.call('publish')).body;
  assert.deepEqual(draft.changes.map((c) => c.status).sort(), ['added', 'removed']);
  const v2 = await a.call('publish', { method: 'POST', body: { expect: draft.changes.map((c) => c.id) } });
  assert.deepEqual(v2.body.summary, { added: 1, changed: 0, removed: 1 });
  const { groups } = (await a.call('groups')).body;
  assert.equal(groups.length, 72);
  assert.ok(groups.some((x) => x.id === fresh.body.id));
  assert.ok(!groups.some((x) => x.id === gone.body.id));
});

// --- Editors (T033) -------------------------------------------------------------------------------

test('the owner adds and removes editors; editors edit and publish, but do not manage editors', async () => {
  const a = await imported();
  const editor = 'Ed@Example.com';
  assert.equal((await a.call('editors', { method: 'POST', body: { email: editor } })).status, 201);
  assert.equal((await a.call('editors', { method: 'POST', body: { email: 'ed@example.com' } })).status, 409);
  assert.equal((await a.call('editors', { method: 'POST', body: { email: 'not-an-email' } })).status, 422);
  assert.equal((await a.call('editors', { method: 'POST', body: { email: owner } })).status, 422);
  assert.deepEqual((await a.call('editors')).body.editors.map((e) => e.email), ['ed@example.com']);

  const as = 'ed@example.com';
  assert.deepEqual((await a.call('me', { as })).body, { email: as, isOwner: false });
  assert.equal((await a.call('editors', { as })).status, 403);
  const g = await find(a, '2:35 7:19');
  const saved = await a.call(`groups/${g.id}`, {
    as, method: 'PUT', body: { ayat: g.ayat, note: g.note, explanation: 'من المحرر', revision: g.revision },
  });
  assert.equal(saved.body.updatedBy, as);
  const v2 = await a.call('publish', { as, method: 'POST', body: { expect: [g.id] } });
  assert.equal(v2.body.publishedBy, as);

  assert.equal((await a.call(`editors/${encodeURIComponent(as)}`, { method: 'DELETE' })).status, 204);
  assert.equal((await a.call('groups', { as })).status, 403, 'removed: refused on the next request');
  assert.equal((await a.call(`editors/${encodeURIComponent(as)}`, { method: 'DELETE' })).status, 404);
});

// --- History and restore (T036) -------------------------------------------------------------------

test('history, and restoring an earlier version as a new one', async () => {
  const a = await imported();
  const g = await find(a, '2:35 7:19');
  await a.call(`groups/${g.id}`, { method: 'PUT', body: { ayat: g.ayat, note: g.note, explanation: 'خطأ', revision: g.revision } });
  await a.call('publish', { method: 'POST', body: { expect: [g.id] } });

  const { versions } = (await a.call('versions')).body;
  assert.deepEqual(versions.map((v) => v.number), [2, 1]);
  assert.equal(versions[0].content, undefined);
  const v1 = (await a.call('versions/1')).body;
  assert.equal(v1.groups.length, 72);
  assert.equal((await a.call('versions/9')).status, 404);

  // An unpublished change blocks a restore unless it is discarded.
  const now = await find(a, '2:35 7:19');
  await a.call(`groups/${g.id}`, { method: 'PUT', body: { ayat: g.ayat, note: g.note, explanation: 'مسودة', revision: now.revision } });
  assert.equal((await a.call('versions/1/restore', { method: 'POST', body: { discardDraft: false } })).status, 409);
  const v3 = await a.call('versions/1/restore', { method: 'POST', body: { discardDraft: true } });
  assert.equal(v3.status, 201);
  assert.equal(v3.body.number, 3);
  assert.equal(v3.body.restoredFrom, 1);
  assert.deepEqual(v3.body.summary, { added: 0, changed: 1, removed: 0 });

  const restored = await find(a, '2:35 7:19');
  assert.equal(restored.explanation, v1.groups.find((x) => x.id === g.id).explanation);
  assert.equal(restored.status, 'published');
  assert.ok(restored.revision > now.revision, 'an open editor sees the change as a conflict');
  assert.deepEqual((await a.call('publish')).body.changes, []);
});
