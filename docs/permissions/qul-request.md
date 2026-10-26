# Request to the Quranic Universal Library / Tarteel (D2)

Send through https://qul.tarteel.ai (contact link on the site). Fill in the contact line before
sending, then record the date in `docs/licences.md` › Permissions.

---

**Subject:** Permission to redistribute QUL layout and word-by-word data in the free app «مثاني»
(Mathani)

Hello QUL team,

Assalamu alaikum. Mercury Engineering & Consultations LLC publishes «مثاني: تلاوة وتدبر المتشابه»
(Mathani) on the Apple App Store and Google Play (identifier `com.mthani.app`) and as a free web app at https://get.mthani.app (specs/008). It is a free Quran
reader with no ads, no accounts and no data collection, and it works fully offline.

The app is built from these QUL resources, which we found no licence for on the site:

1. **KFGQPC 15-line Mushaf layout** (`qpc-hafs` / KFGQPC V4 layout): the page and line breaks of
   the 604 pages.
2. **KFGQPC Hafs word-by-word script**: the words shown on each line.
3. **Imla'i word-by-word script**: search forms for some ayat.

They are processed at build time into a read-only database that ships inside the app. We do not
offer the data for download or through any API.

The next version (specs/006) also uses QUL recitations:

4. **Ayah timings of 7 surah-by-surah recitations**: Mohamed Siddiq El-Minshawi with children
   (resource 314), Mostafa Ismail (346), Mahmoud Khalil Al-Husary's Ijazah recording (368), Bandar
   Baleela (388), Khalid Al-Jalil (420), Hady Toure (421) and Mansour Al-Salimi (572). At build
   time we turn each ayah's start time into a byte offset in the surah's MP3. The app ships only
   these offsets and file sizes, not the timing files, and it never calls QUL's servers.
5. **Streaming and downloading audio hosted on `audio-cdn.tarteel.ai`**: Ahmad Al-Nufais (ayah by
   ayah, resource 471), and the surah files of El-Minshawi with children and Mansour Al-Salimi.
   The app requests each ayah as a byte range of the surah file, cut in the pause between ayat,
   and plays it unaltered. Downloads stay in the app's private storage. Requests carry no
   identifiers.

We would like your written permission to redistribute this data inside the app, and to know:

- the attribution you would like (the About screen currently credits "Quranic Universal Library
  (QUL), https://qul.tarteel.ai");
- any conditions on use in a free app distributed through both stores and on the web;
- for items 4 and 5, whether we may use the timings and the Tarteel-hosted audio as described,
  and the attribution you would like for them;
- whether the KFGQPC V2 (1421 AH) layout and the matching per-word glyph codes may be used the
  same way, for an optional download that shows each page in the printed lettering. This part
  also depends on the King Fahd Complex's permission, which we are requesting separately.

Thank you for QUL. It has made this app possible.

Hamza Gamil, on behalf of Mercury Engineering & Consultations LLC
Email: [contact email]
