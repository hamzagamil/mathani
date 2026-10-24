# Contract: Onboarding UI

The screens and strings of the onboarding. State and wiring are in
[onboarding-flow](./onboarding-flow.md).

Every control is at least 44 pt (iOS) / 48 dp (Android), is labelled in the interface language,
uses brand tokens (`lib/app/theme/tokens.dart`), and works in day and night, at the largest
system font size, and with VoiceOver and TalkBack. Interface numbers follow the language
(`formatNumber`), as elsewhere.

## OnboardingScreen (setup steps and gesture stops)

`lib/features/onboarding/onboarding_screen.dart`. One `Scaffold` on `surface`, inside the safe
area, with three parts:

```text
┌──────────────────────────────────────────┐
│  الخطوة ٢ من ٤                             │  progress (caption, inkMuted)
│                                          │
│  كيف تحب أن يبدو المصحف؟                  │  title (titleLg, ink)
│  hint line, when the step has one        │  (body, inkMuted)
│                                          │
│        ┌───────────────┐                 │
│        │  illustration │                 │  TourIllustration or preview
│        └───────────────┘                 │
│                                          │
│  [ choices for the step ]                │  setup steps only
│                                          │  (scrolls if text is large)
├──────────────────────────────────────────┤
│  تخطَّ            ‹ السابق     [ التالي ]  │  bottom bar, always visible
└──────────────────────────────────────────┘
```

- **Body**: a `PageView` with `physics: NeverScrollableScrollPhysics()`. Steps move only with the
  buttons or back, so a swipe meant for the illustration can't change the step. Each page is a
  `SingleChildScrollView`, so large text scrolls inside the step while the bottom bar stays put
  (FR-019, edge case: large font).
- **Bottom bar** (the "one hand" zone):
  - **Skip** is a text button at the start;
  - **Back** is an outlined button, hidden on the first step;
  - **Next** is a filled button at the end. Gesture stops always follow the setup steps, and the
    last stop is a button hint, so this screen never shows **Done**.

  If the three buttons don't fit on one row, the bar wraps to two rows, with Skip on its own row
  at the start.
- **Direction**: everything follows `Directionality`. Back and Next use `MathaniIcons.back` and
  `MathaniIcons.forward`, which mirror in Arabic.
- **Moving between steps**: `animateToPage` over 250 ms with `Curves.easeOut`. When
  `disableAnimations` is set, it jumps instead. On each step change, screen-reader focus moves to
  the title.
- **System back**: `PopScope(canPop: atFirstStep)`. Elsewhere it calls `onboarding.back()`.

### Language step

The title shows both scripts, «أهلاً بك في مثاني» · "Welcome to Mathani", so a reader of either
language knows where they are. Below it are three large radio cards:

| Card | Label | Note |
| --- | --- | --- |
| system | `languageSystem` + the language it resolves to, for example «حسب الجهاز (English)» or "Device (العربية)" | the resolved name, in its own script |
| ar | العربية | always in Arabic |
| en | English | always in English |

Picking a card calls `updatePreferences(language: …)`. The screen re-localizes and flips
direction, and stays on this step.

### Theme step

Three radio cards: `themeSystem`, `themeDay`, `themeNight`, with `MathaniIcons.themeSystem`,
`day` and `night`. A still `TourIllustration` above the cards shows the reading screen in the
current layout. The whole screen restyles on selection.

### Layout step

Two cards, each with the existing icon, label and a one-line description:

| Card | Label | Description (ar / en) |
| --- | --- | --- |
| mushaf | `layoutMushaf` | «الصفحات كما طُبعت في مصحف المدينة» / "Pages as printed in the Madinah Mushaf" |
| flowing | `layoutFlowing` | «نص متصل يمكنك تكبير خطه» / "Continuous text you can enlarge" |

The illustration above shows the chosen layout. Choosing flowing adds the text size step after
this one.

### Text size step (flowing only)

A slider exactly like Settings (18–34, step 1, value shown beside it). Below it, Al-Fatiha 1–3 is
set with the flowing layout's text style at the chosen size, inside a `surfaceRaised` card.

### Reciter step

One card per reciter in `quran.reciters` order:

```text
┌──────────────────────────────────────────┐
│ ◉  محمود خليل الحصري           ( ▶ )     │  name in the interface language
│    مرتل                                   │  (English: Arabic name · Murattal)
└──────────────────────────────────────────┘
```

- **Tapping the card** selects the reciter (radio).
- **The round button** plays or stops the sample (`previewReciter` / `stopPreview`):
  - while `loading`, it shows a spinner and works as Stop;
  - while `playing`, it shows `MathaniIcons.pause`;
  - its label is «استمع إلى مقطع» / "Play sample" or «أوقف المقطع» / "Stop sample".
- **Offline note**: shown under the cards when the network pre-check says `none`, or after an
  `unavailable` preview. It uses `MathaniIcons.info` with `inkMuted` text. When offline, the sample
  buttons are disabled; the cards still work.

### Gesture stops

The progress shows "*i* من *n*" / "*i* of *n*", counting tour stops. The title and body come from
Strings below, and the illustration is the animated `TourIllustration` (research R3). There are
no choices.

## ButtonTour (hints over the reading screen)

`lib/features/onboarding/button_tour.dart`. It sits over `ReaderScreen` while
`phase == buttons`.

```text
┌──────────────────────────────────────────┐
│░░░░░░░░░░░ reading screen, dimmed ░░░░░░░│
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│  ┌────────────────────────────────────┐  │
│  │ ٤ من ٧                              │  │
│  │ الفهرس                              │  │  title (titleSm)
│  │ السور والأجزاء ومحفوظاتك.           │  │  body (body)
│  │ تخطَّ           ‹ السابق   [التالي]  │  │
│  └───────────────▼────────────────────┘  │  notch towards the target
│ ░░ ╭──╮ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│    │☰ │  🔍   📖   ▶   🔖   ⚙            │  toolbar; the target is in a hole with a focusRing
│ ░░ ╰──╯ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
└──────────────────────────────────────────┘
```

| Part | Spec |
| --- | --- |
| Scrim | Black at 55% opacity, with a rounded-rect hole (radius `sm`) 8 dp around the target and a 2 dp `focusRing` stroke. It absorbs all taps. |
| Card | `surfaceRaised`, radius `md`, 16 dp side gutter. It sits just above the target row, or below it if the target is in the top half. It is at most half the screen tall: the title and body scroll inside, and the buttons are pinned below them, always visible (FR-019). |
| Buttons | The same three as the onboarding bottom bar. Next reads **Done** («تم») on the last stop. |
| Targets | `index`, then `search`, then `player` (Listen button, or the recitation bar while a session exists), then `settings`. A step whose target isn't laid out (no key context) is skipped rather than shown pointing at nothing. |
| Semantics | The screen underneath is excluded. The card is one container, labelled "*i* of *n*, *title*. *body*", followed by the buttons. |

## Settings row

At the end of the options, before the About divider:

```text
 ⓘ  See the tour again                       ›
     How to turn pages, use the ayah actions, the index, search and the player.
```

- It is a `ListTile`. The leading icon is `MathaniIcons.info`, unless a better Lucide glyph is
  added at implementation. The trailing icon is `MathaniIcons.forward`.
- Strings: `tourAgainSetting` and `tourAgainHint`.

## Strings (app_ar.arb / app_en.arb)

New keys. Existing keys are reused where the meaning is the same: `languageSystem`,
`themeSystem`, `themeDay`, `themeNight`, `layoutMushaf`, `layoutFlowing`, `textSizeSetting`,
`chooseReciter`, `murattal`, `playFromAyah`, `copyAyah`, `shareAyah`, `bookmarkAyah`.

| Key | Arabic | English |
| --- | --- | --- |
| `onboardingWelcome` | أهلاً بك في مثاني | Welcome to Mathani |
| `onboardingLanguageTitle` | اختر لغة التطبيق | Choose the app language |
| `onboardingSystemLanguage` | حسب الجهاز ({language}) | Device ({language}) |
| `onboardingThemeTitle` | كيف تحب أن يبدو المصحف؟ | How should the Mushaf look? |
| `onboardingLayoutTitle` | كيف تحب أن تقرأ؟ | How would you like to read? |
| `onboardingLayoutMushafHint` | الصفحات كما طُبعت في مصحف المدينة | Pages as printed in the Madinah Mushaf |
| `onboardingLayoutFlowingHint` | نص متصل يمكنك تكبير خطه | Continuous text you can enlarge |
| `onboardingTextSizeTitle` | اختر حجم الخط | Choose the text size |
| `onboardingReciterTitle` | لمن تحب أن تستمع؟ | Whom would you like to listen to? |
| `onboardingReciterHint` | يمكنك تغيير القارئ في أي وقت من المشغّل أو الإعدادات. | You can change the reciter any time from the player or Settings. |
| `playSample` | استمع إلى مقطع | Play sample |
| `stopSample` | أوقف المقطع | Stop sample |
| `sampleOffline` | تحتاج المقاطع إلى اتصال بالإنترنت، ويمكنك الاختيار دونها. | Samples need an internet connection. You can still choose. |
| `onboardingStep` | الخطوة {index} من {total} | Step {index} of {total} |
| `tourProgress` | {index} من {total} | {index} of {total} |
| `onboardingNext` | التالي | Next |
| `onboardingBack` | السابق | Back |
| `onboardingSkip` | تخطَّ | Skip |
| `tourDone` | تم | Done |
| `tourTurnPagesTitle` | قلّب الصفحات | Turn the pages |
| `tourTurnPagesMushaf` | اسحب الصفحة لتقلبها كما تقلّب صفحات المصحف المطبوع. | Swipe to turn the page, as you would in a printed Mushaf. |
| `tourTurnPagesFlowing` | مرّر الشاشة لتتابع القراءة؛ النص متصل من سورة إلى أخرى. | Scroll to read on. The text flows from one surah to the next. |
| `tourControlsTitle` | أدوات التحكم | The controls |
| `tourControlsMushaf` | انقر على الصفحة لإظهار أدوات التحكم أو إخفائها. | Tap the page to show or hide the controls. |
| `tourControlsFlowing` | تبقى أدوات التحكم في أعلى الشاشة وأسفلها. وفي عرض صفحات المصحف انقر على الصفحة لإظهارها. | The controls stay at the top and bottom. In the Mushaf pages layout, tap the page to show them. |
| `tourAyahTitle` | خيارات الآية | Ayah actions |
| `tourAyahBody` | اضغط مطولاً على آية لتستمع منها أو تحفظها أو تنسخها أو تشاركها. | Press and hold an ayah to play from it, bookmark, copy or share it. |
| `tourIndexTitle` | الفهرس | Index |
| `tourIndexBody` | السور والأجزاء ومحفوظاتك، ومنها تنتقل إلى أي موضع. | Surahs, ajza' and your bookmarks. Go anywhere from here. |
| `tourSearchTitle` | البحث | Search |
| `tourSearchBody` | ابحث في نص القرآن الكريم بالتشكيل أو دونه. | Search the Quran text, with or without diacritics. |
| `tourPlayerTitle` | الاستماع | Listen |
| `tourPlayerBody` | استمع آية آية مع تظليل الآية المتلوّة. ونزّل السور من فهرس السور أو من المشغّل لتستمع دون اتصال. | Listen ayah by ayah as each one is highlighted. Download surahs from the Surahs index or the player to listen offline. |
| `tourSettingsTitle` | الإعدادات | Settings |
| `tourSettingsBody` | غيّر اختياراتك متى شئت، وستجد المزيد: إبقاء الشاشة مضاءة، وخط المصحف المطبوع، والتنزيلات، وهذه الجولة. | Change your choices any time, and find more: keep screen on, printed lettering, downloads, and this tour. |
| `tourAgainSetting` | شاهد الجولة التعريفية مرة أخرى | See the tour again |
| `tourAgainHint` | كيف تقلّب الصفحات وتستخدم خيارات الآية والفهرس والبحث والمشغّل. | How to turn pages and use the ayah actions, index, search and player. |

**Removed**: `controlsHint` (research R2).

## Accessibility checklist (FR-024)

- Radio cards are exposed as radio buttons (`Semantics(inMutuallyExclusiveGroup, checked)`).
- The sample button announces its state ("Play sample, Al-Husary" / "Stop sample, Al-Husary").
- Illustrations are excluded from semantics; the body text carries the meaning.
- The 200% font scale is checked on the smallest reference phone (iPhone SE, 2nd gen). Nothing
  clips, and the bottom bar wraps.
- Contrast: the card text on `surfaceRaised` and the button colours are the existing tokens,
  which are already AA in both themes.
