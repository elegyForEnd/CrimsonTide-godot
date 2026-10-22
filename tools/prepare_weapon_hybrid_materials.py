"""Measure original alpha bounds and configure sampling; never repaint/crop PNG pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/combat/weapon-hybrid-v7'

def prepare():
    manifest={}
    for key in ['metal','blood','tide','frost','storm','stone','cloth','soul','void','feather','star','sun','bell','heat','mirror','stone-impact','frost-impact','tide-impact','heat-impact']:
        path=BASE/f'{key}.png' if key!='mirror' else ROOT/'assets/combat/crystal-cut-v1/ribbon.png'
        if not path.exists():
            raise RuntimeError(f'Missing material: {key}')
        with Image.open(path) as image:
            if image.mode!='RGBA': raise RuntimeError(f'Missing RGBA: {key}')
            alpha=image.getchannel('A')
            bounds=alpha.point(lambda value:255 if value>=24 else 0).getbbox()
            if not bounds or alpha.getextrema()[0]!=0: raise RuntimeError(f'Invalid transparency: {key}')
            w,h=image.size; x0,y0,x1,y1=bounds
            manifest[key]={'file':'res://'+path.relative_to(ROOT).as_posix(),'uv':[x0/w,y0/h,(x1-x0)/w,(y1-y0)/h],'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':[w,h]}
    (BASE/'materials.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    # The originals are shared; change import sampling only, preserving all pixels.
    paths=list(BASE.glob('*.png.import'))+list((ROOT/'assets/combat/imagegen-mechanics/weapon-v5').glob('*surface_v5.png.import'))
    mechanics=ROOT/'assets/combat/imagegen-mechanics'
    originals=json.loads((mechanics/'manifest.json').read_text(encoding='utf-8'))['assets']
    for key,row in originals.items():
        if 'projectile' in key or key.startswith('charged_') or key.startswith('density_'):
            candidate=mechanics/(str(row.get('file',''))+'.import')
            if candidate.is_file(): paths.append(candidate)
    for path in paths:
        old=path.read_text(encoding='utf-8')
        new=old.replace('mipmaps/generate=false','mipmaps/generate=true')
        if old!=new: path.write_text(new,encoding='utf-8')
    print('Measured 15 surface materials + 4 impact components; configured original texture sampling')

if __name__=='__main__': prepare()
