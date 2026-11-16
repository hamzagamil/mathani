// The Worker's two jobs (specs/014 contracts/group-api.md › The Worker). Plain functions over the
// D1 binding and a `send(subject, text)` function, so Node tests run them.
import { isGone, lifetime } from '../../../functions/_lib/khatma-store.js';

/** Every minute: one message to the owner for each report not yet notified (FR-061, SC-020). A
 * failed send leaves the report for the next minute. */
export async function notifyReports(db, send, { page, now = () => Date.now() } = {}) {
  const rows = (await db.prepare(
    'SELECT * FROM reports WHERE notified_at IS NULL ORDER BY created_at LIMIT 20').all()).results;
  let sent = 0;
  for (const r of rows) {
    const subject = `Mathani report #${r.id}`;
    const text = [
      `Report #${r.id}: ${r.participant ? 'a name' : 'a whole group khatma'}.`,
      `Khatma: ${r.title}`,
      r.participant ? `Name: ${r.name}` : null,
      `Code: ${r.code}`,
      '',
      `Review it within 24 hours: ${page ?? 'https://get.mthani.app/editor/khatma.html'}`,
    ].filter((l) => l !== null).join('\n');
    try {
      await send(subject, text);
    } catch {
      continue;
    }
    await db.prepare('UPDATE reports SET notified_at = ? WHERE id = ?').bind(now(), r.id).run();
    sent++;
  }
  return sent;
}

/** Daily: delete khatmas past their lifetime with their parts and participants, and reports
 * closed more than 30 days ago (FR-066, research R21). */
export async function removeExpired(db, { now = () => Date.now() } = {}) {
  const t = now();
  const khatmas = (await db.prepare('SELECT code, changed_at, completed_at FROM khatmas').all()).results;
  const expired = khatmas.filter((k) => isGone(k, t)).map((k) => k.code);
  for (const code of expired) {
    await db.batch([
      db.prepare('DELETE FROM parts WHERE code = ?').bind(code),
      db.prepare('DELETE FROM participants WHERE code = ?').bind(code),
      db.prepare('DELETE FROM khatmas WHERE code = ?').bind(code),
    ]);
  }
  const reports = await db.prepare('DELETE FROM reports WHERE resolved_at IS NOT NULL AND resolved_at < ?')
    .bind(t - lifetime.closedReports).run();
  return { khatmas: expired.length, reports: reports.meta?.changes ?? 0 };
}

/** A plain-text email from [from] to [to], as the send_email binding takes it. */
export function mimeMessage({ from, to, subject, text, date = new Date() }) {
  const encode = (s) => `=?UTF-8?B?${btoa(String.fromCharCode(...new TextEncoder().encode(s)))}?=`;
  const body = btoa(String.fromCharCode(...new TextEncoder().encode(text))).replace(/.{76}/g, '$&\r\n');
  return [
    `From: Mathani <${from}>`,
    `To: ${to}`,
    `Subject: ${encode(subject)}`,
    `Date: ${date.toUTCString()}`,
    `Message-ID: <${crypto.randomUUID()}@mthani.app>`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: base64',
    '',
    body,
  ].join('\r\n');
}
