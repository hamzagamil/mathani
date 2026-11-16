// Group khatmas in D1 (specs/014 data-model.md › 4, contracts/group-api.md). Every write raises
// the khatma's version. Results are `{status, body}`; errors carry `{error}` in the body.
import { check } from './khatma-text.js';

export const TERMS_VERSION = 1;
export const DAY = 24 * 60 * 60 * 1000;
export const limits = { organised: 5, startedPerKey: 20, startedPerDay: 2000, reportsPerKey: 10 };
export const lifetime = { afterComplete: 30 * DAY, idle: 90 * DAY, closedReports: 30 * DAY };

const crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/** [length] random Crockford base32 characters (5 random bits each). */
export function randomCode(length = 16) {
  const bytes = crypto.getRandomValues(new Uint8Array(Math.ceil((length * 5) / 8)));
  let bits = 0, value = 0, out = '';
  for (const b of bytes) {
    value = (value << 8) | b;
    bits += 8;
    while (bits >= 5 && out.length < length) {
      out += crockford[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  return out;
}

export const codePattern = /^[0-9A-HJKMNP-TV-Z]{16}$/;

/** The SHA-256 of a key, in hex. The key itself is never stored. */
export async function hashKey(key) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(key));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

const fail = (status, error, extra = {}) => ({ status, body: { error, ...extra } });
const ok = (body, status = 200) => ({ status, body });

/** Whether [k] is past its lifetime (FR-066). */
export const isGone = (k, now) =>
  (k.completed_at != null && now - k.completed_at > lifetime.afterComplete) ||
  now - k.changed_at > lifetime.idle;

const dateOk = (d) => d == null || (/^\d{4}-\d{2}-\d{2}$/.test(d) && !Number.isNaN(Date.parse(`${d}T00:00:00Z`)));

export function khatmaStore(db, now = () => Date.now()) {
  const one = (sql, ...params) => db.prepare(sql).bind(...params).first();
  const all = async (sql, ...params) => (await db.prepare(sql).bind(...params).all()).results;
  const run = (sql, ...params) => db.prepare(sql).bind(...params).run();

  async function khatma(code) {
    if (!codePattern.test(code ?? '')) return null;
    const k = await one('SELECT * FROM khatmas WHERE code = ?', code);
    return k && !isGone(k, now()) ? k : null;
  }

  const blocked = async (keyHash) => !!(await one('SELECT 1 AS b FROM blocks WHERE key_hash = ?', keyHash));
  const member = (code, keyHash) =>
    one('SELECT * FROM participants WHERE code = ? AND key_hash = ?', code, keyHash);

  async function touch(code, extra = '') {
    await run(`UPDATE khatmas SET version = version + 1, changed_at = ?${extra} WHERE code = ?`, now(), code);
  }

  /** The Snapshot of contracts/group-api.md › Shapes. */
  async function snapshot(code, keyHash) {
    const k = await one('SELECT * FROM khatmas WHERE code = ?', code);
    if (!k) return null;
    const parts = await all('SELECT number, holder, read_at FROM parts WHERE code = ? ORDER BY number', code);
    const people = await all('SELECT id, name, key_hash, removed FROM participants WHERE code = ?', code);
    const organiser = people.find((p) => p.key_hash === k.organiser && !p.removed);
    const holders = new Set(parts.map((p) => p.holder).filter(Boolean));
    const me = keyHash ? people.find((p) => p.key_hash === keyHash && !p.removed) : null;
    const counts = { free: 0, taken: 0, read: 0 };
    const out = parts.map((p) => {
      const state = p.read_at != null ? 'read' : p.holder ? 'taken' : 'free';
      counts[state]++;
      return { n: p.number, state, holder: p.holder ?? null, readAt: p.read_at ?? null };
    });
    return {
      code: k.code,
      title: k.title,
      division: k.division,
      finishDate: k.finish_date ?? null,
      version: k.version,
      createdAt: k.created_at,
      completedAt: k.completed_at ?? null,
      counts,
      organiser: organiser?.id ?? null,
      parts: out,
      participants: people
        .filter((p) => !p.removed && (holders.has(p.id) || p === organiser))
        .map((p) => ({ id: p.id, name: p.name, typed: p.key_hash == null })),
      you: {
        id: me?.id ?? null,
        role: keyHash && keyHash === k.organiser ? 'organiser' : me ? 'participant' : 'viewer',
      },
    };
  }

  const snap = async (code, keyHash, status = 200) => ok(await snapshot(code, keyHash), status);

  async function newParticipant(code, name, keyHash) {
    const id = randomCode(12);
    await run('INSERT OR IGNORE INTO participants (id, code, name, key_hash, removed, joined_at) VALUES (?, ?, ?, ?, 0, ?)',
      id, code, name, keyHash, now());
    return keyHash == null ? { id } : member(code, keyHash);
  }

  /** Who may change part [n]: its holder, or the organiser. */
  async function partFor(code, n, k, keyHash) {
    const number = Number(n);
    if (!Number.isInteger(number) || number < 1 || number > k.division) return { error: fail(404, 'gone') };
    const part = await one('SELECT * FROM parts WHERE code = ? AND number = ?', code, number);
    const me = await member(code, keyHash);
    const organiser = keyHash === k.organiser;
    const mine = me && !me.removed && part.holder === me.id;
    return { part, number, organiser, mine };
  }

  async function completion(code) {
    const left = await one('SELECT COUNT(*) AS n FROM parts WHERE code = ? AND read_at IS NULL', code);
    return left.n === 0;
  }

  return {
    khatma,
    snapshot,
    blocked,

    async read(code, keyHash) {
      const k = await khatma(code);
      if (!k) return fail(404, 'gone');
      return snap(code, keyHash);
    },

    async create(body, keyHash) {
      if (await blocked(keyHash)) return fail(403, 'blocked');
      if (body.terms !== TERMS_VERSION) return fail(422, 'terms', { current: TERMS_VERSION });
      const title = check('title', body.title);
      if (title.problem) return fail(422, 'invalid', { problem: title.problem });
      const name = check('name', body.name);
      if (name.problem) return fail(422, 'invalid', { problem: name.problem });
      if (body.division !== 30 && body.division !== 60) {
        return fail(422, 'invalid', { problem: { field: 'division', kind: 'value' } });
      }
      const finish = body.finishDate ?? null;
      if (!dateOk(finish)) return fail(422, 'invalid', { problem: { field: 'finishDate', kind: 'value' } });
      const t = now();
      const mine = await all('SELECT completed_at, changed_at, created_at FROM khatmas WHERE organiser = ?', keyHash);
      const open = mine.filter((k) => k.completed_at == null && !isGone(k, t)).length;
      if (open >= limits.organised) return fail(429, 'limit', { which: 'organised' });
      if (mine.filter((k) => k.created_at > t - DAY).length >= limits.startedPerKey) {
        return fail(429, 'limit', { which: 'started' });
      }
      const today = await one('SELECT COUNT(*) AS n FROM khatmas WHERE created_at > ?', t - DAY);
      if (today.n >= limits.startedPerDay) return fail(429, 'limit', { which: 'busy' });
      const code = randomCode(16);
      await run('INSERT INTO khatmas (code, title, division, finish_date, organiser, version, created_at, changed_at) VALUES (?, ?, ?, ?, ?, 1, ?, ?)',
        code, title.text, body.division, finish, keyHash, t, t);
      await db.batch(Array.from({ length: body.division }, (_, i) =>
        db.prepare('INSERT INTO parts (code, number) VALUES (?, ?)').bind(code, i + 1)));
      await newParticipant(code, name.text, keyHash);
      return snap(code, keyHash, 201);
    },

    async take(code, n, body, keyHash) {
      const k = await khatma(code);
      if (!k) return fail(404, 'gone');
      if (await blocked(keyHash)) return fail(403, 'blocked');
      if (k.completed_at != null) return fail(409, 'complete', { snapshot: await snapshot(code, keyHash) });
      let me = await member(code, keyHash);
      if (me?.removed) return fail(403, 'removed');
      const number = Number(n);
      if (!Number.isInteger(number) || number < 1 || number > k.division) return fail(404, 'gone');
      if (!me) {
        if (body.terms !== TERMS_VERSION) return fail(422, 'terms', { current: TERMS_VERSION });
        const name = check('name', body.name);
        if (name.problem) return fail(422, 'invalid', { problem: name.problem });
        me = await newParticipant(code, name.text, keyHash);
      }
      // One statement: the part has no holder and is not read. Two at once: one changes the row.
      const result = await run('UPDATE parts SET holder = ? WHERE code = ? AND number = ? AND holder IS NULL AND read_at IS NULL',
        me.id, code, number);
      if (!result.meta.changes) return fail(409, 'taken', { snapshot: await snapshot(code, keyHash) });
      await touch(code);
      return snap(code, keyHash);
    },

    async release(code, n, keyHash) {
      const k = await khatma(code);
      if (!k) return fail(404, 'gone');
      const p = await partFor(code, n, k, keyHash);
      if (p.error) return p.error;
      if (!p.mine && !p.organiser) return fail(409, 'notYours', { snapshot: await snapshot(code, keyHash) });
      if (p.part.read_at != null) return fail(409, 'read', { snapshot: await snapshot(code, keyHash) });
      if (!p.part.holder) return snap(code, keyHash);
      await run('UPDATE parts SET holder = NULL WHERE code = ? AND number = ?', code, p.number);
      await touch(code);
      return snap(code, keyHash);
    },

    async markRead(code, n, body, keyHash) {
      const k = await khatma(code);
      if (!k) return fail(404, 'gone');
      const p = await partFor(code, n, k, keyHash);
      if (p.error) return p.error;
      if (!p.mine && !p.organiser) return fail(409, 'notYours', { snapshot: await snapshot(code, keyHash) });
      const read = body.read !== false;
      if (read) {
        if (p.part.read_at != null) return snap(code, keyHash); // sent twice: the same state
        if (!p.part.holder) return fail(409, 'notYours', { snapshot: await snapshot(code, keyHash) });
        await run('UPDATE parts SET read_at = ? WHERE code = ? AND number = ?', now(), code, p.number);
        await touch(code, (await completion(code)) ? `, completed_at = ${Number(now())}` : '');
        return snap(code, keyHash);
      }
      if (p.part.read_at == null) return snap(code, keyHash);
      if (k.completed_at != null && !p.organiser) {
        return fail(409, 'complete', { snapshot: await snapshot(code, keyHash) });
      }
      await run('UPDATE parts SET read_at = NULL WHERE code = ? AND number = ?', code, p.number);
      await touch(code, ', completed_at = NULL');
      return snap(code, keyHash);
    },

    async assign(code, n, body, keyHash) {
      const k = await khatma(code);
      if (!k) return fail(404, 'gone');
      if (keyHash !== k.organiser) return fail(403, 'organiser');
      if (await blocked(keyHash)) return fail(403, 'blocked');
      const number = Number(n);
      if (!Number.isInteger(number) || number < 1 || number > k.division) return fail(404, 'gone');
      const name = check('name', body.name);
      if (name.problem) return fail(422, 'invalid', { problem: name.problem });
      const part = await one('SELECT * FROM parts WHERE code = ? AND number = ?', code, number);
      if (part.holder || part.read_at != null) return fail(409, 'taken', { snapshot: await snapshot(code, keyHash) });
      const typed = await newParticipant(code, name.text, null);
      const result = await run('UPDATE parts SET holder = ? WHERE code = ? AND number = ? AND holder IS NULL AND read_at IS NULL',
        typed.id, code, number);
      if (!result.meta.changes) {
        await run('DELETE FROM participants WHERE id = ?', typed.id);
        return fail(409, 'taken', { snapshot: await snapshot(code, keyHash) });
      }
      await touch(code);
      return snap(code, keyHash);
    },

    async leave(code, keyHash) {
      const k = await khatma(code);
      if (!k) return fail(404, 'gone');
      if (keyHash === k.organiser) return fail(409, 'organiser');
      const me = await member(code, keyHash);
      if (!me) return ok(null, 204);
      // Unread parts become free; read parts stay read with no name (FR-058).
      await run('UPDATE parts SET holder = NULL WHERE code = ? AND holder = ?', code, me.id);
      await run('DELETE FROM participants WHERE id = ?', me.id);
      await touch(code);
      return ok(null, 204);
    },

    async removeParticipant(code, id, keyHash, { asOwner = false } = {}) {
      const k = await khatma(code);
      if (!k) return fail(404, 'gone');
      if (!asOwner && keyHash !== k.organiser) return fail(403, 'organiser');
      const p = await one('SELECT * FROM participants WHERE code = ? AND id = ? AND removed = 0', code, id);
      if (!p) return fail(404, 'notFound');
      await run('UPDATE parts SET holder = NULL WHERE code = ? AND holder = ?', code, p.id);
      // The row stays, marked removed and nameless, so that key cannot join again (FR-062).
      await run("UPDATE participants SET name = '', removed = 1 WHERE id = ?", p.id);
      await touch(code);
      return snap(code, keyHash);
    },

    async patch(code, body, keyHash) {
      const k = await khatma(code);
      if (!k) return fail(404, 'gone');
      if (keyHash !== k.organiser) return fail(403, 'organiser');
      let title = k.title;
      if (body.title !== undefined) {
        const t = check('title', body.title);
        if (t.problem) return fail(422, 'invalid', { problem: t.problem });
        title = t.text;
      }
      let finish = k.finish_date;
      if (body.finishDate !== undefined) {
        if (!dateOk(body.finishDate)) return fail(422, 'invalid', { problem: { field: 'finishDate', kind: 'value' } });
        finish = body.finishDate;
      }
      await run('UPDATE khatmas SET title = ?, finish_date = ? WHERE code = ?', title, finish, code);
      await touch(code);
      return snap(code, keyHash);
    },

    /** Deletes a khatma and every row under it (FR-062, FR-066). */
    async remove(code, keyHash, { asOwner = false } = {}) {
      const k = await one('SELECT * FROM khatmas WHERE code = ?', code);
      if (!k || (!asOwner && isGone(k, now()))) return fail(404, 'gone');
      if (!asOwner && keyHash !== k.organiser) return fail(403, 'organiser');
      await db.batch([
        db.prepare('DELETE FROM parts WHERE code = ?').bind(code),
        db.prepare('DELETE FROM participants WHERE code = ?').bind(code),
        db.prepare('DELETE FROM khatmas WHERE code = ?').bind(code),
      ]);
      return ok(null, 204);
    },

    async report(code, body, keyHash) {
      const k = await khatma(code);
      if (!k) return fail(404, 'gone');
      if (await blocked(keyHash)) return fail(403, 'blocked');
      const recent = await one('SELECT COUNT(*) AS n FROM reports WHERE reporter = ? AND created_at > ?',
        keyHash, now() - DAY);
      if (recent.n >= limits.reportsPerKey) return fail(429, 'limit', { which: 'reports' });
      let name = '', poster = k.organiser, participant = null;
      if (body.participant != null) {
        const p = await one('SELECT * FROM participants WHERE code = ? AND id = ? AND removed = 0', code, String(body.participant));
        if (!p) return fail(404, 'notFound');
        participant = p.id;
        name = p.name;
        // A typed name was posted by the organiser.
        poster = p.key_hash ?? k.organiser;
      }
      await run('INSERT INTO reports (code, participant, title, name, poster, reporter, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        code, participant, k.title, name, poster, keyHash, now());
      return ok(null, 202);
    },
  };
}
