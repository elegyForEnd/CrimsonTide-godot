"""Reserve physical centrepiece clearances and purposeful circulation around them."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]; path=ROOT/'resources/story-exploration.json'
data=json.loads(path.read_text(encoding='utf8'))
if data.get('centres_revision'): raise RuntimeError('Centres already refined; edit JSON.')
for key,d in data['dungeons'].items():
 a,s=map(int,key.split(':')); room=d['chambers'][7]; x,y=room['center']
 model={1:'castle_fountain' if s==9 else 'mine_support' if d['natural'] else 'archive_lectern',2:'a2_archive' if s==4 else 'a2_hero' if s==7 else 'a2_secondary' if s==8 else 'a2_prop',3:'a3_secondary' if s==8 else 'a3_hero',4:'a4_doll_station' if s==2 else 'a4_secondary' if s in [5,8] else 'a4_hero' if s==7 else 'a4_detail',5:'a5_secondary' if s in [4,8] else 'a5_beacon' if s==6 else 'a5_hero',6:'a6_scriptorium' if s==4 else 'a6_prop' if s in [5,8] else 'a6_hero'}[a]
 footprint=[285,600] if model=='a5_hero' else [430,355] if model=='a4_hero' else [340,340] if model in ['a3_hero','castle_fountain'] else [300,220]
 # Remove any prior side placement of this feature and furniture in its clearance.
 removed=[]; kept=[]
 for item in d['dressing']:
  ix,iy=item['at']; fp=item.get('footprint',[0,0])
  previous=abs(ix-x-560)<5 and abs(iy-y-80)<5 and item['model']==model
  overlap=abs(ix-x)<(fp[0]+footprint[0])*.5+35 and abs(iy-y)<(fp[1]+footprint[1])*.5+35
  if previous or (fp and fp!=[0,0] and overlap): removed.append(item['id'])
  else: kept.append(item)
 d['dressing']=kept
 d['removed_dressing_ids']=removed
 d['dressing'].append({'id':f'd{a}s{s}_chamber_feature','model':model,'at':[x,y],'scale':[1.15]*3,'footprint':footprint,'reveal':True,'occlusion_height':440})
 # Room centre is deliberately occupied by the feature; route around it.
 room['visit']=[x,y+550]
 d['encounters']=[e for e in d['encounters'] if not (abs(e['at'][0]-x)<footprint[0]*.5+70 and abs(e['at'][1]-y)<footprint[1]*.5+70)]
data['centres_revision']=1
path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
print('REFINED_THIRTY_CENTRES')
