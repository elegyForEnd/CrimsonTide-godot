"""Master downloaded Suno BGM into offline, crossfaded Ogg loops.

Requires numpy and ffmpeg on PATH. No API key or network access is needed.
Raw API receipts and MP3s: build/music-source/{camp,ruins}-{request,status}.json,
{camp,ruins}-0.mp3. Run from any directory: python tools/prepare_music.py
"""
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/music-source"
OUT = ROOT / "assets/audio/music"
RATE = 44100


def ffmpeg(*args, **kwargs):
    return subprocess.run(["ffmpeg", "-v", "error", *args], check=True, **kwargs)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"provider": "https://api.apilio.ai", "generator": "Suno",
                "note": "Generated instrumental music; not part of the CC0 SFX bank. Provider/account terms apply. Offline playback; no credentials included.",
                "tracks": {}}
    for name, title in [("camp", "营地守望 · Lanterns of the Watch"),
                        ("ruins", "血潮废墟 · Beneath the Blood Mist")]:
        source = SOURCE / f"{name}-0.mp3"
        raw = ffmpeg("-i", str(source), "-f", "f32le", "-ar", str(RATE),
                     "-ac", "2", "pipe:1", capture_output=True).stdout
        audio = np.frombuffer(raw, dtype="<f4").reshape(-1, 2).copy()
        # Remove opening/ending padding and blend the tail into the opening.
        # The wrapped sample follows the head consumed by the crossfade.
        audio = audio[3 * RATE:-8 * RATE]
        cross = 4 * RATE
        assert len(audio) > 40 * RATE and np.isfinite(audio).all()
        blend = np.linspace(0, 1, cross, dtype=np.float32)[:, None]
        audio[-cross:] = audio[-cross:] * (1 - blend) + audio[:cross] * blend
        audio = audio[cross:]
        output = OUT / f"{name}.ogg"
        ffmpeg("-y", "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-i", "pipe:0",
               "-af", "loudnorm=I=-20:TP=-2:LRA=9", "-ar", str(RATE),
               "-c:a", "libvorbis", "-q:a", "6", str(output), input=audio.tobytes())
        request = json.loads((SOURCE / f"{name}-request.json").read_text())
        status = json.loads((SOURCE / f"{name}-status.json").read_text())["data"]
        clip = status["data"][0]
        manifest["tracks"][name] = {
            "title": title, "file": output.name, "task_id": request["response"]["data"],
            "clip_id": clip["id"], "requested_model": request["request"]["mv"],
            "returned_model": clip.get("model_name"), "request": request["request"],
            "source_file": source.name, "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
            "duration_seconds": len(audio) / RATE,
            "editing": {"trim_start_seconds": 3, "trim_end_seconds": 8, "loop_crossfade_seconds": 4,
                        "target_lufs": -20, "true_peak_ceiling_db": -2}}
        print(name, round(len(audio) / RATE, 2), "seconds", output.stat().st_size, "bytes")
    (OUT / "music-manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()
