// The owner's page for announcements to readers (specs/018 contracts/announcements-api.md):
// write, preview, confirm and send; the history with reuse. Plain JavaScript, like khatma.js.
'use strict';

const $ = (id) => document.getElementById(id);
const when = (ms) => new Date(ms).toLocaleString('ar-EG', { dateStyle: 'medium', timeStyle: 'short' });
const count = (text) => [...text].length;

const audienceText = { all: 'جميع القراء', lang_ar: 'قراء العربية', lang_en: 'قراء الإنجليزية' };
const ttlText = { 3600: 'ساعة', 86400: 'يوم', 604800: 'أسبوع', 2419200: '٤ أسابيع' };
const statusText = {
  sent: 'أُرسل',
  notConfigured: 'الإرسال غير مُعدّ',
  rejected: 'رفضت خدمة الإشعارات الرسالة',
  busy: 'الخدمة مشغولة، أعد المحاولة لاحقًا',
  unavailable: 'الخدمة غير متاحة الآن',
};
const LINK_HOSTS = ['mthani.app', 'www.mthani.app', 'get.mthani.app'];

let configured = false;
let requestId = null;

function say(message) {
  $('status').textContent = message || '';
}

async function api(method, body) {
  let response;
  try {
    response = await fetch('/api/editor/announcements', {
      method,
      credentials: 'same-origin',
      headers: body === undefined ? {} : { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    return { status: 0, body: { error: 'network' } };
  }
  if (!(response.headers.get('content-type') || '').includes('application/json')) {
    return { status: 401, body: { error: 'signIn' } };
  }
  return { status: response.status, body: await response.json() };
}

function failed(r) {
  if (r.status === 0) say('تعذّر الاتصال. تحقق من الإنترنت ثم أعد المحاولة.');
  else if (r.status === 401) say('انتهت الجلسة. سجّل الدخول في نافذة جديدة ثم أعد المحاولة؛ رسالتك محفوظة هنا.');
  else if (r.status === 403) say('هذه الصفحة لمالك التطبيق وحده.');
  else say('حدث خطأ غير متوقع. أعد المحاولة.');
}

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') node.className = v;
    else if (k.startsWith('on')) node.addEventListener(k.slice(2), v);
    else node.setAttribute(k, v);
  }
  for (const c of children) if (c != null) node.append(c);
  return node;
}

/** Direction from the first strong character (research R8). */
function direction(text) {
  for (const ch of text) {
    if (/[֐-ࣿיִ-﷿ﹰ-﻿]/.test(ch)) return 'rtl';
    if (/\p{L}/u.test(ch)) return 'ltr';
  }
  return 'rtl';
}

/** The link if it is an https Mathani link, '' when empty, null when not allowed. */
function checkLink(value) {
  const text = value.trim();
  if (!text) return '';
  try {
    const url = new URL(text);
    if (url.protocol !== 'https:' || !LINK_HOSTS.includes(url.hostname) || url.username || url.password) return null;
    return text.length <= 500 ? text : null;
  } catch {
    return null;
  }
}

function values() {
  return {
    title: $('title').value.trim(),
    body: $('body').value.trim(),
    link: checkLink($('link').value),
    audience: document.querySelector('input[name="audience"]:checked').value,
    ttl: Number($('ttl').value),
  };
}

function valid(v) {
  return count(v.title) >= 1 && count(v.title) <= 65 && count(v.body) >= 1 && count(v.body) <= 240 && v.link !== null;
}

function update() {
  const v = values();
  $('title-count').textContent = `${count(v.title)} / 65`;
  $('body-count').textContent = `${count(v.body)} / 240`;
  $('title-count').classList.toggle('over', count(v.title) > 65);
  $('body-count').classList.toggle('over', count(v.body) > 240);
  $('link-error').hidden = v.link !== null;
  for (const [id, text] of [['preview-title', v.title], ['preview-body', v.body]]) {
    $(id).textContent = text;
    $(id).dir = direction(text);
  }
  $('preview-link').textContent = v.link || '';
  $('send').disabled = !configured || !valid(v);
  hideConfirm();
}

function hideConfirm() {
  $('confirm').hidden = true;
  requestId = null;
}

function showConfirm() {
  const v = values();
  if (!configured || !valid(v)) return;
  // One id per confirmation: a repeated request is never sent twice (research R4).
  requestId = crypto.randomUUID();
  $('confirm-text').textContent = `سيُرسل الإشعار إلى: ${audienceText[v.audience]}. لا يمكن سحبه بعد الإرسال.`;
  $('confirm').hidden = false;
  $('confirm-send').disabled = false;
  $('confirm-send').focus();
}

async function confirmSend() {
  if (!requestId) return;
  const v = values();
  $('confirm-send').disabled = true;
  say('جارٍ الإرسال…');
  const r = await api('POST', {
    requestId, audience: v.audience, title: v.title, body: v.body, link: v.link || null, ttl: v.ttl,
  });
  if (r.status === 429) {
    say(`بلغت حد ١٠ إشعارات في الساعة. يمكنك الإرسال مجددًا في ${when(r.body.retryAt)}.`);
    hideConfirm();
  } else if (r.status === 422) {
    say('في الرسالة حقل غير صالح. راجعها ثم أعد المحاولة.');
    hideConfirm();
  } else if (r.status !== 200 && r.status !== 201) {
    // The same requestId is kept, so trying again cannot send twice.
    failed(r);
    $('confirm-send').disabled = false;
    return;
  } else if (r.body.status === 'sent') {
    say('تم الإرسال.');
    $('form').reset();
    update();
  } else {
    say(`لم يُرسل: ${statusText[r.body.status] ?? r.body.status}.`);
    hideConfirm();
  }
  load();
}

function reuse(a) {
  $('title').value = a.title;
  $('body').value = a.body;
  $('link').value = a.link || '';
  document.querySelector(`input[name="audience"][value="${a.audience}"]`).checked = true;
  $('ttl').value = String(a.ttl);
  update();
  say('نُسخت الرسالة إلى النموذج. لم يُرسل شيء.');
  $('form').scrollIntoView({ behavior: 'smooth' });
  $('title').focus({ preventScroll: true });
}

function result(a) {
  if (a.status === 'sending') {
    return Date.now() - a.createdAt > 60_000
      ? el('span', { class: 'badge warn' }, 'غير معروف، تحقّق قبل إعادة الإرسال')
      : el('span', { class: 'badge' }, 'جارٍ الإرسال');
  }
  if (a.status === 'sent') return el('span', { class: 'badge ok' }, statusText.sent);
  return el('span', { class: 'badge warn' }, statusText[a.status] ?? a.status);
}

function card(a) {
  return el('article', { class: 'card' },
    el('p', { class: 'muted' }, `${when(a.createdAt)} · ${audienceText[a.audience] ?? a.audience} · `
      + `التوصيل: ${ttlText[a.ttl] ?? `${a.ttl} ث`}`),
    el('p', { class: 'card-title', dir: direction(a.title) }, a.title),
    el('p', { dir: direction(a.body) }, a.body),
    a.link ? el('p', { dir: 'ltr', class: 'muted' }, a.link) : null,
    el('p', {}, result(a)),
    a.detail ? el('p', { class: 'muted', dir: 'ltr' }, a.detail) : null,
    el('p', { class: 'muted' }, 'أرسله ', el('bdi', {}, a.sentBy)),
    el('button', { class: 'button', type: 'button', onclick: () => reuse(a) }, 'استخدام مرة أخرى'));
}

async function load() {
  const r = await api('GET');
  if (r.status !== 200) return failed(r);
  configured = r.body.configured;
  if (!configured) say('الإرسال غير مُعدّ بعد. أضف مفتاح خدمة الإشعارات (انظر docs/release.md).');
  else if (r.body.limit.retryAt) say(`بلغت حد ١٠ إشعارات في الساعة. يمكنك الإرسال مجددًا في ${when(r.body.limit.retryAt)}.`);
  const list = $('history-list');
  list.replaceChildren();
  if (!r.body.announcements.length) list.append(el('p', { class: 'muted' }, 'لم يُرسل شيء بعد.'));
  for (const a of r.body.announcements) list.append(card(a));
  $('send').disabled = !configured || !valid(values());
}

for (const id of ['title', 'body', 'link', 'ttl']) $(id).addEventListener('input', update);
for (const radio of document.querySelectorAll('input[name="audience"]')) radio.addEventListener('change', update);
$('form').addEventListener('submit', (e) => {
  e.preventDefault();
  showConfirm();
});
$('confirm-send').addEventListener('click', confirmSend);
$('confirm-cancel').addEventListener('click', hideConfirm);
update();
load();
