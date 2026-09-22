"""Validate licensed recordings, cue coverage, signal quality and CG timings."""
from pathlib import Path
import hashlib
import json
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

project = Path(__file__).resolve().parents[1]
root = project / "assets/audio/voices"
manifest = json.loads((root / "voice-manifest.json").read_text(encoding="utf-8"))
cast = json.loads((project / "tools/free_voice_cast.json").read_text(encoding="utf-8"))
dialogue = json.loads((project / "tools/voice_dialogue.json").read_text(encoding="utf-8"))
assert manifest["provider"] == "Spaland"
assert manifest["engine"] == "prerecorded-human-voice"
assert manifest["terms"] == [cast["terms"]]
assert len(manifest["heroes"]) == 3
assert len({h["voice_id"] for h in manifest["heroes"]}) == 3
required = {"select", "attack", "heavy", "magic", "dash", "hurt", "heal", "down",
            "ultimate-charge", "ultimate-burst", "ultimate-short"}
files = set()
hero_sources = []
for index, hero in enumerate(manifest["heroes"]):
    assert hero["credit"] == cast["credit"]
    assert hero["voice_id"] == cast["heroes"][index]["voice_id"]
    assert set(hero["lines"]) == required
    sources = set()
    for group, lines in hero["lines"].items():
        assert lines
        source_ids = cast["heroes"][index]["lines"][group]
        assert len(lines) == len(source_ids)
        assert len({line["sha256"] for line in lines}) == len(lines), (index, group)
        for offset, line in enumerate(lines):
            source = cast["sources"][source_ids[offset]]
            assert line["source_url"] == source["url"]
            assert line["source_sha256"] == source["sha256"]
            assert source_ids[offset].startswith(hero["voice_id"] + "-")
            assert line["ja"] == source["ja"] and line["zh"] == source["zh"]
            assert dialogue[index]["lines"][group][offset] == {k: line[k] for k in ["ja", "zh"]}
            sources.add(line["source_sha256"])
            path = root / line["file"]
            assert path.parent == root and path.is_file()
            assert hashlib.sha256(path.read_bytes()).hexdigest() == line["sha256"]
            rate, pcm = wavfile.read(path)
            assert rate == 48000 and pcm.ndim == 1 and pcm.dtype == np.int16
            assert abs(len(pcm)/rate-line["length"]) < .001
            x = pcm.astype(float)/32768
            assert np.max(abs(resample_poly(x, 4, 1))) < .81
            assert abs(x[0]) < .001 and abs(x[-1]) < .001
            active = np.flatnonzero(abs(x) > .015)
            assert len(active) > 100 and active[0]/rate < .1, path.name
            assert .025 < np.sqrt(np.mean(x*x)) <= .161, path.name
            assert line["mastering"]["pitch_shift"] == 0
            assert line["mastering"]["speed"] == 1.0
            if group == "attack":
                assert line["length"] < 1.1, path.name
            files.add(line["file"])
    assert len(hero["lines"]["attack"]) >= 3
    assert hero["charge_time"] > hero["lines"]["ultimate-charge"][0]["length"]
    assert hero["burst_time"] > hero["lines"]["ultimate-burst"][0]["length"]
    hero_sources.append(sources)
assert not (hero_sources[0] & hero_sources[1] | hero_sources[0] & hero_sources[2] | hero_sources[1] & hero_sources[2])
assert files == {p.name for p in root.glob("*.wav")}, "No stale synthesized WAVs in game bank"
print(f"VOICE ASSETS: {len(files)} human recordings; provenance, cast consistency, subtitles, waveforms and CG timing passed")
