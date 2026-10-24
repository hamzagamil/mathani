#!/usr/bin/env python3
"""Exports a Tarteel Whisper fine-tune to the int8 ONNX files sherpa-onnx loads (specs/006 R8, T028).

Maintainer tool, run once per model version; not part of the app build:

    py -3.12 tool/export_asr_model.py --model tarteel-ai/whisper-tiny-ar-quran \
        --out build/asr/tarteel-tiny-v1

Writes encoder.int8.onnx, decoder.int8.onnx, tokens.txt and silero_vad.onnx into --out, with a
SHA256SUMS file, and prints each file's size and SHA-256 for asr_model.dart. Every download is
checked against a pinned SHA-256, so --hf-endpoint may name a mirror.

Needs: torch, openai-whisper, onnx, onnxruntime (see tool/README.md).
"""

import argparse
import hashlib
import importlib.util
import os
import re
import shutil
import sys
import urllib.request
from pathlib import Path

# Hugging Face checkpoints (Apache-2.0): (size, SHA-256) of pytorch_model.bin at the pinned commit.
MODELS = {
    "tarteel-ai/whisper-tiny-ar-quran": (
        151098921, "f26c96202427524ec015bcf25bd932414df0474e538d765c16759f1095757688"),
    "tarteel-ai/whisper-base-ar-quran": (
        290458721, "ec75894993a4570a237b2b1c19fd8a448f1e8f6e083cfab699574f7be53874fa"),
}

# sherpa-onnx's Whisper export script and voice activity model, at the version the app uses.
SHERPA_TAG = "v1.13.8"
EXPORT_SCRIPT = (
    f"https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/{SHERPA_TAG}/scripts/whisper/export-onnx.py",
    "5e0ddabfac8330ee9aecaba4c1b4286d1cd9f88df4cd30e54706b011bf976e45")
SILERO_VAD = (
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx",
    "9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6")

# Whisper's attention heads are always 64 wide.
HEAD_WIDTH = 64


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


def openai_whisper_model(checkpoint: Path):
    """Loads a Hugging Face Whisper checkpoint as an openai-whisper model.

    The dimensions come from the weights' shapes, so no unpinned config file is trusted.
    """
    import torch
    from whisper.model import ModelDimensions, Whisper

    renames = [
        ("encoder.embed_positions.weight", "encoder.positional_embedding"),
        ("decoder.embed_positions.weight", "decoder.positional_embedding"),
        ("decoder.embed_tokens", "decoder.token_embedding"),
        (".layers.", ".blocks."),
        ("encoder.layer_norm", "encoder.ln_post"),
        ("decoder.layer_norm", "decoder.ln"),
        (".self_attn_layer_norm", ".attn_ln"),
        (".encoder_attn_layer_norm", ".cross_attn_ln"),
        (".final_layer_norm", ".mlp_ln"),
        (".self_attn.", ".attn."),
        (".encoder_attn.", ".cross_attn."),
        (".q_proj", ".query"),
        (".k_proj", ".key"),
        (".v_proj", ".value"),
        (".out_proj", ".out"),
        (".fc1", ".mlp.0"),
        (".fc2", ".mlp.2"),
    ]
    state = {}
    for key, value in torch.load(checkpoint, map_location="cpu", weights_only=True).items():
        if key == "proj_out.weight":  # tied to the token embedding
            continue
        key = key.removeprefix("model.")
        for old, new in renames:
            key = key.replace(old, new)
        state[key] = value

    def layers(part: str) -> int:
        return len({m.group(1) for k in state for m in [re.match(rf"{part}\.blocks\.(\d+)\.", k)] if m})

    audio_state = state["encoder.conv1.weight"].shape[0]
    text_state = state["decoder.token_embedding.weight"].shape[1]
    dims = ModelDimensions(
        n_mels=state["encoder.conv1.weight"].shape[1],
        n_audio_ctx=state["encoder.positional_embedding"].shape[0],
        n_audio_state=audio_state,
        n_audio_head=audio_state // HEAD_WIDTH,
        n_audio_layer=layers("encoder"),
        n_vocab=state["decoder.token_embedding.weight"].shape[0],
        n_text_ctx=state["decoder.positional_embedding"].shape[0],
        n_text_state=text_state,
        n_text_head=text_state // HEAD_WIDTH,
        n_text_layer=layers("decoder"),
    )
    model = Whisper(dims)
    model.load_state_dict(state, strict=True)
    return model


def quantize_embeddings(fp32_path: str, int8_path: str):
    """Quantises the decoder to int8 including its token embedding (vocabulary × width).

    sherpa-onnx's export computes the logits as MatMul(embedding, xᵀ). onnxruntime quantises only
    a MatMul's second input, so the embedding stays fp32: 80 of tiny's 90 MB. Rewriting that node
    as Transpose(MatMul(xᵀ, embeddingᵀ)), which is equal, lets both it and the embedding's Gather
    be quantised.
    """
    import onnx
    from onnx import helper, numpy_helper
    from onnxruntime.quantization import QuantType, quantize_dynamic

    model = onnx.load(fp32_path)
    graph = model.graph
    inits = {i.name: i for i in graph.initializer}
    # The export passes the weight to the MatMul through an Identity.
    weights = dict(inits)
    for n in graph.node:
        if n.op_type == "Identity" and n.input[0] in inits:
            weights[n.output[0]] = inits[n.input[0]]
    matmuls = [n for n in graph.node if n.op_type == "MatMul" and n.input[0] in weights]
    if len(matmuls) != 1:
        sys.exit(f"ERROR: expected one MatMul with a weight as its first input, found {len(matmuls)}")
    node = matmuls[0]
    weight, x = node.input
    transposed = numpy_helper.from_array(
        numpy_helper.to_array(weights[weight]).T.copy(), weights[weight].name + "_T")
    graph.initializer.append(transposed)
    index = list(graph.node).index(node)
    graph.node.remove(node)
    for offset, new in enumerate([
        helper.make_node("Transpose", [x], [x + "_T"], perm=[0, 2, 1]),
        helper.make_node("MatMul", [x + "_T", transposed.name], [node.output[0] + "_T"]),
        helper.make_node("Transpose", [node.output[0] + "_T"], [node.output[0]], perm=[0, 2, 1]),
    ]):
        graph.node.insert(index + offset, new)
    # Drop the Identity that fed the old MatMul, or it keeps the fp32 embedding alive.
    used = {i for n in graph.node for i in n.input} | {o.name for o in graph.output}
    for n in [n for n in graph.node if n.op_type == "Identity" and n.output[0] not in used]:
        graph.node.remove(n)
    onnx.save(model, fp32_path)
    quantize_dynamic(model_input=fp32_path, model_output=int8_path,
                     op_types_to_quantize=["MatMul", "Gather"], weight_type=QuantType.QInt8)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--model", required=True, choices=sorted(MODELS))
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--embeddings", choices=["int8", "fp32"], default="int8",
                        help="the decoder's token embedding: int8 (default) or fp32 as sherpa-onnx ships")
    parser.add_argument("--hf-endpoint", default=os.environ.get("HF_ENDPOINT", "https://huggingface.co"))
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    out = args.out.resolve()
    cache = out.parent / "cache"
    size, model_sha = MODELS[args.model]
    checkpoint = fetch(f"{args.hf_endpoint.rstrip('/')}/{args.model}/resolve/main/pytorch_model.bin",
                       cache / args.model.replace("/", "--") / "pytorch_model.bin", model_sha)
    assert checkpoint.stat().st_size == size
    script = fetch(EXPORT_SCRIPT[0], cache / f"sherpa-onnx-{SHERPA_TAG}-export-onnx.py", EXPORT_SCRIPT[1])

    # Run sherpa-onnx's export on our model: it writes <name>-*.onnx and <name>-tokens.txt into
    # the working directory, and quantises both halves to int8.
    spec = importlib.util.spec_from_file_location("sherpa_whisper_export", script)
    export = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(export)
    model = openai_whisper_model(checkpoint)
    export.load_model = lambda name: model
    export.get_args = lambda: argparse.Namespace(model="model")

    import torch
    from whisper.model import disable_sdpa

    # sherpa-onnx's script targets the TorchScript exporter (dynamic_axes, opset 17); newer torch
    # defaults to the dynamo exporter.
    torch_export = torch.onnx.export
    torch.onnx.export = lambda *a, **k: torch_export(*a, **{**k, "dynamo": False})

    work = cache / "work"
    shutil.rmtree(work, ignore_errors=True)
    work.mkdir(parents=True)
    cwd = os.getcwd()
    os.chdir(work)
    try:
        torch.set_num_threads(1)
        with disable_sdpa():
            export.main()
        if args.embeddings == "int8":
            quantize_embeddings("model-decoder.onnx", "model-decoder.int8.onnx")
    finally:
        os.chdir(cwd)

    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    for source, target in [("model-encoder.int8.onnx", "encoder.int8.onnx"),
                           ("model-decoder.int8.onnx", "decoder.int8.onnx"),
                           ("model-tokens.txt", "tokens.txt")]:
        shutil.move(work / source, out / target)
    shutil.copy(fetch(SILERO_VAD[0], cache / "silero_vad.onnx", SILERO_VAD[1]), out / "silero_vad.onnx")
    shutil.rmtree(work)

    names = ["encoder.int8.onnx", "decoder.int8.onnx", "tokens.txt", "silero_vad.onnx"]
    lines = [f"{sha256(out / n)}  {n}" for n in names]
    (out / "SHA256SUMS").write_text("\n".join(lines) + "\n", newline="\n")  # LF for sha256sum -c
    print(f"\n{args.model} → {out}")
    for n in names:
        print(f"  {n:20} {(out / n).stat().st_size:>10} B  {sha256(out / n)}")


if __name__ == "__main__":
    main()
