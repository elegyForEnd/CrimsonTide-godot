# R10 · 三个新房间（铁匠铺 forge / 赌徒 gamble / 镜像挑战 mirror）行为数据层

- **轮次**：R10（`output/ROGUE-EXPANSION-EXECUTION-PLAN.md`）
- **日期**：2026-10-05
- **写入面**：**只新建了两个文件**，未改动任何既有源码 / 既有文档（`git status --porcelain -- scripts tests` 只有这两个 `??`）
  - `scripts/rogue_rooms.gd`（19,527 B，`class_name RogueRooms` + `extends RefCounted`）
  - `tests/rogue_rooms.gd`（21,747 B）
- **契约关系**：契约 §5 的签名表里**没有**这三个房间的模块，因此本模块按派单命名，属于**追加**（见文末「待父会话写入 CHANGE-LOG」）。

---

## 1. 交付物与设计

`scripts/rogue_rooms.gd` 是**纯函数 / 纯数据**模块：只「读」context，返回**增量字典**，从不直接改 `s` / `p` / `raid`。落地由 W1/W2 接线轮次负责（见 §4）。

### 1.1 房间类型与深度下限（与 R4 节点图同源）

| 房间 | 显示名 | 深度下限 | 说明 |
| --- | --- | --- | --- |
| `forge` | 游方锻炉 | 3 | 与 `RogueGraph.NEW_KIND_MIN_DEPTH` 逐项相等（测试有交叉断言） |
| `gamble` | 赌徒营帐 | 4 | 同上 |
| `mirror` | 镜中挑战 | 5 | 同上；节点图保证**每层至多 1 个** mirror 节点（测试实测 200 张图） |

### 1.2 铁匠铺（0 次随机）

复用 `RogueBuild` 的既有锻造规则（`FORGE_COST = [1,1,2,2,2]`、上限 `mini(5, raid.floor)`、`bind_forge()`），**不另造一套数值**。四个服务：

| id | 名称 | 价格（层 f） | delta |
| --- | --- | --- | --- |
| `forge_points_1` | 熔炼 · 1 点锻造 | `30 + 12f` | `{"forge_points": 1}` |
| `forge_points_3` | 熔炼 · 3 点锻造（套餐） | `3×(30+12f) − 15` | `{"forge_points": 3}` |
| `forge_direct` | 当场锻打 · +1 级 | `90 + 25f` | `{"forge_level": 1}` |
| `forge_rebind` | 转移锻造 | `0` | `{"bind": true}` |

价格随楼层**单调不降**；`forge_direct` 在 `forge_level >= mini(5, f)` 时 `available=false`；余额不足时所有收费项 `available=false`；`forge_rebind` 永远可用。

### 1.3 赌徒（每次有效下注恰好 1 次 `rng.randf()`）

| method | 名称 | 注额（层 3 例） | 胜率 | 回报 | 期望 |
| --- | --- | --- | --- | --- | --- |
| `coin` | 掷币 · 押魔晶 | `40 + 15f`（上限 220） | 0.48 | 净赢 1×注额 | **96%**（−4%） |
| `tier` | 押装备升阶 | 1 阶 | 0.40 | 胜 +1 阶（≤5）/ 败 −1 阶（≥1） | **−0.20 阶** |
| `ash` | 押灰烬 | `40 + 15f` | 0.32 | 净赢 2×注额 | **96%**（−4%） |

三种赌法的**期望都不高于 100%**，且胜率与期望值都写进 `desc` 文本（诚实告知风险，不留白嫖口子）。
`available` 分别要求：魔晶 ≥ 注额 / `1 ≤ 武器阶 < 5` / 跑局灰烬 ≥ 注额。

### 1.4 镜像挑战（每次有效结算恰好 1 次 `rng.randf()`）

- 对手强度只看楼层：`hp_scale = clamp(0.90 + 0.22(f−1), 0.90, 1.90)`，**不看玩家战力**（避免"装备越强镜像越无敌"）。
- 奖励：`gold = clamp(60 + 20f + 10×阶, 60, 400)`、`ash = clamp(20 + 5f, 20, 60)`、`gear_reward = 1`；预估胜率 `p_win = clamp(0.62 − 0.045f + 0.02×阶, 0.30, 0.65)`。
- **每局至多一次**：`mirror_allowed()` 同时看契约 §3 的 `p.rogue_mirror_used`（本局是否已领奖）与 `raid.mirror_state.active`（是否正在打）；`mirror_accept()` 第二次请求按原因返回 `active` / `used` 并**安全拒绝**（不写状态、不抽取）。
- 结算返回 `state = {"active":false,"owner":id,"round":2,"settled":true}` 与 `used = true`，正好对齐契约 §2 的 `mirror_state` 形状。

### 1.5 随机性纪律

- 随机入口只有 `gamble_roll()` / `mirror_resolve()`，各自**恰好 1 次 `rng.randf()`**；**拒绝路径 0 次**（非法 index / 条件不足 / 未 active / `rng == null`）。
- 每个随机入口都配一个纯变体 `*_from_roll(value, ...)`，测试用它**证明**"恰好一次抽取"（同种子 `randf()` 对照 + `rng.state` 比对），不依赖 PCG 内部实现细节。
- 调用方必须传 `s.rng`（契约 §6.2.3 禁止全局 `randi()/randf()`）。本模块自身**没有任何全局随机调用**。
- 所有返回字典经递归扫描断言：**不含** `hit_radius` / `collision_radius` / `velocity` / `damage` 等 12 个判定几何键。

### 1.6 统一入口

```gdscript
RogueRooms.kinds() / min_depth(kind) / appears_at(kind, floor, depth)
RogueRooms.context_of(s, p) -> Dictionary          # 只读，缺字段/空 session 全部安全降级
RogueRooms.describe(kind, ctx) -> Dictionary
RogueRooms.offers(kind, ctx) -> Array
RogueRooms.resolve(kind, option_index, ctx, rng) -> Dictionary   # 未知房间 → {"ok":false,"reason":"kind"}
```

---

## 2. 验收（原始输出）

命令：`Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit-after 3600 --script tests/rogue_rooms.gd`

```
ROGUE ROOMS: 1299 checks, 0 failures
exit=0    （stderr 0 行，无 SKIPPED 行 —— 真实会话那一段已实跑）
```

派单 7 条验收的落点：

| # | 要求 | 断言位置（tests/rogue_rooms.gd） |
| --- | --- | --- |
| ① | 增量类型/范围正确，非法选项/未知房间/缺字段安全失败 | §B（`forge_resolve(-1/9)`、余额与上限拒绝）、§C（`gamble_roll(null/9/-1)`、`gamble_from_roll("nope")`）、§D（inactive 镜像、`mirror_resolve(null)`）、§A/§G（`describe/offers/resolve` 未知房间）、`DELTA_KEYS` 规范键断言 |
| ② | 同 (seed, 楼层, 选项) 确定 + 固定次数抽取 | §C/§D：每种赌法 ×1000 次重复逐字段相同；镜像 ×1000 次相同；`same(via_rng, via_value)` + `a.state == b.state`（恰好 1 次） |
| ③ | 赔率与实测统计一致（≥2000 样本） | §C：coin 实测胜率≈0.48、ash≈0.32、tier≈0.40，均落在区间内；coin 净收益均值与 `gamble_expectation()` 一致（±10% 注额） |
| ④ | 铁匠铺价格单调、上限、余额门槛 | §B：层 1–8 价格单调不降；`forge_level_cap(1..5,9)`；`forge_level==cap` 时不可再升；余额 0 时收费项全不可买且 `reason=="unavailable"` |
| ⑤ | 镜像每层至多一次 + 奖励有上限 | §D：`mirror_accept` 二次请求按 `active`/`used` 拒绝；层 1–5 × 阶 0–5 的奖励全部落在 `[60,400]`/`[20,60]`；§F：200 张图实测每层 mirror 节点 ≤1 |
| ⑥ | 返回字典不含判定几何键 | 全文 `scan()` 递归断言（12 个禁用键，含 `p`/`v`/`damage`/`bullet` 等） |
| ⑦ | 出现条件与节点图深度下限一致 | §A：`Rooms.MIN_DEPTH[k] == Graph.NEW_KIND_MIN_DEPTH[k]`；§F：`Graph.build()` 实测每个 forge/gamble/mirror 节点的 `depth` 都 ≥ 对应下限 |

补充断言：三张表的 JSON 往返恒等；`describe()`/`offers()` 对未知房间返回空；`context_of(null, {})` 不崩；`context_of` 与真实会话的 `rogue_gold` / `build_forge_points` / `rogue_ash_run` / `rogue_mirror_used` / `equipped.weapon.tier` 逐项对齐。

`--check-only`：`scripts/rogue_rooms.gd` exit=0、`tests/rogue_rooms.gd` exit=0，均 0 报错。

## 3. 回归（本轮实测，失败数口径）

| 测试 | 本轮 | R1 基线 / 归属 | 判定 |
| --- | --- | --- | --- |
| `tests/rogue_rooms.gd`（本模块） | **1299 / 0** | 新增 | ✅ |
| `rogue_graph` | **83608 / 0** | 83608/0（R4） | ✅ 一致 |
| `rogue_wiring` | **123 / 0** | 117/0（R2） | ✅ 失败相同（checks +6 来自并发轮次） |
| `rogue_variants` | **495 / 0** | 495/0（R8） | ✅ 一致 |
| `rogue_curses` | **218 / 0** | 218/0（R9） | ✅ 一致 |
| `rogue_events` | **484 / 0** | 484/0（R9） | ✅ 一致 |
| `rogue_profile_migration` | **113 / 0** | 113/0（R3） | ✅ 一致 |
| `rogue_build_growth` | **4066 / 0**（宝箱样本 `[213, 500]`） | 4066/0 `[213,500]` | ✅ 逐项一致 |
| `rogue_build_system` | **440 / 0** | 440/0 | ✅ 一致 |
| `systems` | **10812 / 0** | 10812/0 | ✅ 一致 |
| `expedition` | **79 / 0** | 79/0 | ✅ 一致 |
| `rogue_build_progression` | **818 / 0** | 505/**39**（R1） | ✅ R5 已按新口径移植（本模块零引用，仅记录） |
| `roguelike_seven_rooms` | **11832 / 0** | 1856/0（R1） | ✅ R5 已移植 |
| `roguelike_routes` | **5220 / 2** | 5219/**5**（R1） | ⚠️ **归 R5**：仅剩 `tests/roguelike_routes.gd:88`「Player can walk continuously along each branch in long and compact rooms」 |

**本轮自身新增失败 = 0。** 我未碰 G 集合（W7）、W1/W2/W3/W4 文件与任何既有测试。

### 3.1 并发观察（交给父会话，供 R18 门禁参考）

1. **`scripts/roguelike.gd:176` 曾把全仓库拖成不可编译**（`var fresh := ... or s.rogue_graph.is_empty()` → 类型推断失败 → `session.gd` 连带失败 → 所有依赖 TideSession 的测试 `Compilation failed`）。已在 R5 侧修复；修复后我立刻复跑，本轮 §3 全部为修复后的实测值。
2. **中途快照会严重误导**：我 19:55 左右测到 `roguelike_seven_rooms 1831/558`、`roguelike_routes` 在 `:28` `exits[1]` 越界后**不调用 `quit()` 挂死**；几分钟后同样的测试变成 `11832/0` 与 `5220/2`。⇒ **门禁必须由"所有写者停止后的一次干净全量跑"产生**，并且 `--script` 用例建议统一加 `--quit-after <大帧数>` 兜底（把"运行期报错 → 不 quit → 挂死"变成可观察的失败）。
3. `roguelike_routes` 剩余 2 项是**几何可走性**断言；按 R1 的 C 分析，这条若在节点图迁移后**变化**，说明 `region_key` 用错了 ground profile（`rogue_map.gd:50-54`）——建议 R6/R14 之前先把它查清。

---

## 4. 待接线清单（提交者 W6：轮次 R10）

> 本模块是纯数据层，**玩法尚未可达**；下面每条都是**别人文件**，我未动。

- **目标文件**：`scripts/rogue_map.gd`
  - **锚点**：`region_key()`，第 50-54 行
  - **期望插入代码**：登记契约 §7.2 的冻结映射 `forge→f{n}-shop`、`gamble→f{n}-treasure`、`mirror→f{n}-talent`
  - **依赖的契约**：§7.2 ①（C3）
  - **验收断言**：`roguelike_routes` 的"分支连续可走"必须由 2 failures 恢复到基线水平
  - **未接线时的临时状态**：新房间会退化成战斗长房

- **目标文件**：`scripts/roguelike.gd`
  - **锚点 1**：`ROOM_NAMES`（第 13 行）追加 `forge/gamble/mirror` 显示名（可直接用 `RogueRooms.ROOM_NAMES`）
  - **锚点 2**：`enter()` 的 `room not in ["shop","treasure","talent"]` 谓词（第 86 行）扩成含 `curse/event/forge/gamble/mirror`
  - **锚点 3**：`enter()` 的非战斗房分支 → 写 `raid.pending_forge = {"offers": RogueRooms.forge_offers(RogueRooms.context_of(s,p)), "revision": s.raid.revision}` / `raid.pending_gamble` / `raid.mirror_state`
  - **锚点 4**：`choose()`（第 567 行起）新增动作 `rogue_forge` / `rogue_gamble` / `rogue_mirror`，**必须**先校验 `int(payload.get("revision",-1)) == int(s.raid.revision)`（契约 §9.2），再调 `RogueRooms.resolve(kind, index, ctx, s.rng)` 并落地 delta：
    - `gold` → `p.rogue_gold = maxi(0, p.rogue_gold + delta.gold)`
    - `forge_points` → `p.build_forge_points += n`
    - `forge_level` → `p.build_forge_level += 1` 且不得越过 `RogueRooms.forge_level_cap(floor)`，随后 `Build.bind_forge(p)`
    - `bind` → `Build.bind_forge(p)`
    - `weapon_tier` → 改写 `p.equipped.weapon.tier`（**会牵动 `Catalog.item_name/description` 与属性计算**，需 `p.rogue_inventory_revision += 1`；建议在接线轮单独验证）
    - `ash` → `p.rogue_ash_run = maxi(0, p.rogue_ash_run + delta.ash)`
    - `gear_reward` → `p.build_reward_queue.append("gear")` + `next_personal(s,p)`（复用 R9 的既有通道）
    - 镜像结算还要 `p.rogue_mirror_used = true`（契约 §3）
  - **依赖的契约**：§2（`pending_forge`/`pending_gamble`/`mirror_state` 已冻结）、§6.2.3（随机点登记）、§9.2（revision）
  - **验收断言**：新增 `rogue_rooms` 接线用例 + `rogue_wiring` 快照往返不回归
  - **未接线时的临时状态**：房间可生成、`offers()` 可渲染，但点不动（无 reward、无状态）
- **目标文件**：`scripts/main.gd`（W2/R7）
  - **锚点**：魔境 HUD/交互 —— forge 服务列表（4 项）、gamble 三个下注项（含 `desc` 里的赔率）、mirror 接受/结算提示
  - **期望**：所有动作携带并校验 `revision`
- **目标文件**：`scripts/rogue_build.gd`（W3，只读依赖）
  - **说明**：`forge_direct` 的 `delta.forge_level` 需要调用方复用既有 `Build.bind_forge()`；本模块**不**直接调它（保持纯函数）

### 需要父会话写入 CHANGE-LOG 的追加项

- **v2 / R10**：新增 W6 模块 `scripts/rogue_rooms.gd`（`class_name RogueRooms`，纯函数数据层），签名见本文件 §1.6；它在契约 §5 的签名表里**不存在**，属纯追加，未改名/改类型/改默认值任何既有条目。
- **随机点登记**：`RogueRooms.gamble_roll()` 与 `RogueRooms.mirror_resolve()` 是新的 `s.rng` 消耗点（各恰好 1 次 `randf()`，拒绝路径 0 次），按 §6.2.3 属允许，建议登记进 RNG 配方文档。
- **class cache**：新增 `class_name RogueRooms` 后 `.godot/global_script_class_cache.cfg` 未包含它。本模块与测试**全部走 `preload`**（实测全仓库无裸类名引用），因此当前无害；建议最终轮跑一次 `tools\check_class_cache.ps1 -ProjectPath .`。

---

## 5. 风险与已知取舍

1. **赌徒期望为负是刻意的**（coin/ash 96%、tier −0.2 阶）：赌徒房是"用期望换方差"的选择，不是印钞机。若后续想让赌徒更有吸引力，应**提高胜率的方差**或给"连胜加成"，而不是把期望抬过 100%。
2. **`tier` 赌法需要接线轮小心**：直接改 `p.equipped.weapon.tier` 会影响 `Catalog` 的命名/描述与部分属性计算，建议接线时同步 `refresh_max_hp()` 与 `rogue_inventory_revision`，并在 R7 UI 上用"阶位预览"展示。
3. **镜像是"每局一次"而非"每层一次"**：这是契约 §3 `rogue_mirror_used` 的语义（本局是否已领奖）。"每层至多一次"由 R4 节点图的**每层 mirror 唯一**保证（测试实测 200 张图）。若设计上真要"每层各一次"，需要新增 `raid.mirror_floor` 键 + CHANGE-LOG。
4. **`forge_direct` 与 `RogueBuild` 的锻造点体系并存**：一个是"花魔晶直接升级"，一个是"攒锻造点升级"。两者共享同一个 `build_forge_level` 与同一个上限，不会互相绕过，但**经济上更贵**（`90+25f` 魔晶 vs 1~2 锻造点），这是我刻意的定位（铁匠铺＝花钱买进度）。
5. **未接线 = 玩法不可达**：本轮只交付数据层，玩家在游戏里还看不到这三个房间的行为，需要 §4 的接线轮。
