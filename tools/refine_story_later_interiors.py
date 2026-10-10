"""Place actual facilities and wall-side work zones in the authored dungeon data."""
import pathlib,json
ROOT=pathlib.Path(__file__).resolve().parents[1]; p=ROOT/'resources/story-later-acts.json'
data=json.loads(p.read_text(encoding='utf8'))
if data.get('interiors_revision'): raise RuntimeError('Interiors already refined; edit JSON.')
for aa,act in data['acts'].items():
 a=int(aa)
 for ss,d in act['regions'].items():
  s=int(ss)
  if s==0: continue
  old=d['interior_dressing']
  for item in old:
   if item['id'].endswith('_inside_0'):
    item['model']=f'a{a}_secondary' if s==8 else f'a{a}_hero'
    item['at']=[2400,2000 if a==5 else 2200]
    item['scale']=[1.5]*3; item['footprint']=[330,700] if a==5 and s!=8 else [360,340]
  for j,(x,y) in enumerate([(750,1400),(950,1400),(750,2800),(1450,2850),(800,3550),(1100,3500),(3600,1800),(3820,2400),(3650,3300),(2300,4570),(2700,4570)]):
   scale=.65+(j%3)*.1
   model=f'a{a}_'+('secondary' if s==8 and j%3==0 else 'detail' if j%2 else 'prop')
   old.append({'id':f'a{a}s{s}_work_zone{j}','model':model,'at':[x,y],'scale':[scale]*3,'footprint':[110,100], 'reveal':True,'occlusion_height':250})
data['interiors_revision']=1
p.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
