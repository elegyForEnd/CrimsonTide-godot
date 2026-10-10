"""Differentiate opening chapel, abbey and castle functions in the authored plans."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]; path=ROOT/'resources/story-exploration.json'
data=json.loads(path.read_text(encoding='utf8'))
if data.get('opening_functions_revision'): raise RuntimeError('Already refined; edit the JSON.')
names={5:['前廊','执事室','祭器库','告解室','巡礼回廊','侧礼拜堂','修士寝间','传道大厅','钟器室','旧斋堂','静默回廊','纪念侧室','内祭坛','遗物库','废弃庇护间'],6:['西前庭','抄经室','旧布告库','悼念侧殿','修士回廊','侧祈祷堂','安葬通道','长老议事厅','修复室','旧宿舍','唱诗回廊','封存侧殿','深层祭坛','圣器库','坍塌旧斋堂'],9:['门庭','驻军值房','粮秣库','军械间','庭院回廊','书记侧室','禁闭间','宴会长厅','骑士厅','后勤走廊','守卫回廊','议事侧厅','领主厅','封存国库','废弃库房']}
for stage,tags in names.items():
 d=data['dungeons'][f'1:{stage}']
 for room,name in zip(d['chambers'],tags): room['name']=name
 if stage==9:
  for item in d['dressing']:
   if item['model']=='dungeon_ossuary': item['model']='dungeon_storage'; item['footprint']=[140,115]
  d['dressing'].append({'id':'d1s9_lord_seat','model':'castle_throne','at':[4000,10150],'scale':[1.2]*3,'footprint':[210,165],'reveal':True,'occlusion_height':320})
data['opening_functions_revision']=1
path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
print('REFINED_CHAPEL_ABBEY_CASTLE')
