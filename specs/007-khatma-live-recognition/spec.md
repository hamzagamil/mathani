# Feature Specification: Khatma Recogniser and Live Word-by-Word Reveal

**Feature Branch**: `007-khatma-live-recognition`

**Created**: 2026-10-25

**Status**: Draft

**Input**: User description: "Now I had a test project to compare different models (memorize-ayah)
and I want to switch to the model M5 Khatma FastConformer. I want the app to show word by word
(live-like)"

**Scope of this spec**: Two changes to memorization mode of
[006-reciters-memorization](../006-reciters-memorization/spec.md). Every rule of feature 006 on
memorization, scoring, privacy and the microphone still holds unless this spec says otherwise.

1. **New recogniser**: the owner compared candidate recognition models in a separate test project
   (Memorize-Ayah, on Surah Al-Mulk) and chose **M5, Khatma FastConformer**. It replaces the
   recogniser memorization uses today (Tarteel Whisper tiny, feature 006 research R8).
2. **Live word-by-word reveal**: today a word appears only after the reader pauses, because the
   recogniser reads the voice one stretch of speech at a time. With this feature each word appears
   while the reader is still reciting, a moment after they say it, as in the test project's Live
   screen.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See each word appear as I recite it (Priority: P1)

A reader memorising Surah Al-Mulk starts a session and recites ayah 1 in one breath. Today nothing
appears until they stop to breathe, then several words appear at once. With this feature, the
words appear one after another while they are still reciting, each a moment after they say it, so
the page keeps pace with their voice like a teacher following along in the Mushaf. When they say a
word wrongly and carry on, the app signals the mistake as soon as it is clear, and the first hidden
word shows them where to go back to.

**Why this priority**: It is the visible change the owner asked for. It shows the reader at once
which word was not recognised, instead of after the pause, and makes the mode feel like recitation
to a teacher.

**Independent Test**: On the reference mid-range phone, with the network off, start a session on
Al-Mulk 1–5 and recite ayah 1 without pausing. Words appear one by one while reciting, the first
within 1.5 seconds of saying it. Recite ayah 2 with one word swapped and carry on without pausing:
the mistake is signalled before the end of the ayah, the swapped word and everything after it stay
hidden, and reciting again from that word reveals the rest.

**Acceptance Scenarios**:

1. **Given** a session is listening, **When** the reader recites the expected words in order
   without pausing, **Then** each word appears while they keep reciting, within 1.5 seconds of
   being said, in order.
2. **Given** the reader recites several words quickly, **When** they are recognised together,
   **Then** they appear in order, never a later word before an earlier one.
3. **Given** a word appears, **When** later listening hears the same audio differently, **Then**
   the word stays shown; a revealed word is never hidden again.
4. **Given** the reader says a word wrongly, skips one or adds one, and carries on, **When** the
   words after it make the mistake clear, **Then** the app signals the mistake at once (feature
   006, FR-015), without waiting for a pause, and the wrong word stays hidden with all after it.
5. **Given** the reader pauses in the middle of an ayah, **When** they pause, **Then** every word
   they said before the pause appears within 1 second, and no mistake is signalled for the
   pause.
6. **Given** the reader reaches the last word of an ayah, **When** it is recognised, **Then** the
   ayah is complete and the next ayah becomes the expected one, with no pause needed.

---

### User Story 2 - Recognition I can trust with the new model (Priority: P1)

The reader recites as they normally would, and memorization recognises their words with the
Khatma model. Correct words are accepted, wrong, missing and added words are caught, and the app
works with no connection, as before.

**Why this priority**: The owner chose the model after comparing candidates on real recordings.
Live reveal only helps if the words it shows and the mistakes it signals are right.

**Independent Test**: Run the recordings of the Memorize-Ayah test set (correct recitations and
recitations with planned mistakes, Surah Al-Mulk) through memorization on the reference phone.
Compare the mistakes caught and the false alarms with the comparison results for M5 in the test
project and with the previous recogniser.

**Acceptance Scenarios**:

1. **Given** a correct recitation, **When** it is checked, **Then** every word is revealed and no
   mistake is signalled, within the rates of SC-004.
2. **Given** a recitation with a planned mistake (word missed, swapped or added), **When** it is
   checked, **Then** the mistake is signalled and the word stays hidden, within the rates of
   SC-005.
3. **Given** the network is off, **When** the reader runs a session, **Then** it works fully; the
   voice is processed on the device only (feature 006, FR-019).

---

### User Story 3 - Move to the new model after updating (Priority: P2)

A reader who already used memorization updates the app. The next time they open memorization, the
app tells them a new recognition model is needed, shows its size, and downloads it, asking first on
mobile data. The old model is removed so it does not use space. A new reader sees the same
download sheet as in feature 006, with the new size.

**Why this priority**: It is needed for existing readers, but it is a one-time step around the
main change.

**Independent Test**: Install the previous version, download its memorization model, then update.
Open memorization: the download sheet names the new model's size, Settings › Downloads no longer
lists the old model, and the device's free space grew by its size. Download the new model on
mobile data (asked first) and start a session.

**Acceptance Scenarios**:

1. **Given** a reader who downloaded the previous model, **When** they first launch the updated
   app, **Then** the previous model is deleted and no longer listed in Settings › Downloads.
2. **Given** the new model is not downloaded, **When** the reader opens memorization, **Then** the
   app shows the download size, asks first on mobile data, checks free space, and starts the
   session once the model is saved (feature 006 research R9).
3. **Given** the download is interrupted, **When** the reader opens memorization again, **Then** it
   continues where it stopped, and a corrupted file is never used.
4. **Given** the new model is downloaded, **When** the reader opens Settings › Downloads, **Then**
   it is listed as "Memorization model" with its size and a delete action.

---

### Edge Cases

- **Phone too slow to keep up live**: words still appear in order and never out of turn; they may
  come later, at the latest when the reader pauses (as before this feature). The session stays
  usable and correct, and reading, scrolling and controls stay smooth.
- **Same word twice in a row or a repeated phrase** (for example «فبأي آلاء ربكما تكذبان»
  recurring): a word is revealed only when it is backed by its neighbours or is the next expected
  word, so one common word heard elsewhere does not reveal the wrong place.
- **Reader repeats a word or goes back to restart a phrase**: not a mistake (feature 006, FR-014);
  the words already shown stay shown.
- **Opening isti'adha or basmala**: ignored, as in feature 006.
- **A word heard only partly at the edge of what was listened to**: not judged until more audio
  confirms it; it is neither revealed nor signalled as a mistake from a partial hearing.
- **Long ayah recited in one breath** (for example Al-Baqarah 282): words keep appearing for the
  whole ayah; live reveal does not stop or slow down as the ayah gets longer.
- **Silence, noise, other voices, or a recitation playing nearby**: no word or ayah is revealed
  that the reader did not recite (feature 006, SC-006). After 30 seconds without speech the session
  pauses itself.
- **"Next word" or "Show this ayah" while a word is being recognised**: the hint or reveal applies
  to the first hidden word; a recognition of that same word arriving just after does not count
  twice or skip the following word.
- **Pause, end, call or app to background while words are being recognised**: listening stops
  within 100 ms; any recognition finishing after that is discarded, except that on End the last
  words said are still checked, as in feature 006.
- **Phone heats up during a long session**: the app keeps working; if the phone slows down, live
  reveal degrades to slower updates rather than wrong ones.
- **Not enough free space for the new model**: the app says how much is needed; memorization does
  not start, and nothing else changes.
- **Reader deletes the model in Settings**: memorization asks to download it again the next time.

## Requirements *(mandatory)*

### Functional Requirements

**Recogniser**

- **FR-001**: Memorization MUST recognise the reader's recitation with the Khatma FastConformer
  model (M5 in the Memorize-Ayah comparison) in place of the previous recogniser. Only one
  recognition model is offered.
- **FR-002**: Recognition MUST stay on the device only: the voice MUST NOT be sent over the network
  or stored, and memorization MUST work with no connection (feature 006, FR-019). Audio kept for
  listening again (FR-005) MUST stay in memory and be discarded when the session ends.
- **FR-003**: The model MUST be a one-time download on first use of memorization, with its size
  shown, mobile data asked first, free space checked, resumable downloads and an integrity check,
  as in feature 006 (research R9). Settings › Downloads MUST list it with its size and a delete
  action.
- **FR-004**: On the first launch after updating, the previous recognition model MUST be deleted
  from the device, and it MUST no longer appear in Settings › Downloads.

**Live word-by-word reveal**

- **FR-005**: While the reader recites, the app MUST keep recognising what they have just said, so
  that words are revealed while the reader keeps reciting, without needing a pause.
- **FR-006**: Each word recited correctly in order MUST be revealed within 1.5 seconds of the reader
  saying it, on the reference mid-range phone. When the reader pauses, every word said before the
  pause MUST be revealed within 1 second.
- **FR-007**: Words MUST be revealed only in order, and a revealed word MUST NEVER be hidden again.
  The app MUST NEVER reveal a word or ayah the reader did not recite or ask for (feature 006,
  FR-017).
- **FR-008**: A word MUST be revealed only when it is the next expected word or is backed by the
  expected words next to it, so that a common word heard out of place does not reveal anything.
- **FR-009**: A missing, wrong or added word MUST be signalled as a mistake as soon as the words the
  reader says after it make it clear, without waiting for a pause, and at the latest when the
  reader pauses. A word heard only partly MUST NOT be judged until more of the recitation confirms
  it. Signalling, carrying on from the wrong word and scoring follow feature 006 (FR-015, FR-024).
- **FR-010**: When the phone cannot keep up, live reveal MUST slow down rather than become wrong:
  words still appear in order, at the latest when the reader pauses, and the controls stay
  responsive.
- **FR-011**: Pause, resume and end MUST still respond within 100 ms, and scrolling and page turns
  MUST stay smooth while the reader recites (constitution, Principle III).

**Credits**

- **FR-012**: The About screen and the open-source licences page MUST credit the model and the work
  it is built on as their licence (CC BY 4.0) requires, and MUST stop crediting the previous model.

### Key Entities

- **Recognition model**: the downloaded file that turns the reader's voice into words. Has a name,
  version, size, integrity checksum and licence credit. One per device; replaces the previous
  model.
- **Recent audio**: the last few seconds of the reader's voice, kept in memory only, listened to
  again as the reader goes so words can be revealed before a pause. Discarded at the end of the
  session.
- **Word verdict**: for each expected word of the session, whether it is still hidden, revealed as
  recited, given as a hint, or flagged as a mistake. Once a word is revealed, its verdict does not
  go back to hidden.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 90% of words recited correctly without a pause, the word appears within 1.5
  seconds of the reader saying it, on the reference mid-range phone.
- **SC-002**: When the reader pauses, every word said before the pause appears within 1 second in
  95% of cases, and a correctly recited ayah appears within 1 second of the reader finishing it in
  95% of cases (feature 006, SC-007).
- **SC-003**: In a 2-minute recitation without a pause (for example Al-Mulk 1–10), words keep
  appearing throughout; no stretch of more than 3 seconds of correct recitation goes by with no
  new word shown.
- **SC-004**: On the same test sets as feature 006 (SC-004: correct recitations; SC-005:
  recitations with one planned mistake per ayah), the share of correct ayat revealed with no false
  alarm and the share of mistakes caught are each at least 95%, and no lower than with the
  previous recogniser on the same recordings.
- **SC-005**: On the Memorize-Ayah test recordings (Surah Al-Mulk), mistakes caught and false alarms
  are within 5 percentage points of M5's results in the comparison project.
- **SC-006**: 0 words or ayat are revealed that the reader did not recite or ask for, and 0
  revealed words are hidden again, across all test sessions, including with another recitation
  playing nearby.
- **SC-007**: When a mistake is followed by at least two more words recited without a pause, it is
  signalled before the reader pauses in at least 80% of cases.
- **SC-008**: A 15-minute session uses no more than 10% of the battery of the reference mid-range
  phone, scrolling and page turns stay at 60 fps throughout, and pause, resume and end respond
  within 100 ms.
- **SC-009**: After updating, 100% of devices that had the previous model no longer hold it, and
  the new model is listed in Settings › Downloads once downloaded.
- **SC-010**: The store download grows by less than 1 MB on each platform, or any growth over 1 MB
  is reported with its cause and approved in review (constitution, Principle IV). The model
  download size is shown to the reader before downloading.

## Assumptions

- **Model choice**: the owner chose M5, Khatma FastConformer
  ([adnanfet/khatma-model](https://huggingface.co/adnanfet/khatma-model)), after comparing M1
  (Whisper base Quran), M2 and M3 (Zipformer phoneme models) and M5 in the Memorize-Ayah test
  project. It is licensed CC BY 4.0, which allows commercial use and redistribution with credit.
  M2's and M3's licences would also forbid charging for features they power.
- **Download size**: the plan repackages the model for the phone's existing recogniser: about
  108 MB to download and about 134 MB on the device, up from 61.5 MB (plan research
  R4). The Khatma package itself is 89.4 MB, but the phone cannot use it as is. Recognition is
  unchanged.
- **Live-like, not streaming**: the model reads a stretch of audio at a time rather than following
  the audio continuously. "Live-like" means re-reading the last few seconds of the recitation every
  fraction of a second and moving a pointer through the expected words, as the test project's Live
  screen does. The plan sets how much audio is re-read and how often.
- **Reference mid-range phone**: the same device used for feature 006's targets.
- **One model, no fallback**: the previous recogniser is removed rather than kept as an option
  (constitution, Principle V). Readers who never open memorization download nothing.
- **Unchanged from feature 006**: choosing the range, the hidden page, mistake signals (vibration,
  sound or neither), "Next word" and "Show this ayah", the 30-second silence pause, the score rule,
  the result and review, and the microphone rules.
- **Diacritics and tajweed are still not judged**: words are compared without diacritics, as in
  feature 006.

## Out of Scope

- Judging tajweed, diacritics or pronunciation detail.
- Offering a choice of recognition models, or keeping the previous model as a fallback.
- Truly streaming recognition models (such as the Zipformer phoneme models tested as M2 and M3).
- Changes to the score rule, the result screen or the range selection.
- Keeping session audio or results after the session (feature 006, FR-019 and FR-026).
