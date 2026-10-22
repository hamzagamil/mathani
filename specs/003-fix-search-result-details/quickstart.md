# Quickstart: Fix Search Result Details

How to check that this feature works. Setup is the same as
[001 quickstart](../001-quran-mushaf-reader/quickstart.md) (Flutter 3.47.7, `assets/db/quran.db`
built).

## Automated checks

```sh
flutter test test/unit/search_index_test.dart     # matching rule, counts, invariants
flutter test test/widget/search_test.dart         # query changes, row text, tap, summary
flutter analyze
```

Expected:
- `search_index_test`: every example in [search-matching](./contracts/search-matching.md) passes,
  including the regression counts and the invariants in [data-model](./data-model.md).
- `search_test`: across 50 consecutive query changes, every visible row's text belongs to the
  ayah in its title (spec SC-001), and tapping a row opens that ayah (SC-003).

## Manual scenarios (device or emulator, Arabic interface)

1. **Wrong-ayah bug (spec User Story 1).** Search «الرحمن الرحيم», then replace it with «قل هو الله
   احد». The single row is «سورة الإخلاص، الآية ١» and shows «قُلْ هُوَ ٱللَّهُ أَحَدٌ», highlighted.
   Before the fix it showed the basmala.
2. **Letter by letter.** Type «الرحمن» one letter at a time. After each letter, every visible row's
   text belongs to the ayah in its title.
3. **Tap.** Tap any row: the Mushaf opens on that ayah, highlighted.
4. **Summary (User Story 2).** Search «الله»: «٢٥٤٧ موضعًا في ١٧٣٧ آية» (or the counts recorded in the contract), and the number of ayat equals
   the rows. Search «الرحمن الرحيم»: «٦ آيات» only. Repeat in English.
5. **Matching rule (User Story 3).** «من» finds «فمن» and «منهم» but not «المؤمنين». «لله» does not
   find «الله». «يا ايها الذين امنوا» gives 89 ayat.
6. **Screen reader.** With TalkBack or VoiceOver, the summary is announced after each search.

## Performance gate

On the reference phones (Galaxy A15, iPhone SE 2nd gen), profile build:
- The first search after opening the app returns within 1 s (corpus load and stem building
  included).
- Later searches update within 100 ms of the debounce.
- Scrolling the «من» list (about 2,600 rows) stays at 60 fps.
