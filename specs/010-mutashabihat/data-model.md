# Data Model: Mutashabihat (Similar Ayat)

**Feature**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

All data comes from one bundled, read-only file: `assets/mutashabihat/mutashabihat.md`. Its
format is in [contracts/content-file.md](./contracts/content-file.md). Nothing is stored in
`quran.db` or `user.db`, and readers create no data.

## MutashabihGroup

One group of similar ayat with one explanation (spec Key Entities: group, member, explanation).

| Field | Type | Rule |
| --- | --- | --- |
| `ayat` | `List<AyahRef>` | 2 or more, all distinct, all real ayat (FR-014, FR-016). Kept in Mushaf order, so the overlay order does not depend on how the owner typed the heading. |
| `explanation` | `String` | Not empty after trimming (FR-016). Paragraphs are separated by one blank line. Lines are kept as written (FR-007). |
| `line` | `int` | The 1-based line of the group's `##` heading in the file. Used in check messages and in tests; it serves as the group's identifier. |

There is no separate member entity: a member is an `AyahRef` in `ayat`. `AyahRef` already exists
in `lib/data/models.dart`, with value equality and Mushaf ordering.

The owner's note after `|` in the heading is not kept. It is for the file only.

## Mutashabihat

The loaded content, held by `ReaderController.similar`.

| Member | Type | Meaning |
| --- | --- | --- |
| `groups` | `List<MutashabihGroup>` | Valid groups, in file order. |
| `isLinked(AyahRef)` | `bool` | The ayah is in at least one group (FR-001, FR-005). |
| `groupsOf(AyahRef)` | `List<MutashabihGroup>` | The ayah's groups, in file order (FR-011). Empty if it is not linked. |
| `linkedOnPage(List<AyahRef>)` | `List<AyahRef>` | Linked ayat among those on a page, for the page semantics label (R8). |
| `Mutashabihat.empty` | constant | No groups. Used when the file is missing or cannot be read (FR-019). |

Built once at startup from an index `Map<AyahRef, List<int>>` (ayah → group positions). Lookups
are a single map access, cheap enough to run for every word at page layout.

## ContentProblem

What the check reports. Used by `tool/check_mutashabihat.dart` and the tests. The app does not
show these.

| Field | Type | Meaning |
| --- | --- | --- |
| `line` | `int` | Line in the file. |
| `kind` | enum | `badReference`, `noSuchAyah`, `tooFewAyat`, `emptyExplanation`, `duplicateAyah`. Notes before the first group are allowed and not reported. |
| `isError` | `bool` | `duplicateAyah` is a warning: the duplicate is dropped (spec Edge Cases). Everything else is an error. Errors fail the check, and the app skips that group. |
| `message` | `String` | English, names the group by its heading line, for example `line 42 (## 2:35 2:300): 2:300 is not an ayah (surah 2 has 286)`. The tool prefixes `error:` or `warning:` and the file name. |

## Parse result

`parseMutashabihat(String text) → (Mutashabihat content, List<ContentProblem> problems)`. Pure,
with no I/O. `loadMutashabihat()` reads the asset and calls it. The tool reads the file from disk
and calls it.

## Ayah counts

`const List<int> ayahCounts` (114 entries, index = surah − 1) in `mutashabihat_content.dart`, so
the check runs without the database (R2). A test checks it against `quran.db`'s surah table.

## State and changes

There are none at runtime: the content is fixed for a given build. When the owner edits the file,
the change reaches readers with the next release (spec Clarifications). The web service worker
replaces its cached copy when the file's hash changes (R9).
