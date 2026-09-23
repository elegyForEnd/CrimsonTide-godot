"""Layer existing credited CC0 boss effects into cues for new encounters."""
from pathlib import Path
import json

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/bosses"
RATE = 48000
SUFFIXES = ["charge", "quick", "sweep", "burst", "lance", "ritual", "fall"]
SOURCES = {
    "mirror": ("knight", "bell", 1.16, 0.91),
    "ember": ("thorn", "queen", 0.93, 1.08),
    "moon": ("queen", "bell", 0.88, 0.83),
}


def clip(path, speed):
    rate, samples = wavfile.read(path)
    assert rate == RATE
    audio = samples.astype(np.float32) / 32768.0
    if audio.ndim == 1:
        audio = np.column_stack((audio, audio))
    return resample_poly(audio, 100, round(speed * 100), axis=0)


def main():
    provenance = {}
    for name, (primary, secondary, speed_a, speed_b) in SOURCES.items():
        provenance[name] = {}
        for suffix in SUFFIXES:
            source_a = OUT / f"{primary}-{suffix}.wav"
            source_b = OUT / f"{secondary}-{suffix}.wav"
            a = clip(source_a, speed_a)
            b = clip(source_b, speed_b)
            length = max(len(a), len(b))
            mix = np.zeros((length, 2), dtype=np.float32)
            mix[:len(a)] += a * 0.78
            mix[:len(b)] += b * 0.38
            fade = min(round(RATE * 0.16), length // 3)
            mix[:round(RATE * 0.004)] *= np.linspace(0, 1, round(RATE * 0.004))[:, None]
            mix[-fade:] *= np.linspace(1, 0, fade)[:, None]
            peak = np.max(np.abs(mix))
            assert peak > 1e-5
            mix *= 0.82 / peak
            output = OUT / f"{name}-{suffix}.wav"
            wavfile.write(output, RATE, np.round(mix * 32767).astype(np.int16))
            provenance[name][suffix] = {"sources": [source_a.name, source_b.name],
                                         "speed": [speed_a, speed_b], "peak": 0.82}
    (OUT / "new-boss-sfx-manifest.json").write_text(
        json.dumps({"origin": "Edits of the credited CC0 recordings in manifest.json",
                    "rate": RATE, "cues": provenance}, indent=2), encoding="utf-8")
    print("Prepared", len(SOURCES) * len(SUFFIXES), "new boss cues")


if __name__ == "__main__":
    main()
