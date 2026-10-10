"""Review-driven refinements: courtyard activity groups and theatre seating grade."""
from pathlib import Path
import json,sys
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'output/dungeon-tools'))
from shapely.geometry import Polygon,Point,LineString,box
PATH=ROOT/'resources/story-exploration.json'; data=json.loads(PATH.read_text(encoding='utf8'))
if data.get('identity_composition_revision'): raise RuntimeError('Already refined; edit JSON.')
d=data['dungeons']['1:9']; x,y=d['chambers'][1]['center']
kept=[]; ordinal=0
for item in d['dressing']:
 if item['model']=='d1_pier' and abs(item['at'][0]-x)<2400 and abs(item['at'][1]-y)<1900:
  ordinal+=1
  if ordinal%2: continue
 kept.append(item)
d['dressing']=kept
ground=Polygon(d['boundary'],d['voids'])
protected=[Point(p).buffer(200) for p in d['anchors']+d['side_anchors']+d['chests']+[d['waypoint']]+[r['visit'] for r in d['chambers']]]
for j,(model,at,fp,scale) in enumerate([
 ('canopy',[3670,4400],[290,230],1.1),('watch_map_table',[3670,4010],[160,110],1.1),
 ('handcart',[3930,4740],[165,210],1.15),('cargo',[4200,4700],[140,140],1.1),
 ('tool_rack',[3550,3780],[160,70],1.1),('wood_stool',[3880,4150],[75,75],1.3),
 ('castle_banner',[8720,3300],[80,80],1.3),('castle_banner',[3500,2700],[80,80],1.3),
]):
 footprint=box(at[0]-fp[0]/2,at[1]-fp[1]/2,at[0]+fp[0]/2,at[1]+fp[1]/2)
 if not ground.buffer(-75).covers(footprint) or any(footprint.intersects(p) for p in protected): raise RuntimeError(('unsafe courtyard group',model))
 if any(abs(at[0]-i['at'][0])<(fp[0]+i.get('footprint',[50,50])[0])/2+25 and abs(at[1]-i['at'][1])<(fp[1]+i.get('footprint',[50,50])[1])/2+25 for i in d['dressing']): continue
 d['dressing'].append({'id':f'd1s9_court_activity_{j}','model':model,'at':at,'footprint':fp,'scale':[scale]*3,'reveal':True,'occlusion_height':300})
d=data['dungeons']['4:6'];d['grade_bands']=[{'start':1750,'end':6200,'from':0,'to':100,'kind':'ramp'},{'start':6450,'end':7150,'from':100,'to':265,'kind':'stairs'}]
ground=Polygon(d['boundary'],d['voids']);d['steps']=[]
for y in range(6450,7150,50):
 cut=ground.intersection(LineString([(0,y),(d['extent'][0],y)]))
 for seg in [cut] if cut.geom_type=='LineString' else cut.geoms:
  if seg.geom_type=='LineString': d['steps'].append({'a':list(seg.coords[0]),'b':list(seg.coords[-1])})
data['identity_composition_revision']=1
PATH.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8'); print('REVIEW_COMPOSITIONS_REFINED')
