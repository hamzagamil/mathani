# Feature Specification: Mathani on the Web

**Feature Branch**: `008-web-app`

**Created**: 2026-10-26

**Status**: Draft

**Input**: User description: "I want the app to be available on the web. Now I have the website hosted on https://www.netlify.com/ and I want the full app features to be available on it"

## Clarifications

### Session 2026-10-26

- Q: Where should the web app live? → A: get.mthani.app, its own address, separate from the
  landing site at mthani.app.
- Q: How should the app look on laptop and desktop screens? → A: The phone layout centred in the
  window for this feature; a layout adapted to wide screens is a follow-up feature.

## Context

Mathani ships today on iOS and Android (version 1.5.0). Its features are the Mushaf reader in
page and flowing layouts (specs/001, 002), the index with surahs, ajza' and bookmarks, search
(003), ayah-by-ayah recitations with downloads for offline listening (004, 006), the onboarding
(005), and memorization with live word-by-word recognition of the reader's voice (006, 007). The
landing site, mthani.app, was hosted on Netlify (moved to Cloudflare Pages on 2026-10-26). A development-only browser preview already exists
but is not a supported product.

This feature makes the whole app a supported product in the browser, at get.mthani.app, with the same features and the same behaviour as the phone apps unless this spec says
otherwise. Everything earlier specs require of reading, search, recitation, memorization, privacy
and onboarding still holds on the web.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read the Quran in the browser (Priority: P1)

A visitor follows a link from mthani.app (or types the web app's address) on a laptop or a phone
browser. Without installing anything, they see the Mushaf, turn pages, switch between the page and
flowing layouts, open the index to jump to a surah, juz', hizb quarter or page number, search the
text, select an ayah to copy, share or bookmark it, and change theme and language in Settings. When
they come back later in the same browser, they are on the page they left, with their bookmarks and
settings kept.

**Why this priority**: Reading is the core of Mathani. On its own it gives people without the app,
or at a computer, the Quran in the same Uthmani script and printed page layout.

**Independent Test**: In a supported browser with no prior visit, open the web address, read
through several pages in both layouts, search a word, bookmark two ayat, change the theme and the
language, close the browser, reopen the address, and confirm the same page, bookmarks, theme and
language.

**Acceptance Scenarios**:

1. **Given** a first visit in a supported browser, **When** the visitor opens the web address,
   **Then** the Mushaf (or the onboarding, as on a first launch of the app) appears without an
   install step and without downloading the whole Mushaf first.
2. **Given** the reader is on page 300, **When** they reload the browser tab or come back days
   later in the same browser, **Then** they are on page 300 with their bookmarks and settings.
3. **Given** any page, **When** the reader turns pages by swipe, by on-screen controls or by the
   keyboard's arrow keys, **Then** pages turn in the Mushaf's reading direction, as in the app.
4. **Given** the page layout, **When** the reader compares a page with the same page in the phone
   app, **Then** the lines, line breaks and decorations are the same.
5. **Given** the reader presses the browser's back button after opening the index or a sheet,
   **Then** it closes as the system back action does on Android, and does not leave the web app.
6. **Given** an ayah is selected, **When** the reader chooses share, **Then** the browser's share
   option is used where the browser offers one, and otherwise the text is copied with a
   confirmation.

---

### User Story 2 - Listen to recitations (Priority: P2)

The reader picks any reciter offered in the app, plays from an ayah, and hears the recitation ayah
by ayah with the playing ayah highlighted and the page following it, with the same repeat, range
and speed options as the app. Playback continues when they switch to another browser tab, and the
system media keys or browser media controls pause and skip where the device provides them. They can
download a surah or a reciter's recordings to listen without a connection, see the downloads and
their sizes in Settings › Downloads, and delete them.

**Why this priority**: Recitation is the most used feature after reading and needs no permissions,
so it is the next most valuable slice.

**Independent Test**: Play a surah with two reciters, switch tabs and confirm playback continues,
pause with the keyboard's media key, download a short surah, disconnect from the network, reload,
and play it again.

**Acceptance Scenarios**:

1. **Given** any reciter offered in the app, **When** the reader plays from an ayah, **Then**
   playback starts and highlights each ayah as in the app.
2. **Given** playback is running, **When** the reader switches to another tab or minimises the
   window, **Then** playback continues.
3. **Given** a downloaded surah and no network, **When** the reader reloads the web app and plays
   it, **Then** it plays from the downloaded copy.
4. **Given** the browser refuses to store more data, **When** the reader starts a download,
   **Then** the web app says there is not enough space and keeps nothing half-saved.

---

### User Story 3 - Memorize with live recognition (Priority: P3)

The reader opens memorization on the web, picks a range, and recites. As in the app, the web app
first explains why it needs the microphone, asks the browser for permission, downloads the
recognition model once (showing its size first), then hides the text and reveals each word as the
reader recites it correctly, and shows the result at the end. Their voice is recognised inside the
browser and never sent anywhere.

**Why this priority**: It completes "full app features", but it needs the microphone, a large
one-time download and a capable device, so it is built after reading and listening work.

**Independent Test**: In a supported browser, start memorization, allow the microphone, download
the model, recite a short surah with one deliberate mistake, and confirm the words reveal live, the
mistake is marked, and the result matches what the phone app shows for the same recitation. Watch
the network while reciting and confirm no audio leaves the device.

**Acceptance Scenarios**:

1. **Given** the model is not downloaded, **When** the reader starts memorization, **Then** the
   web app shows the model's download size and asks before downloading.
2. **Given** the microphone permission is denied or no microphone exists, **When** the reader
   starts memorization, **Then** the web app explains how to allow it and the rest of the app keeps
   working.
3. **Given** a browser or device that cannot run recognition, **When** the reader opens
   memorization, **Then** the web app says memorization is not available in this browser and names
   the supported browsers, instead of failing during a session.
4. **Given** a session in progress, **When** the reader recites, **Then** words are revealed live
   as in the phone app, and no audio or transcript is sent over the network.

---

### User Story 4 - Use it like an app (Priority: P3)

A regular reader adds Mathani to their home screen or desktop from the browser. It opens in its own
window with the Mathani name and icon, starts without a network once it has been used, and shows
the pages they have already read, their bookmarks and their downloaded recitations offline.

**Why this priority**: Useful for regular readers, but reading in a normal tab already works.

**Independent Test**: Install the web app from the browser, open several pages, go offline, open
the installed app, and confirm it starts and shows those pages.

**Acceptance Scenarios**:

1. **Given** a supported browser, **When** the reader installs the web app, **Then** it opens in
   its own window with the Mathani name and icon.
2. **Given** the web app was used before and there is no network, **When** the reader opens it,
   **Then** it starts and shows the pages already viewed, bookmarks and downloads; pages not yet
   viewed say they need a connection.
3. **Given** a new version is published, **When** the reader next opens the web app online,
   **Then** they get the new version within one more visit, without losing their data.

---

### Edge Cases

- **Unsupported or old browser**: the web app shows a short page, in Arabic and English, naming
  the supported browsers and linking to the store apps, instead of a blank or broken screen.
- **Private browsing, or the browser clears site data**: the app works for the session; on the
  next visit bookmarks, settings and downloads are gone, as after reinstalling the phone app.
  Settings says that data is kept only in this browser.
- **The browser evicts stored data under storage pressure**: downloads that disappear are shown
  as not downloaded and can be downloaded again; bookmarks and the reading position are asked to
  be kept persistently where the browser allows it.
- **Two tabs open at once**: a bookmark or setting changed in one tab appears in the other on its
  next reload, and nothing is lost or duplicated.
- **Slow connection on first visit**: the first page shows as soon as its own font has arrived;
  progress is shown while it loads, never a blank screen.
- **Wide or very short browser windows, and resizing**: the layout stays usable at any window size
  from phone width up to a full desktop screen, and resizing keeps the reader on the same page.
- **Browser zoom and text size**: zooming in and out keeps the app usable, as system font scaling
  does on phones.
- **Recitation playback blocked until the user interacts**: the first play starts from the
  reader's tap, so the browser's autoplay rules never block it.
- **Reader also has the phone app**: the web app and the phone app keep separate bookmarks and
  settings; nothing is synced.
- **Memorization on a phone browser**: works where the browser supports it; the screen is kept on
  during a session where the browser allows it.

## Requirements *(mandatory)*

### Functional Requirements

**Access and hosting**

- **FR-001**: The web app MUST be served at get.mthani.app (hosted on Cloudflare Pages), and published
  separately from the landing site, so a web app release cannot change or break the landing pages.
- **FR-002**: The landing site MUST link to the web app, and the existing landing pages,
  including /privacypolicy, MUST keep working at their current addresses.
- **FR-003**: Supported browsers MUST be the current and previous major versions of Chrome, Edge,
  Firefox and Safari, on desktop and on phones. Other browsers MUST get the unsupported-browser
  page described in Edge Cases rather than a broken app.
- **FR-004**: The web app MUST use HTTPS only.

**Feature parity**

- **FR-005**: Every feature of app version 1.5.0 MUST be available on the web with the same
  behaviour, except where this spec says otherwise: the Mushaf reader in page and flowing layouts,
  the index (surahs, ajza', hizb quarters, page number, bookmarks), search, ayah selection with
  copy, share and bookmark, recitations with every reciter offered in the app, downloads and
  Settings › Downloads, memorization with live recognition, the onboarding, settings, About, and
  the licences page.
- **FR-006**: The Quran text, page layout and fonts on the web MUST be the same as in the phone
  app; a page MUST NOT be shown in a fallback font while its own font is loading.
- **FR-007**: The interface MUST follow the browser's language (Arabic or English, otherwise
  English) with the same in-app override as the phone app, and MUST follow the browser's or
  system's light and dark setting with the same override.
- **FR-008**: The browser's back button MUST close the open sheet, dialog or screen as the
  Android back action does, and MUST NOT leave the web app while a sheet or screen is open.
- **FR-009**: The web app MUST be fully usable with a mouse and keyboard as well as by touch:
  page turning by arrow keys, playback toggled by the space bar while the reader is focused,
  visible keyboard focus, and every action reachable without a long press (a long-press action
  MUST also be reachable by right-click or a visible control).
- **FR-010**: The web app MUST be usable with screen readers in the supported browsers to the
  same degree as with VoiceOver and TalkBack in the phone app.
- **FR-011**: Where the phone app uses a device feature that a browser lacks (haptics, share
  sheet, keeping the screen on, lock-screen controls), the web app MUST use the browser's
  equivalent where one exists and otherwise leave it out without an error.
- **FR-012**: On windows wider than a phone, the web app MUST show the phone layout in a centred
  column at a comfortable reading size, with the space around it in the app's background colour;
  sheets and dialogs MUST stay within that column. A layout adapted to wide screens (for example
  two Mushaf pages side by side) is a separate, later feature.

**Data kept in the browser**

- **FR-013**: Bookmarks, the reading position, settings, onboarding progress and memorization
  results MUST be kept in the browser and survive reloads, closing the browser and new versions
  of the web app.
- **FR-014**: The web app MUST ask the browser to keep its data persistently where the browser
  offers that, so it is not cleared under storage pressure.
- **FR-015**: Settings MUST say that data is kept only in this browser and is not shared with
  the phone app or other browsers.

**Loading and offline use**

- **FR-016**: The first visit MUST NOT download the whole Mushaf: page fonts and other large
  content MUST load as the reader needs them, and stay stored for later visits.
- **FR-017**: After a first visit, the web app MUST start without a network and show the pages
  already viewed, bookmarks, settings and downloaded recitations; anything that needs the network
  MUST say so instead of failing silently.
- **FR-018**: The web app MUST be installable from supported browsers that offer installation,
  with the Mathani name, icon and theme colour, and open in its own window.
- **FR-019**: When a new version is published, a returning reader MUST get it on the next visit or
  the one after, and MUST keep all their data.

**Recitations**

- **FR-020**: Recitation playback MUST continue when the tab is in the background or the window is
  minimised, and MUST respond to the device's media keys and the browser's media controls where
  available.
- **FR-021**: Recitation downloads MUST be stored in the browser with the same size display,
  progress, resume after interruption, integrity check and delete actions as in the app (specs/004,
  006), and MUST report when the browser has no room for them.

**Memorization**

- **FR-022**: Memorization MUST use the same recognition model and give the same results for the
  same recitation as the phone app (specs/007).
- **FR-023**: The microphone MUST be requested only when a memorization session starts, after the
  same explanation as in the app, and the app MUST keep working when it is denied.
- **FR-024**: Recognition MUST run entirely in the browser: no audio, transcript or result may be
  sent over the network.
- **FR-025**: The recognition model MUST be a one-time download on first use, with its size shown
  before downloading, resumable, integrity-checked, listed in Settings › Downloads and deletable.
- **FR-026**: Where a browser or device cannot run recognition, the web app MUST say so before a
  session starts and name the supported browsers.

**Privacy and release**

- **FR-027**: The web app MUST NOT add analytics, tracking, advertising, accounts or cookies beyond
  what the app itself needs to work; it collects no personal data, as in the phone app.
- **FR-028**: The privacy policy at mthani.app/privacypolicy MUST be updated to cover the web app
  before the web app is announced.
- **FR-029**: Each web release MUST show the same version number as the matching phone release in
  Settings › About, and MUST be possible to roll back to the previous web release.

### Key Entities

- **Web app release**: one published version of the web app. Has a version number matching the
  phone release and can be rolled back.
- **Browser data**: everything kept for one reader in one browser: bookmarks, reading position,
  settings, onboarding progress, memorization results, stored page fonts, downloaded recitations
  and the recognition model. Separate per browser and per device; not synced.
- **Supported browser list**: the browsers and versions the web app is tested on and names on its
  unsupported-browser page.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a first visit over a typical home broadband connection (about 20 Mbit/s), the
  first Mushaf page (or the onboarding) is readable within 5 seconds of opening the address.
- **SC-002**: On a returning visit, the reader's last page is readable within 2 seconds.
- **SC-003**: Turning pages and scrolling run without visible stutter on a mid-range laptop and a
  mid-range phone in the supported browsers, matching the phone app's 60 frames per second goal.
- **SC-004**: Every feature of app version 1.5.0 can be completed end to end in each supported
  browser, checked against the acceptance scenarios of specs/001 to 007; any exception is listed
  in this spec with its reason.
- **SC-005**: For 20 sampled pages, the web app's page layout matches the phone app's page by
  page, line by line.
- **SC-006**: For the same recorded recitations, memorization gives the same revealed words and
  mistakes on the web as on the phone app.
- **SC-007**: During a memorization session, the network shows no traffic carrying audio,
  transcripts or results.
- **SC-008**: After one online visit, the installed web app starts offline and shows previously
  viewed pages and bookmarks in 100% of trials on each supported browser.
- **SC-009**: The landing pages and /privacypolicy return the same content after the web app is
  published as before.

## Assumptions

- **Same product, one codebase**: the web app is the same app as the phone apps, built from the
  same source, not a separate website; new features in later specs are expected to ship to the web
  as well. Earlier specs' requirements apply to the web unless this spec overrides them.
- **Constitution**: Principles I and II were written for an iOS and Android app. Because the web
  shows the phone layout (FR-012), the plan's Constitution Check passes with two justified
  deviations (plan.md › Complexity Tracking). An amendment that adds the web as a platform, with
  its budgets, is recommended as a follow-up.
- **No accounts and no sync**: the web app, like the phone app, has no accounts. Bookmarks and
  settings are kept per browser; syncing between the web and the phone app is out of scope.
- **Shareable links to pages or ayat** (an address per page or ayah) are out of scope for this
  feature; sharing an ayah shares its text, as in the app.
- **Domain**: get.mthani.app is a subdomain of the existing mthani.app domain, pointed at the
  web app's Pages project. The landing site stays at mthani.app, and the landing site and store listings link
  to get.mthani.app.
- **Hosting**: the web app is served from Cloudflare Pages (project `mthani-web`; owner decision,
  2026-10-26), and the landing site and privacy policy moved there too (project
  `mthani-landing`). Static files on Pages carry no bandwidth charge. Recordings keep coming from the same recitation
  sources as the app, and all of them allow browser downloads. The recognition model is
  mirrored to Hugging Face, because browsers cannot download GitHub release files.
- **Permissions**: the KFGQPC, QUL and EveryAyah permission requests (docs/licences.md D1–D4)
  currently name only the App Store and Google Play. They are widened to include the web app.
- **Content sizes**: the Mushaf page fonts are about 130 MB in total and the recognition model
  about 108 MB, so both must load on demand (FR-016, FR-025); readers who never open memorization
  download nothing for it.
- **Release process**: web releases are published with `tool/web_deploy.mjs` (wrangler). Pages
  keeps every deployment for rollback (FR-029).
- **Store links**: the unsupported-browser page and the landing site keep linking to the App Store
  and Google Play apps.
