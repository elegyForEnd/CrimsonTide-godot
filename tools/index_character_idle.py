"""Read alpha landmarks; writes only JSON. Generated PNGs stay untouched."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]

def gutter(alpha, expected, axis, radius):
    counts = alpha.sum(axis=1 if axis == 0 else 0)
    start, end = max(1, expected-radius), min(len(counts)-1, expected+radius)
    groups = []
    run = None
    for n in range(start, end):
        if counts[n] <= 2:
            if run is None: run = n
        elif run is not None:
            groups.append((run, n)); run = None
    if run is not None: groups.append((run, end))
    if groups:
        a, b = min(groups, key=lambda q: abs((q[0]+q[1])/2-expected)-min(q[1]-q[0],12))
        return (a+b)//2
    return min(range(start,end), key=lambda n: int(counts[n])*3+abs(n-expected))

def index_sheet(file, row_count=4, col_count=4):
    im = Image.open(file).convert('RGBA')
    alpha = np.asarray(im)[:,:,3] > 100
    h, w = alpha.shape
    ys = [0] + [gutter(alpha,round(h*n/row_count),0,round(h*.045)) for n in range(1,row_count)] + [h]
    rows, heights = [], []
    row_heights=[]
    for row in range(row_count):
        strip = alpha[ys[row]:ys[row+1],:]
        xs = [0] + [gutter(strip,round(w*n/col_count),1,round(w*.055)) for n in range(1,col_count)] + [w]
        entries = []
        measured=[]
        for col in range(col_count):
            cell = strip[:,xs[col]:xs[col+1]]
            ch, cw = cell.shape
            central = cell[:,round(cw*.2):round(cw*.73)]
            occupied = np.flatnonzero(central.sum(axis=1)>=4)
            foot = int(occupied[-1])+1
            boot_y = max(round(ch*.65),foot-12)
            boots = np.flatnonzero(central[boot_y:foot,:].sum(axis=0)>=2)
            px = (int(boots[0])+int(boots[-1]))/2+round(cw*.2)
            # Crown-to-sole measurement ignores outward weapons.
            body = cell[:,max(0,round(px-cw*.10)):min(cw,round(px+cw*.10))]
            top = int(np.flatnonzero(body.sum(axis=1)>=5)[0])
            measured.append(foot-top)
            if row == 0: heights.append(foot-top)
            labels, count = ndimage.label(cell, np.ones((3,3)))
            sizes = np.bincount(labels.ravel()); main = int(sizes[1:].argmax())+1
            exclude=[]
            for n in range(1,count+1):
                if n==main or sizes[n]>400 or sizes[n]<4: continue
                yy,xx=np.nonzero(labels==n)
                if xx.min()<8 or xx.max()>cw-12:
                    exclude.append([max(0,int(xx.min())-2),max(0,int(yy.min())-2),int(xx.max()-xx.min())+5,int(yy.max()-yy.min())+5])
            entries.append({'cell':[xs[col],ys[row],cw,ch],'pivot':[px,foot],'exclude':exclude})
        rows.append(entries)
        row_heights.append(sum(measured)/len(measured))
    return {'file':f'res://assets/combat/idle/{file.name}','standing_height':sum(heights)/len(heights),'rows':rows,'row_heights':row_heights}

manifest={}
for hero in range(4):
    manifest[str(hero)] = index_sheet(ROOT / f'assets/combat/idle/hero-{hero}-idle-v1.png')
    print(f'hero {hero}: 16 frames, body height {manifest[str(hero)]["standing_height"]}')
for kind in ['unarmed','rifle']:
    file=ROOT/f'assets/combat/idle/{kind}-idle-v1.png'
    if file.exists():
        data=index_sheet(file)
        for hero in range(4):
            for entry in data['rows'][hero]:
                px, foot = entry['pivot']; height = data['row_heights'][hero]
                entry['grip']=[px+height*.24,foot-height*[.46,.45,.49,.59][hero]]
            manifest[str(hero)][kind]={'file':data['file'],'standing_height':data['row_heights'][hero],'frames':data['rows'][hero]}
file=ROOT/'assets/combat/idle/scythe-idle-v1.png'
if file.exists():
    data=index_sheet(file,2,2)
    manifest['3']['scythe']={'file':data['file'],'standing_height':sum(data['row_heights'])/2,'frames':data['rows'][0]+data['rows'][1]}
(ROOT/'assets/combat/idle/manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
