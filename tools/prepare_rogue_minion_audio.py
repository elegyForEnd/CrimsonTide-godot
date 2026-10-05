"""Deterministic original synthesized cues, one per minion skill (80 WAVs)."""
from pathlib import Path
import array, json, math, random, re, wave
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/rogue'
RATE = 44100

def main():
    source = (ROOT / 'scripts/rogue_minions.gd').read_text(encoding='utf8')
    loadouts = source.split('const LOADOUTS := [', 1)[1].split('\n]\n', 1)[0]
    moves = re.findall(r'\["([^"]+)","([^"]+)"\]', loadouts)
    assert len(moves) == 80
    records = []
    for number, (name, kind) in enumerate(moves):
        floor, variant, index = number // 16, number // 2 % 8, number % 2
        rng = random.Random(18400 + number)
        magic = kind in ['heal','repair','sacrifice_heal','shield','armor','haste','speed','power','summon','ring','beam']
        base = (360 if magic else 105) * (1 + floor*.1 + variant*.055 + index*.08)
        duration = .65 if magic else .4
        data = []
        filtered = 0.0
        phase = 0.0
        for sample in range(int(RATE*duration)):
            t = sample/RATE
            u = t/duration
            phase += math.tau*base*(1.25-u*.35)/RATE
            noise = rng.uniform(-1,1)
            filtered = filtered*.88+noise*.12
            value = (math.sin(phase)*.4+math.sin(phase*2.76)*.23+math.sin(phase*4.17)*.1) if magic else (filtered*1.5+math.sin(phase)*.35+noise*.13)
            value *= min(1,t*90)*math.exp(-u*5)*(1-u)**.4
            data.append(value)
        peak = max(map(abs,data)) or 1
        pcm = array.array('h',(int(value/peak*17000) for value in data))
        cue = f'rogue-minion-{floor}-{variant}-{index}'
        path = OUT / (cue+'.wav')
        with wave.open(str(path),'wb') as out:
            out.setnchannels(1); out.setsampwidth(2); out.setframerate(RATE); out.writeframes(pcm.tobytes())
        records.append({'cue':cue,'move':name,'kind':kind,'file':path.name,'samples':len(pcm),'rate':RATE})
    (OUT/'minion-manifest.json').write_text(json.dumps({'source':'original procedural synthesis','clips':records},ensure_ascii=False,indent=2),encoding='utf8')
    print(f'Generated {len(records)} minion skill cues')

if __name__ == '__main__': main()
