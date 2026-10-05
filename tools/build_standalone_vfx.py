"""Original effect masks: one 1024px PNG per effect, never a sprite atlas.

SVG sources are rasterized by bake_standalone_vfx.gd using Godot's SVG renderer.
No BlazBlue artwork is copied into this project.
"""
from pathlib import Path
import math
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/combat/standalone'
SRC = OUT / 'sources'
SRC.mkdir(parents=True, exist_ok=True)


def polygon(points, opacity=1):
    return '<polygon points="' + ' '.join(f'{x:.2f},{y:.2f}' for x,y in points) + f'" fill="white" opacity="{opacity}"/>'


def line(points, width=5, opacity=1):
    return '<polyline points="' + ' '.join(f'{x:.2f},{y:.2f}' for x,y in points) + f'" fill="none" stroke="white" stroke-width="{width}" opacity="{opacity}"/>'


def ray(a, r):
    return 512 + math.cos(a)*r, 512 + math.sin(a)*r


def crescent(seed):
    pieces=[]
    for layer in range(1 + seed % 3):
        outer=[]; inner=[]
        for i in range(100):
            u=i/99
            a=-1.45+u*2.9
            r=390-layer*42
            width=(22+seed%5*7)*math.sin(math.pi*u)**.65
            outer.append((280+math.cos(a)*r,512+math.sin(a)*r))
            inner.append((280+math.cos(a)*(r-width),512+math.sin(a)*(r-width)))
        pieces.append(polygon(outer+inner[::-1],1-layer*.24))
    return ''.join(pieces)


def star(seed):
    pieces=[]
    for i in range(6+seed%5):
        a=i*2.39996+seed*.16
        r=170+(i*73+seed*23)%235
        normal=(-math.sin(a),math.cos(a))
        pieces.append(polygon([ray(a,42),
            (512+normal[0]*18,512+normal[1]*18),ray(a,r),
            (512-normal[0]*18,512-normal[1]*18)],.6+(i%3)*.2))
    return ''.join(pieces)


def sigil(seed):
    pieces=[]
    for i in range(6+seed%4):
        a=i*math.tau/(6+seed%4)
        pieces.append(line([ray(a,340),ray(a+.13,275),ray(a+.27,340)],6))
        pieces.append(line([ray(a,375),ray(a+.28,375)],4,.65))
    pieces.append(f'<circle cx="512" cy="512" r="225" stroke="white" stroke-width="4" fill="none"/>')
    corners=3+seed%5
    pieces.append(line([ray(i*math.tau/corners+seed*.2,240) for i in range(corners+1)],6,.8))
    return ''.join(pieces)


def lance(seed):
    w=15+seed%5*9
    body=polygon([(100,512),(670,512-w),(924,512),(670,512+w)],.9)
    for i in range(2+seed%3):
        y=450-i*38
        body+=line([(120+i*75,y),(640,y),(780,y-18)],5,.7)
        body+=line([(120+i*75,1024-y),(640,1024-y),(780,1042-y)],5,.7)
    return body


def flame(seed):
    return '<path d="M300 885 Q150 650 395 470 Q350 680 470 580 Q350 300 565 90 Q520 360 650 425 Q650 230 730 330 Q860 630 700 885 Z" fill="white"/>' + sigil(seed)


def feather(seed):
    parts=[]
    for i in range(5+seed%3):
        a=-1.2+i*.38
        parts.append(polygon([ray(a,80),ray(a-.06,290),ray(a,440),ray(a+.1,200)],.5+i*.06))
    return ''.join(parts)


def crystal(seed):
    parts=[]
    for i in range(3+seed%4):
        x=240+i*100; y=260+(i*73+seed*31)%240
        parts.append(polygon([(x,y),(x+26,720),(x,825),(x-26,720)],.65+(i%2)*.3))
        parts.append(line([(x,y+20),(x,780)],3,.8))
    return ''.join(parts)


def lightning(seed):
    parts=[]
    for branch in range(3):
        points=[(150,400+branch*90)]
        for i in range(1,11):
            points.append((150+i*70,512+math.sin(i*5.1+seed+branch)*100+branch*28))
        parts.append(line(points,10-branch*3,1-branch*.2))
    return ''.join(parts)


BUILDERS=[lance,crescent,flame,sigil,flame,crystal,lightning,crescent,lance,feather,sigil,lance,lance,crescent,feather,star,lance,crescent,sigil,star,crescent]
WEAPONS=['守夜步枪','绯红单手剑','破晓双手剑','星辉法杖','赤陨法杖','霜针短杖','鸣雷之杖','月弧法杖','曦光棱镜杖','烬羽散华杖','虚涡法杖','蚀月长枪杖','鸦喙刺剑','回环弯刀','断潮巨刃','裂地重剑','暮羽长弓','黑铁短剑','祭祀短杖','破碎大剑','湮魂之镰']
manifest={}


def save(name, body):
    # Transparent margin is part of every individual image, preventing edge bleed.
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>'
    (SRC/f'{name}.svg').write_text(svg,encoding='utf8')
    manifest[name]={'file':f'{name}.png','size':[1024,1024],'original':True}


for i,name in enumerate(WEAPONS):
    save(f'weapon_{i:02}_release',BUILDERS[i](i))
    save(f'weapon_{i:02}_impact',star(i)+BUILDERS[i](i+3).replace('opacity="1"','opacity="0.45"'))
    save(f'weapon_{i:02}_finisher',BUILDERS[i](i+7)+sigil(i))
for i,builder in enumerate([crescent,crystal,feather,flame]):
    for j,kind in enumerate(['slash','impact','dash','sigil','ultimate','charge']):
        shape=builder(i+j) if kind in ['slash','dash'] else star(i*3) if kind=='impact' else sigil(i*3+j)
        if kind=='ultimate': shape+=builder(i+9)
        save(f'hero_{i}_{kind}',shape)
for i,builder in enumerate([crescent,star,feather,sigil,star,lance,crystal,flame,sigil]):
    save(f'common_{i}',builder(i))
for i,builder in enumerate([flame,crystal,lightning,crescent,lance,feather,sigil,lance]):
    save(f'spell_{i}',builder(i+4))
save('spark',polygon([(110,512),(512,470),(914,512),(512,554)]))
(OUT/'manifest.json').write_text(json.dumps({'resolution':1024,'atlas':False,'weapons':WEAPONS,'effects':manifest},ensure_ascii=False,indent=2),encoding='utf8')
print(f'{len(manifest)} independent original effects written')
