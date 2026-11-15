# Feature Specification: Personal and Group Khatma

**Feature Branch**: `014-khatma-management` (not created yet; this spec was written on
`013-page-zoom-similar-labels`)

**Created**: 2026-11-15

**Status**: Draft

**Input**: User description: "I want to add  an option for managing khatma. I want you to research for possible options in this module and discuss how it will be done"

**Scope of this spec**: A khatma (ختمة) is one complete reading of the Quran. Readers usually
divide it into a daily portion, the wird (ورد). Families and groups of friends also read a khatma
together, each person taking a part: a group khatma (ختمة جماعية). This feature adds both to
Mathani. The Mushaf stays the home screen. Khatma is a separate screen the reader opens when they
want it.

**A personal khatma**, kept on the reader's device:

1. **Plan**: the reader chooses how much to read each day, or in how many days to finish. The
   app divides the Quran into wirds and shows the finish date.
2. **Daily wird**: the Khatma screen shows the wird to read now. One tap opens the Mushaf at the
   right page, and the page shows where the wird ends.
3. **Place**: the khatma keeps its own place. Reading other parts of the Mushaf, listening or
   memorizing does not move it.
4. **Reminder**: one reminder a day at a time the reader picks, only when something is waiting
   to be read.
5. **Progress and changes**: how much is read, when the khatma will finish, and ways to change
   the plan, pause or end it.
6. **Record**: finished khatmas are kept with their dates.

**A group khatma**, kept on Mathani's server so that everyone sees the same state:

7. **Link**: a reader starts a group khatma and shares its link. Others open it in the app or in
   a browser, with no account.
8. **Parts**: each person takes a juz or a hizb, reads it in the Mushaf and marks it as read.
   Everyone sees who has which part and how far the khatma is.
9. **Safety and order**: terms, a filter on names, reporting, and tools for the organiser,
   because people see names that others typed.

This feature delivers the "daily wird reminder" that specs/001 and specs/005 list as a later
feature. It is not related to specs/007, where "Khatma" is the name of the recognition model.

The group khatma changes two things that every earlier spec could say. It is the first feature
in which a reader sees text that another reader typed, and the first that keeps something about
readers on Mathani's server. Story 6 and FR-059 to FR-069 exist because of that.

## Clarifications

### Session 2026-11-15

- Q: Should this feature also cover a group khatma (ختمة جماعية), where the ajza' are shared
  among several people? → A: Yes, a live group khatma: a link that people open to take a part
  and mark it as read, with progress that everyone sees (Stories 5 to 7, FR-044 to FR-072).
- Q: How should the app learn what the reader has read? → A: The khatma place follows the
  reader's own page turns. A wird becomes read by a tap at its end or by reading on past it,
  and "Set khatma place here" corrects it (FR-014 to FR-017).
- Q: After missed days, should the wirds stay as planned and the finish date move, or should
  the finish date stay? → A: The wirds stay as planned and the finish date moves. The reader
  can read more than one wird in a day, or change the plan for what is left (FR-028, FR-030).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Plan a khatma and read today's wird (Priority: P1)

A reader wants to finish the Quran in a month. They open Khatma, choose "a juz a day", see that
this takes 30 days and on which date it ends, and start. The Khatma screen now shows today's wird:
where it starts, where it ends and how many pages it is. They tap Read and the Mushaf opens at the
first page of the wird. When they reach the last page of the wird, a mark shows the ayah where it
ends. They tap Done, and the khatma moves to the next wird.

**Why this priority**: This is the core of the feature. A reader who can plan, read and finish
each wird has a working khatma, even without a reminder, a record or a group.

**Independent Test**: With the network off, start a "juz a day" khatma, read the first wird to
its end, mark it done, close and reopen the app. The Khatma screen shows 1 of 30 read and the
second wird as next.

**Acceptance Scenarios**:

1. **Given** no khatma exists, **When** the reader opens Khatma, **Then** they see one line on
   what a khatma plan does and a "Start a khatma" action. Nothing else must be set up first.
2. **Given** the plan choices, **When** the reader picks "a juz a day", **Then** the app shows
   30 days and the finish date before they confirm.
3. **Given** the plan choices, **When** the reader enters 29 days, **Then** the app shows the
   daily amount (20 or 21 pages) and the finish date before they confirm.
4. **Given** a reader who is already at Juz 16 in a printed Mushaf, **When** they choose to
   start from Juz 16, **Then** the plan covers Juz 16 to the end of the Quran, and the number of
   days and the finish date are for that part only.
5. **Given** a khatma has started, **When** the reader opens Khatma, **Then** the current wird
   shows its number out of the total, where it starts and ends (surah, ayah and page), and its
   number of pages.
6. **Given** the current wird, **When** the reader taps Read, **Then** the Mushaf opens at the
   khatma place, in the reader's reading layout.
7. **Given** the page where the current wird ends is on screen, **When** the reader looks at
   it, **Then** the ayah where the wird ends is marked, no Quran text is moved or covered, and
   an action to mark the wird as read is available without leaving the reading screen.
8. **Given** a page of the current wird is on screen, **When** the reading controls are
   visible, **Then** they show how many pages of the wird are left.
9. **Given** the reader marks the wird as read, **When** they look at Khatma, **Then** the wird
   shows as read today, the progress has grown, and the next wird is shown.
10. **Given** a khatma in progress, **When** the app is closed and opened again with no
    network, **Then** the plan, the read wirds and the place are as they were.
11. **Given** a first run of the app, or the tour replayed from Settings, **When** the reader
    goes through the tour, **Then** one stop introduces Khatma.

---

### User Story 2 - Keep my place in the khatma whatever else I read (Priority: P1)

The reader stops in the middle of today's wird. Later they open another surah from the index,
search for an ayah, listen to a recitation or test their memorization. The next day they tap
Continue, and the Mushaf opens on the page where they stopped in the khatma. If they read on past
the end of the wird, the khatma follows them into the next one. If the app does not know where
they are, for example because they read from a printed Mushaf, they set the place themselves at
any ayah.

**Why this priority**: Today the app remembers one reading position, and any browsing moves it.
A khatma that loses the reader's place is no better than a paper timetable.

**Independent Test**: Read part of a wird, then open other surahs through the index, search and a
bookmark, play a recitation of another surah and run a memorization session. Tap Continue and
check the page. Then read past the end of the wird and check that the khatma moved on.

**Acceptance Scenarios**:

1. **Given** the reader stopped on page 50, inside a wird that covers pages 42 to 62, and then
   opened Surah Ya-Sin from the index, **When** they tap Continue in Khatma, **Then** the Mushaf
   opens on page 50.
2. **Given** the same khatma, **When** the reader opens Ayat al-Kursi on page 42 from search,
   reads it and leaves, **Then** the khatma place is still page 50.
3. **Given** the reader is reading on from the khatma place, **When** they turn forward past the
   last page of the wird, **Then** the wird is marked as read, a short message says so and
   offers Undo, and the place moves into the next wird.
4. **Given** that message, **When** the reader taps Undo, **Then** the wird is unread again and
   the place is its last page.
5. **Given** the reader looks a few pages ahead and turns back to where they were, **When**
   they stop, **Then** the khatma place is the page they stopped on.
6. **Given** the reader read from a printed Mushaf up to an ayah, **When** they long-press that
   ayah in the app, choose "Set khatma place here" and confirm, **Then** the wird that holds
   that ayah is the current wird, every wird before it is read, and the khatma continues from
   that ayah's page.
7. **Given** the reader sets the place at an ayah in a wird that was already read, and
   confirms, **When** they look at Khatma, **Then** that wird and the wirds after it are unread
   again.
8. **Given** a recitation is playing and the page follows it past the end of the wird,
   **When** the reader looks at Khatma, **Then** the wird is not marked as read and the place
   has not moved.
9. **Given** the reader read today's wird from a printed Mushaf, **When** they tap Done on the
   Khatma screen without opening the Mushaf, **Then** the wird is read.

---

### User Story 3 - Be reminded once a day (Priority: P2)

The reader turns on the reminder and picks a time, for example after Fajr. Each day at that time,
if they have not read a wird yet that day, the phone reminds them and names the wird. If they
hold a part of a group khatma that is not read, the same reminder names it too. They tap the
reminder and the Mushaf opens at their place.

**Why this priority**: A reminder is what keeps a khatma going for a month or more. The feature
is usable without it, so it comes after the two stories above.

**Independent Test**: Turn on the reminder for a time two minutes ahead, lock the phone and wait.
Tap the reminder. The next day, read the wird before the time and check that no reminder comes.
Restart the phone, leave the app closed for 7 days and check a reminder comes each day.

**Acceptance Scenarios**:

1. **Given** a reader who has not used the reminder, **When** they look at it, **Then** it is
   off.
2. **Given** the reminder is off, **When** the reader turns it on, **Then** the app asks for
   notification permission at that moment if it does not have it, and the reader picks a time.
3. **Given** the reader refused notifications, **When** they look at the reminder, **Then**
   their choice and time are kept, the screen says reminders are blocked, and it explains how
   to allow them.
4. **Given** the reminder is on and no wird was read today, **When** the time comes with the
   phone locked and the app closed, **Then** a reminder names the current wird (for example
   "Today's wird: Juz 3, pages 42 to 62"), with the phone's usual notification sound.
5. **Given** a wird was read today before the reminder time and no group part is waiting,
   **When** the time comes, **Then** no reminder is shown.
6. **Given** the reader holds a group part that is not read, **When** the time comes, **Then**
   a reminder names that part and its khatma, even when a wird was read that day.
7. **Given** a reminder that names one thing, **When** the reader taps it, **Then** the app
   opens with the Mushaf at that wird's or part's place.
8. **Given** the reader does not open the app for 7 days, **When** each day's time comes,
   **Then** a reminder is shown each day, including after the phone has restarted.
9. **Given** the personal khatma is paused, finished, ended or not started yet, and no group
   part is waiting, **When** the time comes, **Then** no reminder is shown.
10. **Given** the reader changes the reminder time, **When** the next reminder is due, **Then**
    it comes at the new time, and never twice in one day.
11. **Given** the web app, **When** the reader opens Khatma, **Then** everything else works as
    on the phone, there is no reminder setting, and the screen says reminders are available in
    the phone apps.

---

### User Story 4 - See how the khatma is going and change it (Priority: P2)

The reader sees how many wirds and pages they have read, how many are left, the date they
planned to finish and the date they will finish at one wird a day. When they miss some days, the
app does not change the wirds and does not scold. It shows the new finish date. The reader can
read more than one wird in a day, change the plan for what is left, pause the khatma while
travelling or unwell, or end it.

**Why this priority**: A real khatma rarely goes exactly to plan. The reader needs honest numbers
and a simple way to adjust, but can read the wirds of Story 1 without them.

**Independent Test**: Start a 30-day khatma, read 3 wirds over 5 days and check the dates shown.
Read two wirds in one day. Change the plan to finish on the first planned date. Pause for 3
days, resume and check the dates and the reminder.

**Acceptance Scenarios**:

1. **Given** a 30-day khatma on its sixth day, with 3 wirds read and none of them today,
   **When** the reader opens Khatma, **Then** it shows 3 of 30 wirds read, the pages read and
   left, and an expected finish date 2 days after the planned date.
2. **Given** a wird was read today, **When** the reader looks at Khatma, **Then** it says
   today's wird is done, shows the next wird and lets them read it now.
3. **Given** the reader reads two wirds in one day, **When** they look at Khatma, **Then** both
   are read and the finish date is one day earlier.
4. **Given** the reader chooses to change the plan and picks a finish date, **When** the app
   shows the new daily amount and they confirm, **Then** everything from the khatma place to
   the end is divided again, and what was read stays read.
5. **Given** the reader pauses the khatma, **When** days pass, **Then** no reminder is shown
   for it and Khatma says it is paused.
6. **Given** a khatma paused for 3 days, **When** the reader resumes it, **Then** the planned
   finish date is 3 days later than before and the reminder works again.
7. **Given** the reader ends the khatma and confirms, **When** they look at Khatma, **Then**
   there is no personal khatma, nothing is added to the record, and their reading position and
   bookmarks are unchanged.
8. **Given** a khatma, **When** the reader opens its list of wirds, **Then** each wird shows
   its range and whether and when it was read, and tapping one opens its first page.

---

### User Story 5 - Read the Quran together through a link (Priority: P2)

A reader wants their family to finish a khatma together before Friday. In Khatma they start a
group khatma, give it a title, type the name the others will see, and choose thirty ajza'. The
app gives them a link, and they share it in the family's chat. Each relative taps the link. It
opens in Mathani if they have it and in the browser if they do not, with nothing to install and
no account. They type a name once and take a free juz, and it shows under their name for
everyone. They read it in the Mushaf, where its end is marked, and tap Done. Everyone sees how
many parts are free, taken and read. When the last part is read, everyone sees that the khatma
is complete.

**Why this priority**: It is the group half of the feature. It reuses the reading pieces of
Stories 1 and 2: opening a portion, the mark at its end, and its place. It cannot be released
without Story 6.

**Independent Test**: On one phone, start a group khatma and share the link. On a second phone
with Mathani, and on a third device with only a browser, open the link, give names and take
parts. On two devices, take the same part at the same moment. Read and mark parts, one of them
with the network off. Check that all three devices show the same state, and that the khatma is
complete when the last part is read.

**Acceptance Scenarios**:

1. **Given** a reader with a connection, **When** they start a group khatma with a title, their
   name and thirty ajza', **Then** it is created with 30 free parts, and the app offers to
   share its link and says that anyone who has the link can see the names and take parts.
2. **Given** the link in a chat app, **When** a person with Mathani installed taps it, **Then**
   the group khatma opens in the app.
3. **Given** the link, **When** a person without Mathani taps it, **Then** the group khatma
   opens in the browser, with nothing to install and no account.
4. **Given** anyone who has the link, **When** they open the group khatma, **Then** they see
   its title, its finish date if it has one, how many parts are free, taken and read, and each
   part with its range and the name of whoever took it.
5. **Given** a person who has not given a name on this device, **When** they take a free part,
   **Then** they are told their name will be seen by everyone who has the link, they type a
   name, and the part shows under that name for everyone. The name is offered again the next
   time they join a group khatma.
6. **Given** two people take the same free part at the same moment, **When** the server
   answers, **Then** one of them holds it, and the other is told it was just taken and sees
   the current list.
7. **Given** a part the reader took, **When** they tap Read, **Then** the Mushaf opens at the
   part's first page, and the ayah where the part ends is marked as for a wird.
8. **Given** a part the reader took, **When** they mark it as read, **Then** it shows as read
   under their name for everyone. **When** they undo the mark, **Then** it shows as taken
   again.
9. **Given** the group khatma is open on two devices, **When** one of them changes a part,
   **Then** the other shows the change within 30 seconds without being touched.
10. **Given** the reader has no connection, **When** they mark their part as read, **Then** it
    shows as read on their device and reaches the others when the connection returns.
11. **Given** the reader has no connection, **When** they try to take a part, **Then** the app
    says a connection is needed and nothing changes.
12. **Given** the reader has no connection, **When** they open a group khatma they opened
    before, **Then** the last state the device saw shows at once, with a note that it may be
    out of date.
13. **Given** a reader took a part by mistake, **When** they give it back, **Then** it is free
    for everyone.
14. **Given** the last part is marked as read, **When** anyone opens the group khatma,
    **Then** it shows as complete, with the date.
15. **Given** a participant leaves a group khatma, **When** others look at it, **Then** the
    name is gone, the parts that person had not read are free, and the parts they read stay
    read without a name.
16. **Given** the reader reads on past the end of a group part they took, **When** they have
    not tapped Done, **Then** the part is not marked as read.
17. **Given** a reader starts a group khatma in sixty ahzab, **When** it is created, **Then**
    it has 60 free parts of one hizb each.
18. **Given** a link or a code copied from a chat, **When** the reader pastes it in Khatma,
    **Then** the group khatma opens in the app.
19. **Given** a participant, **When** they share the group khatma, **Then** the phone's share
    sheet opens with the link and a short text that names the khatma and Mathani.
20. **Given** a reader with a personal khatma who holds parts in two group khatmas, **When**
    they open Khatma, **Then** it shows the personal khatma and lists each group khatma with
    its title, its progress and the reader's own parts that are not read.

---

### User Story 6 - Keep a group khatma safe and in order (Priority: P2)

A group khatma shows a title and names that people typed to everyone who has the link. So before
anyone starts or joins one, they accept short terms. The app refuses offensive names and titles.
Anyone who sees a group khatma can report a name or the whole khatma to Mathani, and it is hidden
for them at once. The organiser can free a part that someone took and did not read, remove a
participant, and delete the khatma. Mathani can remove a name or a khatma and block whoever
posted it. A group khatma does not stay on the server for ever.

**Why this priority**: The App Store and Google Play require these safeguards of any app in
which people see what others typed, so Story 5 cannot be released without this story. Also, a
part that someone took and abandoned would stop a khatma from ever being complete.

**Independent Test**: Join a group khatma on a new device and check the terms come first. Try an
offensive name and a name with a link. Report a name from a second device and check what the
owner receives. As the organiser, free a part, remove a participant and delete the khatma, and
check each from another device. Remove a khatma as the owner and check that its organiser is
blocked.

**Acceptance Scenarios**:

1. **Given** a person who has not used a group khatma on this device, **When** they start one
   or take a part, **Then** they must first accept the group khatma terms, which say what
   others will see and that offensive names and titles are not allowed.
2. **Given** a name or a title that contains a word from the list of offensive words, or a
   link, **When** the person submits it, **Then** it is refused with a message and nothing is
   saved.
3. **Given** a person sees an offensive name, **When** they report it, **Then** the name is
   hidden on their device at once, they are told the report was sent, and the report reaches
   the owner with what is needed to find the name.
4. **Given** a report, **When** the owner removes the name or the khatma, **Then** it is gone
   for everyone, and the device or browser that posted it can no longer start or join group
   khatmas.
5. **Given** a part that was taken and not read, **When** the organiser frees it, **Then** it
   is free for everyone.
6. **Given** the organiser removes a participant, **When** others look at the khatma, **Then**
   the name is gone and that person's unread parts are free, and that device or browser cannot
   join this khatma again.
7. **Given** the organiser deletes the khatma and confirms, **When** anyone opens its link,
   **Then** it says the khatma no longer exists, and its title and names are no longer on the
   server.
8. **Given** a khatma that has been complete for 30 days, or unchanged for 90 days, **When**
   anyone opens its link, **Then** it says the khatma no longer exists.
9. **Given** a person who is not the organiser, **When** they look at the group khatma,
   **Then** the organiser's actions are not offered, and the server refuses them if tried.
10. **Given** the About section or the group khatma terms, **When** the reader looks at them,
    **Then** they show an address at which to reach Mathani.
11. **Given** a device that already organises as many group khatmas as the server allows,
    **When** its reader starts another, **Then** the app says the limit is reached and nothing
    is created.

---

### User Story 7 - Organise for people who do not use the link (Priority: P3)

Some relatives read from a printed Mushaf and do not use a phone for it. The organiser gives a
part to a name they type, and marks it as read when that person says they have finished. The
organiser can also mark any part as read or not read, and change the title or the finish date.

**Why this priority**: It lets one group khatma include everyone in a family. The group khatma
of Stories 5 and 6 works without it for people who use the link.

**Independent Test**: As the organiser, give two parts to typed names, mark one as read, mark a
participant's part as read and then not read, change the title and the finish date, and check
each change on another device.

**Acceptance Scenarios**:

1. **Given** a free part, **When** the organiser gives it to a name they type, **Then** it
   shows under that name for everyone.
2. **Given** any taken part, **When** the organiser marks it as read or not read, **Then**
   everyone sees the change.
3. **Given** the organiser changes the title or the finish date, **When** others open the
   khatma, **Then** they see the new one, and a title is checked as in Story 6.
4. **Given** a name the organiser typed, **When** anyone reports it, **Then** it is handled as
   any other name.

---

### User Story 8 - Finish a personal khatma and keep a record (Priority: P3)

The reader marks the last wird as read. The app says the khatma is complete and shows when it
started, when it ended and how many days it took. The khatma is added to a record of finished
khatmas, and the reader can start the next one with the same plan in one tap.

**Why this priority**: It closes the journey and gives the reader a history, but it only matters
after weeks of use of the other stories.

**Independent Test**: Start a one-day khatma, mark its only wird as read, check the completion
screen and the record, start a new khatma from it, and restart the app.

**Acceptance Scenarios**:

1. **Given** the last wird of a khatma, **When** the reader marks it as read, **Then** the app
   shows that the khatma is complete, with its start date, end date and number of days.
2. **Given** a finished khatma, **When** the reader opens Khatma, **Then** the record lists it,
   newest first, and shows how many khatmas were finished in total.
3. **Given** the completion screen or the record, **When** the reader chooses to start a new
   khatma, **Then** the plan choices open with the previous plan selected, and the reminder is
   on or off, at the same time, as it was.
4. **Given** a record entry, **When** the reader deletes it and confirms, **Then** it is gone
   and the total is one less.
5. **Given** a record, **When** the app is restarted or updated, **Then** the record is kept.

---

### Edge Cases

**Personal khatma**

- **A wird that ends in the middle of a page**: 4 of the 30 juz and most hizb and quarter marks
  start in the middle of a page. The mark shows at the exact ayah, and the next wird starts on
  the same page.
- **Wirds of different sizes**: a juz is 20 to 23 pages, and the seven-day plan's wirds are 72
  to 106 pages, counting every page a wird touches. Each wird shows its own number of pages.
- **A plan that starts in the middle**: the first wird can be shorter than the others.
- **Start date in the future**: Khatma shows the date it starts. Reminders begin on that date.
  Reading before it counts.
- **Reading at night**: a day is the calendar day of the phone's clock. A wird read after
  midnight counts for the new day.
- **Clock or time zone changed**: the dates shown and the reminder follow the phone's new time.
  No wird is lost or counted twice.
- **No reading for weeks**: nothing changes by itself. Reminders continue as FR-021 requires
  until the reader pauses the khatma or turns the reminder off.
- **Looking ahead past the end of the wird**: the wird is marked as read (Story 2, scenario 3).
  The reader can undo it, or set the place by hand later.
- **Reading starts somewhere else in the wird**: if the reader opens a later page of the wird
  directly and reads on from there, the place does not follow. The Done action at the end of
  the wird still works, and "Set khatma place here" moves the place.
- **Two facing pages (specs/012)**: both pages count as on screen. The khatma place is the
  first of the two. Turning forward past the two pages that hold the end of the wird marks it
  as read.
- **Phone turned sideways (specs/013)**: the end mark scrolls with the page.
- **Flowing layout**: the end mark follows the last ayah of the wird, and the place follows
  the reader as they scroll on from it.
- **During a memorization session**: the end mark and the Done action are not shown, no hidden
  word is revealed by them, and no khatma changes.
- **The reminder time comes while the reader is reading what it would name**: the reminder
  does not interrupt them.
- **A reminder still in the phone's notification list when everything it names is read**: it
  is removed.
- **Phone off at the reminder time**: that day's reminder need not come late. The next day's
  comes as usual.
- **Notifications blocked later in the phone's settings**: Khatma says reminders are blocked
  and how to allow them.
- **Do not disturb, focus modes, battery saving**: the phone may silence or delay the reminder.
  The app does not promise a sound.
- **A reminder tapped during a memorization session**: the app opens without moving the page
  or ending the session.
- **Starting a personal khatma while one is in progress**: the reader must finish or end the
  current one first, and the app says so.
- **A one-day plan**: one wird covers the whole Quran.
- **A page a day**: 604 wirds. The list of wirds stays smooth.
- **Language changed during a khatma**: names of surahs and numbers follow the interface
  language. The Quran text does not change.
- **App deleted**: the personal khatma and the record are lost, unless the phone's own backup
  restores the app's data.

**Group khatma**

- **The link opens in a browser although Mathani is installed**: some apps open links in their
  own built-in browser. The person can take part there, or paste the link in the app. A part
  taken in a browser belongs to that browser: the app on the same phone is a different
  participant.
- **A browser the web app does not support**: the link shows the page of specs/008 that names
  the supported browsers and the store apps.
- **App deleted, browser data cleared, or a new phone**: the person can no longer change the
  parts they took. The organiser can free them or mark them as read. If it happens to the
  organiser, nobody has the organiser's actions: the khatma goes on, and it is removed as
  FR-066 says.
- **Two people with the same name**: allowed. Each person's own parts are shown as theirs on
  their own device.
- **One person takes every part**: allowed. The organiser can free parts.
- **A part freed or given to someone else while its reader was offline**: a mark that was
  waiting to be sent is refused, and the reader is told the part is no longer theirs.
- **A khatma deleted or removed while someone has it open**: the screen says it no longer
  exists, and it leaves their list.
- **The finish date passes with parts not read**: nothing changes by itself. The screen shows
  that the date has passed.
- **A phone with the wrong date**: the dates shown for parts are the server's.
- **A slow connection**: every action shows that it is in progress, and ends with the change or
  with a message. A part is never left half taken.
- **The server cannot be reached**: the personal khatma, the Mushaf and reading a part the
  reader already took all work as usual.
- **The reminder and a part that changed on the server**: the reminder uses the last state the
  device saw. It can name a part the reader no longer holds until the app is next opened.
- **The same pages in the personal wird and a group part**: each keeps its own place and is
  marked as read on its own. The Done action says which one it marks.
- **A name or title in another script or direction**: it shows as typed, and the text around
  it keeps the interface's direction.
- **Reporting the whole khatma**: the khatma is hidden for the reporter and leaves their list.
- **An app too old for a later change to group khatmas**: it says an update is needed, and the
  link still works in the browser.
- **Web**: site data cleared or private browsing loses the personal khatma, like bookmarks
  (specs/008), and the person's hold on their group parts. The phone app and the web app keep
  separate khatmas.

## Requirements *(mandatory)*

### Functional Requirements

**Personal khatma and plan**

- **FR-001**: The reader MUST be able to start a khatma: a reading of the Quran from a start
  point to the end of Surah An-Nas, divided into wirds in Mushaf order, one wird for each day.
- **FR-002**: The reader MUST be able to choose the plan in any of these ways. For every choice
  the app MUST show the number of days and the finish date before the reader confirms.
  - A daily amount by the Mushaf's marks, at least: a quarter hizb, half a hizb, a hizb, a juz,
    two ajza', three ajza' and ten ajza' a day.
  - Seven days, by whole surahs.
  - A custom plan: a number of days from 1 to 604, a number of pages a day from 1 to 604, or a
    finish date.
- **FR-003**: Wirds MUST be made as follows.
  - Every wird is a run of whole ayat. Together the wirds cover every ayah from the start point
    to the end of the Quran exactly once, in order.
  - With a daily amount by marks, wirds begin and end at the juz, hizb and quarter marks shown
    in the Ajza' index (specs/001 FR-011).
  - With seven days, the wirds begin at Al-Fatiha, Al-Ma'idah, Yunus, Al-Isra, Ash-Shu'ara,
    As-Saffat and Qaf.
  - With a custom plan, every wird ends at the end of a page, and the wirds' sizes differ by
    at most one page.
- **FR-004**: The start point MUST be the beginning of the Quran by default. The reader MUST be
  able to choose the page they are on, or any juz, surah or page. When the start point is not
  where a wird of the chosen plan would begin, the first wird runs from the start point to the
  next such place, so it can be shorter than the others. The start date MUST be today by
  default, and the reader MUST be able to choose a later date.
- **FR-005**: There MUST be at most one personal khatma in progress. Group khatmas are
  separate: a reader can take part in them with or without a personal khatma (FR-057).
- **FR-006**: The personal khatma, its place, the reminder settings and the record MUST be kept
  on the device, MUST survive restarts and app updates, and MUST work fully offline.

**Daily wird**

- **FR-007**: The Khatma screen MUST show the current wird, which is the first wird not read
  yet: its number out of the total, where it starts and ends (surah name, ayah number and
  page), its number of pages, and whether a wird was already read today.
- **FR-008**: From the Khatma screen, one action (Read, or Continue once the wird is begun)
  MUST open the Mushaf at the khatma place, in the reader's reading layout.
- **FR-009**: The Khatma screen MUST be reachable from the reading screen within two taps, and
  the khatma place or a group khatma within three.
- **FR-010**: On the Mushaf, in both layouts, the ayah where the current wird ends MUST be
  marked. The mark MUST NOT move, cover or change any Quran text or page detail. It MUST be
  clear in the day and night themes, and screen readers MUST announce it.
- **FR-011**: While a page of the current wird is on screen and the reading controls are
  visible, they MUST show how many pages of the wird are left.
- **FR-012**: The reader MUST be able to mark the current wird as read from the reading screen,
  without leaving it, whenever the page where the wird ends is on screen. They MUST also be
  able to mark it as read from the Khatma screen at any time.

**Keeping the place**

- **FR-013**: The khatma place MUST be separate from the reading position (specs/001 FR-013)
  and from bookmarks. Moving one MUST NOT move the others.
- **FR-014**: The khatma place is a page of the current wird, at first its first page. It MUST
  move with the reader while they turn pages one by one, or scroll, from it, forward or back,
  inside the current wird.
- **FR-015**: Opening another page directly MUST NOT move the khatma place. This covers the
  index, search, bookmarks, go-to, the similar-ayah sheet, and pages shown by a recitation or a
  memorization session.
- **FR-016**: When the reader, reading on from the khatma place, turns forward past the last
  page of the current wird, the wird MUST be marked as read and the place MUST move into the
  next wird. A message MUST say so and offer Undo. The same Undo MUST be offered after the
  reader marks a wird as read by hand. A recitation or a memorization session MUST NOT mark a
  wird as read.
- **FR-017**: A long press on an ayah MUST offer "Set khatma place here" while a personal
  khatma is in progress. After the reader confirms, the wird that holds that ayah is the
  current wird, every wird before it is read, every wird after it is unread, and the place is
  that ayah's page. The confirmation MUST say how many wirds will change.
- **FR-018**: Each read wird MUST record the day it was marked as read. A day counts as read
  when at least one wird was marked as read on it.

**Reminder**

- **FR-019**: The reader MUST be able to turn on one daily reminder and choose its time. It
  MUST be off at first.
- **FR-020**: Notification permission MUST be requested only when the reader turns the reminder
  on. If it is refused, the choice and the time MUST be kept, and the screen MUST say that
  reminders are blocked and how to allow them.
- **FR-021**: A reminder is due on a day when a personal khatma is in progress and that day is
  not read yet, or when the reader holds a group part that is not read. On such a day one
  reminder MUST be shown at the chosen time. It MUST name what is waiting: the current wird,
  the group parts, or both. It MUST come with the app closed and the phone locked, and after
  the phone restarts, for at least 7 days without the app being opened.
- **FR-022**: No reminder MUST be shown on a day when none is due, and none twice in one day.
  A personal khatma that is paused, finished, ended or not started yet is never the reason for
  a reminder.
- **FR-023**: Tapping a reminder that names one wird or part MUST open the app with the Mushaf
  at its place. Tapping one that names more MUST open the Khatma screen. During a memorization
  session it MUST open the app without moving the page or ending the session.
- **FR-024**: After any change to the reminder time, the plan, the place or the reader's group
  parts, every later reminder MUST use the new time and name what is waiting. For group parts
  it uses the last state the device saw.
- **FR-025**: The reminder setting and its time MUST belong to the reader, not to one khatma,
  and MUST be kept from one khatma to the next.
- **FR-026**: The reminder MUST use the phone's own notification sound and settings. The app
  MUST NOT add its own sounds for it.

**Progress and changes**

- **FR-027**: The Khatma screen MUST show the wirds read out of the total, the pages read and
  left, the share read as a percentage, the start date, the planned finish date and the
  expected finish date. The expected finish date is the day the last wird is reached at one
  wird a day, counting from today when today is not read yet, and from tomorrow when it is.
- **FR-028**: Missed days MUST NOT change the wirds. The current wird stays the first wird not
  read yet, and the expected finish date moves later. The reader MUST be able to read more than
  one wird in a day, and the expected finish date then moves earlier.
- **FR-029**: Wording about missed days MUST be neutral: dates and amounts only. The feature
  MUST NOT show streaks, scores or rankings, for one reader or between the people of a group.
- **FR-030**: The reader MUST be able to change the plan of a khatma in progress with the same
  choices as FR-002. Everything from the khatma place to the end is divided again, what was
  read stays read, and the new number of days and finish date are shown before the reader
  confirms.
- **FR-031**: The reader MUST be able to pause and resume a personal khatma. While it is
  paused, it causes no reminder. On resume, the planned finish date moves later by the number
  of days it was paused.
- **FR-032**: The reader MUST be able to end a personal khatma after a confirmation. An ended
  khatma is not added to the record. Ending it MUST NOT change the reading position or
  bookmarks.
- **FR-033**: The reader MUST be able to see the list of all wirds of the khatma, each with its
  range, its number of pages, and whether and when it was read. Tapping a wird MUST open its
  first page in the Mushaf.

**Completion and record**

- **FR-034**: When the last wird is marked as read, the app MUST show that the khatma is
  complete, with its start date, end date and number of days, and MUST add it to the record.
- **FR-035**: The Khatma screen MUST list the finished personal khatmas, newest first, each
  with its start date, end date, number of days and plan, and MUST show how many there are.
- **FR-036**: From the completion screen and from the record, the reader MUST be able to start
  a new khatma with the previous plan already selected.
- **FR-037**: The reader MUST be able to delete a record entry after a confirmation.

**Group khatma: starting and inviting**

- **FR-044**: A reader MUST be able to start a group khatma: the whole Quran, once, divided
  into parts that several people share. It has a title, a division (30 ajza' by default, or 60
  ahzab), an optional finish date, and one organiser, who is the reader that started it.
  Starting one needs a connection.
- **FR-045**: Every group khatma MUST have an invitation link. The organiser and every
  participant MUST be able to share it through the phone's share sheet, or copy it where there
  is none, with a short text that names the khatma and Mathani. Before the organiser first
  shares it, the app MUST say that anyone who has the link can see the names and take parts.
- **FR-046**: On an iPhone or Android phone with Mathani installed, opening the link MUST open
  the group khatma in the app. Without Mathani, the link MUST open the group khatma in the web
  app, with nothing to install. The reader MUST also be able to open a group khatma in the app
  by pasting its link or its code.
- **FR-047**: No account, sign-in, email address or phone number MUST be needed to start, open
  or take part in a group khatma.

**Group khatma: taking part**

- **FR-048**: Anyone who has the link MUST be able to see the group khatma: its title, its
  finish date, how many parts are free, taken and read, and every part with its number, its
  range (surah, ayah and page) and the name of whoever took or read it.
- **FR-049**: To take a part, a person gives a name of 1 to 30 characters. It is asked once on
  a device or browser, remembered there, and offered again for later group khatmas. Before the
  first time, the app MUST say that the name will be seen by everyone who has the link.
- **FR-050**: A participant MUST be able to take any free part, and more than one. One part is
  held by one participant only. When two people take the same part at the same moment, exactly
  one MUST get it, and the other MUST be told and shown the current state.
- **FR-051**: A participant MUST be able to give back a part they took and have not read, to
  mark their part as read, and to undo that mark while the khatma is not complete.
- **FR-052**: A part the reader took MUST work in the Mushaf as a wird does: Read or Continue
  opens it (FR-008), its end is marked (FR-010), the controls show the pages left (FR-011), it
  can be marked as read from the reading screen at its end (FR-012), and it keeps its own place
  by the rules of FR-013 to FR-015. Unlike a wird, a group part MUST be marked as read only by
  a tap, never by reading on past its end, because the whole group sees the mark.
- **FR-053**: A part marked as read with no connection MUST show as read on the reader's device
  and MUST be sent when the connection returns. Taking a part, giving one back, and every
  organiser action need a connection, and the app MUST say so when there is none.
- **FR-054**: While a group khatma is open on screen, changes made by others MUST appear within
  30 seconds without any action, and the reader MUST be able to refresh by hand. The app MUST
  ask the server about group khatmas only while the Khatma screen or a group khatma is open,
  and to send a mark that was waiting (FR-053).
- **FR-055**: With no connection, a group khatma the device opened before MUST show the last
  state the device saw, at once, and say that it may be out of date.
- **FR-056**: When every part is read, the group khatma is complete. Everyone who opens it MUST
  see that, with the date. After that, only the organiser can change a part.
- **FR-057**: A reader MUST be able to take part in more than one group khatma, with or without
  a personal khatma. The Khatma screen MUST list them, each with its title, its progress and
  the reader's own parts that are not read, and MUST offer to start one and to open one from a
  link or code.
- **FR-058**: A participant MUST be able to leave a group khatma. Their name is removed for
  everyone, the parts they had not read become free, the parts they read stay read without a
  name, and the khatma leaves their list. The organiser cannot leave: they delete the khatma
  (FR-062).

**Group khatma: safety, order and data**

- **FR-059**: Before a person starts or joins their first group khatma on a device or browser,
  they MUST accept the group khatma terms. The terms MUST say what others will see, that
  offensive or abusive names and titles are not tolerated and are removed, how to report, and
  how to reach Mathani.
- **FR-060**: The only text a person can type into a group khatma is a name and, for the
  organiser, a title of 1 to 60 characters. The server MUST refuse a name or title that is
  empty, too long, contains a link, or contains a word from Mathani's list of offensive words
  in Arabic and English. A group khatma has no comments, messages or pictures.
- **FR-061**: Anyone who can see a group khatma MUST be able to report a name, or the whole
  khatma, to Mathani from inside the app, in three taps or fewer. What they reported MUST be
  hidden on their device at once. The report MUST reach the owner with what is needed to find
  the khatma and the name.
- **FR-062**: The organiser MUST be able to free any taken part, remove a participant, and
  delete the khatma after a confirmation. A removed participant's name is removed for
  everyone, their unread parts become free, and their device or browser MUST NOT be able to
  join that khatma again. A deleted khatma MUST stop opening for everyone, and its link MUST
  say that it no longer exists.
- **FR-063**: Mathani MUST be able to remove a name or a whole group khatma, and to block the
  device or browser that posted it from starting or joining group khatmas. Every report MUST
  be reviewed within 24 hours.
- **FR-064**: Only the organiser's device or browser MUST be able to use the organiser's
  actions. Only a participant's own device or browser, or the organiser, MUST be able to change
  that participant's parts. A link MUST NOT be guessable, and knowing one link MUST NOT help to
  find another.
- **FR-065**: For a group khatma, Mathani's server MUST keep only its title, division and
  finish date, the dates it was created and last changed, each part's state and date, the
  participants' names, and the random keys that tell the organiser and each participant apart.
  It MUST NOT keep location, contacts, the phone's own identifiers, or anything the reader does
  outside the group khatma. It MUST NOT keep anything about a reader who never starts or joins
  a group khatma.
- **FR-066**: A group khatma MUST be removed from the server, with every name in it, 30 days
  after it is complete, and after 90 days without any change. Deleting a khatma, leaving it,
  and removing a participant MUST remove the names concerned at once.
- **FR-067**: The server MUST limit how many group khatmas one device or browser can organise
  at a time, and how fast it can start khatmas, take parts and send reports. The app MUST say
  so when a limit is reached.
- **FR-068**: An address at which to reach Mathani MUST be shown in the About section and in
  the group khatma terms.
- **FR-069**: Before the release that carries the group khatma, the privacy policy, the App
  Privacy details, the Data safety form, the age-rating answers and the store listings' "no
  data collected" wording MUST be updated to describe it.

**Group khatma: on behalf of others**

- **FR-070**: The organiser MUST be able to give a free part to a name they type, for a person
  who does not use the link, and to take it back. Such a name follows FR-060 and can be
  reported as any other.
- **FR-071**: The organiser MUST be able to mark any taken part as read or not read.
- **FR-072**: The organiser MUST be able to change the title and the finish date. The title
  follows FR-060.

**Privacy and quality**

- **FR-038**: The feature MUST NOT add accounts, analytics or ads. The personal khatma, its
  place, the reminder settings and the record MUST NOT leave the device. A group khatma sends
  to Mathani's server only what FR-065 lists.
- **FR-039**: Nothing from this feature MUST run, and nothing MUST be sent or fetched, before
  the Mushaf appears. The app MUST NOT ask for any permission at startup.
- **FR-040**: The feature MUST work in Arabic and English, right-to-left and left-to-right, in
  the day and night themes, with large text, VoiceOver and TalkBack, and with touch targets of
  at least 44×44 pt on iPhone and 48×48 dp on Android. It targets iOS 15.0+ and Android 7.0
  (API 24)+.
- **FR-041**: The end mark, the Done action and the place, for wirds and for group parts, MUST
  work in the Mushaf layout, the flowing layout, the two facing pages of specs/012 and the
  sideways page of specs/013. The Khatma screen and the group khatma MUST stay usable when the
  phone is sideways (specs/013 FR-013).
- **FR-042**: In the web app (specs/008), everything in this spec MUST work except the
  reminder. The Khatma screen there MUST say that reminders are available in the phone apps.
  Starting a personal khatma, and starting or joining a group khatma, MUST ask the browser to
  keep the site's data, as the first bookmark does (specs/008 FR-014).
- **FR-043**: The onboarding tour (specs/005) MUST gain one stop that introduces Khatma, in the
  first-run tour and in the tour replayed from Settings.

### Key Entities *(include if feature involves data)*

- **Personal khatma**: one reading of the Quran from a start point to its end. It has a start
  point, a start date, a plan, a list of wirds, a place, a planned finish date, and a state:
  not started yet, in progress, paused or finished. At most one is in progress. It is kept on
  the device.
- **Plan**: how the personal khatma is divided: a daily amount by marks, seven days by surahs,
  or a custom number of days or pages a day.
- **Wird**: one day's portion. It has a number, a first and a last ayah, a number of pages,
  and the day it was marked as read, if it was.
- **Khatma place**: the page of the current wird, or of a group part, where the reader will
  continue. It is separate from the reading position and from bookmarks.
- **Reminder setting**: on or off, and a time of day. It belongs to the reader, not to one
  khatma.
- **Record entry**: a finished personal khatma: start point, start date, end date, number of
  days and plan.
- **Group khatma**: one reading of the whole Quran shared among people. It has a title, a
  division, an optional finish date, a list of parts, an organiser, an invitation link, the
  dates it was created and last changed, and a state: open or complete. It is kept on
  Mathani's server until FR-066 removes it.
- **Part**: one juz or one hizb of a group khatma. It has a number, a first and a last ayah,
  and a state: free, taken or read, with the participant who holds it and the date it was
  read.
- **Participant**: a name shown on the parts a person holds. Either a person who uses the
  link, or a name the organiser typed for someone who does not.
- **Organiser**: the participant who started the group khatma, and the only one with the
  organiser's actions.
- **Key**: a random value made on a device or browser the first time its reader starts or
  joins a group khatma. It tells the server which parts are theirs and which khatmas they
  organise, and lets Mathani block abuse. It is not tied to an account, a phone number or the
  phone's own identifiers, and it is lost when the app is deleted or the browser's data is
  cleared.
- **Report**: a name or a group khatma that someone reported, with the date. It goes to the
  owner.
- **Group khatma terms**: the short rules a person accepts before starting or joining.

## Success Criteria *(mandatory)*

### Measurable Outcomes

**Personal khatma**

- **SC-001**: A reader who has never used the feature starts a "juz a day" khatma from the
  reading screen in under 30 seconds.
- **SC-002**: From the reading screen, the reader is back at the khatma place in 3 taps or
  fewer, in 100% of trials, including after reading elsewhere and after a restart.
- **SC-003**: For every plan the app offers and every start page, the wirds cover every ayah
  from the start point to the end of the Quran exactly once: 0 gaps and 0 overlaps.
- **SC-004**: In custom plans, wird sizes differ by at most one page. In plans by marks, every
  wird boundary is on a mark, apart from a start point chosen off a mark.
- **SC-005**: In 20 sessions that mix reading the wird with the index, search, bookmarks, a
  recitation and a memorization session elsewhere, the khatma place is the page where the
  reader stopped reading the wird in at least 19. No wird is marked as read by a recitation or
  a memorization session in any of them.
- **SC-006**: On one iPhone and one Android phone, locked, at least 19 of 20 reminders per
  phone are shown within 5 minutes of the chosen time, including on day 7 without opening the
  app and after a restart. 0 reminders are shown on a day when none is due.
- **SC-007**: The plan, the read wirds, the place, the reminder setting and the record are
  unchanged after 10 restarts and one app update.
- **SC-008**: Cold start stays at or under 2 seconds on the reference phones. Page turns stay
  at 60 fps with the end mark on screen. The Khatma screen responds to every tap within 100 ms,
  and a list of 604 wirds scrolls at 60 fps.
- **SC-009**: The store download grows by less than 1 MB on each platform.
- **SC-010**: Every story can be completed with VoiceOver and with TalkBack, in Arabic and in
  English.
- **SC-011**: In a test with at least 5 readers, at least 4 start a khatma, read a wird, and
  find their place the next day without help.
- **SC-012**: With the network watched during Stories 1 to 4 and 8, by a reader who never
  starts or opens a group khatma, the feature makes no request at all: nothing about the
  personal khatma is sent off the device.

**Group khatma**

- **SC-013**: An organiser starts a group khatma and reaches the share sheet in under 1 minute.
- **SC-014**: A person who has never used Mathani opens the link in a phone browser, gives a
  name and takes a part in under 2 minutes on a typical mobile connection, with nothing
  installed.
- **SC-015**: In 50 trials where two devices take the same free part at the same moment,
  exactly one holds it afterwards in all 50, and the other is told within 3 seconds.
- **SC-016**: While a group khatma is open, a change made on another device appears within 30
  seconds in at least 95 of 100 changes.
- **SC-017**: In 20 trials of marking a part as read with no connection, all 20 marks reach
  the others after the connection returns, and none is applied twice.
- **SC-018**: With 60 parts and 60 participants, every action on a group khatma gives feedback
  within 100 ms and is complete within 3 seconds on a typical mobile connection.
- **SC-019**: After a khatma is deleted, removed or expired, and after a participant leaves or
  is removed, none of the names concerned can be read from the server, in 10 trials of each.
- **SC-020**: A report is with the owner within 5 minutes of being sent, in 10 of 10 trials,
  and every report is reviewed within 24 hours.
- **SC-021**: 100% of names and titles that contain a word from the list of offensive words,
  or a link, are refused, in a test of at least 50 of each in Arabic and English.
- **SC-022**: The release that carries the group khatma is accepted by App Store and Google
  Play review, or any rejection is fixed within one resubmission.
- **SC-023**: In a test with at least 5 groups of 3 people, at least 4 groups complete a group
  khatma of 30 parts started from one link, without help.
- **SC-024**: In a test of 1,000,000 guessed links, none opens a group khatma.

## Options Considered

Research on 2026-11-15 looked at how other Quran apps handle a khatma, as their store listings
and help pages describe it. For a personal khatma: Khatmah, Wirdy, Mushaf Al-Tanzil, Tarteel,
Quran.com and the GTAF Quran App. They share one pattern: the reader picks a duration or a
daily amount, and the app gives a daily wird, a reminder and a progress figure. They differ in
how reading is recorded and in what happens after a missed day. For a group khatma: Khitmah and
Khatma Al-Salihin, in which people reserve ajza' or ahzab and mark them as complete. The table
lists the options found and what this spec does with each.

| Option | Decision | Reason |
|--------|----------|--------|
| Daily amount by the Mushaf's marks | In | What most readers follow: a juz or a hizb a day |
| Seven days by whole surahs | In | The weekly division known as «فمي بشوق» |
| Custom days, pages a day or finish date | In | Covers a 29-day Ramadan and slow plans |
| Start from the middle, start on a later date | In | Readers who are mid-khatma on paper; plans made before Ramadan |
| Place that follows reading, Done, set by hand | In | Owner's choice, 2026-11-15 |
| Reading recorded by a tap only, or by page turns only | No | The first forgets a place; the second counts browsing |
| Wirds stay, finish date moves, change by hand | In | Owner's choice, 2026-11-15 |
| Finish date fixed, missed reading spread over the days left | No | Wirds would grow and leave the marks; "change plan" does it on request |
| Daily reminder | In | The reminder promised in specs/001 |
| Pause | In | Travel, illness and other breaks, without counting them as late |
| Record of finished personal khatmas | In | Small, and readers value it |
| Live group khatma through a link | In | Owner's choice, 2026-11-15 |
| Group list kept only on the organiser's phone | No | Replaced by the live group khatma; FR-070 keeps typed names |
| Accounts or sign-in for a group khatma | No | A link and a name are enough (FR-047) |
| Public group khatmas that anyone can find | No | Only people with the link, so no strangers |
| Comments, du'a text or chat in a group khatma | No | More text to moderate; a title and names only (FR-060) |
| Group parts smaller than a hizb | Later | 30 or 60 parts cover families and most groups |
| Repeating rounds, parts rotating each week | Later | Common in weekly groups; needs its own rules |
| Notices sent to participants by the server | Later | Needs a push service; the daily reminder covers a reader's own parts |
| Passing on the organiser's role, several organisers | Later | The organiser's tools cover a first version |
| Group khatmas in the reader's record | Later | The record is for personal khatmas for now |
| Several personal khatmas at once | Later | One place and one plan are simpler; add if readers ask |
| Reminders after each prayer, wird split in five | Later | Fits specs/009, but needs a prayer place and many more alerts |
| Rest days in the week | Later | Few readers need it; pause covers long breaks |
| Part of the Quran only (a juz, some surahs) | Later | A reading plan, not a khatma |
| Listening counted as reading | Later | A recitation left playing would count; a listener taps Done instead |
| Memorization revision plans | Later | A separate feature on top of specs/006 |
| Sharing a personal wird or completion as text | Later | Small; not needed to run a khatma |
| Home-screen widget, reading-time estimate | Later | Platform work on each phone; not needed to run a khatma |
| Streaks, points, charts, rankings | No | Progress is shown as dates and amounts only (FR-029) |
| A du'a shown at completion | No | A content decision for the owner: which text and from which source |
| Hijri dates, Ramadan dated by the app | No | The Hijri calendar is out of scope (specs/009); the reader picks dates |
| Sync of a personal khatma between devices, backup file | No | No accounts (specs/001 FR-027, specs/008) |

## Assumptions

**Both**

- **Words**: "khatma" and "wird" are used in English as they are. In Arabic the screen is
  «الختمة», the daily portion is «الورد» and a group khatma is «ختمة جماعية». The final
  interface wording is set in the plan.
- **No rulings**: the app gives no ruling or advice on how fast to read, for whom a khatma is
  read, or whether to read one together. The presets are paces that readers commonly follow,
  and a group khatma's title is the organiser's own. Any guidance text is the owner's decision.
- **A wird or a part is read when the reader says so**, or, for a wird, reads on past it. The
  app does not check that the pages were read.
- **Mushaf data**: the marks come from the app's own Mushaf data (specs/001). Checked on
  2026-11-15: 26 of the 30 juz start at the top of a page, and Juz 4, 7, 11 and 26 start in
  the middle of one. 72 of the 240 quarter marks are at the top of a page. No ayah continues
  onto the next page. This is why a wird or a part ends at an ayah, not a page (FR-010).
- **Where Khatma opens from**: a control on the reading screen, since it is used daily. The
  plan decides its place. The reading toolbar already holds up to six buttons, which is close
  to the width of the narrowest supported phones.
- **Reuse**: the notification permission flow and wording follow specs/009 (FR-018). The long
  press menu is the one of specs/001, 004, 006 and 010.
- **Minimum supported versions** stay iOS 15.0 and Android 7.0 (API 24). iPad support stays out
  of scope.

**Personal khatma**

- **On the device**: as the rest of the app so far, there is no account and no sync. A personal
  khatma belongs to one device or one browser.
- **One at a time**: a reader who wants a different plan changes the plan or ends the khatma.
- **The seven-day division**: its first wird runs from Al-Fatiha to the end of An-Nisa, as in
  the common form of this division. Its label in the app is content for the owner to confirm.
- **A day** is the calendar day of the phone's clock and time zone.
- **The reminder is not exact to the minute**: within 5 minutes is enough (SC-006).
- **iPhone limit**: an iPhone app can hold 64 scheduled notifications, and prayer alerts
  (specs/009) use up to 60 of them today. The plan must fit the reminders and the prayer
  alerts inside that limit, and still meet the 7 days of FR-021 and of specs/009 FR-021.
- **Web**: a reminder that works only while the page is open would almost never be shown at the
  chosen time, so the web app has none (FR-042). This is a stated gap, as in specs/009 FR-028.
- **Phone backups**: where the phone's own backup restores the app's data, the personal khatma
  and the record come back with it, and reminders are set again when the app is next opened.

**Group khatma**

- **What changes for Mathani**: until now the app kept nothing about readers off their
  devices (specs/001 FR-027, specs/008 FR-027), and the store listings say "no data
  collected". From the release with the group khatma, the names people type, the titles and
  the random keys of FR-065 are kept on Mathani's server for the life of each group khatma.
  A reader who never starts or joins one is not affected (SC-012).
- **Store rules**: Apple's App Review Guideline 1.2 and Google Play's User Generated Content
  policy, read on 2026-11-15, apply to names and titles that other people see. Between them
  they ask for terms accepted first, a filter for objectionable material, a way to report, the
  ability to block abusive users, and published contact details. FR-059 to FR-063 and FR-068
  answer them. Apple asks for "timely responses"; the 24 hours of FR-063 is Mathani's own
  figure.
- **A standing duty**: reports reach the owner at an @mthani.app address, and the owner reviews
  each within 24 hours, for as long as group khatmas exist.
- **Server**: the hosting that already serves the web app and the Mutashabihat content
  (specs/008, specs/011). No push service is added: nothing is sent to a phone that is not
  asking.
- **Only by link**: there is no list of group khatmas to browse or search. Whoever has the
  link can see it and take parts, and the organiser is told so (FR-045).
- **Whole Quran, once**: a group khatma is always the whole Quran, in 30 or 60 parts, read one
  time. A new khatma has a new link.
- **Names**: any name will do, such as a first name or a nickname. Two people can use the same
  one.
- **Group parts are marked by a tap only** (FR-052). This narrows the owner's choice of
  2026-11-15 for group parts: a mark that everyone sees should not be made by a page turn.
- **The organiser's role stays on the device or browser that started the khatma.** It cannot be
  moved or shared in this version.
- **Keys**: the keys of FR-064 prove who may change what. They count as sensitive data under
  the constitution's storage rule. Browsers have no secure storage, which the plan records as
  an exception.
- **Opening the link in the app** uses each platform's standard way of handing a web link to
  an installed app. Where a chat app shows links in its own built-in browser, the group khatma
  opens there instead (Edge Cases).
- **Default figures**, which the plan may tune: a name of up to 30 characters, a title of up
  to 60, changes seen within 30 seconds, removal 30 days after completion or 90 days without a
  change, and at most 5 group khatmas organised at once by one device or browser (FR-067). The
  plan sets how fast one device may start khatmas, take parts and send reports.
- **The list of offensive words** is kept on the server by the owner and can change without a
  new app release.
- **Store review** needs a group khatma link that reviewers can open. Providing one is part of
  the release.
- **The group reminder** uses what the device last saw (FR-024). The server never wakes the
  phone.
