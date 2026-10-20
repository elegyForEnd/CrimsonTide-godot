"""Encode deterministic real-hit battle captures for local review."""
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/vfx-v6'

def encode():
    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        raise RuntimeError('ffmpeg is required to encode the captured frames')
    records = json.loads((OUT/'battle-capture.json').read_text(encoding='utf-8'))
    (OUT/'battle').mkdir(exist_ok=True)
    for record in records:
        key = f'{int(record["weapon"])}-{record["action"]}'
        frame_count = int(record['frames'])
        source = OUT/f'battle-frames/{key}-%03d.png'
        if not (OUT/f'battle-frames/{key}-{frame_count-1:03d}.png').exists():
            raise RuntimeError(f'Incomplete capture: {key}')
        subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate','30','-i',str(source),'-frames:v',str(frame_count),'-an','-c:v','libx264','-threads','2','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT/f'battle/{key}.mp4')], check=True)
    sequence = OUT/'battle/sequence-600.txt'
    sequence.write_text(''.join(f"file '600-{action}.mp4'\n" for action in ['normal','heavy','art']), encoding='utf-8')
    subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i',str(sequence),'-c','copy','-movflags','+faststart',str(OUT/'sample-600.mp4')], check=True)
    misses = [f'{r["weapon"]}-{r["action"]}' for r in records if r['real_hits']==0]
    print(f'{len(records)} real battle clips encoded; zero-hit clips: {misses}')

if __name__ == '__main__':
    encode()
