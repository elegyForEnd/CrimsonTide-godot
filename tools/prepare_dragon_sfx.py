"""Create dragon-specific effects from the project's credited CC0 boss recordings."""
from pathlib import Path
import json

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/bosses"
RATE = 48000
SUFFIXES = ["charge", "quick", "sweep", "burst", "lance", "ritual", "fall"]


def read(path, speed):
    rate, samples = wavfile.read(path)
    assert rate == RATE
    audio = samples.astype(np.float32) / 32768.0
    if audio.ndim == 1:
        audio = np.column_stack((audio, audio))
    return resample_poly(audio, 100, round(speed * 100), axis=0)


def main():
    provenance = {}
    for suffix in SUFFIXES:
        source_a = OUT / f"bell-{suffix}.wav"
        source_b = OUT / f"queen-{suffix}.wav"
        a = read(source_a, 1.31)
        b = read(source_b, 0.89)
        mix = np.zeros((max(len(a), len(b)), 2), dtype=np.float32)
        mix[:len(a)] += a * 0.71
        mix[:len(b)] += b * 0.49
        fade = min(round(RATE * 0.17), len(mix) // 3)
        mix[:round(RATE * 0.004)] *= np.linspace(0, 1, round(RATE * 0.004))[:, None]
        mix[-fade:] *= np.linspace(1, 0, fade)[:, None]
        peak = np.max(np.abs(mix))
        assert peak > 1e-5
        mix *= 0.79 / peak
        output = OUT / f"dragon-{suffix}.wav"
        wavfile.write(output, RATE, np.round(mix * 32767).astype(np.int16))
        provenance[suffix] = {"sources": [source_a.name, source_b.name],
                              "speed": [1.31, 0.89], "peak": 0.79}
    (OUT / "dragon-sfx-manifest.json").write_text(
        json.dumps({"origin": "Edits of the credited CC0 recordings in manifest.json",
                    "rate": RATE, "cues": provenance}, indent=2), encoding="utf-8")
    print("Prepared", len(SUFFIXES), "dragon cues")


if __name__ == "__main__":
    main()
