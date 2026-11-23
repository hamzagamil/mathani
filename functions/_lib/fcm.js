// Firebase Cloud Messaging HTTP v1 for the owner's announcements (specs/018 research R1, R2, R7).
// The service account JSON is the Pages secret FCM_SERVICE_ACCOUNT, set for production only.
// Its key never leaves this module: not in responses, not in `detail`.

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const TIMEOUT_MS = 10_000;

let cached = null; // {clientEmail, token, expiresAt}

/** For tests: forget the cached access token. */
export function clearTokenCache() {
  cached = null;
}

/** `{projectId, clientEmail, privateKey}` from the secret, or null. */
export function parseServiceAccount(text) {
  if (typeof text !== 'string' || !text) return null;
  try {
    const a = JSON.parse(text);
    if (typeof a.project_id !== 'string' || !a.project_id) return null;
    if (typeof a.client_email !== 'string' || !a.client_email.includes('@')) return null;
    if (typeof a.private_key !== 'string' || !a.private_key.includes('PRIVATE KEY')) return null;
    return { projectId: a.project_id, clientEmail: a.client_email, privateKey: a.private_key };
  } catch {
    return null;
  }
}

export const isConfigured = (env) => parseServiceAccount(env.FCM_SERVICE_ACCOUNT) !== null;

const b64url = (bytes) => btoa(String.fromCharCode(...new Uint8Array(bytes)))
  .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const b64urlText = (text) => b64url(new TextEncoder().encode(text));

function pemBytes(pem) {
  const base64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  return Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
}

class NotConfigured extends Error {}

async function signedJwt(account, nowMs) {
  let key;
  try {
    key = await crypto.subtle.importKey('pkcs8', pemBytes(account.privateKey),
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  } catch {
    throw new NotConfigured('the service account key could not be read');
  }
  const iat = Math.floor(nowMs / 1000);
  const head = b64urlText(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const body = b64urlText(JSON.stringify({
    iss: account.clientEmail, sub: account.clientEmail, scope: SCOPE, aud: TOKEN_URL, iat, exp: iat + 3600,
  }));
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${head}.${body}`));
  return `${head}.${body}.${b64url(signature)}`;
}

/** An access token for [account], reused until 5 minutes before it expires. */
export async function accessToken(account, { fetch = globalThis.fetch, now = Date.now() } = {}) {
  if (cached && cached.clientEmail === account.clientEmail && cached.expiresAt - 5 * 60_000 > now) {
    return cached.token;
  }
  const assertion = await signedJwt(account, now);
  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${assertion}`,
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (response.status === 400 || response.status === 401 || response.status === 403) {
    throw new NotConfigured(`token ${response.status}: ${await errorText(response)}`);
  }
  if (!response.ok) throw new Error(`token ${response.status}: ${await errorText(response)}`);
  const data = await response.json();
  if (typeof data.access_token !== 'string') throw new NotConfigured('token: no access_token');
  cached = { clientEmail: account.clientEmail, token: data.access_token,
    expiresAt: now + (Number(data.expires_in) || 3600) * 1000 };
  return cached.token;
}

async function errorText(response) {
  try {
    const text = await response.text();
    try {
      const e = JSON.parse(text);
      const message = e?.error?.message ?? e?.error_description ?? e?.error;
      const code = e?.error?.status;
      if (message) return code ? `${code}: ${message}` : String(message);
    } catch { /* not JSON */ }
    return text;
  } catch {
    return '';
  }
}

const clip = (text) => {
  const s = String(text ?? '').replace(/-----BEGIN[\s\S]*?-----END[^-]*-----/g, '[key]');
  return s.length > 500 ? s.slice(0, 500) : s;
};

/**
 * Sends one FCM message (`{topic, notification, …}`, without the `message` wrapper).
 * Returns `{status: 'sent', message}` or `{status, detail}` per research R7.
 */
export async function send(env, message, { fetch = globalThis.fetch, now = Date.now() } = {}) {
  const account = parseServiceAccount(env.FCM_SERVICE_ACCOUNT);
  if (!account) return { status: 'notConfigured', detail: 'FCM_SERVICE_ACCOUNT is not set' };
  try {
    const token = await accessToken(account, { fetch, now });
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.projectId)}/messages:send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=utf-8', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ message }),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    if (response.ok) {
      const data = await response.json();
      return { status: 'sent', message: typeof data.name === 'string' ? data.name : null };
    }
    const detail = clip(`${response.status} ${await errorText(response)}`);
    if (response.status === 401 || response.status === 403) {
      cached = null;
      return { status: 'notConfigured', detail };
    }
    if (response.status === 400) return { status: 'rejected', detail };
    if (response.status === 429) return { status: 'busy', detail };
    return { status: 'unavailable', detail };
  } catch (e) {
    if (e instanceof NotConfigured) return { status: 'notConfigured', detail: clip(e.message) };
    return { status: 'unavailable', detail: clip(e?.name === 'TimeoutError' ? 'timeout' : e?.message ?? 'network') };
  }
}
