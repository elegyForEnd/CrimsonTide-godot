"""Match authored centrepieces to each room's actual narrative function."""
import pathlib,json
ROOT=pathlib.Path(__file__).resolve().parents[1]; p=ROOT/'resources/story-later-acts.json'
data=json.loads(p.read_text(encoding='utf8'))
if data.get('room_functions_revision'): raise RuntimeError('Room functions already authored; edit JSON.')
mapping={(2,3):'prop',(2,4):'archive',(3,3):'prop',(4,2):'doll_station',(4,3):'detail',(4,5):'secondary',(4,6):'detail',(5,4):'secondary',(5,6):'beacon',(6,4):'scriptorium',(6,5):'prop'}
for (a,s),kind in mapping.items():
 for item in data['acts'][str(a)]['regions'][str(s)]['interior_dressing']:
  if item['id'].endswith('_inside_0'):
   item['model']=f'a{a}_{kind}'
   if (a,s)==(5,6): item['footprint']=[250,250]
data['room_functions_revision']=1
p.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
