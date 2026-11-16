"""Prepare review copies first; publish only explicitly reviewed audio.

uv run --python 3.12 --with imageio-ffmpeg==0.6.0 --no-project \
  tool/prayer/prepare_athan.py --source-dir build/prayer-audio-review

No guessed opening cuts, tempo changes, runtime FFmpeg or bundled full files.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

SOURCES = json.loads(Path(__file__).with_name("athan_sources.json").read_text(encoding="utf-8"))["sources"]

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def run(ffmpeg: str, *args: str) -> bytes:
    result = subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-nostdin", *args],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if result.returncode:
        # Paths are local; no network command or raw provider error is logged.
        raise RuntimeError("Audio conversion failed: " + result.stderr.decode("utf-8", errors="replace")[:500])
    return result.stdout

def duration(ffmpeg: str, path: Path) -> int:
    samples = run(ffmpeg, "-i", str(path), "-f", "s16le", "-ac", "1", "-ar", "16000", "pipe:1")
    if not samples:
        raise ValueError("Empty decoded audio")
    return round(len(samples) / 2 / 16000 * 1000)

def describe(ffmpeg: str, path: Path, encoding: str) -> dict:
    return dict(sha256=sha(path), expectedBytes=path.stat().st_size,
                durationMs=duration(ffmpeg, path), encoding=encoding)

def prepare(source_dir: Path, output: Path, reviews: dict, ffmpeg: str) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    manifest = dict(schemaVersion=1, readyForShipping=False, recordings=[], missing=[])
    for source in SOURCES:
        original = source_dir / source["filename"]
        if not original.is_file():
            manifest["missing"].append(source["id"])
            continue
        source_hash = sha(original)
        if source.get("sourceSha256", source_hash) != source_hash:
            raise ValueError("Source revision changed: " + source["id"])
        entry = {key: value for key, value in source.items() if key not in ("filename",)}
        entry["sourceSha256"] = source_hash
        full = output / (source["id"] + ".m4a")
        run(ffmpeg, "-y", "-i", str(original), "-map_metadata", "-1", "-vn", "-ac", "1",
            "-ar", "44100", "-c:a", "aac", "-b:a", "64k", "-movflags", "+faststart", str(full))
        entry.update(describe(ffmpeg, full, "aac-lc/m4a"))
        entry["fullAssetUrl"] = "https://get.mthani.app/athan/v1/" + full.name
        entry["changeNotice"] = "Resampled to mono 44.1 kHz and compressed as AAC. Opening variants use only reviewed boundaries; no speed change."
        review = reviews.get(source["id"], {})
        reviewed_source = review.get("sourceSha256") == source_hash and bool(review.get("reviewedBy"))
        entry["redistributionConfirmed"] = (source.get("redistributionConfirmed") is True
                                            and source.get("licenseId") in ("CC0-1.0", "CC-BY-3.0"))
        entry["completeRecordingReviewed"] = reviewed_source and review.get("completeRecordingReviewed") is True
        entry["fourTakbirsReviewed"] = False
        entry["openingDurationMs"] = 0
        entry["iosShortEligible"] = False
        if entry["completeRecordingReviewed"] and review.get("fourTakbirsReviewed") is True:
            start, end = review.get("openingStartMs"), review.get("openingEndMs")
            if type(start) is not int or type(end) is not int or not 0 <= start < end <= entry["durationMs"]:
                raise ValueError("Invalid reviewed boundaries: " + source["id"])
            entry.update(fourTakbirsReviewed=True, openingStartMs=start, openingEndMs=end)
            entry["openingAssetId"] = source["id"].replace("-", "_") + "_opening"
            variants = {}
            for suffix, codec, rate in [("caf", "adpcm_ima_qt", "22050"), ("ogg", "libvorbis", "22050")]:
                clip = output / (entry["openingAssetId"] + "." + suffix)
                run(ffmpeg, "-y", "-i", str(original), "-ss", str(start / 1000), "-t", str((end-start) / 1000),
                    "-map_metadata", "-1", "-vn", "-ac", "1", "-ar", rate, "-c:a", codec, str(clip))
                variants[suffix] = describe(ffmpeg, clip, codec)
            entry["openingVariants"] = variants
            entry["openingDurationMs"] = variants["caf"]["durationMs"]
            entry["iosShortEligible"] = entry["openingDurationMs"] < 30000
        manifest["recordings"].append(entry)

    # The bundled alert sound (sound id `tone`): the first takbira, cut at reviewed boundaries.
    takbira_review = reviews.get("takbira", {})
    takbira_source = next((s for s in SOURCES if s["id"] == takbira_review.get("sourceId")), None)
    if takbira_source and (source_dir / takbira_source["filename"]).is_file():
        original = source_dir / takbira_source["filename"]
        if sha(original) != takbira_review.get("sourceSha256"):
            raise ValueError("Takbira source revision changed")
        start, end, fade = takbira_review["startMs"], takbira_review["endMs"], takbira_review["fadeOutMs"]
        if not 0 <= start < end or not 0 <= fade <= end - start:
            raise ValueError("Invalid takbira boundaries")
        cut = ["-ss", str(start / 1000), "-t", str((end - start) / 1000), "-map_metadata", "-1", "-vn",
               "-ac", "1", "-ar", "22050", "-af", f"afade=t=out:st={(end - start - fade) / 1000}:d={fade / 1000}"]
        wav, caf = output / "athan_takbira.wav", output / "athan_takbira.caf"
        run(ffmpeg, "-y", "-i", str(original), *cut, "-c:a", "pcm_s16le", str(wav))
        run(ffmpeg, "-y", "-i", str(original), *cut, "-c:a", "adpcm_ima_qt", str(caf))
        manifest["takbira"] = {"sourceId": takbira_source["id"], "licenseId": takbira_source["licenseId"],
                               "startMs": start, "endMs": end,
                               "changeNotice": "First takbira of the athan, resampled to mono 22.05 kHz with a fade-out.",
                               "wav": describe(ffmpeg, wav, "pcm_s16le"), "caf": describe(ffmpeg, caf, "adpcm_ima_qt")}
    manifest["readyForShipping"] = len(manifest["recordings"]) == 2 and all(
        item["completeRecordingReviewed"] and item["fourTakbirsReviewed"] and item["iosShortEligible"] and item["redistributionConfirmed"]
        for item in manifest["recordings"])
    (output / "athan_catalogue.review.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=Path("build/prayer-audio-prepared"))
    parser.add_argument("--reviews", type=Path)
    parser.add_argument("--ffmpeg")
    args = parser.parse_args()
    ffmpeg = args.ffmpeg
    if not ffmpeg:
        import imageio_ffmpeg
        ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    reviews = json.loads(args.reviews.read_text(encoding="utf-8")) if args.reviews else {}
    manifest = prepare(args.source_dir, args.output_dir, reviews, ffmpeg)
    print(json.dumps(dict(recordingsPrepared=len(manifest["recordings"]), missing=manifest["missing"],
                          readyForShipping=manifest["readyForShipping"], output=str(args.output_dir))))

if __name__ == "__main__":
    main()
