# 隐藏结局 · 骑士的护身符与死灵法师墓煜

一份新增内容说明。它记录隐藏结局的触发条件、隐藏 Boss、新角色墓煜的技能数值，
以及这次改动碰到的每一个英雄索引假设。素材生成方式见
`tools/prepare_muyu_art.py` 与 `tools/prepare_muyu_audio.py`。

## 一、隐藏结局

### 触发条件

四个条件必须**在同一局远征内**同时成立：

| 条件 | 说明 |
|---|---|
| 三个晨钟封印全部点亮 | 地图上的金色菱形。长按 `E` 3 秒各点亮一处 |
| 背包里带着**骑士的护身符** | 失乡骑士必定掉落，1×1、红色品质、价值 666 |
| 血潮女王已被击败 | 第三天终局 Boss 倒下 |
| 未走深渊分支 | 已收集两枚异兽秘印时优先走 `吞月渊蛇` 结局 |

四个条件全部满足时，女王倒下的那一帧不会结算远征，而是升起第四个遭遇：
**冥火尸王 · 墓玥**。击败它才是这一局的结束。

判定的实现刻意做成"任意帧成立即触发"，而不是绑在某一次事件上：晨钟和护身符
可以在任意一天拿到，所以 `TideSession.simulate()` 每帧检查一次
`hidden_ending_ready()`，一旦 `raid.final_spawned` 与四个条件同时成立就调用
`expedition.spawn_hidden()`。这样无论是"先打女王再补护身符"还是"先齐护身符
再打女王"都能进隐藏线。

### 三个晨钟封印为什么要记账

`raid.sealed_bells` 而不是 `ruins.shrines`。进出晨曦王城会重建边境地图
（`travel_city()` 从 `map_states` 取回旧地图，首次进入则 `Ruins.new()`），
重建出来的地图三处晨钟都是灭的。因此已经点亮的封印记在 raid 状态里，
随网络快照一起同步。

### 护身符必须背在身上

`carries_amulet()` 只查**背包**，不查次元口袋。口袋是永久的、死亡也不会掉，
如果口袋也算数，这个条件的风险就不存在了。放进背包则意味着：为了它要占掉
一格，倒地时它会跟着背包散落在地上。

### 隐藏 Boss

| | |
|---|---|
| 名字 | 冥火尸王 · 墓玥 |
| 生命 | 9200（每多一名队友 +55%） |
| 阶段 | 60% 与 30% 两处阈值，三个阶段 |
| 招式 | 10 招，见 `HIDDEN_MOVES` |
| 配色 | 紫色 `#c07ae0`，与女王的金色区分 |
| 奖励 | 1200 银币 + 一枚 8×8 红色背包 + 两件红色武器与一件红色装备 |

招式表 `cast_hidden()`：墓环迸裂（内环接外环）、冥魂长枪（直线接两侧）、
荒冢标记（脚下印记）、烬火扇面（扇形间隙）、枯骨囚笼（收束环）、
裂隙潜行（落点封锁后十字火线）、死灵火葬（长墙）、抽髓（快慢交错）、
冥火十字（交错火线）、焚尽冥府（终局连击）。

隐藏 Boss 复用女王的美术图集与音频主题（`Presentation.HIDDEN_KIND = 2`），
但**自己的配色**（`Presentation.theme_color(kind, hidden)`）和自己的招式表。
这样不需要一份新的 4×4 特效图集，同时战场上仍然一眼能认出是不同的遭遇。
若要换成完全独立的素材，把 `HIDDEN_KIND` 指向一个新的图集索引即可。

## 二、新角色 · 墓煜

### 解锁

击败隐藏 Boss 后，`Profile` 写入 `unlocks.muyu = true`，营地角色栏出现第四格
（按钮显示为 `墓煜 ✦`）。这是一个**永久解锁**，写进 `profile.json`，
之后每次开局都能选择。

`Catalog.HEROES` 始终有第四行；能不能选由 `Profile.roster_size()` 决定。
未解锁时按钮根本不绘制，所以三个原角色的布局一字未动。

### 数值

| | |
|---|---|
| 名字 / 称号 | 墓煜 / 冥火死灵法师 |
| 生命 | 100 |
| 移速 | 225 |
| 初始武器 | 湮魂之镰（单手剑族，攻速略慢于黑铁短剑） |
| 大招 | 冥火剑雨 |

`Catalog.STARTER_WEAPONS` 从 3 条变成 4 条，索引 20。`STARTER_BASE` 不变
（它只标记"场内武器之后"，与英雄数量无关），`weapon()` / `is_starter()` /
`weapon_family()` / `weapon_icon()` 全部按表长取，所以加一位英雄不需要改武器系统。

### 大招：冥火剑雨

按 `Q` → 立绘切入 → 在**前方矩形区域**召唤法阵与符文剑雨。

```
矩形：身前 480 × 宽 350（半宽 175，身后 20）
剑雨：单次 150 伤害（吃大招乘区：天赋 / 护符 / 营地装备 / 手持武器品质）
冥火：剑雨落点留下紫色冥火区域，持续 6 秒，每 0.5 秒结算 66 伤害
灼烧：被冥火影响过的怪物自身每 0.6 秒扣 6 生命，持续 6 秒
      再次被冥火命中 → 刷新持续时间，**不叠加**
```

数值常量都在 `TideSession` 顶部：`SOUL_REAP_DAMAGE`、`FIRE_LENGTH`、
`FIRE_HALF_WIDTH`、`FIRE_TICK`、`FIRE_TICK_DAMAGE`、`FIRE_DURATION`、
`BURN_TICK`、`BURN_TICK_DAMAGE`、`BURN_DURATION`。

**冥火区域**是 `fire_zones`，**剑雨**是 `soul_reaps`（落点有 0.32 秒延迟，
让矩形读起来是"招式"而不是"按键瞬间"）。两者都由主机结算、通过普通
combat 事件广播给客户端。

**地面表现**在 `CombatVisuals.draw_spells()`：法阵图被拉伸到矩形本身
（`patch_local_rect()`，与 `inside_reap()` 同源），所以法阵和真正烧到的地面
是同一个大小同一个朝向；**紫色边框已经去掉**，法阵图就是提示本身。冥火不再走
"四道直线火柱"，改成**六朵火在大招实际范围内散开**，与剑雨同一套分布规则。

**分布规则**（`spread_over_ring()`）：把法阵切成 `count` 个等角扇区，每个扇区
正好放一个位置，半径按内外两圈交错，再让角度在扇区内小幅随机——纯随机撒点会扎堆，
六把剑挤在一起看着像一道糊痕而不是剑雨。剑和火各自一套扇区、错开半个扇区，
所以两组互不重叠。种子取自「法阵位置 + 朝向」，每个客户端摆出来的是同一场，
不需要多传字段。每把剑的四个角都要落在法阵椭圆内、且不压在自己脚下的施法者身上，
`tests/muyu_effects.gd` 会检查这几条（含"扇区里正好一个"的均匀性检查）。

**刷新而不是叠加**：`burn_enemy(refresh=true)` 只重置 `burn_time`，
不动 `burn_next`（灼烧自己的脉冲时刻表）。这是刻意的：如果刷新把时刻表也
重置，站在冥火里的怪物会因为每 0.5 秒被刷新一次而永远等不到 0.6 秒的那一跳，
灼烧 debuff 会形同虚设。蹲在火里正确的结果是"区域 12 跳 + 灼烧约 10 跳"。

矩形判定是一个静态函数 `inside_reap()`，瞄准、伤害、地面绘制三处共用，
不会出现"看起来在火里却没掉血"。

### 素材

墓煜的战斗素材统一放在 `assets/combat/`（工程里所有角色的战斗素材都在这里），
没有独立角色目录。`assets/muyu/` 已删除，未使用的裁切件在
`D:\dsh\Game\muyu-backup-20260924-042822\`。

| 文件 | 用途 |
|---|---|
| `assets/combat/attack-clean-3.png` | 4×3 攻击图集，三行 = 三个武器族 |
| `assets/combat/movement-3.png` | 4×3 移动图集，三行 = 走 / 跑 / 闪避 |
| `assets/combat/muyu-idle.png` | 待机单帧 |
| `assets/combat/muyu-down.png` | 倒地单帧 |
| `assets/combat/ultimate-cg.png` | `Q` 切入立绘（三行图集，**不由脚本重建**） |
| `assets/combat/muyu-hex-ring.png` | 起手法阵 |
| `assets/combat/muyu-circle.png` | 大招法阵（拉伸覆盖整个生效矩形） |
| `assets/combat/muyu-flames.png` | 冥火，5 帧单行图集 |
| `assets/combat/muyu-sword.png` | 剑雨单把素材 |
| `assets/combat/muyu-rune-rain.png` | 旧的剑雨图集，现在没有代码引用（保留备查） |
| `assets/portrait-3.png` | 营地与结算立绘 |
| `assets/icons/soul_scythe.svg` | 初始武器图标 |
| `assets/icons/grimoire_staff.svg` | 备用魔杖图标 |
| `assets/icons/amulet.svg` | 护身符图标 |

`muyu-circle.png`、`muyu-flames.png`、`muyu-sword.png` 来自 `_refs/muyu-effects/`，
用 `python tools/prepare_muyu_effects.py` 生成，`--preview` 只出预览不覆盖素材。

**这三张参考图都是"透明画布截图"**：编辑器棋盘格被压进了像素里（火焰 119/161、
法阵 189/254），而且手上拿到的是 JPEG。抠底按「既中性又够亮」判定背景，只删掉
和边框连通的那部分，所以暗线条和大招的亮部都留着。**但圆环内部那圈淡辉光已经被
JPEG 压成灰的**——那里棋盘格和辉光在亮度与中性度上完全重合，任何抠底都分不开。
现在的处理是把淡到看不见的那一档 alpha 直接归零（`alpha[halo]` 的起点从 0.35 起算），
让残留的棋盘格落在 1% 以下不透明度上；圆环内部本身是不透明的，所以看不出格子。
如果那几张画布能**导出成真正的 RGBA PNG** 放进 `_refs/muyu-effects/`，跑一次就干净了。

除法阵圆环外，其余素材由 `python tools/prepare_muyu_art.py` 从两张参考图裁切生成，
可用 `python tools/preview_muyu_art.py` 输出对位预览到 `output/muyu-preview/`。
`ultimate-cg.png` 是生图稿而不是裁切稿，所以默认**不重建**（重建会得到完全不同的
版式，切入动画按三行切分会切错）；要重建得显式写 `cutin`。

`assets/portrait-3.png` 是唯一不来自那两张图集的一张：它的画源是
`_refs/muyu-portrait/ref.jpg`（在工程目录外一层，与两张图集同一处），独立的一整幅构图。
换立绘时把新图放到这个路径再跑 `python tools/prepare_muyu_art.py portrait`。
手边只有立绘、没有 `_refs/` 时，`python tools/key_portrait.py 新图.png 输出路径.png`
走的是同一套抠底、裁边、900px 标准化流程，结果一致。
参考图自带 alpha 时按成稿直接使用，只有白底合成图才做连通性抠底；抠底按连通性而不是按
颜色，因为白发、书页和高光与背景是同一个白，按颜色会把它们一起掏空。

语音与音乐由 `python tools/prepare_muyu_audio.py` 生成：墓煜没有重新录音，
她的台词是既有演出的降调变速派生，授权与署名沿用 `VOICE-CREDITS.txt`。

## 三、这次改动碰到的英雄索引假设

原来有三处"硬编码 3"会在第四位英雄出现时崩溃，已全部改成按表长取：

| 位置 | 原来 | 现在 |
|---|---|---|
| `session.gd` `make_player` | `clampi(hero,0,2)` | `clampi(hero,0,Catalog.HEROES.size()-1)` |
| `session.gd` 大招时长 | `.heroes[p.hero]`（越界崩溃） | `ultimate_seconds()`，越界回退到联机短切入 |
| `profile.gd` | `clampi(data.hero,0,2)` | `clampi(data.hero,0,roster_size()-1)` |
| `character_frames.gd` | `for hero in 3` | `for hero in Catalog.HEROES.size()` |
| `ultimate_cinematic.gd` | `clampi(hero,0,2)`，图集 `height/3` | 按 `Catalog.HEROES.size()` 分行 |
| `sound.gd` | `for hero in 3`，`[clampi(hero,0,2)]` | 按表长取，缺文件回退到第一位 |
| `hero_voice.gd` | `clampi(hero,0,2)`，`banks[hero]["select"][0]` | `bank_for()` / `line_for()`，缺项静默 |
| `main.gd` 营地 | `for i in 3` | `for i in profile.roster_size()` |
| `main.gd` / `battlefield.gd` 武器图标 | `WEAPON_ICONS[...]` | `Catalog.weapon_icon()` |

另外修掉一个**与本次内容无关但会崩的既有 bug**：敌人死亡结算在遍历
`enemies` 的同时 `remove_at()`，而 Boss 的奖励流程可能重建敌人列表。
现在先把阵亡者收进 `fallen`，遍历结束后按引用删除。

## 四、测试

```powershell
cd CrimsonTide-godot
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import        # 新素材先导入
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests\hidden_ending.gd
.\Godot_v4.7.2-stable_win64_console.exe --path . --script tests\recruit_ui.gd   # 需要真实窗口
```

- `tests/hidden_ending.gd`：护身符属性与掉落、三钟 + 护身符判定、隐藏遭遇
  的升起与击杀、隐藏结局结算、解锁的存档往返、墓煜的属性与初始武器、
  冥火剑雨的矩形判定、冥火脉冲节奏、灼烧的刷新而非叠加。
- `tests/recruit_ui.gd`：锁定 / 解锁两种营地阵容、点击选择、
  三套移动与三族攻击都有帧、结算面板带隐藏标记。需要真实窗口。

## 五、以后替换素材

这次生成的素材是**可用但粗糙**的版本：角色图集是从两张参考图直接裁切并重排到
游戏的四列三行网格里，姿态是"同一个人不同角度"而不是真正的逐帧动画。
要换成正式素材时：

1. 保持 `1448×1086`、4 列 × 3 行；
2. 攻击图三行依次为单手 / 重武器 / 法杖族，移动图三行依次为走 / 跑 / 闪避；
3. 每个姿势完整落在自己的 362×362 格内，四周留透明边（`tests/movement.gd`
   会检查这一条）；
4. 朝向为**默认朝右**（游戏用镜像处理向左）；
5. 头身比例与 `CharacterMetrics.HEAD_PIXELS` 一致，否则
   `tests/character_scale.gd` 会报"共享头部尺寸"失败；
6. 改完跑一次 `--headless --path . --import` 再跑
   `tests\character_scale.gd` 与 `tests\movement.gd`。

隐藏 Boss 若要独立素材，见第一节末尾的 `HIDDEN_KIND` 说明。
