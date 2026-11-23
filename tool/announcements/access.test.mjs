// Only the owner reads or sends (specs/018 FR-002, SC-004).
import test from 'node:test';
import assert from 'node:assert/strict';

import { message, owner } from './support.mjs';

test('no Access token → 401', async () => {
  const { call, google } = owner();
  assert.equal((await call({ as: null })).status, 401);
  assert.equal((await call({ method: 'POST', body: message(), as: null })).status, 401);
  assert.equal(google.calls.length, 0);
});

test('an editor who is not the owner → 403, and nothing is sent', async () => {
  const { call, env, google } = owner();
  await env.DB.prepare('INSERT INTO editors (email, added_at, added_by) VALUES (?, ?, ?)')
    .bind('editor@example.com', Date.now(), 'owner@example.com').run();
  const get = await call({ as: 'editor@example.com' });
  assert.equal(get.status, 403);
  assert.equal(get.body.error, 'ownerOnly');
  const post = await call({ method: 'POST', body: message(), as: 'editor@example.com' });
  assert.equal(post.status, 403);
  assert.equal(google.calls.length, 0);
});

test('the owner → 200', async () => {
  const { call } = owner();
  assert.equal((await call()).status, 200);
});

test('a deeper path → 404; another origin → 403', async () => {
  const { call, google } = owner();
  assert.equal((await call({ path: '/x' })).status, 404);
  assert.equal((await call({ method: 'POST', body: message(), origin: 'https://evil.example' })).status, 403);
  assert.equal(google.calls.length, 0);
});
