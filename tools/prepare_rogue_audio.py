"""Original synthesized 44.1kHz mono PCM cues for the five rogue guardians.

Each move has an individual anticipation and impact clip. Deterministic noise,
pitched harmonics and envelopes give wood, furnace, crystal, storm and sword
their own timbre; no downloaded / borrowed recordings.
"""
from pathlib import Path
import array
import json
import math
import random
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/rogue'
RATE = 44100

def render(floor, move, action):
    rng = random.Random(7100 + floor * 100 + move * 7 + len(action))
    duration = {'charge': .65, 'release': .85, 'phase': 1.15, 'fall': 1.4}[action]
    frequencies = [125, 67, 620, 165, 210]
    base = frequencies[floor] * (1 + move * .13)
    data = []
    phase = 0.0
    filtered = 0.0
    for i in range(int(duration * RATE)):
        t = i / RATE
        u = t / duration
        charge = action == 'charge'
        envelope = math.sin(math.pi * min(1, u)) ** .7 if charge else min(1, t * 80) * math.exp(-u * 4.8)
        freq = base * (1 + u * .7 if charge else 1.6 - u * .65)
        phase += math.tau * freq / RATE
        noise = rng.uniform(-1, 1)
        filtered = filtered * .89 + noise * .11
        harmonic = math.sin(phase) + .32 * math.sin(phase * 2.01)
        if floor == 0:  # hollow wooden thump and spore rattle
            value = harmonic * .38 + filtered * 1.6
        elif floor == 1:  # furnace bass and iron clang
            value = math.sin(phase) * .6 + math.sin(phase * 3.73) * .24 + noise * .14
        elif floor == 2:  # bright inharmonic glass chime
            value = math.sin(phase) * .3 + math.sin(phase * 2.76) * .24 + math.sin(phase * 4.17) * .17
        elif floor == 3:  # wind and crackling electrical discharge
            value = filtered * 1.7 + noise * .2 + math.sin(phase * 1.3) * .27
        else:  # low sword sweep and metallic impact
            value = filtered * 1.8 + math.sin(phase) * .28 + math.sin(phase * 5.41) * .22
        pulses = 1.0 if move % 3 == 0 else .72 + .28 * math.cos(t * math.tau * (4 + move))
        data.append(value * envelope * pulses)
    peak = max(abs(x) for x in data) or 1
    return array.array('h', (int(x / peak * 25000) for x in data))

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for floor in range(5):
        requests = [(m, a) for m in range(5) for a in ['charge', 'release']]
        requests += [(0, 'phase'), (0, 'fall')]
        for move, action in requests:
            cue = f'rogue-{floor}-{move}-{action}' if action in ['charge', 'release'] else f'rogue-{floor}-{action}'
            path = OUT / (cue + '.wav')
            pcm = render(floor, move, action)
            with wave.open(str(path), 'wb') as file:
                file.setnchannels(1)
                file.setsampwidth(2)
                file.setframerate(RATE)
                file.writeframes(pcm.tobytes())
            manifest.append({'cue': cue, 'file': path.name, 'samples': len(pcm), 'rate': RATE})
    (OUT / 'manifest.json').write_text(json.dumps({'source': 'original procedural synthesis', 'clips': manifest}, ensure_ascii=False, indent=2), encoding='utf8')
    print(f'Wrote {len(manifest)} original boss cues')

if __name__ == '__main__':
    main()
