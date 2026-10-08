"""Record painted contact cores without altering any original image."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

def contact(path, bounds):
    rgba = np.asarray(Image.open(path).convert('RGBA')).astype(float)/255
    x0,y0,x1,y1 = map(int,bounds)
    start = int(x0+(x1-x0)*.65)
    patch = rgba[y0:y1,start:x1]
    strength = patch[:,:,:3].min(2)*patch[:,:,3]
    selected = (strength >= max(.03,float(strength.max())*.75)) & (patch[:,:,3]>.6)
    yy,xx = np.nonzero(selected)
    if not len(xx): return [(x0+x1)*.5,(y0+y1)*.5]
    distal = np.percentile(xx,97)
    near = abs(xx-distal)<=max(2,(x1-x0)*.01)
    candidates = np.flatnonzero(near)
    middle = float(np.median(yy[near]))
    best = int(candidates[np.argmin(abs(yy[candidates]-middle))])
    return [int(xx[best]+start),int(yy[best]+y0)]

def register():
    total = 0
    for folder in ['imagegen-square','imagegen-mechanics']:
        base=ROOT/'assets/combat'/folder
        path=base/'manifest.json'
        data=json.loads(path.read_text(encoding='utf-8'))
        for key,entry in data['assets'].items():
            if not (key.startswith('weapon_') or key.startswith('identity_') or (key.startswith('authored_') and key.endswith('_art'))): continue
            if key.endswith(('_spin','_quake')): continue
            target = entry['frames'][0] if entry.get('frames') else entry
            if 'contact' in target: continue
            source = base/entry.get('file',key+'.png')
            if not source.exists(): continue
            ink=target.get('ink')
            if not ink: continue
            target['contact']=contact(source,ink)
            target['contact_method']='distal luminous core; original alpha'
            total+=1
        path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Registered {total} painted contact cores; existing reviewed contacts preserved')

if __name__ == '__main__': register()
