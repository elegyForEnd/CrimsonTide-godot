"""Verify actual Suno OGG provenance, PCM format, energy, peaks and loop seams."""
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
folder = ROOT / 'assets/audio/music'
manifest = json.loads((folder / 'music-manifest.json').read_text(encoding='utf-8'))
plan = json.loads((ROOT / 'resources/scene_music_plan.json').read_text(encoding='utf-8'))
checked = 0
for name in plan:
    assert name in manifest['tracks'], f'Missing dedicated music: {name}'
    spec = manifest['tracks'][name]
    file = folder / spec['file']
    assert hashlib.sha256(file.read_bytes()).hexdigest() == spec['sha256'], name
    assert spec['task_id'] and spec['clip_id'] and spec['request']['make_instrumental'], name
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(file), '-f', 'f32le',
                          '-ar', '44100', '-ac', '2', 'pipe:1'], capture_output=True, check=True).stdout
    pcm = np.frombuffer(raw, dtype='<f4').reshape(-1, 2)
    assert np.isfinite(pcm).all() and len(pcm) > 60 * 44100, name
    assert abs(len(pcm) / 44100 - spec['duration_seconds']) < .05, name
    assert .005 < float(np.sqrt(np.mean(pcm ** 2))) < .25, name
    assert float(np.abs(pcm).max()) < .95, name
    seam = float(np.abs(pcm[0] - pcm[-1]).max())
    assert seam < .03, (name, seam)
    print(name, f'{len(pcm)/44100:.1f}s seam={seam:.6f}')
    checked += 1
assert checked == len(plan)
print(f'SCENE MUSIC ASSETS: all {checked} generated loops verified')
