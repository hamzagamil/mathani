// Who is asking: the email in the Cloudflare Access token (specs/011 research R2). The signature
// is checked here too, so a request that goes around Access (straight to a pages.dev address)
// gets nowhere.

const certsCache = new Map(); // team domain → {keys, fetchedAt}
const certsTtlMs = 60 * 60 * 1000;

const fromB64url = (s) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
const decodeJson = (s) => JSON.parse(new TextDecoder().decode(fromB64url(s)));

async function defaultFetchCerts(teamDomain) {
  const response = await fetch(`https://${teamDomain}/cdn-cgi/access/certs`);
  if (!response.ok) throw new Error(`certs ${response.status}`);
  return response.json();
}

async function keyFor(kid, env, fetchCerts, now) {
  const cached = certsCache.get(env.ACCESS_TEAM_DOMAIN);
  let keys = cached && now - cached.fetchedAt < certsTtlMs ? cached.keys : null;
  if (!keys || !keys.some((k) => k.kid === kid)) {
    keys = (await fetchCerts(env.ACCESS_TEAM_DOMAIN)).keys ?? [];
    certsCache.set(env.ACCESS_TEAM_DOMAIN, { keys, fetchedAt: now });
  }
  const jwk = keys.find((k) => k.kid === kid);
  if (!jwk) return null;
  return crypto.subtle.importKey('jwk', { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: 'RS256', ext: true },
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
}

/**
 * The signed-in email, lower-cased, or null when the request carries no valid Access token for
 * this application. [fetchCerts] and [now] are for tests.
 */
export async function verifyAccess(request, env, { fetchCerts = defaultFetchCerts, now = Date.now() } = {}) {
  try {
    if (!env.ACCESS_AUD || !env.ACCESS_TEAM_DOMAIN) return null;
    const token = request.headers.get('Cf-Access-Jwt-Assertion');
    if (!token) return null;
    const [head, body, signature] = token.split('.');
    if (!head || !body || !signature) return null;
    const header = decodeJson(head);
    if (header.alg !== 'RS256' || !header.kid) return null;
    const key = await keyFor(header.kid, env, fetchCerts, now);
    if (!key) return null;
    const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, fromB64url(signature),
      new TextEncoder().encode(`${head}.${body}`));
    if (!valid) return null;
    const claims = decodeJson(body);
    const audiences = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
    if (!audiences.includes(env.ACCESS_AUD)) return null;
    if (typeof claims.exp !== 'number' || claims.exp * 1000 <= now) return null;
    if (typeof claims.email !== 'string' || !claims.email.includes('@')) return null;
    return { email: claims.email.toLowerCase() };
  } catch {
    return null;
  }
}

/** For tests: forget cached keys. */
export function clearAccessKeys() {
  certsCache.clear();
}
