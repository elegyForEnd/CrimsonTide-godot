"""Original tileable PBR surfaces for the editable oath-knight model.

Creates source textures, not edits to ImageGen reference artwork. Deterministic.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/bosses/3d/oath-knight/textures"
OUT.mkdir(parents=True, exist_ok=True)
N = 1024
rng = np.random.default_rng(43172)
y, x = np.mgrid[:N, :N].astype(np.float32)
def noise(scale):
    a = rng.integers(0, 256, (scale, scale), dtype=np.uint8)
    return np.asarray(Image.fromarray(a).resize((N, N), Image.Resampling.BICUBIC), dtype=float)/255-.5

records = []
for name, base, rough, metal in [
    ("steel", (64, 80, 92), .39, 1.0),
    ("brass", (148, 112, 64), .46, .91),
    ("blade", (144, 164, 176), .25, 1.0),
    ("leather", (40, 28, 26), .78, 0),
    ("cloth", (73, 19, 29), .88, 0),
]:
    broad = noise(32); grain = noise(384); pits = noise(150)
    height = broad*.3+grain*.11+pits*.1
    c = np.ones((N,N,3))*base
    c *= (1+broad[...,None]*.36+grain[...,None]*.10)
    damage = Image.new("L", (N,N)); d=ImageDraw.Draw(damage)
    if metal:
        for _ in range(1200):
            px,py=rng.integers(0,N,2); length=int(rng.integers(3,45))
            dx=int(rng.integers(-6,7)); value=int(rng.integers(30,145))
            d.line((int(px),int(py),int(px)+dx,int(py)+length),fill=value,width=1)
        scars=np.asarray(damage,dtype=float)/255
        c += scars[...,None]*np.array([65,61,55])
        height -= scars*.32
        oxidation=np.maximum(0,-broad-.14)*2
        c=c*(1-oxidation[...,None]*.28)+oxidation[...,None]*np.array([30,13,5])
        r=np.clip(rough+broad*.2+scars*.18+oxidation*.14,.1,.9)
    elif name=="cloth":
        weave=(np.sin(x*np.pi)*.015+np.sin(y*np.pi)*.015)
        # 2-pixel warp/weft avoids aliasing the weave at normal viewing sizes.
        weave=((x%4<2).astype(float)+(y%4<2).astype(float)-1)*.025
        height+=weave
        c*=1+weave[...,None]*1.8
        r=np.clip(rough+grain*.08,.75,1)
    else:
        height+=np.maximum(0,pits-.15)*.35
        c*=1+grain[...,None]*.24
        r=np.clip(rough+grain*.1,.55,1)
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))*2.8
    dy=(np.roll(height,-1,0)-np.roll(height,1,0))*2.8
    normal=np.stack((-dx,-dy,np.ones_like(dx)),axis=-1)
    normal/=np.linalg.norm(normal,axis=-1)[...,None]
    ao=np.clip(1-np.maximum(0,-pits-.1)*.28,0,1)
    orm=np.stack((ao,r,np.full_like(r,metal)),axis=-1)
    for suffix, pixels in [("albedo",np.clip(c,0,255)),("normal",(normal*.5+.5)*255),("orm",orm*255)]:
        Image.fromarray(pixels.astype(np.uint8)).save(OUT/f"{name}-{suffix}.png")
    records.append({"material":name,"size":[N,N],"albedo":"sRGB","normal":"OpenGL, linear","orm":"R=AO G=roughness B=metallic, linear"})
(OUT.parent/"surface-manifest.json").write_text(json.dumps({"origin":"original deterministic authored surfaces","generator":"tools/make_oath_knight_textures.py","license":"project original","surfaces":records},indent=2),encoding="utf-8")
print("OATH_KNIGHT_TEXTURES",len(records)*3)
