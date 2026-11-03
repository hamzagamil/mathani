# Contract: The Mutashabihat Content File

**File**: `assets/mutashabihat/mutashabihat.md` (UTF-8). The owner edits it. The app ships it as
it is. **Checked by**: `dart run tool/check_mutashabihat.dart` (see [research R2](../research.md#r2-the-check-before-a-release)).

## Format

```markdown
# متشابهات القرآن — ملف المحتوى

Anything before the first `##` is notes for the owner and is ignored, for example this guide.

## 2:35 7:19 | آدم في الجنة
في سورة البقرة: «وَكُلَا مِنْهَا رَغَدًا حَيْثُ شِئْتُمَا»، وفي الأعراف: «فَكُلَا مِنْ حَيْثُ شِئْتُمَا».

زيادة «رَغَدًا» في البقرة ...

## 2:58 7:161
...
```

### Group heading

`## <references> [| <note>]`, on one line starting with `##` and a space.

- **References**: two or more `surah:ayah` pairs separated by spaces, commas (`,` or `،`) or both.
  Digits can be Western (`2:35`) or Arabic-Indic (`٢:٣٥`).
- **Note**: everything after the first `|` is for the owner and is not shown in the app.
- **Order**: references can be in any order. The app shows them in Mushaf order, with the pressed
  ayah first.

### Explanation

Every line after the heading, up to the next `##` heading or the end of the file.

- Leading and trailing blank lines are dropped.
- One or more blank lines start a new paragraph.
- Single line breaks inside a paragraph are kept.
- Any Markdown symbols (`**`, `#`, `-`) are shown as typed. The app does not render Markdown.

### Other rules

- A `#` heading (one hash) before the first group is allowed as a title.
- Lines starting with `###` or more hashes are explanation text, not headings.
- One ayah can appear in several groups, each with its own explanation (spec User Story 4).

## Checks

The tool prints one line per problem and exits with code 1 if there is any error.

| Kind | Error? | Example message |
| --- | --- | --- |
| `badReference` | error | `line 12 (## 2:35 7;19): "7;19" is not a reference (use surah:ayah)` |
| `noSuchAyah` | error | `line 12 (## 2:35 2:300): 2:300 is not an ayah (surah 2 has 286)` · `115:1: there is no surah 115` |
| `tooFewAyat` | error | `line 30 (## 3:7): a group needs at least two different ayat` |
| `emptyExplanation` | error | `line 30 (## 3:7 39:23): the explanation is empty` |
| `duplicateAyah` | warning | `line 41 (## 2:35 2:35 7:19): 2:35 is listed twice; kept once` |
| `textBeforeFirstGroup` | none | not reported: notes before the first group are allowed |

On success the tool prints `mutashabihat.md: N groups, M linked ayat, OK`.

In the app, a group with an error is skipped, so the rest of the file still works (FR-019). The
check exists so that never happens in a release.
