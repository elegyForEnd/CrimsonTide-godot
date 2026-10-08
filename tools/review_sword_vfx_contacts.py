"""Locate contact highlights in untouched directional slash originals."""
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'assets/combat/imagegen-mechanics/manifest.json'
manifest=json.loads(path.read_text(encoding='utf-8'))
for key in ['identity_600_return','identity_600_finisher','identity_603_double_slash','identity_604_slash','identity_605_slash','identity_606_slash','identity_607_slash','identity_609_slash']:
    entry=manifest['assets'][key]
    with Image.open(ROOT/'assets/combat/imagegen-mechanics'/entry['file']) as im:
        # The source direction has been visually reviewed; this chooses a solid
        # bright point on the forward right cutting edge, never empty midpoint.
        px=im.load(); left,top,right,bottom=entry['ink']
        points=[(min(px[x,y][:3])*px[x,y][3]/255,x,y)
                for x in range(int(left+(right-left)*.70),right,2)
                for y in range(top,bottom,2)]
        strength,x,y=max(points)
        assert strength>100, 'Source lacks a bright attachable edge'
        entry['contact']=[x,y]
        entry['contact_review']='Bright forward edge in visually reviewed directional stroke; original RGBA unchanged'
        print(key,entry['contact'])
path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
