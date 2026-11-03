# Contract: Editor Page

**Address**: `https://get.mthani.app/editor/`. **Files**: `web/editor/index.html`, `editor.js`,
`editor.css`, plus the generated `quran.json`. Arabic, right to left.

## Layout

- **Narrow screens** (under 900 px): one column. The list, the group form, Publish, History and
  Editors are separate views, with a top bar.
- **Wide screens**: the list at the start side (right), the open view beside it.
- **Hash routing**: `#group-{id}`, `#new`, `#publish`, `#history`, `#editors`, so a link or a
  reload returns to the same view.

## Top bar

- «المتشابهات» as the title.
- The signed-in email.
- Buttons: «جديد», «نشر (n)» (n = unpublished changes, shown when n > 0), «السجل», and
  «المحررون» (owner only).
- «خروج» leads to Access's `/cdn-cgi/access/logout`.

## Group list

- **Search**: a box that matches an ayah reference (`2:35`, `٢:٣٥`, or a surah name with a
  number) or words in the note or the explanation, ignoring diacritics.
- **Filter**: «غير المنشور فقط».
- **Rows**: the references as «البقرة ٣٥ · الأعراف ١٩», the note, and a status chip: «جديدة»,
  «معدلة» or «محذوفة». Rows waiting for publishing are marked by the chip alone.

## Group form (`#group-{id}`, `#new`)

- **Ayat**: one chip per ayah, «البقرة ٣٥», with a remove button.
  - An «إضافة آية» field takes `2:35` or `٢:٣٥`.
  - The chosen ayah's Uthmani text is shown under its chip (FR-005).
  - A reference that does not exist shows «لا توجد آية ٢:٣٠٠ (سورة البقرة ٢٨٦ آية)» in place.
- **Note**: one line, labelled «ملاحظة (لا تظهر للقراء)».
- **Explanation**: a large text area, right to left. A blank line starts a new paragraph, the
  same as in the app.
- **Buttons**:
  - «حفظ»: disabled until something changes.
  - «حذف» and «تراجع عن الحذف».
  - «إلغاء التعديلات»: shown when there's a local unsaved copy.
- **Other groups**: when an ayah also belongs to other groups, a line under its chip links to
  them (Story 2 AS5).
- **Messages**:
  - Server problems appear next to the field they concern.
  - On `409`: «عدّل {email} هذه المجموعة بعد أن فتحتها» with «تحميل نسختهم» and «الإبقاء على
    نسختي في الصفحة». The second keeps the local text so it can be copied.
- **Local copy**: unsaved text is kept in `localStorage` under `mutashabihat-draft:{id}`, and
  offered back on return. It is cleared after a successful save.

## Publish (`#publish`)

- **Changes**: grouped as «ستُضاف», «ستُعدّل» and «ستُحذف». Each row shows the references, who
  changed it and when, and links to the group.
- **Problems**: if any group fails the checks, they are listed and «نشر» is disabled.
- **Publishing**: «نشر الآن» sends `expect` with the listed ids. On success it shows «نُشر
  الإصدار ١٣: أضيفت ٢ وعُدّلت ٥ وحذفت ١».
  - On `draftChanged` the list refreshes, with a note that someone saved meanwhile.

## History (`#history`)

- **Versions**: newest first. Each shows its number, date and time, who published it, the
  counts, and «مستعاد من الإصدار ٧» where it applies.
- **Opening a version**: shows its groups, read only.
- **«استعادة هذا الإصدار»**:
  - with no unpublished changes, it asks once for confirmation;
  - otherwise it warns that the unpublished changes will be lost, and sends
    `discardDraft: true` after confirmation.

## Editors (`#editors`, owner only)

- The list of emails with «إزالة», and an add field with «إضافة».
- A note: «يدخل المحرر بالبريد نفسه عبر رمز يصله بالبريد».

## First use

When `GET groups` returns no groups and no version, the owner sees «لا يوجد محتوى بعد» and
«استيراد المحتوى الحالي». The import fetches `/assets/assets/mutashabihat/mutashabihat.md` and
posts it to `import`. Editors who aren't the owner see «لم يُستورد المحتوى بعد».

## Not an editor

On `403 notAnEditor` the page shows «هذا البريد ({email}) ليس من المحررين. اطلب من صاحب
التطبيق إضافتك.» and «خروج».

## Accessibility and size

- Every control is reachable by keyboard and has a label. Focus is visible.
- Touch targets are at least 44 px. Text follows the browser's text size.
- No external scripts, styles or fonts. The page works under the site's existing CSP
  (`web/_headers`) with no inline scripts.
