"""Edit downloaded Suno material into game cues. No oscillators or noise synthesis.

Requires numpy, scipy and ffmpeg on PATH. Sources live in build/audio-source.
Run from the project root: python tools/prepare_suno_audio.py
"""
import hashlib
import json
import pathlib
import subprocess

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, resample_poly, sosfilt

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/audio-source"
OUT = ROOT / "assets/audio"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 44100
cache = {}
edits = {}


def source(name):
    if name not in cache:
        path = SOURCE / (name + ".wav")
        rate, data = wavfile.read(path)
        assert rate == RATE
        cache[name] = data.astype(np.float64) / 32768
    return cache[name]


def cut(name, at, duration, high=70, low=14000, speed=1.0, reverse=False):
    audio = source(name)
    clip = audio[int(at * RATE):int((at + duration * speed) * RATE)].copy()
    if speed != 1.0:
        clip = resample_poly(clip, 100, round(speed * 100), axis=0)
    clip = clip[:round(duration * RATE)]
    if reverse:
        clip = clip[::-1].copy()
    clip = sosfilt(butter(2, [high, low], btype="bandpass", fs=RATE, output="sos"), clip, axis=0)
    return clip


def save(name, layers, length, decay=1.0, peak=0.82, fade_out=0.07):
    result = np.zeros((round(length * RATE), 2))
    for spec in layers:
        spec = dict(spec)
        gain = spec.pop("gain", 1.0)
        delay = spec.pop("delay", 0.0)
        audio = cut(**spec) * gain
        start = round(delay * RATE)
        count = min(len(audio), len(result) - start)
        if count > 0:
            result[start:start + count] += audio[:count]
    # Sample edits retain the generated timbre, but end before the next musical event.
    result *= np.exp(-decay * np.linspace(0, 1, len(result)))[:, None]
    fade_in = min(round(0.003 * RATE), len(result))
    result[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    tail = min(round(fade_out * RATE), len(result))
    result[-tail:] *= np.linspace(1, 0, tail)[:, None] ** 2
    maximum = np.max(np.abs(result))
    assert maximum > 1e-5, name
    result *= peak / maximum
    wavfile.write(OUT / (name + ".wav"), RATE, np.round(result * 32767).astype(np.int16))
    edits[name] = {"layers": layers, "length": length, "decay": decay, "peak": peak, "fade_out": fade_out}


def layer(name, at, duration, **kwargs):
    return dict(name=name, at=at, duration=duration, **kwargs)


for i, at in enumerate([2.30, 12.40, 26.62]):
    save(f"slash-{i}", [layer("steel-0", at, .30, high=850, speed=1.12 + i * .04)], .30, 2.8)
for i, at in enumerate([8.28, 22.02, 35.60]):
    save(f"heavy-{i}", [layer("impact-0", at, .58, high=40, low=6000, speed=.80),
                         layer("steel-0", 15.85 + i * .9, .32, high=1400, gain=.65)], .58, 3.1)
for i, at in enumerate([8.83, 28.31, 37.0]):
    save(f"magic-{i}", [layer("arcane-0", at, .62, high=480, speed=1.10)], .62, 2.3)
for i, at in enumerate([9.72, 26.49, 40.08]):
    save(f"hit-{i}", [layer("impact-0", at, .22, high=80, low=6500)], .22, 3.8, .74)
for i, at in enumerate([42.35, 46.56]):
    save(f"impact-heavy-{i}", [layer("impact-1", at, .46, high=35, low=5000, speed=.78)], .46, 3.6)
for i, at in enumerate([3.24, 4.41]):
    save(f"dash-{i}", [layer("steel-0", at, .27, high=1800, low=11000, reverse=True)], .27, .8, .65)
for i, at in enumerate([47.64, 48.40]):
    save(f"shot-{i}", [layer("impact-0", at, .21, high=90, low=9000, speed=1.35)], .21, 4.0)
save("hurt-0", [layer("impact-1", 29.12, .25, high=100, low=2200, speed=.90)], .25, 3.6, .7)
save("loot-0", [layer("arcane-1", 9.44, .48, high=1800, speed=1.3)], .48, 3.2, .55)
save("bell-0", [layer("ritual-0", 6.30, 2.4, high=100, low=10000)], 2.4, 3.4, .75, .4)
save("skill-0", [layer("arcane-1", 39.22, 1.15, high=180),
                 layer("ritual-1", 10.0, .7, high=40, low=1800, gain=.45)], 1.15, 3.0)
for hero, (bank, at, low) in enumerate([("steel-0", 32.2, 9000), ("arcane-1", 20.80, 15000), ("impact-1", 35.04, 6500)]):
    save(f"ultimate-charge-{hero}", [layer("ritual-0", 6.32, 1.85, high=90, reverse=True, gain=.55),
                                      layer(bank, at, 1.85, high=250, low=low, reverse=True)], 1.85, -.8, .70, .08)
    save(f"ultimate-burst-{hero}", [layer(bank, at, .70, high=60, low=low, gain=.9),
                                     layer("ritual-1", 10.0, .70, high=35, low=2500, gain=.70)], .70, 3.1, .88, .18)
    save(f"ultimate-charge-short-{hero}", [layer(bank, at, .60, high=250, low=low, reverse=True)], .60, -.8, .70)
    save(f"ultimate-burst-short-{hero}", [layer(bank, at, .21, high=60, low=low),
                                           layer("ritual-1", 10.0, .21, high=35, low=2500, gain=.7)], .21, 2.5, .88)

# Crossfade the atmospheric source into itself at the loop seam.
ambient = cut("ritual-0", 12.0, 24.0, high=60, low=3800)
cross = RATE * 2
blend = np.linspace(0, 1, cross)[:, None]
ambient[-cross:] = ambient[-cross:] * (1 - blend) + ambient[:cross] * blend
ambient = ambient[cross:]
ambient *= .48 / max(np.max(np.abs(ambient)), 1e-5)
wavfile.write(SOURCE / "ambient-edited.wav", RATE, np.round(ambient * 32767).astype(np.int16))
subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(SOURCE / "ambient-edited.wav"),
                "-c:a", "libvorbis", "-q:a", "5", str(OUT / "ambient.ogg")], check=True)
edits["ambient"] = {"source": "ritual-0", "start": 12.0, "source_length": 24.0, "loop_crossfade": 2.0, "length": 22.0}

provenance = {"provider": "https://api.apilio.ai", "generator": "Suno", "requested_model": "chirp-v4",
              "note": "Sample-based edits of generated audio; not live synthesis or field recordings. Raw source files are in build/audio-source; playback is fully offline.",
              "sources": {}, "edits": edits}
for bank, task_name in [("steel", "pilot"), ("arcane", "arcane"), ("impact", "impact"), ("ritual", "ritual")]:
    request = json.loads((ROOT / f"build/suno-{task_name}.json").read_text(encoding="utf-8"))
    status = json.loads((ROOT / f"build/suno-{task_name}-status.json").read_text(encoding="utf-8"))["data"]
    clips = []
    for index, item in enumerate(status["data"]):
        path = SOURCE / f"{bank}-{index}.mp3"
        if path.exists():
            clips.append({"file": path.name, "clip_id": item["id"], "returned_model": item.get("model_name"),
                          "duration": item.get("duration"), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    provenance["sources"][bank] = {"task_id": status["task_id"], "request": request["request"], "clips": clips}
(OUT / "suno-manifest.json").write_text(json.dumps(provenance, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"Prepared {len(edits)} offline Suno cues in {OUT}")
