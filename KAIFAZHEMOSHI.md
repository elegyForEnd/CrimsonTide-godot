# 开发者模式 · 判定框总览（KAIFAZHEMOSHI）

> 这份文档解释「开发者模式」这个启动入口。启动器本体是 `开发者模式启动.cmd`，它必须保持
> **纯 ASCII + CRLF**（原因见文末「为什么中文写在这里」），所以中文说明放在这里。
> 路牌索引：`PROJECT-GUIDE.md` §9 开发者启动 / §4.R 开发者模式 / §5 速查。

## 怎么开

双击 **`开发者模式启动.cmd`**。它做的事和 `游戏启动.cmd` 完全一样（同一条链）：

```
开发者模式启动.cmd
  → 设 CRIMSON_DEV_RANGES=all          （与正式启动唯一的区别）
  → Start-Game.cmd：
       类缓存守卫 tools/check_class_cache.ps1
    → Godot --editor --import（编译/导入改动过的资源与类缓存）
    → 启动游戏
```

- 正式游玩请用 `游戏启动.cmd`：不设那个环境变量时，覆盖层**连节点都不会创建**
  （`main.gd:305` 的 `if DevRanges.enabled()` 不成立，见路牌 §11.48）。
- 只想编译不启动：`开发者模式启动.cmd --import-only`（参数会透传给 `Start-Game.cmd`）。
- 启动器自己的自检：找不到 `Start-Game.cmd`、或环境变量没能传进子进程时会打印错误并 `pause`，
  双击时窗口不会一闪而过。

## 四个批次与进度（2026-10-11 · 第 5 批已完成）

覆盖层按宿主分成四个批次，`dev_ranges.gd` 里的 `enum Mode { NONE, ROGUE, EXPEDITION, CAMP, STORY }`
由挂载处显式指定（`main.gd` `attach_dev_ranges(host, mode)`，见路牌 §4.R.2）。四批**都已实现并出图**。

| 批次 | 宿主 / 投影来源 | 状态 | 出图 |
|---|---|---|---|
| 魔境（2D 战场） | `rogue_field.gd`，`Transform2D(0,-camera_offset())`（一次仿射） | ✅ 已做 | `build/preview-rogue.png`、`build/rogue-summons-2-seek.png` |
| 搜打撤（3D 战场） | `battlefield.gd` → `world_3d.ground_transform()`（一次仿射） | ✅ 已做 | `build/preview-game.png`、`build/raid-boss0.png` |
| 营地（3D 家园） | `camp_site.gd`，`site.project_ground()` **逐点投影（带地面高度）** | ✅ 已做 | `build/preview-ground.png` |
| 故事（连续地图） | `story_screen.gd`，`project()` **逐点投影（带 height_at）** | ✅ 已做 | `build/preview-story.png` |

两种投影，按宿主二选一（`affine()` 判断）：

- **魔境/搜打撤**：`begin_sim()` 设一次**仿射贴地变换**，圆用 `draw_arc` 画——宿主自己画城门弧线/预警圈
  也是同一套，所以天然重合。
- **营地/故事**：**逐点投影**（每个圆采样 16–44 个点，各自走 `project_ground()` / `project()`），因为这两个
  宿主的投影带地形高度。⚠️ 曾经用 `ground_transform()`（只在世界 (0,0)/(100,0)/(0,100) 三点取高度做一次
  仿射拟合）：台阶上的圈会被整体压下约 90px（800px 屏约屏高 11%），**"宝箱下方一个孤立椭圆、进去没事件"
  就是这么来的**（判定只看 2D 距离，与圈的位置无关）。

文字始终画在画布空间（`label()` 内部临时复位再投影锚点）。**F9** 收文字、**F10** 收/展整个面板。

## 勾选面板（第 5 批新增）

面板是**原生 Godot Control**（`PanelContainer` + `CheckBox` + `ScrollContainer`），只在开发者模式存在：

- **结构**：模式（魔境/搜打撤/营地/故事/通用）→ 功能大类（引魂灵体 / 角色与怪物 / 子弹与互动 / …）→
  具体小类，共 30 项；**当前模式的分组自动排在最前**并标"← 当前"。
- **交互**：勾选**实时生效**（改 `toggles` + `queue_redraw()`）；状态存在 `dev_ranges.gd` 的 `static var toggles`，
  所以换宿主（魔境→营地→故事）不丢，**重启回默认**；底部有 全选 / 全不选 / 重置。
- **标题栏可拖动**，右侧 `—` 最小化成一个小按钮「开发者模式」，点它或按 **F10** 再展开。
- **不会顺带出招**：勾选框是 `Button` 子类，`main.gd mouse_over_button()` 认它；面板空白处由
  `main.gd dev_panel_hover()` → 覆盖层 `captures_mouse()`（用 Godot 自己的 `gui_get_hovered_control()` 命中结果）
  兜住，所以点面板不会蓄力一刀。正式游玩时分组 `dev_ranges` 里没有节点，这两条恒为 false。
- 图例（`common_legend`）默认**关**：面板标签里已经带数值；需要动态数值（如随威胁变化的索敌半径）时再打开。

### 第 5 批修的四件事

1. **灵体门控（用户报"没有灵体词条却出现索敌框"）**：真因在玩法侧——`rogue_build.gd` 的 `hit_event()`
   原来只要打中怪就写 `p.soul_focus`，跟有没有灵体无关，覆盖层据此画出"主人索敌圈"。现在**只有该玩家
   真有活着的灵体（`build_summons` 非空）才写**，并且**最后一只灵体消失时把 `soul_focus` 清成 -1**。
   覆盖层 `draw_souls()` 也改成"`build_summons` 为空直接跳过"。**联机天然按玩家隔离**：`build_summons` /
   `soul_focus` 都是玩家字典字段，随 `players` 快照同步，每个灵体的主人就是它所在的玩家。
2. **魔境补子弹框**：弹体是全模式共用的 `session.bullets`；`draw_bullets()` 抽成公共函数，敌弹
   （`owner==0`）画 `hit_radius`（默认 18）圆，玩家弹画**本帧扫掠线段**（判定就是这条线段）。搜打撤复用同一段。
   故事模式**没有弹体对象**（`ENEMY_STRIKE` 是瞬时距离判定），所以不加。
3. **故事/营地圆环改逐点投影**（见上），并给 `camp_site.gd` 加了 `project_ground()`（`project()` + `ground_height()`）。
4. **故事交互可读性**：
   - 门**只画当前区域**——`story_map.entrances()` 在户外会把别的户外区域的门也返回（`story_map.gd:139`），
     它们的坐标可能在远处甚至水里，不筛就是"水里一个孤立椭圆"。
   - **提示圈（白细）与使用圈分色**：使用圈**绿**＝英雄此刻已在使用半径内、**青**＝还不在、**红**＝距离够了
     但被威胁门（260 内有活敌）挡住。⚠️ 这是**覆盖层显示**，玩法数值一个没改（`OBJECT_USE` 仍是 110）。
   - 新增 **NPC 互动圈**：位置真值 `story_map.npc_at`（6 个世界坐标），门控复用 `PROMPT_RADIUS` 125
     （`story_screen.gd:217/232`，没有独立常量），且**只有营地（stage 0）的 NPC 可交互**。
   - 新增 **建筑碰撞箱**：占地矩形 `region.buildings[].rect`（局部 → 世界要加 `region.origin`）+
     `story_region.building_walls(rect)` 现算的 **5 段 28 厚墙**（南墙留 110 门洞，与 `story_environment`
     摆的墙块同源）；act≥2 的户外/室内没有按建筑分组的体积，改画 `structural_obstacles` / `obstacles`
     这些"被挡矩形"。

### 各批次画了什么、数值来自哪

**魔境**（`draw_rogue()` → `draw_souls()`/`draw_actors()`/`draw_bullets()`/`draw_rogue_interact()`）

| 颜色 | 框 | 数值来源 |
|---|---|---|
| 青色 | 主人索敌圈（**只在该玩家真有灵体时画**） | `rogue_build.gd` `SOUL_SEEK` = 300 |
| 紫色 | 灵体索敌圈 | `SOUL_NEAR` = 166.7 |
| 黄色 | 灵体射程 | `SOUL_RANGE` = 150 |
| 橙色 | 灵体追击停靠 | `SOUL_KEEP` = 127.5 |
| 绿色 | 角色地形判定半径 | `ruins.gd move()` 默认 15（覆盖层 `PLAYER_RADIUS`） |
| 红色 | 怪物半径 | `rogue_combat.setup_minion()` 的 `rogue_radius`（兜底 13） |
| 细红线 | 灵体的当前目标 / 主人点名目标 | — |
| 黄色 | 子弹 | 敌弹 `hit_radius`（`CombatVisuals.ENEMY_BOLT_HIT_RADIUS` 兜底）；玩家弹本帧扫掠线段 |
| 青色 | 宝箱 85 / 奖励箱 / 掉落 80 / 分叉 64 / 救援 75 | `session.gd:108-116` 常量 |

**搜打撤**（`draw_expedition()` → `draw_hazards()`）

| 颜色 | 框 | 数值来源 |
|---|---|---|
| 绿色 | 玩家 15 / 倒地救援 75 | `PLAYER_RADIUS`、`session.RESCUE_RADIUS` |
| 红色 | 怪物半径 | `Ecology.RADIUS[type]`（`ecology.gd:5-19` 六表） |
| 青色 | 怪物索敌 | type0-3 `session.enemy_seek_radius()`、type4 `session.KNIGHT_SEEK`、type≥5 `Ecology.SEEK_RANGE` |
| 黄色 | 怪物攻击射程 | type0-3 `session.ENEMY_MELEE_HIT`、type4 `BossTactics.KNIGHT_MOVES` 最大 reach、type≥5 `Ecology.attack_reach(kind)` |
| 品红 | **Boss 伤害域轮廓** | 沿射线采样**权威判定** `session.expedition.hazard_contains(h, point)` + 二分细化（不重算几何，按签名缓存） |
| 黄色 | 子弹 | 同上（`draw_bullets()` 公共实现） |
| 青色 | 互动圈 | 城门 85 / 撤离 83 / 封印 72 / 搜刮 80 / 掉落 70 / 救援 75 |

**营地**（`draw_camp()`，逐点带高度投影）

| 颜色 | 框 | 数值来源 |
|---|---|---|
| 青色 | 10 个设施交互圈 | `camp_site.gd` `stations[].radius`（250/215/215/205/265/230/200/170/170/170） |
| 绿色 | 角色半径 | `site.ACTOR_RADIUS` = 24 |
| 灰色 | 名牌可见范围 650 | `camp_screen.gd:733`（**只登记、不同源**：它只管地名可见性，进圈才出光环与 [E]） |
| 青色 | 田畦 / 栈桥 / 拾取 | `CampRules.PLOT_RADIUS` 155、`PIER_AT`+`PIER_RADIUS` 240、`DROP_RADIUS` 120 |

**故事**（`draw_story()`，逐点带高度投影）

| 颜色 | 框 | 数值来源 |
|---|---|---|
| 黄色 | 英雄普攻 200/580/245、技能 430、奥义 670 | `story_campaign.HERO_ATTACK` / `HERO_SPECIAL`（**刀光只画到 245**） |
| 绿色 | 英雄近身命中 | `story_campaign.HERO_MELEE_HIT` = 80 |
| 青色 | 敌人索敌 / 出手 / 休眠 | `ENEMY_CHASE` [300,80]、`ENEMY_STRIKE` [650,120]、`ENEMY_SLEEP` 900 |
| 红色 | 前摇 AoE | 敌人 `radius`（+ ring 内圈 `BOSS_RING_INNER` 100 / cross 臂 `BOSS_CROSS_ARM` 65） |
| 青色 | 伙伴索敌 / 事件 / 跟随 | `ALLY_SEEK` 350、`ALLY_EVENT` 150、`ALLY_FOLLOW` 80 |
| 白细 | 提示圈 125（画在"物"上） | `story_campaign.PROMPT_RADIUS` |
| 青/绿/红 | 使用圈：任务物 110 / 宝箱 130 / 门洞 150 / 传送阵 160 | `OBJECT_USE` / `CACHE_USE` / `ENTRANCE_USE` / `WAYPOINT_USE`（HUD 按钮 150） |
| 灰色 | 威胁门 260 | `story_campaign.THREAT_BLOCK` |
| 青/绿 | NPC 互动 125（仅 stage 0） | `story_screen.gd:217/232` 复用 `PROMPT_RADIUS`，位置 `story_map.npc_at` |
| 橙/红 | 建筑占地矩形 / 5 段墙块 | `region.buildings[].rect`、`story_region.building_walls()` |
| 紫 | 被挡矩形（act≥2 体积） | `region.structural_obstacles` / `region.obstacles` |

互动半径的单一真值是路牌 `PROJECT-GUIDE.md` §4.R.1 那张表——**提示出现的距离必须等于按下生效的距离**，
改任何一处先改表再改代码。上表里少数"只登记、不同源"的项（营地 650、故事提示 125 vs 使用 110/130/150/160、
传送阵按钮 150 vs 使用 160）在 §4.R.1 有明确记录，覆盖层照实画出来正是为了让人看见这些不一致。

## 单真值提取（2026-10-11 本轮）

覆盖层的铁律是"框的半径必须引用原系统常量"，所以本轮先把散落的内联字面量提成常量（**只提取、不改数值**）：

- `scripts/session.gd`：`ENEMY_SEEK_BASE` 440 / `ENEMY_SEEK_PER_THREAT` 300 / `KNIGHT_SEEK` 780 /
  `ENEMY_MELEE_HIT` 58，并新增 `enemy_seek_radius()`（`session.gd:3956`）。
- `scripts/ecology.gd`：`SEEK_RANGE` 470 + `static func attack_reach(kind)`（原 `update()` 里 280/340/260/210/185/145/285/230 的 if 链）。
- `scripts/story_campaign.gd`：21 个故事半径常量（`story_campaign.gd:23-43`），24 处内联字面量全部替换。
- `scripts/story_screen.gd`：`var best: float = campaign.PROMPT_RADIUS`（**必须显式 `: float`**，否则"无法推断类型"解析失败）。

## 加一个批次 / 加一个框

1. 在 `scripts/dev_ranges.gd` 里加一个 `draw_xxx()`，并在 `_draw()` 里按 `mode` 调用；
2. **框的半径一律引用原系统的公开常量**（例如灵体四档直接读 `Build.SOUL_*`），不许在覆盖层里抄一份副本，
   否则改数值后框会撒谎；被挡/可交互这类**判定结论**也要照抄原判定的输入（例如威胁门就用
   `story_campaign.THREAT_BLOCK` + 同一批 `enemies`），别另立一套几何；
3. 想让它可勾选：在 `PANEL_TREE` 里对应模式/大类下加一条 `[key, 标签, 默认值]`，然后在该批次的绘制里
   `if toggle_on("key"):`；key 必须唯一（`tests/dev_ranges.gd` 会校验）；
4. 在 `main.gd` 的挂载点用 `attach_dev_ranges(host, DevRanges.Mode.XXX)` 挂上（见路牌 §4.R.2）；
5. 更新本文档的批次表 + 在 `tests/dev_ranges.gd` 里补一条契约断言。

**出图/试手感的预览入口**（都是 `--` 之后的用户参数，正式游玩不经过）：

| 参数 | 进到哪 |
|---|---|
| `--preview-rogue --capture` | 魔境（直接开一局闯关，出图 `build/preview-rogue.png`） |
| `--preview-game --capture` | 搜打撤（出图 `build/preview-game.png`） |
| `--preview-ground --capture` | 营地/家园（出图 `build/preview-ground.png`） |
| `--preview-story --capture` | 故事模式（出图 `build/preview-story.png`） |

例：`$env:CRIMSON_DEV_RANGES="all"; .\Godot_v4.7.2-stable_win64_console.exe --path . -- --preview-rogue --capture`

铁律（路牌 §11.48）：覆盖层**只读**——只画 `session` / `campaign` / `site` 里已有的状态与公开常量，不改数值、
不写 session、不吃 `s.rng`、不参与任何命中判定；**不设 `CRIMSON_DEV_RANGES` 时连节点都不建**（探针实测
`ROGUE/FIELD/CAMP/STORY_OVERLAY` 全 false）。唯一例外是"游戏读覆盖层的 UI 状态"：`main.gd dev_panel_hover()`
问一句"鼠标是不是在面板上"，免得点面板顺带挥一刀——覆盖层自己不写任何游戏状态。
⚠️ 营地/家园与搜打撤、故事表现层都是 3D（`camp_site.gd` 的 `UNIT/PITCH/CAMERA_DISTANCE` 投影、
`world_3d.gd` 正交相机）：**魔境/搜打撤**走一次仿射贴地变换，**营地/故事**必须逐点投影
（`site.project_ground()` / `story_screen.project()`），别用 `ground_transform()`——那是三点拟合，台阶上会偏。

## 为什么中文写在这里（2026-10-11 踩过的坑）

`开发者模式启动.cmd` 原来是 **UTF-8 + LF** 存的，而 cmd.exe 按 **cp936（GBK）** 读 `.cmd` 文件。
多字节字符会把后面的换行"吃掉"，于是：

- 第 26 行的 `echo` 与第 27 行的 `call "%~dp0游戏启动.cmd" %*` **被并成一行**；
- `set "CRIMSON_DEV_RANGES=all"` 实际没执行——桩脚本里读到的变量是**空的**，所以**判定框从来没真正开过**；
- 传给子脚本的参数变成了注释文字：实测 `args=[—— 不设这个环境变量时，判定框覆盖层**根本不会被创建**。]`；
- 表现出来就是"双击后命令行窗口动了一会儿自己关掉、游戏没起来"，而且没有任何明确的报错。

结论：`.cmd` 一律**纯 ASCII + CRLF**（`Start-Game.cmd` 的头注早就写了这条规矩），中文说明放 `.md`。
改完 `.cmd` 后跑这两行自检，两项都必须是 0：

```powershell
$b=[System.IO.File]::ReadAllBytes(".\开发者模式启动.cmd")
"non-ascii bytes: " + ($b | Where-Object { $_ -ge 128 }).Count
"bare LF: " + (1..($b.Length-1) | Where-Object { $b[$_] -eq 10 -and $b[$_-1] -ne 13 }).Count
```
