# Request to the Quran.com Foundation / EveryAyah (D4)

Send through the Quran.com help desk (https://quran.zendesk.com/hc/en-us, "Submit a request"),
which is the contact EveryAyah.com links to. Fill in the contact line before sending, then record
the date in `docs/licences.md` › Permissions.

---

**Subject:** Permission to stream and download EveryAyah recitations in the free app «مثاني»
(Mathani)

Hello,

Assalamu alaikum. Mercury Engineering & Consultations LLC publishes «مثاني: تلاوة وتدبر المتشابه»
(Mathani) on the Apple App Store and Google Play (identifier `com.mthani.app`). It is a free Quran
reader with no ads, no accounts and no data collection.

We would like to add ayah-by-ayah recitation, with the recited ayah highlighted in the Mushaf,
using these EveryAyah recordings:

1. **Sheikh Mahmoud Khalil Al-Husary, Murattal**: `https://everyayah.com/data/Husary_64kbps/`
2. **Sheikh Mohamed Siddiq El-Minshawi, Murattal**:
   `https://everyayah.com/data/Minshawy_Murattal_128kbps/`

How the app would use them:

- **Streaming**: the app requests one ayah file at a time from EveryAyah (falling back to
  `mirrors.quranicaudio.com/everyayah`), a few ayat ahead of the one playing. Recently played
  ayat are cached on the device (at most 100 MB) so they are not downloaded again.
- **Downloads**: a reader can download a surah for offline listening. The files are saved
  inside the app's private storage only, never shared or exported.
- **Unaltered**: the recordings are played exactly as published: no trimming, speed change or
  effects. Al-Fatiha 1:1 is played as the basmala before each surah except At-Tawbah.
- **No redistribution**: we do not host, re-publish or offer the files through any other
  channel. Requests carry no cookies, identifiers or analytics.

We found no licence or terms for the recordings on EveryAyah.com, so we would like your written
permission for this use, and to know:

- the attribution you would like (the About screen would read "Recitations: Sheikh Mahmoud Khalil
  Al-Husary and Sheikh Mohamed Siddiq El-Minshawi (Murattal), via EveryAyah.com", with a link);
- any conditions on use in a free app distributed through both stores, including request rates
  (the app makes at most 2 requests at a time per device);
- whether you prefer that the app use a particular host (everyayah.com, quranicaudio.com mirrors
  or another).

Thank you for EveryAyah. It has served readers of the Quran for many years.

Hamza Gamil, on behalf of Mercury Engineering & Consultations LLC
Email: [contact email]
