"""Regenerate the three Suno themes via APILIO_API_KEY, then collect MP3s.

Set the key only in the process environment. No credential is stored in files.
Run `python tools/generate_boss_music.py submit` once, then `collect` later.
Finally run `python tools/prepare_boss_music.py` to make game loops.
"""
import json
import os
from pathlib import Path
import sys

import requests

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/boss-music-source"
BASE = "https://api.apilio.ai/suno"
THEMES = {
    "mirror": {
        "title": "Crimson Tide - Shards of the Mirror Tomb",
        "tags": "Instrumental gothic anime RPG miniboss, glass harmonica, staccato strings, celesta shards, low cello, cathedral organ, 132 bpm, D minor, haunting reflections, intense combat, no vocals",
        "prompt": "[Instrumental] Crystalline glass motif, quick strings fracture into mirrored answers, organ and taiko drive the fight, loopable return to motif",
    },
    "ember": {
        "title": "Crimson Tide - Ashen Vespers",
        "tags": "Instrumental gothic anime RPG miniboss, ritual drums, bowed cello, brass stabs, pipe organ, 126 bpm, F minor, blazing urgency, no vocals",
        "prompt": "[Instrumental] Smoldering cello ostinato, explosive drums and brass, brief hush then rising strings and organ, loopable return to ostinato",
    },
    "final": {
        "title": "Crimson Tide - The Nameless Blood Moon",
        "tags": "Instrumental final boss soundtrack, gothic anime action RPG, grand orchestra, pipe organ, urgent strings, massive taiko, bells, tragic triumphant melody, D minor, 150 bpm, no vocals",
        "prompt": "[Instrumental] Ominous organ and distant bell motif, urgent string ostinato, cataclysmic final boss melody, suspended eclipse then defiant reprise, loopable close",
    },
}


def main():
    key = os.environ.get("APILIO_API_KEY")
    if not key:
        raise SystemExit("Set APILIO_API_KEY in the process environment")
    OUT.mkdir(parents=True, exist_ok=True)
    headers = {"Authorization": f"Bearer {key}"}
    command = sys.argv[1] if len(sys.argv) > 1 else "submit"
    for name, spec in THEMES.items():
        receipt = OUT / f"{name}-request.json"
        if command == "submit":
            if receipt.exists() and receipt.stat().st_size > 0:
                print(name, "already submitted")
                continue
            payload = {**spec, "mv": "chirp-v4", "make_instrumental": True,
                       "negative_tags": "vocals, singing, speech, lyrics, pop, EDM"}
            response = requests.post(f"{BASE}/submit/music", headers=headers,
                                     json=payload, timeout=45)
            response.raise_for_status()
            result = response.json()
            if result.get("code") != "success":
                raise RuntimeError(f"{name}: {result.get('message', 'submission failed')}")
            receipt.write_text(json.dumps({"request": payload, "response": result},
                                          ensure_ascii=False, indent=2), encoding="utf-8")
            print(name, result["data"])
        elif command == "collect":
            task_id = json.loads(receipt.read_text(encoding="utf-8-sig"))["response"]["data"]
            response = requests.get(f"{BASE}/fetch/{task_id}", headers=headers, timeout=45)
            response.raise_for_status()
            result = response.json()
            data = result.get("data", {})
            print(name, data.get("status"))
            if data.get("status") != "SUCCESS" or not data.get("data"):
                continue
            (OUT / f"{name}-status.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
            target = OUT / f"{name}-0.mp3"
            if not target.exists():
                with requests.get(data["data"][0]["audio_url"], stream=True, timeout=120) as stream:
                    stream.raise_for_status()
                    with target.open("wb") as file:
                        for chunk in stream.iter_content(1024 * 1024):
                            file.write(chunk)
        else:
            raise SystemExit("usage: generate_boss_music.py [submit|collect]")


if __name__ == "__main__":
    main()
