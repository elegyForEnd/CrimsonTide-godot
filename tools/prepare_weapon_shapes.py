"""Register actual-shaped stage artwork on one common virtual canvas per clip."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]

def prepare(weapon=617):
    base=ROOT/f'assets/combat/weapon-batch-01/{weapon}'
    art=ROOT/f'art/weapon-batch-01/{weapon}'
    clips={}
    for action in ['normal','heavy','art']:
        single=base/f'{action}-peak-v1.png'
        if single.exists():
            record=json.loads((art/f'{single.stem}.json').read_text(encoding='utf-8'))
            with Image.open(single) as image:
                if image.mode!='RGBA' or image.getchannel('A').getextrema()[0]!=0: raise ValueError('Transparent RGBA required')
                data=np.asarray(image); h,w=data.shape[:2]
                light=data[:,:,0]*.2126+data[:,:,1]*.7152+data[:,:,2]*.0722
                yy,xx=np.where((data[:,:,3]>100)&(light>170)&(np.indices((h,w))[0]>h*.65)&(np.indices((h,w))[1]>w*.62))
                keep=yy>=np.percentile(yy,85)
                tip=[float(xx[keep].mean())/w,float(yy[keep].mean())/h]
                digest=hashlib.sha256(single.read_bytes()).hexdigest()
                if digest!=hashlib.sha256(Path(record['original']).read_bytes()).hexdigest(): raise ValueError('Original changed')
                clips[action]={**record,'single_peak':True,'sha256':digest,'size':[w,h],'canvas_aspect':w/h,'frame_rects':[[0,0,1,1]]*4,'frame_bounds':[[0,1]]*4,'pivot':[.20,.75],'contact':tip,'reveal_mode':0}
            continue
        path=base/f'{action}-shape-v2.png'
        if not path.exists(): path=base/f'{action}-shape-v1.png'
        if not path.exists(): continue
        record=json.loads((art/f'{path.stem}.json').read_text(encoding='utf-8'))
        with Image.open(path) as image:
            if image.mode!='RGBA': raise ValueError('RGBA required')
            data=np.asarray(image); alpha=data[:,:,3]
            h,w=alpha.shape; nominal=h/4
            coverage=(alpha>=24).sum(axis=1)
            smooth=np.convolve(coverage,np.ones(5)/5,mode='same')
            cuts=[0]
            for i in range(1,4):
                lo=int((i-.30)*nominal); hi=int((i+.30)*nominal)
                window=smooth[lo:hi]
                minimum=float(window.min())
                candidates=np.flatnonzero(window<=minimum+1)
                cut=lo+int(candidates[np.argmin(abs(candidates+lo-i*nominal))])
                if minimum>w*.025: raise ValueError(f'{action}: stage overlap near row {i}')
                cuts.append(cut)
            cuts.append(h)
            # Unequal transparent gutters must not crop a registered key or
            # force independent per-key scaling. Enlarge the common canvas.
            pad=max([nominal*.10]+[cuts[i+1]-(i+1)*nominal for i in range(4)]+[i*nominal-cuts[i] for i in range(4)])+8
            logical=nominal+pad*2
            rects=[[0,(i*nominal-pad)/h,1,logical/h] for i in range(4)]
            bounds=[[cuts[i]/h,cuts[i+1]/h] for i in range(4)]
            # Contact tip is the lower-right bright point in the full peak key.
            luminance=data[:,:,0]*.2126+data[:,:,1]*.7152+data[:,:,2]*.0722
            straight=weapon in [607,608] and action!='normal'
            low_sweep=weapon==614 and action=='art'
            lower=1.25 if straight else 1.50 if low_sweep else 1.65
            yy,xx=np.where((alpha>=100)&(luminance>=170)&(np.indices(alpha.shape)[1]>w*.62)&(np.indices(alpha.shape)[0]>nominal*lower)&(np.indices(alpha.shape)[0]<cuts[2]))
            if len(xx):
                keep=xx>=np.percentile(xx,85) if straight else yy>=np.percentile(yy,85)
                tip=[float(np.mean(xx[keep]))/w,(float(np.mean(yy[keep]))-nominal+pad)/logical]
            else: tip=[.88,(nominal*.92+pad)/logical]
            pivot=[.08,(nominal*.50+pad)/logical] if straight else [.05,(nominal*.80+pad)/logical] if low_sweep else [.20,(nominal*.75+pad)/logical]
            digest=hashlib.sha256(path.read_bytes()).hexdigest()
            if digest!=hashlib.sha256(Path(record['original']).read_bytes()).hexdigest(): raise ValueError('Original changed')
            clips[action]={**record,'sha256':digest,'size':[w,h],'canvas_aspect':w/logical,'frame_rects':rects,'frame_bounds':bounds,'pivot':pivot,'contact':tip,'cuts':cuts,'reveal_mode':1 if straight else 2 if low_sweep else 0,'placement':'ground_wave' if low_sweep else 'blade'}
    if len(clips)!=3: raise ValueError(f'{weapon}: all three action shapes required')
    (base/'shapes.json').write_text(json.dumps({'weapon':weapon,'status':'awaiting_visual_acceptance','clips':clips},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for path in list(base.glob('*-shape-*.png.import'))+list(base.glob('*-peak-*.png.import')):
        old=path.read_text(encoding='utf-8'); new=old.replace('mipmaps/generate=false','mipmaps/generate=true')
        if old!=new: path.write_text(new,encoding='utf-8')
    print(f'{weapon}: three independently drawn actions, four registered stages each; original pixels preserved')

if __name__=='__main__':
    import sys
    prepare(int(sys.argv[1]) if len(sys.argv)>1 else 617)
