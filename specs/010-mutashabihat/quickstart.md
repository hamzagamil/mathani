# Quickstart: Validating Mutashabihat

**Feature**: [spec.md](./spec.md) | **Contracts**: [content-file](./contracts/content-file.md),
[UI](./contracts/mutashabihat-ui.md)

## Prerequisites

- **Code**: the branch with this feature.
- **Devices**: the reference phones (Galaxy A15, iPhone SE 2nd gen), plus a desktop browser for
  the web build.
- **Content**: `assets/mutashabihat/mutashabihat.md` with at least these test groups. Remove them
  before release if they are not real content.
  - `## 2:35 7:19`: two paragraphs of explanation.
  - `## 2:58 7:161`: a second group.
  - `## 2:35 20:117 20:120`: puts 2:35 in two groups.
  - `## 2:282 2:283`: a very long ayah.
  - One group of 12 or more ayat, for example the «فَبِأَيِّ ءَالَآءِ رَبِّكُمَا تُكَذِّبَانِ» refrains in Ar-Rahman.

## Automatic checks

```powershell
dart run tool/check_mutashabihat.dart          # expect: N groups, M linked ayat, OK
flutter analyze
flutter test --exclude-tags golden             # parser, ayah counts vs quran.db, colour contrast, sheet widgets
```

To check the gate, add the line `## 2:35 2:300` to the file, then:
- the tool exits with code 1 and names line, group and `2:300`;
- `flutter test` fails;
- `node --use-system-ca tool/web_deploy.mjs --dry-run` stops before uploading.

Undo the change afterwards.

## Q1. Startup and paging speed (Principle III, SC-002)

1. Cold-start the release build 5 times on each reference phone, before and after the feature.
   **Expect**: the median changes by less than 50 ms and stays ≤ 2 s.
2. Run `integration_test/paging_perf_test.dart` on a page range that includes 2:35 and Ar-Rahman.
   **Expect**: no more dropped frames than before.

## Q2. Colour (US2, SC-003)

1. Open page 6 (2:35) in the Mushaf layout. **Expect**: every word of 2:35 and its end mark are in
   the mutashabih colour, and the neighbouring ayat are in normal ink.
2. Switch to the flowing layout, then to the night theme. **Expect**: the same ayat are coloured,
   readable and clearly different from normal text.
   - **Owner**: confirm or adjust the two colour values here.
3. Long-press 2:35. **Expect**: the selection background shows behind green text. Play from
   2:34 and watch the recitation highlight pass over 2:35. Open 2:35 from search. **Expect**: the
   jump highlight shows, with the text still coloured.
4. Start a memorization session on 2:30–2:40. **Expect**: no ayah on the page is coloured. End the
   session. **Expect**: the colour returns.
5. Turn on TalkBack / VoiceOver in the flowing layout and move to 2:35. **Expect**: "Ayah 35, has
   similar ayat" (Arabic interface: «الآية ٣٥، لها متشابه»). In the Mushaf layout, the page label
   lists the linked ayat.

## Q3. Overlay (US1, SC-001)

1. Long-press 7:19. **Expect**: «عرض المتشابه» is the first action. Long-press 7:18. **Expect**: no
   such action.
2. Tap «عرض المتشابه» on 7:19. **Expect**:
   - feedback within 100 ms and the overlay within 1 s;
   - 7:19 first with «هذه الآية», then 2:35;
   - the explanation in the bottom third, with both paragraphs.
3. Open the 12-ayah group. **Expect**: it opens within 1 s, the top part scrolls to the last ayah,
   and the explanation does not move.
4. Open 2:282. **Expect**: the whole ayah can be read by scrolling the top part.
5. Tap 2:35 in the overlay. **Expect**: the overlay closes, the Mushaf goes to page 6 and 2:35 is
   highlighted briefly.
6. Open the overlay again and close it three ways: ✕, back, swipe down. **Expect**: each time,
   the same page and position as before, with no selection left.
7. Set system font scaling to the maximum. **Expect**: both parts scroll, nothing is clipped, and
   ✕ is still reachable.
8. Turn on airplane mode and repeat step 2. **Expect**: the same result.

## Q4. Several groups (US4)

1. Open the overlay on 2:35. **Expect**: chips «١» «٢». «١» shows 7:19 and its explanation. «٢»
   shows 20:117 and 20:120 and the second explanation.
2. Open the overlay on 20:117. **Expect**: no chips, and only the second group.

## Q5. Owner workflow (US3, SC-005)

1. Time adding a new group of three ayat with a paragraph of explanation to the file. **Expect**:
   under 5 minutes.
2. Run the check, build, and confirm the new group on a phone.
3. Remove an ayah from a group, rebuild, and confirm it is no longer coloured.

## Q6. Content missing (FR-019)

Build once with the file renamed. **Expect**: the reader opens and works normally, no ayah is
coloured, there is no «عرض المتشابه» action, and nothing crashes. Rename it back.

## Q7. Web (FR-020, FR-013)

1. Build and deploy a preview with `--dry-run`. Open it, read page 6 and right-click 2:35.
   **Expect**: the same action and overlay. Esc closes it.
2. Go offline in the browser's developer tools and reload. **Expect**: the colour and the
   overlay still work.

## Q8. Size (Principle IV)

Run the CI size check. **Expect**: growth well under 1 MB on both platforms. Record it in
`docs/release.md`.
