// The Mutashabihat editor (specs/011 contracts/editor-ui.md). Plain DOM, no libraries; every
// change goes through /api/editor/* (contracts/editor-api.md).
'use strict';

const state = {
  me: null,
  groups: [],
  published: null,
  quran: null,
  search: '',
  unpublishedOnly: false,
};

// --- Helpers -------------------------------------------------------------------------------------

/** Builds an element: h('p', {class: 'x'}, 'text', child). Text is never parsed as HTML. */
function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === false || v === null || v === undefined) continue;
    if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
    else if (k === 'class') el.className = v;
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const c of children.flat()) {
    if (c === null || c === undefined || c === false) continue;
    el.append(c instanceof Node ? c : String(c));
  }
  return el;
}

const $ = (id) => document.getElementById(id);

/** Replaces [el]'s content. Unlike replaceChildren, empty slots (null, false) and nested lists
 *  are skipped and flattened rather than shown as text. */
function fill(el, ...children) {
  el.replaceChildren(...children.flat(Infinity).filter((c) => c !== null && c !== undefined && c !== false));
}
const arabicDigits = (n) => String(n).replace(/\d/g, (d) => '٠١٢٣٤٥٦٧٨٩'[d]);
const westernDigits = (s) => s.replace(/[٠-٩]/g, (d) => '0123456789'['٠١٢٣٤٥٦٧٨٩'.indexOf(d)]);
const when = (ms) => new Date(ms).toLocaleString('ar-EG', { dateStyle: 'medium', timeStyle: 'short' });
const plain = (s) => (s || '').replace(/[ؐ-ًؚ-ٰٟۖ-ۭـ]/g, '')
  .replace(/[أإآٱ]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه');

function say(message) {
  $('status').textContent = message || '';
}

async function api(method, path, body) {
  let response;
  try {
    response = await fetch(`/api/editor/${path}`, {
      method,
      credentials: 'same-origin',
      headers: body === undefined ? {} : { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    return { status: 0, body: { error: 'network' } };
  }
  const type = response.headers.get('content-type') || '';
  if (!type.includes('application/json')) {
    // Access answered instead of the editor: the sign-in has expired.
    return { status: 401, body: { error: 'signIn' } };
  }
  return { status: response.status, body: response.status === 204 ? null : await response.json() };
}

function failed(r) {
  if (r.status === 0) say('تعذّر الاتصال. تحقق من الإنترنت ثم أعد المحاولة.');
  else if (r.status === 401) say('انتهت الجلسة. أعد تحميل الصفحة لتسجيل الدخول.');
  else if (r.body?.error === 'notAnEditor') notAnEditor(r.body.email);
  else say('حدث خطأ غير متوقع. أعد المحاولة.');
}

// --- Quran text (quran.json) ----------------------------------------------------------------------

let quranLoad = null;
function loadQuran() {
  quranLoad ??= fetch('quran.json').then((r) => r.json()).then((q) => {
    state.quran = q;
    renderList();
    return q;
  }).catch(() => {
    quranLoad = null;
    return null;
  });
  return quranLoad;
}

const surahName = (n) => state.quran?.surahs[n - 1]?.name;
function refLabel(ref) {
  const [s, a] = ref.split(':').map(Number);
  const name = surahName(s);
  return name ? `${name} ${arabicDigits(a)}` : arabicDigits(ref);
}
const refsLabel = (ayat) => ayat.split(' ').filter(Boolean).map(refLabel).join(' · ');

/** «2:35», «٢:٣٥» or «البقرة 35» → "2:35", or null. */
function parseRef(text) {
  const t = westernDigits(text.trim());
  let m = /^(\d+)\s*[:：]\s*(\d+)$/.exec(t);
  if (m) return `${Number(m[1])}:${Number(m[2])}`;
  m = /^(.+?)\s+(\d+)$/.exec(t);
  if (m && state.quran) {
    const name = plain(m[1].replace(/^سورة\s+/, ''));
    const i = state.quran.surahs.findIndex((s) => plain(s.name) === name);
    if (i >= 0) return `${i + 1}:${Number(m[2])}`;
  }
  return null;
}

/** Why [ref] is not an ayah, or null. */
function refProblem(ref) {
  const [s, a] = ref.split(':').map(Number);
  const surah = state.quran?.surahs[s - 1];
  if (!surah) return state.quran ? `لا توجد سورة ${arabicDigits(s)}` : null;
  if (a < 1 || a > surah.count) {
    return `لا توجد آية ${arabicDigits(ref)} (سورة ${surah.name} ${arabicDigits(surah.count)} آية)`;
  }
  return null;
}

// --- Loading and the frame ------------------------------------------------------------------------

async function load() {
  const me = await api('GET', 'me');
  if (me.status !== 200) return failed(me);
  state.me = me.body;
  $('who').textContent = state.me.email;
  $('actions').hidden = false;
  $('editors-link').hidden = !state.me.isOwner;
  await refresh();
  loadQuran();
  window.addEventListener('hashchange', route);
  route();
}

async function refresh() {
  const r = await api('GET', 'groups');
  if (r.status !== 200) return failed(r);
  state.groups = r.body.groups;
  state.published = r.body.published;
  const pending = state.groups.filter((g) => g.status !== 'published').length;
  const link = $('publish-link');
  link.hidden = pending === 0;
  link.textContent = `نشر (${arabicDigits(pending)})`;
  renderList();
}

function notAnEditor(email) {
  $('actions').hidden = true;
  $('layout').classList.add('has-view');
  $('list-pane').replaceChildren();
  fill($('view'), 
    h('h1', {}, 'لا يمكنك التعديل'),
    h('p', {}, `هذا البريد (${email}) ليس من المحررين. اطلب من صاحب التطبيق إضافتك.`),
    h('a', { class: 'button', href: '/cdn-cgi/access/logout' }, 'خروج'),
  );
}

function route() {
  const hash = decodeURIComponent(location.hash.slice(1));
  say('');
  const view = $('view');
  $('layout').classList.toggle('has-view', hash !== '');
  if (!state.published && state.groups.length === 0) return firstUse();
  if (hash === 'new') return groupForm(null);
  if (hash.startsWith('group-')) return groupForm(hash.slice(6));
  if (hash === 'publish') return publishView();
  if (hash === 'history') return historyView();
  if (hash.startsWith('version-')) return versionView(Number(hash.slice(8)));
  if (hash === 'editors' && state.me.isOwner) return editorsView();
  fill(view, h('p', { class: 'muted' }, 'اختر مجموعة من القائمة، أو أنشئ مجموعة جديدة.'));
  renderList();
}

function back() {
  return h('a', { class: 'button quiet back', href: '#' }, '→ القائمة');
}

// --- The list -------------------------------------------------------------------------------------

const statusLabel = { added: 'جديدة', changed: 'معدلة', removed: 'محذوفة' };

function matches(g, q) {
  if (!q) return true;
  const ref = parseRef(q);
  if (ref) return g.ayat.split(' ').includes(ref);
  const needle = plain(q);
  return plain(g.note).includes(needle) || plain(g.explanation).includes(needle) ||
    plain(refsLabel(g.ayat)).includes(needle);
}

function renderList() {
  const pane = $('list-pane');
  const current = decodeURIComponent(location.hash.slice(1));
  if (!state.me || (!state.published && state.groups.length === 0)) return;
  const shown = state.groups
    .filter((g) => !state.unpublishedOnly || g.status !== 'published')
    .filter((g) => matches(g, state.search));
  const search = h('input', {
    type: 'search', id: 'search', placeholder: 'ابحث بموضع (٢:٣٥) أو بكلمة', value: state.search,
    'aria-label': 'بحث',
    oninput: (e) => {
      state.search = e.target.value;
      renderList();
      $('search').focus();
      $('search').setSelectionRange(state.search.length, state.search.length);
    },
  });
  fill(pane, 
    search,
    h('label', { class: 'filter' },
      h('input', {
        type: 'checkbox', id: 'unpublished-only', checked: state.unpublishedOnly,
        onchange: (e) => { state.unpublishedOnly = e.target.checked; renderList(); },
      }),
      'غير المنشور فقط'),
    h('p', { class: 'muted small' }, `${arabicDigits(shown.length)} من ${arabicDigits(state.groups.length)} مجموعة`),
    h('ul', { class: 'groups' }, shown.map((g) =>
      h('li', {},
        h('a', { href: `#group-${g.id}`, 'aria-current': current === `group-${g.id}` ? 'page' : false },
          h('span', { class: 'refs' }, refsLabel(g.ayat),
            statusLabel[g.status] ? [' ', h('span', { class: `chip ${g.status}` }, statusLabel[g.status])] : null),
          g.note ? h('span', { class: 'note' }, g.note) : null)))),
  );
}

// --- First use ------------------------------------------------------------------------------------

function firstUse() {
  $('layout').classList.add('has-view');
  const view = $('view');
  if (!state.me.isOwner) {
    fill(view, h('h1', {}, 'لم يُستورد المحتوى بعد'),
      h('p', {}, 'يستورد صاحب التطبيق المحتوى الحالي أولًا، ثم يمكنك التعديل.'));
    return;
  }
  const button = h('button', {
    class: 'accent',
    onclick: async () => {
      button.disabled = true;
      say('جارٍ الاستيراد…');
      const markdown = await fetch('/assets/assets/mutashabihat/mutashabihat.md').then((r) => r.text());
      const r = await api('POST', 'import', { markdown });
      if (r.status !== 201) {
        button.disabled = false;
        return r.body?.problems ? say(r.body.problems.map((p) => p.message).join(' — ')) : failed(r);
      }
      await refresh();
      say(`استُورد المحتوى: الإصدار ${arabicDigits(r.body.number)} وفيه ${arabicDigits(r.body.summary.added)} مجموعة.`);
      location.hash = '';
      route();
    },
  }, 'استيراد المحتوى الحالي');
  fill(view, 
    h('h1', {}, 'لا يوجد محتوى بعد'),
    h('p', {}, 'يبدأ المحرر من المحتوى الموجود في التطبيق الآن، ويصبح هو الإصدار الأول.'),
    button,
  );
}

// --- The group form -------------------------------------------------------------------------------

const draftKey = (id) => `mutashabihat-draft:${id || 'new'}`;
function readLocal(id) {
  try {
    return JSON.parse(localStorage.getItem(draftKey(id)) || 'null');
  } catch {
    return null;
  }
}
function writeLocal(id, value) {
  try {
    if (value) localStorage.setItem(draftKey(id), JSON.stringify(value));
    else localStorage.removeItem(draftKey(id));
  } catch { /* private window: no local copy */ }
}

async function groupForm(id) {
  await loadQuran();
  const saved = id ? state.groups.find((g) => g.id === id) : null;
  if (id && !saved) {
    fill($('view'), back(), h('p', {}, 'لم تعد هذه المجموعة موجودة.'));
    return;
  }
  renderList();
  const form = {
    ayat: saved ? saved.ayat.split(' ') : [],
    note: saved?.note ?? '',
    explanation: saved?.explanation ?? '',
  };
  const local = readLocal(id);
  const differs = (a, b) => a.ayat.join(' ') !== b.ayat.join(' ') || a.note !== b.note || a.explanation !== b.explanation;
  const view = $('view');
  let message = null;
  let problems = [];

  const remember = () => writeLocal(id, differs(form, original) ? form : null);
  const original = { ...form, ayat: [...form.ayat] };

  function render() {
    const changed = differs(form, original);
    const others = (ref) => state.groups.filter((g) => g.id !== id && g.ayat.split(' ').includes(ref));
    const addInput = h('input', { type: 'text', id: 'add-ayah', placeholder: '٢:٣٥', 'aria-label': 'موضع الآية' });
    const add = () => {
      const ref = parseRef(addInput.value);
      if (!ref) return say('اكتب الموضع بصيغة سورة:آية، مثل ٢:٣٥');
      const problem = refProblem(ref);
      if (problem) return say(problem);
      if (form.ayat.includes(ref)) return say('هذه الآية موجودة في المجموعة');
      form.ayat.push(ref);
      form.ayat.sort((x, y) => { const [a, b] = x.split(':').map(Number); const [c, d] = y.split(':').map(Number); return a - c || b - d; });
      say('');
      remember();
      render();
      $('add-ayah').focus();
    };
    addInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); add(); } });

    fill(view, 
      back(),
      h('h1', {}, saved ? refsLabel(saved.ayat) : 'مجموعة جديدة'),
      saved ? h('p', { class: 'muted small' },
        `آخر تعديل: ${saved.updatedBy} · ${when(saved.updatedAt)}`,
        statusLabel[saved.status] ? [' · ', h('span', { class: `chip ${saved.status}` }, statusLabel[saved.status])] : null) : null,
      local && differs(local, original) && !changed ? h('div', { class: 'banner' },
        h('p', {}, 'لديك تعديلات لم تُحفظ على هذا الجهاز.'),
        h('div', { class: 'row' },
          h('button', { onclick: () => { Object.assign(form, local); render(); } }, 'استعادة تعديلاتي'),
          h('button', { class: 'quiet', onclick: () => { writeLocal(id, null); render(); } }, 'تجاهلها'))) : null,
      message,
      problems.length ? h('ul', { class: 'problems' }, problems.map((p) => h('li', {}, p.message))) : null,
      saved?.deleted ? h('p', { class: 'error' }, 'ستُحذف هذه المجموعة في النشر القادم.') : null,

      h('h2', {}, 'الآيات'),
      h('ul', { class: 'ayat' }, form.ayat.map((ref) => h('li', { class: 'ayah' },
        h('header', {},
          h('span', { class: 'ref' }, refLabel(ref)),
          h('button', {
            class: 'quiet', 'aria-label': `إزالة ${refLabel(ref)}`,
            onclick: () => { form.ayat = form.ayat.filter((r) => r !== ref); remember(); render(); },
          }, 'إزالة')),
        state.quran?.ayat[ref] ? h('p', { class: 'text' }, state.quran.ayat[ref]) : null,
        others(ref).length ? h('p', { class: 'also' }, 'في مجموعات أخرى:',
          others(ref).map((g) => h('a', { href: `#group-${g.id}` }, refsLabel(g.ayat)))) : null))),
      h('div', { class: 'row' }, addInput, h('button', { onclick: add }, 'إضافة آية')),

      h('label', { for: 'note' }, 'ملاحظة (لا تظهر للقراء)'),
      h('input', {
        type: 'text', id: 'note', value: form.note,
        oninput: (e) => { form.note = e.target.value; remember(); updateSave(); },
      }),
      h('label', { for: 'explanation' }, 'الشرح'),
      h('p', { class: 'muted small' }, 'السطر الفارغ يبدأ فقرة جديدة، كما في التطبيق.'),
      h('textarea', {
        id: 'explanation', dir: 'rtl',
        oninput: (e) => { form.explanation = e.target.value; remember(); updateSave(); },
      }, form.explanation),

      h('div', { class: 'form-actions' },
        h('button', { class: 'accent', id: 'save', disabled: !changed, onclick: save }, 'حفظ'),
        saved && !saved.deleted ? h('button', { class: 'danger', onclick: () => setDeleted(true) }, 'حذف') : null,
        saved?.deleted ? h('button', { onclick: () => setDeleted(false) }, 'تراجع عن الحذف') : null,
        changed ? h('button', {
          class: 'quiet',
          onclick: () => { Object.assign(form, { ...original, ayat: [...original.ayat] }); writeLocal(id, null); render(); },
        }, 'إلغاء التعديلات') : null),
    );
  }

  function updateSave() {
    const button = $('save');
    if (button) button.disabled = !differs(form, original);
  }

  async function save() {
    const body = { ayat: form.ayat.join(' '), note: form.note, explanation: form.explanation };
    const r = saved
      ? await api('PUT', `groups/${saved.id}`, { ...body, revision: saved.revision })
      : await api('POST', 'groups', body);
    if (r.status === 200 || r.status === 201) {
      writeLocal(id, null);
      await refresh();
      say('حُفظ. ستصل التعديلات إلى القراء بعد النشر.');
      if (!saved) location.hash = `group-${r.body.id}`;
      else groupForm(saved.id);
      return;
    }
    if (r.status === 422) {
      problems = r.body.problems;
      message = null;
      return render();
    }
    if (r.status === 409) return conflict(r.body.group);
    failed(r);
  }

  function conflict(theirs) {
    problems = [];
    message = h('div', { class: 'banner' },
      h('p', {}, `عدّل ${theirs.updatedBy} هذه المجموعة بعد أن فتحتها.`),
      h('div', { class: 'row' },
        h('button', { onclick: async () => { writeLocal(id, null); await refresh(); groupForm(id); } }, 'تحميل نسختهم'),
        h('button', { class: 'quiet', onclick: () => { message = null; render(); } }, 'الإبقاء على نسختي في الصفحة')));
    render();
  }

  async function setDeleted(deleted) {
    const r = await api(deleted ? 'DELETE' : 'POST', deleted ? `groups/${saved.id}` : `groups/${saved.id}/undelete`,
      { revision: saved.revision });
    if (r.status === 409) return conflict(r.body.group);
    if (r.status !== 200) return failed(r);
    await refresh();
    if (r.body.status === 'discarded') {
      say('حُذفت المجموعة.');
      location.hash = '';
    } else {
      say(deleted ? 'ستُحذف المجموعة في النشر القادم.' : 'أُعيدت المجموعة.');
      groupForm(saved.id);
    }
  }

  render();
}

// --- Publish --------------------------------------------------------------------------------------

async function publishView(note) {
  await loadQuran();
  const r = await api('GET', 'publish');
  if (r.status !== 200) return failed(r);
  const { changes, problems } = r.body;
  const view = $('view');
  const section = (status, title) => {
    const rows = changes.filter((c) => c.status === status);
    if (!rows.length) return null;
    return [h('h2', {}, `${title} (${arabicDigits(rows.length)})`),
      h('ul', { class: 'changes' }, rows.map((c) => h('li', {},
        h('a', { href: `#group-${c.id}` }, refsLabel(c.ayat)),
        h('div', { class: 'muted small' }, `${c.updatedBy} · ${when(c.updatedAt)}`))))];
  };
  const button = h('button', {
    class: 'accent', disabled: changes.length === 0 || problems.length > 0,
    onclick: async () => {
      button.disabled = true;
      const p = await api('POST', 'publish', { expect: changes.map((c) => c.id) });
      if (p.status === 201) {
        await refresh();
        const s = p.body.summary;
        say(`نُشر الإصدار ${arabicDigits(p.body.number)}: أضيفت ${arabicDigits(s.added)} وعُدّلت ${arabicDigits(s.changed)} وحذفت ${arabicDigits(s.removed)}.`);
        return publishView();
      }
      if (p.body?.error === 'draftChanged') return publishView('حفظ أحدٌ تعديلًا أثناء ذلك، فتحدّثت القائمة. راجعها ثم انشر.');
      if (p.status === 422) return publishView();
      failed(p);
    },
  }, 'نشر الآن');
  fill(view, 
    back(),
    h('h1', {}, 'النشر'),
    state.published ? h('p', { class: 'muted' },
      `آخر إصدار منشور: ${arabicDigits(state.published.number)} · ${state.published.publishedBy} · ${when(state.published.publishedAt)}`) : null,
    note ? h('div', { class: 'banner' }, note) : null,
    changes.length === 0 ? h('p', {}, 'لا توجد تعديلات تنتظر النشر.') : null,
    section('added', 'ستُضاف'),
    section('changed', 'ستُعدّل'),
    section('removed', 'ستُحذف'),
    problems.length ? [h('p', { class: 'error' }, 'لا يمكن النشر حتى تُصلح هذه المجموعات:'),
      h('ul', { class: 'problems' }, problems.map((p) => h('li', {}, h('a', { href: `#group-${p.id}` }, p.message))))] : null,
    h('div', { class: 'row' }, button),
    h('p', { class: 'muted small' }, 'تصل التعديلات إلى التطبيقات عند فتحها خلال ساعات، دون تحديث من المتجر.'),
  );
}

// --- History --------------------------------------------------------------------------------------

async function historyView() {
  const r = await api('GET', 'versions');
  if (r.status !== 200) return failed(r);
  fill($('view'), 
    back(),
    h('h1', {}, 'السجل'),
    h('ul', { class: 'versions' }, r.body.versions.map((v) => h('li', {},
      h('a', { href: `#version-${v.number}` },
        h('strong', {}, `الإصدار ${arabicDigits(v.number)}`),
        h('div', { class: 'muted small' }, `${when(v.publishedAt)} · ${v.publishedBy}`),
        h('div', { class: 'small' },
          `أضيفت ${arabicDigits(v.summary.added)} · عُدّلت ${arabicDigits(v.summary.changed)} · حذفت ${arabicDigits(v.summary.removed)}`,
          v.restoredFrom ? ` · مستعاد من الإصدار ${arabicDigits(v.restoredFrom)}` : ''))))),
  );
}

async function versionView(number) {
  await loadQuran();
  const r = await api('GET', `versions/${number}`);
  if (r.status !== 200) return failed(r);
  const v = r.body;
  const pending = state.groups.filter((g) => g.status !== 'published').length;
  const latest = state.published?.number === v.number;
  const confirmBox = h('div', { class: 'banner', hidden: true },
    h('p', {}, pending
      ? `لديكم ${arabicDigits(pending)} تعديلات غير منشورة ستضيع إذا استعدت هذا الإصدار.`
      : `سيُنشر محتوى الإصدار ${arabicDigits(v.number)} من جديد كإصدار جديد، ويصل إلى التطبيقات كأي تحديث.`),
    h('div', { class: 'row' },
      h('button', {
        class: 'accent',
        onclick: async () => {
          const res = await api('POST', `versions/${v.number}/restore`, { discardDraft: pending > 0 });
          if (res.status !== 201) return failed(res);
          await refresh();
          say(`نُشر الإصدار ${arabicDigits(res.body.number)}، مستعادًا من الإصدار ${arabicDigits(v.number)}.`);
          location.hash = 'history';
        },
      }, 'نعم، استعده'),
      h('button', { class: 'quiet', onclick: () => { confirmBox.hidden = true; } }, 'إلغاء')));
  fill($('view'), 
    h('a', { class: 'button quiet', href: '#history' }, '→ السجل'),
    h('h1', {}, `الإصدار ${arabicDigits(v.number)}`),
    h('p', { class: 'muted' }, `${when(v.publishedAt)} · ${v.publishedBy}`),
    latest ? h('p', {}, 'هذا هو الإصدار المنشور الآن.') : h('button', {
      onclick: () => { confirmBox.hidden = false; },
    }, 'استعادة هذا الإصدار'),
    confirmBox,
    h('ul', { class: 'ayat read-only' }, v.groups.map((g) => h('li', { class: 'ayah' },
      h('header', {}, h('span', { class: 'ref' }, refsLabel(g.ayat))),
      g.note ? h('p', { class: 'muted small' }, g.note) : null,
      h('p', { class: 'explanation' }, g.explanation)))),
  );
}

// --- Editors (owner) -------------------------------------------------------------------------------

async function editorsView() {
  const r = await api('GET', 'editors');
  if (r.status !== 200) return failed(r);
  const input = h('input', { type: 'email', id: 'editor-email', placeholder: 'name@example.com', dir: 'ltr', 'aria-label': 'البريد' });
  const add = async () => {
    const res = await api('POST', 'editors', { email: input.value });
    if (res.status === 201) {
      say(`أضيف ${res.body.email}.`);
      return editorsView();
    }
    if (res.body?.error === 'exists') return say('هذا البريد من المحررين بالفعل.');
    if (res.body?.error === 'email') return say('اكتب بريدًا صحيحًا غير بريدك.');
    failed(res);
  };
  fill($('view'), 
    back(),
    h('h1', {}, 'المحررون'),
    h('p', {}, 'يدخل المحرر بالبريد نفسه عبر رمز يصله بالبريد، ويعدّل وينشر مثلك. أنت وحدك تضيف المحررين وتزيلهم.'),
    h('ul', { class: 'changes' }, r.body.editors.length === 0 ? h('li', { class: 'muted' }, 'لا يوجد محررون بعد.') : null,
      r.body.editors.map((e) => h('li', { class: 'row' },
        h('span', { dir: 'ltr' }, e.email),
        h('span', { class: 'muted small' }, when(e.addedAt)),
        h('button', {
          class: 'danger',
          onclick: async () => {
            const res = await api('DELETE', `editors/${encodeURIComponent(e.email)}`);
            if (res.status !== 204) return failed(res);
            say(`أُزيل ${e.email}.`);
            editorsView();
          },
        }, 'إزالة')))),
    h('label', { for: 'editor-email' }, 'إضافة محرر'),
    h('div', { class: 'row' }, input, h('button', { class: 'accent', onclick: add }, 'إضافة')),
  );
}

load();
