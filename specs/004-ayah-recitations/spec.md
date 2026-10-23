# Feature Specification: Ayah-by-Ayah Recitations

**Feature Branch**: `004-ayah-recitations`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "I want to start introducing voice recitations that will play ayah by
ayah. Start small with one or two reciters (Hosary, Minshawy) and then we can add up"

**Scope of this spec**: The first recitations in Mathani. This is the next feature named in
[001-quran-mushaf-reader](../001-quran-mushaf-reader/spec.md) *Out of Scope* item 1
("Recitations with ayah sync"). The reader listens to the Quran one ayah after another, by Sheikh
Mahmoud Khalil Al-Husary (محمود خليل الحصري) or Sheikh Mohamed Siddiq El-Minshawi (محمد صديق
المنشاوي). The ayah being recited is highlighted in the Mushaf, which follows the recitation.
More reciters come in later releases.

## Clarifications

### Session 2026-10-24

- Q: Which recordings: Murattal, Mujawwad, or both? → A: Murattal (المرتل) for both reciters
  (FR-001).
- Q: Offline listening in this release? → A: Streaming, plus downloading a surah for offline
  listening (User Story 4, FR-027 to FR-034).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Listen ayah by ayah from where I am reading (Priority: P1)

A reader is on a page of the Mushaf and wants to hear it. They tap play, or long-press an ayah and
choose "Play from this ayah". The recitation starts at that ayah and continues one ayah after
another. The ayah being recited is highlighted. When the recitation moves past the end of the
page, the Mushaf turns to the next page by itself. A small player lets the reader pause, resume,
skip to the next or previous ayah, and stop.

**Why this priority**: This is the feature. Hearing a great reciter while following the text on
the printed page is what readers ask for. It is useful on its own with one reciter.

**Independent Test**: With a network connection, open page 50, long-press its third ayah and
choose "Play from this ayah". Listen across the page break into page 51. Each ayah is heard in
order with none skipped or repeated, the highlight matches the ayah heard, and the page turns at
the right moment. Pause, resume, skip forward, skip back and stop all work.

**Acceptance Scenarios**:

1. **Given** the reader is on any page, **When** they tap play, **Then** the recitation starts at
   the first ayah that begins on that page, and that ayah is highlighted.
2. **Given** the reader long-presses an ayah, **When** they choose "Play from this ayah", **Then**
   the recitation starts at that ayah.
3. **Given** an ayah is playing, **When** it ends, **Then** the next ayah plays without a
   noticeable gap and the highlight moves to it.
4. **Given** the last ayah on the page is playing, **When** the next ayah starts on the following
   page, **Then** the Mushaf turns to that page and highlights it.
5. **Given** the recitation reaches the start of a surah, **When** the surah has a basmala, **Then**
   the reciter's basmala plays before ayah 1. At-Tawbah has no basmala, and in Al-Fatiha the
   basmala is ayah 1.
6. **Given** audio is playing, **When** the reader taps pause, next, previous or stop, **Then** it
   takes effect within 100 ms of the tap; stop clears the highlight and hides the player.
7. **Given** the flowing layout, **When** audio plays, **Then** the recited ayah is highlighted and
   kept in view in the same way.

---

### User Story 2 - Choose a reciter (Priority: P1)

A reader picks whom they want to hear: Al-Husary or El-Minshawi. Their choice is remembered, and
every recitation uses it until they change it.

**Why this priority**: The request names two reciters, and readers have strong preferences. It is
P1 because the first release needs a default and a way to change it, but it is small.

**Independent Test**: Choose El-Minshawi, play any ayah and hear El-Minshawi. Restart the app and
play again: still El-Minshawi. Switch to Al-Husary while an ayah is playing.

**Acceptance Scenarios**:

1. **Given** a fresh install, **When** the reader plays for the first time, **Then** Al-Husary is
   heard.
2. **Given** the reciter list, **When** the reader opens it from the player or from Settings,
   **Then** each reciter shows their name in the interface language and the style of the
   recitation.
3. **Given** an ayah is playing, **When** the reader picks another reciter, **Then** the same ayah
   restarts in the new reciter's voice and the recitation continues from there.
4. **Given** the reader chose a reciter, **When** they restart the app, **Then** the choice is kept.

---

### User Story 3 - Keep listening with the screen off (Priority: P2)

A reader starts a recitation, then locks the phone or switches to another app. The recitation
keeps going. From the lock screen or the system's media controls they see the reciter, surah and
ayah, and can pause, resume and skip. When they come back to Mathani, the Mushaf is on the page of
the ayah being recited.

**Why this priority**: Many readers listen while doing something else or with the screen off to
save battery. Story 1 is still useful without it.

**Independent Test**: Start playing Al-Mulk, lock the phone, wait for at least three ayat, pause
and resume from the lock screen, then unlock and open Mathani.

**Acceptance Scenarios**:

1. **Given** audio is playing, **When** the reader locks the phone or leaves the app, **Then** the
   recitation continues ayah by ayah.
2. **Given** audio is playing in the background, **When** the reader looks at the lock screen or
   system media controls, **Then** they show the reciter, surah name and ayah number, with play,
   pause, next and previous.
3. **Given** the recitation moved on in the background, **When** the reader returns to Mathani,
   **Then** the Mushaf shows the page of the ayah being recited, highlighted.
4. **Given** audio is playing, **When** a phone call comes in, another app starts playing audio,
   or headphones are disconnected, **Then** the recitation pauses, following each platform's
   convention. It does not resume by itself after headphones are disconnected.

---

### User Story 4 - Listen without a connection (Priority: P3)

A reader listens to some surahs often, such as Al-Kahf on Fridays or Al-Mulk at night, and wants
them to play anywhere, with no connection and no mobile data. They download those surahs for their
reciter. Downloaded surahs play offline. In Settings they see what they have downloaded, how much
storage it uses, and they can delete any of it.

**Why this priority**: Streaming covers most listening, so Stories 1 to 3 are useful without it.
Downloads make the most-used surahs reliable on a plane, in a mosque without signal, or on a
limited data plan.

**Independent Test**: On Wi-Fi, download Al-Mulk for Al-Husary. Turn the network off and play all
of Al-Mulk. Then play a surah that is not downloaded and check the message. Delete Al-Mulk and
check that the storage is freed and it no longer plays offline.

**Acceptance Scenarios**:

1. **Given** a surah and the chosen reciter, **When** the reader opens the download option from the
   Surahs index or the player, **Then** they see the download size before anything downloads.
2. **Given** the reader is on mobile data, **When** they start a download, **Then** they are told
   it is on mobile data and asked to confirm.
3. **Given** a download is running, **When** the reader keeps reading or listening, **Then** neither
   is interrupted, and the progress is visible.
4. **Given** a download stops (no network, app closed, low storage), **When** the reader comes
   back, **Then** they can resume it without downloading again the ayat already saved.
5. **Given** a surah is downloaded for a reciter, **When** the reader plays it with no connection,
   **Then** every ayah plays, with the basmala, exactly as when streaming.
6. **Given** the Surahs index, **When** the reader views it, **Then** surahs downloaded for the
   chosen reciter are marked.
7. **Given** downloaded surahs, **When** the reader opens Downloads in Settings, **Then** they see
   each surah by reciter with its size and the total storage used, and can delete one surah or
   all of a reciter's downloads. Deleting frees the storage at once.

---

### Edge Cases

- **Reader turns pages while audio plays**: the Mushaf stops following the recitation. The
  recitation keeps playing, and the player offers a way to go back to the ayah being recited.
  Going back resumes following.
- **Reader navigates elsewhere** (index, search, go-to, a bookmark): the recitation keeps playing
  from where it was. It does not jump to the new place unless the reader plays from there.
- **End of the Quran**: after An-Nas the recitation stops and the player shows that it has ended.
- **Slow or lost connection**: the recitation never skips an ayah. If the next ayah cannot be
  loaded, playback pauses on it with a clear "no connection" message and a retry action. Ayat
  already loaded keep playing until then.
- **No connection when the reader taps play**: if the surah is downloaded for the chosen reciter,
  it plays. Otherwise a clear message says this surah needs a connection or a download, and
  offers the download. Reading is not affected.
- **Offline recitation reaches a surah that is not downloaded**: playback pauses at the end of the
  downloaded surah with the same message, and does not skip ahead to the next downloaded surah.
- **Switching reciter with no connection**: if the current surah is not downloaded for the new
  reciter, the reader is told so and the previous reciter stays selected for this session.
- **Not enough storage for a download**: the reader is told before it starts, with the space
  needed. If storage runs out during a download, it stops cleanly and can be resumed later.
- **A downloaded recording is damaged or incomplete**: it is not played; the ayah is streamed if
  possible, otherwise playback pauses with the retry message (FR-020). The surah is no longer
  shown as downloaded until it is repaired by downloading again.
- **Previous at the first ayah of a surah** goes to the last ayah of the previous surah; **next at
  An-Nas 6** ends the recitation.
- **Long-press during playback**: the ayah actions sheet opens as in feature 001 and the
  recitation keeps playing.
- **Switching layout, language or theme during playback**: the recitation keeps playing and the
  highlight stays on the same ayah.
- **App ended by the system during playback**: on the next launch, nothing plays by itself; the
  reader is on the last page they read, as in feature 001.
- **Phone on silent or volume at zero**: the app follows each platform's convention for media
  playback; it does not change the system volume.
- **Screen reader on**: player controls and the reciter list have labels in the interface
  language, and the recitation is not interrupted by the reader moving focus.

## Requirements *(mandatory)*

### Functional Requirements

**Recitations and reciters**

- **FR-001**: The app MUST offer recitations by two reciters: Sheikh Mahmoud Khalil Al-Husary and
  Sheikh Mohamed Siddiq El-Minshawi, both in the Murattal style (المرتل), narration of Hafs 'an
  'Asim, matching the Mushaf in the app.
- **FR-002**: Every reciter MUST have a recording of all 6,236 ayat, one recording per ayah, plus
  a basmala. A reciter with any ayah missing MUST NOT be offered.
- **FR-003**: Recordings MUST come from an authentic, authorised source and be played unaltered:
  no trimming into an ayah, no speed or pitch change, no audio effects.
- **FR-004**: Users MUST be able to choose the reciter from the player and from Settings. The
  choice MUST persist across restarts. The default is Al-Husary.
- **FR-005**: Each reciter MUST be listed with their name in Arabic and, in the English interface,
  in English, along with the style of the recitation (Murattal).

**Playback**

- **FR-006**: Users MUST be able to start a recitation from the current page (its first ayah that
  begins on that page) and from any ayah through the long-press ayah actions of feature 001
  (FR-020), as "Play from this ayah".
- **FR-007**: Playback MUST proceed one ayah at a time in Mushaf order, never skipping or repeating
  an ayah, and continue across pages and surahs until the reader stops it or the end of the
  Quran is reached.
- **FR-008**: The reciter's basmala MUST play before ayah 1 of every surah except At-Tawbah (none)
  and Al-Fatiha (where the basmala is ayah 1).
- **FR-009**: Moving from one ayah to the next MUST add no more than 150 ms of silence beyond
  what is in the reciter's own recordings.
- **FR-010**: A player MUST be visible on the reading screen while a recitation is active (playing
  or paused), with play/pause, next ayah, previous ayah, stop and the reciter choice. It MUST
  show the surah and ayah being recited. It MUST NOT cover any Quran text.
- **FR-011**: Player controls MUST respond within 100 ms of a tap (constitution, Principle III).
  When audio is still loading, the player MUST show that it is loading.

**Following the recitation**

- **FR-012**: The ayah being recited MUST be highlighted in the Mushaf and flowing layouts. The
  highlight MUST cover exactly the words of that ayah, as the selection highlight of feature 001
  does, with either lettering of feature 002.
- **FR-013**: While the reader has not turned away from the recitation, the Mushaf layout MUST
  turn to the page of each ayah as it starts, and the flowing layout MUST keep it in view.
- **FR-014**: When the reader turns pages or navigates while audio plays, following MUST stop
  until they choose to return to the recited ayah from the player. Playback MUST NOT be affected.

**Background and system integration**

- **FR-015**: Playback MUST continue when the screen is locked or the reader switches to another
  app, until the reader stops it or the Quran ends. Nothing else may keep running in the
  background once playback stops.
- **FR-016**: The lock screen and system media controls MUST show the reciter, surah name and ayah
  number, and offer play, pause, next and previous, on both iOS and Android.
- **FR-017**: Playback MUST pause for phone calls, for audio started by other apps and when
  headphones are disconnected, and resume or stay paused as each platform's convention expects.

**Network and data**

- **FR-018**: Recitations MUST stream over the internet when not downloaded; the recordings are
  not part of the app download. Ayat that are downloaded (FR-027) MUST play from the device,
  with or without a connection.
- **FR-019**: Playback MUST load the next ayat ahead of time so that a brief network slowdown does
  not interrupt the recitation.
- **FR-020**: When an ayah cannot be loaded, playback MUST pause on that ayah with a clear message
  and a retry action. It MUST NOT skip the ayah.
- **FR-021**: Replaying an ayah heard recently MUST NOT download it again. Storage used for this
  MUST stay within a fixed limit (set in the plan) and be clearable from Settings.
- **FR-022**: Reading, navigation, bookmarks, search and settings MUST keep working fully offline,
  as required by feature 001 (FR-026). Only recitations that are not downloaded need a
  connection.

**Privacy, attribution and platform**

- **FR-023**: Requesting recordings MUST NOT send any personal data, account or device identifier.
  The app still requires no account (feature 001, FR-027). The store privacy answers MUST be
  updated for the new network use before release.
- **FR-024**: The source of the recordings and each reciter MUST be credited in the About screen,
  as the source's terms require.
- **FR-025**: All new screens and controls MUST meet the constitution's mobile requirements:
  phone portrait layout, safe areas, minimum touch targets, dark mode, system font scaling and
  screen-reader labels in Arabic and English.
- **FR-026**: The feature MUST work on iOS 15.0+ and Android 7.0 (API 24)+, as feature 001.

**Downloads for offline listening**

- **FR-027**: Users MUST be able to download any surah for a chosen reciter, from the Surahs index
  and from the player. A download covers every ayah of the surah and, where it has one, the
  basmala.
- **FR-028**: Before a download starts, the app MUST show its size. On mobile data, the app MUST
  say so and ask the reader to confirm. If there is not enough free storage, the app MUST say how
  much is needed and not start.
- **FR-029**: Downloads MUST run without interrupting reading or listening, show their progress,
  and be cancellable. Several surahs MAY be queued; they download one after another.
- **FR-030**: An interrupted download MUST be resumable and MUST NOT download again the ayat
  already saved. Downloads MUST NOT keep running in the background after the app is closed
  unless the platform provides this as a user-visible download; the plan decides which.
- **FR-031**: A surah MUST count as downloaded only when all its recordings are saved and checked
  as complete. A damaged or incomplete recording MUST NOT be played.
- **FR-032**: The Surahs index MUST mark surahs downloaded for the chosen reciter.
- **FR-033**: Settings MUST list downloads by reciter and surah with their sizes and the total
  storage used, and let the reader delete one surah or all of a reciter's downloads. Deleting
  MUST free the storage at once.
- **FR-034**: Downloaded recordings MUST stay on the device until the reader deletes them or
  uninstalls the app. They MUST NOT count toward the recently played limit of FR-021, and
  clearing that storage MUST NOT delete downloads.

### Key Entities

- **Reciter**: a qari offered in the app. Has an Arabic and an English name, a recitation style
  (Murattal or Mujawwad) and the narration (Hafs 'an 'Asim). Has one recording per ayah plus a
  basmala.
- **Ayah Recording**: the audio of one ayah (or the basmala) by one reciter, identified by
  reciter, surah and ayah.
- **Recitation Session**: the recitation in progress: reciter, the ayah being recited, whether it
  is playing or paused, and whether the Mushaf is following it. It is not kept after the app is
  closed.
- **Surah Download**: a surah saved on the device for one reciter. Has its size, its state
  (queued, downloading with progress, paused, complete) and the date it finished.
- **Reader Preferences** (from feature 001): gains the chosen reciter.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the reference mid-range phone with a typical 4G or Wi-Fi connection, the first
  ayah is heard within 2 seconds of tapping play in 95% of trials.
- **SC-002**: Playing a full surah of at least 100 ayat (for example, Al-Kahf or Al-Anbiya),
  every ayah is heard exactly once, in order, with 0 skipped or repeated, for each reciter.
- **SC-003**: An automated check confirms that each reciter has a recording for all 6,236 ayat
  and the basmala, and that each recording is the right ayah (spot-checked by listening for at
  least 1 ayah per surah).
- **SC-004**: The highlighted ayah matches the ayah heard 100% of the time, and in follow mode
  the Mushaf is on the page of the recited ayah within 0.5 seconds of that ayah starting.
- **SC-005**: With the screen locked, a 30-minute recitation plays without stopping, and the lock
  screen controls work on both iOS and Android.
- **SC-006**: Scrolling and page turns stay at 60 fps while audio plays (constitution,
  Principle III).
- **SC-007**: The feature bundles no recordings. Store download growth is measured on each
  platform, and any growth over 1 MB is reported with its cause and approved in review
  (constitution, Principle IV).
- **SC-008**: With the network turned off, every feature of releases 001 to 003 still works.
  Tapping play on a surah that is not downloaded shows a clear message within 1 second.
- **SC-009**: In a test with at least 10 readers, at least 9 can start a recitation from an ayah
  they choose and change the reciter on their first try, with no help.
- **SC-010**: With the network turned off, a downloaded surah of at least 100 ayat plays from
  start to end with 0 skipped or repeated ayat, for each reciter.
- **SC-011**: An interrupted download resumes and completes without downloading again more than
  one ayah's worth of data already saved, in 100% of trials.
- **SC-012**: After a surah is deleted, the storage it used is shown as freed in Settings within
  1 second.

## Assumptions

- "Ayah by ayah" means the recordings are one file per ayah, so the app always knows which ayah is
  being recited. Highlighting individual words as they are recited is not in scope.
- Both reciters recited the narration of Hafs 'an 'Asim, which matches the Mushaf in the app.
- Recordings come from an established source of ayah-by-ayah Quran audio (to be chosen in the
  plan). Permission to stream them in a free app, and the attribution its terms require, will be
  recorded in `docs/licences.md` as a new dependency (D4), like the text and font permissions. If
  the source is unconfirmed by release, this feature does not ship.
- Al-Husary is the default because the app's audience is mainly Egyptian and the 001 spec names
  him first.
- Both recitations are the Murattal recordings. The Mujawwad recordings, El-Minshawi's in
  particular, can be added later as further reciter entries.
- Streaming over mobile data is allowed without asking, as one ayah is small (well under 1 MB).
  Downloads ask first on mobile data (FR-028), because a surah can be large: roughly 1 MB for a
  short surah and around 50–100 MB for Al-Baqarah, depending on quality. The plan confirms the
  sizes.
- Downloads are per surah only. Downloading a whole reciter or a juz at once is not in this
  release; readers can queue several surahs (FR-029).
- The list of reciters will grow in later releases. Adding a reciter means adding their
  recordings; how readers pick and play reciters does not change.
- The recitation session is not restored after the app is closed; readers restart it with one tap
  from where they were reading.
- The audio uses the system media volume and output (speaker, headphones, Bluetooth, car).

## Out of Scope

- More reciters (later releases, as the request says), including Mujawwad recordings.
- Downloading a whole reciter or a whole juz in one action.
- Repeating an ayah or a range (for memorisation), playback speed, and a sleep timer.
- Word-by-word highlighting during recitation.
- Recitations in narrations other than Hafs, and full-surah recordings that are not split by ayah.
- Audio tafsir or translations.
- Casting to TVs or smart speakers beyond what the system's audio output already offers.
