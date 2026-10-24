# Feature Specification: All Available Reciters and Memorization Mode

**Feature Branch**: `006-reciters-memorization`

**Created**: 2026-10-24

**Status**: Draft

**Input**: User description: "- I want to add recitations for all available reciters on everyayah
- Add a memorization option, it should listen to the user from the mic and reveal ayah by ayah in
case the user pronounced the ayah correctly. The page should have only ayah numbers and the text
reveals as the user goes. After the voice session ends, the app should give the user a score for
his/her performance."

**Scope of this spec**: Two additions to the recitations of
[004-ayah-recitations](../004-ayah-recitations/spec.md).

1. **All reciters**: feature 004 offers two reciters from EveryAyah (Al-Husary and El-Minshawi,
   Murattal). This feature offers every complete Quran recitation on QUL (Quranic Universal
   Library, qul.tarteel.ai) or EveryAyah that can be followed ayah by ayah and matches the Mushaf
   in the app (narration of Hafs 'an 'Asim). Playing, following, background
   playback and per-surah downloads work for each of them exactly as in feature 004.
2. **Memorization mode** (وضع الحفظ): the reader recites from memory into the microphone. The page
   shows only the ayah numbers. Each ayah's text appears once the reader has recited it correctly.
   When the session ends, the reader gets a score and sees where they made mistakes.

## Clarifications

### Session 2026-10-24

- Q: What does a memorization session cover? → A: A range of ayat the reader chooses (surah, from
  ayah, to ayah), with the ayat of the current page chosen by default (FR-009).
- Q: Where is the reader's voice processed? → A: On the device only. The voice never leaves the
  phone, and memorization works with no connection (FR-019).
- Q: After a mistake, does the reader recite the ayah again from its first word or carry on from
  the word they got wrong? → A: Carry on from the wrong word; the words already recited correctly
  are kept (FR-015).
- Q: Does "all reciters on EveryAyah" include other narrations (Warsh) or translations? → A: No,
  Hafs recitations only, in every style (Murattal, Mujawwad, teaching) (FR-001, FR-002).
- Q: When stuck, is the only help revealing the whole ayah, or also a next-word hint? → A: Both.
  "Next word" shows one word at a time and the ayah earns a quarter credit; "Show this ayah"
  reveals the rest and earns none (FR-016, FR-024).
- Q: How is a mistake signalled? → A: On screen always, plus a Settings choice of vibration, sound
  or neither; vibration by default (FR-015).
- Q (owner, at planning): Which library do the recitations come from? → A: QUL's recitations where
  they can be streamed, because QUL lists more recitations than EveryAyah. EveryAyah supplies the
  reciters QUL lacks. Where both have the same recording, the copy with the lower data use is
  played (FR-001, plan research R0).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose from every available reciter (Priority: P1)

A reader wants to listen to their favourite qari, such as Abdul Basit, Mishary Alafasy, Saad
Al-Ghamdi or Maher Al-Muaiqly, not only Al-Husary or El-Minshawi. They open the reciter list, find
the reciter by name, and pick them. From then on every recitation uses that reciter, with
following, background playback and downloads exactly as in feature 004.

**Why this priority**: It is the smaller of the two requests and builds on what readers already
use. It is useful on its own, and the reciter list must handle dozens of entries before anything
else depends on it.

**Independent Test**: Open the reciter list, search for "Alafasy" in English and «العفاسي» in
Arabic, pick Mishary Alafasy and play page 50 across the page break. Download Al-Mulk for him and
play it offline. Repeat with a reciter whose recordings use a teaching style (with repetition),
with a Mujawwad recording, and with a reciter recorded one surah per file (for example Bandar
Baleela), checking that the highlight still moves ayah by ayah.

**Acceptance Scenarios**:

1. **Given** the reciter list opened from the player or Settings, **When** the reader views it,
   **Then** they see every reciter offered, each with their name in the interface language, the
   style of the recitation (Murattal, Mujawwad or teaching), and the chosen reciter marked.
2. **Given** the reciter list, **When** the reader types part of a name in Arabic or English,
   **Then** the list shows only matching reciters, within 100 ms of each keystroke.
3. **Given** a reciter with more than one recording style (for example El-Minshawi Murattal and
   Mujawwad), **When** the reader views the list, **Then** each style is a separate entry and
   clearly labelled.
4. **Given** the reader picks any reciter, **When** they play, **Then** every behaviour of feature
   004 holds: ayah-by-ayah order, basmala, highlight and page turns, lock-screen controls,
   downloads and offline playback.
5. **Given** a reader who chose Al-Husary or El-Minshawi in an earlier version, **When** they
   update, **Then** their choice and their downloads are kept.

---

### User Story 2 - Recite from memory and see each ayah appear (Priority: P1)

A reader memorising the Quran wants to test themselves. They open memorization mode from the
reading screen, choose what to recite, and allow the microphone. The page appears with its layout
kept but the text hidden: only the ayah numbers are shown, in their places. The reader recites.
Each time they finish an ayah correctly, its text appears and the next ayah becomes the one
expected. If they make a mistake, the app signals it without showing the text, and they carry on
from the word they got wrong, as a teacher would correct them. If they are stuck, they can ask for
the next word as a hint, or reveal the whole ayah. When the last ayah is revealed or the reader
ends the session, the session ends.

**Why this priority**: It is the new capability the request is about, and the score (Story 3) is
built on it.

**Independent Test**: With the network turned off, start memorization on Al-Fatiha 1–7. Recite it
correctly: each ayah appears after it is recited and in order. Start again on Al-Ikhlas, skip a
word in ayah 2: the app signals a mistake, ayah 2 stays hidden; recite from the skipped word to the
end and it appears. In ayah 3 ask for the next word: only that word appears; finish the ayah and it
appears in full. Then deny the microphone and check the message.

**Acceptance Scenarios**:

1. **Given** the reading screen, **When** the reader opens memorization mode, **Then** they choose
   the ayat to recite as a surah with a first and last ayah, with the ayat of the current page
   chosen by default, and can start with one tap.
2. **Given** the microphone permission was never asked, **When** the reader starts a session for
   the first time, **Then** the app explains why it needs the microphone before the system asks.
3. **Given** a session has started, **When** the page is shown, **Then** it keeps the layout of the
   reader's chosen lettering, with the text of the ayat to recite hidden and each ayah number
   visible in its place. Surah headers and the basmala lines stay visible.
4. **Given** the session is listening, **When** the reader recites the expected ayah correctly,
   **Then** its text appears within 1 second of the reader finishing it, and the next ayah becomes
   the expected one.
5. **Given** the reader recites a wrong word, skips or adds a word, **When** the app detects it,
   **Then** the expected ayah is marked as having a mistake (without showing any of its text), the
   phone vibrates or plays a short sound as set in Settings, and the app listens again from the word the reader got wrong, keeping the words before it. When the
   reader then completes the ayah from that word, it appears.
6. **Given** the reader is stuck, **When** they choose "Next word", **Then** only the next word of
   the expected ayah appears in its place, marked as a hint, and the app listens from the word
   after it. The reader can ask again for each following word.
7. **Given** the reader is stuck, **When** they choose "Show this ayah", **Then** the rest of its
   text appears marked as revealed, and the next ayah becomes the expected one.
8. **Given** the ayat reach the end of the page, **When** the next ayah to recite is on the
   following page, **Then** the Mushaf turns to that page with its text hidden.
9. **Given** a session is listening, **When** the reader taps pause or end, **Then** listening stops
   within 100 ms; pause can be resumed, end goes to the result (Story 3).
10. **Given** a session is listening, **When** the screen shows it, **Then** a clear indicator shows
   that the microphone is on, at all times.

---

### User Story 3 - Get a score for my session (Priority: P2)

When the session ends, the reader sees how well they did: a score out of 100, how many ayat they
recited with no mistake, how many after correcting a mistake, how many with a hint, and how many
they had to reveal. They can open the session's ayat with their mistakes and hints marked, to see
which words they missed or got wrong, and start the same session again with one tap.

**Why this priority**: The request names the score explicitly, and it turns the session into
feedback. It needs Story 2 to exist.

**Independent Test**: Recite Al-Mulk 1–10 with ayat 1–4 correct, one mistake then a correction in
ayah 5, one "Next word" hint in ayah 6, ayah 7 revealed, and end the session after ayah 8 (correct).
The score is (5 × 1 + 0.5 + 0.25 + 0) ÷ 8 × 100 ≈ 72. Check the score, the counts and the words
marked in ayat 5, 6 and 7 against the scoring rule of FR-024.

**Acceptance Scenarios**:

1. **Given** the reader ends the session or reveals its last ayah, **When** the result appears,
   **Then** it shows the score out of 100, the count of ayat with no mistake, corrected, hinted,
   revealed, and not reached (including an ayah left unfinished), all within 1 second.
2. **Given** the result, **When** the reader opens the review, **Then** every ayah of the session is
   shown in full, with the words they missed, said wrongly or added marked, the words given as
   hints marked, and the revealed ayat marked.
3. **Given** the result, **When** the reader taps "Try again", **Then** a new session starts on the
   same ayat with the text hidden.
4. **Given** the result, **When** the reader closes it, **Then** they return to the reading screen at
   the page where the session ended, in normal reading.

---

### Edge Cases

**Reciters**

- **A reciter has missing or broken recordings**: they are not offered (feature 004, FR-002).
  Recordings in narrations other than Hafs and translation recordings are not offered.
- **The same reciter at several quality levels**: offered once per recording style; the plan picks
  the quality.
- **Teaching-style recordings** (an ayah recited with repetitions for learners): played ayah by
  ayah like any other; the label says it is a teaching recording.
- **Reciter whose recording has no separate basmala**: the basmala is still heard before ayah 1
  (004 FR-008), as part of ayah 1's recording, with the highlight on ayah 1 (FR-005). A reciter
  whose surah recordings lack the basmala is not offered.
- **Downloads for many reciters**: Settings lists downloads per reciter as in feature 004; the
  total storage covers all reciters.

**Memorization**

- **Microphone denied**: memorization does not start; the app says why it needs the microphone and
  how to allow it in the system settings. Reading and listening are not affected.
- **Device cannot recognise Quran recitation** (unsupported device, OS version or missing
  language support): memorization is shown as unavailable with the reason; nothing else changes.
- **No connection**: memorization works fully, as the voice is processed on the device (FR-019).
- **First use needs a one-time download of the recitation recognition model** (about 61.5 MB; see
  plan research R9): the app shows its size, asks first on mobile data, and starts the session
  once it is saved. After that, memorization needs no connection. The voice is never sent online
  instead.
- **Range spans several pages**: the Mushaf turns as the reader goes (FR-018). A range that starts
  or ends mid-page hides only the ayat in the range; the rest of the page stays visible.
- **Range chosen from a long-press**: "Memorize from this ayah" starts the range at that ayah and
  ends it at the last ayah of that page by default; the reader can change both.
- **Reader starts with isti'adha or basmala** (أعوذ بالله..., بسم الله...) before an ayah that does
  not include it: it is ignored, not counted as a mistake.
- **Reader repeats a word or goes back to restart a phrase**, as reciters do after a pause: not a
  mistake, as long as the ayah is completed in order.
- **Reader pauses inside an ayah** (to breathe or at a waqf sign): not a mistake; the app keeps
  listening for the rest of the ayah.
- **Reader recites a different ayah** (for example the next one, skipping the expected one): the
  expected ayah is marked as a mistake and stays hidden; nothing ahead is revealed.
- **Long ayat** (for example Al-Baqarah 282): the ayah appears only once fully recited; the reader
  is told of a mistake as soon as it is detected, not only at the end, and carries on from that
  word rather than from the start.
- **Reader goes back further than the wrong word**, or restarts the ayah after a mistake: accepted,
  as long as they then recite from the wrong word on correctly.
- **Mistake sound and the microphone**: the sound is short and quiet and MUST NOT be taken as the
  reader's recitation. With the phone on silent, the sound follows the platform's convention and
  the on-screen mark still shows.
- **Phone cannot vibrate** (or vibration is turned off in the system): the on-screen mark still
  shows; the app does not fall back to sound unless the reader chose sound.
- **Several mistakes in one ayah**: each is signalled and the reader carries on from each wrong
  word; the ayah counts once, as corrected.
- **Mistakes and hints in the same ayah**: the ayah counts by its weakest outcome: revealed, then
  hinted, then corrected (FR-024).
- **"Next word" on the last word of an ayah**: the word appears and the ayah is complete; it counts
  as hinted, not revealed.
- **Silence**: after 30 seconds with no speech, the session pauses itself and says so.
- **Noise, other voices, or a recitation playing nearby**: the app must not reveal an ayah the
  reader did not recite. Recitation playback of feature 004 stops when a session starts.
- **Phone call, alarm, or the app goes to the background**: the session pauses and the microphone
  turns off; the reader resumes it when they come back.
- **App closed during a session**: the session is lost; on the next launch the reader is on the
  last page read, as in feature 001.
- **Screen reader on**: the hidden page, mistake signals, revealed ayat and the result are
  announced in the interface language.

## Requirements *(mandatory)*

### Functional Requirements

**All reciters**

- **FR-001**: The app MUST offer every reciter on QUL or EveryAyah that has a complete recitation
  of the Quran in the narration of Hafs 'an 'Asim that can be played and followed ayah by ayah:
  either one recording per ayah, or one recording per surah with the start time of every ayah.
  A recitation available from both MUST be offered once. Each recording style of a reciter
  (Murattal, Mujawwad, teaching) MUST be a separate entry.
- **FR-002**: Recordings in other narrations (such as Warsh), translations, compilations (such as
  Taraweeh recordings), surah recordings without ayah timings, and recordings with any ayah or
  surah missing MUST NOT be offered (feature 004, FR-002).
- **FR-003**: Each reciter entry MUST show the reciter's name in Arabic and, in the English
  interface, in English, along with the recording style.
- **FR-004**: The reciter list MUST be searchable by part of a name in Arabic (ignoring diacritics
  and letter forms such as أ/ا and ة/ه) or English, and MUST stay smooth to scroll with every
  reciter listed.
- **FR-005**: Every feature 004 requirement on playback, following, background playback, network,
  privacy and downloads (FR-006 to FR-034) MUST hold for every reciter offered. For reciters
  recorded one surah per file, the reciter's basmala is heard at the start of ayah 1 and ayah 1 is
  highlighted from that moment; the basmala line is not highlighted separately. This is the only
  exception to feature 004 for these reciters.
- **FR-006**: The reader's chosen reciter and existing downloads MUST be kept when updating. The
  default for a new install stays Al-Husary.
- **FR-007**: The About screen MUST credit QUL, EveryAyah and the reciters as each source's terms
  require (feature 004, FR-024).

**Starting a memorization session**

- **FR-008**: Users MUST be able to start memorization mode from the reading screen and from the
  long-press ayah actions (feature 001, FR-020) as "Memorize from this ayah".
- **FR-009**: A session MUST cover a range of ayat within one surah, chosen as the surah, the first
  ayah and the last ayah. From the reading screen the default is the ayat of the current page in
  the surah where the page starts; from a long-press it is that ayah to the last ayah of its page.
  The reader MUST be able to change the range before starting, and MUST NOT be able to choose a
  last ayah before the first.
- **FR-010**: The app MUST ask for the microphone only when the reader starts their first session,
  after explaining why, and MUST degrade gracefully when it is denied (constitution, Platform &
  Store Requirements).
- **FR-011**: Starting a session MUST stop any recitation playing (feature 004).

**During a session**

- **FR-012**: The page MUST keep the layout of the reader's chosen lettering and layout, with the
  text of the session's unrevealed ayat hidden and each ayah number visible in its place. Text
  outside the session, surah headers and basmala lines MUST stay visible.
- **FR-013**: The app MUST listen to the reader and compare what they recite with the expected
  ayah, word by word, in order.
- **FR-014**: An ayah MUST be revealed only when every one of its words was recited in order, with
  no missing, wrong or added words. Diacritics and tajweed rules are not judged (see Assumptions).
  Repeating words, restarting a phrase, pausing, and an opening isti'adha or basmala MUST NOT count
  as mistakes.
- **FR-015**: When a mistake is detected, the app MUST signal it at once without showing any of the
  ayah's text: always by marking the ayah number on screen, and also by a short vibration, a short
  sound, or neither, as the reader chooses in Settings (vibration by default; the choice persists
  across restarts). It MUST then keep the words recited correctly before the mistake and listen
  again from the wrong word. The ayah is revealed when the reader completes it from that word. Going back further, or
  restarting the ayah, MUST also be accepted. An ayah with one or more mistakes counts as corrected
  (FR-024).
- **FR-016**: Users MUST be able to ask for the next word of the expected ayah at any time ("Next
  word"), as many times as they need. Only that word is shown, marked as a hint, and the app
  listens from the word after it. The ayah then counts as hinted. Users MUST also be able to reveal
  the rest of the expected ayah at any time ("Show this ayah"); it then counts as revealed.
- **FR-017**: Ayat and words MUST be revealed only in order; the app MUST NEVER reveal an ayah or
  word the reader did not recite or ask for.
- **FR-018**: When the next ayah to recite is on another page, the Mushaf MUST turn to it; the
  flowing layout MUST keep the expected ayah in view.
- **FR-019**: The reader's voice MUST be processed on the device only. It MUST NOT be sent over the
  network, and it MUST NOT be stored or kept after the session. Memorization MUST work with no
  connection.
- **FR-020**: The microphone MUST be on only while a session is listening. A visible indicator MUST
  show when it is on. Pausing, ending, a call, or leaving the app MUST turn it off at once.
- **FR-021**: Pause, resume and end MUST respond within 100 ms (constitution, Principle III). After
  30 seconds without speech the session MUST pause itself.
- **FR-022**: A session MUST end when its last ayah is revealed or the reader ends it.

**Score and review**

- **FR-023**: When a session ends, the app MUST show a result with the score, the number of ayat
  recited with no mistake, corrected, hinted, revealed, and not reached.
- **FR-024**: The score MUST be out of 100, rounded to the nearest whole number, and computed over
  the ayat the reader reached: an ayah recited with no mistake earns 1, a corrected ayah 0.5, a
  hinted ayah 0.25, a revealed ayah 0. An ayah counts by its weakest outcome (revealed, then
  hinted, then corrected). Score = sum of credits ÷ ayat reached × 100. The result MUST also show
  how many of the session's ayat were reached. The ayah being recited when the reader ends the
  session counts as not reached, and is shown as not finished in the review.
- **FR-025**: The result MUST offer a review of the session's ayat in full, with words missed, said
  wrongly or added marked, words given as hints marked, and revealed ayat marked; and a "Try
  again" action that restarts the same session.
- **FR-026**: The result MUST NOT be kept after the reader closes it (see Out of Scope).

**Platform**

- **FR-027**: All new screens and controls MUST meet the constitution's mobile requirements: phone
  portrait layout, safe areas, minimum touch targets, dark mode, system font scaling and
  screen-reader labels in Arabic and English.
- **FR-028**: The feature MUST work on iOS 15.0+ and Android 7.0 (API 24)+, as features 001 and
  004. Where a device cannot support memorization, the app MUST say so and the rest of the app MUST
  work unchanged; the plan names the devices affected and documents any gap between platforms
  (constitution, Principle I).
- **FR-029**: The store privacy answers (App Privacy details, Data safety form) and the microphone
  permission text MUST be updated before release. They state that the microphone is used only
  during a memorization session and that no audio is collected or leaves the device.

### Key Entities

- **Reciter** (from feature 004): gains every followable Hafs recitation on QUL or EveryAyah; each
  entry is one reciter in one recording style (Murattal, Mujawwad, teaching), with its source.
- **Memorization Session**: what the reader is reciting: its ayat, the expected ayah, each ayah's
  state (hidden, no mistake, corrected, hinted, revealed, not reached), for the expected ayah the
  words recited or hinted so far, and whether it is listening or paused. Exists only while open.
- **Ayah Mistake**: a word of the expected ayah that the reader missed, said wrongly, or added a
  word before, recorded with its position for the review (FR-025). The audio itself is never
  kept.
- **Word Hint**: a word of the expected ayah shown on request ("Next word"), recorded with its
  position for the review.
- **Reader Preferences** (from features 001 and 004): gains the mistake signal (vibration, sound
  or none; vibration by default).
- **Session Result**: score, the counts of FR-023 and the per-ayah review; shown once at the end.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An automated check confirms that every reciter offered has a recording of all 6,236
  ayat, and either a separate basmala recording or, for reciters recorded one surah per file, the
  basmala at the start of ayah 1 (confirmed by listening, quickstart Q-7). No recording in another
  narration or a translation is offered.
- **SC-002**: The reciter list with every reciter scrolls at 60 fps and filters within 100 ms of
  each keystroke on the reference mid-range phone.
- **SC-003**: For 5 reciters picked at random, a surah of at least 100 ayat plays with 0 skipped or
  repeated ayat, streaming and downloaded.
- **SC-004**: In a test set of correct recitations by at least 10 readers (men and women, of
  different ages) covering at least 200 ayat, at least 95% of the ayat are revealed with no mistake
  wrongly signalled.
- **SC-005**: In a test set of recitations with one deliberate mistake per ayah (a word missed,
  swapped or added) over at least 200 ayat, the mistake is detected and the ayah stays hidden in at
  least 95% of cases.
- **SC-006**: 0 ayat are revealed that the reader did not recite or reveal, including with another
  recitation playing nearby, across all test sessions.
- **SC-007**: A correctly recited ayah appears within 1 second of the reader finishing it in 95% of
  cases.
- **SC-008**: The result appears within 1 second of the session ending, and its score matches the
  rule of FR-024 in 100% of test sessions.
- **SC-009**: In a test with at least 10 readers who memorise the Quran, at least 9 can start a
  session on ayat of their choice, finish it, and read their score on their first try, with no
  help.
- **SC-010**: Scrolling and page turns stay at 60 fps during a session (constitution, Principle
  III). Store download growth is measured on each platform, and any growth over 1 MB is reported
  with its cause and approved in review (constitution, Principle IV).

## Assumptions

- "All available reciters" means every complete Arabic recitation in the narration of Hafs 'an
  'Asim, the narration of the Mushaf in the app, that QUL or EveryAyah publishes in a form the app
  can follow ayah by ayah. Warsh and other narrations would not match the text shown, and
  translation recordings are not recitations; neither is offered. If a reciter exists at several
  quality levels or in both libraries, the plan picks one per style.
- The list of reciters ships with the app release; reciters added to QUL or EveryAyah later come
  in later releases.
- Permission to use the recordings must be extended to every reciter offered: dependency D4
  (Quran.com Foundation, for EveryAyah and quranicaudio) and D2 (QUL / Tarteel, for QUL's timings
  and Tarteel-hosted audio) in `docs/licences.md`. Both requests are updated before release.
- "Pronounced correctly" means the words of the ayah, in order, with no missing, wrong or added
  words. Judging harakat (vowel marks) and tajweed rules (madd lengths, ghunnah, makharij) is not in
  this release: speech recognition cannot judge them reliably, and a strict judge that is often
  wrong would discourage readers.
- The ayah is the unit revealed, as the request says: words the reader recites are not shown one
  by one. The only words shown before an ayah is complete are those the reader asks for as hints.
- Scoring gives half credit for a corrected ayah and a quarter for a hinted one, so the score
  rewards accuracy first, then self-correction, then recall with a prompt. Ayat not reached when
  the reader ends early do not lower the score; the result shows how many were reached.
- Memorization uses the reader's chosen layout and lettering (features 001 and 002).
- The session does not continue in the background: the microphone turns off when the app leaves
  the foreground (constitution, Principle IV; privacy).
- The reader's voice is used only to compare it with the ayah being recited, on the device; it is
  never stored, sent anywhere, or used to identify the reader.
- On-device recognition of Quran recitation may be less accurate than online services, and may
  not be available on older devices. The plan tests it against SC-004 to SC-006 on the reference
  devices of both platforms before committing to it; if the targets cannot be met on the device,
  that is reported back to the owner rather than moving the voice online.
- The range is limited to one surah; a reader revising across surahs runs one session per surah.

## Out of Scope

- A history of past sessions, progress over time, streaks or memorisation plans.
- Judging tajweed or harakat, and showing each word as it is recited.
- Playing the reciter's version of an ayah after a mistake (the reader can use normal playback).
- Recitations and memorization in narrations other than Hafs, such as Warsh, until the app can
  show that narration's Mushaf.
- Repeating an ayah or a range in playback, playback speed and a sleep timer (as in feature 004).
- Reciters from sources other than QUL and EveryAyah, and translation recordings.
- Downloading a whole reciter or juz in one action (as in feature 004).
