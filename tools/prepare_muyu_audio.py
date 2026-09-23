"""Gives the hidden recruit 墓煜 an empty voice bank to fill in later.

Nothing is recorded for the recruit, and her lines are deliberately NOT borrowed
from the three shipped performances. What this writes is the wiring: one silent
placeholder per cue, carrying the filename a real recording should replace, plus
the manifest entry the game reads. Drop a recording in under the same name and it
plays; nothing in the code has to change.

Silence is not "no voice" though, so the manifest carries "voice_ready": false
and HeroVoice refuses to speak for a hero who is not ready. That keeps the whole
voice path switched off until the recordings exist, instead of playing a silent
clip that still ducks the music and still counts as speaking.

  assets/audio/voices/hero-3-muyu-<cue>-0.wav   silent placeholders
  assets/audio/voices/voice-manifest.json       a fourth heroes[] entry
  assets/audio/bosses/hidden-*.wav              the hidden encounter's own cues

Run:  python tools/prepare_muyu_audio.py
"""

from __future__ import annotations

import audioop
import json
import os
import shutil
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOICES = os.path.join(ROOT, "assets", "audio", "voices")
AUDIO = os.path.join(ROOT, "assets", "audio")
BOSSES = os.path.join(AUDIO, "bosses")
MANIFEST = os.path.join(VOICES, "voice-manifest.json")

VOICE_ID = "muyu"
HERO_NAME = "墓煜"
RATE = 44100
KINDS = ["attack", "heavy", "magic", "dash", "hurt", "heal", "down",
         "ultimate-charge", "ultimate-burst", "ultimate-short", "select"]
# How long a placeholder is, so anything that measures a line has a number
# before the real take exists.
PLACEHOLDER_SECONDS = 0.35

# Boss cues for the hidden encounter. These are pitch shifted takes of the
# queen's cues, not borrowed character performances, and the encounter ships
# with them; delete the files to fall back to the queen's own cue.
BOSS_CUES = ["charge", "quick", "sweep", "burst", "lance", "ritual", "fall"]
BOSS_SOURCE = "queen"
BOSS_PITCH = 0.82
BOSS_SPEED = 0.92


def silence(path: str, seconds: float = PLACEHOLDER_SECONDS) -> None:
    """Writes an empty mono wav of the given length."""
    frames = int(RATE * seconds)
    with wave.open(path, "wb") as dst:
        dst.setnchannels(1)
        dst.setsampwidth(2)
        dst.setframerate(RATE)
        dst.writeframes(b"\x00\x00" * frames)


def shift(source: str, target: str, pitch: float, speed: float) -> None:
    """Resamples a PCM wav, keeping its channel count and rate."""
    with wave.open(source, "rb") as src:
        params = src.getparams()
        frames = src.readframes(src.getnframes())
    if params.sampwidth != 2:
        shutil.copyfile(source, target)
        return
    stretched = audioop.ratecv(frames, 2, params.nchannels,
                               int(params.framerate * pitch), params.framerate, None)[0]
    sped = audioop.ratecv(stretched, 2, params.nchannels,
                          int(params.framerate * speed), params.framerate, None)[0]
    with wave.open(target, "wb") as dst:
        dst.setnchannels(params.nchannels)
        dst.setsampwidth(params.sampwidth)
        dst.setframerate(params.framerate)
        dst.writeframes(sped)


def remove_borrowed_takes() -> int:
    """Deletes shifted takes of the shipped performances, if any are present.

    An earlier pass built the recruit's bank that way. A placeholder is short and
    a real take is long, so anything longer than the placeholder under her naming
    is one of the borrowed files."""
    removed = 0
    for name in os.listdir(VOICES):
        stem = os.path.splitext(name)[0]
        if not stem.startswith("hero-3-%s-" % VOICE_ID):
            continue
        path = os.path.join(VOICES, name)
        try:
            with wave.open(path, "rb") as probe:
                seconds = probe.getnframes() / float(max(1, probe.getframerate()))
        except wave.Error:
            continue
        if seconds > PLACEHOLDER_SECONDS * 1.5:
            os.remove(path)
            removed += 1
    return removed


def reset_jingles() -> int:
    """Deletes the recruit's shifted cut-in jingles, so the first hero's play."""
    removed = 0
    for name in ["ultimate-charge", "ultimate-burst",
                 "ultimate-charge-short", "ultimate-burst-short"]:
        path = os.path.join(AUDIO, "%s-3.wav" % name)
        if os.path.exists(path):
            os.remove(path)
            removed += 1
    return removed


def build_manifest() -> tuple[int, int]:
    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    heroes = manifest["heroes"]
    written = 0
    lines: dict[str, list[dict]] = {}
    for cue in KINDS:
        name = "hero-3-%s-%s-0.wav" % (VOICE_ID, cue)
        path = os.path.join(VOICES, name)
        if not os.path.exists(path):
            silence(path)
            written += 1
        lines[cue] = [{
            "file": name,
            "ja": "",
            "zh": "",
            "length": PLACEHOLDER_SECONDS,
            "voice_id": VOICE_ID,
            "placeholder": True,
            "note": "占位空音频：把同名的正式录音放进来即可，无需改代码。",
        }]
    entry = {
        "name": HERO_NAME,
        "voice_id": VOICE_ID,
        "credit": "",
        "character_type": "hidden-recruit",
        # The switch HeroVoice reads. Flip it to true once the takes exist.
        "voice_ready": False,
        "note": ("尚未录音。这里只有占位空音频与文件名，游戏在此期间不会为该角色播放任何语音。"
                 "补录音后把同名文件放进 assets/audio/voices/，并把 voice_ready 改为 true。"),
        "lines": lines,
        # Zero means "unknown": the offline cut-in falls back to the short timing
        # until a real recording supplies its own length.
        "charge_time": 0.0,
        "burst_time": 0.0,
    }
    manifest["heroes"] = heroes[:3] + [entry]
    json.dump(manifest, open(MANIFEST, "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
    return len(manifest["heroes"]), written


def copy_boss_cues() -> int:
    written = 0
    for cue in BOSS_CUES:
        src = os.path.join(BOSSES, "%s-%s.wav" % (BOSS_SOURCE, cue))
        dst = os.path.join(BOSSES, "hidden-%s.wav" % cue)
        if os.path.exists(src) and not os.path.exists(dst):
            shift(src, dst, BOSS_PITCH, BOSS_SPEED)
            written += 1
    return written


def main() -> int:
    if not os.path.exists(MANIFEST):
        print("missing %s" % MANIFEST, file=sys.stderr)
        return 1
    borrowed = remove_borrowed_takes()
    jingles = reset_jingles()
    heroes, written = build_manifest()
    bosses = copy_boss_cues()
    print("voice banks: %d   placeholders written: %d   borrowed takes removed: %d"
          % (heroes, written, borrowed))
    print("borrowed jingles removed: %d   hidden boss cues: %d" % (jingles, bosses))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
