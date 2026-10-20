"""Measure the seven storyboard-derived originals without changing their pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/combat/weapon-606-action-v1'
ART=ROOT/'art/weapon-606-action-v1'
LAYERS=['surface','impact','mist','ground','shard','charge','trail']

def measure():
    entries={}
    sheet=Image.new('RGB',(1200,1200),'#16212c')
    draw=ImageDraw.Draw(sheet)
    for i,key in enumerate(LAYERS):
        path=BASE/f'{key}.png'
        if not path.exists(): continue
        with Image.open(path) as im:
            if im.mode!='RGBA': raise ValueError(f'{key}: RGBA required')
            alpha=im.getchannel('A')
            bounds=alpha.point(lambda a:255 if a>=16 else 0).getbbox()
            if not bounds or alpha.getextrema()[0]!=0: raise ValueError(f'{key}: transparent artwork required')
            w,h=im.size
            x0,y0,x1,y1=bounds
            metadata=json.loads((ART/f'{path.stem}.json').read_text(encoding='utf-8'))
            if not str(metadata['file']).startswith('res://'): metadata['file']='res://'+str(metadata['file'])
            entries[key]={**metadata,'uv':[x0/w,y0/h,(x1-x0)/w,(y1-y0)/h],'size':[w,h],
                          'aspect':(x1-x0)/(y1-y0),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
            preview=im.copy(); preview.thumbnail((570,255))
            x,y=(i%2)*600,(i//2)*300
            sheet.paste(preview,(x+(600-preview.width)//2,y+30+(255-preview.height)//2),preview)
            draw.text((x+16,y+9),key,fill='white')
    if len(entries)!=len(LAYERS): raise ValueError(f'Incomplete storyboard component set: {len(entries)}/7')
    (BASE/'manifest.json').write_text(json.dumps({'weapon':606,'status':'awaiting_user_acceptance','storyboard':'output/weapon-606-action-reference/full-action-v1.png','layers':entries},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for path in BASE.glob('*.png.import'):
        old=path.read_text(encoding='utf-8')
        new=old.replace('mipmaps/generate=false','mipmaps/generate=true')
        if old!=new: path.write_text(new,encoding='utf-8')
    sheet.save(ART/'components.jpg')
    print(f'606 storyboard components: {len(entries)}/7')

if __name__=='__main__': measure()
