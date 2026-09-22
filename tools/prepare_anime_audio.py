"""Rebuild the CC0 bank with bright, compact anime-action layering.

Run prepare_free_voices.py first; cinematic effects follow its speech timing.
The original library builder supplies licensed source readers and the quiet foley.
"""
import json
import shutil
from pathlib import Path
import prepare_library_audio as b

b.build_bank()

layer, cue = b.layer, b.cue
sw, sword, spell, druid, heal, k, f = b.sw, b.sword, b.spell, b.druid, b.heal, b.k, b.f

# Short air snaps, pitched metallic glints, and spectral tails; no wet cutting foley.
for i in range(6):
    cue(f"slash-{i}", [layer(sw([1,2,4,5,7,9][i]), speed=1.30 if i<4 else 1.05, gain=.85, high=700),
                       layer(sword([3,4,6,3,7,5][i]), speed=1.5, high=2100, gain=.32, duration=.25),
                       layer(spell("Lightning",i%4+1), speed=1.6, high=3100, gain=.13, duration=.15)],
        .28 if i<4 else .36, tail=.08, room=.35, rms=.19)
for i in range(4):
    cue(f"heavy-{i}", [layer(sw([7,8,9,6][i]), speed=.85, high=200, gain=.7),
                       layer(druid("Wind",i+1), speed=1.45, duration=.32, gain=.4),
                       layer(sword(7), speed=1.15+i*.04, high=1800, duration=.26, gain=.38)], .46, room=.45, rms=.21)
    cue(f"impact-heavy-{i}", [layer(druid("Earth",i+1), speed=1.4, duration=.34, low=2200, gain=.72),
                              layer(spell("Lightning",i+1), speed=1.4, duration=.27, high=1200, gain=.52),
                              layer(k(f"impactGlass_medium_00{i}"), speed=1.5, gain=.20)], .48, tail=.14, room=.55, rms=.22)
    cue(f"impact-metal-{i}", [layer(f"swords/sword_clash.{i+2}.ogg", speed=1.6, high=1500, gain=.65),
                              layer(spell("Ice",i+1), speed=1.6, duration=.17, gain=.18)], .30, tail=.10, rms=.15)
    cue(f"magic-{i}", [layer(heal([2,4,7,11][i]), speed=1.6, high=1100, duration=.38, gain=.65),
                       layer(spell("Ice",i+1), speed=1.45, duration=.36, high=600, gain=.38),
                       layer(sw(i+1), speed=1.6, high=1300, gain=.32)], .50, tail=.18, room=.5, rms=.17)
    cue(f"impact-magic-{i}", [layer(spell("Ice",i+1), speed=1.45, duration=.40, high=650, gain=.65),
                              layer(heal(i+7), speed=1.8, duration=.4, high=2200, gain=.40)], .56, tail=.22, room=.6, rms=.18)
    cue(f"magic-windup-{i}", [layer(heal([4,5,7,9][i]), reverse=True, duration=.42, stretch=.19, high=1600)],
        .22, tail=.025, rise=True, rms=.13)
    cue(f"dash-{i}", [layer(sw([7,8,9,6][i]), speed=1.45, high=900),
                      layer(druid("Wind",i+1), speed=1.7, duration=.2, high=1700, gain=.18)], .22, rms=.14)
    cue(f"equip-{i}", [layer(sword([3,4,7,6][i]), speed=1.6, high=1200, duration=.22, gain=.5),
                       layer(heal(i+4), speed=1.8, high=2400, duration=.19, gain=.2)], .3, tail=.09, rms=.12)
for i in range(5):
    cue(f"hit-{i}", [layer(k(f"impactPunch_heavy_00{i}"), speed=1.35, duration=.17, gain=.45),
                     layer(spell("Lightning",i%4+1), speed=1.9, duration=.18, high=1700, gain=.55)],
        .24, tail=.08, rms=.20)
for i in range(3):
    cue(f"shot-{i}", [layer(spell("Lightning",i+1), speed=1.65, duration=.19, high=700, gain=.65),
                      layer(k(f"impactMetal_light_00{i}"), speed=1.45, high=1900, gain=.18)], .26, tail=.08, rms=.17)
    # The separate character bank supplies grunts; impacts no longer contain another voice.
    cue(f"hurt-{i}", [layer(k(f"impactPunch_medium_00{i}"), speed=1.3, gain=.6),
                      layer(spell("Ice",i+1), speed=1.5, duration=.14, high=2000, gain=.16)], .26, tail=.09, rms=.13)
    cue(f"death-{i}", [layer(druid("Wind",i+1), speed=1.25, duration=.4, gain=.55),
                       layer(spell("Ice",i+1), speed=1.8, duration=.3, high=2000, gain=.2)], .45, tail=.16, rms=.10)
    cue(f"loot-{i}", [layer(heal([4,7,11][i]), speed=1.85, duration=.27, high=1900, gain=.55),
                      layer("foley1/bell_01.ogg", speed=1.4+i*.12, gain=.18, duration=.27)], .38, tail=.13, rms=.11)
    cue(f"ui-{i}", [layer(k(f"impactGlass_light_00{i}"), speed=1.8, high=1800, duration=.08)], .10, tail=.04, rms=.07)
for i in range(2):
    cue(f"down-{i}", [layer(druid("Earth",i+1), duration=.30, low=1800, gain=.5),
                      layer(spell("Ice",i+2), duration=.3, high=2200, gain=.15)], .55, tail=.22, rms=.11)
    cue(f"heal-{i}", [layer(heal([4,7][i]), speed=1.3, duration=1.0, high=500),
                      layer("foley1/bell_01.ogg", speed=1.8, duration=.30, gain=.12)], 1.05, tail=.32, rms=.13)

voices = json.loads((b.ROOT/"assets/audio/voices/voice-manifest.json").read_text(encoding="utf-8"))
for hero, meta in enumerate(voices["heroes"]):
    core = [spell("Fire",2),heal(11),spell("Lightning",1)][hero]
    motif = [sword(6),spell("Ice",2),druid("Wind",4)][hero]
    cue(f"skill-{hero}", [layer(core, speed=1.3, duration=.75, gain=.7),
                          layer(motif, speed=1.5, duration=.65, high=1500, gain=.4)], .9, tail=.3, room=.5, rms=.16)
    for short in [False,True]:
        suffix = "-short" if short else ""
        charge_len = .60 if short else meta["charge_time"]
        burst_len = .22 if short else meta["burst_time"]
        cue(f"ultimate-charge{suffix}-{hero}", [layer(core, reverse=True, duration=1.6, stretch=charge_len, gain=.55, high=600),
                                                layer(motif, reverse=True, duration=.65, stretch=charge_len, high=1600, gain=.38),
                                                layer(druid("Wind",hero+1), reverse=True, duration=1.6, stretch=charge_len, gain=.3)],
            charge_len, tail=.035, rise=True, rms=.13, width=1.1)
        # Leave midrange room for the named attack and place sparkle around its dry voice.
        cue(f"ultimate-burst{suffix}-{hero}", [layer(core, speed=1.2, gain=.62),
                                               layer(motif, speed=1.4, high=2000, gain=.48),
                                               layer(druid("Earth",1), duration=.28, low=1300, gain=.35 if hero!=1 else .12)],
            burst_len, tail=.07 if short else .35, room=1.0, rms=.19, width=1.15)

used_paths = {part["path"] for spec in b.CUES.values() for part in spec.get("layers",[])} | {"ambience.mp3"}
used_files = {path:info for path,info in b.USED.items() if path in used_paths}
used_sources = {info["source"] for info in used_files.values()}
manifest = {"license":"CC0-1.0","license_url":"https://creativecommons.org/publicdomain/zero/1.0/",
            "note":"Anime action revision: edited/layered CC0 source designs. Japanese voices are separately licensed under voices/.",
            "sample_rate":b.RATE,"sources":{key:{"author":v[0],"url":v[1]} for key,v in b.SOURCES.items() if key in used_sources},
            "source_files":used_files,"cues":b.CUES,"style":"anime-action-2026-09-22"}
(b.OUT/"library-manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
for file in b.OUT.iterdir():
    if file.suffix in [".wav",".ogg",".json"]:
        shutil.copy2(file,b.ROOT/"assets/audio"/file.name)
credits = ["CRIMSON TIDE — ANIME ACTION SOUND EFFECTS",f"114 CC0 sound effects / ambience from {len(used_files)} source files.",
           "The separate Japanese voice bank is NOT CC0; see VOICE-CREDITS.txt.",
           "SFX license: https://creativecommons.org/publicdomain/zero/1.0/", ""]
seen = set()
for spec in manifest["sources"].values():
    if spec["url"] not in seen:
        credits.extend([spec["author"],spec["url"],""])
        seen.add(spec["url"])
credits += ["Game edits: transient cuts, pitch/time treatment, crystalline layers, stereo reflections and mastering.",
            "Provenance and recipes: assets/audio/library-manifest.json (AUDIO-MANIFEST.json in the portable package).",
            "Source libraries, synthesis caches and model runtimes are excluded from the game distribution."]
for target in [b.ROOT/"AUDIO-CREDITS.txt",b.ROOT/"assets/audio/CREDITS.txt"]:
    target.write_text("\n".join(credits)+"\n",encoding="utf-8")
print("ANIME SOUND BANK:",len(b.CUES),"cues; voices remain independently licensed")

# Preserve the stronger post-CG release cues when rebuilding the full bank.
from prepare_ultimate_audio import build as build_ultimate_releases
build_ultimate_releases()
