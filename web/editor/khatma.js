// The owner's page for group khatma reports (specs/014 contracts/group-api.md › Owner endpoints):
// open reports first, each with dismiss, remove the name, or remove the khatma, and "block the
// poster". Plain JavaScript, like the Mutashabihat editor.
'use strict';

const $ = (id) => document.getElementById(id);
const when = (ms) => new Date(ms).toLocaleString('ar-EG', { dateStyle: 'medium', timeStyle: 'short' });

function say(message) {
  $('status').textContent = message || '';
}

async function api(method, path, body) {
  let response;
  try {
    response = await fetch(`/api/editor/khatma/${path}`, {
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
  else if (r.status === 401) say('انتهت الجلسة. أعد تحميل الصفحة لتسجيل الدخول.');
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

const actionText = { none: 'رُفض البلاغ', name: 'حُذف الاسم', khatma: 'حُذفت الختمة' };

function card(r) {
  const block = el('input', { type: 'checkbox', id: `block-${r.id}` });
  const resolve = async (action) => {
    say('جارٍ التنفيذ…');
    const result = await api('POST', `reports/${r.id}/resolve`, { action, block: block.checked });
    if (result.status !== 200) return failed(result);
    say('تم.');
    load();
  };
  const open = r.resolvedAt == null;
  return el('article', { class: 'card' },
    el('h2', {}, `بلاغ #${r.id} · ${r.participant ? 'اسم' : 'ختمة كاملة'}`),
    el('p', {}, el('bdi', {}, r.title)),
    r.participant ? el('p', {}, 'الاسم: ', el('bdi', {}, r.name || '—')) : null,
    el('p', { class: 'muted' }, `${when(r.createdAt)} · ${r.exists ? 'الختمة موجودة' : 'الختمة لم تعد موجودة'} · ${r.code}`),
    open
      ? el('div', { class: 'actions' },
        el('label', { for: block.id }, block, ' احظر من كتب النص'),
        el('button', { class: 'button', type: 'button', onclick: () => resolve('none') }, 'ارفض البلاغ'),
        r.participant
          ? el('button', { class: 'button', type: 'button', onclick: () => resolve('name') }, 'احذف الاسم')
          : null,
        r.exists
          ? el('button', { class: 'button accent', type: 'button', onclick: () => resolve('khatma') }, 'احذف الختمة')
          : null)
      : el('p', { class: 'muted' },
        `${actionText[r.action] ?? r.action}${r.blocked ? ' · حُظر الكاتب' : ''} · ${when(r.resolvedAt)}`));
}

async function load() {
  const r = await api('GET', 'reports');
  if (r.status !== 200) return failed(r);
  const list = $('reports');
  list.replaceChildren();
  const open = r.body.reports.filter((x) => x.resolvedAt == null).length;
  list.append(el('p', {}, open ? `بلاغات مفتوحة: ${open}` : 'لا بلاغات مفتوحة.'));
  for (const report of r.body.reports) list.append(card(report));
}

$('refresh').addEventListener('click', load);
load();
