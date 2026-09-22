"""Check the separate Japanese speech bank, provenance and cinematic timings."""
from pathlib import Path
import hashlib
import json
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

root = Path(__file__).resolve().parents[1]/"assets/audio/voices"
manifest = json.loads((root/"voice-manifest.json").read_text(encoding="utf-8"))
assert manifest["provider"] == "MiniMax" and manifest["engine"] == "MiniMax speech-2.8-hd"
assert len({h["voice_id"] for h in manifest["heroes"]}) == 3
hashes = set()
for hero in manifest["heroes"]:
    assert hero["credit"].startswith("MiniMax ")
    for group, lines in hero["lines"].items():
        for line in lines:
            p = root/line["file"]
            digest = hashlib.sha256(p.read_bytes()).hexdigest()
            assert digest == line["sha256"] and digest not in hashes, p.name
            hashes.add(digest)
            rate, pcm = wavfile.read(p)
            assert rate == 48000 and pcm.ndim == 1 and pcm.dtype == np.int16, p.name
            assert abs(len(pcm)/rate-line["length"]) < .001, p.name
            x = pcm.astype(float)/32768
            assert np.max(abs(resample_poly(x,4,1))) < .83, p.name
            assert abs(x[0]) < .001 and abs(x[-1]) < .001, p.name
            active = np.flatnonzero(abs(x)>.015)
            assert len(active)>100 and active[0]/rate<.1, p.name
            assert line["ja"] and line["zh"], p.name
            assert line["model"] == "speech-2.8-hd" and line["trace_id"], p.name
            assert line["voice_id"] == hero["voice_id"] == line["voice_setting"]["voice_id"], p.name
            if group == "attack":
                assert line["ja"] in {"はっ！","やっ！","せいっ！","たあっ！","えいっ！","やあっ！","たっ！","ふっ！","はあっ！"}, p.name
                assert line["length"] < 1.1, (p.name, line["length"])
            assert not line["prosody"]["local_pitch_edit"], p.name
            assert line["mastering"]["ending_emphasis_db"] == 0, p.name
            assert np.sqrt(np.mean(x*x)) <= .191, p.name
    assert hero["charge_time"] > hero["lines"]["ultimate-charge"][0]["length"]
    assert hero["burst_time"] > hero["lines"]["ultimate-burst"][0]["length"]
assert len(hashes)==51 and len(list(root.glob("*.wav")))==51
print("VOICE ASSETS: 51 distinct MiniMax clips; original loudness, no local pitch edit, provenance, waveforms and CG timing passed")
