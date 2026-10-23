# Licences and Attributions

Every third-party source and asset shipped in Mathani, the licence it is used under, and what
that licence requires of the app. The About screen (`lib/features/settings/about_section.dart`)
must show every attribution marked **required**.

## Quran text and data

| Source | Used for | Licence | Requirements |
| --- | --- | --- | --- |
| Tanzil Project, Uthmani text v1.1 and metadata (https://tanzil.net) | Integrity reference for every ayah; surah, juz, hizb, page and sajdah metadata | Creative Commons Attribution 3.0 | **Required**: verbatim copies only (CHANGING IT IS NOT ALLOWED); clearly name the source "Tanzil Project"; link to https://tanzil.net; keep the copyright notice with verbatim copies |
| Quranic Universal Library (QUL, https://qul.tarteel.ai): KFGQPC Mushaf layout, KFGQPC Hafs word-by-word script, Imla'i word-by-word script | Page and line layout; displayed words; search forms | **Unconfirmed** (no licence stated; site terms at https://tarteel.ai/terms) | Attribution expected. **Dependency D2**: confirm in writing before release |
| King Fahd Glorious Quran Printing Complex (KFGQPC) | Origin of the Mushaf layout and Hafs text | See the font row below for the font; text origin credited | **Required**: credit "King Fahd Glorious Quran Printing Complex" |

## Fonts

| Font | Used for | Licence | Requirements |
| --- | --- | --- | --- |
| KFGQPC Uthmanic Script HAFS | Quran text (production, preferred) | **Proprietary**: no reproduction or modification without written approval from KFGQPC | **Dependency D1**: not bundled until written approval is received |
| Amiri Quran | Quran text (fallback; used until D1 is resolved) | SIL Open Font License 1.1 | Ship the OFL text; do not sell the font by itself |
| KFGQPC Madinah Mushaf page fonts, edition V2 (1421 AH), one per page (`assets/qcf/`) | Printed lettering of the Mushaf layout, the default (specs/002, User Story 4) | **Proprietary**, as above | **Dependency D3**: bundled unmodified; requires written approval |
| IBM Plex Sans Arabic (Regular, Medium, SemiBold, Bold) | Interface text, Arabic and Latin | SIL Open Font License 1.1 | Ship the OFL text |

## Recitations

Streamed or downloaded on request; nothing is bundled (specs/004-ayah-recitations). The file
sizes in `quran.db` (`recitation_files`) come from these servers.

| Recording | Used for | Licence | Requirements |
| --- | --- | --- | --- |
| Sheikh Mahmoud Khalil Al-Husary, Murattal, EveryAyah `Husary_64kbps` (https://everyayah.com, mirror https://mirrors.quranicaudio.com/everyayah) | Ayah-by-ayah recitation (default reciter) | **Unconfirmed** (no terms stated on the site) | **Dependency D4**: written permission before release. **Required** until D4 says otherwise: the About screen credits both reciters and EveryAyah.com with a link (`recitationAttribution`) |
| Sheikh Mohamed Siddiq El-Minshawi, Murattal, EveryAyah `Minshawy_Murattal_128kbps` (same hosts) | Ayah-by-ayah recitation | **Unconfirmed** (no terms stated on the site) | **Dependency D4**: as above |

## Icons and images

| Asset | Used for | Licence | Requirements |
| --- | --- | --- | --- |
| Lucide icons, `lucide-static` 1.48.0 font (`assets/fonts/Lucide.ttf`, tree-shaken in release builds) | Interface icons | ISC (`assets/fonts/LICENSE-Lucide.txt`) | Keep the ISC notice |
| Mathani logos and app icon (brand guide «مثاني — دليل الهوية») | App icon, launch screen, About | Owned by the project | — |

## Permissions

| ID | What | Asked | Status | Date | Notes |
| --- | --- | --- | --- | --- | --- |
| D1 | KFGQPC: embed the unmodified KFGQPC Uthmanic Script HAFS font in a free app on the App Store and Google Play | not yet | requested / granted / refused | — | Contact via https://fonts.qurancomplex.gov.sa. Draft: [permissions/kfgqpc-request.md](permissions/kfgqpc-request.md) (with D3) |
| D2 | QUL / Tarteel: redistribute the KFGQPC layout and word-by-word data inside the app | not yet | requested / granted / refused | — | Contact via https://qul.tarteel.ai. Draft: [permissions/qul-request.md](permissions/qul-request.md) |
| D3 | KFGQPC: bundle the unmodified Madinah Mushaf page fonts (604) in the app (since 2026-10-23; previously planned as a hosted download) | not yet | granted | — | Same request as D1. Unblocks specs/002 task T026 |
| D4 | Quran.com Foundation / EveryAyah: stream, cache and let readers download the Al-Husary and El-Minshawi Murattal recordings in a free app on the App Store and Google Play | not yet | requested / granted / refused | — | Contact via https://quran.zendesk.com/hc/en-us. Draft: [permissions/everyayah-request.md](permissions/everyayah-request.md). **Blocks the store release** of specs/004 |
