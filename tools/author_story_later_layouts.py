"""Initial authored scene layout data. Preserve edited JSON on subsequent runs."""
from pathlib import Path
import json,math
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'resources/story-later-acts.json'
if DEST.exists(): raise RuntimeError('Layout already authored; edit JSON instead.')
def rect(x,y,w,h): return [[x,y],[x+w,y],[x+w,y+h],[x,y+h]]
def ellipse(x,y,rx,ry,n=24): return [[round(x+rx*math.cos(i*math.tau/n),2),round(y+ry*math.sin(i*math.tau/n),2)] for i in range(n)]
themes={2:['烟砖机坊','冷却渠工场','钟机裁判庭','铅字档案库','熔炼水渠','钟楼机芯殿','封存铸造厂','地下蓄水机房'],
3:['霜松哨坡','狩猎山道','石英矿脉','陨星裂地','山顶观星台','猎誓试炼坪','废弃测星站','霜骨祭坛'],
4:['蔷薇修剪园','人偶工房','镜月舞厅','凋零庭园','镜棺回廊','无观众剧院','失控温室','面具藏馆'],
5:['盐蚀堤岸','沉船海滩','净水泵渠','潮汐祭池','逆潮闸桥','搁浅船坞','封闭干船坞','沉锚泵房'],
6:['圣都白石阶','圣血圣物堂','破冠庭院','悬卷文库','失序仪式层','六翼圣座','封印圣物库','赤月星仪室']}
acts={}
for a in range(2,7):
 regions={}
 for s in range(9):
  d={'theme':['石城工坊','寒山观星','蔷薇庄园','潮汐船坞','圣都仪式'][a-2] if s==0 else themes[a][s-1],'dressing':[]}
  def place(model,x,y,scale=1,footprint=None,angle=0,reveal=True):
   i={'id':f'a{a}s{s}_{model}_{len(d["dressing"])}','model':f'a{a}_{model}','at':[x,y],'scale':[scale]*3,'angle':angle,'reveal':reveal,'occlusion_height':300*scale}
   if footprint: i['footprint']=footprint
   d['dressing'].append(i)
  if s==0:
   # Outer zones, six service areas and no objects on the central route.
   for i,(x,y) in enumerate([(250,350),(1930,350),(260,1250),(1910,1300)]): place('tree',x,y,.85)
   for i,(x,y) in enumerate([(280,1730),(1860,1730),(320,700),(1870,750)]): place('detail' if i<2 else 'prop',x,y,.55,[65,65])
  else:
   # Named clusters: loading/water/erosion/ritual, not uniform scatter.
   for j,(x,y) in enumerate([(620,820),(810,1020),(520,1320),(3980,2900),(4150,3130),(3850,3370),(660,3500),(800,3750)]):
    place('tree' if j%3==0 else 'rock',x+((a+s)%3-1)*70,y,.6+(j%3)*.17)
   for j,(x,y) in enumerate([(670,1700),(3900,1900),(720,3000),(3900,3950)]):
    place(['hero','detail','prop','wall_broken'][j],x,y,.72,[140,110] if j<3 else [210,90],angle=.15*(s%3-1))
  regions[str(s)]=d
 acts[str(a)]={'regions':regions,'ground':f'a{a}_ground','wall':f'a{a}_wall','floor':f'a{a}_floor',
  'sun':['c4b1a1','a8c9e7','b8b6cf','8ab9ca','d3b6c4'][a-2],'ambient':['89949c','8199b3','9293ac','6e9fab','998495'][a-2],
  'lamp':['ffb46d','97d9ff','eeb5d2','8ee0d3','ed7a8d'][a-2]}
 # Different floor plans. Main plot targets follow region anchors, old IDs stay.
 for s in range(1,9):
  d=regions[str(s)]
  # These are only applied to indoors by the region builder.
  off=(s%3-1)*100
  spine=rect(2050,0,700,4800)
  lower=rect(2100,3920,750,880)
  if a==2: # offset process halls linked by a service gallery
   polygons=[spine,rect(650,1150,2800,850),rect(3100,1900,1000,1700),rect(650,2500,2100,900),rect(650,3200,950,1100),rect(1250,3800,1200,450),lower]
  elif a==3: # central polygonal observatory plus radial annexes
   polygons=[spine,ellipse(2350,2300,1750,1350,12),ellipse(1200,3800,700,650,10),rect(1250,3200,1250,750),lower]
  elif a==4: # long conservatory, an oval stage and asymmetrical storage wings
   polygons=[spine,rect(650,1150,2000,2000),ellipse(3100,2650,1200,1050,20),rect(600,3200,1150,1050),rect(1250,3800,1200,450),lower]
  elif a==5: # broad dry dock, narrow keel-axis, split shipwright wings
   polygons=[spine,rect(650,1000,3300,2100),rect(3200,2750,1000,900),rect(700,3200,950,1150),rect(1250,3800,1300,450),lower]
  else: # ritual nave and octagonal side chapels
   polygons=[spine,ellipse(1250,1900,750,950,8),ellipse(3500,2650,850,1050,8),rect(1200,1350,2100,800),rect(700,2700,2050,650),ellipse(1250,3800,720,600,8),rect(1250,3650,1200,550),lower]
  # Annex shape varies by stage, without cloning a whole previous room plan.
  if s%2: polygons.append(ellipse(2850+off,1250,600,600,12))
  else: polygons.append(rect(2750+off,1000,1100,650))
  d['polygons']=polygons
  d['anchors']=[[1300,1650],[3500,2550],[2460,4170]]
  d['side_anchors']=[[1150,2850],[1200,3900],[3500,3200]]
  d['chests']=[[1100,4000],[3600,3100]]
  d['interior_dressing']=[]
  for j,(model,x,y,scale,fp) in enumerate([('hero',850,2000,.85,[210,170]),('prop',3650,2850,.8,[150,150]),('detail',800,3750,.75,[130,130]),('arch',2400,2100,1,None),('detail',2720,4300,.65,[100,90])]):
   d['interior_dressing'].append({'id':f'a{a}s{s}_inside_{j}','model':f'a{a}_{model}','at':[x,y],'scale':[scale]*3,'footprint':fp,'reveal':True,'occlusion_height':320*scale})
  # An explicitly different thematic centrepiece for each floor.
  if s%3==0: d['interior_dressing'][0]['model']=f'a{a}_detail'
DEST.write_text(json.dumps({'version':1,'units':'100 logic units = 1 metre','acts':acts},ensure_ascii=False,indent=2),encoding='utf8')
print('AUTHORED_LATER_REGIONS',45)
