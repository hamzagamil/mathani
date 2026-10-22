# Quickstart: Print-Like Mushaf Page

How to check that this feature works. Setup is the same as
[001 quickstart](../001-quran-mushaf-reader/quickstart.md) (Flutter 3.47.7, `assets/db/quran.db`
built, reference devices: Galaxy A15 and iPhone SE 2nd gen).

## Automated checks

```sh
flutter test tool/measure_line_widths_test.dart   # writes meta.justify_target_em
flutter test test/unit/kashida_test.dart   # join points, justifyLine rules
flutter test test/widget/mushaf_typesetting_test.dart   # all 604 pages × 3 widths: budgets
flutter test test/widget/reader_page_view_test.dart     # controls, hint, accessibility
flutter test test/widget/mushaf_page_renderer_golden_test.dart --update-goldens   # once, then review
flutter analyze && flutter test
```

Expected:
- `kashida_test`: every rule in [page-typesetting](./contracts/page-typesetting.md) holds.
- `mushaf_typesetting_test` at 320, 390 and 430 pt widths: every justified line within 1% of the
  target; scale ≥ 0.95; gap ≤ 1.5 × space except the recorded count of lines with too few join
  points; text block ratio 1.77 ± 2%; Quran font ≥ today's size; page text identical to
  `Word.text` (copy and semantics).
- `reader_page_view_test`: the transitions in [reader-page-view](./contracts/reader-page-view.md).
- Goldens for pages 1, 3, 50, 300 and 604 in day and night: review them by eye against the
  reference screenshot before accepting.

## Manual scenarios (device, Arabic and English interfaces)

1. **Lines (User Story 1).** Open pages 3, 50, 300 and 604. Every full line reaches both edges,
   and no gap between words looks wider than a normal space. Centred lines stay centred.
2. **Copy (FR-005).** Long-press an ayah on page 3 and copy it. The pasted text has no tatweel and
   matches the source.
3. **Screen sizes (User Story 2).** Compare page 3 on the iPhone SE and on a tall phone. The same
   words sit on each line; the tall phone shows margins above and below the block, not wider line
   spacing.
4. **Paper page (User Story 3).** Open the reader: the controls show. Turn a page: they hide, and
   the first time the hint appears. Tap: they show within a moment. Tap again: they hide.
   Long-press still opens the ayah sheet. Surah and juz at the top of the page, page number at the
   bottom. Repeat in night theme.
5. **Screen reader.** With TalkBack or VoiceOver on, the controls stay visible and reachable.
6. **Switching layouts.** Switch to flowing and back: the system bars come back in flowing, and
   the reader stays at the same ayah.

## Performance and size gates

On the reference phones, profile build:
- Paging through 50 pages stays at 60 fps (no frame over 16 ms in the page-turn traces).
- Page layout ≤ 8 ms per page.
- Cold start to a readable page ≤ 2 s.
- `flutter build appbundle --analyze-size` and `flutter build ipa --analyze-size`: growth ≤ 0.5 MB
  against `main` (SC-007).

## Replica pack (after D3 and spikes S-1, S-2)

1. `dart run tool/build_replica_pack.dart` must pass its layout check (100% of words on the same
   page and line) and its missing-glyph check.
2. On Wi-Fi, download the pack from Settings, turn on airplane mode, open pages 1, 3, 300 and 604:
   printed lettering, same line breaks, highlights in place.
3. Interrupt the download (airplane mode mid-way), reopen the app, resume: it continues without
   re-downloading finished files.
4. Delete the pack: built-in lettering returns at the same ayah, and the storage is freed.
