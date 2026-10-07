"""Choose generated alternatives by boundary quality; never alter PNG pixels."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/bosses/imagegen/actions'

def score(path):
    im=Image.open(path); a=np.array(im.convert('RGBA'))[:,:,3]
    if im.width!=im.height: return 1000
    cell=im.width/3; result=0
    for i in range(9):
        row,col=divmod(i,3); tile=a[round(row*cell):round((row+1)*cell),round(col*cell):round((col+1)*cell)]
        edge=np.r_[tile[0],tile[-1],tile[:,0],tile[:,-1]]
        result+=int((edge>100).mean()>.035)
    return result

def main():
    path=BASE/'catalog-3x3-v5.json'; catalog=json.loads(path.read_text(encoding='utf-8'))
    changes=[]
    for spec in catalog['assets']:
        original=BASE/spec['file']; replacement=BASE/spec['file'].replace('.png','-r1.png')
        if not original.exists() or not replacement.exists(): continue
        old,new=score(original),score(replacement)
        if new<old:
            spec['file']=replacement.name
            spec['source']=[.25,.55] if spec['style'] in ['flow','field','directional','projectile','blade'] else [.5,.73]
            changes.append({'id':spec['id'],'selected':replacement.name,'before':old,'after':new})
    catalog['repair_selections']=catalog.get('repair_selections',[])+changes
    path.write_text(json.dumps(catalog,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(changes))
if __name__=='__main__': main()
