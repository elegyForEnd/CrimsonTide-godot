"""Apply visually reviewed support-foot and blade-tip landmarks (metadata only)."""
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'assets/combat/weapon-atlases/manifest.json'
manifest=json.loads(path.read_text(encoding='utf-8'))
atlas=manifest['atlases']['0/600']
assert atlas['file']=='weapon-600/hero-0-actions-v5.png', 'Landmarks apply to this original only'
im=Image.open(ROOT/'assets/combat/weapon-atlases'/atlas['file'])
alpha=im.getchannel('A')
rear_x=[196,740,1207,178,704,1193]
tips=[(417,136),(829,13),(1138,75),(493,447),(948,565),(1387,580)]
art_rear=[195,754,1201,175,704,1196]
art_tips=[(340,722),(642,645),(1429,711),(491,960),(949,1077),(1381,1080)]
support_points={}
for state,points,endpoints in [('attack',rear_x,tips),('art',art_rear,art_tips)]:
    support_points[state]=[]
    for i,frame in enumerate(atlas['states'][state]):
        x,y,w,h=frame['region']
        boot=alpha.crop((points[i]-12,y+int(h*.65),points[i]+12,y+h)).point(lambda v:255 if v>160 else 0).getbbox()
        assert boot
        foot_y=y+int(h*.65)+boot[3]-1
        frame['pivot']=[points[i]+60-x,foot_y-y]
        frame['socket']=[endpoints[i][0]-x,endpoints[i][1]-y]
        support_points[state].append([points[i],foot_y])
atlas['review']='Support boot registered at fixed ground point; hand-painted endpoint visually reviewed. Continuous playback still under review.'
atlas['anchor_review']={'support_boot_source_x':rear_x,'support_boot_actor_x':-60,'source_tips':tips,'support_points':support_points}
atlas['sources'].pop('weapon-600/hero-0-attack-v2.png',None)
atlas.get('page_heights',{}).pop('weapon-600/hero-0-attack-v2.png',None)
atlas['sources'].pop('weapon-600/hero-0-actions-v2.png',None)
atlas.get('page_heights',{}).pop('weapon-600/hero-0-actions-v2.png',None)
atlas['fps']={'idle':1,'walk':7,'run':11.5}
path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Registered twelve support boots across normal cut/spin art; source RGBA untouched')
