"""Register clean character frames and their measured support-foot positions."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/bosses/imagegen/actions'
assets={}; warnings=[]
for key in ['grove','furnace','astral','wing','obsidian']:
    path=BASE/(key+'-body-clean-3x3-v5.png')
    repaired=BASE/(key+'-body-clean-3x3-v5-r1.png')
    if repaired.exists(): path=repaired
    if not path.exists(): continue
    image=Image.open(path); assert image.mode=='RGBA' and image.width==image.height
    pixels=np.array(image); cell=image.width/3
    frames=[]; reference=1
    for index in range(9):
        row,col=divmod(index,3); y0,y1=round(row*cell),round((row+1)*cell)
        # Generative arm poses may extend past the nominal division while
        # remaining separate. Register the actual transparent gutter, not a
        # hard cut through the hand. The PNG itself remains untouched.
        band=pixels[y0:y1,:,3]
        columns=np.count_nonzero(band>40,axis=0)
        boundaries=[0]
        for division in [1,2]:
            expected=round(division*cell); start=max(0,expected-round(cell*.18)); end=min(image.width,expected+round(cell*.18))
            values=columns[start:end]; best=values.min()
            candidates=np.where(values==best)[0]+start
            boundaries.append(int(candidates[np.argmin(np.abs(candidates-expected))]))
        boundaries.append(image.width)
        x0,x1=boundaries[col:col+2]
        tile=pixels[y0:y1,x0:x1]; a=tile[:,:,3]; ys,xs=np.where(a>12)
        assert len(xs)>100
        left,right=max(0,int(xs.min())-2),min(x1-x0,int(xs.max())+3)
        top,bottom=max(0,int(ys.min())-2),min(y1-y0,int(ys.max())+3)
        center=a[:,round((x1-x0)*.20):round((x1-x0)*.80)]
        foot_rows=np.where(np.count_nonzero(center>150,axis=1)>3)[0]
        foot_y=float(foot_rows[-1]) if len(foot_rows) else cell*.8
        support_y,support_x=np.where((a>150)&(np.indices(a.shape)[0]>=foot_y-10))
        foot_x=float(np.median(support_x)) if len(support_x) else (x1-x0)*.5
        frames.append({'region':[x0+left,y0+top,right-left,bottom-top],'pivot':[foot_x-left,foot_y-top],
                       'sha256':hashlib.sha256(tile.tobytes()).hexdigest()})
        if index==0: reference=foot_y-top
        edge=np.r_[a[0],a[-1],a[:,0],a[:,-1]]
        if (edge>100).mean()>.035: warnings.append({'identity':key,'frame':index,'issue':'body touches cell boundary'})
    assets[key+'_body_v5']={'file':path.name,'identity':key,'role':'body','style':'body','square':True,'columns':3,'rows':3,
        'frames':frames,'reach':cell*.68,'height':reference,'reference_height':reference,'ink_height':reference,
        'states':{'prepare':[0,1,2,3],'contact':[4,5],'recover':[6,7,8]}}
(BASE/'body-atlas-3x3-v5.json').write_text(json.dumps({'assets':assets},indent=2)+'\n',encoding='utf-8')
print(json.dumps({'bodies':len(assets),'frames':len(assets)*9,'warnings':warnings}))
