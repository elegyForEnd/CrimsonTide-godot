# R12 交付记录 · 灰烬局外永久成长树（`RogueGrowth`）

- **轮次**：R12（`output/ROGUE-EXPANSION-EXECUTION-PLAN.md`）
- **契约**：`output/ROGUE-CONTRACTS.md`（冻结版 v1）§4/§5/§6.2/§8.1/§9
- **所有权**：F 集合（W6），**本轮只新建 2 个文件**，未改动任何既有源码/文档
- **日期**：2026-10-05

## 1. 交付物

| 文件 | 说明 | SHA256 前 16 位 |
| --- | --- | --- |
| `scripts/rogue_growth.gd` | `RogueGrowth`：14 节点成长树 + 灰烬经济 + 结核算式（纯函数） | `4F245A1335A4EE5D` |
| `tests/rogue_growth.gd` | 验收用例（6886 断言） | `A40AFCC4857AF6FE` |

`grep -rn 'RogueGrowth\|rogue_growth' scripts tests resources` 只有：本模块自身、本用例、以及 `scripts/profile.gd:121` 的一句注释
（"per-node level cap lives in the tree itself (RogueGrowth.tree())"）。**本轮没有给任何既有路径接线**，因此不可能改变其它测试的行为。

## 2. 契约符合性（冻结签名逐字实现）

| 契约 §5 冻结签名 | 实现 |
| --- | --- |
| `tree() -> Dictionary` | ✅ 返回 `{id -> {"cost","max","requires","effect"}}`，**恰好 4 个键**（深拷贝，改不动常量表） |
| `power(profile_data) -> Dictionary` | ✅ 返回**恰好** `enemy_hp`(float)/`enemy_damage`(float)/`start_coins`(int)/`start_rerolls`(int) |
| `can_buy(profile_data, id) -> bool` | ✅ |
| `buy(profile_data, id) -> bool` | ✅ 副作用＝扣 `ashes` + `growth[id]+=1`，**不落盘**；失败路径零变化 |
| `ashes_on_settle(s, p) -> int` | ✅ 只读 `s.raid.cleared/floor` 与 `p.status`，再乘成长树的灰烬加成 |
| `grant(s, p) -> int` | ✅ `p.rogue_ash_run += 值` + 累加**局外** `profile.data.ashes`；0 产出时不写任何字段 |

### 2.1 契约没冻结、本轮定死的语义（追加，不改别人）

1. **花费曲线**：`cost_for(id, level) = cost * (level + 1)`（第 1 级付 `cost`、第 2 级付 `2*cost`…），
   单调不降、满级后返回 `-1`。全树满级 `total_cost() = 7305`（**机器导出**，见 §3）。
2. **`power()` 的语义**：`enemy_hp`/`enemy_damage` 是**乘性缩放**（1.0 = 无修正，`MIN_ENEMY_SCALE = 0.70` 封顶下限，
   上限恒为 1.0 —— 成长树**永不**让敌人更强）；`start_coins`/`start_rerolls` 是**整数加成**
   （分别加到 `p.rogue_gold` 与 `p.rogue_rerolls`）。
3. **结算公式**：`earn_for_run({"cleared","floor","won","ash_bonus"})`
   `= round((12*cleared + 30*floor + (150 if won)) * (1 + clamp(ash_bonus,0,1)))`，非负、对三个自变量单调不减。
4. **`ash_bonus` 是本轮新增的效果键**（灰烬是契约 §4 新引入的局外货币，仓库里没有同义键）。
   它**只影响结算产出**，不影响任何战斗数值。其余效果键全部取自既有词汇：
   `rogue_variants.gd` 的 canonical 键（`enemy_hp`/`enemy_damage`/`player_damage`/`player_damage_taken`/`gold`/`xp_gain`/
   `shop_price`/`chest_drop`/`heal_scale`）与 `rogue_curses.gd` 的 `move_speed`、整数键 `loot_tier`。
5. **判定几何硬约束**：模块提供 `forbidden_keys()`，`effects()`/`power()` 永不产出
   `hit_radius`/`collision_radius`/`zone`/`hitbox` 等键（有断言钉死，共 40 条）。

### 2.2 追加的纯函数（契约允许"只追加"）

`ids / has / label / describe / max_level / cost_for / cost_to_max / total_cost / level_of / can_buy_reason /
spent_on / total_spent / reset_cost / reset / effects / ash_bonus / earn_for_run / sanitize / forbidden_keys / canonical_keys`

## 3. 成长树全表（`cost`/`total` 由模块机器导出，`TOTAL_COST=7305` 与 `total_cost()` 一致）

| id | 名称 | 上限 | 首级花费 | 满级总花费 | 前置 | 每级效果 | 满级效果 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `coin_purse` | 沉甸钱囊 | 4 | 30 | 300 | — | `start_coins +25` | +100 |
| `ash_vein` | 灰烬矿脉 | 5 | 40 | 600 | — | `ash_bonus +0.10` | +0.50 |
| `reroll_charm` | 运势护符 | 3 | 45 | 270 | — | `start_rerolls +1` | +3 |
| `iron_constitution` | 铁躯 | 5 | 50 | 750 | — | `enemy_damage -0.03` | -0.15 |
| `hunt_instinct` | 猎杀本能 | 5 | 50 | 750 | — | `player_damage +0.04` | +0.20 |
| `warden_plate` | 守望重甲 | 5 | 55 | 825 | `iron_constitution` | `player_damage_taken -0.03` | -0.15 |
| `deep_pockets` | 深袋 | 4 | 40 | 400 | `coin_purse` | `shop_price -0.05` | -0.20 |
| `scavenger` | 拾荒者 | 4 | 45 | 450 | — | `chest_drop +0.08` | +0.32 |
| `field_medic` | 战地医者 | 4 | 40 | 400 | — | `heal_scale +0.08` | +0.32 |
| `swift_boots` | 疾行长靴 | 4 | 40 | 400 | — | `move_speed +12` | +48 |
| `scholar` | 博识 | 4 | 45 | 450 | — | `xp_gain +0.10` | +0.40 |
| `midas_hand` | 点金之手 | 4 | 45 | 450 | `deep_pockets` | `gold +0.10` | +0.40 |
| `hunter_luck` | 猎运 | 3 | 60 | 360 | — | `loot_tier +1` | +3 |
| `monster_slaying` | 屠戮研习 | 5 | 60 | 900 | `hunt_instinct`, `warden_plate` | `enemy_hp -0.04` | -0.20 |

- 前 5 条无前置，形成三条链：`coin_purse→deep_pockets→midas_hand`、`iron_constitution→warden_plate→monster_slaying`（与 `hunt_instinct` 并联）、其余为叶子。
- **满级 `power()`** = `enemy_hp 0.80` / `enemy_damage 0.85` / `start_coins 100` / `start_rerolls 3`（有断言）。
- 经济：按 `earn_for_run` 的公式，一次 5 层全清+撤离约 `12*35+30*5+150 = 720`（未计加成），满树需 7305 ≈ 10 局左右（含 `ash_vein` 加成后更少）。

## 4. 验收原始输出

引擎：`D:\game\CrimsonTide-godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/<n>.gd`
（Godot 不在 PATH；`tests/rogue_growth.gd` 是规则用例，headless 即可，无需 `_visual` 窗口）

| 命令 | 结果 | 基线 | 判定 |
| --- | --- | --- | --- |
| `tests/rogue_growth.gd` | **ROGUE GROWTH 6886 checks / 0 failures**（exit 0，stderr 0 行错误） | 本轮新建 | ✅ |
| `tests/rogue_wiring.gd` | ROGUE WIRING 117 checks / **2 failures** | 117 / 0 | ⚠ **非本轮引入**，见 §6 |
| `tests/rogue_variants.gd` | ROGUE VARIANTS 495 / 0 | 495 / 0 | ✅ 一致 |
| `tests/rogue_curses.gd` | ROGUE CURSES 218 / 0 | 218 / 0 | ✅ 一致 |
| `tests/rogue_events.gd` | ROGUE EVENTS 484 / 0 | 484 / 0 | ✅ 一致 |
| `tests/rogue_graph.gd` | ROGUE GRAPH 83608 / 0 | 83608 / 0 | ✅ 一致 |
| `tests/rogue_build_growth.gd` | BUILD GROWTH 4066 / 0（箱样本 [213,500]） | 4066 / 0 | ✅ 一致 |
| `tests/rogue_build_system.gd` | ROGUE BUILD 440 / 0 | 440 / 0 | ✅ 一致 |
| `tests/systems.gd` | SYSTEM TESTS 10812 / 0 | 10812 / 0 | ✅ 一致 |
| `tests/expedition.gd` | EXPEDITION 79 / 0 | 79 / 0 | ✅ 一致 |

原始日志留在 `build/r12/run4.txt`、`build/r12/reg-<test>.txt`（`build/` 被 gitignore，磁盘可见）。
`rogue_build_progression` / `roguelike_seven_rooms` / `roguelike_routes` 按派单**不充当门禁**（R5 正在改口径）；
`rogue_build_rules`（崩溃挂死）与 `rogue_build_pack`（资产缺失）按基线**豁免**。

### 4.1 `tests/rogue_growth.gd` 覆盖清单（6886 断言）

① `tree()` 形状（恰好 4 键、类型、非空名/描述、未知 id 行为）与**前置图无环**（Kahn 拓扑全解析）；
② 花费曲线单调不降、`cost_to_max()` 求和一致、未知 id 返回 `-1`；
③ `effects()` 中性值/单节点分级线性/等级超上限截断/未知 id 忽略/上下限 clamp；
④ `power()` 冻结形状与类型、中性值、满级值、敌人倍率下限与"永不高于 1.0"；
⑤ `can_buy/buy`：钱不够、未知 id、前置未满足、已满级、浮点灰烬、缺 `growth` 键、非数值灰烬、非法 profile；
⑥ **失败路径零痕迹**（7 组用例逐组 `JSON.stringify` 前后比对）；
⑦ 持久化：JSON 往返、老档 `{version:1}`、脏数据（负数/字符串/未知 id/零级/超上限）与"不原地改传入值"；
⑧ `spent_on/total_spent/reset_cost/reset`；
⑨ `earn_for_run` 边界与三个自变量单调性、`ash_bonus` 乘算与 clamp、非字典 stats；
⑩ 200 组随机成长向量：键集恒定、逐键在界、`power()` 形状不变、JSON 可序列化且往返等价；
⑪ 判定几何黑名单（`effects()`/`power()`/每个节点的 `effect` 都不含）；
⑫ **无死节点**：足额预算贪心买空后 14 节点全部满级、恰好花掉 `total_cost()`；
    1000 个采样预算的"预算↑ ⇒ 总等级不减"单调性；
⑬ **真实会话往返**：`ashes_on_settle` 与 `grant` 在 `TideSession` 上的灰烬累加/入账/零产出不写字段；
    无 profile 通道时只累加 `rogue_ash_run` 且不崩；浮点 `raid` 计数被正确取整；`null` 入参安全。

## 5. 本轮自查发现并修掉的缺陷（都发生在提交前）

1. `cost_to_max(未知 id)` 原本返回 `0`（空循环），与"未知 → `-1`"的约定不符 → 已加 `NODES.has(id)` 前置判断。
2. 验收用例里的 Kahn 拓扑把入度记在了**前置**而不是**依赖方**（`X requires Y` 的拓扑边是 Y→X），
   导致 `resolved=9/14` 误报 → 已修正为 `pending[X] += 1`，并用一次性探针脚本定位后删除。
3. 冻结签名把 `profile_data` 标成 `Dictionary`，因此 `null` 在语言层就传不进来
   （运行期报 `Cannot convert argument 1 from Nil to Dictionary`）——本轮据此**删掉了 5 条写在测试里的 null 断言**，
   非字典容错改由 `effects({"growth":[]})` / `level_of({"growth":[]})` / `sanitize({"growth":[]})` 覆盖。
4. `Object.get_meta(name, null)` 在 meta 键不存在时**会打印引擎错误**
   （`The object does not have any 'meta' values with the key 'profile_data'`），即使传了默认值也一样。
   → profile 通道改为 `has_meta()` 先判断再取；最终一轮 `stderr` 为 **0 行错误**（§4 的 6886/0 就是这一版）。

## 6. 受阻与恢复记录（并发写者导致，非本轮引入）

- 19:5x 期间 `scripts/roguelike.gd:176`（R5 在飞）有解析错误 `Cannot infer the type of "fresh" variable`，
  把 `scripts/session.gd` 拖成 `Compilation failed`，一切依赖 `TideSession` 的用例整体无法编译。
  → 本轮先完成纯函数部分（**6869 checks / 0 failures**），并把用例改成"`session.gd`/`roguelike.gd` 探针不可用则推迟会话段"
  （`session_script()` 只做 `load()` + `can_instantiate()` 探针，**不再静态依赖 `TideSession` 类型**）。
- R5 修好后**已复跑全套**：会话段执行、总计 **6886 checks / 0 failures**，回归 8 项与基线逐项一致（见 §4 表）。
- `tests/rogue_wiring.gd` 的 **2 failures** 是 `Only node/depth ride inside raid`（该断言原文：
  `check(str(decoded_raid.get("node",""))=="","Only node/depth ride inside raid")`）。
  原因：R5 已把节点图接进推进，`s.raid.node` 不再恒为 `""` —— 这正是**该测试的既有口径过期**，
  而 `tests/rogue_wiring.gd` 与 `scripts/roguelike.gd` 的所有者都是 **R5/W1**，不属于本轮写作面。
  本轮证据：全仓库只有 `profile.gd:121` 的注释提到 `RogueGrowth`，本模块零接线，不可能影响该用例。

## 7. 待接线清单（提交者 W6：轮次 R12；全部是别人的文件，本轮未动）

```
- 目标文件: scripts/session.gd
- 目标函数/锚点: 顶层 var（`var rogue_graph` 附近）
- 期望插入代码: func profile_data() -> Dictionary: return profile.data
- 依赖的契约: §5 RogueGrowth.grant / §4 profile.data
- 验收断言: tests/rogue_growth.gd 的"grant() banks the ashes into the external profile"
- 未接线时的临时状态: grant() 只累加 p.rogue_ash_run（不崩、不入账）

- 目标文件: scripts/main.gd（W2）
- 目标函数/锚点: 启动魔境前（`main.gd:901` 的 payload 组装处附近）
- 期望插入代码: session.profile = profile（或等价地把 profile.data 交给上述 profile_data()）
- 依赖的契约: §4/§5 grant
- 验收断言: 同上
- 未接线时的临时状态: 灰烬只进 rogue_ash_run，局外货币不增长

- 目标文件: scripts/session.gd
- 目标函数/锚点: 启动时把 profile.data 交给 RogueGrowth（`Profile.data` 是权威）
- 期望插入代码: 由 main.gd 在 launch 前赋值（见上条），session 只做透传
- 依赖的契约: §5 power
- 验收断言: tests/rogue_growth.gd 的 power() 断言 + R13 的闭环用例
- 未接线时的临时状态: power() 中性（敌人倍率 1.0、起始加成 0），玩法不变

- 目标文件: scripts/roguelike.gd（W1）
- 目标函数/锚点: reset() 的 `p.rogue_gold=60` / `p.rogue_rerolls` 赋值处（现 44 行、49 行附近）
- 期望插入代码: var pw := RogueGrowth.power(<profile data>);
                p.rogue_gold += int(pw.start_coins); p.rogue_rerolls += int(pw.start_rerolls)
- 依赖的契约: §5 RogueGrowth.power
- 验收断言: 需 R13 新增"开局魔晶/刷新次数"用例
- 未接线时的临时状态: 起始加成不生效（60 魔晶、原刷新次数）

- 目标文件: scripts/rogue_build.gd / scripts/rogue_combat.gd（W1/W3）
- 目标函数/锚点: `s.raid["build_enemy_hp"]`（`rogue_build.gd:920-921`）与敌人伤害合成处
- 期望插入代码: `* float(pw.enemy_hp)` / `* float(pw.enemy_damage)`
- 依赖的契约: §5 RogueGrowth.power
- 验收断言: tests/rogue_growth.gd 的满级 power 值（0.80 / 0.85）
- 未接线时的临时状态: 敌人倍率不变

- 目标文件: scripts/roguelike.gd（W1）
- 目标函数/锚点: settle()（`roguelike.gd:666-676`，已有 `if s.raid.ended: return` 守卫）
- 期望插入代码: 在 `s.running=false` 之前 `for id in s.players: RogueGrowth.grant(s, s.players[id])`，
                随后由 main.gd 侧 `profile.save_profile()` 落盘
- 依赖的契约: §9.3「结算只有一个出口」+ §5 grant
- 验收断言: tests/rogue_growth.gd 的 grant() 三条断言
- 未接线时的临时状态: 灰烬永不发放（结算流程不变）

- 目标文件: scripts/rogue_build.gd / scripts/rogue_map.gd / scripts/rogue_combat.gd（W1/W4/W3）
- 目标函数/锚点: effects() 各键的消费点（heal_scale/cooldown 之外的 gold/xp_gain/shop_price/chest_drop/
                move_speed/loot_tier/elite 相关）
- 期望插入代码: 由 W1/W3/W4 各自决定，统一读 `RogueGrowth.effects(<profile data>)`（**不要**自造键名）
- 依赖的契约: §5 + 本轮 canonical 键表
- 验收断言: 需 R13 增补
- 未接线时的临时状态: 这些键暂时不生效（数据层已就绪）

- 目标文件: scripts/main.gd（W2）
- 目标函数/锚点: 成长树 UI 页 + 结算页
- 期望插入代码: `rogue_growth` 动作**必须携带并校验 raid.revision**（契约 §9.2）；显示 ashes 与各节点 label()/describe()
- 依赖的契约: §9.2
- 验收断言: 需 R7/R13 UI 用例
- 未接线时的临时状态: 玩家暂时无处花灰烬

- 目标文件: scripts/profile.gd（W1，可选）
- 目标函数/锚点: sanitize_growth()（`:122-133`）
- 期望插入代码: 可用 `RogueGrowth.sanitize(data)` 的结果替换手写清理（把等级 clamp 到节点上限）
- 依赖的契约: §4.1（保持 version 1，只新增键）
- 验收断言: 现有 tests/rogue_wiring.gd 的老档用例 + 本模块 sanitize 断言
- 未接线时的临时状态: profile 层只做"非负 + 去零 + 去非数值"，等级**不**按节点上限截断
                （RogueGrowth 侧读取时会自己 clamp，因此不影响正确性）
```

## 8. 建议追加到 `ROGUE-CONTRACTS.md` CHANGE-LOG 的条目

```
- v2 · R12：新增 `scripts/rogue_growth.gd`（F 集合）。
  * 冻结签名 §5 逐字实现（tree/power/can_buy/buy/ashes_on_settle/grant）。
  * 追加纯函数：ids/has/label/describe/max_level/cost_for/cost_to_max/total_cost/level_of/
    can_buy_reason/spent_on/total_spent/reset_cost/reset/effects/ash_bonus/earn_for_run/
    sanitize/forbidden_keys/canonical_keys。
  * 花费曲线定为 cost*(level+1)；全树满级 7305 灰烬。
  * power() 语义：enemy_hp/enemy_damage 为乘性缩放（[0.70,1.0]），start_coins/start_rerolls 为整数加成。
  * 结算公式：round((12*cleared+30*floor+(150 if won))*(1+clamp(ash_bonus,0,1)))。
  * 新增效果键 `ash_bonus`（仅影响结算产出，无战斗影响）；其余键复用
    rogue_variants.gd 的 canonical 词汇与 rogue_curses.gd 的 move_speed。
  * profile 通道（未在 §5 冻结）：`grant(s,p)` 按 `s.profile_data()` → `s.get_meta("profile_data")` → `{}`
    的顺序安全探测；W1 接线后应补 `func profile_data()`（见 R12 待接线清单）。
```

## 9. 风险与遗留

1. **`reset()` 会返还 50% 灰烬**（`RESET_REFUND_RATIO`）：这是本轮追加的机制，UI 接上之前不会有玩家路径触发；
   R13 若要暴露它，需要 `rogue_growth` 动作带 `revision`（§9.2）。
2. **`grant()` 不自带幂等守卫**：契约 §9.3 把"只发一次"交给 `settle()` 的 `ended` 守卫；
   接线方必须在 `s.raid.ended=true` 之后调用（当前实现就是先设 `ended` 再逐人发，顺序安全）。
3. **`ash_bonus` 上限 +100%**：`earn_for_run` 里 clamp 到 `MAX_ASH_BONUS`，避免树与未来变数/诅咒叠乘失控。
4. `effects()` 是"加法合成 + clamp"，与 `rogue_build.gd` 既有减伤池的**交互**要等 §7 的消费点接线后才能断言；
   本轮只保证单侧数值正确与有界。
5. `tests/rogue_wiring.gd` 的 2 条 `node` 断言已过期（§6），**需要 R5 在自己的所有权内更新口径**；
   本轮按门禁只比 failures 的口径如实登记，未越权修改他人测试。
