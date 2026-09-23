"""Master new Suno tracks while leaving the existing three boss files intact."""
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/boss-music-source"
OUT = ROOT / "assets/audio/music"
RATE = 44100
TITLES = {
    "earth": "裂地钻兽 · Faultline Maw",
    "storm": "雷骸巨鸟 · Carrion Tempest",
    "abyss": "吞月渊蛇 · Moon-Eater Leviathan",
}


def run(*args, **kwargs):
    return subprocess.run(["ffmpeg", "-v", "error", *args], check=True, **kwargs)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / "music-manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for name, title in TITLES.items():
        source = SOURCE / f"{name}-0.mp3"
        receipt = json.loads((SOURCE / f"{name}-request.json").read_text(encoding="utf-8-sig"))
        status = json.loads((SOURCE / f"{name}-status.json").read_text(encoding="utf-8-sig"))["data"]
        clip = status["data"][0]
        raw = run("-i", str(source), "-f", "f32le", "-ar", str(RATE),
                  "-ac", "2", "pipe:1", capture_output=True).stdout
        audio = np.frombuffer(raw, dtype="<f4").reshape(-1, 2).copy()
        audio = audio[2 * RATE:-5 * RATE]
        cross = 3 * RATE
        assert len(audio) > 40 * RATE and np.isfinite(audio).all()
        blend = np.linspace(0, 1, cross, dtype=np.float32)[:, None]
        audio[-cross:] = audio[-cross:] * (1 - blend) + audio[:cross] * blend
        audio = audio[cross:]
        output = OUT / f"{name}.ogg"
        run("-y", "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-i", "pipe:0",
            "-af", "loudnorm=I=-20:TP=-2:LRA=9", "-ar", str(RATE),
            "-c:a", "libvorbis", "-q:a", "6", str(output), input=audio.tobytes())
        manifest["tracks"][name] = {
            "title": title, "file": output.name, "task_id": status["task_id"],
            "clip_id": clip["id"], "requested_model": "chirp-v4",
            "returned_model": clip.get("model_name"), "request": receipt["request"],
            "source_file": source.name,
            "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
            "duration_seconds": len(audio) / RATE,
            "editing": {"trim_start_seconds": 2, "trim_end_seconds": 5,
                        "loop_crossfade_seconds": 3, "target_lufs": -20,
                        "true_peak_ceiling_db": -2},
        }
        print(name, round(len(audio) / RATE, 2), "seconds")
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()
