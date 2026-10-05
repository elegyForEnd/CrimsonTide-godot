"""Read six-frame sprite sheets and write registration metadata; preserve original PNGs."""
import json
from PIL import Image
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'assets/rogue/build'
result={}
for hero in range(4):
    path=folder/f'hero-{hero}-jump-v1.png'
    im=Image.open(path)
    assert im.mode=='RGBA'
    w,h=im.size
    entries=[]
    for i in range(6):
        left=round((i%3)*w/3); right=round((i%3+1)*w/3)
        top=round((i//3)*h/2); bottom=round((i//3+1)*h/2)
        cell=im.getchannel('A').crop((left,top,right,bottom))
        bounds=cell.point(lambda a:255 if a>=80 else 0).getbbox()
        assert bounds
        x0,y0,x1,y1=bounds
        entries.append({'cell':[left,top,right-left,bottom-top],'pivot':[(x0+x1)/2,(bottom-top)*.94], 'body_height':y1-y0})
    # Final upright pose defines one common scale; crouching never stretches the body.
    result[str(hero)]={'file':'res://assets/rogue/build/'+path.name,'standing_height':entries[-1]['body_height'],'frames':entries}
(folder/'jump-manifest.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('Registered4 heroes,24 poses with fixed per-hero scale.')
