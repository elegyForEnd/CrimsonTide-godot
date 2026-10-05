# R9 · 诅咒房 / 事件房数据层（交付记录）

- **轮次**：R9（`output/ROGUE-EXPANSION-EXECUTION-PLAN.md` §3.2 R9 行）
- **交付者**：W6（F 集合新文件），日期 2026-10-05
- **本轮纪律**：只新建自己的文件；`roguelike.gd` / `session.gd` / `rogue_map.gd` / `rogue_field.gd` / `main.gd` / `rogue_build.gd` / G 集合**一律未动**；未 `git commit`；未改任何既有 `.md`。
- **契约遵守**：`output/ROGUE-CONTRACTS.md` v1 §2/§3/§5/§6/§7/§8/§9。跨文件引用**全部走 `preload`**（不依赖 global class cache，见 `output/R2-WIRING.md` 的 stale-cache 提示）。

## 1. 交付文件

| 文件 | 说明 |
| --- | --- |
| `scripts/rogue_curses.gd` | `RogueCurses`：10 条诅咒纯数据 + 聚合/上限/同池折算/成对回报/复现抽样 |
| `scripts/rogue_events.gd` | `RogueEvents`：9 个事件房（22 个选项）+ 纯函数结算 + `pending_event` 生命周期 |
| `tests/rogue_curses.gd` | 218 项断言 |
| `tests/rogue_events.gd` | 484 项断言 |

**没有**任何既有脚本引用这两个模块（`grep RogueCurses|RogueEvents|rogue_curses|rogue_events` 只命中 R9 自己的 4 个文件，外加 R2 在 `roguelike.gd:46` 写的字段名 `p.rogue_curses=[]`）→ 本轮是**纯新增**，不可能改变既有玩法路径。

## 2. 设计要点（为什么这样实现）

1. **诅咒是个人状态，变数是全队状态**：id 列表放 `p["rogue_curses"]`（随 `players` 整表快照同步），`s.raid.curse_serial` 只做施加序号。
2. **不新开乘数**：诅咒的减益被折算成**既有减伤池里的一项负贡献**。
   - `damage_taken_scale(p)`（契约 §5 冻结的出口）= `1 + Σ damage_taken`（受 `CAPS.damage_taken=0.60` 约束）。
   - `defense_penalty(p)` = `clampf(1 - 1/scale, 0, MAX_POOL)`，供 `session.incoming_damage` 与 `RogueBuild.conditional_defense` **同池相减**：
     `(1 - clampf(conditional_defense(s,p) - defense_penalty(p), 0.0, RogueCurses.MAX_POOL))`
   - 两者严格等价（未触池上限时），测试里逐条断言等价性与单调性；**不开第二层乘数**。
3. **上限全部生效**：`CAPS` 覆盖 9 个 effect 键，`aggregate()` 无论喂进来多少条（含重复 id、未知 id）都必须过上限；`count()` 忽略未知 id。
4. **诅咒必须成对**：表内每条都带 `boon`（`gold` / `attribute_points` / `gear_reward`），`apply_pair()` 一并发放；`gear_reward` 走既有 `build_reward_queue` 三选一，**不新造装备通道**（不会撑爆 `rogue_stash<=12`）。
5. **确定性**：`resolve(event_id, index)` 不读 `s`、不用 RNG → 同参数同结果；事件房因此**不消耗** `s.rng`。
   `RogueCurses.roll()` 与 `RogueEvents.roll_offer()` 各**恒定消耗 1 次 `s.rng.randi_range`**，是同种子可复现的唯二新随机点。
6. **安全边界**：事件代价永远不能让玩家死亡或负魔晶 —— `commit()` 里 `hp` 下限 1.0、`gold` 下限 0；金/血/血瓶/诅咒位不足的选项由 `available()` 拦下，`apply()` 返回 false 且**保留 `pending_event`** 让玩家改选。
7. **JSON 可序列化**：所有返回字典只含 `int/float/bool/String/Array/Dictionary`；测试对每一行做 JSON 往返结构比较。

## 3. 验收证据（实跑原始输出）

引擎（**不在 PATH**）：`D:\game\CrimsonTide-godot\Godot_v4.7.2-stable_win64_console.exe`
命令模板：`& <exe> --headless --path . --script tests/<name>.gd`
日志：`build/r9-curses/*.out.txt` / `*.err.txt`（`final-*` 是本轮最后一次复跑）

| 测试 | 结果 | errorLines |
| --- | --- | --- |
| `tests/rogue_curses.gd`（本轮新增） | **ROGUE CURSES: 218 checks, 0 failures** | 0 |
| `tests/rogue_events.gd`（本轮新增） | **ROGUE EVENTS: 484 checks, 0 failures** | 0 |
| `rogue_wiring`（R2 的门禁） | ROGUE WIRING 113 checks / 0 failures | 0 |
| `rogue_build_growth` | BUILD GROWTH: 4066 checks, 0 failures | 0 |
| `rogue_build_system` | ROGUE BUILD: 440 checks, 0 failures | 0 |
| `roguelike_seven_rooms` | SEVEN ROOMS 1856 checks / 0 failures | 0 |
| `roguelike_routes` | ROGUE ROUTES 5219 checks / **5 failures** | 10 |
| `rogue_build_progression` | BUILD PROGRESSION 533 checks / **41 failures** | 82 |
| `systems` | SYSTEM TESTS: 10812 checks, 0 failures | 0 |

新增断言覆盖（逐条对应派单验收要求）：
- ① 同 (seed, 层) 抽取确定 → `Same seed yields the same curse` / `Same seed rolls the same event offer`；
- ② ≥1000 样本覆盖 + 区间断言 → 诅咒 1000 次抽样每条落在 `[40,180]` 且全被抽到；事件 1000 次抽样每个落在 `[50,200]` 且全被抽到；
- ③ 上下限生效 + 与既有池合成单调 → `Aggregate clamps at the damage-taken cap` / `move-speed cap` / `Curses only ever reduce the shared defense pool` / `Reduced defense never lowers incoming damage`；
- ④ `resolve()` 类型/范围正确、非法 `index` 安全返回 `{}`、`apply()` 拒绝非法/不可用且保留 pending；
- ⑤ 成对出现 → `Curse pays a symmetric boon`（10 条全覆盖）+ `Curse room always pays something back` + `Curse room never pays only a penalty`；
- ⑥ 不含命中判定几何字段 → `FORBIDDEN` 列表对 effect 键、delta 键、summary 键逐条断言。

## 4. 与基线的偏差归因（`output/TEST-BASELINE.md`）

| 测试 | R1 基线 | 本轮实测 | 归因 |
| --- | --- | --- | --- |
| `rogue_build_progression` | 505 / 39 | 533 / **41** | **并发写者**，非 R9。R2 按契约 §6.2 把 `Variants.roll(s)` 插到 `roguelike.gd:99`（`exit_choices` 之前）→ `s.rng` 序列改变 → 基于种子的 route 抽样变化。失败分解由 `10/10/8/7/2/2` 变为 `10/10/9/8/2/2`，只多出「Fourth area offers supplies or a second sanctuary」+1、「Every floor has one or two sanctuaries」+1 两组陈旧断言；这两组本就是 R5 要统一移植的旧「每层 5 区」口径 |
| `roguelike_routes` | 5219 / 5 | 5219 / 5 | 一致（既存红） |
| 其余 7 项 | — | 与基线逐字一致 | 无新增失败 |

R9 自身不可能引入上述偏差：R9 的 4 个文件不被任何既有脚本引用（见 §1 的 grep 证据），且两个新测试 0 failures。

## 5. 内容全表

### 5.1 诅咒（10 条，`RogueCurses.table()`）

| id | 名称 | 效果 | 对称回报 |
| --- | --- | --- | --- |
| CU01 | 血蚀 | 受伤 +15% | 魔晶 +90 |
| CU02 | 铁枷 | 移速 -18 | 装备三选一 |
| CU03 | 贪婪之握 | 魔晶收入 -30% | 局内属性 +1 |
| CU04 | 奸商印记 | 商店价格 +35% | 魔晶 +120 |
| CU05 | 空箱咒 | 宝箱掉率 -40% | 装备三选一 |
| CU06 | 干涸 | 治疗 -30% | 魔晶 +110 |
| CU07 | 破瓶 | 血瓶容量 -25 | 局内属性 +1 |
| CU08 | 迷雾 | 视野 -35% | 装备三选一 |
| CU09 | 迟滞 | 技能冷却 +25% | 魔晶 +130 |
| CU10 | 碎盾 | 受伤 +10%、治疗 -15% | 魔晶 +150 |

单玩家上限 `MAX_CURSES=4`；同一条不可重复；上限键见 `CAPS`。

### 5.2 事件房（9 个 / 22 选项，`RogueEvents.table()`）

`EV01 血祭石阶`(1F,3) · `EV02 锈蚀商栈`(1F,3) · `EV03 迷途魂灯`(1F,3) · `EV04 拾遗老树`(2F,3) ·
`EV05 深渊回声`(2F,2) · `EV06 贪婪秤盘`(3F,3) · `EV07 蚀骨温泉`(3F,3) · `EV08 无名祭坛`(4F,3) · `EV09 星屑坠地`(4F,2)
（括号内为：解锁层 / 选项数）

## 6. 待接线清单（提交者 W6：轮次 R9）

> 以下**全部是别人的文件**，R9 只回传，未改。锚点行号以 2026-10-05 当次工作副本为准。

### 6.1 诅咒的实际生效（W1）

```
- 目标文件: scripts/session.gd
- 目标函数/锚点: incoming_damage() 的魔境分支，
  现为 `if roguelike.active(self): return maxf(0,damage)*(1-stat_defense(p))*(1-RogueBuild.conditional_defense(self,p))`
  （R1 时在 :497；R2 之后行号请自行定位，锚点用上面这行原文）
- 期望插入代码:
    var pool := clampf(RogueBuild.conditional_defense(self,p)-RogueCurses.defense_penalty(p),0.0,RogueCurses.MAX_POOL)
    return maxf(0,damage)*(1-stat_defense(p))*(1-pool)
- 依赖的契约: §5 RogueCurses.damage_taken_scale（冻结出口）；R9 **追加** defense_penalty(p) 作为"同池表达"。
  两种取用方式请 W1 二选一并写进 CHANGE-LOG：
  (a) 同池相减（推荐，见上）：不开第二层乘数；
  (b) 直接乘 `* RogueCurses.damage_taken_scale(p)`：实现最短，但会与 conditional_defense 形成乘算。
- 验收断言: tests/rogue_curses.gd 的 "Penalty is the same-pool equivalent of the multiplier" /
  "Curses only ever reduce the shared defense pool" / "Reduced defense never lowers incoming damage"
- 未接线时的临时状态: 诅咒能被施加、能被快照同步、能在 HUD 显示，但**不产生任何数值影响**（玩法不生效）
```

```
- 目标文件: scripts/roguelike.gd
- 目标函数/锚点: clear_room() 的金币发放
  `p.rogue_gold+=25+int(s.raid.floor)*10+(50 if s.raid.get("challenge",false) else 0)`（R1 :260 / 现 :277）
- 期望插入代码: 右值乘 `RogueCurses.personal_reward_scale(p)`（roundi 后取整）
- 依赖的契约: §5 RogueCurses.reward_scale（提供；个人版为追加函数 personal_reward_scale）
- 验收断言: tests/rogue_curses.gd 的 "Reward scale saturates instead of growing without bound"
- 未接线时的临时状态: 带诅咒的玩家拿到的补偿不增加（仍可玩）
```

```
- 目标文件: scripts/roguelike.gd
- 目标函数/锚点: roll_offers() 的商店定价 `offer.price=50 if ... else 65+int(s.raid.floor)*10`（R1 :476 / 现 :493）
- 期望插入代码: `offer.price=roundi(float(offer.price)*(1.0+float(RogueCurses.stat_delta(p).get("shop_price",0.0))))`
- 依赖的契约: §5 RogueCurses.table()/stat_delta
- 验收断言: tests/rogue_curses.gd 的表结构断言 + shop_price 上限断言
- 未接线时的临时状态: 商店不涨价（仍可玩）
```

```
- 目标文件: scripts/roguelike.gd
- 目标函数/锚点: 宝箱属性灵晶掉率 `var chance := .5 if s.raid.room=="boss" else .2`（R1 :378 / 行号请按锚点原文定位）
- 期望插入代码: `chance*=maxf(0.1,1.0+float(RogueCurses.stat_delta(ally).get("chest_drop",0.0)))`
- 依赖的契约: §5；**注意这是个人掉落，必须用 ally 而不是发箱人**
- 验收断言: tests/rogue_curses.gd 的 chest_drop 上限断言
- 未接线时的临时状态: 宝箱掉率不变
```

```
- 目标文件: scripts/rogue_build.gd
- 目标函数/锚点: heal()（R1 :134）`var wanted := minf(target.max_hp-target.hp,target.max_hp*ratio*(1.0+minf(.3,amp)))`
- 期望插入代码: `ratio*=maxf(0.2,1.0+float(RogueCurses.stat_delta(target).get("heal_scale",0.0)))`（放在 wanted 计算之前）
- 依赖的契约: §5；heal_scale 上限 -0.60 → 最低 40% 治疗量
- 验收断言: 追加断言（建议 R18 在 tests/rogue_curses.gd 外补一条集成断言）
- 未接线时的临时状态: 治疗量不变
```

```
- 目标文件: scripts/rogue_build.gd
- 目标函数/锚点: ready()（R1 :109，冷却判断）/ commit_flask()（R1 :1002，血瓶消耗）/ tick()（R1 :632）
- 期望插入代码: 冷却 seconds 乘 `(1.0+cooldown)`；血瓶容量用一次性 choke point
  `p.flask=minf(maxf(0.0,100.0+float(RogueCurses.stat_delta(p).get("flask_max",0.0))),p.flask)`
- 依赖的契约: §5；cooldown 上限 +0.60 / flask_max 上限 -50
- 阻塞点: 血瓶上限没有唯一 choke point（仓库里 `minf(100,...)` 有 4 处以上），**建议 W1 先给一个唯一入口再接线**，
  否则宁可本轮只接 cooldown，flask_max 保持"表内有效果、暂不生效"
- 未接线时的临时状态: 冷却/血瓶容量不变
```

```
- 目标文件: scripts/session.gd
- 目标函数/锚点: 移速合成 `speed+=float(p.get("rogue_speed",0))`（R1 :2613）
- 期望插入代码: `speed+=float(RogueCurses.stat_delta(p).get("move_speed",0.0))`
- 依赖的契约: §5；move_speed 上限 -60（与 p.rogue_speed 同一加法池，不是乘数）
- 未接线时的临时状态: 移速不变
```

```
- 目标文件: （G 集合，W7 独占）battlefield.gd / 表现层
- 目标: vision 效果目前**只存在于数据表**，没有任何接线点。建议 R9 之后仍**不接**，
  由 W7 决定是否做视野遮罩；若不做，请 W8 在 CHANGE-LOG 标注 "CU08 迷雾的 vision 字段为装饰性，无实际效果"
- 未接线时的临时状态: 迷雾只显示在 HUD，不影响画面
```

### 6.2 两个新房间的接线（W1，依赖契约 §7）

```
- 目标文件: scripts/rogue_map.gd
- 目标函数/锚点: region_key()（:50-54）的 `if room in ["shop","treasure","talent"]`
- 期望插入代码: 按契约 §7.2 ① 的冻结映射扩成
  {"curse":"f{n}-treasure","event":"f{n}-talent","forge":"f{n}-shop","gamble":"f{n}-treasure","mirror":"f{n}-talent"}
  （必须映射到 **已存在于 ground-manifest.json** 的 key，否则 ground_regions 取空 → 崩图）
- 依赖的契约: §7.2 ①
- 验收断言: tests/rogue_graph.gd / 新增房间用例的"新房间几何合法"；R9 无法验（属 W1/W4）
- 未接线时的临时状态: 新房间会被当成战斗长房（不崩，但不是设计意图）
```

```
- 目标文件: scripts/roguelike.gd
- 目标函数/锚点: enter() 的 `room not in ["shop","treasure","talent"]`（现 :86）
- 期望插入代码: 扩成 `room not in ["shop","treasure","talent","curse","event","forge","gamble","mirror"]`
- 依赖的契约: §7.2 ②（漏这一处，新房间会被 configure(..., long_room=true) 当战斗房）
- 未接线时的临时状态: 同上
```

```
- 目标文件: scripts/roguelike.gd
- 目标函数/锚点: enter() 的 `elif s.raid.room in ["treasure","talent"]: clear_room(s)` 分支（现 :118 附近）
- 期望插入代码（curse 房，**只给 W1 的两个调用，不要新增 phase**）:
    RogueCurses.apply_pair(s,p,RogueCurses.roll(s,p.get("rogue_curses",[])))   # 施咒 + 对称回报
    clear_room(s)                                                              # 复用既有清房/宝箱流程
  或（event 房）:
    RogueEvents.roll_offer(s)      # 写 raid.pending_event，phase 仍复用 clear_room / rogue_reward
- 依赖的契约: §5 RogueCurses.roll / apply_pair、RogueEvents.roll_offer；§7.3"不要新增 phase 名"
- 验收断言: tests/rogue_curses.gd 的 apply_pair 组；tests/rogue_events.gd 的 pending 组
- 未接线时的临时状态: 房间池里没有 curse/event（数据层可跑、玩法不可达）
```

```
- 目标文件: scripts/roguelike.gd
- 目标函数/锚点: choose()，在 `if int(payload.get("revision",-1))!=int(s.raid.revision): return` 之后
- 期望插入代码:
    if kind=="rogue_event":
        if RogueEvents.matches_revision(s,int(payload.get("revision",-1))):
            RogueEvents.apply(s,p,int(payload.get("index",-1)))
        return
- 依赖的契约: §9.2（UI 动作必须带并校验 revision）；RogueEvents.apply() 成功后会把 raid.revision +1
- 验收断言: tests/rogue_events.gd 的 "matches_revision rejects a stale revision" /
  "Resolving an event advances raid.revision"
- 未接线时的临时状态: 事件房没有可点的 UI 动作（玩家无法结算）
```

```
- 目标文件: scripts/main.gd（W2）
- 目标: HUD 一行显示 `RogueCurses.summary(p)`（`{id,name,desc}` 数组，已保证 JSON 可序列化）
- 依赖的契约: §5 追加函数 summary（R9 提供）
- 未接线时的临时状态: 诅咒对玩家不可见（有数值效果但无提示）
```

## 7. 需要仲裁 / 请 W8 记 CHANGE-LOG 的两点

1. **契约 §5 只冻结了 `damage_taken_scale(p)`**；R9 追加了 `defense_penalty(p)`（同池表达）、
   `personal_reward_scale(p)`、`aggregate(id_list)`、`roll(s,exclude)`、`summary(p)`、`apply_pair()`、`caps()`、`count()`、`has()`。
   全部是**纯追加**，不改名、不改类型、不改默认值。
2. **`raid.pending_event` 多了一个 `"id"` 键**（契约 §2 只写了 `{"offer":Array,"revision":int}`）。
   结算必须知道事件 id，因此 R9 把 id 一并写进 pending（追加字段，向后兼容）。
   若仲裁要求严格保持两键格式，替代方案是让 `offer[i]` 各自带 `event_id`——请指示，R9 可在一轮内改。
3. **RNG 配方**：`RogueCurses.roll()` 与 `RogueEvents.roll_offer()` 是同种子可复现的**新随机点**，
   不在 `enter()` 的 `[抽变数]→[exits]→[spawn_wave]` 配方里（它们在房间分支内触发）。
   按契约 §6.2.3 属允许范围，但建议 W8 把它登记进配方文档，避免后续轮次误判为"擅自新增 s.rng 消耗"。

## 8. 未做 / 未核实

- 未做任何**玩法可达性**验证（房间不在池子里、没有 region key 映射、没有 UI 动作）→ 属 W1/W2/W4 的接线范围；
  R9 只交付数据层与纯函数，并已把全部接线点写成 §6 的清单。
- `vision` / `flask_max` 两个效果键目前**只有数据、没有唯一 choke point**，已在 §6.1 明确标注为"待 W1 定入口"。
- 未跑 `-- --server --four` 的多进程联机用例（`roguelike_network` / `rogue_build_network`），
  与 R1 基线口径一致（单跑噪声，不计入新增失败）。
