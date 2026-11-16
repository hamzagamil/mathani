// The checks on names and titles (specs/014 FR-060, SC-021): at least 50 refused names and 50
// refused titles in each of Arabic and English, and ordinary names that pass.
import test from 'node:test';
import assert from 'node:assert/strict';

import { check } from '../../functions/_lib/khatma-text.js';

const englishWords = ['fuck', 'shit', 'bitch', 'bastard', 'whore', 'slut', 'cunt', 'dick', 'pussy', 'nigger',
  'faggot', 'retard', 'wanker', 'twat', 'porn', 'rape', 'nazi', 'motherfucker'];
const arabicWords = ['كلب', 'حمار', 'خنزير', 'حقير', 'قذر', 'كافر', 'داعش', 'شرموطة', 'قحبة', 'عاهرة', 'منيوك',
  'متناك', 'ديوث', 'معرص', 'سكس', 'ابن الكلب', 'يلعن', 'زانية'];

/** Variants a person might type: case, marks, tatweel, letter forms, spacing, around a name. */
function englishVariants(w) {
  return [w, w.toUpperCase(), `${w[0].toUpperCase()}${w.slice(1)}`, `Ali ${w}`, `${w} 123`, `the ${w}`];
}
function arabicVariants(w) {
  const marked = [...w].map((c) => `${c}َ`).join(''); // a fatha on every letter
  const stretched = w.length > 2 ? `${w.slice(0, 2)}ـ${w.slice(2)}` : w; // a tatweel
  return [w, marked, stretched, `يا ${w}`, `${w} الأول`, w.replace(/ة$/u, 'ه')];
}

const links = ['https://x.com', 'www.site.org', 'me@mail.com', 'visit evil.com now', 'go to t.me/abc',
  'http://a.b', 'site.net', 'ftp://files', 'bit.ly/xyz', 'anyone@here'];

const refusedNames = (variants, words) => words.flatMap(variants).filter((t) => [...t].length <= 30);

test('at least 50 refused names and 50 titles in English', () => {
  const names = refusedNames(englishVariants, englishWords);
  const titles = englishWords.flatMap((w) => [`Khatma of the ${w}s`, `${w.toUpperCase()} group khatma`, `Our ${w} khatma`]);
  assert.ok(names.length >= 50 && titles.length >= 50);
  for (const t of names) assert.equal(check('name', t).problem?.kind, 'word', t);
  for (const t of titles) assert.equal(check('title', t).problem?.kind, 'word', t);
});

test('at least 50 refused names and 50 titles in Arabic', () => {
  const names = refusedNames(arabicVariants, arabicWords);
  const titles = arabicWords.flatMap((w) => [`ختمة ${w}`, `ختمة جماعية ${w}`, `${w} في رمضان`]);
  assert.ok(names.length >= 50 && titles.length >= 50);
  for (const t of names) assert.equal(check('name', t).problem?.kind, 'word', t);
  for (const t of titles) assert.equal(check('title', t).problem?.kind, 'word', t);
});

test('links and addresses are refused', () => {
  for (const t of links) assert.equal(check('title', t).problem?.kind, 'link', t);
});

test('empty, too long, and control or direction characters', () => {
  assert.equal(check('name', '   ').problem.kind, 'empty');
  assert.equal(check('name', 'a'.repeat(31)).problem.kind, 'long');
  assert.equal(check('name', 'a'.repeat(30)).text, 'a'.repeat(30));
  assert.equal(check('title', 'ب'.repeat(61)).problem.kind, 'long');
  assert.equal(check('name', 'Ali\nOmar').problem.kind, 'characters');
  assert.equal(check('name', 'Ali\u202eOmar').problem.kind, 'characters');
  assert.equal(check('name', 'Ali\u2066Omar').problem.kind, 'characters');
});

test('ordinary names and titles pass, stored as typed and trimmed', () => {
  const ordinary = ['Amina', 'Yusuf', 'Maryam', 'Omar Khan', 'Ashita', 'Dickens', 'Cassandra', 'Scunthorpe',
    'Hamza', 'Jo-Anne', "O'Brien", 'Assad', 'Basil', 'Classic', 'Kalb Street',
    'عائشة', 'محمد', 'فاطمة الزهراء', 'عبد الله', 'أم أحمد', 'كلثوم', 'حمزة', 'خديجة', 'سكينة', 'كسرى',
    'ختمة العائلة', 'ختمة رمضان ١٤٤٨', 'Family khatma before Friday', 'Khatma for grandma'];
  for (const t of ordinary) {
    const r = check(t.length > 30 ? 'title' : 'name', t);
    assert.equal(r.problem, undefined, `${t}: ${JSON.stringify(r.problem)}`);
  }
  assert.equal(check('name', '  Amina   Ali ').text, 'Amina Ali');
});
