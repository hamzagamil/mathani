# Feature Specification: Mutashabihat (Similar Ayat)

**Feature Branch**: `010-mutashabihat` (not created yet; work so far is on `008-web-app`)

**Created**: 2026-11-03

**Status**: Draft

**Input**: User description: "Add a feature to show mutashabih, similar ayat. I need to be able as
an app owner to link related ayas and the user will be able to see the related ayas when he long
press on aya and select (عرض المتشابه). The ayas which have related ayas should have a custom font
color to allow user to know that there is a mutashabih here. When the user clicks on (عرض المتشابه)
an overlay shows with the ayah and related ayas. and the bottom third of the page contains a text
entered by me as an app owner that explains the relation"

**Scope of this spec**: The first Mutashabihat (تدبر المتشابه) feature, which specs/001 named as
the app's core differentiator. It has three parts:

1. **Marking**: ayat that have similar ayat show in a distinct text colour in the Mushaf.
2. **Viewing**: a new long-press action, «عرض المتشابه», opens an overlay with the ayah, its
   similar ayat, and the owner's explanation of how they relate.
3. **Authoring**: the owner links similar ayat into groups and writes the explanation for each
   group. Readers cannot edit this content.

## Clarifications

### Session 2026-11-03

- Q: How does the owner enter the content, and how does it reach readers? → A: For now the owner
  edits a content file kept with the app, and changes reach readers with the next app and web
  release. An online editor that updates readers without a release is a later feature.
- Q: Should the overlay highlight the words that differ between the ayat? → A: No. The overlay
  shows whole ayat, and the owner's explanation describes the differences.
- Q: The seed content linked ayat that a source quotes only as context (the ayah before or after
  the mutashabih). What is linked and coloured? → A: Only the mutashabih ayat themselves, whole.
  Context ayat are neither linked nor coloured (FR-014).
- Q: Which colour? → A: Emerald green, chosen from four candidates as the clearest.
- Q: How do readers learn what the colour means? → A: A stop in the onboarding tour (FR-021),
  also shown once to readers who finished the onboarding before.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the similar ayat and why they are similar (Priority: P1)

The reader long-presses an ayah while reading. If the owner has linked it to similar ayat, the
action sheet includes «عرض المتشابه». Tapping it opens an overlay. The top two thirds show the ayah
the reader pressed, followed by its similar ayat, each with its surah name and ayah number. The
bottom third shows the owner's explanation of the relation: what is the same, what differs, and
how to tell them apart. The reader closes the overlay and is back where they were.

**Why this priority**: This is the feature. Without it, the colour and the authoring have no
purpose. It can be tested with a small set of groups prepared by hand.

**Independent Test**: With one prepared group of three ayat and an explanation, long-press each of
the three ayat in turn, open «عرض المتشابه», and check that the overlay shows the pressed ayah
first, the other two after it, and the explanation in the bottom third. Long-press an ayah with no
group and check the action is absent.

**Acceptance Scenarios**:

1. **Given** an ayah that belongs to a group, **When** the reader long-presses it, **Then** the
   action sheet shows «عرض المتشابه» with the existing actions (play, memorize, copy, share,
   bookmark).
2. **Given** an ayah that belongs to no group, **When** the reader long-presses it, **Then**
   «عرض المتشابه» does not appear.
3. **Given** the reader taps «عرض المتشابه», **When** the overlay opens, **Then** the pressed ayah
   is shown first and marked as the current ayah, the other ayat of the group follow in Mushaf
   order, and every ayah shows its full Uthmani text, surah name and ayah number.
4. **Given** the overlay is open, **When** the reader looks at its bottom third, **Then** they see
   the owner's explanation for the group. If the explanation is longer than the space, it scrolls
   on its own without moving the ayat above it.
5. **Given** the group has more ayat than fit in the top two thirds, **When** the reader scrolls
   that area, **Then** all ayat can be reached and the explanation stays in place.
6. **Given** the overlay is open, **When** the reader taps a related ayah, **Then** the overlay
   closes and the Mushaf opens at that ayah, briefly highlighted, as when opening a search result.
7. **Given** the overlay is open, **When** the reader closes it (close button, back gesture or
   swiping it down), **Then** they return to the same page and position as before.
8. **Given** the phone has no internet connection, **When** the reader opens «عرض المتشابه»,
   **Then** the overlay shows the same content as online.

---

### User Story 2 - Know where a mutashabih is while reading (Priority: P1)

While reading, the reader notices that some ayat are in a different text colour. That colour means
"this ayah has similar ayat". They do not have to long-press every ayah to find out.

**Why this priority**: Without the marking, readers would not know the feature exists or where to
use it. It is part of the minimum the owner asked for.

**Independent Test**: Open a page that contains a linked ayah, in both the page layout and the
flowing layout, in both the day and night themes. Check that only the linked ayat are coloured
and that the colour is readable and different from the normal text and from the existing
highlights.

**Acceptance Scenarios**:

1. **Given** a page with linked and unlinked ayat, **When** it is displayed, **Then** every word of
   each linked ayah, including its ayah-end marker, is in the mutashabih colour, and all other ayat
   are in the normal text colour.
2. **Given** the day or the night theme, **When** a linked ayah is displayed, **Then** the colour
   is clearly different from the normal text and still easy to read against the page.
3. **Given** a linked ayah is selected by long-press, being recited, or briefly highlighted after
   a jump, **When** it is displayed, **Then** the existing highlight still shows clearly and the
   reader can still see that the ayah is linked.
4. **Given** memorization mode hides the text of the ayat to recite, **When** a hidden ayah is
   linked, **Then** nothing about its text is revealed. The colour applies only to text that is
   shown.
5. **Given** a screen reader is on, **When** focus reaches a linked ayah, **Then** it announces
   that the ayah has similar ayat, so the information does not depend on colour alone.

---

### User Story 3 - Owner links ayat and writes the explanation (Priority: P2)

The owner creates a group of similar ayat by choosing the ayat by surah and ayah number and writing
the explanation in Arabic. Later they can add or remove ayat, correct the explanation, or delete
the group. All of this is done in one content file kept with the app. The changes reach readers
with the next app and web release.

**Why this priority**: Readers see nothing without content, but Stories 1 and 2 can be built and
tested with a few groups prepared by hand. The owner's way of working only has to be in place
before the content grows beyond a handful of groups.

**Independent Test**: In the content file, the owner creates a new group of three ayat with an
explanation, changes the explanation of another group, removes one ayah from it, and deletes a
third group. After building the app, check on a phone that the new group appears, the corrected
text shows, the removed ayah is no longer coloured or linked, and the deleted group is gone.

**Acceptance Scenarios**:

1. **Given** the owner adds a group of two or more ayat with an explanation, **When** the next
   release reaches the reader, **Then** each of those ayat is coloured and opens the group in
   «عرض المتشابه».
2. **Given** the content file references an ayah that does not exist (for example surah 2, ayah
   300), **When** the content is checked before a release, **Then** the check fails with a message
   naming the group and the bad reference, and a release cannot be built with it.
3. **Given** the content file has a group with fewer than two ayat or with no explanation,
   **When** the content is checked, **Then** the check fails with a message naming the group and
   saying what is missing.
4. **Given** the owner removes an ayah from a group or deletes a group, **When** the next release
   reaches the reader, **Then** ayat no longer in any group lose the colour and the «عرض المتشابه»
   action.
5. **Given** the owner writes the explanation in several paragraphs, **When** the reader opens the
   overlay, **Then** the paragraphs are kept as written.

---

### User Story 4 - An ayah in more than one group (Priority: P3)

Some ayat are similar to different ayat for different reasons, for example one phrase matches one
set of ayat and another phrase matches another. The owner can put the same ayah in several groups,
each with its own explanation. The reader sees all of them from that ayah.

**Why this priority**: Real Mutashabihat often overlap like this, but the feature is useful for
most ayat without it.

**Independent Test**: Put one ayah in two groups. Open «عرض المتشابه» on it and check that the
reader can see both groups, each with its own ayat and explanation. Open it on an ayah that is
only in the second group and check that only the second group shows.

**Acceptance Scenarios**:

1. **Given** an ayah belongs to two or more groups, **When** the reader opens «عرض المتشابه»,
   **Then** the overlay shows the first group and lets the reader move between the groups. The
   explanation always belongs to the group on screen.
2. **Given** an ayah belongs to exactly one group, **When** the overlay opens, **Then** there is no
   control for moving between groups.

---

### Edge Cases

- **Very long ayat**: an ayah such as Al-Baqarah 282 is longer than the top area. The area scrolls
  and the ayah is shown in full, not cut off.
- **Large groups**: some phrases recur in ten or more places. All ayat are listed and reachable by
  scrolling, and the overlay still opens quickly.
- **Two linked ayat on the same page**: tapping a related ayah on the page already open closes the
  overlay and highlights it on that page without reloading.
- **Same ayah twice**: the owner cannot add the same ayah to one group twice. If they try, it is
  kept once.
- **Text size and font scaling**: the overlay follows the reader's text size and system font
  scaling. At the largest sizes the two areas scroll rather than clip.
- **Flowing and page layouts**: marking and the action work the same in both layouts.
- **Small screens and safe areas**: the overlay keeps its two thirds and one third split on small
  phones, stays clear of the notch and home indicator, and its close control is reachable one
  handed.
- **Content unavailable**: if the Mutashabihat content cannot be read, the Mushaf still opens and
  works normally. No ayah is coloured and the action does not appear. Nothing crashes.
- **Web app**: the same marking, action and overlay work in the web app (specs/008), with the
  long-press equivalent already used there.

## Requirements *(mandatory)*

### Functional Requirements

**Marking**

- **FR-001**: The app MUST show every ayah that belongs to at least one group in a distinct
  mutashabih text colour, on every page and in both the page and flowing layouts.
- **FR-002**: The mutashabih colour MUST be defined for both the day and night themes, MUST be
  easy to tell apart from the normal text and from the existing selection, recitation and jump
  highlights, and MUST remain readable against the page background.
- **FR-003**: The colour MUST NOT reveal text that memorization mode hides.
- **FR-004**: For screen readers, a linked ayah MUST be announced as having similar ayat.

**Action and overlay**

- **FR-005**: The long-press action sheet MUST show «عرض المتشابه» (English interface: "Show
  similar ayat") for ayat in at least one group, and MUST NOT show it for other ayat.
- **FR-006**: Choosing the action MUST open an overlay over the Mushaf. The top two thirds MUST
  show the pressed ayah first, marked as the current ayah, and then the other ayat of the group in
  Mushaf order. Each ayah MUST show its full Uthmani text, surah name and ayah number.
- **FR-007**: The bottom third of the overlay MUST show the owner's explanation for the group,
  with the owner's paragraphs kept.
- **FR-008**: The ayat area and the explanation area MUST scroll independently when their content
  does not fit.
- **FR-009**: Tapping a related ayah in the overlay MUST close it and open the Mushaf at that ayah
  with the existing brief highlight.
- **FR-010**: The reader MUST be able to close the overlay with a visible close control, the
  platform back gesture or button, and a swipe down, and MUST return to the same reading position.
- **FR-011**: When an ayah belongs to several groups, the overlay MUST let the reader move between
  them, and MUST show each group's own ayat and explanation.
- **FR-012**: The overlay MUST be in Arabic layout (right to left) for the Arabic interface. The
  explanation is shown as the owner wrote it in either interface language.
- **FR-013**: Marking, the action and the overlay MUST work without an internet connection, using
  the content the app already has.

**Content and authoring**

- **FR-014**: A group MUST hold two or more distinct ayat and one non-empty explanation. An ayah
  MAY belong to several groups. A group holds only the ayat that carry the mutashabih, not ayat a
  source quotes as context around it.
- **FR-015**: The owner MUST create, edit and delete groups in a single content file kept with the
  app, readable and editable as text, with the explanation written in Arabic as it should appear.
  Readers MUST NOT be able to change the content.
- **FR-016**: A check MUST run before every app and web release and MUST fail, naming the group and
  the problem, if any group references an ayah that does not exist, has fewer than two distinct
  ayat, or has an empty explanation. A release MUST NOT be built while the check fails.
- **FR-017**: The content MUST ship inside the app and the web app, and changes MUST reach readers
  with the next release. The app MUST NOT need the internet to get or show the content.
- **FR-018**: The overlay MUST show whole ayat in their normal lettering. It MUST NOT highlight
  individual words; the explanation describes the differences.
- **FR-019**: If the content cannot be read, the Mushaf MUST work normally with no marking and no
  «عرض المتشابه» action.

**Platforms**

- **FR-020**: The feature MUST work the same on iOS 15.0+, Android 7.0 (API 24)+ and the web app.

**Onboarding**

- **FR-021**: When there is content, the onboarding tour MUST include a stop after the ayah
  actions that says what the coloured ayat mean and how to open «عرض المتشابه». Readers who
  finished the onboarding before MUST see this stop once, on their next launch.

### Key Entities

- **Mutashabih group**: a set of two or more ayat that the owner considers similar for one reason,
  with one explanation. Has an identifier so the owner can edit it later.
- **Group member**: one ayah in a group, identified by surah number and ayah number. The same ayah
  can be a member of several groups, but only once in each.
- **Explanation**: the owner's Arabic text for a group, in one or more paragraphs, describing what
  the ayat share, how they differ and how to tell them apart.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The overlay appears within 1 second of tapping «عرض المتشابه», including for a group
  of 10 or more ayat, and the tap shows visible feedback within 100 ms.
- **SC-002**: Pages with coloured ayat open and scroll as smoothly as pages without them: no new
  dropped frames and no measurable slowdown in page turns.
- **SC-003**: In a check of every group, 100% of member ayat are coloured and offer the action,
  and 0 ayat outside any group are coloured or offer it.
- **SC-004**: 0 broken ayah references reach readers: every reference shown in an overlay opens
  the right ayah.
- **SC-005**: The owner can create a new group of three ayat with a paragraph of explanation in
  under 5 minutes.
- **SC-006**: In a test with at least 5 readers who were not told what the colour means, at least
  4 find «عرض المتشابه» on a coloured ayah within one minute of reading.
- **SC-007**: The feature works fully offline on all three platforms.

## Assumptions

- **Group model**: the owner said "link related ayas" and "a text that explains the relation".
  This spec reads that as a group of ayat sharing one explanation, not separate links between
  pairs. When ayat need different explanations, the owner puts them in different groups (Story 4).
- **Whole ayat**: the owner links whole ayat. Linking part of an ayah, such as one phrase, is not
  in this release. The explanation can name the phrase.
- **Explanation language**: explanations are in Arabic only. There is no English version, even in
  the English interface.
- **Plain text**: explanations are plain text with paragraphs. No links, images, audio or rich
  formatting in this release.
- **Always on**: the colour is always shown. There is no setting to turn it off in this release
  (Principle V). If readers ask for one, it is a small follow-up.
- **Text in the overlay**: ayat in the overlay use the same Uthmani text and lettering the reader
  already has, so no new font or text download is needed.
- **One owner**: only one person, the owner, writes content. There are no editor roles, reviews,
  drafts or history beyond the project's own version history.
- **Release cadence**: a correction to the content waits for the next app and web release. The
  owner accepts this until the online editor exists.
- **Starting content**: the owner will write the first groups. The feature ships when there is
  enough content to be useful; the number is the owner's call.
- **Existing behaviour reused**: the long-press sheet, the brief highlight after a jump, the day
  and night themes, and the web app's long-press equivalent already exist and are reused.

## Out of Scope

- An online editor for the owner that updates readers without a release. This is the planned next
  step for authoring and will get its own spec.
- Highlighting the words that differ between the ayat of a group.
- Readers creating their own links or notes.
- Searching or browsing all Mutashabihat as a list or index. This may be a later feature.
- Copying or sharing the overlay or the explanation.
- Audio for the ayat in the overlay.
- Tafsir and translations.
