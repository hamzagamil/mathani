// Access token checks (specs/011 T010).
import test, { beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { clearAccessKeys, verifyAccess } from '../../functions/_lib/access.js';
import { accessKeys, environment, request } from './support.mjs';

const keys = accessKeys();
const other = accessKeys();
const env = environment();
const check = (token, e = env, fetchCerts = keys.fetchCerts) =>
  verifyAccess(request('/api/editor/me', { token }), e, { fetchCerts });

beforeEach(clearAccessKeys);

test('a valid token gives the lower-cased email', async () => {
  assert.deepEqual(await check(keys.sign({ email: 'Owner@Example.com' })), { email: 'owner@example.com' });
});

test('anything else gives null', async () => {
  assert.equal(await check(undefined), null, 'no header');
  assert.equal(await check('not.a.token'), null, 'garbage');
  assert.equal(await check(other.sign({ email: 'a@b.c' })), null, 'signed by another key');
  assert.equal(await check(keys.sign({ email: 'a@b.c', aud: 'other' })), null, 'wrong audience');
  assert.equal(await check(keys.sign({ email: 'a@b.c', exp: Math.floor(Date.now() / 1000) - 5 })), null, 'expired');
  assert.equal(await check(keys.sign({ email: 'a@b.c', keyId: 'unknown' })), null, 'unknown key');
  assert.equal(await check(keys.sign({ email: 'a@b.c' }), { ...env, ACCESS_AUD: '' }), null, 'not configured');
  clearAccessKeys(); // keys are cached for an hour; without them, an unreachable team fails closed
  assert.equal(await check(keys.sign({ email: 'a@b.c' }), env, async () => { throw new Error('down'); }), null,
    'keys unreachable');
});
