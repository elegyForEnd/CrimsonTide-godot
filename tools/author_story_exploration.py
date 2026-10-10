"""Author connected, furnished dungeon graphs and organic outdoor outlines.
Run once. Editing the resulting JSON is the normal authoring workflow.
Requires shapely in output/dungeon-tools (isolated tooling, no game dependency).
"""
from pathlib import Path
import sys,json,math,random
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/'output/dungeon-tools'))
from shapely.geometry import Polygon,LineString,Point,box
from shapely.ops import unary_union
DEST=ROOT/'resources/story-exploration.json'
if DEST.exists(): raise RuntimeError('Exploration layout exists; edit JSON rather than regenerating it.')
content=json.loads((ROOT/'resources/story_content.json').read_text(encoding='utf8'))
INSIDE={'hall','library','crypt','cathedral','mine','chapel','castle'}
functions={1:['前庭','守墓值房','废弃储藏室','旧祭坛','回廊','安葬侧室','石棺室','断柱厅','守卫室','遗骨廊','旧水井','崩塌侧厅','深层门厅','陪葬库','封死旧道'],
2:['装卸门厅','检修工位','备件库','冷却间','配电室','阀门室','维修走廊','主机工场','传动间','煤料间','排水间','废弃炉间','封存机芯室','贵重件库','旧锅炉房'],
3:['防风门厅','勘探室','木支架库','矿脉间','测绘室','结晶洞室','旧矿工营地','观星穹厅','冰裂洞室','遗骨室','星盘廊','祭仪侧室','誓约厅','霜骨库','掩埋旧矿道'],
4:['门廊','修剪间','种子库','苗床室','养护厅','装扮间','枯藤走廊','展演花厅','损坏标本室','旧更衣室','观众回廊','面具侧室','无人舞台','封存展库','失控育种间'],
5:['船坞门厅','绳具库','装卸间','木工室','检修廊','泵阀室','断裂肋骨廊','船体大厅','积盐工具室','蓄水工位','船长回廊','干燥棚','闸机深室','航海器具库','旧排水支线'],
6:['净礼门厅','守经室','供品库','悼念侧殿','祈祷回廊','修复间','封印走廊','圣物中殿','残卷室','戒律侧厅','唱诗回廊','失序仪式间','深层圣座','禁忌圣物库','废弃修复室']}
nodes=[(4000,1150),(2100,1650),(6300,1600),(1750,3400),(4050,3450),(6400,3400),(1750,5450),(4100,5500),(6400,5500),(1750,7500),(4100,7500),(6400,7450),(4000,9650),(6550,9550),(1350,9550)]
base_edges=[(0,1),(0,2),(1,3),(3,4),(4,5),(2,5),(3,6),(6,7),(7,8),(5,8),(6,9),(9,10),(10,11),(8,11),(10,12),(12,13),(9,14)]
regional_nodes={
 1:[(4000,1150),(2100,1750),(6250,1700),(1500,3450),(3700,3500),(6650,3200),(2150,5450),(4300,5500),(6400,5650),(1550,7700),(4150,7400),(6550,7600),(4000,9650),(6500,9650),(1350,9600)],
 2:nodes,
 3:[(4000,1150),(2000,1700),(6200,1600),(1550,3400),(4050,3300),(6450,3500),(1650,5400),(4000,5500),(6650,5400),(2300,7400),(4400,7500),(6500,7600),(4000,9650),(6400,9500),(1450,9400)],
 4:[(4000,1150),(2300,1600),(6100,1550),(1700,3500),(4000,3700),(6650,3300),(1600,5500),(4000,5400),(6500,5600),(1600,7450),(4050,7550),(6500,7700),(4000,9650),(6600,9550),(1300,9650)],
 5:[(4000,1150),(1800,1700),(6250,1600),(1800,3400),(4050,3400),(6400,3350),(1850,5350),(4100,5450),(6500,5500),(1700,7400),(4150,7500),(6400,7450),(4000,9650),(6550,9650),(1450,9500)],
 6:[(4000,1150),(1800,1650),(6500,1600),(1700,3450),(4000,3400),(6550,3350),(1650,5550),(4000,5500),(6500,5550),(1700,7450),(4000,7600),(6400,7450),(4000,9650),(6650,9600),(1400,9600)]}
regional_edges={
 1:[(0,1),(0,2),(1,3),(3,4),(4,5),(2,5),(3,6),(6,7),(7,8),(5,8),(7,10),(10,9),(10,11),(8,11),(10,12),(12,13),(9,14)],
 2:base_edges,
 3:[(0,1),(0,2),(1,3),(2,5),(3,4),(4,5),(3,6),(6,7),(5,8),(8,7),(6,9),(9,10),(10,11),(11,8),(10,12),(12,13),(9,14),(7,10)],
 4:[(0,1),(1,3),(0,2),(2,5),(3,4),(4,5),(3,6),(5,8),(6,7),(7,8),(6,9),(8,11),(9,10),(11,10),(10,12),(12,13),(9,14)],
 5:[(0,4),(0,1),(0,2),(1,3),(2,5),(3,4),(4,5),(4,7),(3,6),(5,8),(6,9),(8,11),(7,10),(9,10),(10,11),(10,12),(12,13),(9,14)],
 6:[(0,4),(0,1),(0,2),(1,3),(2,5),(3,4),(4,5),(4,7),(7,6),(7,8),(6,9),(8,11),(9,10),(10,11),(10,12),(12,13),(9,14)]}
result={'version':1,'units':'100 logical units = 1 metre','dungeons':{},'outdoor':{}}
def points(ring): return [[round(x,2),round(y,2)] for x,y in list(ring.coords)[:-1]]
def polygon(cx,cy,w,h,a,s,i,natural):
 if natural:
  rng=random.Random(a*999+s*41+i)
  n=24
  return Polygon([(cx+math.cos(t*math.tau/n)*w*.5*(1+rng.uniform(-.12,.10)),cy+math.sin(t*math.tau/n)*h*.5*(1+rng.uniform(-.12,.10))) for t in range(n)])
 if a in [3,4,6] or i in [7,12]:
  n=12 if a==4 else 8
  return Polygon([(cx+math.cos(t*math.tau/n)*w*.5,cy+math.sin(t*math.tau/n)*h*.5) for t in range(n)])
 return box(cx-w*.5,cy-h*.5,cx+w*.5,cy+h*.5)
for act in content['acts']:
 a=act['id']
 for s,m in enumerate(act['maps'],1):
  if m['layout'] not in INSIDE:
   # Apertures at cardinal connection points remain broad and walkable.
   rng=random.Random(a*808+s*39)
   corners=[(2400,0),(2680,0),(3400,140),(4070,210),(4510,540),(4600,1250),(4680,2000),(4800,2180),(4800,2620),(4630,3350),(4570,4010),(4290,4490),(3570,4650),(2700,4800),(2180,4800),(1500,4660),(800,4520),(350,4180),(150,3430),(0,2620),(0,2180),(150,1530),(330,850),(670,380),(1500,140),(2180,0)]
   # Curved, non-square cliff/forest shoulders. Port aprons use original coords.
   raw=[]
   for i,p in enumerate(corners):
    q=corners[(i+1)%len(corners)]
    raw.append(p)
    if p[0] not in [0,4800] and p[1] not in [0,4800] and q[0] not in [0,4800] and q[1] not in [0,4800]:
     raw.append(((p[0]+q[0])/2+rng.uniform(-60,60),(p[1]+q[1])/2+rng.uniform(-60,60)))
   result['outdoor'][f'{a}:{s}']={'boundary':[[round(x,2),round(y,2)] for x,y in raw],'edge':'岩脊与坡脚' if a in [1,3] else '林缘与坍塌基础' if a==4 else '侵蚀石岸','soft_platforms':True}
   continue
  natural=(a==1 and m['layout']=='mine') or (a==3 and s==3)
  rng=random.Random(a*1531+s*97)
  centres=[(x+50*rng.randrange(-2,3),y+50*rng.randrange(-1,2)) for x,y in regional_nodes[a]]
  centres[0]=(4000,1150); centres[12]=(4000,9650)
  if s%2==0: centres=[(8000-x,y) for x,y in centres]
  shapes=[]; chambers=[]; trails=[]
  for i,(cx,cy) in enumerate(centres):
   w,h=(2100,1750) if i in [7,12] else (1200+100*((i+a+s)%4),1150+100*((i*3+s)%3))
   if a==5 and i==7: w,h=2100,1900
   if natural: w*=1.15; h*=1.12
   poly=polygon(cx,cy,w,h,a,s,i,natural); shapes.append(poly)
   chambers.append({'id':f'room-{i}','name':functions[a][i],'center':[cx,cy],'boundary':points(poly.exterior),'index':i})
  edges=list(regional_edges[a])
  if s%3==0 and (4,5) in edges and (4,7) not in edges: edges.remove((4,5)); edges.append((4,7))
  for i,(u,v) in enumerate(edges):
   p,q=centres[u],centres[v]
   # Long galleries turn at elbows, rather than all rooms opening onto one spine.
   if natural: chain=[p,((p[0]+q[0])*.5+rng.randrange(-200,201),(p[1]+q[1])*.5+rng.randrange(-200,201)),q]
   elif abs(p[0]-q[0])<400 or abs(p[1]-q[1])<400: chain=[p,q]
   else: chain=[p,(p[0],q[1]),q] if (i+s)%2 else [p,(q[0],p[1]),q]
   width=420 if natural else 400+(50 if a in [2,5] else 0)
   shapes.append(LineString(chain).buffer(width*.5,cap_style=2,join_style=1 if natural else 2))
   trails.append([list(p) for p in chain])
  shapes.append(box(3750,0,4250,1300)); trails.append([[4000,320],list(centres[0])])
  ground=unary_union(shapes).buffer(0)
  if ground.geom_type!='Polygon': raise RuntimeError(f'disconnected {a}:{s}')
  targets=[list(centres[i]) for i in [3,8,12]]
  targets[-1][1]+=100
  sides=[list(centres[i]) for i in [2,13,14]]
  chests=[[centres[i][0]+(200 if i%2 else -200),centres[i][1]+180] for i in [14,13,2,11]]
  bands=[{'start':2050,'end':2650,'from':0,'to':-90,'kind':'ramp' if natural else 'stairs'},
         {'start':4150,'end':4650,'from':-90,'to':-35,'kind':'ramp' if natural else 'stairs'},
         {'start':6200,'end':6700,'from':-35,'to':100,'kind':'ramp' if natural else 'stairs'},
         {'start':8350,'end':8950,'from':100,'to':20,'kind':'ramp' if natural else 'stairs'}]
  d={'name':m['name'],'extent':[8000,10800],'boundary':points(ground.exterior),'voids':[points(r) for r in ground.interiors],
     'chambers':chambers,'edges':[list(e) for e in edges],'trails':trails,'spawn':[4000,320],'waypoint':list(centres[4]),'anchors':targets,'side_anchors':sides,'chests':chests,
     'grade_bands':bands,'natural':natural,'area_m2':round(ground.area/10000,1),'dressing':[],'encounters':[],'steps':[]}
  used=[]
  protected=[Point(p) for p in targets+sides+chests+[d['spawn'],d['waypoint']]]
  def place(model,x,y,scale=1,fp=None,angle=0,reveal=True):
   if any(Point(x,y).distance(p)<210 for p in protected): return
   f=box(x-(fp[0] if fp else 20)*.5,y-(fp[1] if fp else 20)*.5,x+(fp[0] if fp else 20)*.5,y+(fp[1] if fp else 20)*.5)
   if not ground.buffer(-75).covers(f) or any(f.buffer(25).intersects(b) for b in used): return
   if fp: used.append(f)
   d['dressing'].append({'id':f'd{a}s{s}_{len(d["dressing"])}','model':model,'at':[round(x,2),round(y,2)],'scale':[scale]*3,'angle':angle,'reveal':reveal,'occlusion_height':340*scale,**({'footprint':fp} if fp else {})})
  facility={1:'castle_fountain' if s==9 else 'mine_support' if natural else 'archive_lectern',2:'a2_archive' if s==4 else 'a2_hero' if s==7 else 'a2_secondary' if s==8 else 'a2_prop',3:'a3_secondary' if s==8 else 'a3_hero',4:'a4_doll_station' if s==2 else 'a4_secondary' if s in [5,8] else 'a4_hero' if s==7 else 'a4_detail',5:'a5_secondary' if s in [4,8] else 'a5_beacon' if s==6 else 'a5_hero',6:'a6_scriptorium' if s==4 else 'a6_prop' if s in [5,8] else 'a6_hero'}[a]
  for room in chambers:
   i=room['index']; cx,cy=room['center']
   shell=Polygon(room['boundary']); minx,miny,maxx,maxy=shell.bounds
   # Each room has a functional work/burial/storage zone plus a clear fighting lane.
   for side in [-1,1]:
    place(f'd{a}_pier',cx+side*340,cy-300,.75,[80,80])
    place(f'd{a}_niche',cx+side*370,cy+290,.68,[125,75],0 if side<0 else math.pi)
   furniture='dungeon_ossuary' if (a in [1,3,6] and i%3!=1) else 'dungeon_workbench' if i%3==0 else 'dungeon_storage'
   for side in [-1,1]: place(furniture,cx+side*330,cy+(40 if i%2 else -60),.72,[110,130] if furniture=='dungeon_ossuary' else [155,85],math.pi/2 if a==5 else 0)
   place('dungeon_chain_lamp',cx-220,cy-330,.80,None)
   for j in range(3): place('dungeon_roots' if natural else 'dungeon_rubble',cx+(-1 if j%2 else 1)*(320+j*40),cy+(j-1)*270,.6,None,rng.uniform(-math.pi,math.pi),False)
   if a==5 and i%2: place('dungeon_grate',cx+250,cy+180,.8,None,0,False)
   if i==7:
    # Off-axis centrepiece: the playable lane does not run through the model.
    place(facility,cx+560,cy+80,1.15,[310,620] if a==5 and s==7 else [310,280])
   if i in [2,6,11,13]: place('dungeon_fallen_pier',cx+30,cy+370,.7,[200,70],rng.uniform(-.25,.25))
   if i not in [0,1]:
    for j in range(3):
     x,y=cx+(j-1)*150,cy+(-110 if j%2 else 100)
     p=Point(x,y)
     if ground.buffer(-60).covers(p) and not any(p.distance(b)<65 for b in used): d['encounters'].append({'id':f'pack-{i}-{j}','at':[x,y],'room':i})
  # Named gallery thresholds and bundled visual composition, with passable piers.
  for i,(u,v) in enumerate(edges):
   cx,cy=centres[v]; px,py=centres[u]
   if abs(cx-px)<400: place(f'd{a}_portal',cx,(cy+py)*.5,.70,None,0)
   elif abs(cy-py)<400: place(f'd{a}_portal',(cx+px)*.5,cy,.70,None,math.pi/2)
  for band in bands:
   if band['kind']!='stairs': continue
   for y in range(band['start'],band['end'],50):
    line=ground.intersection(LineString([(0,y),(8000,y)]))
    segments=[line] if line.geom_type=='LineString' else list(line.geoms)
    for line in segments:
     if line.geom_type!='LineString': continue
     coords=list(line.coords); x0,x1=sorted([coords[0][0],coords[-1][0]])
     if x1-x0>30: d['steps'].append({'y':y,'x0':round(x0,2),'x1':round(x1,2)})
  result['dungeons'][f'{a}:{s}']=d
DEST.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print('AUTHORED_EXPLORATION',len(result['dungeons']),'dungeons',len(result['outdoor']),'outdoor',sum(len(d['dressing']) for d in result['dungeons'].values()),'placements')
for key,d in result['dungeons'].items(): print(key,'area',d['area_m2'],'rooms',len(d['chambers']),'voids',len(d['voids']),'props',len(d['dressing']),'encounters',len(d['encounters']))
