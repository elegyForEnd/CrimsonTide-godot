"""Initial regional vegetation and usage clusters, appended without replacing edits."""
from pathlib import Path
import json,math
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'resources/story-later-acts.json'; data=json.loads(p.read_text(encoding='utf8'))
if data.get('clusters_revision'): raise RuntimeError('Clusters exist, edit the JSON.')
for aa,act in data['acts'].items():
 a=int(aa)
 for ss,d in act['regions'].items():
  s=int(ss)
  if s==0: continue
  for group,(cx,cy) in enumerate([(700,900),(4130,2200),(850,3650)]):
   for i in range(17):
    angle=i*2.399963+(a+s)*.41; radius=90+52*math.sqrt(i)
    x=cx+math.cos(angle)*radius*1.35; y=cy+math.sin(angle)*radius*1.8
    scale=.48+(i%5)*.13; kind='tree' if i%4 else 'rock'
    item={'id':f'a{a}s{s}_cluster{group}_{i}','model':f'a{a}_{kind}','at':[round(x,2),round(y,2)],'scale':[scale]*3,'angle':angle,'reveal':True,'occlusion_height':340*scale}
    if kind=='rock': item['footprint']=[round(115*scale),round(85*scale)]
    d['dressing'].append(item)
  # Different functions for the two optional floors; not the same cave prop.
  if s==8:
   for item in d['interior_dressing']:
    if item['model'].endswith('_hero'): item['model']=f'a{a}_'+('detail' if a in [2,4,5] else 'prop')
data['clusters_revision']=1
p.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
