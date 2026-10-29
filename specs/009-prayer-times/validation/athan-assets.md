# G02 audio preparation — 2026-10-29

Status: **OPEN**. No production catalogue, recording, opening clip or hosted download has been published.

The user rejected the original Beautiful/Madinah sources and requested Egyptian athan. The user selected Al-Hussary and replied `0:12` to the listening/boundary question. This was stated back as 0:00–0:12. The decision is recorded against the source SHA-256 in `tool/prayer/athan_review.json`; it is user review, not an independent listening claim by the implementation agent.

`tool/prayer/athan_sources.json` pins Al-Hussary and El-Minshawi source URLs and original hashes. Both have **UNVERIFIED** redistribution permission. El-Minshawi has no approved listening review or opening interval. These facts keep `readyForShipping` false.

Preparation ran successfully using:

```powershell
uv run --python 3.12 --with imageio-ffmpeg==0.6.0 --no-project tool/prayer/prepare_athan.py --source-dir build/prayer-audio-review --output-dir build/prayer-egyptian-review --reviews tool/prayer/athan_review.json
```

Local, ignored output includes full AAC review files, the Husary opening CAF/OGG, a generated Qiyam tone and `athan_catalogue.review.json`. Husary full duration is 127454ms; opening decoded CAF duration is 12002ms (under the iOS 30000ms threshold). Its CAF SHA-256 is `33daa88033022622c7330b07b49066a77060cfd0b44757715d9e0e874b9d9f40`; OGG SHA-256 is `fb88c4e5ff2bed17c07aa24f94f678b1a12fdbd660b3e4e866b2573d56f42440`.

Remaining: confirm redistribution rights and retain evidence/license/attribution; approve a second suitable recording and four-takbir interval; review prepared playback on both platforms; only then register cleared assets and publish the catalogue. The debug startup prototype uses an original generated tone, never these unlicensed recordings.

## User correction

The user identified that `984f3e129c8c.mp3` is not El-Minshawi. The source hash is now recorded under `rejectedSources`, excluded from the preparation input, and its performer identity is left unverified. The earlier two-file preparation result above is historical evidence only. Subsequent review manifests contain only the Husary candidate; the old ignored review audio must not be promoted or attributed to El-Minshawi. A replacement second recording is still required.

Preparation was rerun to `build/prayer-egyptian-review-corrected/` and returned `recordingsPrepared: 1`, `missing: []`, `readyForShipping: false`. No incorrect attribution is carried into that manifest or a production catalogue.
