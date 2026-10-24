# Contract: Reader Page View

Updates the **Reader** row of [001 ui-screens](../../001-quran-mushaf-reader/contracts/ui-screens.md)
for the Mushaf layout. The flowing layout is unchanged.

## States

| State | System bars | App header and toolbar | Page |
| --- | --- | --- | --- |
| **Reading** (controls hidden) | hidden | hidden | full screen within safe areas |
| **Controls shown** | visible | overlaid: header slides down, toolbar slides up (200 ms) | unchanged underneath |
| **Screen reader on** | visible | always shown | unchanged |

## Transitions

| From | Event | To |
| --- | --- | --- |
| any | open reader in Mushaf layout | Controls shown |
| Controls shown | page turn | Reading |
| Controls shown | tap on page | Reading |
| Reading | tap on page | Controls shown (visible within 100 ms) |
| any | tap while an ayah is selected | clears the selection, controls unchanged |
| any | long-press on an ayah | ayah action sheet (001), controls unchanged |
| any | switch to flowing layout, or leave the reader | system bars restored |

First time ever only: when the controls first hide, show the snackbar «اضغط على الصفحة لإظهار
الأدوات» / "Tap the page to show controls" for 4 s, then set `controls_hint_shown = true`.
*(Removed 2026-10-24 by [specs/005](../../005-app-onboarding/research.md) research R2: the
onboarding teaches the tap, so the hint and `controls_hint_shown` are gone.)*

## Controls

The same actions as today (index, search, layout switch, bookmark, settings), plus the header
with surah, juz and page in the interface language (001 FR-008). Touch targets 44 pt (iOS) /
48 dp (Android).

## Sheet

- Day: background `surface` (cream «Mushaf paper»), noise texture at 3% ink, page-edge gradient
  12 pt on the binding side (right side for odd pages and left for even pages, as in a bound
  Mushaf).
- Night: the same, with the night `surface` and night ink.
- Quran ink against the darkest texture value: contrast ≥ 4.5:1 in both themes.

## Accessibility

- Semantics: the page keeps its label «صفحة {n}، سورة {name}». The page details in the header and
  footer bands are not read separately.
- Controls overlay: a semantic "Show controls" action on the page, so switch-access users can
  open them.

## Updated by specs/004 (recitations)

While a recitation is on, its bar is the reader's bottom bar: it stays visible in the **Reading**
state (controls hidden), the page sits above it and is never covered, and the toolbar overlay
appears above it. A page turn made by following the recitation does not hide the controls; a
swipe still does. See [specs/004 recitation-ui](../../004-ayah-recitations/contracts/recitation-ui.md)
and [recitation-playback › Following](../../004-ayah-recitations/contracts/recitation-playback.md).
