// The Mutashabihat editor's storage in D1 (specs/011 data-model.md): the working set of groups
// (published state plus the shared draft), the published versions, and the editors.
import { checkGroup, contentFormat, formatAyat, parse, render, sha256Hex } from './mutashabihat-content.js';

const alphabet = 'abcdefghijklmnopqrstuvwxyz234567';

function newId() {
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  return [...bytes].map((b) => alphabet[b % 32]).join('');
}

const sameContent = (a, b) => a.ayat === b.ayat && a.note === b.note && a.explanation === b.explanation;
const fields = (g) => ({ id: g.id, ayat: g.ayat, note: g.note, explanation: g.explanation });

/** A group as the API returns it (contracts/editor-api.md › Shapes). */
const shape = (row, status) => ({
  id: row.id,
  ayat: row.ayat,
  note: row.note,
  explanation: row.explanation,
  deleted: row.deleted === 1,
  revision: row.revision,
  updatedBy: row.updated_by,
  updatedAt: row.updated_at,
  status,
});

const versionShape = (v) =>
  v && {
    number: v.number,
    format: v.format,
    sha256: v.sha256,
    bytes: v.bytes,
    summary: JSON.parse(v.summary),
    publishedBy: v.published_by,
    publishedAt: v.published_at,
    restoredFrom: v.restored_from ?? null,
  };

/** Counts of groups added, changed and removed from [before] (a Map id → group) to [after]. */
function summarise(before, after) {
  const summary = { added: 0, changed: 0, removed: 0 };
  const seen = new Set();
  for (const g of after) {
    seen.add(g.id);
    const old = before.get(g.id);
    if (!old) summary.added++;
    else if (!sameContent(old, g)) summary.changed++;
  }
  for (const id of before.keys()) if (!seen.has(id)) summary.removed++;
  return summary;
}

export function editorStore(db, now = () => Date.now()) {
  const latest = () =>
    db.prepare('SELECT * FROM versions ORDER BY number DESC LIMIT 1').first();

  const rows = async () => (await db.prepare('SELECT rowid, * FROM groups ORDER BY rowid').all()).results;

  const publishedMap = (version) =>
    new Map(version ? JSON.parse(version.groups_json).map((g) => [g.id, g]) : []);

  /** Each row with its draft status (data-model.md › draft status). */
  function statusOf(row, published) {
    const old = published.get(row.id);
    if (row.deleted === 1) return old ? 'removed' : 'discarded';
    if (!old) return 'added';
    return sameContent(old, row) ? 'published' : 'changed';
  }

  async function working() {
    const [all, version] = await Promise.all([rows(), latest()]);
    const published = publishedMap(version);
    return { version, published, rows: all.map((r) => ({ row: r, status: statusOf(r, published) })) };
  }

  async function getRow(id) {
    return db.prepare('SELECT rowid, * FROM groups WHERE id = ?').bind(id).first();
  }

  async function withStatus(row) {
    return shape(row, statusOf(row, publishedMap(await latest())));
  }

  /** Saves a version made of [groups] (id, ayat, note, explanation, in order). */
  async function versionStatements(groups, email, summary, restoredFrom = null) {
    const number = ((await latest())?.number ?? 0) + 1;
    const content = render({ version: number, groups });
    const statement = db
      .prepare(`INSERT INTO versions (number, format, content, sha256, bytes, groups_json, summary,
                published_by, published_at, restored_from) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .bind(number, contentFormat, content, await sha256Hex(content), new TextEncoder().encode(content).length,
        JSON.stringify(groups.map(fields)), JSON.stringify(summary), email, now(), restoredFrom);
    return { number, statement };
  }

  async function versionByNumber(number) {
    return db.prepare('SELECT * FROM versions WHERE number = ?').bind(number).first();
  }

  return {
    async isEmpty() {
      const g = await db.prepare('SELECT COUNT(*) AS n FROM groups').first('n');
      const v = await db.prepare('SELECT COUNT(*) AS n FROM versions').first('n');
      return g === 0 && v === 0;
    },

    async isEditor(email) {
      return (await db.prepare('SELECT 1 AS ok FROM editors WHERE email = ?').bind(email).first()) !== null;
    },

    /** Every group except deletes of never-published groups, and the latest version. */
    async listGroups() {
      const w = await working();
      return {
        groups: w.rows.filter((x) => x.status !== 'discarded').map((x) => shape(x.row, x.status)),
        published: versionShape(w.version) ?? null,
      };
    },

    async getGroup(id) {
      const row = await getRow(id);
      return row ? withStatus(row) : { error: 'notFound' };
    },

    async createGroup(input, email) {
      const checked = checkGroup(input);
      if (!checked.ok) return { error: 'invalid', problems: checked.problems };
      const id = newId();
      await db
        .prepare(`INSERT INTO groups (id, ayat, note, explanation, deleted, revision, updated_by, updated_at)
                  VALUES (?, ?, ?, ?, 0, 1, ?, ?)`)
        .bind(id, checked.ayat, checked.note, checked.explanation, email, now())
        .run();
      return withStatus(await getRow(id));
    },

    /** Saves a group if nobody saved it since [revision] (research R4). */
    async updateGroup(id, input, email) {
      const row = await getRow(id);
      if (!row) return { error: 'notFound' };
      if (row.revision !== input.revision) return { error: 'conflict', group: await withStatus(row) };
      const checked = checkGroup(input);
      if (!checked.ok) return { error: 'invalid', problems: checked.problems };
      const result = await db
        .prepare(`UPDATE groups SET ayat = ?, note = ?, explanation = ?, revision = revision + 1,
                  updated_by = ?, updated_at = ? WHERE id = ? AND revision = ?`)
        .bind(checked.ayat, checked.note, checked.explanation, email, now(), id, input.revision)
        .run();
      if (result.meta.changes === 0) return { error: 'conflict', group: await withStatus(await getRow(id)) };
      return withStatus(await getRow(id));
    },

    async setDeleted(id, deleted, revision, email) {
      const row = await getRow(id);
      if (!row) return { error: 'notFound' };
      if (row.revision !== revision) return { error: 'conflict', group: await withStatus(row) };
      await db
        .prepare(`UPDATE groups SET deleted = ?, revision = revision + 1, updated_by = ?, updated_at = ?
                  WHERE id = ? AND revision = ?`)
        .bind(deleted ? 1 : 0, email, now(), id, revision)
        .run();
      return withStatus(await getRow(id));
    },

    /** What a publish would change, and the groups that would block it. */
    async draft() {
      const w = await working();
      const changes = w.rows
        .filter((x) => ['added', 'changed', 'removed'].includes(x.status))
        .map(({ row, status }) => ({
          id: row.id, status, ayat: row.ayat, updatedBy: row.updated_by, updatedAt: row.updated_at,
        }));
      const problems = [];
      for (const { row } of w.rows) {
        if (row.deleted === 1) continue;
        for (const p of checkGroup(row).problems) {
          if (p.isError) problems.push({ id: row.id, kind: p.kind, message: p.message });
        }
      }
      return { changes, problems };
    },

    /** Publishes the draft if it is still what the publisher saw ([expect], research R4). */
    async publish(expect, email) {
      const { changes, problems } = await this.draft();
      const ids = changes.map((c) => c.id).sort();
      if (JSON.stringify(ids) !== JSON.stringify([...expect].sort())) return { error: 'draftChanged', changes };
      if (changes.length === 0) return { error: 'nothingToPublish' };
      if (problems.length) return { error: 'invalid', problems };
      const w = await working();
      const live = w.rows.filter((x) => x.row.deleted !== 1).map((x) => fields(x.row));
      const { number, statement } = await versionStatements(live, email, summarise(w.published, live));
      try {
        await db.batch([statement, db.prepare('DELETE FROM groups WHERE deleted = 1')]);
      } catch {
        return { error: 'draftChanged', changes }; // someone else published this number first
      }
      return versionShape(await versionByNumber(number));
    },

    async listVersions() {
      const { results } = await db
        .prepare(`SELECT number, format, sha256, bytes, summary, published_by, published_at, restored_from
                  FROM versions ORDER BY number DESC`)
        .all();
      return results.map(versionShape);
    },

    async getVersion(number) {
      const v = await versionByNumber(number);
      return v ? { ...versionShape(v), groups: JSON.parse(v.groups_json) } : { error: 'notFound' };
    },

    /** Publishes an earlier version again, as a new version (FR-011, research R4). */
    async restore(number, discardDraft, email) {
      const old = await versionByNumber(number);
      if (!old) return { error: 'notFound' };
      const { changes } = await this.draft();
      if (changes.length && !discardDraft) return { error: 'draftNotEmpty', changes };
      const w = await working();
      const revisions = new Map(w.rows.map((x) => [x.row.id, x.row.revision]));
      const groups = JSON.parse(old.groups_json);
      const { number: next, statement } =
        await versionStatements(groups, email, summarise(w.published, groups), number);
      const at = now();
      await db.batch([
        db.prepare('DELETE FROM groups'),
        ...groups.map((g) =>
          db
            .prepare(`INSERT INTO groups (id, ayat, note, explanation, deleted, revision, updated_by, updated_at)
                      VALUES (?, ?, ?, ?, 0, ?, ?, ?)`)
            .bind(g.id, g.ayat, g.note, g.explanation, (revisions.get(g.id) ?? 0) + 1, email, at)),
        statement,
      ]);
      return versionShape(await versionByNumber(next));
    },

    async listEditors() {
      const { results } = await db.prepare('SELECT email, added_at FROM editors ORDER BY email').all();
      return results.map((r) => ({ email: r.email, addedAt: r.added_at }));
    },

    async addEditor(email, owner) {
      const clean = String(email ?? '').trim().toLowerCase();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(clean) || clean === owner) return { error: 'email' };
      if (await this.isEditor(clean)) return { error: 'exists' };
      await db.prepare('INSERT INTO editors (email, added_by, added_at) VALUES (?, ?, ?)').bind(clean, owner, now()).run();
      return { email: clean };
    },

    async removeEditor(email) {
      const result = await db.prepare('DELETE FROM editors WHERE email = ?').bind(String(email).toLowerCase()).run();
      return result.meta.changes ? {} : { error: 'notFound' };
    },

    /** The first use: today's content becomes the groups and version 1 (FR-008). */
    async importMarkdown(markdown, email) {
      if (!(await this.isEmpty())) return { error: 'notEmpty' };
      const parsed = parse(String(markdown ?? ''));
      const errors = parsed.problems.filter((p) => p.isError);
      if (errors.length || parsed.groups.length === 0) {
        return { error: 'invalid', problems: errors.map((p) => ({ kind: p.kind, message: p.message })) };
      }
      const at = now();
      const groups = parsed.groups.map((g) => ({
        id: newId(), ayat: formatAyat(g.ayat), note: g.note, explanation: g.explanation,
      }));
      const { number, statement } = await versionStatements(groups, email, { added: groups.length, changed: 0, removed: 0 });
      await db.batch([
        ...groups.map((g) =>
          db
            .prepare(`INSERT INTO groups (id, ayat, note, explanation, deleted, revision, updated_by, updated_at)
                      VALUES (?, ?, ?, ?, 0, 1, ?, ?)`)
            .bind(g.id, g.ayat, g.note, g.explanation, email, at)),
        statement,
      ]);
      return versionShape(await versionByNumber(number));
    },

    /** For the content endpoint: the latest version number, or null. */
    async currentNumber() {
      return db.prepare('SELECT MAX(number) AS n FROM versions').first('n');
    },

    async content(number) {
      return db.prepare('SELECT number, format, content, sha256 FROM versions WHERE number = ?').bind(number).first();
    },
  };
}
