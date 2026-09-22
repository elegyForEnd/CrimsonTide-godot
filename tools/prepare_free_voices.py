"""Import licensed, prerecorded Spaland voices. No synthesis or voice conversion.

Requires requests, numpy, scipy and ffmpeg. Source recordings and old banks stay
in ignored build/free-voices. Only game-ready cues and provenance enter assets.
Run this before prepare_anime_audio.py to synchronize cinematic effect timing.
"""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

import numpy as np
import requests
from scipy.io import wavfile
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "build/free-voices"
OUT = ROOT / "assets/audio/voices"
RATE = 48000


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    spec = json.loads((ROOT / "tools/free_voice_cast.json").read_text(encoding="utf-8"))
    CACHE.mkdir(parents=True, exist_ok=True)
    stage = CACHE / "prepared"
    stage.mkdir(exist_ok=True)
    manifest = {"provider": "Spaland", "engine": "prerecorded-human-voice",
                "language": "ja", "license": "Spaland custom free-use terms",
                "terms": [spec["terms"]], "terms_checked": spec["terms_checked"],
                "note": "Human recordings by すぱるな瀟洒; not CC0. Game embedding allowed; standalone redistribution and AI training prohibited.",
                "heroes": []}
    expected = set()
    for index, cast in enumerate(spec["heroes"]):
        hero = {"name": cast["name"], "voice_id": cast["voice_id"],
                "credit": spec["credit"], "character_type": cast["character_type"], "lines": {}}
        prepared = {}
        for kind, source_ids in cast["lines"].items():
            hero["lines"][kind] = []
            for source_id in source_ids:
                source = spec["sources"][source_id]
                raw_path = CACHE / source_id
                if not raw_path.exists():
                    response = requests.get(source["url"], timeout=30)
                    response.raise_for_status()
                    raw_path.write_bytes(response.content)
                if digest(raw_path) != source["sha256"]:
                    raise ValueError(f"Source changed; review before importing: {source_id}")
                if source_id not in prepared:
                    decoded = subprocess.run(["ffmpeg", "-v", "error", "-i", str(raw_path),
                        "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-"],
                        capture_output=True, check=True).stdout
                    x = np.frombuffer(decoded, dtype=np.float32).astype(np.float64)
                    # Trim silence only. Preserve the actor's pitch, speed and breaths.
                    active = np.flatnonzero(abs(x) > max(.003, np.max(abs(x)) * .012))
                    if len(active) < 100:
                        raise ValueError(f"Empty recording: {source_id}")
                    start = max(0, int(active[0]) - 720)
                    end = min(len(x), int(active[-1]) + 2400)
                    x = x[start:end].copy()
                    gain = min(4.0, .16 / max(np.sqrt(np.mean(x*x)), 1e-6))
                    x *= gain
                    limit = min(1.0, .80 / max(np.max(abs(resample_poly(x, 4, 1))), 1e-6))
                    x *= limit
                    fade = min(240, len(x)//2)
                    x[:fade] *= np.linspace(0, 1, fade)
                    x[-fade:] *= np.linspace(1, 0, fade)
                    filename = f"hero-{index}-{Path(source_id).stem}.wav"
                    path = stage / filename
                    wavfile.write(path, RATE, np.round(x * 32767).astype(np.int16))
                    prepared[source_id] = {"file": filename, "ja": source["ja"], "zh": source["zh"],
                        "length": round(len(x)/RATE, 6), "sha256": digest(path),
                        "source_url": source["url"], "source_page": source["page"],
                        "source_sha256": source["sha256"], "voice_id": cast["voice_id"],
                        "mastering": {"trim_start_seconds": start/RATE, "trim_end_seconds": end/RATE,
                                      "gain": gain*limit, "pitch_shift": 0, "speed": 1.0,
                                      "target_rms": .16, "true_peak_limit": .80}}
                    expected.add(filename)
                    print(cast["name"], source["ja"], round(len(x)/RATE, 3), flush=True)
                hero["lines"][kind].append(prepared[source_id].copy())
        hero["charge_time"] = round(hero["lines"]["ultimate-charge"][0]["length"] + .12, 3)
        hero["burst_time"] = round(hero["lines"]["ultimate-burst"][0]["length"] + .22, 3)
        manifest["heroes"].append(hero)

    # Back up the active bank once per manifest before replacing any resources.
    old_manifest = OUT / "voice-manifest.json"
    if old_manifest.exists():
        backup = CACHE / ("backup-" + digest(old_manifest)[:12])
        if not backup.exists():
            shutil.copytree(OUT, backup)
    OUT.mkdir(exist_ok=True)
    for filename in sorted(expected):
        shutil.copy2(stage / filename, OUT / filename)
    (OUT / "voice-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    # Remove only obsolete voice WAVs/import descriptors inside this fixed bank.
    for path in OUT.glob("hero-*.wav"):
        if path.name not in expected:
            path.unlink()
            path.with_suffix(".wav.import").unlink(missing_ok=True)
    dialogue = [{"name": h["name"], "lines": {k: [{"ja": line["ja"], "zh": line["zh"]}
                 for line in lines] for k, lines in h["lines"].items()}} for h in manifest["heroes"]]
    (ROOT / "tools/voice_dialogue.json").write_text(json.dumps(dialogue, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    credits = ["CRIMSON TIDE — PRERECORDED JAPANESE CHARACTER VOICES", "", spec["credit"],
               "https://soalunashosya.jimdofree.com/", ""]
    credits += [h["name"] + ": " + h["character_type"] for h in manifest["heroes"]]
    credits += ["", "Human recordings, not AI synthesis. Free use under the author's custom terms; NOT CC0.",
                "Commercial game embedding and audio editing permitted. Attribution/reporting optional.",
                "Do not redistribute individual voice assets, misrepresent authorship, or use for AI training.",
                "Terms checked: " + spec["terms_checked"], spec["terms"], "",
                "Game processing: silence trim, mono/48 kHz conversion, gain and edge fades only.",
                "Actor pitch and speaking speed are unchanged. Some cues share the same recording.",
                "The manifest transcribes recordings; cinematic text uses the original fictional invocations.",
                "Per-file source URLs and hashes: assets/audio/voices/voice-manifest.json."]
    for path in [ROOT / "VOICE-CREDITS.txt", OUT / "CREDITS.txt"]:
        path.write_text("\n".join(credits)+"\n", encoding="utf-8")
    print(f"Imported {len(expected)} distinct human recordings; {sum(len(v) for h in manifest['heroes'] for v in h['lines'].values())} cue assignments.")


if __name__ == "__main__":
    main()
