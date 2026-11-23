// The owner's announcements (specs/018 contracts/announcements-api.md), under
// /api/editor/announcements behind Cloudflare Access, for OWNER_EMAIL only (checked by the
// editor dispatcher). Every attempt is stored before FCM is called; one requestId sends once.
import * as fcm from './fcm.js';

const AUDIENCES = new Set(['all', 'lang_ar', 'lang_en']);
const TTLS = new Set([3600, 86400, 604800, 2419200]);
const LINK_HOSTS = new Set(['mthani.app', 'www.mthani.app', 'get.mthani.app']);
const PER_HOUR = 10;
const HOUR_MS = 3_600_000;
const HISTORY = 100;

/** Characters as the page counts them: code points. */
export const count = (text) => [...text].length;

const row = (r) => ({
  id: r.id,
  audience: r.audience,
  title: r.title,
  body: r.body,
  link: r.link ?? null,
  ttl: r.ttl,
  sentBy: r.sent_by,
  createdAt: r.created_at,
  status: r.status,
  message: r.message ?? null,
  detail: r.detail ?? null,
});

const invalid = (field) => ({ status: 422, body: { error: 'invalid', field } });

/** The link if it is an https Mathani link, null when empty, undefined when not allowed. */
export function checkLink(value) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || value.length > 500) return undefined;
  let url;
  try {
    url = new URL(value);
  } catch {
    return undefined;
  }
  if (url.protocol !== 'https:' || !LINK_HOSTS.has(url.hostname) || url.username || url.password) return undefined;
  return value;
}

function validate(body) {
  const { requestId, audience } = body;
  if (typeof requestId !== 'string' || requestId.length < 8 || requestId.length > 64) return invalid('requestId');
  if (!AUDIENCES.has(audience)) return invalid('audience');
  const title = typeof body.title === 'string' ? body.title.trim() : '';
  if (count(title) < 1 || count(title) > 65) return invalid('title');
  const text = typeof body.body === 'string' ? body.body.trim() : '';
  if (count(text) < 1 || count(text) > 240) return invalid('body');
  const link = checkLink(body.link);
  if (link === undefined) return invalid('link');
  const ttl = body.ttl === undefined || body.ttl === null ? 86400 : body.ttl;
  if (typeof ttl !== 'number' || !TTLS.has(ttl)) return invalid('ttl');
  return { value: { requestId, audience, title, body: text, link, ttl } };
}

/** The FCM message (research R3), matching specs/015 contracts/announcements.md. */
export function fcmMessage(a, nowMs) {
  const message = {
    topic: a.audience,
    notification: { title: a.title, body: a.body },
    android: { ttl: `${a.ttl}s`, notification: { channel_id: 'announcements_v1' } },
    apns: { headers: { 'apns-expiration': String(Math.floor(nowMs / 1000) + a.ttl) } },
  };
  if (a.link) message.data = { link: a.link };
  return message;
}

async function limit(db, nowMs) {
  const rows = (await db.prepare(
    "SELECT created_at FROM announcements WHERE status IN ('sending', 'sent') AND created_at > ? " +
    'ORDER BY created_at ASC').bind(nowMs - HOUR_MS).all()).results;
  return {
    perHour: PER_HOUR,
    used: rows.length,
    retryAt: rows.length >= PER_HOUR ? rows[rows.length - PER_HOUR].created_at + HOUR_MS : null,
  };
}

const byRequest = (db, requestId) =>
  db.prepare('SELECT * FROM announcements WHERE request_id = ?').bind(requestId).first();

/** `{status, body}` for [method] on /api/editor/announcements, for the owner [who]. */
export async function announcementsAdmin(method, body, env, who, { now = () => Date.now(), fetch } = {}) {
  const db = env.DB;
  if (!db) return { status: 503, body: { error: 'unavailable' } };

  if (method === 'GET') {
    const rows = (await db.prepare(
      `SELECT * FROM announcements ORDER BY created_at DESC, id DESC LIMIT ${HISTORY}`).all()).results;
    return {
      status: 200,
      body: { configured: fcm.isConfigured(env), limit: await limit(db, now()), announcements: rows.map(row) },
    };
  }

  if (method !== 'POST') return { status: 404, body: { error: 'notFound' } };

  const checked = validate(body ?? {});
  if (!checked.value) return checked;
  const a = checked.value;

  const existing = await byRequest(db, a.requestId);
  if (existing) return { status: 200, body: row(existing) };

  const at = now();
  const l = await limit(db, at);
  if (l.retryAt !== null) return { status: 429, body: { error: 'limit', retryAt: l.retryAt } };

  let id;
  try {
    const result = await db.prepare(
      'INSERT INTO announcements (request_id, audience, title, body, link, ttl, sent_by, created_at, status) ' +
      "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'sending')")
      .bind(a.requestId, a.audience, a.title, a.body, a.link, a.ttl, who.email, at).run();
    id = result.meta.last_row_id;
  } catch (e) {
    // Two requests with one requestId at once: the other one sends.
    const raced = await byRequest(db, a.requestId);
    if (raced) return { status: 200, body: row(raced) };
    throw e;
  }

  const outcome = await fcm.send(env, fcmMessage(a, at), { fetch, now: at });
  await db.prepare('UPDATE announcements SET status = ?, message = ?, detail = ?, finished_at = ? WHERE id = ?')
    .bind(outcome.status, outcome.message ?? null, outcome.detail ?? null, now(), id).run();
  const stored = await db.prepare('SELECT * FROM announcements WHERE id = ?').bind(id).first();
  return { status: 201, body: row(stored) };
}
