"""Submit and collect three instrumental Suno themes using APILIO_API_KEY."""
import json
import os
from pathlib import Path
import sys

import requests

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/boss-music-source"
BASE = "https://api.apilio.ai/suno"
THEMES = {
    "earth": {
        "title": "Crimson Tide - Faultline Maw",
        "tags": "Instrumental dark fantasy giant burrowing centipede miniboss, seismic low drums, contrabass, metallic scraping, irregular 7/8 pulse, earthy dread, intense action, no vocals",
        "prompt": "[Instrumental] Deep subterranean rumble, jagged strings trace the moving tunnel, sudden percussion eruptions, a heavy chitin rhythm, loopable motif",
    },
    "storm": {
        "title": "Crimson Tide - Carrion Tempest",
        "tags": "Instrumental dark fantasy thunder roc miniboss, fierce airborne orchestral action, rapid snare rolls, shrill strings, brass swoops, electric crackle, 148 bpm, no vocals",
        "prompt": "[Instrumental] Wide soaring motif interrupted by plunge attacks, asymmetrical thunder drums and sharp brass, open air before a storm-front climax, loopable return",
    },
    "abyss": {
        "title": "Crimson Tide - Moon-Eater Leviathan",
        "tags": "Instrumental cosmic dark fantasy secret final boss, abyssal leviathan, oceanic low brass, pipe organ, massive timpani, eerie choir-like synth without voices, 136 bpm, apocalyptic, no vocals",
        "prompt": "[Instrumental] Ancient deep-sea pulse rises into a moon-eating cataclysm, swirling strings, abyssal organ and tidal percussion, three escalating waves, seamless return",
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
            raise SystemExit("usage: generate_wild_boss_music.py [submit|collect]")


if __name__ == "__main__":
    main()
