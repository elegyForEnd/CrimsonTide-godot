"""Generate the tiny 8-bit "voice" ticks used by the story typewriter.

Why generate instead of shipping a sampled voice: each line has to sound like
one short syllable per character (the old console-RPG trick), not a looped
recording. Three fixed variants keep the import deterministic; the game adds
a little pitch jitter on top so repeated characters do not turn into a metronome.

Run from the project root:

    python tools/make_type_sfx.py

Only the Python standard library is used so the files can always be rebuilt.
"""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 48000
DURATION = 0.075
PEAK = 0.45
VARIANTS = (520.0, 590.0, 660.0)  # lower than the first pass: easier to hear under music
OUT_DIR = Path("assets/audio")


def render(base_hz: float, seed: int) -> list[int]:
    """One short descending square/triangle blip with a fast decay."""
    frames = int(SAMPLE_RATE * DURATION)
    out: list[int] = []
    phase = 0.0
    # A tiny deterministic wobble gives each variant its own grain.
    wobble = 0.02 + (seed % 3) * 0.006
    for i in range(frames):
        t = i / SAMPLE_RATE
        progress = i / max(1, frames - 1)
        hz = base_hz * (1.06 - 0.18 * progress) * (1.0 + wobble * math.sin(t * 90.0 + seed))
        phase += hz / SAMPLE_RATE
        square = 1.0 if (phase % 1.0) < 0.32 else -1.0
        triangle = 4.0 * abs((phase % 1.0) - 0.5) - 1.0
        attack = min(1.0, t / 0.0015)
        decay = math.exp(-t * 38.0)
        tail = 1.0 - progress ** 2
        value = (square * 0.58 + triangle * 0.42) * attack * decay * tail
        out.append(int(max(-1.0, min(1.0, value * PEAK)) * 32767))
    return out


def write_wav(path: Path, samples: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(b"".join(struct.pack("<h", sample) for sample in samples))


def main() -> None:
    for index, hz in enumerate(VARIANTS):
        path = OUT_DIR / f"type-{index}.wav"
        write_wav(path, render(hz, index))
        print(f"wrote {path} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
