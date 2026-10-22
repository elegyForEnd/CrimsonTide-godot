"""Measure transparent gutters in unchanged originals; register native UV regions."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/combat/weapon-reference-v2'

def valley(profile,expected,radius):
    lo=max(1,int(expected-radius)); hi=min(len(profile)-1,int(expected+radius))
    smoothed=np.convolve(profile,np.ones(5)/5,mode='same')
    window=smoothed[lo:hi]
    low=window.min()
    candidates=np.flatnonzero(window<=low+1)
    return lo+int(candidates[np.argmin(abs(candidates+lo-expected))]),float(low)

def measure(weapon,record,spec):
    path=ROOT/record['atlas']; original=Path(record['original'])
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    if digest!=hashlib.sha256(original.read_bytes()).hexdigest(): raise ValueError('Original changed')
    image=Image.open(path)
    if image.mode!='RGBA' or image.getchannel('A').getextrema()[0]!=0: raise ValueError('True alpha required')
    data=np.asarray(image); h,w=data.shape[:2]
    solid=data[:,:,3]>80
    count=5 if int(spec['family']) in [0,3] else 4
    cuts=[0]; risks=[]
    for i in range(1,count):
        cut,risk=valley(solid.sum(axis=1),h*i/count,h/count*.44)
        cuts.append(cut); risks.append(risk/w)
    cuts.append(h)
    clips={}; layers={}; regions={}
    roles=['normal','heavy','art','impact','charge','shard','mist','trail','projectile','projectile_art']
    for row in range(count):
        y0,y1=cuts[row:row+2]
        cut,risk=valley(solid[y0:y1].sum(axis=0),w/2,w*.20)
        risks.append(risk/max(1,y1-y0))
        for col,(x0,x1) in enumerate([(0,cut),(cut,w)]):
            role=roles[row*2+col]
            cell=data[y0:y1,x0:x1]
            visible=cell[:,:,3]>24
            yy,xx=np.where(visible)
            if not len(xx): raise ValueError(f'{weapon}/{role} empty')
            bx0,by0,bx1,by1=int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)
            regions[role]=[x0,y0,x1,y1]
            file='res://'+path.relative_to(ROOT).as_posix()
            layers[role]={'file':file,'uv':[(x0+bx0)/w,(y0+by0)/h,(bx1-bx0)/w,(by1-by0)/h],
                          'aspect':(bx1-bx0)/max(1,by1-by0),'sha256':digest}
            if role in ['normal','heavy','art']:
                straight=weapon==601 or (int(spec['family']) in [0,3] and (role!='art' or spec['art_kind']!='burst'))
                pivot=[.10,.50] if straight else [.16,.72]
                contact=[.90,.50] if straight else [.86,.83]
                burst=role=='art' and int(spec['family'])==3 and spec['art_kind']=='burst'
                if burst: pivot=[.50,.75]; contact=[.95,.75]
                clips[role]={'file':file,'sha256':digest,'original':str(original),'single_peak':True,
                    'size':[w,h],'canvas_aspect':(x1-x0)/(y1-y0),
                    'frame_rects':[[x0/w,y0/h,(x1-x0)/w,(y1-y0)/h]]*4,
                    'frame_bounds':[[y0/h,y1/h]]*4,'pivot':pivot,'contact':contact,
                    'reveal_mode':3 if burst else 1 if straight else 0,'placement':'burst' if burst else 'blade'}
    layers['surface']=layers['normal']; layers['ground']=layers['impact']
    clips['finisher']=clips['art']
    if int(spec['family'])==3 and spec['art_kind'] in ['beam','burst']:
        # A charged single spell uses its compact contact/payload source;
        # the art alone owns the elaborate multi-stage signature shape.
        slot='projectile_art' if spec['art_kind']=='beam' else 'impact'
        r=layers[slot]; u,v,rw,rh=r['uv']
        burst=spec['art_kind']=='burst'
        clips['charged_spell']={'file':r['file'],'sha256':digest,'original':str(original),
            'single_peak':True,'size':[w,h],'canvas_aspect':r['aspect'],
            'frame_rects':[[u,v,rw,rh]]*4,'frame_bounds':[[v,v+rh]]*4,
            'pivot':[.50,.80] if burst else [.08,.50],
            'contact':[.95,.80] if burst else [.92,.50],
            'reveal_mode':3 if burst else 1,'placement':'burst' if burst else 'blade'}
    folder=BASE/str(weapon)
    qa={'cuts':cuts,'regions':regions,'max_solid_gutter_coverage':max(risks),'all_risks':risks}
    # Significant hard-painted material crossing a gutter requires re-authoring.
    (folder/'atlas-qa.json').write_text(json.dumps(qa,indent=2)+'\n',encoding='utf-8')
    if max(risks)>.08: raise ValueError(f'{weapon}: painted cells overlap ({max(risks):.1%}); revise atlas')
    (folder/'manifest.json').write_text(json.dumps({'weapon':weapon,'layers':layers,'family':spec['family'],'status':'pending_visual_qa'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (folder/'shapes.json').write_text(json.dumps({'weapon':weapon,'clips':clips,'status':'pending_visual_qa'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(weapon,'gutters',cuts,'max hard crossing',round(max(risks),4))
    return digest,qa

def register(batch):
    path=ROOT/'art/weapon-all-v2/production.json'; production=json.loads(path.read_text(encoding='utf-8'))
    specs={r['id']:r for r in production['weapons']}
    received=json.loads((ROOT/f'art/weapon-all-v2/received-batch{batch:02d}.json').read_text(encoding='utf-8'))
    for r in received:
        digest,qa=measure(r['id'],r,specs[r['id']])
        specs[r['id']].update(r,status='registered_pending_runtime_qa',sha256=digest,qa=qa)
    path.write_text(json.dumps(production,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':
    import sys
    register(int(sys.argv[1]))
