// The Worker's jobs (specs/014 contracts/group-api.md › The Worker).
import test from 'node:test';
import assert from 'node:assert/strict';

import { mimeMessage, notifyReports, removeExpired } from '../../workers/khatma-ops/src/jobs.js';
import { server } from './support.mjs';

const DAY = 24 * 60 * 60 * 1000;

test('the minute job emails each new report once, and retries a failed send', async () => {
  const s = server();
  const k = await s.start({ title: 'Family' });
  const taken = await s.take(k.code, 1, 2, 'Some Name');
  await s.call(`/${k.code}/report`, { method: 'POST', as: 3, body: { participant: taken.body.parts[0].holder } });
  const sent = [];
  let failing = true;
  const send = async (subject, text) => {
    if (failing) throw new Error('down');
    sent.push({ subject, text });
  };
  assert.equal(await notifyReports(s.db, send, { now: s.now }), 0);
  failing = false;
  assert.equal(await notifyReports(s.db, send, { now: s.now, page: 'https://get.mthani.app/editor/khatma.html' }), 1);
  assert.equal(await notifyReports(s.db, send, { now: s.now }), 0, 'once only');
  assert.equal(sent.length, 1);
  assert.match(sent[0].subject, /report #1/);
  assert.match(sent[0].text, /Khatma: Family/);
  assert.match(sent[0].text, /Name: Some Name/);
  assert.match(sent[0].text, /editor\/khatma\.html/);
});

test('the daily job removes what is past its lifetime, and nothing else', async () => {
  const s = server();
  const done = await s.start({ as: 1 });
  const idle = await s.start({ as: 2 });
  const fresh = await s.start({ as: 3 });
  s.db.raw.prepare('UPDATE khatmas SET completed_at = ? WHERE code = ?').run(s.now() - 31 * DAY, done.code);
  s.db.raw.prepare('UPDATE khatmas SET changed_at = ? WHERE code = ?').run(s.now() - 91 * DAY, idle.code);
  s.db.raw.prepare("INSERT INTO reports (code, title, name, reporter, created_at, resolved_at) VALUES ('x', 't', 'n', 'r', 0, ?)")
    .run(s.now() - 31 * DAY);
  s.db.raw.prepare("INSERT INTO reports (code, title, name, reporter, created_at, resolved_at) VALUES ('y', 't', 'n', 'r', 0, ?)")
    .run(s.now() - 5 * DAY);
  s.db.raw.prepare("INSERT INTO reports (code, title, name, reporter, created_at) VALUES ('z', 't', 'n', 'r', 0)").run();
  const result = await removeExpired(s.db, { now: s.now });
  assert.deepEqual(result, { khatmas: 2, reports: 1 });
  const codes = s.db.raw.prepare('SELECT code FROM khatmas').all().map((r) => r.code);
  assert.deepEqual(codes, [fresh.code]);
  assert.equal(s.db.raw.prepare('SELECT COUNT(*) AS n FROM parts').get().n, 30);
  assert.equal(s.db.raw.prepare('SELECT COUNT(*) AS n FROM participants').get().n, 1);
  assert.equal(s.db.raw.prepare('SELECT COUNT(*) AS n FROM reports').get().n, 2);
});

test('the email is plain text, UTF-8, to the owner', () => {
  const m = mimeMessage({ from: 'khatma@mthani.app', to: 'owner@example.com', subject: 'Report #1', text: 'ختمة العائلة' });
  assert.match(m, /^From: Mathani <khatma@mthani.app>\r\nTo: owner@example.com\r\n/);
  assert.match(m, /Content-Type: text\/plain; charset=UTF-8/);
  const body = m.split('\r\n\r\n')[1].replace(/\r\n/g, '');
  assert.equal(Buffer.from(body, 'base64').toString('utf8'), 'ختمة العائلة');
});
