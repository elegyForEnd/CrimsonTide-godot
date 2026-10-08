"""Register three four-key animations from an untouched 4:3 ImageGen original.

Image pixels are never resized, recolored, cropped or repacked here. Transparent
gutters define AtlasTexture regions; each row retains its concrete weapon ID.
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

def install(source,hero,weapons,prompt,version=1,state='attack'):
    assert len(weapons)==3 and len(set(weapons))==3
    source=Path(source)
    prompt=Path(prompt)
    with Image.open(source) as im:
        assert im.mode=='RGBA' and abs(im.width/im.height-4/3)<.02
        alpha=im.getchannel('A');assert alpha.getextrema()[0]==0
        w,h=im.size;px=alpha.load()
        rows=boundaries([sum(px[x,y]>96 for x in range(w)) for y in range(h)],3)
        clips=[]
        for row,weapon in enumerate(weapons):
            top,bottom=rows[row:row+2]
            cols=boundaries([sum(px[x,y]>96 for y in range(top,bottom)) for x in range(w)],4)
            frames=[]
            for col in range(4):
                left,right=cols[col:col+2];cw,ch=right-left,bottom-top
                cell=alpha.crop((left,top,right,bottom))
                ink=cell.point(lambda v:255 if v>96 else 0).getbbox()
                assert ink and ink[0]>0 and ink[1]>0 and ink[2]<cw and ink[3]<ch, f'Clipped row{row} frame{col}'
                body=cell.crop((int(cw*.18),0,int(cw*.75),ch)).point(lambda v:255 if v>160 else 0).getbbox()
                assert body
                frames.append({'region':[left,top,cw,ch],'ink':list(ink),'pivot':[cw*.5,body[3]-1],'socket':[ink[2]-1,(ink[1]+ink[3])*.5]})
                if col==0: height=body[3]-body[1]
            clips.append((weapon,frames,height))
    filename=f'batches/hero-{hero}-weapons-{weapons[0]}-{weapons[-1]}-{state}-v{version}.png'
    target=BASE/filename;assert not target.exists(),'Use another version'
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    path=BASE/'manifest.json';manifest=json.loads(path.read_text(encoding='utf-8'))
    provenance={'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'size':[w,h],'prompt':str(prompt.relative_to(ROOT)).replace('\\','/')}
    for weapon,frames,height in clips:
        key=f'{hero}/{weapon}'
        previous=manifest['atlases'].get(key,{})
        if state in previous.get('states',{}): manifest.setdefault('rejected_atlases',{})[key+f'-before-{state}-row-sheet-v{version}']=previous
        for frame in frames:frame['file']=filename
        # Adding a skill/movement page must preserve the reviewed normal attack.
        manifest['atlases'][key]={**previous,'file':previous.get('file',filename),'states':{**previous.get('states',{}),state:frames},'standing_height':previous.get('standing_height',height),'page_heights':{**previous.get('page_heights',{}),filename:height},'sources':{**previous.get('sources',{}),filename:provenance},'contact_frames':{**previous.get('contact_frames',{}),state:2},'enabled':False,'review':'Pending original boot/socket landmark registration and rendered review'}
    manifest['layout']='4:3 original sheet, four columns x three rows; one four-key concrete animation per row'
    path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Registered three concrete animations, 4 keys each; original RGBA untouched; disabled until landmark review')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('hero',type=int);p.add_argument('weapons',type=int,nargs=3);p.add_argument('--prompt',required=True);p.add_argument('--version',type=int,default=1);p.add_argument('--state',default='attack')
    a=p.parse_args();install(a.source,a.hero,a.weapons,a.prompt,a.version,a.state)
