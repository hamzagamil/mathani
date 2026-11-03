# Feature Specification: Online Mutashabihat Editor

**Feature Branch**: `011-mutashabihat-online-editor` (not created yet; the work so far is on
`010-mutashabihat`)

**Created**: 2026-11-03

**Status**: Draft

**Input**: User description: "Online editing of the Mutashabihat content (the deferred option from
specs/010 Q1): the owner edits the mutashabihat groups and explanations in a private web page, and
readers' apps (iOS, Android and the web app) download the changes over the internet without a
store release. Today the content is the file assets/mutashabihat/mutashabihat.md shipped inside
each release (specs/010)."

**Scope of this spec**: Specs/010 shipped the Mutashabihat content inside each release: the owner
edits one file, and readers get changes with the next app and web release. Its Clarifications
named an online editor as the next step. This spec adds it:

1. **Editor**: a private web page where the owner creates, edits and deletes groups, with the
   same rules the release check enforces today.
2. **Publishing**: the owner decides when changes go to readers.
3. **Updates in the apps**: the iOS, Android and web apps fetch the published content over the
   internet and use it without a new release, keeping the bundled copy for first launch and
   offline use.

How the content looks and behaves in the app (colour, «عرض المتشابه», the overlay, the onboarding
stop) does not change. That is specs/010.

## Clarifications

### Session 2026-11-03

- Q: Is the editor for the owner only, or can others edit? → A: The owner can add editors, all
  with the same editing and publishing rights. Only the owner adds and removes editors.
- Q: Does saving publish at once? → A: No. Saved changes wait as a draft, and go to readers when
  someone presses Publish. Before publishing, the editor shows what will change.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fix an explanation and see it on phones the same day (Priority: P1)

The owner notices a mistake in a group's explanation while reading on the phone. They open the
editor on their laptop or phone, sign in, find the group, correct the text and publish. Within
the day, readers who open the app see the corrected explanation, without updating the app.

**Why this priority**: This is the reason for the feature. Today a one-word fix waits for a store
release and app review.

**Independent Test**: Change one explanation in the editor and publish. Then open an installed
iPhone build, an installed Android build and the web app, which were all built before the change,
and check that each shows the new text.

**Acceptance Scenarios**:

1. **Given** the owner is signed in, **When** they search for a group by an ayah reference (for
   example 2:35) or by words of its note or explanation, **Then** the matching groups are listed
   with their ayat.
2. **Given** the owner opens a group, **When** they edit the explanation and save, **Then** the
   change is kept as a draft and readers do not see it yet.
3. **Given** there are saved changes, **When** the owner publishes, **Then** the editor confirms
   the publish with the number of changed groups, and the published content becomes the version
   readers' apps download.
4. **Given** a reader's app was installed before the change, **When** the reader opens the app
   with an internet connection after the publish, **Then** the app downloads the new content in
   the background and shows the corrected explanation, without a store update.
5. **Given** the reader has no connection, **When** they open the app, **Then** it shows the last
   content it has, and fetches the update the next time it is online.

---

### User Story 2 - Add, change and remove groups (Priority: P1)

The owner adds a new group by choosing ayat and writing the explanation, adds or removes ayat in a
group, and deletes groups. The editor shows each ayah's text as it is chosen, so mistakes in a
reference are visible at once.

**Why this priority**: The owner has to manage the content online once the file is no longer
where changes are made. Without this, Story 1 covers only explanation fixes.

**Independent Test**: Create a group of three ayat, remove one ayah from another group, and
delete a third group. Publish, and check on a phone that the new group appears, the removed ayah
is no longer coloured, and the deleted group is gone.

**Acceptance Scenarios**:

1. **Given** the owner adds an ayah by surah and ayah number, **When** the reference is valid,
   **Then** the editor shows that ayah's text and surah name next to it.
2. **Given** the owner enters a reference that does not exist (for example 2:300), **When** they
   try to save, **Then** the editor refuses and says which reference is wrong.
3. **Given** a group has fewer than two different ayat or an empty explanation, **When** the
   owner tries to save, **Then** the editor refuses and says what is missing.
4. **Given** the owner deletes a group, **When** they confirm, **Then** it is gone from the next
   publish, and the editor can bring it back until then.
5. **Given** an ayah belongs to several groups, **When** the owner opens it, **Then** the editor
   shows all of its groups.

---

### User Story 3 - Share the work with editors (Priority: P2)

The owner adds a trusted person as an editor by their email address. That person signs in with
their own email and can edit and publish like the owner. The owner can remove them at any time.
The history shows who made each change and each publish.

**Why this priority**: The owner wants to share the work, but the editor is useful to the owner
alone first.

**Independent Test**: Add an editor, sign in as them on another device, edit and publish a group,
and check that the history names them. Remove them, and check they can no longer open the
editor.

**Acceptance Scenarios**:

1. **Given** the owner adds an email address as an editor, **When** that person signs in with
   that email, **Then** they can edit, save and publish.
2. **Given** an editor is signed in, **When** they look for the list of editors, **Then** they
   cannot see or change it. Only the owner manages editors.
3. **Given** the owner removes an editor, **When** that person next opens the editor or tries to
   save, **Then** they are refused, even if they were signed in at that moment.
4. **Given** several people have saved changes, **When** anyone opens Publish, **Then** the list
   of what will change names who changed each group.

---

### User Story 4 - Undo a bad publish (Priority: P2)

The owner publishes by mistake, or finds a problem after publishing. They open the publish
history, see when each version was published and what it changed, and restore an earlier one.
Readers' apps pick up the restored version like any other update.

**Why this priority**: Without a way back, a wrong publish reaches every reader within hours and
the owner has no quick fix. It is needed before heavy use, but the first publishes can be checked
by hand.

**Independent Test**: Publish a change, then restore the version before it, and check on a phone
that the change is gone after the next app start.

**Acceptance Scenarios**:

1. **Given** at least two published versions, **When** the owner opens the history, **Then** each
   version shows its date, time and the number of groups added, changed and removed.
2. **Given** the owner restores an earlier version, **When** they confirm, **Then** it becomes the
   published content, and the history records the restore as a new version.

---

### User Story 5 - Releases carry the latest content (Priority: P2)

When the owner builds a new app or web release, the release includes the content most recently
published from the editor, so a reader who installs the app offline still sees current content.

**Why this priority**: After this feature the editor is where content lives. A release built from
an old file would make new installs show outdated content until they go online.

**Independent Test**: Publish a change, build a release, install it on a phone with no internet,
and check that the change is there.

**Acceptance Scenarios**:

1. **Given** a published version newer than the content in the repository, **When** a release is
   prepared, **Then** the release uses the published version and the release check still runs on
   it.
2. **Given** the editor cannot be reached when a release is prepared, **When** the release step
   runs, **Then** it stops and says so, rather than shipping old content without warning.

---

### Edge Cases

- **Not signed in**: anyone who opens the editor's address without signing in sees only a
  sign-in page. No content, draft or history is shown, and nothing can be changed.
- **Unsaved work**: if the owner closes the page or loses the connection while editing, the
  unsaved group is kept on that device, and the editor offers it again on return.
- **Two devices or two editors**: the same group is edited in two places. The second save is
  refused, with a message that the group changed elsewhere (and by whom) and a way to reload it.
- **Large publishes**: a publish that changes most groups downloads the same way. Readers never
  see a half-updated mix of two versions.
- **Download interrupted**: the app keeps using the content it had and tries again later. A
  partial or damaged download is never used.
- **App older than the content format**: if a published version uses something an older app does
  not understand, that app keeps its current content instead of breaking.
- **No connection on first launch**: the app uses the content bundled in the release.
- **Data use**: the app downloads the content only when the published version has changed. A
  check that finds no change costs almost nothing.
- **Many readers at once**: a publish that thousands of apps download in the same hour does not
  slow the editor or fail the downloads.

## Requirements *(mandatory)*

### Functional Requirements

**Access**

- **FR-001**: The editor MUST be a web page that only the owner and the editors the owner has
  added can open, each signing in with their own email address.
- **FR-002**: Every change the editor saves and every publish MUST be refused unless the person
  is signed in and is the owner or a current editor. Removing an editor MUST take effect on their
  next request.
- **FR-002a**: Only the owner MUST be able to add and remove editors. Editors have the same
  editing and publishing rights as the owner.
- **FR-003**: The editor MUST work in current desktop and phone browsers, at phone width
  included.

**Editing**

- **FR-004**: The owner MUST be able to list, search (by ayah reference or by text), open,
  create, edit and delete groups.
- **FR-005**: When an ayah is added to a group, the editor MUST show its text and surah name.
- **FR-006**: Saving a group MUST be refused, with a message saying why, if it references an ayah
  that does not exist, has fewer than two different ayat, or has an empty explanation (the same
  rules as specs/010 FR-016).
- **FR-007**: Each group MUST keep the owner's private note (the text after `|` in today's file),
  which readers never see.
- **FR-008**: The first time the editor is used, it MUST start from the content that is live
  today, the 72 groups of specs/010, with nothing lost.

**Publishing**

- **FR-009**: Saved changes MUST stay in one shared draft that readers do not see. They MUST
  reach readers only when the owner or an editor presses Publish. Before publishing, the editor
  MUST list the groups that will be added, changed and removed, and who changed each.
- **FR-010**: Every publish MUST be checked with the same rules as FR-006 across all groups, and
  MUST be refused if any group fails.
- **FR-011**: The editor MUST keep a history of published versions with date, time, who
  published and what changed, and MUST let the owner or an editor restore any earlier version as
  a new publish.

**Updates in the apps**

- **FR-012**: The iOS, Android and web apps MUST check for newly published content when the app
  opens or comes back to the foreground, at most once every few hours, and only after the first
  screen is shown.
- **FR-013**: The apps MUST download content only when it has changed, keep the last complete
  version on the device, and use it offline.
- **FR-014**: A downloaded version MUST be used only if it is complete and passes the same checks
  as FR-006. Otherwise the app MUST keep the content it has.
- **FR-015**: A new version MUST take effect without restarting the app. If the similar-ayat
  overlay is open at the time, it MUST keep showing what it opened with.
- **FR-016**: Without any downloaded version, the app MUST use the content bundled in the release.
- **FR-017**: The apps MUST NOT send any personal or device information when they check for or
  download content, beyond what any web request carries.

**Releases**

- **FR-018**: Preparing an app or web release MUST include the most recently published content,
  checked by the release check of specs/010, and MUST stop if it cannot get it.

### Key Entities

- **Group**: the same as specs/010: two or more ayat, one explanation, and the owner's private
  note. It gains an identity that stays the same across edits, so history and conflicts can name
  it.
- **Draft**: saved changes that are not yet published, shared by everyone who edits, each change
  recording who made it.
- **Editor**: a person the owner allowed to edit, known by their email address. The owner is
  always allowed.
- **Published version**: a complete, checked set of groups that readers' apps can download, with
  a version number, date and time, and a summary of what changed from the previous one.
- **Content on the device**: the last complete version an app downloaded, or the bundled one, and
  its version number.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A one-line correction takes the owner under 2 minutes, from opening the editor to
  publishing.
- **SC-002**: After a publish, at least 95% of readers who open the app with a connection see the
  new content within 24 hours, without updating the app.
- **SC-003**: Content updates add no measurable delay to app start (cold start stays within the
  constitution's 2-second budget) and never block reading.
- **SC-004**: A check that finds no change transfers less than 1 KB. A full content download is
  under 200 KB compressed at today's size.
- **SC-005**: 0 broken or partial versions reach readers: every version an app uses passes the
  same checks as the release check.
- **SC-006**: A wrong publish can be reverted in under 1 minute, and readers get the reverted
  version on the same schedule as SC-002.
- **SC-007**: No one but the owner and current editors can read drafts or change content. Every
  attempt without signing in, or by a removed editor, is refused.

## Assumptions

- **Same content model**: groups, explanations and notes as in specs/010. Word highlighting and
  linking parts of ayat stay out of scope.
- **The editor becomes the source**: after the first import, content changes are made in the
  editor, not in `assets/mutashabihat/mutashabihat.md`. The file in the repository becomes the
  snapshot bundled in releases (Story 4).
- **Arabic editor**: the editor's interface is Arabic, right to left, like the content.
- **Update timing**: a delay of up to a day between publish and readers seeing the change is
  acceptable. Pushing changes to devices instantly is not needed.
- **No reader accounts**: readers never sign in. Content is the same for everyone.
- **Hosting**: the editor and the published content are served from the same hosting the web app
  already uses (specs/008), with no new paid service at today's scale.
- **One language**: explanations stay Arabic only.

## Out of Scope

- Reader comments, suggestions or votes on explanations.
- Content other than Mutashabihat (for example the onboarding text or the reciter list).
- Scheduled publishing, and publishing to only some readers.
- Push notifications about new content.
