# Feature Specification: Send Announcements from the Owner Dashboard

**Feature Branch**: `018-dashboard-announcements` (not created yet)

**Created**: 2026-11-23

**Status**: Draft

**Input**: User description: "I want to be able to send notifications to customers from the
dashboard." Expanded: let the owner send announcements to readers from an owner page on the
website instead of the Firebase console. The page sits in the owner area at `/editor/`, beside the
group khatma reports page, behind the same sign-in, for the owner only. The owner writes a title
and text, may add a Mathani link, picks the audience (everyone, or Arabic or English readers),
sees a preview, confirms and sends. The page keeps a history of what was sent. Readers' apps need
no change.

**Scope of this spec**: A new way for the owner to send the announcements that feature 015
already delivers. Feature 015 ([spec](../015-jumuah-duha-announcements/spec.md), Story 4) made the
app receive announcements and left sending to the push service's console. This spec adds a page
for sending and a record of what went out. Readers see exactly what they see today.

**Out of scope**:

- Sending to one device, to one reader, or to segments other than the three audiences below.
  Segments stay the later item noted in spec 015.
- Scheduling a message for later; every message is sent when the owner confirms.
- Editing or recalling a message after it is sent (the push service cannot recall a delivered
  message).
- Images, buttons or sounds in the message.
- Delivery and open statistics per message (the push service's console and the analytics from
  feature 016 remain the place for these).
- Any change to the Android, iOS or web app. Minimum supported OS versions are unchanged from
  feature 015 (the app's current minimums); this spec ships only on the website.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Write and send an announcement (Priority: P1)

The owner opens the announcements page in the owner area, writes a title and a short text, picks
who receives it, checks the preview, confirms, and the message goes out. Readers who have
announcements turned on get it as they would a message sent from the console.

**Why this priority**: This is the whole request. Without it the owner keeps using the push
service's console, which is in English, shows options that do not apply to Mathani, and makes it
easy to pick the wrong audience or channel.

**Independent Test**: With a test phone that has announcements on and the app in Arabic, send a
message to Arabic readers from the page. Check it arrives on the phone with the title and text as
written. Send one to English readers and check it does not arrive on that phone.

**Acceptance Scenarios**:

1. **Given** the owner is signed in, **When** they open the owner area, **Then** they can reach
   the announcements page from it, as they reach the khatma reports page.
2. **Given** the announcements page, **When** the owner fills in a title and text, **Then** a
   preview shows the message as a phone notification would, right to left for Arabic text and
   left to right for English text.
3. **Given** a title, text and audience, **When** the owner chooses Send, **Then** the page asks
   them to confirm, naming the audience in words ("All readers", "Arabic readers", "English
   readers"). Nothing is sent until they confirm.
4. **Given** the owner confirms, **When** the push service accepts the message, **Then** the page
   says it was sent and clears the form. Readers in that audience who have announcements on
   receive it within a few minutes.
5. **Given** the audience is "All readers", **When** the message is sent, **Then** readers in both
   languages receive it once each, not twice.
6. **Given** a reader has announcements turned off in the app, **When** any message is sent,
   **Then** they do not receive it (feature 015 behaviour, unchanged).

---

### User Story 2 - Add a link that opens a place in the app (Priority: P2)

The owner adds a Mathani link to the message, for example to a page or a group khatma. When a
reader taps the message, the app opens at that link.

**Why this priority**: Useful for pointing readers to something new, but a message without a link
already works.

**Independent Test**: Send a message with a link to a group khatma. Tap it on the test phone and
check the app opens that khatma. Try to enter a link to another site and check the page refuses
it.

**Acceptance Scenarios**:

1. **Given** the form, **When** the owner enters a link on `mthani.app`, `www.mthani.app` or
   `get.mthani.app` that starts with `https://`, **Then** it is accepted and shown in the preview.
2. **Given** the form, **When** the owner enters any other link (another site, `http://`, or not
   a link), **Then** the page says only Mathani links are allowed and Send stays unavailable.
3. **Given** a sent message with a link, **When** a reader taps it, **Then** the app opens at that
   link, as feature 015 does today for console messages.

---

### User Story 3 - See what has been sent (Priority: P2)

The owner sees a list of past announcements, newest first: when it was sent, by whom, the
audience, title, text, link, how long it stays deliverable, and whether the push service accepted
it.

**Why this priority**: It stops the owner from sending the same message twice and answers "did
that go out?" without opening the console. It is not needed to send.

**Independent Test**: Send two messages, one of which fails (for example with sending turned off,
see Edge Cases). Reload the page and check both appear, newest first, with the right result.

**Acceptance Scenarios**:

1. **Given** messages were sent before, **When** the owner opens the page, **Then** they see the
   history, newest first, with the details above.
2. **Given** a message the push service refused, **When** the owner looks at the history, **Then**
   it is marked as not sent with the reason in plain words, and the owner can copy it back into
   the form to try again.
3. **Given** any past message, **When** the owner chooses to reuse it, **Then** the form fills
   with its title, text, link and audience for editing; nothing is sent until they confirm again.

---

### User Story 4 - Choose how long a message may still be delivered (Priority: P3)

Some messages only matter today (for example a reminder about tonight). The owner chooses how long
the push service keeps trying to deliver a message to phones that are off or offline.

**Why this priority**: The default covers most messages. Spec 015 listed "Old messages" as the
admin's choice in the console, so the page keeps that choice.

**Independent Test**: Send a message that stays deliverable for one hour to a test phone in
airplane mode. Turn airplane mode off after two hours and check the message does not arrive.

**Acceptance Scenarios**:

1. **Given** the form, **When** the owner does not change it, **Then** a message stays deliverable
   for 1 day.
2. **Given** the form, **When** the owner picks another period, **Then** they can choose 1 hour,
   1 day, 1 week or 4 weeks.

---

### Edge Cases

- **Someone other than the owner**: an editor of the mutashabihat (feature 011) who is signed in
  to the owner area cannot see the announcements page or send, and the server refuses a send from
  anyone but the owner, even if the request is made by hand.
- **Signed out or session expired**: the page asks the owner to sign in again; a half-written
  message stays in the form.
- **Pressing Send twice, or a slow network**: one confirmation sends one message. A repeated
  request for the same message (for example after a retry) is not sent a second time.
- **Sending not set up**: if the push service credentials are missing or rejected, the page says
  sending is not set up, Send is unavailable, and nothing is recorded as sent.
- **Push service unavailable or refuses**: the page shows the failure in plain words, the form
  keeps the message, and the history records the attempt as not sent.
- **Too long**: the title is limited to 65 characters and the text to 240, so they are not cut
  short on most phones; the page counts characters as the owner types and will not send past the
  limit.
- **Empty fields**: Send is unavailable until both title and text have visible text (not only
  spaces).
- **Mixed language**: the preview's direction follows the first strong character of each field,
  so an English title with Arabic text shows each the right way.
- **No readers in an audience**: the push service accepts messages to an audience with no
  subscribers; the page says sent, as the console does.
- **Many messages in a short time**: at most 10 sends per hour from the page, so a mistake or a
  stuck button cannot flood readers; the page says when the limit is reached and when it resets.

## Requirements *(mandatory)*

### Functional Requirements

**Access**

- **FR-001**: The announcements page MUST be part of the owner area at `/editor/`, behind the same
  sign-in as the khatma reports page, and MUST be reachable from the owner area.
- **FR-002**: Only the owner (the address set as the owner for the owner area) MUST be able to
  load the history or send. The server MUST check this on every request, not only the page.
- **FR-003**: The credentials used to send MUST be kept only on the server, never in the page, the
  site's files or the repository.

**Writing and sending**

- **FR-004**: The owner MUST enter a title (1–65 characters) and text (1–240 characters), with a
  live character count for each.
- **FR-005**: The owner MAY enter one link; it MUST be an `https://` link on `mthani.app`,
  `www.mthani.app` or `get.mthani.app` (the same rule the app applies to tapped messages).
- **FR-006**: The owner MUST pick exactly one audience: All readers, Arabic readers or English
  readers, matching the groups the app already joins (feature 015 contract: `all`, `lang_ar`,
  `lang_en`). "All readers" MUST be preselected.
- **FR-007**: The owner MUST pick how long the message stays deliverable: 1 hour, 1 day (default),
  1 week or 4 weeks.
- **FR-008**: The page MUST show a preview of the notification with the title, text and link,
  each shown in its own reading direction.
- **FR-009**: Sending MUST require a confirmation step that names the audience in words.
- **FR-010**: The message sent MUST match the format in the feature 015 announcements contract
  (the announcements notification channel on Android, the link as the message's link field), so
  readers' apps show it and handle a tap exactly as they do a console message.
- **FR-011**: One confirmation MUST produce at most one message, even if the request is repeated.
- **FR-012**: The server MUST refuse more than 10 sends in any hour and say when sending is
  possible again.
- **FR-013**: After a send, the page MUST say whether the push service accepted it and, if not,
  why, in plain words; on failure the form MUST keep the message.

**History**

- **FR-014**: Every send attempt MUST be recorded with: time, the owner's address, audience, title,
  text, link, deliverable period, result (sent or not sent), and the push service's message
  reference or failure reason.
- **FR-015**: The page MUST list the history newest first, showing at least the last 100 attempts.
- **FR-016**: The owner MUST be able to copy any past message into the form to edit and send it
  again; copying MUST NOT send.
- **FR-017**: The history MUST be kept until the owner removes it; it holds no reader data.

**Language**

- **FR-018**: The page MUST be in Arabic, right to left, like the other owner pages.

### Key Entities

- **Announcement**: one send attempt by the owner. Title, text, optional link, audience,
  deliverable period, sent-by address, created time, result, and the push service's reference or
  failure reason. Holds nothing about readers.
- **Audience**: one of three fixed groups (all readers, Arabic readers, English readers) that the
  app already subscribes readers to when announcements are on.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The owner can write and send an announcement from the page in under 2 minutes,
  without opening the push service's console.
- **SC-002**: A message sent from the page reaches a test phone in the chosen audience, with
  announcements on and a network connection, within 5 minutes in 10 out of 10 tries.
- **SC-003**: A message sent from the page looks and behaves on Android and iOS the same as one
  sent from the console under the feature 015 contract: same channel, same tap handling.
- **SC-004**: No request from anyone but the owner sends a message or reads the history (0 out of
  all attempts in testing, including requests made by hand without the page).
- **SC-005**: The sending credentials appear nowhere in the site's published files or the
  repository (checked before release).
- **SC-006**: Every send attempt, sent or failed, appears in the history within the time it takes
  to reload the page.

## Assumptions

- "Customers" are the app's readers, and "the dashboard" is the owner area on the website
  (`/editor/`), where the owner already handles khatma reports. The analytics dashboard from
  feature 016 is read-only by design (spec 016 FR-015) and is not used for sending.
- Readers receive announcements only if they have them turned on in the app (feature 015); this
  spec does not change that or ask for permission anywhere.
- The owner area's existing sign-in and owner check (features 011 and 014) are reused.
- The owner creates the push service credentials for sending once, in the project's Firebase
  settings, and stores them as a server secret; the quickstart for this feature will list the
  steps.
- Messages are written in one language per send. To reach both languages with their own wording,
  the owner sends one message to Arabic readers and one to English readers.
- The 10-per-hour limit and the 65/240 character limits are defaults chosen for safety and
  readability; they can be changed in the plan if the owner prefers.
- Deliverable periods follow what the push service allows (at most 4 weeks).
