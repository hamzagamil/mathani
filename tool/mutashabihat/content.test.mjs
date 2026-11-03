// The server's content rules (specs/011 T008): the same checks as the Dart parser, and rendering.
import test from 'node:test';
import assert from 'node:assert/strict';
import { checkGroup, parse, render, sha256Hex } from '../../functions/_lib/mutashabihat-content.js';
import { fixtureMarkdown, shippedMarkdown } from './support.mjs';

const kinds = (problems) => problems.map((p) => p.kind);

test('references: Western and Arabic-Indic digits, commas, Mushaf order, the note', () => {
  const { groups, problems } = parse('# t\n\n## ٧:١٩، 2:35 ,20:117 | آدم\nشرح');
  assert.deepEqual(problems, []);
  assert.deepEqual(groups[0].ayat, [[2, 35], [7, 19], [20, 117]]);
  assert.equal(groups[0].note, 'آدم');
  assert.equal(groups[0].line, 3);
});

test('each check, with the Dart messages', () => {
  const { groups, problems } = parse('## 2:35 7;19\nشرح\n\n## 2:35 2:300 115:1\nشرح\n\n## 3:7\nشرح\n\n## 3:7 39:23\n\n## 2:35 2:35 7:19\nشرح');
  assert.deepEqual(kinds(problems), [
    'badReference', 'noSuchAyah', 'noSuchAyah', 'tooFewAyat', 'emptyExplanation', 'duplicateAyah',
  ]);
  assert.equal(problems[0].message, 'line 1 (## 2:35 7;19): "7;19" is not a reference (use surah:ayah)');
  assert.equal(problems[1].detail, '2:300 is not an ayah (surah 2 has 286)');
  assert.equal(problems[2].detail, '115:1: there is no surah 115');
  assert.equal(problems[5].isError, false);
  assert.equal(groups.length, 1);
  assert.deepEqual(groups[0].ayat, [[2, 35], [7, 19]]);
});

test('paragraphs and the version line', () => {
  const { version, groups } = parse('<!-- version: 7 -->\n## 2:35 7:19\n\n\nأول\nثان\n\n\n\n### فقرة\n');
  assert.equal(version, 7);
  assert.equal(groups[0].explanation, 'أول\nثان\n\n### فقرة');
  assert.equal(parse('## 2:35 7:19\n<!-- version: 9 -->\nشرح').version, 0, 'only before the first group');
});

test('render then parse gives the same groups and version', async () => {
  const source = parse(shippedMarkdown());
  assert.deepEqual(source.problems.filter((p) => p.isError), []);
  const groups = source.groups.map((g) => ({
    ayat: g.ayat.map(([s, a]) => `${s}:${a}`).join(' '), note: g.note, explanation: g.explanation,
  }));
  const text = render({ version: 12, groups });
  const again = parse(text);
  assert.equal(again.version, 12);
  assert.equal(again.problems.length, 0);
  assert.deepEqual(again.groups.map((g) => [g.ayat, g.note, g.explanation]),
    source.groups.map((g) => [g.ayat, g.note, g.explanation]));
  assert.match(await sha256Hex(text), /^[0-9a-f]{64}$/);
});

test('the shipped file and the quickstart fixture', () => {
  assert.equal(parse(shippedMarkdown()).groups.length, 72);
  const fixture = parse(fixtureMarkdown());
  assert.equal(fixture.groups.length, 5);
  assert.deepEqual(fixture.problems, []);
});

test('checkGroup: normalises, and refuses notes and headings that would break the file', () => {
  const ok = checkGroup({ ayat: '٧:١٩, 2:35', note: ' آدم ', explanation: '\n\nشرح\n\n\nثان\n' });
  assert.equal(ok.ok, true);
  assert.equal(ok.ayat, '2:35 7:19');
  assert.equal(ok.note, 'آدم');
  assert.equal(ok.explanation, 'شرح\n\nثان');
  assert.deepEqual(kinds(checkGroup({ ayat: '2:35 7:19', note: 'a\nb', explanation: 'x' }).problems), ['note']);
  assert.deepEqual(kinds(checkGroup({ ayat: '2:35 7:19', note: 'a|b', explanation: 'x' }).problems), ['note']);
  assert.deepEqual(kinds(checkGroup({ ayat: '2:35 7:19', explanation: 'x\n## 3:1 3:2' }).problems), ['explanation']);
  const bad = checkGroup({ ayat: '2:300', explanation: '' });
  assert.equal(bad.ok, false);
  assert.deepEqual(kinds(bad.problems), ['noSuchAyah', 'emptyExplanation']);
});
