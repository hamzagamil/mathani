// Test helpers for the group khatma functions (specs/014 research R25): a D1 stand-in over
// node:sqlite with the real schema, keys, and a client for /api/khatma.
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';

import { dispatch } from '../../functions/_lib/khatma-api.js';

export const base = 'https://get.mthani.app';
const schema = readFileSync(new URL('../../functions/_lib/khatma-schema.sql', import.meta.url), 'utf8');

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

/** A D1-like database in memory, with the khatma schema applied. */
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
  };
}

/** A device key: 43 base64url characters, distinct for each [n]. */
export const key = (n) => Buffer.alloc(32, n).toString('base64url');

/** A server over a fresh database, a clock the test moves, and a client. */
export function server() {
  const env = { KHATMA_DB: d1() };
  let clock = Date.UTC(2026, 2, 1, 9);
  const call = async (path, { method = 'GET', body, as, origin = base, headers = {}, raw } = {}) => {
    const h = { ...headers };
    if (as !== undefined) h['X-Mathani-Key'] = typeof as === 'number' ? key(as) : as;
    if (body !== undefined) h['Content-Type'] = 'application/json';
    if (origin && method !== 'GET') h.Origin = origin;
    const request = new Request(`${base}/api/khatma${path}`, {
      method,
      headers: h,
      body: raw !== undefined ? raw : body === undefined ? undefined : JSON.stringify(body),
    });
    const response = await dispatch(request, env, { now: () => clock });
    const text = await response.text();
    return { status: response.status, body: text ? JSON.parse(text) : null, headers: response.headers };
  };
  return {
    env,
    db: env.KHATMA_DB,
    call,
    advance: (ms) => (clock += ms),
    now: () => clock,
    /** Starts a khatma as key [as] and returns its snapshot. */
    async start({ as = 1, title = 'Family khatma', name = 'Amina', division = 30, finishDate } = {}) {
      const r = await call('', { method: 'POST', as, body: { title, name, division, finishDate, terms: 1 } });
      if (r.status !== 201) throw new Error(`start: ${r.status} ${JSON.stringify(r.body)}`);
      return r.body;
    },
    /** Takes part [n] as key [as], joining with [name] the first time. */
    take: (code, n, as, name = `Reader ${as}`) =>
      call(`/${code}/parts/${n}/take`, { method: 'POST', as, body: { name, terms: 1 } }),
  };
}

/** Every text value in the database, to check that a name is gone (SC-019). */
export function allText(db) {
  const out = [];
  for (const table of ['khatmas', 'participants', 'parts', 'reports', 'blocks']) {
    for (const row of db.raw.prepare(`SELECT * FROM ${table}`).all()) {
      for (const v of Object.values(row)) if (typeof v === 'string') out.push(`${table}:${v}`);
    }
  }
  return out;
}
