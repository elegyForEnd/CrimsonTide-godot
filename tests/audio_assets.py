"""Signal checks for the shipped audio bank (does not replace human listening)."""
from pathlib import Path
import hashlib
import json
import subprocess
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

root = Path(__file__).resolve().parents[1]
folder = root / "assets/audio"
manifest = json.loads((folder/"library-manifest.json").read_text(encoding="utf-8"))
assert manifest["license"] == "CC0-1.0"
checks = 0
hashes = set()
for name, spec in manifest["cues"].items():
    if name == "ambient":
        continue
    file = folder/(name+".wav")
    rate, pcm = wavfile.read(file)
    assert rate == 48000 and pcm.dtype == np.int16 and pcm.shape[1] == 2, name
    assert abs(len(pcm)/rate-spec["length"]) < .001, name
    x = pcm.astype(float)/32768
    assert np.max(np.abs(resample_poly(x,4,1,axis=0))) < .87, name
    assert np.max(np.abs(x[0])) < .001 and np.max(np.abs(x[-1])) < .001, name
    active = np.flatnonzero(np.max(np.abs(x),axis=1)>.015)
    assert len(active)>480 and (active[0]/rate<.10 or spec["rise"]), name
    digest = hashlib.sha256(file.read_bytes()).hexdigest()
    assert digest not in hashes, f"Duplicate variation: {name}"
    hashes.add(digest)
    for ingredient in spec["layers"]:
        assert ingredient["path"] in manifest["source_files"], name
        assert manifest["source_files"][ingredient["path"]]["source"] in manifest["sources"], name
    checks += 1
raw = subprocess.run(["ffmpeg","-v","error","-i",str(folder/"ambient.ogg"),"-f","f32le","-ac","2","-ar","48000","-"],
                     capture_output=True,check=True).stdout
x = np.frombuffer(raw,np.float32).reshape(-1,2)
seam = float(np.max(np.abs(x[0]-x[-1])))
assert seam < .02, f"Audible discontinuity at ambience loop: {seam}"
assert np.max(np.abs(x)) < .9 and len(x)>48000*40
assert len(list(folder.glob("*.wav"))) == checks
print(f"AUDIO ASSETS: {checks} distinct WAVs + ambience; peaks, onsets, tails, provenance and loop seam passed (seam {seam:.6f})")
