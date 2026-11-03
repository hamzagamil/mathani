// Test helpers for the Mutashabihat functions (specs/011 research R10): a D1 stand-in over
// node:sqlite with the real schema, and Cloudflare Access tokens signed with a test key.
import { generateKeyPairSync, sign as rsaSign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';

export const base = 'https://get.mthani.app';
const schema = readFileSync(new URL('../../functions/_lib/mutashabihat-schema.sql', import.meta.url), 'utf8');

class Statement {
  constructor(db, sql, params = []) {
    this.db = db;
    this.sql = sql;
    this.params = params;
  }
  bind(...params) {
    return new Statement(this.db, this.sql, params);
  }
  _first() {
    const row = this.db.prepare(this.sql).get(...this.params);
    return row ? { ...row } : null;
  }
  _all() {
    return { results: this.db.prepare(this.sql).all(...this.params).map((r) => ({ ...r })), success: true };
  }
  _run() {
    const info = this.db.prepare(this.sql).run(...this.params);
    return { success: true, meta: { changes: info.changes, last_row_id: Number(info.lastInsertRowid) } };
  }
  async first(column) {
    const row = this._first();
    return row && column ? row[column] : row;
  }
  async all() {
    return this._all();
  }
  async run() {
    return this._run();
  }
}

/** A D1-like database in memory, with the Mutashabihat schema applied. */
export function d1() {
  const db = new DatabaseSync(':memory:');
  db.exec(schema);
  return {
    raw: db,
    prepare: (sql) => new Statement(db, sql),
    async batch(statements) {
      db.exec('BEGIN');
      try {
        const results = statements.map((s) => (/^\s*select/i.test(s.sql) ? s._all() : s._run()));
        db.exec('COMMIT');
        return results;
      } catch (e) {
        db.exec('ROLLBACK');
        throw e;
      }
    },
    async exec(sql) {
      db.exec(sql);
    },
  };
}

const b64url = (data) => Buffer.from(data).toString('base64url');

/** A test Access team: signs tokens and serves its public keys like /cdn-cgi/access/certs. */
export function accessKeys() {
  const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const kid = 'test-key';
  const jwk = { ...publicKey.export({ format: 'jwk' }), kid, alg: 'RS256', use: 'sig' };
  return {
    sign({ email, aud = 'aud1', exp = Math.floor(Date.now() / 1000) + 3600, keyId = kid }) {
      const head = b64url(JSON.stringify({ alg: 'RS256', kid: keyId, typ: 'JWT' }));
      const body = b64url(JSON.stringify({ email, aud: [aud], exp, iss: 'https://t.cloudflareaccess.com' }));
      const signature = rsaSign('sha256', Buffer.from(`${head}.${body}`), privateKey);
      return `${head}.${body}.${b64url(signature)}`;
    },
    fetchCerts: async () => ({ keys: [jwk] }),
  };
}

export function environment(db = d1()) {
  return {
    DB: db,
    OWNER_EMAIL: 'owner@example.com',
    ACCESS_TEAM_DOMAIN: 't.cloudflareaccess.com',
    ACCESS_AUD: 'aud1',
  };
}

/** A request to the editor API as a browser on the same origin would send it. */
export function request(path, { method = 'GET', body, token, origin = base, headers = {} } = {}) {
  const h = { ...headers };
  if (token) h['Cf-Access-Jwt-Assertion'] = token;
  if (body !== undefined) h['Content-Type'] = 'application/json';
  if (origin && method !== 'GET') h.Origin = origin;
  return new Request(base + path, { method, headers: h, body: body === undefined ? undefined : JSON.stringify(body) });
}

/** An in-memory stand-in for caches.default. */
export function memoryCache() {
  const store = new Map();
  return {
    store,
    async match(key) {
      const hit = store.get(typeof key === 'string' ? key : key.url);
      return hit ? hit.clone() : undefined;
    },
    async put(key, response) {
      store.set(typeof key === 'string' ? key : key.url, response.clone());
    },
  };
}

export const shippedMarkdown = () =>
  readFileSync(new URL('../../assets/mutashabihat/mutashabihat.md', import.meta.url), 'utf8');
export const fixtureMarkdown = () =>
  readFileSync(new URL('../../test/fixtures/mutashabihat/quickstart.md', import.meta.url), 'utf8');
