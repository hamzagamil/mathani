// An optional Mathani link, sent as data.link (specs/018 Story 2, FR-005).
import test from 'node:test';
import assert from 'node:assert/strict';

import { message, owner } from './support.mjs';

test('Mathani https links are sent as data.link', async () => {
  for (const link of ['https://mthani.app/x', 'https://www.mthani.app/', 'https://get.mthani.app/k/ABCDEFGHJKMNPQRS']) {
    const { call, google } = owner();
    const r = await call({ method: 'POST', body: message({ link }) });
    assert.equal(r.status, 201, link);
    assert.equal(r.body.link, link);
    assert.deepEqual(JSON.parse(google.sends[0].body).message.data, { link });
  }
});

test('no link → no data key', async () => {
  for (const link of [null, undefined, '']) {
    const { call, google } = owner();
    const r = await call({ method: 'POST', body: message({ link }) });
    assert.equal(r.body.link, null);
    assert.equal('data' in JSON.parse(google.sends[0].body).message, false);
  }
});

test('other links → 422 link, nothing sent', async () => {
  const { call, google } = owner();
  for (const link of [
    'http://mthani.app/', 'https://example.com/', 'https://mthani.app.evil.com/', 'https://evil.com/mthani.app',
    'https://user:pw@mthani.app/', 'https://user@mthani.app/', 'javascript:alert(1)', 'mthani.app',
    `https://mthani.app/${'a'.repeat(500)}`, 42,
  ]) {
    const r = await call({ method: 'POST', body: message({ link }) });
    assert.equal(r.status, 422, String(link));
    assert.deepEqual(r.body, { error: 'invalid', field: 'link' });
  }
  assert.equal(google.calls.length, 0);
});
