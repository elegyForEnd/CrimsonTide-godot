"""Readable production design for the enemy catalog actually used by the game."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
d=json.loads((ROOT/'resources/scarlet/enemies.json').read_text(encoding='utf-8'))
c=json.loads((ROOT/'resources/scarlet/campaign.json').read_text(encoding='utf-8'))
rows=['# 赤月遗书 · RPG敌人与首领制作','',
      '8种小怪、6位章节首领、2位可选首领已经接入源码版。每个敌人均有待机、蓄力、出手3个独立绘制姿态，共48个姿态；使用原生尺寸透明图片，运行时增加呼吸、移步、出手位移与受击震动。34个Boss招式和13个小怪招式使用实际判定与预警。',
      '', '[造型总览](../../assets/story/rpg-enemies-v1/contact-sheet.png) · [48姿态总览](../../assets/story/rpg-enemies-v1/all-poses.png) · [原图画廊](../../assets/story/rpg-enemies-v1/gallery.html)',
      '', '## 小怪如何服务剧情与战斗','', '| 敌人 | 战斗职责 | 应对 |', '|---|---|---|']
for key,m in d['minions'].items(): rows.append(f"| {m['name']} | {m['role']} | {m['counter']} |")
for key,m in d['minions'].items():
    rows+=['',f"### {m['name']}",'',m['lore'],'',
           f"相对生命系数 {m['hp']}，移动速度 {m['speed']}，偏好距离 {m['distance']}，基础攻击间隔 {m['cooldown']} 秒。生命以章节基础值 80＋章数×16 计算，距离和速度再按当前地图比例换算。"]
    for move in m['skills']:
        delays='／'.join(str(s['delay']) for s in move['strikes'])
        rows.append(f"- **{move['name']}**：{move['hint']}。预警 {delays} 秒；最后判定后收招 {move['recovery']} 秒；伤害类型 `{move['element']}`。")
rows+=['','## 章节首领与可选首领','',
       '所有主线首领均使用与现有剧情立绘一致的新战斗造型，身份由Boss自身ID决定，不再按当前章节借用旧怪物。人类敌人的击退不等于剧情处决；女王仍由剧情控制三个战斗阶段及两条结局。','',
       '| Boss | 实际地点 | 阶段机制 |','|---|---|---|']
mechanics={
 'inquisitor':'第一阶段拆两座弩台；拆除会取消该弩台已排队的射线。第二阶段近身追斩。',
 'judge':'先解三庭实体隔断，不能靠伤害跳过；后半亲持刑剑。',
 'vein':'第一阶段读旧剑路；第二阶段引到断柱，再按E反制重盾。',
 'surgeon':'只关闭示范厅的两个局部阀门；第二阶段解除手术偶承重索，不切断病房保障。',
 'admiral':'先避重锚和回收链环；第二阶段锁舰舵，阻止断链离港。',
 'queen':'王剑控制→打开侧廊→救回工区六人→解除强制认证。雪璃稳近场、鸦羽解外扣、绯月解除护架；回答之前不毁核心、不转交王冠。',
 'beast':'S03可选清理兽道，岩甲冲撞→霜脊落石。绕开挑战也能继续接回旅人。',
 'warden':'S06可选制服额外拘留室看守，盾击拖链→扫链重击。不会替主线清空未知工区或提供双结局必需钥匙。'}
for key,b in d['bosses'].items(): rows.append(f"| {c['bosses'][key]['name']} | {b['arena']} | {mechanics[key]} |")
for key,b in d['bosses'].items():
    rows+=['',f"### {c['bosses'][key]['name']}",'',b['identity'],'',mechanics[key],'',
           f"基础阶段生命 {c['bosses'][key]['hp']}，每阶段另加基础值的12%；强制机关未解除时保留原有减伤与血量底线。以下每个招式都有真实预警、固定落点和收招，不以台词代替判定。"]
    for i,moves in enumerate(b['phases']):
        rows+=['',f"**阶段{i+1}：{c['bosses'][key]['phases'][i]}**",'']
        for move in moves:
            shapes='、'.join({'line':'直线','cone':'扇区','circle':'落点圆','ring':'带安全内圈的圆环','rect':'走道压区'}[s['shape']] for s in move['strikes'])
            delays='／'.join(str(s['delay']) for s in move['strikes'])
            rows.append(f"- **{move['name']}**：{shapes}；预警{delays}秒。{move['hint']}。收招{move['recovery']}秒；伤害类型 `{move['element']}`。")
rows+=['','## 在哪里开打','',
       '主线战斗继续在原任务的战斗、路线和护送步骤触发；六位章末首领仍由对应主线节点开启。普通战斗按章节混编，序章先教猎犬扑击和役骸重击；护送民船段优先使用黑帆登船队。','',
       '另外新增六处可选现场遭遇，地图显示可选战斗标记，靠近按E开始；未主动交互不会开战。每处只清理一次，结果和战利品凭据随存档保留，胜利不推进主线步骤。途中退出会从该场开头安全恢复，不复制掉落。','',
       '| 地区 | 敌人组合 |','|---|---|']
for zone,types in {'1:2':['tide_hound','crystal_husk','tide_hound'],'2:4':['royal_pikeman','archive_scribe','royal_arbalist'],'3:3':['crystal_stalker','crystal_husk','crystal_stalker'],'4:2':['suture_puppet','suture_puppet','archive_scribe'],'5:3':['anchor_raider','royal_arbalist','anchor_raider'],'6:3':['royal_pikeman','archive_scribe','suture_puppet']}.items():
    rows.append(f"| {zone} · {c['zones'][zone]['name']} | {'＋'.join(d['minions'][t]['name'] for t in types)} |")
rows+=['','## 实际表现与操作','',
       '- **B 遭遇手册**：自动记录已见敌人；可查看造型、背景、招式和应对，打开时暂停战斗。',
       '- 直线／扇区在起手时锁定方向，落点圆在起手时锁位置；不会在预警末尾追着玩家转弯。射线受地图实体遮挡。',
       '- 收招期间停止移动和再次攻击；达到其生命14%的单次有效伤害可打断小怪的未出手攻击，取消对应待发判定。',
       '- 枪卫准备姿态只对正面减伤，出手与背后均有破绽；弩手、书记员保持距离，被贴近后后撤；猎犬与潜猎兽尝试绕侧。',
       '- 圆环填色只覆盖真实危险环带，内圈留空；地面范围、进度提示、实际伤害使用同一份几何数据。',
       '- Boss台词仍为非模态短句，继续打斗；招式名、躲避提示和收招机会另外显示，不遮挡台词。',
       '- 女王使用自己的成熟脸型、冠服和晶翼；第三阶段只解除外侧认证护架，核心与双结局条件未改。',
       '', '## 美术交付与复现','',
       '美术使用内置imagegen生成。原稿保存在art/rpg-enemies-v1/masters；运行资源、每姿态UV与脚底枢轴、SHA-256见assets/story/rpg-enemies-v1/manifest.json。7位首领使用1024×1536纵排图，8种小怪使用1536×1024横排图；女王使用3张1536×1024独立透明图。保留原生分辨率，没有冒充原生4K。',
       '', 'PNG没有手工抹除或重画。编译器按透明区域识别完整人物、武器及装饰，越过名义分格的长枪也保留；必要时以多块UV矩形排除邻帧碎片。所有分块共用脚底枢轴，仅产生一块接地阴影。',
       '', '- 原始提示词：art/rpg-enemies-v1/prompts.json。',
       '- 实际追加约束与纵排重排提示词：art/rpg-enemies-v1/generation-prompts.json。',
       '- 女王独立姿态提示词：art/rpg-enemies-v1/queen-single-prompts.json。',
       '- 采用图源与排版：art/rpg-enemies-v1/generation-results.json；初稿图源见original-results.json。',
       '', '```powershell', 'python tools/build_scarlet_enemy_roster.py', 'python tools/package_scarlet_enemies.py',
       './tools/preview_scarlet_enemy_art.ps1', './tools/preview_scarlet_enemy_art.ps1 -AllPoses',
       '.\\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/scarlet_enemies.gd', '```',
       '', '素材打包工具只分析alpha与写UV元数据，需要Pillow、NumPy和SciPy；游戏运行不需要Python。',
       '', '## 后续精修边界','',
       '当前是三关键姿态配程序过渡，并非完整骨骼动画或逐帧跑步、转身、倒地动画。后续可继续补高帧动作和独立受击／倒地姿态、专属音效及战术配音。自动回归与实渲不等于完整人工动作通关，整体难度仍需手动试玩调节。24个剧情影片槽保持空路径，未生成或绑定任何过场动画。dist发布包本轮未重新导出。','']
(ROOT/'docs/rpg/SCARLET-ENEMIES.md').write_text('\n'.join(rows),encoding='utf-8')
print('Enemy design written: docs/rpg/SCARLET-ENEMIES.md')
