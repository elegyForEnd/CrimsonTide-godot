"""Master only the three post-cinematic releases from the cached CC0 library.

Run with numpy/scipy and ffmpeg on PATH. Original downloads and preview stay
in build/; output provenance is merged into the existing library manifest.
"""
import hashlib
import json
import shutil
from pathlib import Path

import numpy as np
from scipy.io import wavfile

import prepare_library_audio as b


def build():
    layer = b.layer
    # Match the five blood blades (55 ms spacing), holy pillar (100 ms),
    # and three raven slashes (90 ms), with an immediate impact underneath.
    recipes = [
        (1.45, [
            layer(b.spell("Fire", 2), gain=.95, duration=1.35, speed=.95),
            layer(b.druid("Earth", 1), gain=.5, duration=.45, low=1400),
            *[layer(b.sword(6), gain=.5-i*.065, speed=1.15+i*.10,
                    duration=.38, high=1300, delay=i*.055) for i in range(5)],
            layer(b.druid("Wind", 4), gain=.45, duration=.8, high=450),
        ]),
        (1.85, [
            layer(b.heal(11), gain=1.0, duration=1.75, speed=.9),
            layer(b.spell("Ice", 2), gain=.65, duration=1.25, high=650, delay=.10),
            layer(b.druid("Earth", 1), gain=.28, duration=.3, low=950),
            layer(b.heal(7), gain=.38, duration=.85, speed=1.45, high=2200, delay=.20),
        ]),
        (1.6, [
            layer(b.spell("Lightning", 1), gain=1.0, duration=1.45, speed=.85),
            layer(b.druid("Earth", 4), gain=.8, duration=1.0, speed=.8, low=2100),
            *[layer(b.druid("Wind", 4), gain=.45-i*.06, duration=.45,
                    speed=1.2+i*.1, high=1100, delay=i*.09) for i in range(3)],
        ]),
    ]
    folder = b.ROOT / "assets/audio"
    manifest_path = folder / "library-manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    preview = []
    for hero, (length, layers) in enumerate(recipes):
        name = f"skill-{hero}"
        b.cue(name, layers, length, tail=.38, room=.8, rms=.25, width=1.1)
        source = b.OUT / (name + ".wav")
        shutil.copy2(source, folder / source.name)
        spec = b.CUES[name]
        spec["sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
        manifest["cues"][name] = spec
        for ingredient in layers:
            path = ingredient["path"]
            info = b.USED[path]
            manifest["source_files"][path] = info
            author, url = b.SOURCES[info["source"]]
            manifest["sources"][info["source"]] = {"author": author, "url": url}
        _, pcm = wavfile.read(source)
        # Approximate the cue gain, not a claim of recording the Godot mix.
        preview.extend([pcm.astype(float)*10**(-5/20), np.zeros((48000, 2))])
    manifest["ultimate_release_revision"] = "post-cinematic-2026-09-22"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    wavfile.write(b.ROOT / "build/Ultimate-Release-Preview.wav", b.RATE,
                  np.concatenate(preview).astype(np.int16))
    print("ULTIMATE RELEASE: 3 CC0 cues; preview order: Feiyue, Xueli, Yayu")


if __name__ == "__main__":
    build()
