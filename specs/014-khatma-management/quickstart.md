# Quickstart: Checking the Personal and Group Khatma

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Contracts**:
[contracts/](./contracts/)

A guide for checking that the feature works, on the reference phones (Galaxy A15, iPhone SE 2nd
generation) and in a browser. Part A needs no setup. Part B needs the owner's setup first.

## Automated checks

```powershell
flutter analyze
flutter test --exclude-tags golden,web
flutter test --tags golden                       # locally: the end-mark goldens
node --test tool/khatma/*.test.mjs               # release B: the functions and the Worker
cd android; ./gradlew :app:testDebugUnitTest     # the alarm store and receiver rules
```

What they must cover is listed in each contract under "What the tests must show", and in
[research R13](./research.md#r13-tests-for-release-a) and
[R25](./research.md#r25-tests-for-release-b).

---

## Part A: the personal khatma

### A1. Plan a khatma and read a wird (Story 1)

With the network off, on each phone:

1. Open Khatma from the reading toolbar. Expect one line and "Start a khatma".
2. Choose "a juz a day". Expect "30 days" and a finish date 29 days from today.
3. Enter 29 days. Expect "20 to 21 pages a day". Go back to "a juz a day" and start.
4. Expect the wird card: "1 of 30", Al-Fatiha 1 to Al-Baqarah 141, pages 1 to 21.
5. Tap Read. Expect page 1. Show the controls: the header ends with "21 pages left".
6. Turn to page 21. Expect the end mark at ayah 141 and, with the controls, the Done row.
7. Tap Done. Expect "Today's wird is done" with Undo, then in Khatma: 1 of 30 read.
8. Close and reopen the app. Expect the same state.
9. End the khatma. Start one from Juz 16. Expect 15 days.

### A2. The mark at the end of a wird (FR-010, FR-041)

Mark wirds 1 and 2 as read, so that wird 3 is current. It ends at Al 'Imran 92, the first ayah
on page 62.

1. On page 62: the ayah-end sign of ayah 92 is in the mark's colour, a small triangle sits in
   the margin on that line, and no word has moved. Compare with the same page after ending the
   khatma.
2. Repeat in the night theme, in the flowing layout, with the phone sideways, and with two
   facing pages (a foldable, or a wide browser window).
3. With VoiceOver and with TalkBack: the page says where today's wird ends.
4. Start a memorization session on that page: no mark and no Done row.

### A3. The place (Story 2)

Follow rows P1 to P10 of [contracts/khatma-ui-and-reminders.md](./contracts/khatma-ui-and-reminders.md)
› The place, by hand. After each, check the page that Continue opens.

### A4. Reading on, Undo, and setting the place (FR-016, FR-017)

1. From the wird's last page, turn forward. Expect the message with Undo, and the next wird in
   Khatma.
2. Tap Undo. Expect the wird unread and the place on its last page.
3. Long-press an ayah in Juz 10, "Set khatma place here". Expect a count of wirds, then Juz 10
   current and the nine before it read.
4. Set the place at an ayah in Juz 5. Expect Juz 5 current and the later ones unread.
5. Mark the current wird Done from the Khatma screen without opening the Mushaf.

### A5. The reminder (Story 3)

On each phone, with exact alarms allowed on Android:

1. Turn the reminder on. Expect the permission request now, not before. Pick a time two minutes
   ahead, lock the phone. Expect one notification with the phone's usual sound, naming the wird.
2. Tap it. Expect the Mushaf at the khatma place.
3. Next day (move the phone's date forward), read the wird before the time. Expect none.
4. Restart the phone, do not open the app, and move the date forward a day at a time for seven
   days. Expect one reminder each day.
5. Open a page of the current wird before the time and stay on it past the time. Expect none
   while it is on screen.
6. Pause the khatma. Expect none. Resume. Expect them back.
7. Refuse notifications on a fresh install. Expect the blocked line, with the setting kept.
8. **Prayer alerts**: with prayer alerts on, check they still fire, and that at least seven
   days of them are pending (specs/009 quickstart).

Record for SC-006: 20 reminders on each phone, each within 5 minutes of the time.

### A6. Progress and changes (Story 4)

1. Start a 30-day khatma dated five days back (set the phone's date back, start it, restore the
   date). Read three wirds on earlier days. Expect "3 of 30" and an expected finish two days
   after the planned one.
2. Read two wirds in one day. Expect the expected finish a day earlier.
3. Change plan, pick the first planned date. Expect the new daily amount before confirming, and
   the read wirds kept.
4. Pause for three days, resume. Expect the planned finish three days later.
5. Open "All wirds", scroll to the end, tap one. Expect its first page, and the place unchanged.

### A7. Completion and the record (Story 8)

1. Start a one-day khatma, tap Done. Expect the completion screen with dates and "1 day".
2. Undo. Expect the khatma back. Tap Done again.
3. Expect the record: one entry, "1 khatma finished".
4. "Start a new khatma". Expect the one-day plan selected and the reminder as it was.
5. Delete the entry. Restart the app. Expect it gone.

### A8. The tour, the web, and what must not change

1. Settings › see the tour again. Expect one stop on the Khatma button (FR-043).
2. In a supported browser at phone width: A1, A3, A4, A6 and A7 pass. The Reminder section is
   one line about the phone apps (FR-042).
3. Bookmarks and the reading position are unchanged after every step above (FR-013, FR-032).

### A9. Performance, size and privacy (SC-008, SC-009, SC-012)

1. Cold start on both phones, five runs each, with a khatma in progress: at or under 2 seconds.
2. Page turns across page 62 with the mark on screen, in profile mode: no frame over 16 ms
   beyond those of a page without the mark.
3. A page-a-day khatma: "All wirds" scrolls its 604 rows at 60 fps.
4. An iPhone SE (1st generation) simulator and a 320 dp Android emulator: the seven toolbar
   buttons show without overflow, and scroll sideways where they do not fit.
5. `dart run tool/size_check.dart` on both platforms: under 1 MB of growth.
6. Watch the network through A1 to A7. Expect no request from this feature.
7. Each of A1 to A7 once more with VoiceOver, with TalkBack, and in the other language.

---

## Part B: the group khatma

### Setup (owner and developer, once)

1. **Databases**:
   ```powershell
   npx wrangler@4 d1 create mthani-khatma
   npx wrangler@4 d1 create mthani-khatma-preview
   npx wrangler@4 d1 execute mthani-khatma --remote --file functions/_lib/khatma-schema.sql
   npx wrangler@4 d1 execute mthani-khatma-preview --remote --file functions/_lib/khatma-schema.sql
   ```
   Put both ids in `wrangler.toml` (`KHATMA_DB`, and the preview override).
2. **The Worker**: in the Cloudflare dashboard, enable email sending for mthani.app. Then
   `npx wrangler@4 deploy` in `workers/khatma-ops/`. Check: insert a row into `reports` in the
   preview database and expect an email within two minutes. If sending cannot be enabled, set
   the webhook instead ([research R14](./research.md#r14-where-the-group-khatma-lives)).
3. **Rate limiting**: one rule in the dashboard: path starts with `/api/khatma`, more than 100
   requests in 10 seconds from one IP, block for 10 seconds.
4. **Links**:
   - Apple developer account: enable Associated Domains for `com.mthani.app`, then renew the
     profiles (docs/release.md › iOS signing).
   - Play Console › App integrity: copy the SHA-256 of the app signing key and of the upload
     key into `web/.well-known/assetlinks.json`.
   - After a web deploy, check both files:
     ```powershell
     curl.exe -sI https://get.mthani.app/.well-known/apple-app-site-association
     curl.exe -sI https://get.mthani.app/.well-known/assetlinks.json
     ```
     Expect `200` and `application/json` for each. If Pages does not serve them, add the two
     functions ([research R16](./research.md#r16-the-link-the-code-and-opening-it)).
5. **Contact address**: choose it. It goes into About and the terms.
6. **Owner's page**: open `https://get.mthani.app/editor/khatma.html`. Expect the Access
   sign-in, then an empty list.

Test on a preview deployment (`node --use-system-ca tool/web_deploy.mjs --dry-run`) with phone
builds pointed at it by `--dart-define=MATHANI_API_BASE=<preview address>`. Links open the app
only for get.mthani.app, so B3 steps 1 and 2 are checked after the production deploy; before it,
use "Open a link or code".

### B1. Start and share (Story 5)

1. Khatma › Start a group khatma. Expect the terms first. Agree.
2. Title "ختمة العائلة", your name, thirty ajza'. Expect 30 free parts, the line about the
   link, and the share sheet with the text and the link.
3. Start another with sixty ahzab. Expect 60 parts.
4. With the network off: Start says a connection is needed.

### B2. Open the link (FR-046)

1. Android with Mathani: tap the link in a chat app. Expect the app, on the group khatma.
2. iPhone with Mathani: the same. Repeat both with the app closed, and with a recitation
   playing in the background.
3. A phone without Mathani: expect the browser, on the group khatma, with nothing to install.
4. In the app: Khatma › Open a link or code. Paste the link, then the code with and without
   hyphens. Expect the same khatma each time.
5. An old or unsupported browser: expect the unsupported-browser page.

### B3. Take, read and see each other (Story 5)

With three devices on the same khatma:

1. On device 2, take Juz 7. Expect the name prompt with its warning, then "Juz 7" under the
   name on all three within 30 seconds, untouched.
2. On devices 2 and 3, tap Take on Juz 8 at the same moment. Expect one holder, and "just
   taken" on the other.
3. On device 2: Read. Expect page 121, and the end mark at Al-An'am 110 on page 141. Turn past
   page 141. Expect the part still not read. Tap Done. Expect "read" on all three.
4. Undo the mark, give the part back. Expect it free on all three.
5. Take every part between the three devices and mark them. Expect "Complete" with the date on
   all three.
6. Leave from device 3. Expect its name gone, its unread parts free, its read parts read with
   no name.

Record for SC-016: 100 changes, each seen on another device within 30 seconds in at least 95.

### B4. Without a connection (FR-053, FR-055)

1. Network off on device 2. Open the khatma. Expect the last state and "may be out of date".
2. Tap Done on a held part. Expect "read" here and "waiting to be sent".
3. Tap Take on a free part. Expect "a connection is needed".
4. Network on. Expect the mark on the other devices within a minute.
5. Repeat 2, and free the part from the organiser's device before reconnecting. Expect "This
   part is no longer yours".

Record for SC-017: 20 marks made offline, all 20 arriving, none twice.

### B5. Safety (Story 6)

1. A fresh install: starting or taking shows the terms first. Cancel leaves nothing saved.
2. Try a name with an offensive word in Arabic and in English, a name with a link, and a
   61-character title. Expect each refused with its reason.
3. From device 3, report device 2's name. Expect it hidden on device 3 at once, and an email to
   the owner within five minutes.
4. On the owner's page: remove the name and block. Expect the name gone on every device, and
   device 2 refused when it starts or takes.
5. As organiser: free a taken part; remove a participant, who then cannot take a part in this
   khatma; delete the khatma. Expect "no longer exists" on the other devices and at the link.
6. From a device that is not the organiser: no organiser action is offered.
7. About and the terms show the contact address.
8. In the preview database, set a khatma's `completed_at` 31 days back and another's
   `changed_at` 91 days back. Expect `404` from the API at once, and the rows gone after the
   daily job.

### B6. For people who do not use the link (Story 7)

1. As organiser, give two free parts to typed names. Expect both names on every device.
2. Mark one as read, then not read. Mark a participant's part as read.
3. Change the title and the finish date. Expect them on every device.

### B7. The reminder and the reading screen with a group part

1. With the reminder on, no personal khatma, and one unread part: expect a reminder that names
   the part and the khatma. Tap it: the Mushaf opens at the part's place.
2. With a personal wird and a part both waiting: expect one reminder naming both. Tap it: the
   Khatma screen opens.
3. A personal wird and a part that end on the same page: two Done rows, each named.

### B8. Privacy, scale and the stores (SC-012, SC-018 to SC-022)

1. A reader who never opens a group khatma: watch the network for a session. Expect no request
   to `/api/khatma`.
2. After B3 step 6 and B5 step 5, search the database for the names used. Expect none.
3. Fill a khatma of 60 parts with 60 participants (a script against the preview API). Every
   action on a phone gives feedback within 100 ms and finishes within 3 seconds.
4. `docs/store/privacy.md`, both listings and the published policy describe the group khatma.
   The review notes carry a link reviewers can open.
5. Each of B1 to B6 once with VoiceOver, with TalkBack, and in the other language.
