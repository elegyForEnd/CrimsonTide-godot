"""Build Crimson Tide's offline sound bank from attributed CC0 recordings/designs.

Run from any directory with Python + numpy/scipy and ffmpeg on PATH.
Source downloads stay in build/audio-library; only mastered game cues are exported.
No Suno samples, generated noise or oscillators are used here.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, resample_poly

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "build/audio-library"
OUT = ROOT / "build/audio-remaster"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 48000
CACHE, USED, CUES = {}, {}, {}
SOURCES = {
    "swords": ("StarNinjas", "https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes"),
    "swishes": ("artisticdude", "https://opengameart.org/content/swishes-sound-pack"),
    "foley": ("Jan Schupke / Vehicle", "https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx"),
    "kenney": ("Kenney", "https://kenney.nl/assets/impact-sounds"),
    "spells": ("Lentikula", "https://lentikula.itch.io/freecc0-basic-spell-impacts-sfx"),
    "druid": ("Lentikula", "https://lentikula.itch.io/druid-spell-impacts"),
    "healing": ("Lentikula", "https://lentikula.itch.io/healing-spell-impacts"),
    "foley1": ("rubberduck", "https://opengameart.org/content/100-cc0-sfx"),
    "foley2": ("rubberduck", "https://opengameart.org/content/100-cc0-sfx-2"),
    "gun": ("Ben Jaszczak and the Free Firearm Sound Library team", "https://opengameart.org/content/the-free-firearm-sound-library"),
    "hurt-source.ogg": ("AuraVoice / Nocturnal_Vanguard", "https://opengameart.org/content/female-hurt-grunts-groans"),
    "reload-source.wav": ("SpringySpringo", "https://opengameart.org/content/gun-reload-sounds"),
    "cock-source.wav": ("SpringySpringo", "https://opengameart.org/content/gun-reload-sounds"),
    "ambience.mp3": ("kindland", "https://opengameart.org/content/forgoten-tomb-ambience"),
}


def read(path):
    if path not in CACHE:
        file = SRC / path
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(file), "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-"],
                             capture_output=True, check=True).stdout
        CACHE[path] = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)
        USED[path] = {"sha256": hashlib.sha256(file.read_bytes()).hexdigest(), "source": path.split("/")[0]}
    return CACHE[path].copy()


def layer(path, gain=1.0, speed=1.0, high=65, low=17000, at=0.0, duration=None,
          reverse=False, delay=0.0, stretch=None, trim=True):
    return dict(path=path, gain=gain, speed=speed, high=high, low=low, at=at,
                duration=duration, reverse=reverse, delay=delay, stretch=stretch, trim=trim)


def render(spec):
    x = read(spec["path"])
    start = round(spec["at"] * RATE)
    end = start + round(spec["duration"] * RATE) if spec["duration"] else len(x)
    x = x[start:end]
    x -= np.mean(x, axis=0)
    if spec["trim"]:
        # Remove recording pre-roll, retaining 4 ms before the first audible transient.
        energy = np.max(abs(x), axis=1)
        indices = np.flatnonzero(energy > max(.003, energy.max() * .035))
        if len(indices):
            x = x[max(0, indices[0] - 192):min(len(x), indices[-1] + 4800)]
    x = sosfilt(butter(2, [spec["high"], spec["low"]], btype="bandpass", fs=RATE, output="sos"), x, axis=0)
    x /= max(np.max(abs(x)), 1e-6)
    if spec["speed"] != 1:
        x = resample_poly(x, 100, round(spec["speed"] * 100), axis=0)
    if spec["reverse"]:
        x = x[::-1].copy()
    if spec["stretch"]:
        # Offline time stretch preserves the source pitch for the cinematic reveal.
        ratio = len(x) / RATE / spec["stretch"]
        filters = []
        while ratio < .5:
            filters.append("atempo=0.5")
            ratio /= .5
        while ratio > 2:
            filters.append("atempo=2")
            ratio /= 2
        filters.append(f"atempo={ratio:.8f}")
        raw = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-i", "-",
                              "-af", ",".join(filters), "-f", "f32le", "-"],
                             input=x.astype(np.float32).tobytes(), capture_output=True, check=True).stdout
        x = np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)
    return x * spec["gain"]


def cue(name, layers, length, tail=.08, room=0.0, rise=False, rms=.18, width=.85):
    x = np.zeros((round(length * RATE), 2))
    for spec in layers:
        sample = render(spec)
        start = round(spec["delay"] * RATE)
        count = min(len(sample), len(x) - start)
        x[start:start + count] += sample[:count]
    if room:
        dry = x.copy()
        for seconds, gain in [(.037, .17), (.073, .12), (.127, .075), (.191, .045)]:
            delay = round(seconds * RATE)
            if delay < len(x):
                x[delay:] += dry[:-delay, ::-1] * gain * room
    mid = x.mean(axis=1, keepdims=True)
    x = mid + (x - mid) * width
    fade_in = min(round((.05 if rise else .002) * RATE), len(x))
    x[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    if rise:
        x *= np.linspace(.08, 1, len(x))[:, None] ** .7
    fade_out = min(round(tail * RATE), len(x))
    x[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None] ** 1.5
    active = np.max(abs(x), axis=1) > .015
    assert active.any(), name
    x *= min(3, rms / max(np.sqrt(np.mean(x[active] ** 2)), 1e-6))
    # Check oversampled peaks, not just stored PCM peaks.
    true_peak = np.max(abs(resample_poly(x, 4, 1, axis=0)))
    if true_peak > .86:
        x *= .86 / true_peak
    wavfile.write(OUT / (name + ".wav"), RATE, np.round(x * 32767).astype(np.int16))
    CUES[name] = dict(layers=layers, length=length, tail=tail, room=room, rise=rise, rms=rms, width=width,
                      peak_db=round(float(20*np.log10(max(np.max(abs(x)), 1e-8))), 2))


def f(name): return "foley/sfx-cc0/" + name + ".wav"
def k(name): return "kenney/Audio/" + name + ".ogg"
def sw(number): return f"swishes/swishes/swish-{number}.wav"
def sword(number): return f"swords/sword - StarNinjas/sword.{number}.ogg"
def spell(element, number): return f"spells/{element} Spell Impacts/{element} Spell Impact {number}.wav"
def druid(element, number): return f"druid/{element} Spell Impacts/{element} Spell Impact {number}.wav"
def heal(number): return f"healing/Impacts/Healing Spell Impact {number}.wav"


# A swing is air and a blade ring; a collision only sounds after confirmed contact.
for i, number in enumerate([1, 2, 4, 5, 7, 9]):
    cue(f"slash-{i}", [layer(sw(number), speed=[1.1, 1.12, 1, 1.04, .84, .88][i]),
                       layer(sword([3, 4, 6, 3, 7, 5][i]), gain=.22, high=1700, duration=.40)], .32 if i<4 else .42, room=.3)
for i, number in enumerate([7, 8, 9, 6]):
    cue(f"heavy-{i}", [layer(sw(number), speed=.60, low=10500),
                       layer(f("knife-unsheathe-02"), gain=.22, speed=.75, high=1300, duration=.4)], .55, room=.5)
for i in range(5):
    cue(f"hit-{i}", [layer(k(f"impactPunch_heavy_00{i}"), gain=.90),
                     layer(f(f"apple-cut-0{i%3+1}"), gain=.43, high=900, duration=.25)], .30, room=.2)
for i in range(4):
    cue(f"impact-heavy-{i}", [layer(druid("Earth", i+1), gain=.85, duration=.50, low=4200),
                              layer(k(f"impactPunch_heavy_00{i}"), gain=.85, speed=.8),
                              layer(f("metal-hammer-hit-01"), gain=.28, duration=.30)], .68, tail=.20, room=.6)
    cue(f"impact-metal-{i}", [layer(f"swords/sword_clash.{i+2}.ogg", gain=.70),
                              layer(k(f"impactMetal_heavy_00{i}"), gain=.40)], .52, tail=.16, room=.4)
    cue(f"magic-{i}", [layer(spell("Ice", i+1), duration=.65, high=450, gain=.80),
                       layer(sw(i+1), speed=1.3, gain=.20)], .72, tail=.22, room=.4)
    cue(f"impact-magic-{i}", [layer(spell("Ice", i+1), gain=.85, duration=.75),
                              layer(k(f"impactGlass_medium_00{i}"), gain=.30)], .90, tail=.27, room=.6)
    cue(f"magic-windup-{i}", [layer(heal([4, 5, 7, 9][i]), gain=.5, reverse=True, duration=.6, stretch=.20, high=800)], .22, tail=.025, rise=True)
    cue(f"dash-{i}", [layer(sw([7, 8, 9, 6][i]), speed=.9),
                      layer(f("cloth-pouch-shake-01"), gain=.20, duration=.24, high=300)], .28, room=.15)
    cue(f"land-{i}", [layer(k(f"footstep_concrete_00{i}"), speed=.83),
                      layer(f("boots-leather-jump-01"), gain=.20, duration=.30)], .34)
for i in range(8):
    cue(f"step-{i}", [layer(k(f"footstep_concrete_00{i%5}"), speed=[.95, 1.02, .99, 1.08, .97, 1.05, 1, 1.03][i]),
                      layer(f("boots-leather-step-01"), gain=.12, duration=.22)], .25, tail=.045, rms=.11)
    cue(f"run-{i}", [layer(k(f"footstep_concrete_00{i%5}"), speed=.96 + i*.015),
                     layer(f("cloth-pouch-shake-02"), gain=.20, duration=.19)], .24, tail=.04, rms=.14)
for i, (path, speed, at) in enumerate([("AR-15/D_32P.wav", 1, 5.62), ("AR-15/D_24P.wav", 1.02, .55), ("SKS/U_19P.wav", 1.05, 2.60)]):
    cue(f"shot-{i}", [layer("gun/Prepared SFX Library/"+path, speed=speed, at=at, duration=1.2, high=80)], .60, tail=.20, room=.15)
for i, at in enumerate([.46, 2.07, 3.69]):
    cue(f"hurt-{i}", [layer("hurt-source.ogg", at=at, duration=.68, gain=.8),
                      layer(k(f"impactPunch_medium_00{i}"), gain=.4)], .72, tail=.10, rms=.15)
for i, at in enumerate([4.94, 9.36]):
    cue(f"down-{i}", [layer("hurt-source.ogg", at=at, duration=1.15),
                      layer(k("impactSoft_heavy_000"), gain=.45, speed=.8)], 1.25, tail=.22)
for i in range(3):
    cue(f"loot-{i}", [layer(f(["coinflip-01", "coins-shake-01", "coin-spin-fall-01"][i]), duration=.45),
                      layer("foley1/bell_01.ogg", gain=.10, speed=1.6, delay=.06)], .60, tail=.15, rms=.12)
    cue(f"ui-{i}", [layer(f(["keyhole-lockbox-insert-01", "handcuffs-metal-lock-01", "keyhole-lockbox-turn-01"][i]), duration=.09, high=350)], .11, tail=.025, rms=.1)
    cue(f"skill-{i}", [layer(heal([2, 7, 13][i]), duration=1.5)], 1.6, tail=.4, room=.5)
    cue(f"death-{i}", [layer(druid("Plant", i+1), duration=.65, speed=.77, gain=.70),
                       layer(k(f"impactSoft_heavy_00{i}"), gain=.5)], .85, tail=.26, room=.35)
for i in range(2):
    cue(f"ui-open-{i}", [layer(f(f"book-page-0{i+1}"), duration=.26), layer(f("cloth-pouch-shake-01"), gain=.15, duration=.2)], .30, rms=.1)
    cue(f"ui-close-{i}", [layer(f(f"book-page-0{i+1}"), duration=.22, reverse=True)], .26, rms=.1)
    cue(f"reload-{i}", [layer("reload-source.wav", speed=1+i*.025)], 1.12, tail=.08, rms=.15)
    cue(f"reload-end-{i}", [layer("cock-source.wav", speed=.93+i*.07)], .27, tail=.055, rms=.15)
    cue(f"heal-{i}", [layer(f("bottle-glass-uncork-01"), gain=.30), layer(heal([4, 7][i]), gain=.75, delay=.06)], 1.8, tail=.5, room=.45)
    cue(f"burn-{i}", [layer(spell("Fire", i+2), duration=1.3), layer("foley2/sfx100v2_glass_01.ogg", gain=.24)], 1.45, tail=.4, room=.3)
    cue(f"bell-{i}", [layer(f"foley1/bell_0{i+1}.ogg", speed=.48), layer("foley1/gong_01.ogg", speed=.66, gain=.35)], 3.2, tail=.8, room=1.4, rms=.14)
    cue(f"enemy-cast-{i}", [layer(druid("Plant", i+3), duration=.5, speed=.8)], .62, tail=.2, rms=.12)
    cue(f"chest-{i}", [layer(f("keyhole-lockbox-turn-01"), speed=.95+i*.10),
                       layer(f("drawer-open-01"), gain=.5, delay=.06+i*.025, duration=.55, speed=1-i*.08)], .75, tail=.15)
for i in range(4):
    cue(f"equip-{i}", [layer(f(["knife-unsheathe-02", "knife-unsheathe-02", "cloth-pouch-shake-02", "knife-unsheathe-02"][i]),
                                speed=[1,.9,.95,.75][i], duration=.45)], .50, tail=.12, rms=.13)

# Each ultimate has a different sonic identity. Separate short cues retain the pitch.
for hero, core in enumerate([spell("Fire", 2), heal(11), spell("Lightning", 1)]):
    motif = sword(6) if hero==0 else spell("Ice", 2) if hero==1 else druid("Earth", 4)
    for short, charge_len, burst_len in [(False, 1.85, .70), (True, .60, .21)]:
        suffix = "-short" if short else ""
        cue(f"ultimate-charge{suffix}-{hero}", [layer(core, duration=1.4, reverse=True, stretch=charge_len, gain=.70),
                                                layer(druid("Wind", hero+1), duration=2, reverse=True, stretch=charge_len, gain=.40),
                                                layer(motif, duration=.7, reverse=True, stretch=charge_len, gain=.35)],
            charge_len, tail=.035, rise=True, rms=.16, width=1.12)
        cue(f"ultimate-burst{suffix}-{hero}", [layer(core, duration=burst_len, gain=.85),
                                               layer(motif, duration=burst_len, gain=.45),
                                               layer(druid("Earth", 1), duration=burst_len, low=1600, gain=.45 if hero!=1 else .18)],
            burst_len, tail=.07 if short else .22, room=.8, rms=.23, width=1.10)

ambient = read("ambience.mp3")[RATE*15:RATE*63]
ambient = sosfilt(butter(2, [55, 6500], btype="bandpass", fs=RATE, output="sos"), ambient, axis=0)
cross = 4 * RATE
mix = np.linspace(0, 1, cross)[:, None]
ambient[-cross:] = ambient[-cross:]*(1-mix) + ambient[:cross]*mix
ambient = ambient[cross:]
ambient *= .35 / max(np.max(abs(ambient)), 1e-6)
wavfile.write(OUT / "ambient-source.wav", RATE, np.round(ambient*32767).astype(np.int16))
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(OUT/"ambient-source.wav"), "-c:a", "libvorbis", "-q:a", "6", str(OUT/"ambient.ogg")], check=True)
(OUT/"ambient-source.wav").unlink()
CUES["ambient"] = {"source": "ambience.mp3", "start": 15, "duration": 48, "crossfade": 4, "length": 44}
manifest = {"license": "CC0-1.0", "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
            "note": "Recorded foley and authored sound designs, edited for Crimson Tide. No generative audio. Original authors retain attribution below.",
            "sample_rate": RATE, "sources": {key: {"author": value[0], "url": value[1]} for key,value in SOURCES.items()},
            "source_files": USED, "cues": CUES}
(OUT/"library-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Mastered {len(CUES)} cues from {len(USED)} source recordings/designs.")
