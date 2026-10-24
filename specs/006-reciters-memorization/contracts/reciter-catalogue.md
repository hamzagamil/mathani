# Contract: Reciter Catalogue and List

Changes to [feature 004's catalogue](../../004-ayah-recitations/contracts/recitation-catalogue.md)
for 51 reciters from EveryAyah and QUL. Research: R0–R5, R18, R19.

## Build

```text
dart run tool/build_recitation_manifest.dart [--reciter <id>] [--concurrency 4] [--skip-existing]
  → tool/sources/recitations/<id>.json      (pinned in tool/sources.lock.json)
dart run tool/add_recitations.dart          (patches assets/db/quran.db)
dart run tool/build_quran_db.dart           (full rebuild writes the same tables)
```

`tool/recitations.json` entries gain `source`, `file_pattern`, `basmala_in_ayah1`, and for
`qul_surah` also `qul_id` (the QUL resource id). `mirror_url` may be null.

Manifest by source:

| Source | How sizes are measured | Manifest |
| --- | --- | --- |
| `everyayah`, `qul_ayah` | HEAD per ayah, as in 004 | `{"reciter", "files": {"1:1": bytes, …}}` |
| `qul_surah` | Read `tool/sources/qul-recitations/<qul_id>.json` (pinned). Then per surah: HEAD for the length; a 128 KB range read for ID3 and the CBR check; a 4 KB range read per ayah boundary for the exact frame start (R19) | `{"reciter", "range_start": {"1": byte, …}, "files": {"1:1": clipBytes, …}}` |

Changes to `tool/src/recitations.dart`:
- `writeRecitationTables` writes `recitation_sizes` (see [data-model](../data-model.md)) instead
  of `recitation_files`, and drops `recitation_files` if present.
- **New checks**:
  - every size satisfies 0 < size < 2²⁴;
  - ids are unique and match `^[a-z0-9_]+$`;
  - `style` ∈ {murattal, mujawwad, muallim};
  - `base_url` + `file_pattern` is unique;
  - for `qul_surah`: CBR, all 114 surahs, 6,236 increasing timings, and
    `range_start + Σ sizes == file length` for every surah.
- A reciter whose manifest is missing or fails **fails the build**, as today. To drop a
  reciter, remove it from `tool/recitations.json`.

`--skip-existing` skips reciters whose manifest already matches the lock file, so the first full
run (about 3 hours) can resume.

## Repository API

| Member | Change |
| --- | --- |
| `reciters` | 51 entries; `Reciter` gains `source`, `filePattern` and `basmalaInAyah1`; `mirrorUrl` is nullable |
| `recordingBytes(reciter, surah)` | Reads one `recitation_sizes` row and decodes 3-byte LE integers |
| `clipRange(reciter, surah, ayah)` | **New**: `(start, endExclusive)` byte range for `qul_surah`, null otherwise |
| `surahDownloadBytes(reciter, surah)` | Unchanged. The basmala is added only when `!basmalaInAyah1` |

`Reciter.urlFor(surah, ayah, {mirror})`:
- ayah sources: `'$base/${pad3(surah)}${pad3(ayah)}.mp3'`, as in 004;
- `qul_surah`: the surah file, `base` + `file_pattern` with `{sss}` = `pad3(surah)` and `{s}` =
  `surah`. `ayah` is ignored; the range comes from `clipRange`.

Unit tests:
- `husary` and `minshawy` return the same values as the 004 catalogue for all 114 surahs;
- for a `qul_surah` fixture, the clip ranges are contiguous and cover the file.

## Fetching QUL surah clips (change to `AyahFetcher`)

For a reciter with `source == qul_surah`, `_get`:
- sends `Range: bytes=<start>-<endExclusive − 1>` to `urlFor(surah, ayah)`;
- requires `206` with `Content-Range: bytes <start>-<end>/<fileLength>` and the expected length;
- writes the clip to the usual per-ayah file through `.part`, as today.

A `200` (range ignored) or a wrong range is a retry, never a partial accept. There is no mirror,
so the 004 mirror fallback is skipped. Everything after the fetch (cache, downloads, playlist,
validity check `file.length() == bytes`) is unchanged.

The playlist skips the basmala item when `reciter.basmalaInAyah1`. The `recitedBasmala` highlight
is therefore never set for these reciters (R18).

## Rows

**EveryAyah** (`source: everyayah`, `file_pattern: {sss}{aaa}.mp3`, `basmala_in_ayah1: 0`):
`base_url` is `https://everyayah.com/data/<folder>` and `mirror_url` is
`https://mirrors.quranicaudio.com/everyayah/<folder>`.

The Arabic and English names below are drafts. The owner confirms every Arabic name before
release (quickstart Q-3); `tool/recitations.json` is the source of truth.

| id | Folder | kbps | style | name_ar | name_en |
| --- | --- | --- | --- | --- | --- |
| husary | Husary_64kbps | 64 | murattal | محمود خليل الحصري | Mahmoud Khalil Al-Husary |
| minshawy | Minshawy_Murattal_128kbps | 128 | murattal | محمد صديق المنشاوي | Mohamed Siddiq El-Minshawi |
| husary_mujawwad | Husary_Mujawwad_64kbps | 64 | mujawwad | محمود خليل الحصري | Mahmoud Khalil Al-Husary |
| husary_muallim | Husary_Muallim_128kbps | 128 | muallim | محمود خليل الحصري | Mahmoud Khalil Al-Husary |
| minshawy_mujawwad | Minshawy_Mujawwad_64kbps | 64 | mujawwad | محمد صديق المنشاوي | Mohamed Siddiq El-Minshawi |
| abdulbasit_murattal | Abdul_Basit_Murattal_64kbps | 64 | murattal | عبد الباسط عبد الصمد | Abdul Basit Abdus-Samad |
| abdulbasit_mujawwad | Abdul_Basit_Mujawwad_128kbps | 128 | mujawwad | عبد الباسط عبد الصمد | Abdul Basit Abdus-Samad |
| tablawi | Mohammad_al_Tablaway_64kbps | 64 | murattal (V-1) | محمد محمود الطبلاوي | Mohamed Mahmoud Al-Tablawi |
| banna | mahmoud_ali_al_banna_32kbps | 32 | murattal | محمود علي البنا | Mahmoud Ali Al-Banna |
| alafasy | Alafasy_64kbps | 64 | murattal | مشاري راشد العفاسي | Mishary Rashid Alafasy |
| sudais | Abdurrahmaan_As-Sudais_64kbps | 64 | murattal | عبد الرحمن السديس | Abdul Rahman Al-Sudais |
| shuraim | Saood_ash-Shuraym_64kbps | 64 | murattal | سعود الشريم | Saud Al-Shuraim |
| muaiqly | Maher_AlMuaiqly_64kbps | 64 | murattal | ماهر المعيقلي | Maher Al-Muaiqly |
| ghamdi | Ghamadi_40kbps | 40 | murattal | سعد الغامدي | Saad Al-Ghamdi |
| shatri | Abu_Bakr_Ash-Shaatree_64kbps | 64 | murattal | أبو بكر الشاطري | Abu Bakr Al-Shatri |
| ajamy | Ahmed_ibn_Ali_al-Ajamy_64kbps_QuranExplorer.Com | 64 | murattal | أحمد بن علي العجمي | Ahmed ibn Ali Al-Ajamy |
| basfar | Abdullah_Basfar_64kbps | 64 | murattal | عبد الله بصفر | Abdullah Basfar |
| hudhaify | Hudhaify_64kbps | 64 | murattal | علي الحذيفي | Ali Al-Hudhaify |
| ayyoub | Muhammad_Ayyoub_64kbps | 64 | murattal | محمد أيوب | Muhammad Ayyoub |
| jibreel | Muhammad_Jibreel_64kbps | 64 | murattal | محمد جبريل | Muhammad Jibreel |
| rifai | Hani_Rifai_64kbps | 64 | murattal | هاني الرفاعي | Hani Ar-Rifai |
| akhdar | Ibrahim_Akhdar_32kbps | 32 | murattal | إبراهيم الأخضر | Ibrahim Al-Akhdar |
| bukhatir | Salaah_AbdulRahman_Bukhatir_128kbps | 128 | murattal | صلاح بو خاطر | Salah Bukhatir |
| muhsin_qasim | Muhsin_Al_Qasim_192kbps | 192 | murattal | عبد المحسن القاسم | Abdul Muhsin Al-Qasim |
| juhany | Abdullaah_3awwaad_Al-Juhaynee_128kbps | 128 | murattal | عبد الله عواد الجهني | Abdullah Awwad Al-Juhany |
| budair | Salah_Al_Budair_128kbps | 128 | murattal | صلاح البدير | Salah Al-Budair |
| matroud | Abdullah_Matroud_128kbps | 128 | murattal | عبد الله المطرود | Abdullah Al-Matroud |
| neana | Ahmed_Neana_128kbps | 128 | murattal | أحمد نعينع | Ahmed Neana |
| abdulkareem | Muhammad_AbdulKareem_128kbps | 128 | murattal | محمد عبد الكريم | Muhammad Abdul Kareem |
| tunaiji | khalefa_al_tunaiji_64kbps | 64 | murattal | خليفة الطنيجي | Khalifa Al-Tunaiji |
| mansoori | Karim_Mansoori_40kbps | 40 | murattal | كريم منصوري | Karim Mansoori |
| parhizgar | Parhizgar_48kbps | 48 | murattal | شهريار پرهيزگار | Shahriar Parhizgar |
| qahtani | Khaalid_Abdullaah_al-Qahtaanee_192kbps | 192 | murattal | خالد القحطاني | Khalid Al-Qahtani |
| dossari | Yasser_Ad-Dussary_128kbps | 128 | murattal | ياسر الدوسري | Yasser Al-Dosari |
| qatami | Nasser_Alqatami_128kbps | 128 | murattal | ناصر القطامي | Nasser Al-Qatami |
| suesy | Ali_Hajjaj_AlSuesy_128kbps | 128 | murattal | علي حجاج السويسي | Ali Hajjaj Al-Suesy |
| sahl_yassin | Sahl_Yassin_128kbps | 128 | murattal | سهل ياسين | Sahl Yassin |
| alili | aziz_alili_128kbps | 128 | murattal | عزيز عليلي | Aziz Alili |
| salamah | Yaser_Salamah_128kbps | 128 | murattal | ياسر سلامة | Yaser Salamah |
| alaqimy | Akram_AlAlaqimy_128kbps | 128 | murattal | أكرم العلاقمي | Akram Al-Alaqimy |
| ali_jaber | Ali_Jaber_64kbps | 64 | murattal | علي جابر | Ali Jaber |
| fares_abbad | Fares_Abbad_64kbps | 64 | murattal | فارس عباد | Fares Abbad |
| ayman_sowaid | Ayman_Sowaid_64kbps | 64 | muallim (V-1) | أيمن سويد | Ayman Suwayd |

`(V-1)`: the style is confirmed by listening (research R2) and corrected here if wrong.

**QUL** (research R0). `mirror_url` is null for all of them.

| id | source | QUL id | base_url | file_pattern | kbps | style | name_ar | name_en |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| alnufais | qul_ayah | 471 | `https://audio-cdn.tarteel.ai/quran/alnufais` | `{sss}{aaa}.mp3` | 128 (V-1) | murattal | أحمد النفيس | Ahmad Al-Nufais |
| minshawy_children | qul_surah | 314 | `https://audio-cdn.tarteel.ai/quran/surah/minshawy/kids_repeat/mp3` | `{sss}.mp3` | 128 | muallim | محمد صديق المنشاوي (مع الأطفال) | Mohamed Siddiq El-Minshawi (with children) |
| mostafa_ismail | qul_surah | 346 | `https://download.quranicaudio.com/quran/mostafa_ismaeel/` | `{sss}.mp3` | 128 | murattal (V-1) | مصطفى إسماعيل | Mustafa Ismail |
| husary_ijazah | qul_surah | 368 | `https://download.quranicaudio.com/quran/mahmood_khaleel_al-husaree_iza3a/` | `{sss}.mp3` | 128 | murattal | محمود خليل الحصري (إجازة) | Mahmoud Khalil Al-Husary (Ijazah) |
| bandar_baleela | qul_surah | 388 | `https://download.quranicaudio.com/quran/bandar_baleela/complete/` | `{sss}.mp3` | 128 | murattal | بندر بليلة | Bandar Baleela |
| khalid_jalil | qul_surah | 420 | `https://download.quranicaudio.com/qdc/khalid_jalil/murattal/mp3` | `{s}.mp3` | 96 | murattal | خالد الجليل | Khalid Al-Jalil |
| hady_toure | qul_surah | 421 | `https://download.quranicaudio.com/qdc/hadi_toure/mp3` | `{s}.mp3` | 96 | murattal | هادي توري | Hady Toure |
| salimi | qul_surah | 572 | `https://audio-cdn.tarteel.ai/quran/surah/mansourAlSalimi/murattal/mp3` | `{sss}.mp3` | 128 | murattal | منصور السالمي | Mansour Al-Salimi |

`qul_surah` rows have `basmala_in_ayah1: 1`. A trailing `/` on `base_url` reproduces the host's
double slash (`…/complete//001.mp3`) exactly as the host serves it; `urlFor` joins with `/`.

**Not offered** (R0, R1):
- **From EveryAyah**: translations, `MultiLanguage/Basfar_Walk`, Warsh sets,
  `Mustafa_Ismail_48kbps` (incomplete; QUL's surah set is used instead),
  `AbdulSamad_64kbps_QuranExplorer.Com`, `Menshawi_16kbps` and `_32kbps`, the other Al-Ajamy
  sets, and any other bitrate of a listed reciter and style.
- **From QUL**:
  - ayah-by-ayah sets that are copies of EveryAyah folders already listed;
  - timed surah sets of reciters and styles already listed (for example Alafasy 411/414,
    Maher 405/562);
  - the two with English translation (327, 331);
  - Abu Bakr Dhaby (473: surah 2 missing);
  - all 68 untimed sets (Taraweeh, translations, other narrations, or no ayah timings).

## Reciter list (UI, replaces the 004 reciter sheet)

`showReciterSheet(context, {downloaded})`, with the same signature, opens a
`DraggableScrollableSheet`:

| Part | Behaviour |
| --- | --- |
| Title | «اختر القارئ» / "Choose a reciter" (existing `chooseReciter` string) |
| Search field | Placeholder «ابحث عن قارئ» / "Search reciters". Filters as the reader types (R5). Clear button. Empty result: «لا يوجد قارئ بهذا الاسم» / "No reciter with this name" |
| Rows | `ListView.builder` over 51 rows, sorted by name in the interface language. Title: name in the interface language. Subtitle: style label, plus the Arabic name in the English UI (as in 004). Leading: downloaded mark for the current surah. Trailing: check on the chosen reciter |
| Opening | Scrolled so the chosen row is visible |
| Tap | Unchanged: `chooseReciter(reader, recitation, r)` |

Style labels: «مرتّل» / "Murattal", «مجوّد» / "Mujawwad", «معلّم» / "Teaching".

Every row is a 56 dp tile, which meets the 48 dp minimum. Search field semantics: "Search
reciters". The onboarding reciter step (feature 005) uses the same list widget,
`ReciterList`, embedded in the step.

Downloads screen (feature 004): unchanged. It already groups by reciter and now lists whichever
reciters have downloads.
