# Contract: Recitation UI

This updates the **Reader**, **Index › Surahs**, **Ayah actions** and **Settings** rows of
[001 ui-screens](../../001-quran-mushaf-reader/contracts/ui-screens.md) and
[002 reader-page-view](../../002-print-like-mushaf-page/contracts/reader-page-view.md). All
controls are at least 44 pt (iOS) / 48 dp (Android), have labels in the interface language, use
brand tokens, and work in day and night.

## Reader toolbar

Add a **Play** button (`MathaniIcons.play`) to the toolbar, between the layout switch and the
bookmark. Its label is «استمع» / "Listen". It calls `playFromPage(reader.page)` (or the top ayah
in the flowing layout). While a session exists it is hidden, because the bar takes its place.

## Recitation bar

It is docked at the bottom of the reader in both layouts while a session exists (research R10).
In the Mushaf layout it stays visible when the controls are hidden. When the controls are shown,
the toolbar sits above it. It takes no part in tap-to-show.

```text
┌──────────────────────────────────────────────────────────┐
│  ⏮   ▶/⏸   ⏭   سورة الملك · ١٢           الحصري ▾   ✕    │
│                ↩ العودة إلى التلاوة  (only when not following)
└──────────────────────────────────────────────────────────┘
```

| Element | Behaviour |
| --- | --- |
| Previous / Play-Pause / Next | `previous()`, `pause()`/`resume()`, `next()`. In `loading`, Play-Pause shows a spinner and stays tappable as Pause. |
| Item text | Surah and ayah (or «البسملة» / "Basmala") in the interface language and numerals. Tap: `returnToRecitation()`. |
| Reciter chip | The short name from the catalogue (`short_ar` / `short_en`: الحصري / المنشاوي, Al-Husary / El-Minshawi). Tap: reciter sheet. |
| Close ✕ | `stop()` |
| "Back to recitation" row | Visible only when `following == false`. Tap: `returnToRecitation()`. |
| Error row | Replaces the "back" row in `error`: the message and a **Retry** action. For `offline` on a surah that is not complete, it also has a **Download** action (opens the download flow). |

Bar height is 56 dp, or 56 + 36 dp with the second row, plus the bottom safe area. The Mushaf
page refits when the height changes (R10). The row change animates over 200 ms and does not
change the page's text size twice in a row: the refit happens once, at the end.

Semantics: the bar is a region labelled «مشغّل التلاوة» / "Recitation player". The item text is
a live region that announces only on a user action, not on each ayah, so screen readers aren't
interrupted (spec edge case).

## Reciter sheet

A modal bottom sheet, opened from the bar's chip and from Settings.

- **Rows**: name in the interface language (Arabic name always shown), and the style «مرتّل» /
  "Murattal". A check mark on the current reciter.
- **Download marker**: when the current surah is downloaded for a reciter, that row shows a
  "downloaded" icon.
- **Tap a row**: `setReciter(id)`, and the sheet closes.

## Ayah actions sheet (001 FR-020)

Add **«تشغيل من هذه الآية» / "Play from this ayah"** as the first action. It calls
`playFrom(ref)` and closes the sheet. The order is Play, Copy, Share, Bookmark.

## Index › Surahs

- The list renders immediately. Download marks appear when the background disk scan finishes; the
  scan never blocks the list (constitution, Principle III).
- Surahs downloaded (complete) for the **chosen reciter** show a small download-done icon after
  the ayah count (FR-032). Partial surahs show nothing.
- **Long-press, or the trailing "⋯" on each row**, opens a surah menu:
  - «تنزيل التلاوة ({size})» / "Download recitation ({size})" when not complete;
  - «إيقاف التنزيل» / "Stop download" while queued or downloading, with progress;
  - «حذف التنزيل» / "Delete download" when complete or partial.

  The size is `DownloadQueue.sizeOf`, formatted to one decimal place in MB, or in KB under 1 MB.
  Starting a download runs the preconditions in [audio-storage](./audio-storage.md#preconditions-checked-in-the-ui-before-enqueue).

The bar's error **Download** action opens the same menu item for the current surah.

## Settings › Recitations (new section)

| Row | Behaviour |
| --- | --- |
| **Reciter** «القارئ» | Shows the current name. Tap: reciter sheet. |
| **Downloads** «التنزيلات» | Shows the total storage used, e.g. «١٢٣٫٤ م.ب». Tap: the Downloads screen. |
| **Clear recent recitations** «مسح التلاوات المؤقتة» | Shows the cache size. Tap: a confirmation, then clear (FR-021). Disabled at 0. |

### Downloads screen

- **While scanning**: the screen renders on its first frame with skeleton rows for each reciter,
  and the total as «…», until the disk scan completes (constitution, Principle III).
- **Grouped by reciter**: a header with the reciter name, total size and a **Delete all** action
  (with confirmation). Then one row per surah that has any files.
- **Each row**: surah name and number, size, and state:
  - complete: a done icon;
  - downloading: a progress bar and percentage;
  - queued: «في الانتظار» / "Waiting";
  - stopped: «متوقف — استئناف» / "Stopped — Resume", with the reason when known (no connection, not
    enough storage).
- **Row actions**: Resume, Stop, Delete (swipe or "⋯"). Deleting updates the totals within 1 s
  (SC-012).
- **Empty state**: «لم تنزّل أي سورة بعد. نزّل سورة من فهرس السور.» / "No surahs downloaded yet.
  Download one from the Surahs index."

## About screen

Add an attribution row, as `docs/licences.md` requires once D4 is answered. The default wording
until then: «التلاوات: الشيخ محمود خليل الحصري والشيخ محمد صديق المنشاوي (مرتّل)، عن EveryAyah.com»
/ "Recitations: Sheikh Mahmoud Khalil Al-Husary and Sheikh Mohamed Siddiq El-Minshawi (Murattal),
via EveryAyah.com", with a link.

## Messages

| Key | Arabic | English |
| --- | --- | --- |
| `recitationOffline` | لا يوجد اتصال. نزّل السورة للاستماع دون إنترنت. | No connection. Download this surah to listen offline. |
| `recitationFetchFailed` | تعذّر تحميل الآية. | Couldn't load this ayah. |
| `retry` | إعادة المحاولة | Retry |
| `reciterNotDownloaded` | {name} غير منزّل لهذه السورة | {name} isn't downloaded for this surah |
| `recitationEnded` | انتهت التلاوة | Recitation finished |
| `backToRecitation` | العودة إلى التلاوة | Back to recitation |
| `downloadOnMobileData` | أنت على بيانات الجوال. تنزيل {size}؟ | You're on mobile data. Download {size}? |
| `notEnoughStorage` | المساحة غير كافية: تحتاج {size} | Not enough storage: {size} needed |
| `noInternet` | لا يوجد اتصال بالإنترنت | No internet connection |
