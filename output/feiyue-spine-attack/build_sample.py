from pathlib import Path
from PIL import Image, ImageDraw
import json, math, sys, shutil

OUT=Path(__file__).resolve().parent
OUT.mkdir(exist_ok=True)
IMAGES=OUT/'images'; IMAGES.mkdir(exist_ok=True)
source=Path(sys.argv[1]); shutil.copy2(source,OUT/'parts-source.png')
sheet=Image.open(source).convert('RGBA')
# Regions recorded from the generated parts sheet, then trimmed using alpha.
xs=[0,447,815,1238,1536]; ys=[0,554,1024]
names=['hair','head','body','arm_sword','arm_free','leg_left','leg_right','sword']
sizes=[(350,420),(300,320),(280,280),(100,190),(100,190),(85,160),(85,160),(100,300)]
textures={}
for i,name in enumerate(names):
    cell=sheet.crop((round(xs[i%4]*sheet.width/1536),round(ys[i//4]*sheet.height/1024),round(xs[i%4+1]*sheet.width/1536),round(ys[i//4+1]*sheet.height/1024)))
    box=cell.getchannel('A').point(lambda a:255 if a>80 else 0).getbbox()
    if box is None: raise ValueError(name+' is empty')
    cell=cell.crop(box).resize(sizes[i],Image.Resampling.LANCZOS)
    cell.save(IMAGES/(name+'.png')); textures[name]=cell

# Coordinates in Spine space, positive Y upward. Each image has a joint pivot.
bones=[{'name':'root'},{'name':'body','parent':'root','y':150},
 {'name':'hair','parent':'body','y':210}, {'name':'leg_left','parent':'root','x':-62,'y':160},
 {'name':'leg_right','parent':'root','x':62,'y':160},
 {'name':'arm_free','parent':'body','x':80,'y':220,'rotation':18},
 {'name':'head','parent':'body','y':260},
 {'name':'arm_sword','parent':'body','x':-82,'y':220,'rotation':-25},
 {'name':'sword','parent':'arm_sword','x':0,'y':-158,'rotation':-12}]
order=['hair','leg_left','leg_right','arm_free','body','head','sword','arm_sword']
pivots={'hair':(175,65),'head':(150,220),'body':(140,280),'arm_sword':(50,15),'arm_free':(50,15),'leg_left':(42.5,0),'leg_right':(42.5,0),'sword':(50,24)}
attachments={}
for name in order:
    w,h=sizes[names.index(name)]; px,py=pivots[name]
    attachments[name]={name:{'type':'region','path':name,'x':w/2-px,'y':py-h/2,'width':w,'height':h}}
T=[0,.16,.30,.40,.49,.65,.83,1.05]
angles={'body':[0,-7,-12,10,13,5,-2,0],'head':[0,3,5,-6,-8,2,1,0],
 'arm_sword':[0,-60,-125,5,90,45,5,0],'sword':[0,-15,-30,20,25,-10,0,0],
 'arm_free':[0,10,22,-25,-35,-10,5,0],'hair':[0,3,8,-4,-13,-5,3,0]}
anim={'bones':{name:{'rotate':[{'time':t,'angle':v} for t,v in zip(T,vals)]} for name,vals in angles.items()}}
data={'skeleton':{'spine':'3.8.75','images':'./images/','fps':30,'x':-250,'y':0,'width':500,'height':620},
 'bones':bones,'slots':[{'name':n,'bone':n,'attachment':n} for n in order],
 'skins':[{'name':'default','attachments':attachments}],
 'animations':{'attack':anim,'idle':{'bones':{'hair':{'rotate':[{'time':0,'angle':0},{'time':.8,'angle':2},{'time':1.6,'angle':0}]}}}}}
(OUT/'feiyue-attack.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')

def interpolate(t,vals):
    for i in range(len(T)-1):
        if t<=T[i+1]:
            u=(t-T[i])/(T[i+1]-T[i]); return vals[i]+(vals[i+1]-vals[i])*u
    return vals[-1]

def render(t):
    world={}
    for b in bones:
        x,y=b.get('x',0),b.get('y',0); a=math.radians(b.get('rotation',0)+interpolate(t,angles[b['name']]) if b['name'] in angles else b.get('rotation',0))
        if 'parent' in b:
            X,Y,A=world[b['parent']]; c,s=math.cos(A),math.sin(A)
            x,y=X+c*x-s*y,Y+s*x+c*y; a+=A
        world[b['name']]=(x,y,a)
    canvas=Image.new('RGBA',(1000,950),(25,24,36,255))
    d=ImageDraw.Draw(canvas); d.ellipse((370,887,630,917),fill=(14,13,21)); d.text((20,20),'FEIYUE / SPINE 3.8 / ATTACK STUDY',fill=(220,210,215))
    for n in order:
        x,y,a=world[n]; c,s=math.cos(a),math.sin(a); px,py=pivots[n]; X,Y=500+x,900-y
        affine=(c,-s,px-c*X+s*Y,s,c,py-s*X-c*Y)
        layer=textures[n].transform(canvas.size,Image.Transform.AFFINE,affine,Image.Resampling.BICUBIC)
        canvas.alpha_composite(layer)
    return canvas.convert('RGB')
frames=[render(i/30) for i in range(33)]
frames[0].save(OUT/'preview.gif',save_all=True,append_images=frames[1:],duration=33,loop=0)
montage=Image.new('RGB',(1200,740),(25,24,36))
for i,t in enumerate([0,.30,.40,.49,.65,1.05]):
    montage.paste(render(t).resize((400,370)),((i%3)*400,(i//3)*370))
montage.save(OUT/'keyposes.png')
(OUT/'README.md').write_text('''# 绯月攻击骨骼动画小样

Spine 3.8.75 数据，8 个独立贴图部件、9 根骨骼，attack 动作约 1.05 秒，另含 idle。
素材由原图参考生成，属于重新拆层绘制的小样，并非原图无损拆层。
手臂为整段刚性部件，未做肘关节、网格权重或 IK，不能代表最终质量。

打开 feiyue-attack.spine，选择 attack，播放即可。
若工程尚未生成，可在 Spine 导入数据中选 feiyue-attack.json，图片路径设为 images 目录。
preview.gif 使用同一骨骼层级和关键帧由脚本渲染；实际 Spine 显示以编辑器为准。
未接入或覆盖游戏资源。
''',encoding='utf-8')
print('Built',OUT)
