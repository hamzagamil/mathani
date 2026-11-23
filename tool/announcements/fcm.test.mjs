// FCM HTTP v1 sending (specs/018 research R1, R2, R7).
import test from 'node:test';
import assert from 'node:assert/strict';
import { verify } from 'node:crypto';

import { accessToken, clearTokenCache, parseServiceAccount, send } from '../../functions/_lib/fcm.js';
import { accountPublicKey, fakeGoogle, serviceAccount } from './support.mjs';

const env = { FCM_SERVICE_ACCOUNT: serviceAccount };
const msg = { topic: 'all', notification: { title: 't', body: 'b' } };

test.beforeEach(() => clearTokenCache());

test('the service account is read only when complete', () => {
  assert.equal(parseServiceAccount(serviceAccount).projectId, 'mthani');
  const a = JSON.parse(serviceAccount);
  assert.equal(parseServiceAccount(JSON.stringify({ ...a, private_key: undefined })), null);
  assert.equal(parseServiceAccount(JSON.stringify({ ...a, client_email: 'x' })), null);
  assert.equal(parseServiceAccount('{not json'), null);
  assert.equal(parseServiceAccount(undefined), null);
});

test('the token request carries a JWT with the messaging scope, signed by the account key', async () => {
  const google = fakeGoogle();
  const now = Date.UTC(2026, 10, 23, 10);
  await accessToken(parseServiceAccount(serviceAccount), { fetch: google.fetch, now });
  const form = new URLSearchParams(google.tokens[0].body);
  assert.equal(form.get('grant_type'), 'urn:ietf:params:oauth:grant-type:jwt-bearer');
  const [head, body, signature] = form.get('assertion').split('.');
  assert.deepEqual(JSON.parse(Buffer.from(head, 'base64url')), { alg: 'RS256', typ: 'JWT' });
  const claims = JSON.parse(Buffer.from(body, 'base64url'));
  assert.equal(claims.iss, 'mthani-announcements@mthani.iam.gserviceaccount.com');
  assert.equal(claims.sub, claims.iss);
  assert.equal(claims.scope, 'https://www.googleapis.com/auth/firebase.messaging');
  assert.equal(claims.aud, 'https://oauth2.googleapis.com/token');
  assert.equal(claims.iat, now / 1000);
  assert.equal(claims.exp, now / 1000 + 3600);
  assert.ok(verify('sha256', Buffer.from(`${head}.${body}`), accountPublicKey, Buffer.from(signature, 'base64url')));
});

test('a sent message uses the bearer token and the project from the account', async () => {
  const google = fakeGoogle();
  const r = await send(env, msg, { fetch: google.fetch });
  assert.deepEqual(r, { status: 'sent', message: 'projects/mthani/messages/1' });
  assert.equal(google.sends[0].url, 'https://fcm.googleapis.com/v1/projects/mthani/messages:send');
  assert.equal(google.sends[0].headers.Authorization, 'Bearer token-1');
  assert.deepEqual(JSON.parse(google.sends[0].body), { message: msg });
});

test('the token is reused within its hour and renewed near the end', async () => {
  const google = fakeGoogle();
  const now = Date.now();
  await send(env, msg, { fetch: google.fetch, now });
  await send(env, msg, { fetch: google.fetch, now: now + 30 * 60_000 });
  assert.equal(google.tokens.length, 1);
  await send(env, msg, { fetch: google.fetch, now: now + 56 * 60_000 });
  assert.equal(google.tokens.length, 2);
  assert.equal(google.sends.length, 3);
});

test('failures map to plain statuses (research R7)', async (t) => {
  const cases = [
    [{ FCM_SERVICE_ACCOUNT: undefined }, null, null, 'notConfigured'],
    [{ FCM_SERVICE_ACCOUNT: 'nope' }, null, null, 'notConfigured'],
    [env, { status: 400, body: { error: 'invalid_grant' } }, null, 'notConfigured'],
    [env, { status: 401, body: {} }, null, 'notConfigured'],
    [env, null, { status: 401, body: {} }, 'notConfigured'],
    [env, null, { status: 403, body: { error: { status: 'PERMISSION_DENIED', message: 'no' } } }, 'notConfigured'],
    [env, null, { status: 400, body: { error: { status: 'INVALID_ARGUMENT', message: 'bad topic' } } }, 'rejected'],
    [env, null, { status: 429, body: { error: { status: 'QUOTA_EXCEEDED' } } }, 'busy'],
    [env, null, { status: 503, body: {} }, 'unavailable'],
    [env, 'throw', null, 'unavailable'],
    [env, null, 'throw', 'unavailable'],
  ];
  for (const [e, token, fcm, expected] of cases) {
    await t.test(`${JSON.stringify(token)} / ${JSON.stringify(fcm)} → ${expected}`, async () => {
      clearTokenCache();
      const google = fakeGoogle();
      google.token = token;
      google.fcm = fcm;
      const r = await send(e, msg, { fetch: google.fetch });
      assert.equal(r.status, expected);
      assert.ok(!String(r.detail).includes('PRIVATE KEY'));
      assert.ok(String(r.detail).length <= 500);
    });
  }
});

test('a timeout is unavailable', async () => {
  const fetch = async (url) => {
    if (String(url).includes('oauth2')) return Response.json({ access_token: 'x', expires_in: 3600 });
    throw new DOMException('timed out', 'TimeoutError');
  };
  const r = await send(env, msg, { fetch });
  assert.deepEqual(r, { status: 'unavailable', detail: 'timeout' });
});

test('the detail is cut to 500 characters', async () => {
  const google = fakeGoogle();
  google.fcm = { status: 400, body: { error: { message: 'x'.repeat(2000) } } };
  const r = await send(env, msg, { fetch: google.fetch });
  assert.equal(r.detail.length, 500);
});
