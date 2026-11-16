# Contract: Group Khatma Screens, Links and Safety Flows

**Spec**: [../spec.md](../spec.md) Stories 5 to 7 | **API**: [group-api.md](./group-api.md) |
**Model**: [../data-model.md](../data-model.md) › 2 | **Research**: [R15 to R22](../research.md)

Release B. The screens below are added to the Khatma screen of
[khatma-ui-and-reminders.md](./khatma-ui-and-reminders.md).

## Screens

| Screen or sheet | Contents |
| --- | --- |
| **Khatma screen › Group khatmas** | A row for each group khatma the reader keeps: title, "{read} of {total} read", and the reader's own unread parts, each with Read. "Start a group khatma". "Open a link or code". Shown from the device's copies at once, then refreshed (FR-057). |
| **Terms** | Shown before the first start or the first take on this device or browser. Four short points: what others will see (the title, your name, your parts); offensive or abusive names and titles are not tolerated and are removed, and the device may be blocked; how to report; how to reach Mathani. "I agree" and "Cancel" (FR-059). |
| **Start sheet** | Title (60 characters). Your name (30, filled with the last name used). Division: 30 ajza' or 60 ahzab. Finish date, optional. Start. Needs a connection. |
| **After starting** | One line: "Anyone who has the link can see the names and take parts", then the share sheet (FR-045). |
| **Group khatma** | **Header**: title, finish date ("passed" after it), "{free} free · {taken} taken · {read} read", a progress bar, "Complete on {date}" when complete. **My parts**, first: each with its range, Read or Continue, Done, Give back, and "waiting to be sent" while a mark waits. **All parts**: number, name ("Juz 7"), range, and its state: Free with Take, a name, or a name and "read". A part of the reader's own is marked "you". **Actions**: Share, Refresh, Report, Leave. When offline: "Last updated {time}. It may be out of date". |
| **Name prompt** | Before the first take in a khatma, if no name is kept: "Your name will be seen by everyone who has the link", the field, Take (FR-049). |
| **Organiser's menu on a part** | Free it. Mark as read or not read. Give to a name (a field, the same checks). |
| **Organiser's menu on a participant** | Remove from this khatma, with a confirmation. |
| **Organiser's menu on the khatma** | Edit the title or the finish date. Delete, with a confirmation that names the title. |
| **Report** | "Report a name" (pick one) or "Report this khatma". One confirmation. Then "Report sent", and the name shows as "hidden" on this device, or the khatma leaves the list (FR-061). |
| **Open a link or code** | A field that takes a pasted link or a code. Open. |
| **Gone** | "This khatma no longer exists." One button removes it from the list. |
| **Blocked** | "This device cannot start or join group khatmas", with the contact address. |

The reader's own name is never shown as "hidden". Names and titles are shown as typed, isolated
from the direction of the text around them.

**All screens** follow the same rules as the rest of the feature: Arabic and English, both
directions, both themes, text scaling, sideways, 44 pt / 48 dp targets, semantic labels, feedback
within 100 ms. Every part row reads as one sentence to a screen reader: "Juz 7, Al-Ma'idah 82 to
Al-An'am 110, taken by Maryam".

## A group part in the Mushaf

A part the reader holds and has not read is a reading
([khatma-ui-and-reminders.md](./khatma-ui-and-reminders.md) › The reading screen and › The
place): Read opens its place, its end is marked, the header shows its pages left, and the Done
row names it ("Your part in «{title}» ends on this page"). It is marked only by Done, on the
reading screen or on the group khatma's screen (FR-052). A part's range is juz *n* or hizb *n*
in the app's own Mushaf data.

## Refreshing and waiting marks

| When | What the app does |
| --- | --- |
| The Khatma screen opens | One read for each kept khatma, with `If-None-Match` |
| A group khatma is on screen and the app is in the foreground | A read every 20 seconds, and on resume |
| After the reader's own action | The answer's snapshot replaces what is shown. No extra read |
| The app is in the background, or neither screen is open | No request, except to send a waiting mark |
| Done with a connection | The mark is sent. On failure it waits |
| Done without a connection | The part shows as read on this device, "waiting to be sent" |
| A mark waits | Tried again on resume, when either screen opens, after any successful call, and every 60 seconds in the foreground |
| The server answers `notYours` to a waiting mark | The mark is dropped. "This part is no longer yours" |
| `404 gone` | The Gone state |
| `403 blocked` | The Blocked state |
| A limit (`429`) | One line that says which limit, and no retry by itself |

## Opening a link

| Where | Contract |
| --- | --- |
| **Link** | `https://get.mthani.app/k/<code>`. The share text: "{title}: a group khatma in Mathani. Take your part: {link}", in the organiser's interface language. |
| **Code** | 16 characters, shown as `XXXX-XXXX-XXXX-XXXX`. Reading one ignores case, spaces and hyphens, and takes a whole link too. |
| **Browser** | The web app reads the code from its address after the first frame, opens the group khatma over the reader, and sets the address back to `/`. An unsupported browser gets the page of specs/008. |
| **Android** | An intent filter for `https://get.mthani.app/k/`, verified through `/.well-known/assetlinks.json` (package `com.mthani.app` and the SHA-256 of the Play signing key and the upload key). `MainActivity` reads the link from the intent it was opened with, and from a new intent. |
| **iPhone** | The Associated Domains entitlement `applinks:get.mthani.app`, verified through `/.well-known/apple-app-site-association` (app id `YJBH85NYZU.com.mthani.app`, paths `/k/*`). `SceneDelegate` reads the link when the scene connects and when it continues a browsing activity. |
| **To Dart** | The existing channel `app.mathani/device`: `takeLink` returns the link the app was opened with, once; a `link` event carries one that arrives while it runs. |
| **Flutter's own link handler** | Switched off in the Android manifest and in `Info.plist`, so a link is never pushed as a route name. |
| **In the app** | After the first frame: any open sheet is closed, the Khatma screen and the group khatma are pushed over the reader. During a memorization session the link waits until the session ends. |

## Dart interfaces (behavioural)

- **`KeyStore`** (conditional import): `read()`, `create()`, `delete()`. Phones: the platform's
  secure storage. Browsers: a `preferences` row. `create()` is called only by the first start,
  take or report.
- **`AppLinks`** (conditional import): `takeLink()` and a `links` stream. Phones: the device
  channel. Browsers: the page's address.
- **`GroupCode`** (plain Dart): `parse(text)` returns a code or null; `format(code)`;
  `linkOf(code)`.
- **`GroupClient`**: one method for each endpoint, returning a snapshot or a typed failure. It
  sends the key on writes, and on reads once a key exists. It takes the HTTP client, so tests
  pass a fake.
- **`GroupRepository`**: the two device tables: the kept khatmas with their snapshots, the
  places, the waiting marks.
- **`GroupController`** (`ChangeNotifier`, app-scoped, idle until the reader has a group khatma
  or opens a link): the list, one khatma's state, the actions, the timers of the table above,
  and the readings it gives to `KhatmaController`.

## User-visible states

Each state has one line of text and at most one action.

| State | Action |
| --- | --- |
| No connection, for an action that needs one | Retry |
| Last updated {time} | Refresh |
| Just taken by someone else | none: the list is already fresh |
| Waiting to be sent | none |
| This part is no longer yours | none |
| The name or title was refused: too long, a link, or a word that is not allowed | none: the field keeps the text |
| A limit was reached | none |
| This khatma no longer exists | Remove from the list |
| This device cannot start or join group khatmas | The contact address |
| An update is needed for this khatma | The store, or "open in the browser" |

## Wording (proposed; the owner sets the final text)

| Key | Arabic | English |
| --- | --- | --- |
| Section title | الختمات الجماعية | Group khatmas |
| Start | ابدأ ختمة جماعية | Start a group khatma |
| Open | افتح رابطا أو رمزا | Open a link or code |
| Take | خذ هذا الجزء | Take this part |
| Give back | أعِد الجزء | Give back |
| Done | أتممت الجزء | Done |
| Free, taken, read | متاح · محجوز · مقروء | Free · Taken · Read |
| Share text | «{title}»: ختمة جماعية في مثاني. خذ جزءك: {link} | {title}: a group khatma in Mathani. Take your part: {link} |
| Link warning | كل من لديه الرابط يرى الأسماء ويستطيع أخذ الأجزاء | Anyone who has the link can see the names and take parts |
| Name warning | سيرى اسمك كل من لديه الرابط | Your name will be seen by everyone who has the link |
| Report | بلّغ | Report |
| Leave | غادر الختمة | Leave the khatma |
| Gone | هذه الختمة لم تعد موجودة | This khatma no longer exists |
