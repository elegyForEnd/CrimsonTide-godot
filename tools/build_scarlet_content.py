"""Build the approved screenplay; the old narrative lives only in revision archives."""
from pathlib import Path
import json
from scarlet_screenplay_runtime import apply
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'resources/scarlet'
OUT.mkdir(parents=True,exist_ok=True)
CAMPS=['边境客舍','白垩避难所','月晶驿站','蔷薇篱营','月舟码头','旧水门营地']
KEYS=['inquisitor','judge','vein','surgeon','admiral','queen']
LAYOUTS=[['camp','road','town','home','chapel','canal','arena'],
 ['camp','road','town','prison','library','canal','arena'],
 ['camp','road','ravine','mine','ravine','tower','arena'],
 ['camp','garden','workshop','bedroom','prison','archive','theatre'],
 ['camp','dock','wreck','dock','cliff','canal','ship'],
 ['camp','watergate','corridor','garden','workshop','thronehall','throne']]
bosses={
 'inquisitor':dict(name='血烙审判官 · 赫缄',phases=['锁链禁区','解除交接封锁'],hp=1050),
 'judge':dict(name='白面法官',phases=['三庭宣判','亲持刑剑'],hp=1250),
 'vein':dict(name='旧骑士 · 维恩',phases=['旧剑路','重盾反制'],hp=1450),
 'surgeon':dict(name='缀身夫人 · 瑟芮',phases=['局部麻醉','手术偶胸舱'],hp=1650),
 'admiral':dict(name='黑帆提督 · 莫罗',phases=['重锚封路','断链离港'],hp=1850),
 'queen':dict(name='血潮女王',phases=['王剑控制','开侧廊','解除强制认证'],hp=2200),
 'beast':dict(name='霜脊岩兽',phases=['岩甲','落石'],hp=950),
 'warden':dict(name='牢狱看守 · 铁棺',phases=['重盾封路','锁链拖拽'],hp=1400)}
zones={}
for a in range(1,7):
 for s in range(7):
  zones[f'{a}:{s}']=dict(id=f'{a}:{s}',act=a,stage=s,name='',layout=LAYOUTS[a-1][s],
   points=[[800,1320],[1000,1120],[820,920],[990,700],[820,470],[1050,310],[900,220]],
   ambient=['5c6b78','6b6372','5c6d87','70566e','487c85','663746'][a-1])
zones['6:7']={**zones['6:1'],'id':'6:7','stage':7,'layout':'cliff'}
content=apply(dict(title='赤月遗书 · 王冠与空城',acts=[dict(id=i+1,title='',camp=camp,maps=[],boss=KEYS[i]) for i,camp in enumerate(CAMPS)],zones=zones,bosses=bosses))
(OUT/'campaign.json').write_text(json.dumps(content,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
rows=['# 赤月遗书 · 运行内容索引','','正文：完整剧情脚本；运行编排：tools/scarlet_screenplay_runtime.py。结局为接受／拒绝王冠。','','| ID | 任务 | 接取地点 | 可操作节点／演出 |','|---|---|---|---|']
for q in content['quests'].values():
 rows.append(f"| {q['id']} | {q['title']} | {q['intake']['place']} | {' → '.join(n['label'] for n in q['nodes'])} |")
(ROOT/'docs/rpg/SCARLET-CONTENT-INDEX.md').write_text('\n'.join(rows)+'\n',encoding='utf-8')
print(f"Scarlet: {len(content['main_order'])} main, {len(content['quests'])-len(content['main_order'])} side, {len(content['scenes'])} scenes, {sum(len(s['pages']) for s in content['scenes'].values())} pages")
