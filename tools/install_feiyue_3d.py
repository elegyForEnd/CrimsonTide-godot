"""Install Blender-rendered sprites without per-pose recentering or scaling."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'output/feiyue-3d-v1/renders'
OUT=ROOT/'output/feiyue-3d-v1'
DEST=ROOT/'assets/combat/feiyue-3d'
specs=json.loads((SOURCE/'render-spec.json').read_text())
manifest={}
audit=[]
clips={}
for action,spec in specs.items():
    if spec.get('preview'): raise ValueError('Run a full Blender build before installing; two-frame previews are not complete clips')
    dest=DEST/action; dest.mkdir(parents=True,exist_ok=True)
    images=[]
    for i in range(8):
        source=SOURCE/action/f'{i:03}.png'
        im=Image.open(source).convert('RGBA')
        alpha=im.getchannel('A')
        bbox=alpha.getbbox()
        if not bbox: raise ValueError(f'Empty sprite: {source}')
        if min(bbox[0],bbox[1],im.width-bbox[2],im.height-bbox[3])<4:
            raise ValueError(f'Clipped sprite: {source}: {bbox}')
        if im.getpixel((0,0))[3]!=0: raise ValueError(f'Opaque background: {source}')
        sprite=im.resize((384,384),Image.Resampling.LANCZOS)
        sprite.save(dest/f'{i:03}.png')
        images.append(im)
        audit.append({'action':action,'frame':i,'bbox':bbox})
    clips[action]=images
    pivot=[n/2 for n in spec['pivot']]
    scale=90/(spec['standing_height_pixels']/2)
    manifest['heroes/hero-0/'+action]={'path':'res://assets/combat/feiyue-3d/'+action,'frame_count':8,'pivot':pivot,'facing':1,'standing_height':90,'rect':[-pivot[0]*scale,16-pivot[1]*scale,384*scale,384*scale],'source':'Blender 5.2 / feiyue-character.blend','motion_source':spec.get('motion_source','procedural'),'motion_license':spec.get('license','original')}
(DEST/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(OUT/'inspection/sprite-audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
names=list(clips)
review=Image.new('RGB',(8*160,len(names)*180),'#242837')
d=ImageDraw.Draw(review)
for row,name in enumerate(names):
    d.text((5,row*180+2),name,fill='white')
    for index,im in enumerate(clips[name]):
        tile=Image.new('RGBA',(160,160),'#242837')
        tile.alpha_composite(im.resize((160,160),Image.Resampling.LANCZOS))
        review.paste(tile.convert('RGB'),(index*160,row*180+20))
review.save(OUT/'animation-review.png')
movie=[]
for frame in range(8):
    page=Image.new('RGBA',(5*256,2*282),'#242837')
    draw=ImageDraw.Draw(page)
    for slot,name in enumerate(names):
        x=(slot%5)*256; y=(slot//5)*282
        page.alpha_composite(clips[name][frame].resize((256,256),Image.Resampling.LANCZOS),(x,y+24))
        draw.text((x+12,y+5),name,fill='white')
        draw.line((x+62,y+24+specs[name]['pivot'][1]/3,x+194,y+24+specs[name]['pivot'][1]/3),fill='#515769')
    movie.append(page.convert('RGB'))
movie[0].save(OUT/'feiyue-animation-preview.gif',save_all=True,append_images=movie[1:],duration=120,loop=0)
movie[4].save(OUT/'feiyue-animation-preview.png')
print(f'Installed {len(manifest)} clips / {len(audit)} sprites; all alpha margins verified')
