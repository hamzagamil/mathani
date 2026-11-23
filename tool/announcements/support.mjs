// Test helpers for the owner announcements (specs/018): the editor environment with the
// announcements table, a service account with a fresh key, and a fake Google for the token
// exchange and FCM.
import { generateKeyPairSync } from 'node:crypto';
import { readFileSync } from 'node:fs';

import { dispatch as editor } from '../../functions/_lib/editor-api.js';
import { clearAccessKeys } from '../../functions/_lib/access.js';
import { clearTokenCache } from '../../functions/_lib/fcm.js';
import { accessKeys, environment as editorEnvironment, request } from '../mutashabihat/support.mjs';

export { accessKeys, request };
export { base } from '../mutashabihat/support.mjs';

const schema = readFileSync(new URL('../../functions/_lib/announcements-schema.sql', import.meta.url), 'utf8');

export const OWNER = 'owner@example.com';

const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
export const accountPublicKey = publicKey;
export const serviceAccount = JSON.stringify({
  type: 'service_account',
  project_id: 'mthani',
  client_email: 'mthani-announcements@mthani.iam.gserviceaccount.com',
  private_key: privateKey.export({ format: 'pem', type: 'pkcs8' }),
});

/** The editor environment with the announcements table; [configured] sets the secret. */
export function environment({ configured = true } = {}) {
  const env = editorEnvironment();
  env.DB.raw.exec(schema);
  env.OWNER_EMAIL = OWNER;
  if (configured) env.FCM_SERVICE_ACCOUNT = serviceAccount;
  return env;
}

/**
 * A fetch stand-in for Google. `calls` records {url, body}. Set `token` / `fcm` to
 * {status, body} to change the answers, or to 'throw' for a network error.
 */
export function fakeGoogle() {
  let n = 0;
  const google = {
    calls: [],
    token: null,
    fcm: null,
    get sends() {
      return google.calls.filter((c) => c.url.includes('fcm.googleapis.com'));
    },
    get tokens() {
      return google.calls.filter((c) => c.url.includes('oauth2.googleapis.com'));
    },
    async fetch(url, init = {}) {
      const body = typeof init.body === 'string' ? init.body : '';
      google.calls.push({ url: String(url), body, headers: init.headers ?? {} });
      const isToken = String(url) === 'https://oauth2.googleapis.com/token';
      const answer = isToken ? google.token : google.fcm;
      if (answer === 'throw') throw new TypeError('fetch failed');
      if (answer) {
        return new Response(JSON.stringify(answer.body ?? {}), {
          status: answer.status, headers: { 'Content-Type': 'application/json' } });
      }
      if (isToken) {
        return Response.json({ access_token: 'token-1', expires_in: 3600, token_type: 'Bearer' });
      }
      n += 1;
      return Response.json({ name: `projects/mthani/messages/${n}` });
    },
  };
  return google;
}

/**
 * A caller for /api/editor/announcements. Returns {status, body}. Options: method, body, path
 * (after `announcements`), as (email, or null for no token), origin.
 */
export function owner({ env = environment(), google = fakeGoogle(), now = () => Date.now() } = {}) {
  clearTokenCache();
  clearAccessKeys();
  const keys = accessKeys();
  const call = async ({ method = 'GET', body, path = '', as = OWNER, origin } = {}) => {
    // Expires in 2100: tests move the server's clock.
    const token = as ? keys.sign({ email: as, exp: 4102444800 }) : undefined;
    const r = await editor(request(`/api/editor/announcements${path}`, { method, body, token, origin }),
      env, { fetchCerts: keys.fetchCerts, now, fetch: google.fetch });
    const text = await r.text();
    return { status: r.status, body: text ? JSON.parse(text) : null };
  };
  return { call, env, google };
}

let ids = 0;
/** A valid POST body; [over] replaces fields. */
export const message = (over = {}) => ({
  requestId: `request-${++ids}-${Math.random().toString(36).slice(2)}`,
  audience: 'all',
  title: 'عنوان',
  body: 'نص الإشعار',
  ...over,
});
