// The Mutashabihat content rules on the server (specs/011 research R3): a port of
// lib/features/mutashabihat/mutashabihat_content.dart with the same checks and messages, plus
// rendering. test/unit/mutashabihat_parsers_agree_test.dart keeps the two in step.

/** Ayat in each surah (Hafs), index = surah - 1. */
export const ayahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
];

/** Content format the apps understand (contracts/content-api.md). */
export const contentFormat = 1;

const reference = /^(\d+):(\d+)$/;
const separators = /[\s,،]+/;
const blankLines = /\n[ \t]*(\n[ \t]*)+/g;
const versionLine = /^<!-- version: (\d+) -->$/;

const westernDigits = (s) =>
  s.replace(/[٠-٩۰-۹]/g, (c) => {
    const code = c.charCodeAt(0);
    return String.fromCharCode(0x30 + (code >= 0x06f0 ? code - 0x06f0 : code - 0x0660));
  });

const compare = ([s1, a1], [s2, a2]) => (s1 !== s2 ? s1 - s2 : a1 - a2);
export const formatAyat = (ayat) => ayat.map(([s, a]) => `${s}:${a}`).join(' ');

/** Normalises an explanation as the Dart parser does: trimmed, runs of blank lines → one. */
export const normaliseExplanation = (text) => text.replace(/\r\n/g, '\n').trim().replace(blankLines, '\n\n');

/**
 * Checks one group's parts. [line] and [heading] name it in messages. Returns the ayat in Mushaf
 * order and the problems: errors, plus a warning for a duplicate (kept once).
 */
function checkParts(refs, explanation, line, heading) {
  const problems = [];
  const errors = [];
  const seen = new Set();
  const ayat = [];
  const problem = (kind, detail, error = true) => {
    const p = { line, kind, heading, detail, message: `line ${line} (${heading}): ${detail}`, isError: error };
    (error ? errors : problems).push(p);
  };
  for (const token of westernDigits(refs).split(separators)) {
    if (!token) continue;
    const m = reference.exec(token);
    if (!m) {
      problem('badReference', `"${token}" is not a reference (use surah:ayah)`);
      continue;
    }
    const surah = Number(m[1]);
    const ayah = Number(m[2]);
    if (surah < 1 || surah > ayahCounts.length) {
      problem('noSuchAyah', `${token}: there is no surah ${surah}`);
    } else if (ayah < 1 || ayah > ayahCounts[surah - 1]) {
      problem('noSuchAyah', `${token} is not an ayah (surah ${surah} has ${ayahCounts[surah - 1]})`);
    } else if (seen.has(`${surah}:${ayah}`)) {
      problem('duplicateAyah', `${token} is listed twice; kept once`, false);
    } else {
      seen.add(`${surah}:${ayah}`);
      ayat.push([surah, ayah]);
    }
  }
  if (errors.length === 0 && ayat.length < 2) {
    problem('tooFewAyat', 'a group needs at least two different ayat');
  }
  const text = normaliseExplanation(explanation);
  if (!text) problem('emptyExplanation', 'the explanation is empty');
  return { ayat: ayat.sort(compare), explanation: text, problems: [...problems, ...errors], errors };
}

/**
 * Parses a content file (specs/010 contracts/content-file.md). Groups with an error are left out;
 * `version` comes from a «<!-- version: N -->» line before the first group (0 without one).
 */
export function parse(text) {
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  const groups = [];
  const problems = [];
  let version = 0;
  let heading = null;
  let headingLine = 0;
  let body = [];

  const addGroup = () => {
    const pipe = heading.indexOf('|');
    const refs = (pipe < 0 ? heading.substring(3) : heading.substring(3, pipe)).trim();
    const note = pipe < 0 ? '' : heading.substring(pipe + 1).trim();
    const checked = checkParts(refs, body.join('\n'), headingLine, heading);
    problems.push(...checked.problems);
    if (checked.errors.length === 0) {
      groups.push({ ayat: checked.ayat, note, explanation: checked.explanation, line: headingLine });
    }
  };

  lines.forEach((raw, i) => {
    const l = raw.trimEnd();
    if (l.startsWith('## ')) {
      if (heading !== null) addGroup();
      heading = l;
      headingLine = i + 1;
      body = [];
    } else if (heading !== null) {
      body.push(l);
    } else {
      const m = versionLine.exec(l);
      if (m) version = Number(m[1]);
    }
  });
  if (heading !== null) addGroup();
  return { version, groups, problems };
}

/**
 * Checks a group from the editor: `ayat` as typed ("2:35, ٧:١٩"), the note and the explanation.
 * Returns the normalised fields and the problems (errors only block a save).
 */
export function checkGroup({ ayat = '', note = '', explanation = '' }) {
  const heading = `## ${ayat}`.trim();
  const checked = checkParts(String(ayat), String(explanation), 0, heading);
  const problems = checked.problems.map((p) => ({ kind: p.kind, message: p.detail, isError: p.isError }));
  const cleanNote = String(note).trim();
  if (/[\r\n]/.test(cleanNote)) {
    problems.push({ kind: 'note', message: 'the note must be one line', isError: true });
  }
  if (cleanNote.includes('|')) {
    problems.push({ kind: 'note', message: 'the note cannot contain "|"', isError: true });
  }
  if (checked.explanation.split('\n').some((l) => l.startsWith('## '))) {
    problems.push({ kind: 'explanation', message: 'a line of the explanation cannot start with "## "', isError: true });
  }
  return {
    ayat: formatAyat(checked.ayat),
    note: cleanNote,
    explanation: checked.explanation,
    problems,
    ok: problems.every((p) => !p.isError),
  };
}

const preamble = `# متشابهات القرآن — ملف المحتوى

يُنتج هذا الملف من محرر المتشابهات (https://get.mthani.app/editor/) ولا يُعدَّل يدويًا.
يُنسخ أحدث إصدار منشور إلى التطبيق قبل كل إصدار: dart run tool/pull_mutashabihat.dart

دليل الصيغة (هذا الجزء قبل أول مجموعة لا يظهر في التطبيق):

- كل مجموعة تبدأ بسطر أوله «## » ثم مواضع الآيات بصيغة سورة:آية، مثل: ## 2:35 7:19
- ما بعد العلامة | في سطر المجموعة ملاحظة للمحررين ولا تظهر في التطبيق.
- كل ما بعد سطر المجموعة حتى المجموعة التالية هو الشرح. السطر الفارغ يبدأ فقرة جديدة.
`;

/** Renders a published version: the version line, the guide, then the groups in order. */
export function render({ version, groups }) {
  const body = groups
    .map((g) => `## ${g.ayat}${g.note ? ` | ${g.note}` : ''}\n${g.explanation}`)
    .join('\n\n');
  return `<!-- version: ${version} -->\n${preamble}\n${body}\n`;
}

/** Hex SHA-256 of [text] as UTF-8. */
export async function sha256Hex(text) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}
