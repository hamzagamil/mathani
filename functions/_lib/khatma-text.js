// Checks on group khatma names and titles (specs/014 contracts/group-api.md › Checks on names and
// titles, FR-060), in order; the first failure is reported as a Problem.
import { anywhere, wholeWords } from './khatma-words.js';

export const limits = { name: 30, title: 60 };

/** Trims and collapses runs of spaces. */
export const tidy = (text) => String(text ?? '').trim().replace(/\s+/g, ' ');

// Line breaks and other controls, and the direction overrides and isolates.
const controls = /[\u0000-\u001f\u007f-\u009f\u200e\u200f\u202a-\u202e\u2066-\u2069\u061c]/u;
const links = /:\/\/|www\.|@|\p{L}\.\p{L}{2,}/iu;

/** The text as the word lists are written: no Arabic marks or tatweel, one form of alef, hamza,
 * yaa and taa marbuta, Latin letters lower-cased. */
export function normalise(text) {
  return text
    .normalize('NFKC')
    .replace(/[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed\u0640]/gu, '')
    .replace(/[أإآٱ]/gu, 'ا')
    .replace(/[ؤئ]/gu, 'ء')
    .replace(/ى/gu, 'ي')
    .replace(/ة/gu, 'ه')
    .toLowerCase();
}

const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const wholePattern = new RegExp(
  // With an English plural ending too ("bastards").
  `(?:^|[^\\p{L}\\p{N}])(?:${wholeWords.map(escape).join('|')})(?:e?s)?(?:$|[^\\p{L}\\p{N}])`,
  'u',
);

/** The checked text, or a Problem `{field, kind}`. The stored text is the trimmed text as typed. */
export function check(field, raw) {
  const text = tidy(raw);
  if (!text) return { problem: { field, kind: 'empty' } };
  if ([...text].length > limits[field]) return { problem: { field, kind: 'long' } };
  if (controls.test(String(raw ?? '').trim())) return { problem: { field, kind: 'characters' } };
  if (links.test(text)) return { problem: { field, kind: 'link' } };
  const plain = normalise(text);
  // Letters spread out with spaces or dots are read together too.
  const squeezed = plain.replace(/[\s._\-*]+/gu, '');
  if (wholePattern.test(plain) || anywhere.some((w) => plain.includes(w) || squeezed.includes(w.replace(/\s+/g, '')))) {
    return { problem: { field, kind: 'word' } };
  }
  return { text };
}
