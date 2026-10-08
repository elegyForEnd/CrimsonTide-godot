"""Install an original ImageGen atlas; only measure pixels, never rewrite RGBA.

Transparent gutters determine regions. Root anchors remain fixed across each
clip, so airborne feet and running bob are not cancelled by per-frame fitting.
"""
import argparse
import hashlib
import json
import shutil
import statistics
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/combat/weapon-atlases'
STATES = ['idle', 'walk', 'run', 'dodge', 'attack', 'art']

def boundaries(counts, divisions):
    length = len(counts)
    result = [0]
    for i in range(1, divisions):
        expected = round(length * i / divisions)
        margin = round(length / divisions * .22)
        gaps = []
        start = None
        for p in range(expected-margin, expected+margin+1):
            if counts[p] == 0:
                if start is None: start = p
            elif start is not None:
                gaps.append((start, p)); start = None
        if start is not None: gaps.append((start, expected+margin+1))
        assert gaps, f'No transparent separator around {expected}; reject/repair source'
        start, end = min(gaps, key=lambda g: abs((g[0]+g[1])/2-expected))
        result.append((start+end)//2)
    return result + [length]

def install(source, hero, weapon, prompt_path, cols=3, version=1, state='attack', page='', action_type='', rows=2):
    source = Path(source)
    with Image.open(source) as original:
        assert original.mode == 'RGBA' and abs(original.width/original.height-4/3) < .02
        alpha = original.getchannel('A')
        assert alpha.getextrema()[0] == 0, 'Real transparency required'
        w, h = original.size
        px = alpha.load()
        labels = ['idle','walk','run','dodge'] if page=='movement' else ['attack','attack','art','art'] if page=='actions' else [state]*rows if state else STATES
        if page: cols=4 if page=='movement' else 3
        row_count=len(labels)
        rows = boundaries([sum(px[x,y]>96 for x in range(w)) for y in range(h)],row_count)
        states = {}
        heights = []
        for row in range(row_count):
            label = labels[row]
            top, bottom = rows[row:row+2]
            columns = boundaries([sum(px[x,y]>96 for y in range(top,bottom)) for x in range(w)],cols)
            frames = []
            for col in range(2 if page=='movement' and row==0 else cols):
                left, right = columns[col:col+2]
                cell = alpha.crop((left,top,right,bottom))
                cw,ch = cell.size
                ink = cell.point(lambda v: 255 if v>96 else 0).getbbox()
                assert ink and ink[0]>0 and ink[1]>0 and ink[2]<cw and ink[3]<ch, f'Clipped {state}:{col}'
                end_x = ink[2]-1
                ys = [y for y in range(ink[1],ink[3]) if cell.getpixel((end_x,y))>96]
                body=cell.crop((int(cw*.20),0,int(cw*.65),ch)).point(lambda v:255 if v>160 else 0).getbbox()
                assert body, f'Missing body {label}:{col}'
                frames.append({'region':[left,top,cw,ch], 'ink':list(ink), 'socket':[end_x,statistics.mean(ys)],'ground':body[3]-1,'root_x':w*(col+.5)/cols-left})
                if row==0 and col==0: heights.append(body[3]-body[1])
            # Root X is the original cell centre. Ground baseline comes from
            # planted poses of a clip, not a different boot in every image.
            ground = max(frame['ground'] for frame in frames)
            for frame in frames:
                frame['pivot']=[frame.pop('root_x'),ground]
                frame.pop('ground')
            states.setdefault(label,[]).extend(frames)
    filename=f'{"type-"+action_type if action_type else "weapon-"+str(weapon)}/hero-{hero}-{page or state or "all"}-v{version}.png'
    target=BASE/filename
    target.parent.mkdir(parents=True,exist_ok=True)
    assert not target.exists(), 'Use another version rather than overwrite art'
    shutil.copy2(source,target)
    manifest_path=BASE/'manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {'generator':'built-in ImageGen','original_rgba':True,'atlases':{}}
    for frames in states.values():
        for frame in frames: frame['file']=filename
    entries=manifest.setdefault('type_atlases' if action_type else 'atlases',{})
    key=f'{hero}/{action_type or weapon}'
    previous=entries.get(key,{})
    old_states=previous.get('states',{})
    old_states.update(states)
    sources=previous.get('sources',{})
    sources[filename]={'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'size':[w,h], 'prompt':str(Path(prompt_path).relative_to(ROOT)).replace('\\','/')}
    page_heights=previous.get('page_heights',{})
    page_heights[filename]=statistics.median(heights)
    entries[key]={**previous,'file':filename,'standing_height':previous.get('standing_height',statistics.median(heights)), 'states':old_states,'sources':sources,'page_heights':page_heights,
        'contact_frames':{label:2 if len(frames)==4 else 3 for label,frames in old_states.items() if label in ['attack','art']}, 'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'size':[w,h], 'prompt':str(Path(prompt_path).relative_to(ROOT)).replace('\\','/'), 'review':'pending animated review', 'enabled':False}
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Installed {hero}/{weapon}/{page or state}: {sum(len(f) for f in states.values())} frames, untouched original RGBA; review pivots/sockets before accepting')

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('source'); p.add_argument('hero',type=int); p.add_argument('weapon',type=int)
    p.add_argument('--prompt',required=True); p.add_argument('--columns',type=int,default=3); p.add_argument('--version',type=int,default=1)
    p.add_argument('--state',default='attack')
    p.add_argument('--page',choices=['movement','actions'],default='')
    p.add_argument('--action-type',default='')
    p.add_argument('--rows',type=int,default=2)
    a=p.parse_args(); install(a.source,a.hero,a.weapon,a.prompt,a.columns,a.version,a.state,a.page,a.action_type,a.rows)
