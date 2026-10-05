# 魔境扩展 · 可执行实施计划（顶层调度用）

本文件由只读勘察产出，供父 Agent 直接切块委派给子智能体。所有行号/函数名均按当前工作区实测
（勘察中复核并**纠正**了任务书里若干过时数据，见 §0）。

---

## 0. 勘察纠正（先看这段，任务书里的数字有几处已过时）

| 任务书说法 | 实测 | 影响 |
| --- | --- | --- |
| `session.gd` 3755 行 / `main.gd` 3425 行 / `battlefield.gd` 735 行 / `roguelike.gd` 644 行 | session 3755、main 3425、battlefield 708、**roguelike 674**、rogue_combat 367、rogue_build 1011 | 小，仅供估算 |
| `roguelike.gd:59` 的 route 模板、`:596-614`、`:293-337`、`:339-351` | 完全正确 | — |
| `roguelike.gd` 每层固定 7 区 | 正确，`AREAS_PER_FLOOR := 7`（roguelike.gd:11） | — |
| `rogue_combat.gd:220-253` 的 `boss_enraged` | 实测在 `:205-209`；`:220-253` 是招式释放分支 | 委派时给函数名，别只给行号 |
| 5 个守层者、17 个美术 key | 正确。`boss_effect_art.gd:4` 是 **17** 个 key，`ROGUE := ["grove","furnace","astral","wing","obsidian"]` 只用了其中 5 个 | Boss 池扩容**不需要新美术**，见 W6 |
| `tests/rogue_build_progression.gd`（417 项，跑通完整 5 层 25 区） | **实测 505 checks / 39 failures（已红）**，且断言的是**旧的每层 5 区**设计 | 见 §4，这条不能当"保持通过" |
| `tests/rogue_build_growth.gd`（4066 项） | 正确，实测 **4066 checks / 0 failures**，统计样本 `[213, 500]` | 见 §4.3 |
| —— | `AREAS_PER_FLOOR=7` 意味着**每层 7 区、共 35 区**，`ROGUELIKE.md:181` 已记录 2026-10-05 的 7 关改造 | 文档/结算文案里残留的"25 区"是旧值 |
| —— | `rogue_build_content.json` 是**生成物**，源是 `ROGUE-BUILD-SYSTEM-DESIGN.md` + `tools/build_rogue_content.py`（脚本第 57 行有 `assert == 252`） | 加内容必须改这两处 |
| —— | `server/app.py:408-433` 的 `validate_profile` 硬校验 `version == 1`、属性 key 白名单 | 见 §5.1，直接卡存档方案 |

### 已实测的基线（本计划的门禁以此为基准，不要重新定义）

在仓库根用 `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/<name>.gd`：

| 测试 | 结果 | 备注 |
| --- | --- | --- |
| `rogue_build_growth` | **4066 checks / 0 failures** | 含统计断言 |
| `rogue_build_system` | 440 checks / 0 failures | |
| `roguelike_seven_rooms` | 1856 checks / 0 failures | 硬编码 `route.size()==7`、`exits.size()==2`、`area 7 == boss` |
| `roguelike_routes` | 5219 checks / **5 failures** | 挑战闸门保底守层者、挑战守层者血量、跨层商店路线、分支连续可行走×2 |
| `rogue_build_progression` | 505 checks / **39 failures** | 6 组陈旧断言（见 §4.1） |
| `rogue_build_rules` | **1 failure + SCRIPT ERROR** | `Painted icon exists: W001` → `Nil.atlas`（素材/图集环境问题） |
| `rogue_build_pack` | **2 failures** | `Failed to load script main.gd "Compilation failed"` + `Missing exported icon W001`（环境问题） |
| `roguelike_network` / `rogue_build_network` | 0 errors | 需多进程参数才真正跑 |
| `tools/run_all_tests.ps1` | 348 个 `tests/*.gd`，逐个 60s 超时；`*_visual`/`ui`/`hybrid_vfx_preview` 走窗口模式 | `city` 已出现 60s TIMEOUT |
| `tools/verify_rogue_build.ps1` | 只跑 6 个测试，命中 `SCRIPT ERROR:`/`^ERROR:` 即 throw | **因为 progression 已红，现在必然失败** |

> 结论：**不要用"全绿"当门禁**。用"指定测试的错误数不增加 + 新增测试全绿"（见 §4.4）。

---

## 1. 一句话 objective（可直接登记）

> 在 `D:\game\CrimsonTide-godot` 中完成两件事并保持既有存档与联机快照兼容：①把敌人弹幕改成更大更显眼的**纯视觉**方案且逐条证明命中判定几何零变化（命中判定不变是验收硬条件）；②按方案 2+3 扩展魔境肉鸽——加入每层全队共享且 HUD 可见的"深渊变数"、诅咒房/事件房、守层者半血二阶段换招表、种子分享与每日挑战，把每层固定 7 槽路线重做为节点图并新增铁匠铺/赌徒/镜像挑战房、以"灰烬"货币实现局外永久成长树并做存档迁移、扩容守层者池；所有既有测试不得出现**新增**失败，新增行为必须有 `--script` 可跑测试或截图为证。

**objective 里必须保留的硬约束**（否则会被执行成"顺手改了判定"）：
1. 弹幕只改视觉层，`rogue_combat.gd` 的 `zone()/contains()/bolt()` 伤害几何与 `s.bullets` 的 `damage` 字段不动；
2. 存档 `profile.json` 老档可读且**不丢字段**，服务端 `validate_profile` 不拒收；
3. 联机下新增游戏状态必须在 `raid` 或 `players[*]` 内（快照白名单，见 §5.2）。

---

## 2. 建议 `max_goal_rounds`

**建议 `max_goal_rounds: 24`**（若要求把 5–6 个预算也要跑全绿，给 **28**）。

估算依据（按"一个子智能体一轮 = 一个可验收工作包"计）：

| 工作包 | 轮数 | 说明 |
| --- | --- | --- |
| 弹幕视觉验收（已在他处执行） | 1 | 只做验收+回归证明 |
| 共享契约冻结（`raid`/`players` 新字段、`RogueGraph`/`Variants`/`Curses` API、RNG 配方） | 1 | 必须先做，否则后续互相踩 |
| `session.gd` 一次性接线（快照字段、`reset()`、`perform` 路由） | 1 | 串行闸门 |
| `profile.gd` 迁移 + `server/app.py` 校验放宽 + `online_service` 兼容 | 1 | 串行闸门（W1 独占） |
| 节点图（`rogue_graph.gd` + `roguelike.gd` 改造 + `rogue_map.region_key`） | 2 | 最大风险块，拆成"生成器+测试"与"接线+移植测试" |
| 新房间（铁匠铺/赌徒/镜像） | 2 | 各 1 轮 + 共用 1 轮，合并为 2 轮 |
| 深渊变数 | 1 | 数据+抽取+HUD |
| 诅咒房/事件房 | 1 | 复用新房间管线 |
| Boss 二阶段换招表 | 1 | `boss_enraged` 分支 + `choreography` 备用招表 |
| 种子分享 / 每日挑战 | 1 | |
| 局外成长树 + 灰烬 + 铁匠铺 UI | 2 | 数据/规则 1 轮，UI 1 轮 |
| Boss 池扩容（≥3 个新守层者 + 音频） | 2 | 巡逻/编排 1 轮，音频与表现 1 轮 |
| 新学派/内容（若做） | 1 | 需要动设计文档+生成器 |
| 文档 + 全量回归 + 收尾 | 2 | |
| 预留返工/联机 4 进程验证 | 3 | |

上限设 24 是**真实体量下的折中**：太低会在节点图/Boss 池中途被截断，留下半迁移状态（正是现在
`rogue_build_progression` 39 红的成因）。若想更稳，把 objective 收窄为"方案 2 全部 + 方案 3 的
节点图与新房间"，Boss 池扩容与局外成长树另开一个 goal。

---

## 3. 分阶段计划（轮次 · 文件 · 验收 · 依赖）

### 3.0 文件所有权（防互相踩的硬规则）

三个文件是**多方都会想改**的：`scripts/roguelike.gd`、`scripts/session.gd`、`scripts/main.gd`。
规则：**每个文件在任何时刻只有一个"所有者轮次"在写**；其他轮次只能读，需要加东西就写进
该轮的"待接线清单"，由所有者轮次统一落。

| 集合 | 文件 | 所有者 |
| --- | --- | --- |
| **A 核心状态与入场** | `roguelike.gd`、`session.gd`、`profile.gd` | W1 |
| **B HUD 与界面** | `main.gd`、`rogue_field.gd` | W2 |
| **C 战斗与呈现** | `rogue_combat.gd`、`boss_choreography.gd`、`boss_effect_art.gd`、`rogue_enemy_vfx.gd`、`sound.gd` | W3 |
| **D 地图** | `rogue_map.gd`、`rogue_art.gd` | W4 |
| **E 内容/数据** | `resources/rogue_build_content.json`、`tools/build_rogue_content.py`、`ROGUE-BUILD-SYSTEM-DESIGN.md`、`server/app.py`、`ROGUELIKE.md` | W5 |
| **F 新文件**（无冲突） | `rogue_graph.gd`、`rogue_variants.gd`、`rogue_curses.gd`、`rogue_growth.gd`、`rogue_daily.gd`、`rogue_event_ui.gd`、`rogue_forge_ui.gd`、`rogue_gamble_ui.gd`、`rogue_mirror.gd`、`rogue_seed_ui.gd`、`rogue_map_ui.gd`、`rogue_growth_ui.gd`、`rogue_boss_pool.gd` | W6（可并行） |

### 3.1 必须先冻结的接口契约（第 1 轮成果，写进 `output/ROGUE-CONTRACTS.md`）

不做这轮，后面 6 个方向会各写一套字段名。冻结内容至少包括：

- `s.raid` 新增键：`variant`(String)、`variant_serial`(int)、`curse_serial`(int)、`seed_shared`(String)、
  `daily`(bool)、`graph`(Dictionary)、`node`(String)、`depth`(int)、`pending_event`(Dictionary)、
  `pending_forge`(Dictionary)、`pending_gamble`(Dictionary)、`mirror_state`(Dictionary)。
  **`graph` 不允许进每 0.1s 的快照**（见 §5.2），只放节点 id/kind/邻接或干脆客户端用
  `seed_value+floor` 本地重建。
- `players[id]` 新增键：`rogue_curses`(Array)、`rogue_ash_run`(int)、`rogue_mirror_used`(bool)。
- 新模块静态 API 签名（列出函数名+参数+返回，一次定死）：
  `RogueGraph.build(seed_value, floor) -> Dictionary`、`RogueGraph.kinds()`、`RogueGraph.neighbors(g,id) -> Array`、
  `RogueVariants.roll(s) -> Dictionary`、`RogueVariants.active(s) -> Dictionary`、
  `RogueCurses.apply(s,p,curse)`、`RogueGrowth.power(p) -> Dictionary`、`RogueGrowth.ashes_on_settle(s,p) -> int`、
  `RogueDaily.seed_for(date_string) -> int`。
- **RNG 配方**（保证同种子可复现，联机两边一致）：
  `enter()` 里 `s.rng` 的消耗顺序必须固定为 `[抽变数(仅每层首区)] → [节点图已预先建好] → [exits 生成] → [spawn_wave]`。
  任何新随机都必须经 `s.rng`，不得用 `randi()`。

### 3.2 轮次表

依赖列：`→ X` 表示必须等 X 完成；"并行"表示可与其他轮同时开。

| # | 目标 | 涉及文件（精确到函数） | 验收 | 依赖 / 并行 |
| --- | --- | --- | --- | --- |
| **R0** | **弹幕视觉验收入账**（设计已在别处执行） | `scripts/rogue_combat.gd`(`bolt`,`zone`,`contains`,`update_missiles`)、`scripts/rogue_enemy_vfx.gd`、`scripts/rogue_minion_vfx.gd` | ①新增/改用断言证明 `zone()` 产出的 `radius/damage/shape/delay` 与改动前字节级一致（可用固定种子跑 20 秒，序列化 `combat.effects` 的几何字段做快照比对）；②`tests/roguelike_minion_vfx.gd`、`tests/roguelike_vfx.gd`、`tests/roguelike_attack_timing.gd` 0 失败；③弹幕截图为证（`tests/roguelike_minion_vfx_visual.gd` 走窗口模式） | 独立，可第一轮就做 |
| **R1** | **冻结契约**（见 §3.1），不写业务逻辑 | 新建 `output/ROGUE-CONTRACTS.md`；只读核对 `roguelike.gd`/`session.gd`/`main.gd` | 文档评审通过；列出每个新字段的"归属快照位置" | 无依赖，最先做 |
| **R2** | **`session.gd` 一次性接线**：`reset()`(roguelike.gd:24) 初始化全部新字段；`perform()`(session.gd:1532) 增加 `rogue_event`/`rogue_forge`/`rogue_gamble`/`rogue_mirror`/`rogue_growth`/`rogue_daily` 路由；确认 `snapshot()`(session.gd:1483) 与 `_physics_process` 的 `raid["visual_*"]`(1464-1468) 不需要改 | `scripts/session.gd`(1532-1560 区段)、`scripts/roguelike.gd`(`reset`,`choose`,`advance`,`settle`) | 新字段能过 `snapshot()`/`bytes_to_var` 往返（写一个 20 行的往返测试）；`rogue_build_growth` 仍 4066/0 | 串行闸门：**所有后续轮次等它**。**此轮禁止并行改 A 集合** |
| **R3** | **存档迁移 + 服务端放行** | `scripts/profile.gd`(`apply_data:31`、`_init:20`、`save_profile:107`、`sanitize_attributes:118`)、`server/app.py`(`validate_profile:408`)、`scripts/online_service.gd`(`watch:65`、`upload:74`) | ①构造 `version:1` 的**老档 JSON**（无 `ashes`/`growth`）喂给 `apply_data`，断言老字段一个不少、默认硬币/天赋/仓库保留；②构造 `version:2` 新档，断言读回；③`version:2` 档经 `validate_profile` 不报 400（改 app.py 后）；④补一条 `tests/profile_migration.gd` | → R2（同属 A 集合，R2 后立即做，期间 W2/W3/W4 可并行） |
| **R4** | **节点图生成器**（纯逻辑，不接线） | 新建 `scripts/rogue_graph.gd`；同步写 `tests/rogue_graph.gd` | 断言：每层**恰好 1 个 boss 节点**；入口到 boss 至少 1 条路径；无环；每层节点数在 `[7, 10]`；**同种子两次生成 `hash()` 相同**；100 个种子全过；每层至少 1 个商店/补给节点 | 可与 R3 并行（新文件，零冲突） |
| **R5** | **节点图接线 + 移植受影响测试** | `scripts/roguelike.gd`(`new_floor:57`、`enter:61-114`、`exit_choices:596`、`random_destinations:606`、`advance:635`、`choose` 的 `rogue_next:578-594`)、`scripts/rogue_map.gd`(`region_key:50`、`configure:65`、`exit_position:112`)、`scripts/rogue_field.gd`(`171-205` 出口绘制/镜头) | ①`tests/roguelike_seven_rooms.gd` 移植：`route.size()==7`→"节点数在 `[7,10]`"、`area 7 == boss`→"boss 节点是该层最后一个"、`exits.size()==2`→保留（`region.exits` 目前只定义 0/1 两个出口，**不要改成 3 出口**，否则 `rogue_map.configure` 的 `assert(joined.size()==1)` 与出口表都会崩）；②`tests/roguelike_routes.gd` 5 项失败归零或明确登记；③`main.gd:1559` 的"第 x / 7 区"与 `main.gd:3336/3338` 文案同步（**这属于 B 集合，只提需求，由 R7 落**） | → R4，且必须等 R2。**独占 A 集合**，此时 W2/W3/W5/W6 只读 |
| **R6** | **Boss 二阶段换招表** | `scripts/rogue_combat.gd`(`update_boss:202`、`begin_skill:145`、`release:237`)、`scripts/boss_choreography.gd`(`MOVES:7`、`choose:27`、`start:32`)、`scripts/sound.gd`(87-94 cue 命名) | ①半血触发：把 `hp` 打到 `<=max_hp*0.5`，断言 `boss_enraged` 为真**且**接下来 5 次 `begin_skill` 使用的招式全部来自第二招表（`phase2` 集合），断言不再出现第一阶段招式；②`Choreography.choose` 在 `phase>=2` 时只返回备用表内招式；③既有 `tests/roguelike_bosses.gd` 的 414 项不新增失败（它是"5 招轮换"的旧断言，需要按新行为更新——见 §4.1） | → R2（要读 `raid` 新字段）。**独占 C 集合**；可与 R5 并行 |
| **R7** | **HUD 与入口界面接线**（B 集合唯一写者） | `main.gd`(`update_hud:1540`、`update_rogue_hud:3369`、`show_rogue_setup:3331`、`start_rogue:3352`、`rogue_icon:3416`、`config():902`)、`rogue_field.gd` | ①HUD 显示当前"深渊变数"名称+效果；②区域文案从 "/ 7 区" 改为按节点图深度显示；③开局界面加入种子输入框/每日挑战按钮（先占位，逻辑由 R12 接）；④`tests/rogue_visual.gd`/`rogue_inventory.gd` 截图与断言不新增失败 | → R2。**独占 B 集合**，与 R5/R6 并行 |
| **R8** | **深渊变数** | 新建 `rogue_variants.gd`；接线由 R2 的 `reset()`/`enter()` 钩子完成（提 issue 给 W1，或等 R5 后由 W1 一次性落） | ①同种子同层抽出同一变数（100 种子）；②变数效果生效：至少 3 条数值型断言（例如"敌人伤害 ×1.2"后 `e.build_damage_scale` 变化、"魔晶 +20%"后 `clear_room` 的金币数变化）；③变数不进 `players`（全队共享）；④`tests/rogue_variants.gd` | → R2 + R1 契约。可与 R6/R7 并行 |
| **R9** | **诅咒房 / 事件房（数据 + 房间类型）** | 新建 `rogue_curses.gd`；`rogue_map.region_key:50`（新 room 映射到既有 key，见下）；`roguelike.gd` 的 `enter()` 分支（提给 W1） | ①`region_key` 必须把 `"curse"`/`"event"` 映射到**已有** manifest key（`f{n}-talent` 或 `f{n}-treasure`），否则 `ground_regions[...]` 取空 → `region.top` 报错崩图；②诅咒施加后有 debuff 生效断言（如减伤下降、受到伤害上升）；③事件房三选一后 `raid.pending_event` 清空且 `exits` 开放 | → R2。与 R8 并行（不同新文件） |
| **R10** | **三个新房间**（铁匠铺 / 赌徒 / 镜像挑战） | 新建 `rogue_forge_ui.gd`、`rogue_gamble_ui.gd`、`rogue_mirror.gd`；`rogue_map.region_key` 再映射 `forge→shop`、`gamble→treasure`、`mirror→talent`；美术复用既有 `assets/rogue/regions/f{n}-{shop,treasure,talent}-safe-night-v1-3x.png`（**已确认每层各一套**，不需要新图） | ①铁匠铺：花局内魔晶换词条，断言魔晶扣除且**不产生新装备**（不影响 `rogue_stash<=12`）；②赌徒：固定种子 1000 次下注，断言期望返还在 `[0.8,1.2]` 区间且不出现负数魔晶；③镜像：断言镜像与玩家同 `build_*` 数值、被击败后只发一次奖励（无重复击杀）；④三者各自 `--script` 测试 | → R9（共用 room 分支与 UI 骨架时串行；若各自独立可并行） |
| **R11** | **种子分享 / 每日挑战** | 新建 `rogue_daily.gd`、`rogue_seed_ui.gd`；`main.gd` 由 R7 落 UI 钩子（提需求）；`session.gd:1374 launch()` 的 `fixed_seed` 已存在，**不要新增顶层快照字段** | ①`launch(false, X)` 两次，断言 `seed_value==X` 且首层节点图 hash 相同、首个三选一候选相同；②每日挑战种子 = 日期字符串的确定性函数（断言同一天两次相同、跨天不同）；③分享字符串解析：合法种子 / 非法输入被拒（不崩） | → R2 + R7。可与 R8–R10 并行 |
| **R12** | **局外成长树数据层** | 新建 `rogue_growth.gd`；`profile.gd` 的 `data["ashes"]`/`data["growth"]` 由 R3 已建槽位 | ①`RogueGrowth.power(p)` 返回的倍率在 `departure()`(rogue_build.gd:909) 里被正确计入 `build_enemy_hp/build_enemy_damage`（断言：带/不带成长树时两值不同）；②灰烬只在 `settle()`(roguelike.gd:649) 结算一次（连点两次不重复发）；③树节点上限/互斥/前置约束断言 | → R2 + R3。与 R8–R11 并行 |
| **R13** | **成长树 UI + 灰烬入口** | 新建 `rogue_growth_ui.gd`；`main.gd`/`camp_screen.gd`/`home_screen.gd` 挂入口（**B 集合，需 R7 完成后串行**） | ①截图：打开成长树、点亮一级、灰烬扣减、重启后保持；②`rogue_growth_ui` 走窗口模式截图测试（命名 `*_visual` 才会被 `run_all_tests.ps1` 用窗口跑） | → R12 + R7（B 集合串行） |
| **R14** | **Boss 池扩容（逻辑+美术路由）** | 新建 `rogue_boss_pool.gd`；`rogue_combat.gd`(`NAMES:5`、`MOVES:6`、`setup_boss:45`、`visual_move:101`、`begin_skill:149` 的 `MOVES[int(e.rogue_skin)]`)、`boss_effect_art.gd`(`ROGUE:7`、`identity:33`)、`boss_presentation.gd`、`boss_frames.gd` | ①`rogue_skin` **必须保持 int**（`cue()`(rogue_combat.gd:199)、`sound.gd:91/94` 的字符串拼接、`rogue_boss_effects.gd` 都按 int 索引），扩容方式是把 `ROGUE` 从 5 扩到 N 并把 `clampi(...,0,4)` 放宽；②新守层者复用既有 17 个美术 key 中未用的（`bell/thorn/queen/knight/hidden/mirror/ember/moon/earth/storm/abyss/dragon`），**无需新图**；③断言每个新 skin 能 `begin_skill` 0..4 且 `contains()` 命中判定正确 | → R2 + R6（招式表冲突，需与 R6 串行改 `rogue_combat.gd`） |
| **R15** | **Boss 扩容的音频与表现** | `assets/audio/rogue/`、`tools/prepare_rogue_audio.py`、`sound.gd`(`87-94,140-141`)、新建/扩 `tests/*_visual.gd` | ①新 cue 名能被 `sound.gd` 解析并播放（`rogue-%d-%d-%s`、`rogue-%d-phase`、`rogue-%d-fall`）；②截图 5→N 个守层者的预警/释放 | → R14 |
| **R16** | **新学派/新内容（可选，仅在需要时做）** | `ROGUE-BUILD-SYSTEM-DESIGN.md`（表格 + 18.5 小节）、`tools/build_rogue_content.py:57` 的 `assert`、`rogue_content.gd:14/17/23` 的 48 硬编码、`roguelike.gd:339-351 build_directions` 的硬编码武器号 | ①`build_directions` 的 `[6,16,28,38,43]` 等硬编码必须改成按 `family/school` 从内容表推导，否则新学派永远抽不到；②`rogue_content.gd` 的 48 必须改成 `data.weapons.size()`；③生成器 assert 同步；④新增学派后跑 1000 次 `reward_offers` 断言新学派出现概率 > 0 | → R5（`build_directions` 在 A 集合，须串行） |
| **R17** | **文档与收尾** | `ROGUELIKE.md`(10、19、53-59、181 等)、`README.md`、`output/` 计划与本计划 | ①把每层 7 区/25 区/35 区的表述统一到新结构；②新增玩法各写一节含验证入口；③结算文案 `main.gd:3074` 的 "0 / 25 区" 修正 | → 全部 |
| **R18** | **全量回归** | `tools/run_all_tests.ps1`、`tools/verify_rogue_build.ps1` | 见 §4.4：以 `build/exp-report-runs.txt` 的前后对比为准，逐条判定"新增失败=0"；visual 类用窗口模式（本机有 RTX 4080 + OpenGL Compatibility） | → 全部 |
| **R19** | **联机 4 进程验证** | `tests/roguelike_network.gd -- --server --four`、`tests/rogue_build_network.gd` | 新状态（变数/诅咒/成长树/节点图）在 4 客户端下一致；客户端不因缺字段报错；结算只发一次 | → R18 |

### 3.3 串行 / 并行总结（一句话版）

- **严格串行链**：`R1 契约 → R2 session.gd → {R3 profile/server} 和 {R4→R5 节点图}`；`R6 → R14 → R15`（都改 `rogue_combat.gd`）；`R7 → R13`（都改 `main.gd`）。
- **真正可并行**（新文件 + 只读 A/B/C/D 集合）：`R4`、`R8`、`R9`、`R10`、`R11`、`R12`、`R0`。
- **A 集合同一时刻只能一个写者**：R2、R3、R5、R16 必须排队。建议顺序 `R2 → R3 → R5 → R16`。
- **C 集合**：`R6 → R14 → R15`。
- **B 集合**：`R7 → R13`。
- **E 集合**：`R3`(app.py) 与 `R16`(设计文档/生成器) 顺序随意，但都要在 `R18` 前。
- **别做的事**：不要让两个轮次"顺手"改 `roguelike.gd`；不要新增 3 出口（`region.exits` 只有 0/1，且 `configure()` 有合并断言）；不要把节点图塞进每 0.1s 的快照；不要改 `rogue_skin` 的类型。

---

## 4. "先改测试口径还是先改玩法"

**结论：先做一次性"测试口径盘点+标记"，再改玩法；不要在每个玩法轮里顺手改断言。**
理由：现在口径已经错位（`rogue_build_progression` 39 红、`roguelike_seven_rooms` 写死 7/2/boss-7、
`rogue_build_rules`/`rogue_build_pack` 环境红），如果先改玩法，改动会被淹没在既存红色里，
无法判断哪些失败是自己造成的。做法：在 R1 同轮产出 `output/TEST-BASELINE.md`，登记每个被触碰
测试的"当前 checks/failures 组合"与**失败断言原文**，之后每轮只允许"失败数不增加、新增测试全绿"。

### 4.1 必须更新的旧断言（含理由）

| 测试 / 位置 | 旧断言 | 为什么必须改 |
| --- | --- | --- |
| `tests/rogue_build_progression.gd:100` | `rooms==25 and s.raid.cleared==25` | 实际每层 7 区共 **35** 区；旧值来自**每层 5 区**年代 |
| `tests/rogue_build_progression.gd:33` | `area==1 → exits==1 且 room=="talent"`（"每条路线都必须先进第一座圣坛"） | 现在的模板 `route[0]=="combat"`（`roguelike.gd:59`）且 `random_destinations` 从 5 类随机抽 2；这条断言描述的是**更早的设计**。节点图后彻底不成立 |
| `tests/rogue_build_progression.gd:35` | `area==2 → 两个出口都在 [combat, elite]` | 同上，旧模板假设 |
| `tests/rogue_build_progression.gd:37` | `area==3 → exits[0] in [shop,treasure] 且 exits[1]=="talent"` | 同上 |
| `tests/rogue_build_progression.gd:101` | 每层 1 或 2 座圣坛、偶数层 2 座 | 同旧模板 |
| `tests/rogue_build_progression.gd:102` | `talent_choices==14*count and core_choices==count` | 直接由"两座圣坛各两轮"推出，节点图后圣坛数量与位置都变 |
| `tests/roguelike_seven_rooms.gd:37,42` | `route.size()==7`、`room=="boss" iff area==7` | 节点图后节点数变 |
| `tests/roguelike_routes.gd` 的 5 项 | 挑战闸门保底守层者 / 挑战守层者血量 / 跨层商店路线 / 分支连续可行走×2 | 前两项与两阶段/挑战规则耦合；后两项是几何回归，**先判定是既存红还是真的坏了**再决定改或修 |
| `tests/roguelike_bosses.gd`（414 项，`ROGUELIKE.md:98` 记） | 五 Boss 五招轮换 | 二阶段换招表会改变半血后的招式序列，必须改成"阶段一=前 5 招、阶段二=备表" |
| `main.gd:1559`（非测试但同源） | `"第 %d / 5 层 · 第 %d / %d 区" ... AREAS_PER_FLOOR` | 节点图后要按深度显示 |
| `main.gd:3074` | `"魔境闯关 · 已完成 %d / 25 区"` | 旧值 |
| `rogue_combat.gd` 相关断言 | 若弹幕视觉改了 `visual_move`/fx 名，需同步断言 | 取决于 R0 实现 |

### 4.2 必须保持通过的（回归红线，不允许新增失败）

- `tests/rogue_build_growth.gd`（4066/0）、`tests/rogue_build_system.gd`（440/0）、`tests/roguelike_seven_rooms.gd`（1856/0，**允许按 §4.1 更新断言但必须先绿再改**）。
- 战役回归：`tests/expedition.gd`(79/0)、`tests/combat.gd`(78/0)、`tests/systems.gd`、`tests/attributes.gd`。
- 存档与联机：`tests/rogue_build_network.gd`、`tests/roguelike_network.gd`（0 error 日志）、`rogue_chest_rewards.gd`、`rogue_inventory.gd`、`rogue_equipment.gd`。
- 表现回归：`roguelike_vfx.gd`、`roguelike_minion_vfx.gd`、`roguelike_attack_timing.gd`、`roguelike_animations.gd`。
- **特别红线**：`s.raid.reward_drops` 的"每人武器+装备各一份"（`rogue_build_progression.gd:71` 的 `count*2`）与新房间的奖励发放不能互相污染。

### 4.3 统计类断言怎么处理

现状：`tests/rogue_build_growth.gd:64` 的
`counts[0] in range(140,261) and counts[1] in range(420,581)` 是**宽区间**（期望 200/500，容差约 ±30%），
本次实测样本 `[213, 500]`，**依然通过**——不必为它做改造。

规则：
1. 任何**新**随机玩法（赌徒、变数、诅咒抽卡、节点图）都**不要**写点估计断言，写成区间 + 固定种子 + 足够样本（≥1000），并断言"抽样只由 `s.rng` 驱动"。
2. 已有统计断言**只允许放宽、不允许收紧**；如果节点图/新房间改变了 `roll_tier` 的调用次数，必须重新实测再登记新区间，并在 `TEST-BASELINE.md` 写清改动原因与实测样本值。
3. 所有新增随机测试必须能用固定种子复现；把种子写进断言失败信息里。
4. 不要为了通过而 `p.build_chest_attribute_drops=0` 之类地"重置状态"——那会掩盖真实回归；用固定种子即可。

### 4.4 推荐门禁（替代"全绿"）

```
# 每轮结束：只跑本轮的定向测试 + 回归红线
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/<本轮测试>.gd --quit-after 600
# 每 3~4 轮：全量并做前后对比
tools/run_all_tests.ps1     # 产出 build/exp-report-runs.txt
# 对比脚本要求：新报告中"failures > 0"的测试集合，不得超出 TEST-BASELINE.md 登记的集合
```

`tools/verify_rogue_build.ps1` 因为命中任意 `ERROR:` 就 throw，**在 progression 修绿之前不能当门禁**；
要么在 R5/R17 中把它修绿，要么新增一个"基线错误数对比"的包装脚本替代它。

---

## 5. 风险清单

### 5.1 存档兼容（profile.json + 服务端）

- **`profile.gd:31-50 apply_data` 是"全有或全无"**：`if parsed.get("version",0)==1:` 不成立时**整段跳过**，
  然后直接被 `sanitize_storage()` 用默认值覆盖 → 用户丢档。所以**绝对不能把 `data.version` 改成 2**，
  除非同时改成"按版本分支 + 老版本走 v1 路径 + 新增键取默认"。
- 推荐方案：**保持 `version == 1`**，只新增键（`ashes`、`growth`），用 `if not parsed.has("ashes")` 补默认。
  这样老客户端、老服务端、云存档三方都还能读。
- **`server/app.py:409` 硬校验 `data.get('version') != 1`** → 改版本号必须同轮改 `server/app.py`，否则
  联机账号上传一律 400 `存档格式错误`。**这也是"保持 version 1"更省事的理由。**
- `server/app.py:420-431` 的 `attributes` key 白名单与"属性点不超等级预算"校验 → **灰烬/成长树不能塞进
  `attributes`**，否则被 400 拒；必须放独立顶层键。
- `apply_data:37-39` 逐键做 `typeof(parsed[key]) == typeof(data[key])` 类型匹配 → 新增键**必须先在
  `_init()` 里给出同类型默认值**，否则用户第一次存档时该键被静默丢弃。int/float 混用要像 41-43 行那样单独纠正。
- `online_service.gd:77-82` 上传的是 `profile.data.duplicate(true)`，用 `JSON.stringify` 比较 dirty →
  新字段必须是 JSON 可序列化（不能放 `Vector2`/`Object`/`NaN`/`INF`）。
- 迁移验收必须包含：**老档（无新键）→ 读 → 存 → 再读**，且 `coins/xp/talents/attributes/warehouse/pocket/bags/home` 逐项不变。

### 5.2 联机快照同步（新字段必须能随快照走）

- `session.gd:1467` 的快照是**白名单式顶层数组**：`[players,enemies,bullets,world_drops,chests,shrines,elapsed,objectives,threat,results,map_id,raid,ruins.sites]`。
  **放进 `s.raid` 或 `players[*]` 的字段自动同步**；放进新对象（如 `s.rogue_graph`）**不会**同步。
- `session.gd:1487-1488` 只接受 `data.size() in [12,13]` → 新功能别新增顶层元素。
- `session.gd:1505` 是 `players=data[0]` **整表替换**，所以 `players` 里的字段可以随便加（整表传）。
- 客户端重建地图只用 `floor/area/room + seed_value`（`session.gd:1495-1497`），
  所以 `seed_value` 必须全队一致；每日挑战的种子**必须由房主算好并随 `begin` RPC 下发**
  （`launch()` 已把 `seed_value` 传给 `begin.rpc`），**不能让每个客户端各按本地日期算**（时区/跨零点会错位）。
- `roguelike.gd:596-614 random_destinations` 用 `s.rng`，而 `s.rng.seed = seed_value+71`（`session.gd:1415`）
  只在 `begin()` 里设一次；新随机代码**不得重置 `s.rng.seed`**，否则联机两侧分叉。
- 表现层（弹幕、VFX、Boss 二阶段演出）走 `s.broadcast_combat`（`session.gd:3037`）与
  `raid["visual_effects"]/["visual_missiles"]`（`session.gd:1464-1466`，每 0.1s 重发）；**状态真相不要走这里**。
- **明确不要做的事**：把节点图整张图放进 `raid` 并让每 0.1s 快照携带。要么只放当前节点 + 邻接，
  要么客户端用 `seed_value + floor` 本地重建同构节点图（推荐：`RogueGraph.build` 是确定性的，两端可各自算）。
- 音频 cue 名依赖 `rogue_skin` 为 int（`rogue_combat.gd:199`、`sound.gd:87-94`）。Boss 池扩容时若把
  `rogue_skin` 改成 String key，会同时打断 `MOVES[int(e.rogue_skin)]`(`:149`)、`update_boss`(`:220,239`)、
  `release`(`:242`)、`bolt`(`:256`)、`defeated`(`:359`) 与音频表 —— **这是本次最容易踩的坑**。

### 5.3 16000+ 项基线的具体风险点

1. **`rogue_build_progression` 已 39 红**：不先处理它，任何"全量对比"都失去意义（新增失败会被 39 掩盖）。
2. **`rogue_build_rules` / `rogue_build_pack` 是环境/素材红**（`W001` 图集缺失、`main.gd` "Compilation failed" 加载报错）：
   `rogue_build_pack` 的 "Compilation failed" 在本机实测出现，**如果它不是环境偶发而是真编译错，任何脚本轮次都无法验证**——
   必须在 R1 就复核（`--check-only` 或看该 log 的完整错误），否则后面所有验收都不可信。
3. **`roguelike_routes` 的 2 项"分支连续可行走"是几何回归**：节点图只改节点拓扑不该动几何；
   若这 2 项在改动后**变化**，说明 `rogue_map.configure` 被误动（`region_key` 映射错 → 用了错的 ground profile）。
4. **`rogue_map.configure:95` 有 `assert(joined.size()==1,"Both level paths must join the same floor")`**：
   给新房间用错 region key 会直接触发断言崩溃（不是普通失败），而且**联机时只在客户端崩**。
5. **`exit_position(index)` 只支持 0/1**（`region.exits` 来自 `ground-manifest.json`，每 key 两个出口）：
   不要试图给节点图做 3 个出口。
6. **60s/测试的超时**：`run_all_tests.ps1` 每个测试 60s 上限，`city` 已经 TIMEOUT；
   新增的重型测试（节点图 1000 种子抽样、赌徒 1000 次下注）要控制规模，否则以 TIMEOUT 形式"红"。
7. **`*_visual` 走窗口模式**：新截图测试必须**以 `_visual` 结尾**才会被脚本用窗口跑（否则在 headless 下拍照失败）。
8. **`rogue_build_content.json` 是生成物**：手改 JSON 会被下次 `build_rogue_content.py` 覆盖，
   且脚本第 57 行 `assert == 252` 会在内容变更时直接失败。
9. **`roguelike.gd` 与 `main.gd` 有 `revision` 版本号防重放**（`choose:565`）：
   新增 UI 动作（铁匠/赌徒/事件）**必须携带并校验 `revision`**，否则会出现"过期点击生效"这类只在联机复现的 bug。
10. **`settle()`(`roguelike.gd:649`) 是唯一结算点**：灰烬、每日挑战记录都要在这里且只发一次（有 `raid.ended` 守卫）；新房间不得绕过它。

---

## 6. 每轮的"可交付中间态"（做到哪一步可以停）

| 停在哪 | 可交付状态 | 绝对不能停的状态 |
| --- | --- | --- |
| R0 后 | 弹幕视觉已改且命中判定有比对证据；可发布 | — |
| R1 后 | 只有一份契约文档，代码零改动；**完全可停** | — |
| R2 后 | 新字段已在 `reset()` 初始化、`snapshot` 往返通过；玩法未变；可发布 | 只加了 `reset` 没做往返测试 |
| R3 后 | 老档安全、新键落盘、服务端放行；游戏行为未变；可发布 | `version` 改了但服务端没改；新键缺默认类型 |
| R5 后 | 节点图已接管推进，5 层每层 7–9 节点、每层 1 boss；`roguelike_seven_rooms`/`roguelike_routes` 按新口径绿；旧房间类型全部可达；**可发布** | `roguelike.gd` 半迁移（`route[]` 与新图并存、`new_floor` 没删干净） |
| R6 后 | 二阶段换招表生效，第一阶段行为不变；可发布 | 阶段二用了未实装的招式名（会走 `MOVES[key].find(move)<0` 静默失败） |
| R7 后 | HUD 能显示变数占位与节点深度；可发布 | — |
| R8/R9/R10 各自后 | 每条都是"新增房/变数已可玩 + 独立测试绿"，其余系统不受影响；**可分别发布** | 新房间用了不存在的 region key（会崩图） |
| R12 后 | 成长树数据层生效、灰烬结算正确，但无 UI（可用测试改存档验证）；可发布 | 灰烬只减不加/重复发放 |
| R13 后 | 成长树可玩闭环（赚灰烬→点树→下局生效）；**这是一个自然的里程碑，可停** | UI 改了 `main.gd` 却与 R7 的改动冲突 |
| R14/R15 后 | Boss 池扩容完成、音频齐、截图齐；可发布 | 只扩了池没做音频（`sound.gd` 播放空 cue 不会报错，但会静默无音） |
| R16 后 | 新学派能被抽到（`build_directions` 已去硬编码）；**可停** | 只改了 JSON 没改生成器/设计文档（下次生成回滚） |
| R17/R18 后 | 文档同步 + 全量报告与基线逐条比对；**这是最终交付态** | 用"全绿"当结论 |

**最小可用里程碑（若预算被砍）**：`R1 → R2 → R4 → R5`：节点图层重做完成且旧玩法全部可达。
**第二里程碑**：`+ R3 → R12 → R13`：局外成长闭环。
**第三里程碑**：`+ R6 → R14 → R15`：Boss 深度。
`R8/R9/R10/R11/R16` 均可独立增补，不阻塞里程碑。

---

## 附：委派时的提示词要点（给父 Agent 用）

每个子智能体必须收到：
1. 本文件路径 `output/ROGUE-EXPANSION-EXECUTION-PLAN.md` 与其负责的轮次号；
2. **文件所有权表（§3.0）**，并明确"你只许改这些文件，其它一律只读；需要改别处就写待接线清单返回"；
3. **引擎绝对路径**（不在 PATH）：`D:\game\CrimsonTide-godot\Godot_v4.7.2-stable_win64_console.exe`；
4. 该轮的**具体验收命令**与**基线数字**（§0 表格里对应的一行），要求返回"命令 + 原始 checks/failures 行"；
5. 该轮结束后要回传：改了哪些文件哪些函数、跑了什么命令、原始输出、遗留的待接线清单。
