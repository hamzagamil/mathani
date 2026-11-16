// The owner's two endpoints for group khatma reports (specs/014 contracts/group-api.md › Owner
// endpoints), under /api/editor/khatma/ behind Cloudflare Access, for OWNER_EMAIL only.
import { khatmaStore } from './khatma-store.js';

/** `{status, body}` for [method] on [path] (after `khatma/`). */
export async function khatmaAdmin(method, path, body, env, now = () => Date.now()) {
  const db = env.KHATMA_DB;
  if (!db) return { status: 503, body: { error: 'unavailable' } };
  const [resource, id, action] = path;
  if (method === 'GET' && resource === 'reports' && !id) {
    const rows = (await db.prepare(
      'SELECT r.*, (SELECT COUNT(*) FROM khatmas k WHERE k.code = r.code) AS present FROM reports r ' +
      'ORDER BY (r.resolved_at IS NOT NULL), r.created_at DESC LIMIT 500').all()).results;
    return { status: 200, body: { reports: rows.map(report) } };
  }
  if (method === 'POST' && resource === 'reports' && id && action === 'resolve') {
    const row = await db.prepare('SELECT * FROM reports WHERE id = ?').bind(Number(id)).first();
    if (!row) return { status: 404, body: { error: 'notFound' } };
    const what = body.action;
    if (!['none', 'name', 'khatma'].includes(what)) return { status: 422, body: { error: 'invalid' } };
    const store = khatmaStore(db, now);
    if (what === 'name' && row.participant) {
      await store.removeParticipant(row.code, row.participant, null, { asOwner: true });
    } else if (what === 'khatma') {
      await store.remove(row.code, null, { asOwner: true });
    }
    const block = body.block === true && row.poster;
    if (block) {
      await db.prepare('INSERT OR IGNORE INTO blocks (key_hash, blocked_at, report) VALUES (?, ?, ?)')
        .bind(row.poster, now(), row.id).run();
    }
    await db.prepare('UPDATE reports SET resolved_at = ?, action = ? WHERE id = ?')
      .bind(now(), `${what}${block ? '+block' : ''}`, row.id).run();
    const updated = await db.prepare(
      'SELECT r.*, (SELECT COUNT(*) FROM khatmas k WHERE k.code = r.code) AS present FROM reports r WHERE r.id = ?')
      .bind(row.id).first();
    return { status: 200, body: report(updated) };
  }
  return { status: 404, body: { error: 'notFound' } };
}

const report = (r) => ({
  id: r.id,
  code: r.code,
  participant: r.participant ?? null,
  title: r.title,
  name: r.name,
  createdAt: r.created_at,
  resolvedAt: r.resolved_at ?? null,
  action: r.action ? r.action.replace('+block', '') : null,
  blocked: (r.action ?? '').endsWith('+block'),
  exists: r.present > 0,
});
