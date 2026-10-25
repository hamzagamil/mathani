#!/usr/bin/env python3
"""Converts the Khatma FastConformer package to a model sherpa-onnx loads (specs/007 R2, R4, T001).

Maintainer tool, run once per model version; not part of the app build:

    build/asr/venv/Scripts/python tool/export_khatma_model.py --out build/asr/khatma-v1 \
        [--check build/asr/check]

Writes model.int8.onnx (and model.int8.onnx.gz, the file the app downloads), tokens.txt and
silero_vad.onnx into --out, with SHA256SUMS and NOTICE.txt, and prints each file's size and
SHA-256 for asr_model.dart. Every download is checked against a pinned SHA-256, so --hf-endpoint
may name a mirror.

The model keeps Khatma's graph whole, features included, and runs as a sherpa-onnx raw-audio CTC
model (the "omnilingual" type): sherpa-onnx's own NeMo features differ from NeMo's and its NeMo
path drops the last frame, which cut final words in spike S1 (research R2).

--check DIR decodes every 16 kHz mono float32 clip (*.f32) in DIR twice, with Khatma's graph on the
raw clip and with the converted model through sherpa-onnx, and fails when fewer than 97% of the
words agree as the app's matcher compares them: diacritics removed, and the same word when their
similarity reaches the matcher's thetaMatch (spike S1).

Needs: onnx, onnxruntime, numpy, and sherpa-onnx 1.13.8 for --check (see tool/README.md).
"""

import argparse
import difflib
import gzip
import hashlib
import json
import os
import re
import shutil
import struct
import sys
import urllib.request
from pathlib import Path

import numpy as np

# Khatma's package (CC BY 4.0, NVIDIA; MIT, Tilawa export) at the pinned repository commit.
KHATMA = (
    "adnanfet/khatma-model", "35999927467a7ac0198cb0706e3626c7ff3f8ead",
    "fastconformer_ar_khatma_v1.bin",
    89410608, "67043116646830400106be8177f69823e70a90d9b3a5d96d6bb374cab9dc9b9f")
# The NVIDIA model's 1024 SentencePiece pieces, from a sherpa-onnx export of the same model. Only
# the line order is used: that file numbers the pieces from 1, Khatma's graph from 0 with the
# blank last (research R1).
TOKENS = (
    "dev-ahmedhany/stt_ar_fastconformer_hybrid_large_pcd_v1.0-sherpa-ctc",
    "9137361f6f29fa5162aa7aa3d730bdda1e703bf2", "tokens.txt",
    12850, "49ff8d21d22199ae9742fc4c9ab4f0486209ab5c573ee7131aa71289e6828a6a")
SILERO_VAD = (
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx",
    "9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6")

VOCAB = 1025  # 1024 pieces and the blank
BLANK = 1024
SAMPLE_RATE = 16000

# sherpa-onnx's raw-audio CTC models have one input, the waveform; Khatma's graph also takes its
# length in samples, which the converted graph computes from the waveform's shape.
LENGTH = "length"

MIN_AGREEMENT = 0.97
# lib/features/memorization/recitation_matcher.dart: a heard word matches at this similarity.
THETA_MATCH = 0.75

# What the app's normalizeArabic (lib/features/search/arabic_normalizer.dart) removes or unifies,
# so --check compares words as the matcher sees them.
DIACRITICS = re.compile("[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]")
LETTERS = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ى": "ي", "ؤ": "و", "ئ": "ي", "ة": "ه"})

LICENCE = Path(__file__).resolve().parent.parent / "assets" / "licences" / "LICENSE-khatma-model.txt"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch(url: str, target: Path, expected_sha: str) -> Path:
    """Downloads [url] to [target] unless it is already there, then checks its SHA-256."""
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        part = target.with_suffix(target.suffix + ".part")
        print(f"Downloading {url}")
        with urllib.request.urlopen(url) as r, open(part, "wb") as f:
            shutil.copyfileobj(r, f, 1 << 20)
        part.replace(target)
    actual = sha256(target)
    if actual != expected_sha:
        target.unlink()
        sys.exit(f"ERROR: {target.name} has SHA-256 {actual}, expected {expected_sha}")
    return target


def fetch_hf(endpoint: str, pinned: tuple, cache: Path) -> Path:
    repo, commit, name, size, digest = pinned
    path = fetch(f"{endpoint}/{repo}/resolve/{commit}/{name}", cache / repo.replace("/", "--") / name, digest)
    assert path.stat().st_size == size
    return path


def unpack_kfc1(pkg: bytes) -> tuple[bytes, str, bytes]:
    """Splits Khatma's "KFC1" package into its ONNX graph and the int8 weights file it references.

    Layout (as the Memorize-Ayah test project's khatmaPackage.ts): "KFC1", uint32 LE header
    length, a JSON header, then the data. Each matrix is int4 blocks (zero point 8, one float scale
    per block, low nibble first, rows of length K) plus one float scale per output row; the graph
    reads int8 laid out [K, N] with the row scales, so int8[k][n] = round((q − 8) × blockScale /
    rowScale), rounded half up like JavaScript's Math.round.
    """
    if pkg[:4] != b"KFC1":
        sys.exit(f"ERROR: unexpected Khatma package format {pkg[:4]!r}")
    (header_len,) = struct.unpack_from("<I", pkg, 4)
    header = json.loads(pkg[8:8 + header_len])
    if header["verzija"] != 1:
        sys.exit(f"ERROR: unsupported Khatma package version {header['verzija']}")
    base = 8 + header_len
    graph_at, graph_len = header["graf"]
    graph = pkg[base + graph_at:base + graph_at + graph_len]
    out = np.zeros(header["tezine"]["velicina"], dtype=np.int8)
    data = np.frombuffer(pkg, dtype=np.uint8)

    def f32(at: int, count: int) -> np.ndarray:
        return np.frombuffer(pkg, dtype="<f4", count=count, offset=base + at).astype(np.float64)

    for m in header["matrice"]:
        n, k, nb, bs = m["N"], m["K"], m["nb"], m["bs"]
        block_scales = f32(m["sb"][0], n * nb).reshape(n, nb)
        row_scales = f32(m["sk"][0], n)
        packed = data[base + m["b"][0]:base + m["b"][0] + m["b"][1]].reshape(n, k // 2)
        q = np.empty((n, k), dtype=np.float64)
        q[:, 0::2] = (packed & 15).astype(np.float64) - 8
        q[:, 1::2] = (packed >> 4).astype(np.float64) - 8
        scales = block_scales[:, np.arange(k) // bs]
        v = np.floor(q * scales * (1 / row_scales)[:, None] + 0.5)
        v = np.clip(v, -127, 127).astype(np.int8)
        # Layout check: every output row reaches ±127 exactly (its row scale is its maximum).
        short = int(np.count_nonzero(np.abs(v.astype(np.int16)).max(axis=1) != 127))
        if short:
            sys.exit(f"ERROR: {short} of {n} rows of the matrix at {m['izlaz']} do not reach ±127")
        out[m["izlaz"]:m["izlaz"] + k * n] = v.T.reshape(-1)
    return graph, header["tezine"]["putanja"], out.tobytes()


def embed_weights(model, weights_name: str, weights: bytes) -> None:
    """Replaces every reference to the external weights file with the bytes themselves.

    sherpa-onnx reads a model into memory before creating the session, so an external data file
    next to it would not be found (research R2).
    """
    from onnx import TensorProto

    def embed(tensor):
        if tensor.data_location != TensorProto.EXTERNAL:
            return
        info = {e.key: e.value for e in tensor.external_data}
        if info["location"] != weights_name:
            sys.exit(f"ERROR: {tensor.name} refers to unknown external file {info['location']}")
        at = int(info.get("offset", 0))
        tensor.raw_data = weights[at:at + int(info["length"])]
        del tensor.external_data[:]
        tensor.data_location = TensorProto.DEFAULT

    for t in model.graph.initializer:
        embed(t)
    for node in model.graph.node:
        for a in node.attribute:
            if a.HasField("t"):
                embed(a.t)


def length_from_shape(model) -> None:
    """Replaces the `length` input with the waveform's length, read from its shape.

    sherpa-onnx feeds a raw-audio model one input (research R2). It normalises the waveform to zero
    mean and unit variance first; Khatma's per-feature normalisation makes its features nearly
    blind to that (S1: the same words).
    """
    from onnx import helper

    graph = model.graph
    inputs = [i for i in graph.input if i.name == LENGTH]
    if len(inputs) != 1 or [i.name for i in graph.input] != ["audio_signal", LENGTH]:
        sys.exit(f"ERROR: expected inputs audio_signal and {LENGTH}, found {[i.name for i in graph.input]}")
    graph.input.remove(inputs[0])
    graph.node.insert(0, helper.make_node("Shape", ["audio_signal"], [LENGTH], start=1, end=2, name="length_from_shape"))
    if [o.name for o in graph.output] != ["log_probs"]:
        sys.exit(f"ERROR: expected the single output log_probs, found {[o.name for o in graph.output]}")


def write_tokens(reference: Path, target: Path) -> list[str]:
    pieces = [line.split()[0] for line in reference.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(pieces) != VOCAB - 1:
        sys.exit(f"ERROR: expected {VOCAB - 1} pieces in {reference.name}, found {len(pieces)}")
    lines = [f"{p} {i}" for i, p in enumerate(pieces)] + [f"<blk> {BLANK}"]
    target.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    return pieces


def gzip_file(source: Path, target: Path) -> None:
    # mtime 0 and no file name, so the same model always gives the same bytes.
    with open(source, "rb") as src, open(target, "wb") as raw, \
            gzip.GzipFile(filename="", mode="wb", compresslevel=9, fileobj=raw, mtime=0) as dst:
        shutil.copyfileobj(src, dst, 1 << 20)


def check(original: Path, converted: Path, tokens: Path, pieces: list[str], clips: Path) -> None:
    """Spike S1: the converted model in sherpa-onnx must hear the words the original graph hears.

    Diacritics are left out of the comparison: the app strips them, and sherpa-onnx's waveform
    normalisation shifts them more than the words.
    """
    import onnxruntime as ort
    import sherpa_onnx

    session = ort.InferenceSession(str(original), providers=["CPUExecutionProvider"])
    recogniser = sherpa_onnx.OfflineRecognizer.from_omnilingual_asr_ctc(
        model=str(converted), tokens=str(tokens), num_threads=4)

    def words(text: str) -> list[str]:
        cleaned = (re.sub(r"[^\w]", "", DIACRITICS.sub("", w).translate(LETTERS)) for w in text.split())
        return [w for w in cleaned if w]

    def khatma(audio: np.ndarray) -> list[str]:
        (log_probs,) = session.run(None, {
            "audio_signal": audio[None, :], "length": np.array([audio.size], dtype=np.int64)})
        ids, previous = [], None
        for i in log_probs[0].argmax(axis=-1):
            if i != previous and i != BLANK:
                ids.append(int(i))
            previous = i
        return words("".join(pieces[i] for i in ids).replace("\u2581", " "))

    def sherpa(audio: np.ndarray) -> list[str]:
        stream = recogniser.create_stream()
        stream.accept_waveform(SAMPLE_RATE, audio)
        recogniser.decode_stream(stream)
        return words(stream.result.text)

    def similarity(x: str, y: str) -> float:
        """1 − levenshtein / longer length, as the matcher's similarity()."""
        previous = list(range(len(y) + 1))
        for i in range(1, len(x) + 1):
            current = [i] + [0] * len(y)
            for j in range(1, len(y) + 1):
                current[j] = min(current[j - 1] + 1, previous[j] + 1, previous[j - 1] + (x[i - 1] != y[j - 1]))
            previous = current
        return 1 - previous[len(y)] / max(len(x), len(y), 1)

    def agreeing(a: list[str], b: list[str]) -> int:
        """The most word pairs, in order, that the matcher would take for the same word."""
        best = [[0] * (len(b) + 1) for _ in range(len(a) + 1)]
        for i in range(1, len(a) + 1):
            for j in range(1, len(b) + 1):
                same = similarity(a[i - 1], b[j - 1]) >= THETA_MATCH
                best[i][j] = max(best[i - 1][j], best[i][j - 1], best[i - 1][j - 1] + same)
        return best[len(a)][len(b)]

    files = sorted(clips.glob("*.f32"))
    if not files:
        sys.exit(f"ERROR: no .f32 clips in {clips}")
    same = total = 0
    for clip in files:
        audio = np.fromfile(clip, dtype="<f4")
        a, b = khatma(audio), sherpa(audio)
        matcher = difflib.SequenceMatcher(a=a, b=b, autojunk=False)
        agree = agreeing(a, b)
        same += agree
        total += max(len(a), len(b))
        print(f"\n{clip.name}: {agree}/{max(len(a), len(b))} words agree")
        print(f"  khatma: {' '.join(a)}")
        if a != b:
            print(f"  sherpa: {' '.join(b)}")
            for tag, i1, i2, j1, j2 in matcher.get_opcodes():
                if tag != "equal":
                    print(f"    {tag}: {' '.join(a[i1:i2])!r} -> {' '.join(b[j1:j2])!r}")
    share = same / total if total else 0
    print(f"\nS1 equivalence: {same}/{total} words = {share:.2%} (pass at {MIN_AGREEMENT:.0%})")
    if share < MIN_AGREEMENT:
        sys.exit("ERROR: the converted model does not match Khatma; see research R2's fallback")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--check", type=Path, help="folder of 16 kHz mono float32 clips (*.f32)")
    parser.add_argument("--hf-endpoint", default=os.environ.get("HF_ENDPOINT", "https://huggingface.co"))
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    import onnx

    out = args.out.resolve()
    cache = out.parent / "cache"
    endpoint = args.hf_endpoint.rstrip("/")
    package = fetch_hf(endpoint, KHATMA, cache)
    reference_tokens = fetch_hf(endpoint, TOKENS, cache)
    vad = fetch(SILERO_VAD[0], cache / "silero_vad.onnx", SILERO_VAD[1])

    print("Unpacking the Khatma package")
    graph, weights_name, weights = unpack_kfc1(package.read_bytes())
    model = onnx.load_model_from_string(graph)
    embed_weights(model, weights_name, weights)
    del weights
    # The original graph, with its length input, kept in the cache for --check only.
    original = cache / "khatma-original.onnx"
    onnx.save(model, original)

    length_from_shape(model)
    onnx.checker.check_model(model)

    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    onnx.save(model, out / "model.int8.onnx")
    gzip_file(out / "model.int8.onnx", out / "model.int8.onnx.gz")
    pieces = write_tokens(reference_tokens, out / "tokens.txt")
    shutil.copy(vad, out / "silero_vad.onnx")
    shutil.copy(LICENCE, out / "NOTICE.txt")

    names = ["model.int8.onnx", "model.int8.onnx.gz", "tokens.txt", "silero_vad.onnx", "NOTICE.txt"]
    lines = [f"{sha256(out / n)}  {n}" for n in names]
    (out / "SHA256SUMS").write_text("\n".join(lines) + "\n", newline="\n")  # LF for sha256sum -c
    print(f"\nKhatma FastConformer → {out}")
    for n in names:
        print(f"  {n:20} {(out / n).stat().st_size:>10} B  {sha256(out / n)}")

    if args.check:
        check(original, out / "model.int8.onnx", out / "tokens.txt", pieces, args.check.resolve())


if __name__ == "__main__":
    main()
