# Contract: Memorization UI

Screens, states and strings for memorization mode. Engine:
[memorization-engine](./memorization-engine.md). Every string is in `app_ar.arb` and
`app_en.arb`. Arabic is the source text.

## Entry points (FR-008)

| Where | Control | Action |
| --- | --- | --- |
| Reading screen toolbar | New icon button «الحفظ» / "Memorize" (Lucide `brain`), beside Listen | Opens the range sheet with the page default |
| Ayah actions (long-press) | «احفظ من هذه الآية» / "Memorize from this ayah" | Opens the range sheet with the long-press default |

The button tour of feature 005 gains one hint for the Memorize button: «اختبر حفظك: تلُ من
ذاكرتك وتظهر الآيات كلما أتممتها» / "Test your memorization: recite from memory and each ayah
appears as you complete it".

## Range sheet (FR-009)

A bottom sheet:

| Part | Behaviour |
| --- | --- |
| Surah | Picker, the same list as the go-to sheet of feature 001 |
| From / To | Two numeric steppers with direct entry, limited to 1..ayahCount. Moving From past To also moves To to it, so `to < from` cannot happen |
| Summary | «٧ آيات · الصفحة ٥٠–٥١» / "7 ayat · pages 50–51" |
| Model status, when not `ready` | Row: «يحتاج الحفظ إلى تنزيل نموذج التعرّف على التلاوة مرة واحدة (٦١٫٥ م.ب). بعدها يعمل دون اتصال.» / "Memorization needs a one-time download of the recitation model (61.5 MB). After that it works offline." with a Download button and progress |
| Primary button | «ابدأ» / "Start". Disabled until the model is ready |

**Device not supported** (R15): the sheet shows only «الحفظ غير متاح على هذا الجهاز» /
"Memorization isn't available on this device", with the reason (64-bit or memory).

## Microphone explainer (FR-010)

Shown before the system prompt, the first time only:

- Title: «الميكروفون للمتابعة فقط» / "The microphone is only for following you".
- Body: «يستمع مثاني إلى تلاوتك ليُظهر كل آية حين تتمها. يجري ذلك على جهازك فقط، ولا يُسجَّل صوتك
  ولا يُرسل.» / "Mathani listens to your recitation to reveal each ayah as you complete it. This
  happens on your device only; your voice is never recorded or sent."
- Button: «متابعة» / "Continue", which shows the system prompt.

**Denied**: «لا يمكن بدء الحفظ دون الميكروفون.» / "Memorization can't start without the
microphone." When the permission is permanently denied, an «فتح الإعدادات» / "Open Settings"
button calls `openAppSettings`.

## Reading screen during a session (FR-012, FR-018, FR-020)

- **Page**: the range's ayat show only their ayah-end markers; their words are hidden without
  reflow (R13). Text outside the range, surah headers and basmala lines are shown as usual.
- **Marks**:
  - revealed words: normal ink;
  - hinted words: `hint` colour (new token, day and night);
  - an ayah with a mistake: its ayah-end marker in the `mistake` colour (new token);
  - the expected ayah: its marker in `accent`, with a soft pulse while listening. The pulse is
    off when the system reduce-motion setting is on.
- **No interference**: page swipes are allowed and do not affect the session. The bar offers
  «عُد إلى الآية» / "Back to the ayah" when the expected ayah is off-screen, as the recitation bar
  does. Long-press ayah actions are disabled for range ayat while a session exists, so the text
  can't be copied or shared.

### Memorization bar

Docked like the recitation bar, so it never covers text:

| Part | Content |
| --- | --- |
| Mic indicator | Always visible while listening: red dot plus «يستمع» / "Listening". Paused: «متوقف» / "Paused" with the reason (below) |
| Progress | «الآية ٣ من ٧» / "Ayah 3 of 7" |
| Buttons | Pause/Resume, «الكلمة التالية» / "Next word", «أظهر الآية» / "Show this ayah", «إنهاء» / "End". All 48 dp |
| Mistake line | On a mistake: «خطأ — تابع من الكلمة» / "Mistake — carry on from the word" for 3 s; a live region for screen readers |

The recitation bar and the Listen button are hidden during a session. The Memorize button
becomes the bar.

**Paused reasons**:

| Reason | Text |
| --- | --- |
| user | «متوقف» / "Paused" |
| silence | «توقّف الاستماع بعد ٣٠ ثانية من الصمت» / "Stopped listening after 30 seconds of silence" |
| interruption | «توقّف بسبب مكالمة أو صوت آخر» / "Paused for a call or other audio" |
| background | «توقّف حين غادرت التطبيق» / "Paused when you left the app" |
| routeLost | «انقطع الميكروفون» / "The microphone was disconnected" |

Screen readers: hidden ayat read «الآية ٥، مخفية» / "Ayah 5, hidden". A reveal announces
«ظهرت الآية ٥» / "Ayah 5 revealed". The mic indicator has the label "Microphone on".

## Result screen (FR-023 to FR-026)

A full-screen route, pushed when the session ends:

| Part | Content |
| --- | --- |
| Score | Large «٧٢» with «من ١٠٠» / "out of 100", or «—» when no ayah was reached |
| Counts | «دون خطأ ٥ · صُحّحت ١ · بتلميح ١ · أُظهرت ١ · لم تُبلغ ٢» / "No mistake 5 · Corrected 1 · Hinted 1 · Revealed 1 · Not reached 2" |
| Reached | «بلغت ٨ من ١٠ آيات» / "You reached 8 of 10 ayat" |
| Review | A list of the range's ayat in full, flowing style, with marks: missed or wrong words underlined in `mistake` (wrong shows the heard form in the semantics only), added marked with a caret between words, hinted words in `hint`, revealed ayat with a «أُظهرت» / "Revealed" tag, and unreached ayat dimmed with «لم تُبلغ» / "Not reached" |
| Actions | «أعد المحاولة» / "Try again" (same range, new session) and «تم» / "Done" (back to reading at the last page of the session, FR-025, US3-4) |

The result is not saved (FR-026).

## Settings

- **Recitations section**: new row «التنبيه عند الخطأ» / "Mistake alert" with three choices:
  «اهتزاز» / "Vibrate" (default), «صوت» / "Sound", «بدون» / "None".
- **Downloads screen** (feature 004): a top row «نموذج الحفظ · ٦١٫٥ م.ب» / "Memorization model ·
  61.5 MB" with delete. Deleting during a session is not offered: the row is disabled while a
  session exists.

## Theme tokens

| Token | Day | Night | Use |
| --- | --- | --- | --- |
| `hint` | secondary at 70% | secondary at 80% | Hinted words |
| `mistake` | the error palette tone used for snackbars | the night counterpart | Mistake markers and review marks |

Both tokens meet 3:1 contrast against the page.
