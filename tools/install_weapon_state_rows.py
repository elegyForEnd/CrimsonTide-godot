"""Measure and register three four-key states without editing original RGBA.

Draft pages remain disabled until their root/socket landmarks and poses have
been visually reviewed. Adding a page preserves previously registered states.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image
from install_weapon_atlas import boundaries

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/combat/weapon-atlases'

def install(source,hero,weapon,states,prompt,version=1):
    assert len(states)==3 and len(set(states))==3
    assert set(states)<=set(['idle','walk','run','dodge','attack','art'])
    source=Path(source); prompt=Path(prompt)
    filename=f'weapon-{weapon}/hero-{hero}-'+ '-'.join(states)+f'-v{version}.png'
    target=BASE/filename
    assert not target.exists(),'Use another version'
    with Image.open(source) as im:
        assert im.mode=='RGBA' and abs(im.width/im.height-4/3)<.02
        w,h=im.size; alpha=im.getchannel('A'); px=alpha.load()
        rows=boundaries([sum(px[x,y]>96 for x in range(w)) for y in range(h)],3)
        clips={}; heights=[]
        for row,state in enumerate(states):
            top,bottom=rows[row:row+2]
            cols=boundaries([sum(px[x,y]>96 for y in range(top,bottom)) for x in range(w)],4)
            frames=[]
            for col in range(4):
                left,right=cols[col:col+2]; cw,ch=right-left,bottom-top
                cell=alpha.crop((left,top,right,bottom))
                ink=cell.point(lambda v:255 if v>96 else 0).getbbox()
                assert ink and min(ink[0],ink[1],cw-ink[2],ch-ink[3])>=8,f'Insufficient gutter {state}/{col}'
                body=cell.crop((int(cw*.25),0,int(cw*.65),ch)).point(lambda v:255 if v>160 else 0).getbbox()
                assert body
                frames.append({'region':[left,top,cw,ch],'ink':list(ink),'pivot':[w*(col+.5)/4-left,body[3]-1],'socket':[ink[2]-1,(ink[1]+ink[3])*.5],'file':filename})
                if row==0 and col==0: heights.append(body[3]-body[1])
            # Motion uses one ground plane; don't cancel airborne feet by
            # re-anchoring a different shoe at every pose.
            baseline=max(frame['pivot'][1] for frame in frames)
            for frame in frames: frame['pivot'][1]=baseline
            clips[state]=frames
    target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(source,target)
    path=BASE/'manifest.json'; manifest=json.loads(path.read_text(encoding='utf-8'))
    key=f'{hero}/{weapon}'; old=manifest['atlases'].get(key,{})
    if any(state in old.get('states',{}) for state in states):
        manifest.setdefault('rejected_atlases',{})[key+'-before-'+ '-'.join(states)+f'-v{version}']=old
    provenance={'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'size':[w,h],'prompt':str(prompt.relative_to(ROOT)).replace('\\','/')}
    manifest['atlases'][key]={**old,'file':old.get('file',filename),'states':{**old.get('states',{}),**clips},'standing_height':old.get('standing_height',heights[0]),'page_heights':{**old.get('page_heights',{}),filename:heights[0]},'sources':{**old.get('sources',{}),filename:provenance},'enabled':False,'review':'Pending original root/socket landmarks and four-key rendered review'}
    path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Registered draft states; original RGBA unchanged; disabled until review')

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('source');p.add_argument('hero',type=int);p.add_argument('weapon',type=int);p.add_argument('states',nargs=3);p.add_argument('--prompt',required=True);p.add_argument('--version',type=int,default=1)
    a=p.parse_args();install(a.source,a.hero,a.weapon,a.states,a.prompt,a.version)
