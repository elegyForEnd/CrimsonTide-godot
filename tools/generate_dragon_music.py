"""Create and master the frostbone dragon's offline Suno theme via APILIO_API_KEY."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

import numpy as np
import requests

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/boss-music-source"
OUT = ROOT / "assets/audio/music"
BASE = "https://api.apilio.ai/suno"
NAME = "dragon"
RATE = 44100
SPEC = {
    "title": "Crimson Tide - Frostbone Ancient Dragon",
    "tags": "Instrumental gothic dark fantasy dragon boss, ancient frost dragon, low brass, glacial glass bells, soaring strings, taiko drums, cold pipe organ, 138 bpm, A minor, intense cinematic combat, no vocals",
    "prompt": "[Instrumental] A vast ancient dragon wakes beneath the moon; icy bells and deep brass announce it, rapid strings follow sweeping breath, crashing drums mark wingbeats, solemn organ rises in the second phase, loopable return",
}


def api(command):
    key = os.environ.get("APILIO_API_KEY")
    if not key:
        raise SystemExit("Set APILIO_API_KEY in the process environment")
    SOURCE.mkdir(parents=True, exist_ok=True)
    headers = {"Authorization": f"Bearer {key}"}
    receipt = SOURCE / f"{NAME}-request.json"
    if command == "submit":
        if receipt.exists() and receipt.stat().st_size > 0:
            print(NAME, "already submitted")
            return
        payload = {**SPEC, "mv": "chirp-v4", "make_instrumental": True,
                   "negative_tags": "vocals, singing, speech, lyrics, pop, EDM"}
        response = requests.post(f"{BASE}/submit/music", headers=headers,
                                 json=payload, timeout=45)
        response.raise_for_status()
        result = response.json()
        if result.get("code") != "success":
            raise RuntimeError(result.get("message", "submission failed"))
        receipt.write_text(json.dumps({"request": payload, "response": result},
                                      ensure_ascii=False, indent=2), encoding="utf-8")
        print(NAME, result["data"])
    else:
        task_id = json.loads(receipt.read_text(encoding="utf-8-sig"))["response"]["data"]
        response = requests.get(f"{BASE}/fetch/{task_id}", headers=headers, timeout=45)
        response.raise_for_status()
        result = response.json()
        data = result.get("data", {})
        print(NAME, data.get("status"))
        if data.get("status") != "SUCCESS" or not data.get("data"):
            return
        (SOURCE / f"{NAME}-status.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
        target = SOURCE / f"{NAME}-0.mp3"
        if not target.exists():
            with requests.get(data["data"][0]["audio_url"], stream=True, timeout=120) as stream:
                stream.raise_for_status()
                with target.open("wb") as file:
                    for chunk in stream.iter_content(1024 * 1024):
                        file.write(chunk)


def master():
    def ffmpeg(*args, **kwargs):
        return subprocess.run(["ffmpeg", "-v", "error", *args], check=True, **kwargs)

    OUT.mkdir(parents=True, exist_ok=True)
    source = SOURCE / f"{NAME}-0.mp3"
    receipt = json.loads((SOURCE / f"{NAME}-request.json").read_text(encoding="utf-8-sig"))
    status = json.loads((SOURCE / f"{NAME}-status.json").read_text(encoding="utf-8-sig"))["data"]
    clip = status["data"][0]
    raw = ffmpeg("-i", str(source), "-f", "f32le", "-ar", str(RATE),
                 "-ac", "2", "pipe:1", capture_output=True).stdout
    audio = np.frombuffer(raw, dtype="<f4").reshape(-1, 2).copy()
    audio = audio[2 * RATE:-5 * RATE]
    cross = 3 * RATE
    assert len(audio) > 40 * RATE and np.isfinite(audio).all()
    blend = np.linspace(0, 1, cross, dtype=np.float32)[:, None]
    audio[-cross:] = audio[-cross:] * (1 - blend) + audio[:cross] * blend
    audio = audio[cross:]
    output = OUT / f"{NAME}.ogg"
    ffmpeg("-y", "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-i", "pipe:0",
           "-af", "loudnorm=I=-20:TP=-2:LRA=9", "-ar", str(RATE),
           "-c:a", "libvorbis", "-q:a", "6", str(output), input=audio.tobytes())
    manifest_path = OUT / "music-manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["tracks"][NAME] = {
        "title": "霜骨古龙 · Frostbone Ancient Dragon", "file": output.name,
        "task_id": status["task_id"], "clip_id": clip["id"],
        "requested_model": "chirp-v4", "returned_model": clip.get("model_name"),
        "request": receipt["request"], "source_file": source.name,
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "duration_seconds": len(audio) / RATE,
        "editing": {"trim_start_seconds": 2, "trim_end_seconds": 5,
                    "loop_crossfade_seconds": 3, "target_lufs": -20,
                    "true_peak_ceiling_db": -2},
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    print(NAME, round(len(audio) / RATE, 2), "seconds")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "submit"
    if command in ["submit", "collect"]:
        api(command)
    elif command == "master":
        master()
    else:
        raise SystemExit("usage: generate_dragon_music.py [submit|collect|master]")
