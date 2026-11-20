#!/usr/bin/env python3
"""Generate the dialogue track for an episode with an offline Chinese TTS model.

    KOKORO_DIR=/path/to/kokoro-multi-lang-v1_1 python3 tools/voice.py ep01

Writes ep01/voice/lineNN.wav (48 kHz mono) plus ep01/voice/voices.json, which
tools/animatic.py mixes into the preview. The voices are generic AI voices from
the open Kokoro v1.1-zh model (Apache-2.0), not the anime's voice actors.

Model download (about 350 MB):
  https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_1.tar.bz2
Engine:  pip install sherpa-onnx
"""
from __future__ import annotations

import json
import os
import sys
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build import ROOT, layout, validate  # noqa: E402

OUT_SR = 48000

# Who sounds like what. sid = Kokoro v1.1 speaker id (58-102 are male voices).
# pitch < 1 lowers the voice without changing its tempo.
CAST = {
    "鸣人": {"sid": 99, "pitch": 1.0},                       # bright, quick young male
    "自来也": {"sid": 68, "pitch": 0.95},                    # low, warm, older
    "佩恩·天道": {"sid": 74, "pitch": 0.93, "reverb": (1.5, 0.30), "lowpass": 5200},  # flat and cold
    # 分不清男女：an in-between voice, a sub-octave copy and a higher voice, in a big space
    "陌生声音": {"layers": [(46, 1.0, 1.0), (46, 0.5, 0.35), (13, 0.97, 0.45)], "reverb": (2.6, 0.45)},
}

# (clip, nth line in clip) -> (speed, gain). Speed < 1 is slower.
STYLE = {
    ("1B", 0): (0.85, 0.9), ("1C", 0): (0.80, 0.85), ("2B", 0): (0.95, 1.0),
    ("3D", 0): (0.85, 0.75), ("3E", 0): (0.90, 1.0), ("4D", 0): (0.85, 1.0),
    ("4E", 0): (1.00, 1.05), ("4E", 1): (0.90, 1.0), ("5C", 0): (0.90, 1.0),
    ("5D", 0): (0.90, 1.0), ("6A", 0): (0.80, 0.9), ("6E", 0): (0.95, 0.8),
    ("7C", 0): (1.00, 0.9), ("7C", 1): (1.00, 0.95), ("8B", 0): (0.80, 1.0),
    ("8C", 0): (0.85, 0.9), ("8D", 0): (0.95, 1.05), ("8D", 1): (1.05, 1.3),
}

TUNNEL_CLIPS = {"3", "4", "5"}  # shots set in the underground waterway get a little room echo


def load_tts(model_dir: str):
    import sherpa_onnx
    d = model_dir.rstrip("/")
    cfg = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            kokoro=sherpa_onnx.OfflineTtsKokoroModelConfig(
                model=f"{d}/model.onnx", voices=f"{d}/voices.bin", tokens=f"{d}/tokens.txt",
                data_dir=f"{d}/espeak-ng-data", dict_dir=f"{d}/dict",
                lexicon=f"{d}/lexicon-us-en.txt,{d}/lexicon-zh.txt"),
            num_threads=os.cpu_count() or 2),
        rule_fsts=f"{d}/phone-zh.fst,{d}/date-zh.fst,{d}/number-zh.fst",
        max_num_sentences=1)
    return sherpa_onnx.OfflineTts(cfg)


def synth(tts, text: str, sid: int, speed: float, pitch: float) -> np.ndarray:
    """Speech at OUT_SR with pitch shifted by `pitch` and tempo `speed`."""
    a = tts.generate(text, sid=sid, speed=speed / pitch)
    x = np.asarray(a.samples, np.float32)
    step = pitch * a.sample_rate / OUT_SR  # read the input slower -> lower pitch, longer
    pos = np.arange(0, len(x) - 1, step)
    return np.interp(pos, np.arange(len(x)), x).astype(np.float32)


def reverb(x: np.ndarray, rt: float, wet: float, seed: int = 1) -> np.ndarray:
    n = int(rt * OUT_SR)
    rng = np.random.default_rng(seed)
    ir = rng.standard_normal(n).astype(np.float32) * np.exp(-6.9 * np.arange(n) / n).astype(np.float32)
    ir[: int(0.012 * OUT_SR)] = 0  # short pre-delay
    m = len(x) + n
    y = np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m).astype(np.float32)
    y /= (np.max(np.abs(y)) or 1.0)
    out = np.zeros(m, np.float32)
    out[: len(x)] += x * (1 - wet)
    out += y * wet * (np.max(np.abs(x)) or 1.0)
    return out


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / OUT_SR)
    return np.fft.irfft(X / (1 + (f / cutoff) ** 4), len(x)).astype(np.float32)


def trim(x: np.ndarray, thr: float = 0.01) -> np.ndarray:
    idx = np.where(np.abs(x) > thr)[0]
    if len(idx) == 0:
        return x
    a = max(0, idx[0] - int(0.02 * OUT_SR))
    b = min(len(x), idx[-1] + int(0.08 * OUT_SR))
    return x[a:b]


def render_line(tts, ln: dict, speed: float) -> tuple[np.ndarray, float]:
    """Returns the processed line and how long the speech itself lasts (without echo tail)."""
    who = next(k for k in CAST if ln["who"].startswith(k))
    c = CAST[who]
    if "layers" in c:
        parts = [trim(synth(tts, ln["text"], sid, speed, p)) * g for sid, p, g in c["layers"]]
        n = max(len(p) for p in parts)
        x = np.zeros(n + int(0.03 * OUT_SR), np.float32)
        for i, p in enumerate(parts):
            off = int(0.015 * i * OUT_SR)
            x[off: off + len(p)] += p
    else:
        x = trim(synth(tts, ln["text"], c["sid"], speed, c.get("pitch", 1.0)))
    speech = len(x) / OUT_SR
    if "lowpass" in c:
        x = lowpass(x, c["lowpass"])
    if "reverb" in c:
        x = reverb(x, *c["reverb"])
    elif ln["clip"][0] in TUNNEL_CLIPS:
        x = reverb(x, 0.6, 0.14)
    elif "旁白" in ln["who"]:
        x = reverb(x, 0.9, 0.2)
    return x / (np.max(np.abs(x)) or 1.0), speech


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        sys.exit(2)
    model = os.environ.get("KOKORO_DIR")
    if not model or not Path(model, "model.onnx").exists():
        sys.exit("请把 KOKORO_DIR 设成 kokoro-multi-lang-v1_1 模型目录（下载地址见文件开头）")
    ep = argv[1].strip("/")
    d = json.loads((ROOT / ep / "storyboard.json").read_text(encoding="utf-8"))
    d["_ep"] = ep
    validate(d)
    layout(d)
    out_dir = ROOT / ep / "voice"
    out_dir.mkdir(exist_ok=True)
    tts = load_tts(model)
    nth: dict[str, int] = {}
    manifest = []
    for i, ln in enumerate(d["all_lines"], 1):
        k = nth.get(ln["clip"], 0)
        nth[ln["clip"]] = k + 1
        speed, gain = STYLE.get((ln["clip"], k), (1.0, 1.0))
        x, speech = render_line(tts, ln, speed)
        # keep the speech inside its subtitle window, with a little slack; echo tails may run on
        room = ln["len"] + 0.35
        tries = 0
        while speech > room and tries < 3 and speed < 1.4:
            speed = min(1.4, speed * speech / (ln["len"] + 0.15))
            x, speech = render_line(tts, ln, speed)
            tries += 1
        name = f"line{i:02d}.wav"
        pcm = (np.clip(x * 0.9, -1, 1) * 32767).astype(np.int16)
        with wave.open(str(out_dir / name), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(OUT_SR)
            wf.writeframes(pcm.tobytes())
        manifest.append({"file": name, "clip": ln["clip"], "who": ln["who"], "text": ln["text"],
                         "start": round(ln["start"], 3), "window": ln["len"], "speech": round(speech, 3),
                         "speed": round(speed, 3), "gain": gain})
        flag = "  超出字幕时长" if speech > room else ""
        print(f"{i:2d} {ln['clip']} {ln['who'][:6]:<6} 说话 {speech:4.2f}s / 字幕 {ln['len']:.1f}s  speed {speed:.2f}  {ln['text']}{flag}")
    (out_dir / "voices.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main(sys.argv)
