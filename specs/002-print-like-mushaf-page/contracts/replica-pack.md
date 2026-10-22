# Contract: Replica Pack

The optional printed-lettering download (spec User Story 4, FR-014 to FR-021). **Blocked** by D3
(KFGQPC permission) and by spikes S-1 (layout match) and S-2 (font format and memory) in
[research P6](../research.md#p6-exact-replica-pack-fr-014-to-fr-021-format-and-gating).

## Host

Static files at `REPLICA_PACK_URL` (build-time `--dart-define`), versioned path:

```text
{REPLICA_PACK_URL}/{version}/manifest.json
{REPLICA_PACK_URL}/{version}/glyphs.json
{REPLICA_PACK_URL}/{version}/p001.{ext} … p604.{ext}
{REPLICA_PACK_URL}/latest.json        → {"version": "..."}
```

Plain HTTPS GET, no cookies, no headers beyond the defaults, no query strings (FR-020).

## manifest.json

```json
{
  "version": "2026.1",
  "edition": "kfgqpc-v2-1421",
  "format": "woff2",
  "layout_sha256": "<sha256 of the layout the glyphs were checked against>",
  "totalBytes": 97500000,
  "files": [{"name": "glyphs.json", "bytes": 1234567, "crc32": "8c1e…"},
            {"name": "p001.woff2", "bytes": 61234, "crc32": "…"}]
}
```

- `layout_sha256` MUST equal the `quran.db` meta value `source_qul_layout_sha256`. Otherwise the app refuses
  the pack (FR-017) and tells the reader that an app update is needed.

## Build tool

`tool/build_replica_pack.dart` (new) takes the licensed source files and QUL glyph codes, and:
1. checks that every word id in `quran.db` has a glyph and that page and line match the layout
   (SC-008: 100%, or it fails);
2. writes `glyphs.json`, copies the page fonts and writes `manifest.json` with sizes and CRC32;
3. renders all 604 pages offscreen and fails on any missing glyph.

## App behaviour

| Action | Behaviour |
| --- | --- |
| Open Settings › Printed Mushaf | shows the state; for `notInstalled`, the download size (`totalBytes`) and the storage it will use |
| Download | checks free space ≥ `totalBytes × 1.1`; on mobile data asks to confirm; downloads files one by one to `.part`, renaming each when done; progress in Settings |
| Leave app / no network | stops; the state is `paused`; finished files kept |
| Resume | deletes `.part` files, skips finished files whose size matches |
| All downloaded | verifies sizes and CRC32 → `installed`, or `damaged` and lists the bad files |
| Use lettering | `lettering = replica`; pages redraw at once at the same ayah |
| Delete | removes `replica/`, sets `lettering = builtin`, shows the storage freed |
| Startup | derives the state from disk (cheap: manifest + file sizes; CRC32 only after download or repair) |

## Rendering with the pack

- The page font for page *n* is loaded the first time page *n* is shown, prefetching n ± 2.
- Each word is drawn as its glyph string in the page's font, at the position and line of the
  built-in layout, scaled so the line fills the text block. No kashida is added.
- Search, copy, share, semantics and highlights are unchanged (FR-021).
