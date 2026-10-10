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
| IBM Plex Sans Arabic (Regular, Medium, SemiBold, Bold) | Interface text, Arabic and Latin | SIL Open Font License 1.1 | Ship the OFL text |

## Icons and images

| Asset | Used for | Licence | Requirements |
| --- | --- | --- | --- |
| Lucide icons (selected SVGs compiled into `MathaniIcons.ttf`) | Interface icons | ISC | Keep the ISC notice |
| Mathani logos and app icon (brand guide «مثاني — دليل الهوية») | App icon, launch screen, About | Owned by the project | — |

## Permissions

| ID | What | Asked | Status | Date | Notes |
| --- | --- | --- | --- | --- | --- |
| D1 | KFGQPC: embed the unmodified KFGQPC Uthmanic Script HAFS font in a free app on the App Store and Google Play | not yet | requested / granted / refused | — | Contact via https://fonts.qurancomplex.gov.sa |
| D2 | QUL / Tarteel: redistribute the KFGQPC layout and word-by-word data inside the app | not yet | requested / granted / refused | — | Contact via https://qul.tarteel.ai |
