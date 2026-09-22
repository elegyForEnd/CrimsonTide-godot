"""Bake art from authoritative Godot geometry so water, cliffs and paths agree.
Run Godot --headless --script tools/export_world_layout.gd first.
"""
import json, math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
from scipy.ndimage import gaussian_filter
D=json.loads(Path('output/world-layout.json').read_text(encoding='utf-8'))
W,H=map(int,D['size']); size=(W,H); out=Path('assets/world')
rng=np.random.default_rng(821)
def mask(poly):
    m=Image.new('L',size); ImageDraw.Draw(m).polygon([tuple(p) for p in poly],fill=255); return m
def texture(index):
    t=Image.open(out/f'terrain-{index}.png').convert('RGB')
    t=ImageEnhance.Color(t).enhance(.67)
    canvas=Image.new('RGB',size)
    for y in range(0,H,t.height):
        for x in range(0,W,t.width): canvas.paste(t,(x,y))
    return canvas
land=texture(0)
for i,r in enumerate(D['regions'][1:],1):
    t=texture(i if i!=5 else 0)
    if i==1: t=Image.blend(t,texture(0),.48)
    if i==5: t=Image.blend(t,texture(2),.42)
    land.paste(t,(0,0),mask(r['polygon']).filter(ImageFilter.GaussianBlur(95)))
# Soft broad variations break repeated tiles while retaining generated detail.
noise=rng.random((48,64)).astype('float32')
noise=Image.fromarray((noise*255).astype('uint8')).resize(size,Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(20))
a=np.asarray(land).astype(np.float32); shade=.80+np.asarray(noise)[:,:,None]/255*.29
a=np.clip(a*shade,0,255).astype('uint8'); land=Image.fromarray(a)
roadmask=Image.new('L',size); rd=ImageDraw.Draw(roadmask)
for line in D['roads']:
    pts=[tuple(p) for p in line]; rd.line(pts,fill=255,width=86,joint='curve')
    for x,y in pts: rd.ellipse((x-42,y-42,x+42,y+42),fill=255)
roadmask=roadmask.filter(ImageFilter.GaussianBlur(9))
road=Image.blend(texture(1),Image.new('RGB',size,'#b4ab92'),.35)
land.paste(road,(0,0),roadmask)
# Jagged coastline and inset terraces, no painted ground outside walkable land.
coast=mask(D['coast']); water=Image.new('RGB',size,'#46686e')
wd=ImageDraw.Draw(water)
for y in range(0,H,14):
    wd.line([(0,y),(W,y)],fill=('#4b7075' if y%28 else '#52777a'),width=1)
coastshadow=coast.filter(ImageFilter.GaussianBlur(32))
water.paste(Image.new('RGB',size,'#253c42'),(0,0),coastshadow)
water.paste(land,(0,0),coast)
base=water; draw=ImageDraw.Draw(base)
coastpts=[tuple(p) for p in D['coast']]+[tuple(D['coast'][0])]
draw.line(coastpts,fill='#a29880',width=27,joint='curve')
draw.line(coastpts,fill='#e0cf9e',width=7,joint='curve')
# Fine radial cliff marks follow each edge rather than random decorative noise.
for a,b in zip(coastpts,coastpts[1:]):
    ax,ay=a; bx,by=b; dist=math.hypot(bx-ax,by-ay)
    nx,ny=-(by-ay)/dist,(bx-ax)/dist
    for t in np.arange(0,dist,17):
        x=ax+(bx-ax)*t/dist; y=ay+(by-ay)*t/dist
        length=float(rng.uniform(17,38))
        draw.line((x,y,x+nx*length,y+ny*length+8),fill='#5b6156',width=3)
for feature in D['features']:
    m=mask(feature['polygon']); pts=[tuple(p) for p in feature['polygon']]; pts.append(pts[0])
    if feature['kind']=='lake':
        shore=m.filter(ImageFilter.GaussianBlur(16)); base.paste(Image.new('RGB',size,'#9bbfb2'),(0,0),shore)
        base.paste(Image.new('RGB',size,'#4f909b'),(0,0),m)
        draw=ImageDraw.Draw(base); draw.line(pts,fill='#b4d1ba',width=7,joint='curve')
        for x,y in pts[::2]: draw.line((x-15,y+15,x+22,y+13),fill='#7eb2b5',width=2)
    else:
        shadow=m.filter(ImageFilter.GaussianBlur(18)); base.paste(Image.new('RGB',size,'#434d4b'),(0,0),shadow)
        rock=Image.blend(texture(2),Image.new('RGB',size,'#918977'),.5); base.paste(rock,(0,0),m)
        draw=ImageDraw.Draw(base); draw.line(pts,fill='#d0bb91',width=16,joint='curve'); draw.line(pts,fill='#6d6d5c',width=3)
        cx=sum(x for x,y in pts[:-1])/len(pts[:-1]); cy=sum(y for x,y in pts[:-1])/len(pts[:-1])
        for a,b in zip(pts,pts[1:]):
            dist=math.dist(a,b)
            for t in np.arange(0,dist,15):
                x=a[0]+(b[0]-a[0])*t/dist; y=a[1]+(b[1]-a[1])*t/dist
                draw.line((x,y,x+(cx-x)*.19,y+(cy-y)*.19),fill='#b5a688',width=3)
# The exact river polygon is shared with collision and the tactical chart.
river=mask(D['river']); base.paste(Image.new('RGB',size,'#acc5b1'),(0,0),river.filter(ImageFilter.GaussianBlur(16)))
base.paste(Image.new('RGB',size,'#4c8793'),(0,0),river)
# Clip river to coast again.
base=Image.composite(base,water,coast)
for r in D['sites']:
    x,y,w,h=r['rect']; m=Image.new('L',size)
    ImageDraw.Draw(m).rounded_rectangle((x-20,y-20,x+w+20,y+h+20),radius=50,fill=255)
    m=m.filter(ImageFilter.GaussianBlur(11))
    base.paste(texture(5 if r['tier']==2 else 1),(0,0),m)
# Chunks avoid rendering or uploading a 30MP texture on every frame.
for y in range(3):
    for x in range(4): base.crop((x*1600,y*1600,(x+1)*1600,(y+1)*1600)).save(out/f'ground-{x}-{y}.jpg',quality=91,subsampling=0)
# Bridges also appear on the atlas at exactly their playable locations.
draw=ImageDraw.Draw(base)
for x,y,w,h in D['bridges']:
    draw.rectangle((x,y,x+w,y+h),fill='#c7b591',outline='#776e5f',width=9)
    for xx in range(int(x),int(x+w),30): draw.line((xx,y,xx,y+h),fill='#9a8a70',width=2)
# Same terrain, tinted towards illuminated parchment for the exploration atlas.
thumb=base.resize((1600,1200),Image.Resampling.LANCZOS)
thumb=ImageEnhance.Color(thumb).enhance(.48)
thumb=Image.blend(thumb,Image.new('RGB',thumb.size,'#bba886'),.22)
thumb.save(out/'atlas.jpg',quality=94)
print('Baked 12 terrain chunks and matching atlas',len(D['features']),'landforms')
