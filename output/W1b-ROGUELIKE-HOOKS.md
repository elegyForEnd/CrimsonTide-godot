# W1b · `roguelike.gd` 钩子接线（玩法层落地）

- **轮次**：W1b（顶层调度指派）；日期 2026-10-05；工作副本 `D:\game\CrimsonTide-godot`
- **写入面**：`scripts/roguelike.gd`（主）、`tests/rogue_hooks_roguelike.gd`（新建）、
  `tests/rogue_build_progression.gd`（**两处过期断言按新语义迁移**，见 §4）。
  `scripts/rogue_map.gd` 只读复核（C3 已由 R5 完成，无需改动）。
- **未碰**：`session.gd`(W1a)、`profile.gd`、`main.gd`(W2)、`rogue_combat.gd`/`boss_choreography.gd`/`sound.gd`(W3/R14)、
  G 集合(W7 弹幕轮)、全部 `rogue_*.gd` 数据层模块（只读 `preload` 调用）。
- **引擎调用**：`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/<n>.gd`

---

## 1. 落地清单（before → after）

| 钩子 | 位置 | before | after |
|---|---|---|---|
| 掉落品质 `loot_tier` | `roll_tier()` | 权重表命中哪档就是哪档 | `clampi(tier + round(mods.loot_tier), 0, 5)`；**rng 抽取次数不变**（仍是那一次 `randi_range(1,100)`） |
| 房间金币 `gold` + 诅咒补偿 | `clear_room()` | `p.rogue_gold += 25+floor*10+(50 if challenge)` | `+= max(0, scale_int(基线, (1+mods.gold) * RogueCurses.personal_reward_scale(p)))` |
| 商店定价 `shop_price` | `roll_offers()` | `price = 65+floor*10`，血瓶 `45` | `max(1, scale_int(基线, 1+clamp(shop_price,-0.9,3.0)))` |
| 经验 `xp_gain` | `spawn_wave()` / `spawn_minion()` / `settle()` | `build_xp_reward = 20` / `6│2`；`xp = 35+cleared*15` | 同式乘 `(1+xp_gain)`，`scale_int` 取整且 ≥1 |
| 精英率 `elite_chance` | `spawn_wave()` | 精英房里 `i<2` 才升精英 | `i < 2 + round(max(0,elite_chance)/0.12)`；**不新增 rng 抽取**（避免扰动种子流） |
| 宝箱灵晶掉率 `chest_drop` | `loot_interact()` | `chance = .5│.2` | `chance = clamp(基线*(1+mods[ally].chest_drop),0,1)`；**用开箱人自己的诅咒**；仍是 1 次 `randf()` |
| 每日挑战标记 | `reset()` | 无 | `raid.daily = (launched_seed == RogueDaily.global_daily_seed())`（UTC 口径，种子由房主随 `begin` 下发；客户端只是比对，不各算本地日期） |
| 成长树起始资源 | `reset()` | `rogue_gold=60`；`rerolls` 原样 | `rogue_gold = 60 + power.start_coins`；`rerolls += power.start_rerolls`（无 profile 通道时 power 全 0 → 逐位不变） |
| 灰烬结算 | `settle()` | 无 | 在 `ended=true` **之后**逐人 `RogueGrowth.grant(s,p)`（唯一结算点、只发一次） |
| 每日打卡 | `settle()` | 无 | `record_daily()`：**仅当 `profile.data` 已有 `daily` 键时**写入（该键仍属 profile.gd 的接线面，见 §5） |
| 诅咒回廊 | `enter()` → `open_room()` | 新房间只是"安全空房" | 每人 `RogueCurses.apply_pair(roll(s, 自己已有的 id))`：一条诅咒 + 对称回报 |
| 幽暗异事 | 同上 | — | `RogueEvents.roll_offer(s)` 写 `raid.pending_event`（带 revision） |
| 游方锻炉 / 赌徒营帐 | 同上 + `refresh_dedicated()` | — | `raid.pending_forge` / `raid.pending_gamble` 报价，**在 `clear_room()` 之后重算**以保证报价的 revision 是活的 |
| 镜像试炼 | 同上 + `mirror_action()` | — | 两步：第一次点击 `mirror_accept`（state.active=true），第二次 `mirror_resolve` 结算并置 `p.rogue_mirror_used` |
| 四个新动作 | `choose()` | — | `rogue_event` / `rogue_forge` / `rogue_gamble` / `rogue_mirror`，**全部在既有 `revision` 防重放守卫之后**，未知/过期点击零副作用 |
| 房间增量落地 | `apply_room_delta()` | — | `gold / forge_points / forge_level / bind / weapon_tier / ash / gear_reward`；货币夹 ≥0；`weapon_tier` 同步 `refresh_max_hp` + `rogue_inventory_revision`（R10 标注的高风险项） |
| 守层者池（R14 转交） | `spawn_wave()` | `setup_boss(e, floor_index)` | `setup_boss(e, floor_index, s)` + 播报改用 `e.boss_name` |

**数值出口统一**：`session.rogue_mods()` 是"变数 + 诅咒"的唯一实现，`roguelike.run_mods()` 只是转发；
`mod_of(s,key,p)` / `scale_int(base,scale)` 是全部钩子的入口，`scale_int` 在倍率 1.0 时**逐位返回原值**，
所以"没有变数/没有诅咒"的路径与 W1b 之前的数字完全相同（这是本轮的回归护城河）。

---

## 2. rng 纪律

- **未新增任何 `s.rng` 消耗点**，也未改变任何既有消耗点的次数与顺序：
  `roll_tier` 仍是一次 `randi_range(1,100)`；`elite_chance`、`chest_drop`、金币/定价/经验全部不抽随机。
- 新增消耗点只有 `open_room()` 里的两个，且都已在 CHANGE-LOG v2-7 登记：
  `RogueCurses.roll()`（每人 1 次 `randi_range`）与 `RogueEvents.roll_offer()`（全队 1 次 `randi_range`）。
- `room_action()`/`mirror_action()` 里的 `RogueRooms.resolve(..., s.rng)` 各恰好 1 次 `randf()`（R10 的登记请求，见 §5）。
- 任何路径都不重置 `s.rng.seed`。

---

## 3. 验收（原始输出）

```
--check-only scripts/roguelike.gd   EXIT=0
--check-only scripts/session.gd     EXIT=0

tests/rogue_hooks_roguelike.gd   ROGUE HOOKS ROGUELIKE 55 checks / 0 failures   EXIT=0
```

`tests/rogue_hooks_roguelike.gd` 断言覆盖：空变数时 `mod_of/scale_int` 恒等；`clear_room` 基线金币；
干净商店 65+floor\*10 与血瓶 45；`bounty` +25% 金币；`rust` -30% 商店价且不破 1；`blood_moon` +1 档且 `roll_tier≥1`；
`bargain` -1 档且 200 次抽样下限仍 ≥0；诅咒补偿 >1 且 `rogue_mods` 的 `defense_penalty` 与 `RogueCurses` 逐位相同；
铁匠铺报价/扣费/过期 revision 零副作用/成交后 revision 前进且报价重算；赌徒净额恰好 ±stake；
镜像两步、`rogue_mirror_used` 一次性、用过的镜像不能再接受；诅咒房每人恰好 1 条诅咒；
事件房 `pending_event` 带 id 与 2~3 个选项、过期点击不能结算；服务房报价必须晚于 `clear_room` 的 revision 自增；
`settle()` 的灰烬入账等于本局灰烬、二次 `settle` 幂等、每日打卡写入当天键；
R14 池：`boss_art == boss_art_for(seed,floor)`、`boss_name == NAMES[boss_art]`、`rogue_skin` 仍是楼层索引。

---

## 4. 过期断言迁移（原文 → 新断言 → 理由）

**（a）本轮唯一需要迁移的两条，都在 `tests/rogue_build_progression.gd`：**

1. 原文（`tests/rogue_build_progression.gd:95`，在"普通房间"分支）：
   `check(p.rogue_selection.is_empty() and p.build_reward_queue.is_empty(),"Ordinary rooms do not grant talents")`
   → 新断言：同一句被 `if str(s.raid.room) in ["combat","elite"]:` 包住（语句本身未改），
   其后原有的 `while not p.rogue_selection.is_empty(): claim(s,p)` 排水逻辑保持不变。
   **理由**：该分支同时承接 `rogue_combat`/`rogue_reward` 两种 phase，而**新的诅咒回廊进房即发对称回报**
   （`RogueCurses.apply_pair`），会把一个"装备三选一"排进 `build_reward_queue`。原句声称的
   "普通房间不发天赋奖励"这个**意图只对普通（战斗/精英）房间成立**，对专属奖励房是错误前提。
   迁移没有放宽成恒真：战斗/精英房仍然被逐字检查（`combat`/`elite` 分支仍会跑这句），
   而且该测试的 `rogue_build_progression` 其余 715 条断言一条未动。

2. 原文（`tests/rogue_build_progression.gd:144`）：
   `check(points==(int(s.players[1].build_level)-1)*2*count+attribute_shards,"All points come from levels and actually collected chest shards: %d vs %d" % ...)`
   → 新断言：把诅咒回报计入来源，并把变量标注为 `int`：
   ```gdscript
   var Curses := preload("res://scripts/rogue_curses.gd")
   var curse_points := 0
   for p in s.players.values():
       points+=int(p.build_attribute_points)
       for curse_id in p.get("rogue_curses",[]):
           curse_points+=int(Curses.find(str(curse_id)).get("boon",{}).get("attribute_points",0))
   var from_sources: int = (int(s.players[1].build_level)-1)*2*count+attribute_shards+curse_points
   check(points==from_sources,"All points come from levels, collected chest shards and curse boons: %d vs %d" % [points,from_sources])
   ```
   **理由**：属性点的来源从"等级 + 宝箱灵晶"变成三类，第三类是**诅咒回报**（诅咒回廊的对称收益，
   属 R9 的冻结设计）。断言仍然是一个**精确等式**（不是 `>=`、不是区间），只是把新来源收进账。
   在本测试的行走路径上，诅咒只能来自诅咒回廊——测试从不派发 `rogue_event`，
   所以"每条身上的诅咒恰好贡献一次 boon"是精确的，不需要放大区间。

**（b）`tests/rogue_wiring.gd` 的 `seed_shared starts empty` —— 不需要迁移，改的是实现：**
- 事实：我最初在 `reset()` 里写了 `raid["seed_shared"]=Daily.encode(seed)`，与该断言（以及契约 §2 的
  "默认值 `""`、写入者是 W2/R7 的种子页"）冲突。
- 处置：**回退实现**（去掉那一行），而不是改断言。`seed_shared` 保持冻结默认 `""`，
  由 R7 的种子界面负责写入。迁移留痕为零，因为断言一字未动：
  `rogue_wiring` 由 122/1 回到 **122/0**。

---

## 5. 仍未接线的缺口（都不在我这轮的文件里）

1. **`session.profile_data()` 通道缺失**：`RogueGrowth.grant()` 用
   `s.profile_data()` → `s.get_meta("profile_data")` → `{}` 探测，而 `session.gd` 目前**两者都没有**
   （`grep "func profile_data" scripts/session.gd` 无命中）。→ 本局灰烬只会累加到 `p.rogue_ash_run`，
   **不入账 `profile.ashes`**；`RogueGrowth.power()` 也恒为 0（起始金币/刷新券加成不生效）。
   需要 W1/W2 补一行 `session.gd: func profile_data() -> Dictionary: return profile.data`
   （或在 `launch` 前 `session.set_meta("profile_data", profile.data)`）。
2. **`profile.data["daily"]` 第三键尚不存在**（CHANGE-LOG v3-1 仍是"计划中·未生效"）。
   `record_daily()` 因此是**受保护的 no-op**：只在键已存在时写，不凭空造一个会被 `apply_data()`
   的 typeof 匹配静默丢弃的键。需要 profile.gd 在 `_init()` 补 `"daily":{}`。
3. **`RogueRooms` 三个房间没有 UI**：`rogue_forge`/`rogue_gamble`/`rogue_mirror` 的动作与报价已经可用、
   可测（`raid.pending_forge` / `pending_gamble` / `mirror_state`），但 `main.gd`(W2) 还没有对应面板，
   玩家暂时点不到。`rogue_event` 的面板 R7 已交付。
4. **子弹表现层 `bullet_visual` 仍无消费端**（W7 的 G 集合），普通敌人弹也还没写该字段（R8 清单 (d) 归 W1a）。
5. **`RogueCurses.roll()` / `RogueEvents.roll_offer()` / `RogueRooms.gamble_roll()` / `mirror_resolve()`
   四个新的 `s.rng` 消耗点**建议在 CHANGE-LOG 里补记（前三者见 v2-7 与 R10 的提案，
   第四个 `mirror_resolve` 是 R10 的 `resolve("mirror",...)`）。
6. **`RogueGrowth` 的敌人倍率**（`rogue_build.gd:920-921` 的 `build_enemy_hp/damage` 乘 `power()`）属 W3，
   本轮未接。

---

## 6. 已知风险

- 变数经济钩子会**改变局内数值**（金币/价格/经验/掉档），这是设计目标；但它同时让
  "按固定种子的数值断言"这类旧口径失效——本轮已按 §4 把受影响的两条迁移并留痕。
- `open_room()` 的诅咒 roll 是**每人 1 次**，人多时消耗次数随人数增长（联机下房主统一结算，
  客户端不跑 `enter()`，因此不需要本地对齐）。
- `elite_chance` 用"整数前缀"而不是概率实现，避免了 rng 扰动；代价是它的效果是**阶梯式**的
  （+12% ≈ 精英房多 1 只精英），不是连续概率。

---

## 7. `tests/roguelike.gd` 挂死：判定为**与本轮无关**（附根因与证据）

**结论**：不是 W1b 引入的，也不需要 W1b 修（`Build.reset` 与 `Content/Catalog` 都不在 W1b 的写入面）。

**证据 1（时序）**：本轮**第一次** `tests/roguelike.gd` 的运行是在我做出任何编辑**之前**发起的
（那次运行超过 240s 仍未结束，被我 kill），即挂死在改动之前就存在。

**证据 2（逻辑不可达 + 反证）**：我的 diff 对 `p.rogue_rerolls` 的唯一写入是
`roguelike.gd:127` 的 `p.rogue_rerolls=int(p.get("rogue_rerolls",0))+int(meta.get("start_rerolls",0))`，
而 `meta = RogueGrowth.power(profile_data_of(s))` 在**裸 `TideSession`**（既无 `profile_data()` 方法、
也无 `profile_data` meta，测试已断言）上恒为 `{start_rerolls:0, start_coins:0}`。
`p.weapon` 我一行都没写。

**真正的根因（实测）**：
- `roguelike.gd:133` 的 `Build.reset(s,p)` 在 `:127` **之后**执行，而 `scripts/rogue_build.gd:20` 的
  `merge(..., true)` 里写死了 `"rogue_rerolls":3` → **无论调用方配置 2 还是 5，最终都是 3**。
  这就是 `tests/roguelike.gd:21` 的 `p.rogue_rerolls==2` 不可能成立的原因（本轮的探针实测
  `bare-session weapon=600 rerolls=3 gold=60`，其中 `gold=60` 证明 W1b 的金币接线是恒等 no-op）。
- `p.weapon==1` 同理落在 `roguelike.gd:134-136` 的"按 Catalog 名称回匹配 Content 武器"老路径上
  （实测得到 600），与 W1b 无关。
- **挂死机制**：`:21` 失败后，`:65` 的循环首轮 phase 是 `rogue_prepare`（测试从不派发开局武器选择）
  → 落到 `else` 的 `check(false,"Unexpected phase"); break` → `:67` 访问 `s.results[1]` 越界
  → SCRIPT ERROR 后**没有 `quit()`** → 进程空转 = TIMEOUT。

**建议（交给所有者轮次）**：要么让 `Build.reset()` 不再覆盖调用方显式传入的 `rogue_rerolls`
（改成 `if not p.has("rogue_rerolls")` 才给默认 3），要么把 `tests/roguelike.gd` 的开局配置断言
与 `:65` 的 `rogue_prepare` 分支按新语义补齐（该测试不在门禁集合内）。

