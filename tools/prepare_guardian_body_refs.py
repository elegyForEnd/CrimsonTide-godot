"""Extract measured neutral atlas cells as references, preserving source pixels."""
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
data=json.loads((ROOT/'assets/rogue/animations/hd-packed-manifest.json').read_text())['assets']
dest=ROOT/'build/boss-square-refs'; dest.mkdir(parents=True,exist_ok=True)
for index,key in enumerate(['grove','furnace','astral','wing','obsidian']):
    file=f'boss-hd-{index}.png'
    sheet=Image.open(ROOT/'assets/rogue/animations'/file)
    r=next(s for s in data if s['file']==file)['frames'][0]['content']
    sheet.crop((r[0],r[1],r[0]+r[2],r[1]+r[3])).save(dest/(key+'-body.png'))
print('Five original neutral guardian body references extracted')
