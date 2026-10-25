#!/usr/bin/env python3
"""Converts WAV recordings to the 16 kHz mono float32 clips the memorization checks read (specs/007 T002).

Maintainer tool for the check set, which holds volunteers' voices and stays out of the repository:

    py -3.12 tool/wav_to_f32.py recitation-audio.zip-folder/*.wav --out build/asr/check

Each input.wav becomes <out>/<input name>.f32, raw little-endian float32 samples in [-1, 1). Name
the files SSSAAA[-label].wav (067002-swap.wav is Al-Mulk 2) so the desktop tests know the ayah.
16- and 32-bit PCM are read; stereo is averaged to mono; other sample rates are resampled to
16 kHz by linear interpolation. Standard library only.
"""

import argparse
import array
import sys
import wave
from pathlib import Path

SAMPLE_RATE = 16000


def read_mono(path: Path) -> tuple[list[float], int]:
    with wave.open(str(path), "rb") as w:
        width, channels, rate = w.getsampwidth(), w.getnchannels(), w.getframerate()
        frames = w.readframes(w.getnframes())
    if width not in (2, 4):
        sys.exit(f"ERROR: {path.name} is {8 * width}-bit; only 16- and 32-bit PCM are read")
    samples = array.array("h" if width == 2 else "i", frames)
    if sys.byteorder == "big":
        samples.byteswap()
    scale = float(1 << (8 * width - 1))
    mono = [sum(samples[i:i + channels]) / channels / scale for i in range(0, len(samples), channels)]
    return mono, rate


def resample(samples: list[float], rate: int) -> list[float]:
    if rate == SAMPLE_RATE or not samples:
        return samples
    count = int(len(samples) * SAMPLE_RATE / rate)
    step = rate / SAMPLE_RATE
    out = []
    for i in range(count):
        x = i * step
        j = int(x)
        k = min(j + 1, len(samples) - 1)
        out.append(samples[j] + (samples[k] - samples[j]) * (x - j))
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("wavs", nargs="+", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    args.out.mkdir(parents=True, exist_ok=True)
    for path in args.wavs:
        samples, rate = read_mono(path)
        clip = array.array("f", resample(samples, rate))
        if sys.byteorder == "big":
            clip.byteswap()
        target = args.out / f"{path.stem}.f32"
        target.write_bytes(clip.tobytes())
        print(f"{path.name}: {rate} Hz → {target} ({len(clip) / SAMPLE_RATE:.1f} s)")


if __name__ == "__main__":
    main()
