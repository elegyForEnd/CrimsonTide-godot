"""Replace the uniform chamber lattice with authored typologies.

Only edits the exploration JSON. Rebuild/rebake the thirty indoor scenes afterwards.
The old source is backed up under ignored build/, and a second run is refused.
Shapely is an offline authoring dependency, never a runtime dependency.
"""
from pathlib import Path
import json, math, random, sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'output/dungeon-tools'))
from shapely.geometry import Polygon, Point, LineString, box
from shapely.ops import unary_union
from shapely import affinity
PATH=ROOT/'resources/story-exploration.json'

# These are spatial arrangements, not material swaps. Each entry assigns a
# distinct programme, envelope, main space, branching rhythm and edge language.
ASSIGN={
 '1:5':('basilica','旧祷礼拜堂'), '1:6':('cloister','寂钟修道院'),
 '1:7':('grotto','断叶矿窟'), '1:8':('catacomb','斜阳墓室'), '1:9':('castle','灰棘旧堡'),
 '2:3':('factory','锈炉内庭'), '2:4':('archive','灰页书库'), '2:6':('basilica','灰烬法庭'),
 '2:7':('foundry','灰炉铸造厂'), '2:8':('cistern','地下蓄水机房'),
 '3:3':('grotto','坠星矿井'), '3:5':('tower','观星高塔'),
 '3:7':('observatory','废弃测星站'), '3:8':('mausoleum','霜骨祭坛'),
 '4:2':('archive','人偶旧宅'), '4:3':('cloister','月蔷长廊'), '4:5':('catacomb','花冢'),
 '4:6':('theatre','旧影剧场'), '4:7':('garden','失控温室'), '4:8':('exhibition','面具藏馆'),
 '5:4':('cistern','潮下遗迹'), '5:6':('tower','归航灯塔'),
 '5:7':('shipyard','封闭干船坞'), '5:8':('pumphouse','沉锚泵房'),
 '6:2':('basilica','圣血外殿'), '6:4':('archive','誓词书库'), '6:5':('castle','日蚀地下城'),
 '6:6':('cloister','白骨回廊'), '6:7':('reliquary','封印圣物库'), '6:8':('observatory','赤月星仪室'),
}
LABELS={
 'catacomb':['下墓前庭','主甬道','铭文交叉口','陪葬长廊','封印深室','旧墓龛','遗骨支廊','石棺侧室','守墓室','花根墓室','封死旧道','陪葬库','合葬支厅'],
 'grotto':['矿口','岔道岩腔','坍塌矿道','地下大岩腔','渗水洞','深矿脉','弃营','断根洞','支撑架遗址','塌方侧洞','晶簇裂隙','尽头矿井'],
 'basilica':['门廊','中殿前段','中殿后段','十字交会','主祭坛','北耳堂','南耳堂','钟楼基座','司祭侧室','后殿回廊','封存祭室'],
 'cloister':['前门廊','西侧回廊','东侧回廊','北侧回廊','钟院出口','药草庭','值守翼楼','侧礼堂','抄写翼楼','旧食堂','荒废寝室'],
 'castle':['双塔门厅','露天前庭','西守卫翼','东军械翼','大宴厅','旧王座厅','厨房支翼','储藏院','回廊露台','塔楼基座','领主书房','断墙后院'],
 'archive':['门厅','阅览大厅','档案长厅','誓词深库','西侧书廊','东侧书廊','修复间','抄录侧室','索引室','禁卷库','旧装卸间'],
 'factory':['装卸口','开放工场','传动工场','配电长厅','封存机芯','检修湾','备件湾','废料支厅','值班室','管线间','旧锅炉间'],
 'foundry':['卸煤入口','炉前大工场','铸模横厅','冷却廊','核心炉室','煤料库','炉具间','出渣廊','浇铸侧湾','检修台','封存料库'],
 'cistern':['检修入口','西侧栈廊','东侧栈廊','中央过桥','深层闸厅','进水井','排水井','旧机房','阀门侧湾','值守间','水位刻度廊'],
 'pumphouse':['泵房入口','主泵厅','联轴器横厅','压力井廊','封存闸室','管线侧室','排水工位','旧动力室','备用泵湾','工具库','滤网支厅'],
 'tower':['塔基门厅','西环廊','北环廊','东环廊','上行折廊','仪器露台','值守龛','旧绞盘间','透光壁龛','封存灯室'],
 'observatory':['观测门厅','西观测弧','北观测弧','东观测弧','星仪平台','月刻侧厅','镜组室','星图支厅','测绘廊','旧观测露台','封存天球室','断轨支廊'],
 'mausoleum':['祭坛门廊','霜骨环廊西','霜骨环廊北','霜骨环廊东','誓约祭座','冰封陪葬室','祭仪侧洞','合葬侧殿','旧守墓室','霜骨库'],
 'garden':['温室入口','偏移种植畦','中央育种园','枯藤环路','深层花房','育苗侧湾','施肥间','旧修剪棚','失控根室','水罐工位','封存种库','塌顶试验畦'],
 'theatre':['检票门厅','下层看台','上层看台','横向观众通道','主舞台','侧台左','侧台右','后场走廊','更衣间','布景库','乐池侧廊','封存后台'],
 'exhibition':['藏馆门厅','主展廊','椭圆展厅','斜向展廊','封存展库','面具壁龛','修复支厅','试装室','旧陈列侧厅','空橱回廊','藏品后室'],
 'shipyard':['船坞入口','西装卸长堤','东检修长堤','横向龙骨桥','闸机深厅','木工棚','绳具棚','造船支坞','旧船长室','货物露台','工具支坞','封存绞盘房'],
 'reliquary':['净礼门厅','斜轴前殿','封印十字厅','圣物内环','终仪圣座','守经侧龛','戒律侧厅','修复间','禁忌侧殿','残卷库','封存小圣室','弃置供品廊'],
}

def ring(cx,cy,w,h,n=32,irregular=False,seed=0):
 rng=random.Random(seed)
 return Polygon([(cx+math.cos(t*math.tau/n)*w/2*(rng.uniform(.87,1.08) if irregular else 1),cy+math.sin(t*math.tau/n)*h/2*(rng.uniform(.87,1.08) if irregular else 1)) for t in range(n)])

def authored(family,variant):
 """Fixed room programmes and paths, in centimetres. No common 3x5 lattice."""
 rooms=[]; paths=[]; extras=[]; holes=[]
 def room(x,y,w,h,shape='rect'):
  poly=box(x-w/2,y-h/2,x+w/2,y+h/2) if shape=='rect' else ring(x,y,w,h,8 if shape=='oct' else 28,shape=='rock',int(x+y+variant*47))
  rooms.append([x,y,w,h,shape,poly]); return len(rooms)-1
 def link(a,b,width=650,bend=None):
  pts=[rooms[a][:2]]+([bend] if bend else [])+[rooms[b][:2]]
  paths.append((a,b,pts,width))
 if family=='catacomb':
  extent=[9200,12600]; spawn=[4550,320]
  for y in [1150,3300,5600,7950,11350]: room(4550,y,1050 if y<11000 else 2450,1250 if y<11000 else 1800,'oct' if y==11350 else 'rect')
  for i in range(4): link(i,i+1,760)
  for j,(x,y) in enumerate([(1700,2850),(7300,3900),(1350,5300),(7200,6500),(1600,8500),(7350,9450),(2000,11400),(7800,11350)]):
   idx=room(x,y,2350 if j%2==0 else 1550,1000 if j%2==0 else 1750,'rect' if j%3 else 'oct')
   link(min(3,1+j//2),idx,420 if j%2 else 560,(4550,y))
  link(8,10,430,(7850,8200)); link(9,11,440,(1750,9900))
 elif family=='grotto':
  extent=[11600,11800]; spawn=[4700,320]
  for x,y,w,h in [(4700,1100,1900,1550),(3250,2900,2000,2300),(6700,2850,3250,1500),(5400,5550,4400,3100),(9000,5000,2300,2500),(5400,9900,3400,2550),(2200,7200,1900,2100),(8600,7700,2700,1700),(1500,4400,1650,1650),(2400,10200,2200,1300),(9200,10400,2900,1400),(7500,9300,1400,1550)]: room(x,y,w,h,'rock')
  for u,v in [(0,1),(0,2),(1,3),(2,3),(3,4),(3,6),(6,9),(1,8),(4,7),(7,11),(11,5),(3,5),(7,10)]:
   p,q=rooms[u],rooms[v]; link(u,v,540 if (u+v)%2 else 780,((p[0]+q[0])/2+(-210 if u%2 else 270),(p[1]+q[1])/2))
 elif family=='basilica':
  extent=[10600,12300]; spawn=[5300,320]
  for args in [(5300,1100,1650,1650),(5300,3600,2600,3900),(5300,6900,2800,3100),(5300,7200,8400,1900),(5300,10800,2850,2100),(1900,7200,2100,2300),(8700,7200,1900,2500),(2400,3100,1500,1950),(8050,4000,1600,2600),(5300,9950,5600,850),(8350,11000,1500,1650)]: room(*args,'oct' if args[1]>10500 else 'rect')
  for u,v in [(0,1),(1,2),(2,3),(2,4),(3,5),(3,6),(1,7),(1,8),(4,9),(9,10),(8,6),(7,5)]: link(u,v,620)
 elif family=='cloister':
  extent=[10200,11200]; spawn=[5100,320]
  for args in [(5100,1100,2000,1400),(2350,4900,900,6500),(7850,4900,950,6500),(5100,8150,6300,1000),(5100,10000,2450,1850),(3700,3200,2200,1000),(1250,2900,1650,2050),(9000,5900,1500,2800),(3500,9850,1900,1350),(7450,9850,2200,1650),(1350,7800,1800,2100)]: room(*args)
  for u,v in [(0,1),(0,2),(1,3),(2,3),(3,4),(1,5),(1,6),(2,7),(4,8),(4,9),(1,10)]: link(u,v,700,(rooms[u][0],rooms[v][1]))
  # The courtyard is planted earth below the cloister, not a room tiled solid.
 elif family=='castle':
  extent=[12400,12200]; spawn=[6200,320]
  for args in [(6200,1000,1850,1600),(6200,3900,6300,4100),(1800,4100,2200,2850),(10400,4800,2600,3900),(6200,7750,4200,2300),(6200,10800,3000,2150),(1800,7900,1950,3000),(10000,9500,2800,3400),(3250,6200,1200,4700),(10000,1550,1750,1900),(3650,10950,1550,1600),(1350,10500,1500,2100)]: room(*args,'oct' if args[1]==1550 else 'rect')
  for u,v in [(0,1),(1,2),(1,3),(1,4),(4,5),(2,6),(6,4),(3,7),(4,7),(2,8),(3,9),(5,10),(6,11)]: link(u,v,750)
 elif family=='archive':
  extent=[10800,10400]; spawn=[4300,320]
  for args in [(4300,1150,1800,1700),(4300,3550,4700,3000),(4300,6600,3200,2950),(4300,9400,3600,1500),(1600,3650,1050,3800),(8000,3900,3000,1550),(1200,7400,1500,2200),(8250,6800,2050,2200),(7200,9650,1700,1100),(9500,2000,1600,1550),(1750,9600,1600,1100)]: room(*args,'oct' if args[1]==9400 else 'rect')
  for u,v in [(0,1),(1,2),(2,3),(1,4),(1,5),(4,6),(5,7),(7,8),(5,9),(6,10),(7,3)]: link(u,v,650)
 elif family in ['factory','foundry','pumphouse']:
  extent=[14600,9800]; spawn=[1850,320]
  for args in [(1850,1150,1900,1700),(4300,3550,5200,3650),(9950,3550,5650,4000),(11900,7050,4100,2350),(6400,8200,3800,2050),(1700,7200,2350,2550),(7500,1150,1650,1200),(13050,1400,1750,1300),(4000,8900,1300,1250),(12900,8900,2250,1400),(9300,8750,1300,1450)]: room(*args)
  for u,v in [(0,1),(1,2),(2,3),(3,4),(4,5),(1,5),(1,6),(2,7),(4,8),(3,9),(3,10)]: link(u,v,1000 if v<5 else 650)
  # Process trenches interrupt the open halls, with circulation on both sides.
  holes=[box(3500,2350,3900,4050),box(9100,2350,9500,4400)]
  if family=='foundry': holes.append(box(10800,3050,12100,3750))
  if family=='pumphouse': holes=[box(3450,2600,4650,3850),ring(10300,3500,1450,1450,16)]
 elif family in ['cistern','shipyard']:
  extent=[11800,14200]; spawn=[5900,320]
  for args in [(5900,1100,1950,1650),(3100,6600,1450,8600),(8700,6600,1500,8600),(5900,6100,6900,850),(5900,12600,4300,2400),(1450,3350,1850,2200),(10100,3550,1800,2450),(1250,8850,1800,3700),(10200,9300,1800,3000),(3600,12550,1800,2150),(8300,12600,2000,2400),(10500,12200,1450,2050)]: room(*args)
  for u,v in [(0,1),(0,2),(1,3),(2,3),(1,4),(2,4),(1,5),(2,6),(1,7),(2,8),(4,9),(4,10),(10,11)]: link(u,v,760,(rooms[u][0],rooms[v][1]))
  # The long central basin is split by a real walkable cross bridge.
  extras=[box(2450,1600,9400,2150),box(2450,10800,9400,11350)]
 elif family in ['tower','observatory','mausoleum']:
  extent=[11800,10800]; spawn=[5850,320]
  coords=[(5850,1150,1900,1400),(2300,4300,2200,2400),(5350,8350,3400,1800),(9400,4850,2400,2600),(7900,9400,2450,1750),(1150,2200,1400,1450),(1050,7000,1400,1800),(2750,9550,2000,1200),(10500,7600,1550,1600),(9850,2050,1750,1750)]
  if family=='observatory': coords +=[(5450,10200,2350,950),(8350,3000,1550,1350)]
  for args in coords: room(*args,'oct' if family!='observatory' else 'ellipse')
  # Central drum and an annular gallery: the principal space is circulation.
  outer=ring(5850,5150,8600,6900,8 if family=='tower' else 48)
  inner=ring(5850,5150,5400,3700,8 if family=='tower' else 40)
  extras=[outer]; holes=[inner]
  for u,v in [(0,1),(1,2),(2,3),(3,0),(2,4),(1,5),(1,6),(2,7),(3,8),(3,9)]:
   # Ring arcs are already continuous. Never cut a straight path through core.
   if u<4 and v<4: paths.append((u,v,[rooms[u][:2],rooms[v][:2]],0))
   else: link(u,v,560)
  if family=='observatory': link(2,10,650); link(3,11,500)
 elif family=='garden':
  extent=[13400,11500]; spawn=[4350,320]
  for args in [(4350,1150,1900,1550),(3000,3400,3850,2200),(6500,5650,5400,4000),(10400,7350,3800,2550),(6900,10000,4200,2350),(1050,5150,1700,1900),(2250,8350,3000,2300),(7950,2050,3000,1950),(11300,4400,2600,1650),(11050,10300,1900,1600),(4400,10400,1500,1450),(1000,9650,1400,1950)]: room(*args,'ellipse')
  for u,v in [(0,1),(1,2),(2,3),(3,4),(4,2),(1,5),(2,6),(0,7),(7,8),(8,3),(3,9),(4,10),(6,11),(6,4)]: link(u,v,820,(rooms[u][0],rooms[v][1]))
  holes=[ring(6350,5200,1100,1550,12),ring(7350,6100,1000,1100,12)]
 elif family=='theatre':
  extent=[13400,11300]; spawn=[6500,320]
  for args in [(6500,1100,2600,1600),(6500,3200,3300,2500),(6500,5100,7100,2550),(6500,6450,9600,850),(6500,8150,5800,2600),(2300,8200,2550,2700),(10900,8200,2200,3000),(6500,10400,8100,900),(1950,10400,1950,1200),(11300,10400,2200,1200),(1800,5900,1900,1700),(11300,4100,2200,2000)]: room(*args)
  extras=[Polygon([(4800,1600),(8200,1600),(11600,6900),(1400,6900)])]
  for u,v in [(0,1),(1,2),(2,3),(3,4),(4,5),(4,6),(5,7),(6,7),(7,8),(7,9),(3,10),(2,11)]: link(u,v,650)
 elif family=='exhibition':
  extent=[14500,10000]; spawn=[1550,320]
  for args in [(1550,1250,1700,1950),(4800,2200,4400,1600),(8000,4850,4450,3200),(4250,7600,2900,1650),(11500,8300,3900,2400),(11800,2400,3000,1950),(1600,4400,2050,1500),(1350,8000,1800,2450),(10200,6500,2400,1450),(12300,5050,2100,1950),(8200,8950,2000,1050)]: room(*args,'ellipse' if args[0]==8000 else 'oct')
  for u,v in [(0,1),(1,2),(2,3),(2,4),(1,5),(0,6),(6,7),(7,3),(4,8),(5,9),(9,4),(3,10)]: link(u,v,740)
 elif family=='reliquary':
  extent=[12600,12500]; spawn=[4700,320]
  for args in [(4700,1100,1900,1700),(3500,3350,3300,2350),(6300,5800,6600,1950),(8150,8700,4000,3700),(9200,11350,3250,1600),(1400,2350,1400,1550),(1350,5500,1900,2450),(2750,8300,2100,2500),(11400,6100,1800,2650),(5850,10900,1700,1950),(10650,3100,1950,2300),(2700,11200,1600,1650)]: room(*args,'oct')
  for u,v in [(0,1),(1,2),(2,3),(3,4),(1,5),(1,6),(6,7),(7,3),(2,8),(3,9),(8,10),(7,11)]: link(u,v,620)
  holes=[ring(8150,8600,1750,1450,8)]
 else: raise ValueError(family)
 # Sibling programmes get architectural changes, not translated copies.
 act=variant//10
 if family=='basilica' and act==2:
  rooms[1][-1]=ring(5300,3600,5300,3900,24)
  rooms[3][-1]=box(2300,6250,8300,7700)
  extras.append(box(2800,1800,7800,2400))
 elif family=='basilica' and act==6:
  rooms[3][-1]=ring(5300,7200,9200,2850,12)
  holes.append(box(4880,2950,5720,4300))
 elif family=='archive' and act==4:
  # Mansion rooms subdivide the reading hall; the central cross stays passable.
  holes +=[box(2800,2350,3550,3000),box(5100,2350,5850,3000),box(2800,4050,3550,4700),box(5100,4050,5850,4700)]
  rooms[5][-1]=ring(8000,3900,3250,2100,8)
 elif family=='archive' and act==6:
  rooms[1][-1]=ring(4300,3550,5100,3400,8)
  extras.append(box(6250,7550,8700,8100))
 elif family=='castle' and act==6:
  # Underground city: a divided vault courtyard with crossed upper passages.
  rooms[1][-1]=ring(6200,3900,5000,4700,8)
  holes +=[box(4700,2550,5350,3700),box(7150,4500,7950,5700)]
 elif family=='cloister' and act==4:
  rooms[5][-1]=ring(3700,3200,2850,1850,28)
  link(5,2,520,(6200,3200))
 elif family=='cloister' and act==6:
  rooms[1][-1]=box(1875,2100,2825,9100)
  extras.append(box(3300,7400,6900,7850))
 elif family=='catacomb' and act==4:
  for i in [5,7,9,11]:
   x,y,w,h,_,_=rooms[i]; rooms[i][-1]=ring(x,y,w*1.1,h*1.2,20)
  link(7,9,500,(2200,7200))
 elif family=='tower' and act==5:
  extras=[ring(5850,5150,9250,7350,40)]; holes=[ring(5850,5150,5700,4150,32)]
  rooms[4][-1]=box(6200,8400,9650,10300)
 elif family=='observatory' and act==6:
  holes=[ring(5850,5150,4750,3550,12)]
  extras.append(box(3050,8600,7700,9150))
 elif family=='cistern' and act==5:
  rooms[7][-1]=ring(1250,8850,2000,4100,12)
  link(7,9,650,(3100,9800))
 # A deliberate extension changes the programme/branch count for sibling maps.
 if variant%2:
  base=2 if family in ['archive','basilica','castle'] else len(rooms)-2
  x,y,w,h,shape,_=rooms[base]
  at=(min(extent[0]-950,x+1600),min(extent[1]-900,y+900))
  ix=room(*at,1300,1250,'oct'); link(base,ix,520)
 return extent,spawn,rooms,paths,extras,holes

def pts(r): return [[round(x,2),round(y,2)] for x,y in list(r.coords)[:-1]]

def make(key,old):
 a,s=map(int,key.split(':')); family,title=ASSIGN[key]; rng=random.Random(a*713+s*67)
 extent,spawn,rooms,paths,extras,holes=authored(family,a*10+s)
 shapes=[r[-1] for r in rooms]+extras
 for u,v,p,w in paths:
  if w: shapes.append(LineString(p).buffer(w/2,cap_style=2,join_style=1 if family in ['grotto','garden','exhibition'] else 2))
 shapes.append(box(spawn[0]-300,0,spawn[0]+300,rooms[0][1]))
 ground=unary_union(shapes).difference(unary_union(holes)).buffer(0)
 if ground.geom_type!='Polygon': raise RuntimeError((key,'disconnected',ground.geom_type))
 # Remove sliver loops too small to serve as spatial divisions.
 ground=Polygon(ground.exterior,[r for r in ground.interiors if Polygon(r).area>70000])
 d={'name':old['name'],'identity':title,'layout_family':family,'layout_revision':2,'extent':extent,'boundary':pts(ground.exterior),'voids':[pts(r) for r in ground.interiors],
    'chambers':[],'edges':[[u,v] for u,v,_,_ in paths],'trails':[p for _,_,p,w in paths if w>0], 'spawn':spawn,
    'waypoint':rooms[1][:2], 'anchors':[rooms[2][:2],rooms[3][:2],rooms[4][:2]], 'side_anchors':[rooms[i][:2] for i in [-1,-2,-3]],
    'chests':[], 'natural':family=='grotto', 'area_m2':round(ground.area/10000,1),'dressing':[],'encounters':[],'steps':[],
    'sky_open':family in ['garden','shipyard'] or (family=='castle' and a==1), 'void_surface':'water' if family in ['shipyard','cistern','pumphouse'] else 'earth' if family in ['garden','cloister'] else 'rock' if family=='grotto' else 'pit',
    'grade_axis':'x' if family in ['factory','foundry','pumphouse','exhibition'] else 'y'}
 # No four universal stair bands. Architecture follows its actual sequence.
 profiles={
  'catacomb':[(1700,2250,0,-85),(10100,10700,-85,-205)], 'grotto':[(1700,2900,0,-80),(6700,8150,-80,-155)],
  'basilica':[(5800,6500,0,105),(9650,10350,105,220)], 'cloister':[(8950,9600,0,90)],
  'castle':[(6400,7050,0,110),(9500,10250,110,240)], 'archive':[(8150,8750,0,80)],
  'factory':[(6150,6750,0,-95),(10800,11450,-95,30)], 'foundry':[(5750,6450,0,-120),(11600,12300,-120,20)],
  'pumphouse':[(6050,6850,0,-145)], 'cistern':[(1800,2450,0,-95),(11700,12350,-95,50)],
  'shipyard':[(1800,2500,0,-140),(11700,12400,-140,25)], 'tower':[(1950,2650,0,100),(7100,7850,100,220)],
  'observatory':[(7800,8650,0,135)], 'mausoleum':[(2050,2750,0,-105)], 'garden':[(3800,4700,0,-50),(8900,9800,-50,40)],
  'theatre':[(6450,7150,0,165)], 'exhibition':[(6100,6850,0,110)], 'reliquary':[(3800,4450,0,90),(10350,11050,90,210)],
 }
 for start,end,h0,h1 in profiles[family]:
  # Sibling maps alter pacing as well as their spatial programme.
  shift=50*((s%3)-1); start+=shift; end+=shift
  d.setdefault('grade_bands',[]).append({'start':start,'end':end,'from':h0,'to':h1,'kind':'ramp' if family in ['grotto','garden','shipyard'] else 'stairs'})
 labels=LABELS[family]
 safe=ground.buffer(-115)
 def safe_at(x,y):
  point=Point(x,y)
  if not safe.covers(point):
   for step in [150,300,500,700,950]:
    for angle in range(16):
     q=Point(x+step*math.cos(angle*math.tau/16),y+step*math.sin(angle*math.tau/16))
     if safe.covers(q): return [round(q.x,2),round(q.y,2)]
   raise RuntimeError((key,'no safe gameplay point',x,y))
  return [x,y]
 for i,r in enumerate(rooms):
  visit=safe_at(*r[:2]); d['chambers'].append({'id':f'space-{i}','index':i,'name':labels[i] if i<len(labels) else '独立封存侧厅','center':visit,'visit':visit,'boundary':pts(r[-1].exterior),'shape':r[4]})
 for k in ['anchors','side_anchors']: d[k]=[safe_at(*p) for p in d[k]]
 d['waypoint']=safe_at(*d['waypoint'])
 for i in [-1,-2,-3,5]: d['chests'].append(safe_at(rooms[i][0]+100,rooms[i][1]+170))
 protected=[Point(p).buffer(220) for p in d['anchors']+d['side_anchors']+d['chests']+[d['waypoint'],spawn]+[c['visit'] for c in d['chambers']]]
 used=[]
 def place(model,x,y,scale=.8,fp=None,angle=0,height=0,suffix=None):
  b=box(x-(fp[0] if fp else 50)/2,y-(fp[1] if fp else 50)/2,x+(fp[0] if fp else 50)/2,y+(fp[1] if fp else 50)/2)
  if not safe.covers(b) or any(b.intersects(p) for p in protected) or any(b.buffer(32).intersects(p) for p in used): return False
  used.append(b)
  d['dressing'].append({'id':f'd{a}s{s}_{suffix or len(d["dressing"])}','model':model,'at':[round(x,2),round(y,2)],'scale':[scale]*3,'angle':angle,'height':height,'reveal':True,'occlusion_height':320*scale,**({'footprint':fp} if fp else {})})
  return True
 # Functional compositions per typology. Open facilities use bays and process
 # rows; archives retain wide reading aisles; tombs use asymmetric burial rows.
 for i,r in enumerate(rooms):
  x,y,w,h,shape,poly=r; minx,miny,maxx,maxy=poly.bounds
  if family in ['archive','exhibition']:
   for dx in range(-int(w/2)+280,int(w/2)-200,470):
    for dy in [-h*.32,h*.32]: place('bookshelf' if a==1 else f'a{a}_detail',x+dx,y+dy,.85,[160,85])
   for dx in [-w*.27,w*.27]: place('archive_lectern' if a==1 else 'dungeon_workbench',x+dx,y+120,.80,[150,100])
  elif family in ['catacomb','mausoleum','reliquary']:
   for dx in [-w*.33,w*.31]:
    for dy in range(-int(h/2)+260,int(h/2)-220,360): place('dungeon_ossuary',x+dx,y+dy,.85,[120,150],math.pi/2 if h<w else 0)
   place(f'd{a}_niche',x+w*.3,y-h*.34,.95,[155,115])
  elif family=='theatre':
   if i in [1,2,3]:
    for dy in range(-int(h*.35),int(h*.35),390):
     for dx in range(-int(w*.35),int(w*.35),430): place('wood_stool',x+dx,y+dy,1.2,[70,70])
   elif i>4:
    for dx in [-w*.32,w*.32]: place(f'a{a}_detail',x+dx,y,.95,[190,140])
  elif family in ['factory','foundry','pumphouse','shipyard','cistern']:
   for dx in range(-int(w/2)+320,int(w/2)-200,660):
    for dy in [-h*.33,h*.34]:
     model='dungeon_workbench' if (i+int(dx))%3 else 'dungeon_storage'
     place(model,x+dx,y+dy,.95,[190,110],math.pi/2 if family=='shipyard' else 0)
   for dy in range(-int(h/2)+310,int(h/2)-260,740): place(f'a{a}_prop',x+w*.34,y+dy,.85,[180,150])
  elif family in ['garden','grotto']:
   for j in range(11):
    theta=j*math.tau/11+.35; xx=x+math.cos(theta)*w*.32; yy=y+math.sin(theta)*h*.32
    place('strata_outcrop' if a==1 else f'a{a}_rock' if family=='grotto' else 'dungeon_roots',xx,yy,.65,[145,130] if family=='grotto' else None,rng.uniform(-math.pi,math.pi))
   if family=='garden':
    for dx in [-w*.22,w*.22]:
     for dy in [-h*.24,h*.23]: place(f'a{a}_tree',x+dx,y+dy,.60,None)
   elif i in [0,2,6]: place('mine_support',x-w*.25,y,.9,[130,95])
  else:
   # Long aisles get structural rhythms; courts have grouped edge activity.
   for dy in range(-int(h/2)+330,int(h/2)-290,680):
    for dx in [-w*.35,w*.35]: place(f'd{a}_pier',x+dx,y+dy,.9,[100,100])
   for dx in [-w*.3,w*.31]:
    place('dungeon_storage' if family=='castle' else f'd{a}_niche',x+dx,y+h*.3,.8,[130,105])
  # Debris appears in edge clusters, never identical three-prop room centres.
  for j in range(5 if i%3 else 8):
   theta=rng.uniform(0,math.tau)
   place('dungeon_roots' if family=='garden' else 'dungeon_rubble',x+math.cos(theta)*w*.38,y+math.sin(theta)*h*.37,rng.uniform(.42,.85),None,theta)
  place('dungeon_chain_lamp',x-w*.28,y-h*.30,.8,None)
  # Space-dependent combat distribution keeps service alcoves smaller.
  for j in range(5 if w*h>4e6 else 3):
   ex,ey=safe_at(x+(j-2)*105,y+(180 if j%2 else -160))
   if not any(Point(ex,ey).distance(u)<85 for u in used): d['encounters'].append({'id':f'pack-{i}-{j}','at':[ex,ey],'room':i})
 # Dedicated focal object offset from the actual travel destination.
 focal=1 if family=='castle' else 4 if family in ['theatre','basilica','reliquary'] else 2
 x,y,w,h,_,_=rooms[focal]
 model={1:'castle_fountain' if family=='castle' else 'mine_support' if family=='grotto' else 'archive_lectern',2:'a2_archive' if family=='archive' else 'a2_hero' if family=='foundry' else 'a2_secondary',3:'a3_secondary' if family=='mausoleum' else 'a3_hero',4:'a4_doll_station' if s==2 else 'a4_hero' if family=='garden' else 'a4_secondary',5:'a5_hero' if family=='shipyard' else 'a5_beacon' if family=='tower' else 'a5_secondary',6:'a6_scriptorium' if family=='archive' else 'a6_hero'}[a]
 footprint=[290,610] if model=='a5_hero' else [440,365] if model=='a4_hero' else [345,345]
 for dx,dy in [(w*.24,0),(-w*.24,0),(0,h*.28)]:
  if place(model,x+dx,y+dy,1.1,footprint,suffix='chamber_feature'): break
 if family=='castle' and a==1:
  x,y=rooms[5][:2]; place('castle_throne',x,y-580,1.2,[210,165],suffix='lord_seat')
 # Stairs are clipped to physical ground and may run east/west as well as north.
 for band in d['grade_bands']:
  if band['kind']!='stairs': continue
  for n in range(band['start'],band['end'],50):
   line=LineString([(n,0),(n,extent[1])]) if d['grade_axis']=='x' else LineString([(0,n),(extent[0],n)])
   cut=ground.intersection(line); segments=[cut] if cut.geom_type=='LineString' else list(getattr(cut,'geoms',[]))
   for seg in segments:
    if seg.geom_type!='LineString': continue
    p,q=list(seg.coords)[0],list(seg.coords)[-1]
    d['steps'].append({'a':list(p),'b':list(q)})
 # Boundary segments no longer automatically become enclosing high walls.
 def style_ring(raw,inner=False):
  styles=[]
  for i,p in enumerate(raw):
   q=raw[(i+1)%len(raw)]; mx,my=(p[0]+q[0])/2,(p[1]+q[1])/2
   if family=='grotto': kind='rock'
   elif family in ['shipyard','cistern','pumphouse']: kind='rail' if inner or family=='shipyard' else 'wall'
   elif family=='garden': kind='roots' if inner else 'broken' if i%5==0 else 'rail' if i%3==0 else 'none'
   elif family=='cloister': kind='colonnade' if inner else 'wall'
   elif family=='castle': kind='broken' if my<6400 and a==1 else 'wall'
   elif family in ['factory','foundry']: kind='rail' if inner else 'broken' if my<5200 and i%3==0 else 'wall'
   elif family=='observatory': kind='rail' if inner else 'colonnade' if i%3==0 else 'broken'
   elif family=='tower': kind='wall' if inner else 'broken'
   else: kind='wall'
   styles.append(kind)
  return styles
 d['edge_styles']=[style_ring(d['boundary'])]+[style_ring(v,True) for v in d['voids']]
 d['wall_fraction']=round(sum(a.distance(Point(d['boundary'][(i+1)%len(d['boundary'])])) for i,p in enumerate(d['boundary']) if d['edge_styles'][0][i]=='wall' for a in [Point(p)])/ground.exterior.length,3)
 d['layout_family']={('archive',4):'estate',('archive',6):'scriptorium',('basilica',2):'tribunal',('castle',6):'necropolis'}.get((family,a),family)
 # Ensure all centres and content targets are physically reachable before export.
 for p in d['anchors']+d['side_anchors']+d['chests']+[d['waypoint'],spawn]:
  if not ground.buffer(-70).covers(Point(p)): raise RuntimeError((key,'unsafe target',p))
 return d

def main():
 data=json.loads(PATH.read_text(encoding='utf8'))
 if data.get('identity_revision'): raise RuntimeError('Identity layouts exist; edit the authored JSON instead of replaying.')
 (ROOT/'build/exploration-before-identities.json').write_text(json.dumps(data,ensure_ascii=False),encoding='utf8')
 for key,old in list(data['dungeons'].items()):
  data['dungeons'][key]=d=make(key,old)
  print(key,d['layout_family'],'spaces',len(d['chambers']),'area',d['area_m2'],'dressing',len(d['dressing']),'walls',d['wall_fraction'])
 data['identity_revision']=2
 PATH.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
 print('AUTHORED_IDENTITIES',len(data['dungeons']))
if __name__=='__main__': main()
