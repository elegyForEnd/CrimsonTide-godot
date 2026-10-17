"""Copy tool-generated originals unchanged and author atlas UV/pivot metadata.

Pillow is used for alpha/bounds analysis only. No character pixels are repainted,
removed or resampled. Runtime samples the original PNGs using these rectangles.
"""
from pathlib import Path
import json, shutil, hashlib
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'art/rpg-enemies-v1'
OUT=ROOT/'assets/story/rpg-enemies-v1'

def source_file(record):
    original=Path(record['source'])
    return original if original.exists() else ROOT/record['workspace_source']

def without(rectangles,cut):
    """Partition UV rectangles around another pose's pixels, without editing PNGs."""
    result=[]
    cx,cy,cw,ch=cut
    for x,y,w,h in rectangles:
        x0=max(x,cx); y0=max(y,cy); x1=min(x+w,cx+cw); y1=min(y+h,cy+ch)
        if x0>=x1 or y0>=y1: result.append([x,y,w,h]); continue
        for part in [[x,y,w,y0-y],[x,y1,w,y+h-y1],[x,y0,x0-x,y1-y0],[x1,y0,x+w-x1,y1-y0]]:
            if part[2]>0 and part[3]>0: result.append(part)
    return result

def foreign_cuts(foreign,own,rect):
    x,y,w,h=rect
    if not foreign[y:y+h,x:x+w].any(): return []
    if not own[y:y+h,x:x+w].any(): return [rect]
    # Adjacent cloth and weapons may have interleaving bounding rectangles;
    # subdivide UV space instead of ever erasing a pixel of the wanted pose.
    if w>=h and w>1:
        half=w//2
        return foreign_cuts(foreign,own,[x,y,half,h])+foreign_cuts(foreign,own,[x+half,y,w-half,h])
    if h>1:
        half=h//2
        return foreign_cuts(foreign,own,[x,y,w,half])+foreign_cuts(foreign,own,[x,y+half,w,h-half])
    raise ValueError('Contradictory atlas pixel ownership')

def package():
    OUT.mkdir(parents=True,exist_ok=True)
    records=json.loads((ART/'generation-results.json').read_text(encoding='utf-8'))
    design=json.loads((ROOT/'resources/scarlet/enemies.json').read_text(encoding='utf-8'))
    entries={}
    for row in records:
        key=row['id']; source=source_file(row)
        if row.get('singles'):
            frames=[]
            for single in row['singles']:
                target=OUT/(single['id']+'.png'); shutil.copy2(source_file(single),target)
                with Image.open(target) as image: alpha=np.asarray(image.getchannel('A'))
                ys,xs=np.where(alpha>96); height,width=alpha.shape
                left=max(0,int(xs.min())-3); right=min(width,int(xs.max())+4)
                top=max(0,int(ys.min())-3); bottom=min(height,int(ys.max())+4)
                _,heel_xs=np.where(alpha[max(top,bottom-(bottom-top)//18):bottom,left:right]>128)
                pivot_x=left+float(np.median(heel_xs)) if heel_xs.size else (left+right)/2
                frames.append(dict(path='res://assets/story/rpg-enemies-v1/'+target.name,region=[left,top,right-left,bottom-top],
                                   pivot=[pivot_x,bottom],size=[width,height],opaque_pixels=int((alpha>128).sum()),
                                   sha256=hashlib.sha256(target.read_bytes()).hexdigest(),source=single['source']))
            entries[key]=dict(path=frames[0]['path'],size=frames[0]['size'],layout='separate',frames=frames,
                              display_height=design['bosses'][key]['height'],native_size=True)
            continue
        name=key+('-combat-v2' if row.get('layout')=='vertical' else '')+'.png'
        target=OUT/name
        if source.resolve()!=target.resolve(): shutil.copy2(source,target)
        with Image.open(target) as image:
            alpha=np.asarray(image.getchannel('A'))
            height,width=alpha.shape
        vertical=row.get('layout')=='vertical'
        labels,_=ndimage.label(alpha>96)
        areas=np.bincount(labels.ravel()); areas[0]=0
        bodies=list(np.argsort(areas)[-3:])
        bodies.sort(key=lambda label: np.where(labels==label)[0 if vertical else 1].mean())
        if min(areas[label] for label in bodies)<5000:
            raise ValueError(f'Atlas does not contain three separate full figures: {key}')
        # Follow complete connected figures beyond nominal cells. A long spear
        # or wing never gets cut merely because it crossed the one-third mark.
        primary=np.isin(labels,bodies)
        nearest=ndimage.distance_transform_edt(~primary,return_distances=False,return_indices=True)
        ownership=labels[tuple(nearest)]
        frames=[]
        for i in range(3):
            other=[label for label in bodies if label!=bodies[i]]
            keep=(alpha>96)&(ownership==bodies[i])
            ys,xs=np.where(keep)
            if not xs.size: raise ValueError(f'Empty frame {key}:{i}')
            left=max(0,int(xs.min())-3); right=min(width,int(xs.max())+4)
            top=max(0,int(ys.min())-3); bottom=min(height,int(ys.max())+4)
            heel_start=max(top,bottom-max(10,(bottom-top)//18))
            _,heel_xs=np.where(keep[heel_start:bottom,left:right])
            heel_x=left+float(np.median(heel_xs)) if heel_xs.size else (left+right)/2
            region=[left,top,right-left,bottom-top]
            pieces=[region]; exclusions=[]
            for other_body in other:
                fy,fx=np.where((ownership[top:bottom,left:right]==other_body)&(alpha[top:bottom,left:right]>96))
                if not fx.size: continue
                cut=[left+int(fx.min()),top+int(fy.min()),int(fx.max()-fx.min()+1),int(fy.max()-fy.min()+1)]
                cx,cy,cw,ch=cut
                foreign=(ownership==other_body)&(alpha>96)
                for safe_cut in foreign_cuts(foreign,keep,cut):
                    exclusions.append(safe_cut); pieces=without(pieces,safe_cut)
            frames.append(dict(region=region,pieces=pieces,excluded_neighbor_regions=exclusions,pivot=[heel_x,bottom],
                               opaque_pixels=int(((alpha>128)&(ownership==bodies[i])).sum())))
        info=design['minions'].get(key,design['bosses'].get(key))
        entries[key]=dict(path='res://assets/story/rpg-enemies-v1/'+name,size=[width,height],
                          layout='vertical' if vertical else 'horizontal',frames=frames,
                          display_height=info['height'],sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                          source=str(source),native_size=True)
    manifest=dict(revision='rpg-enemies-1',generator='built-in imagegen',pixel_edits=False,entries=entries)
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    cards=[]
    for key,item in entries.items():
        info=design['minions'].get(key,design['bosses'].get(key))
        title=info.get('name',key)
        images=''.join(f'<img loading="lazy" src="{Path(f["path"]).name}" alt="{title}姿态" style="width:32%;height:300px">' for f in item['frames']) if item['layout']=='separate' else f'<img loading="lazy" src="{Path(item["path"]).name}" alt="{title}三姿态">'
        cards.append(f'<article><h2>{title}</h2><p>{info.get("role",info.get("arena",""))}</p>{images}</article>')
    (OUT/'gallery.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>赤月遗书 · RPG敌人图鉴</title><style>body{background:#11151f;color:#e7ddcb;font:16px system-ui;padding:30px}main{display:grid;grid-template-columns:repeat(2,1fr);gap:24px}article{border:1px solid #78614c;padding:20px;background:#262b35}img{width:100%;height:450px;object-fit:contain}p{color:#b7c6d8}</style><h1>赤月遗书 · 战斗敌人</h1><p>8种小怪 · 6位章节首领 · 2位支线首领。原生尺寸透明图，每个敌人有待机、蓄力、出手三姿态；运行中另有受击、收招及轻量动作。影片仍留空。</p><main>'+''.join(cards)+'</main></html>',encoding='utf-8')
    print(f'{len(entries)} enemy art sets installed; {len(entries)*3} runtime pose regions indexed')

if __name__=='__main__': package()
