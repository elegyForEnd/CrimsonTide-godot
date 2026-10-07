"""Validate original 3x3 PNGs; store registration metadata, never repaint art."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/bosses/imagegen/actions'

def main():
    catalog=json.loads((BASE/'catalog-3x3-v5.json').read_text(encoding='utf-8'))['assets']
    assets={}; missing=[]; warnings=[]; errors=[]; sheets=[]
    for spec in catalog:
        path=BASE/spec['file']
        if not path.exists(): missing.append(spec['file']); continue
        try:
            image=Image.open(path)
            assert image.mode=='RGBA', ('requires RGBA',image.mode)
            assert image.width==image.height, ('requires square',image.size)
            data=np.array(image); assert data[:,:,3].min()==0, 'requires true transparency'
            cell=image.width/3
            horizontal=spec['style'] in ['flow','field','directional','projectile','blade']
            source=spec.get('source',(.16,.55) if horizontal else (.5,.82))
            frames=[]; hashes=set(); ink_height=1
            for index in range(9):
                row,col=divmod(index,3)
                x0,x1=round(col*cell),round((col+1)*cell)
                y0,y1=round(row*cell),round((row+1)*cell)
                tile=data[y0:y1,x0:x1]; alpha=tile[:,:,3]
                ys,xs=np.where(alpha>12)
                if len(xs):
                    left,right=max(0,int(xs.min())-2),min(x1-x0,int(xs.max())+3)
                    top,bottom=max(0,int(ys.min())-2),min(y1-y0,int(ys.max())+3)
                else: left,right,top,bottom=0,x1-x0,0,y1-y0
                if index in [2,3,4,5,6]: ink_height=max(ink_height,bottom-top)
                edge=np.r_[alpha[0],alpha[-1],alpha[:,0],alpha[:,-1]]
                if (edge>100).mean()>.035: warnings.append({'asset':spec['id'],'frame':index,'issue':'solid ink at cell boundary'})
                digest=hashlib.sha256(tile.tobytes()).hexdigest(); hashes.add(digest)
                frames.append({'region':[x0+left,y0+top,right-left,bottom-top],
                               'pivot':[cell*source[0]-left,cell*source[1]-top], 'sha256':digest})
            assert len(hashes)>=8, ('too few distinct poses',len(hashes))
            assets[spec['id']]={'file':path.name,'identity':spec['key'],'role':spec['role'],'style':spec['style'],
                               'square':True,'columns':3,'rows':3,'frames':frames,'reach':cell*.68,
                               'height':cell*.67,'ink_height':ink_height,'cell_size':cell,
                               'states':{'prepare':[0,1],'contact':[2,3],'sustain':[4,5,6],'recover':[7,8]},
                               'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
            sheets.append({'identity':spec['key'],'role':spec['role'],'file':path.name,'size':list(image.size),'frames':9})
        except Exception as error: errors.append({'file':path.name,'error':str(error)})
    report={'expected':len(catalog),'ready':len(assets),'frames':len(assets)*9,'missing':missing,'warnings':warnings,'errors':errors,'sheets':sheets}
    (BASE/'atlas-3x3-v5.json').write_text(json.dumps({'assets':assets},indent=2)+'\n',encoding='utf-8')
    (BASE/'audit-3x3-v5.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    dest=ROOT/'build/boss-3x3-audit'; dest.mkdir(parents=True,exist_ok=True)
    ids=list(assets)
    for page in range((len(ids)+11)//12):
        sheet=Image.new('RGB',(1280,1020),'#171d28'); draw=ImageDraw.Draw(sheet)
        for n,key in enumerate(ids[page*12:(page+1)*12]):
            entry=assets[key]; raw=Image.open(BASE/entry['file']); r=entry['frames'][3]['region']
            sample=raw.crop((r[0],r[1],r[0]+r[2],r[1]+r[3])); sample.thumbnail((270,270))
            x,y=n%4*320,n//4*340; sheet.paste(sample,(x+(320-sample.width)//2,y+40+(270-sample.height)//2),sample)
            draw.text((x+14,y+12),key,fill='white')
        sheet.save(dest/('contact-%02d.png'%page))
    print(json.dumps({k:v for k,v in report.items() if k not in ['sheets','missing']},ensure_ascii=False))
if __name__=='__main__': main()
