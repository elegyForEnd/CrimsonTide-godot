# R4 · 层间节点图生成器（`RogueGraph`）交付记录

- **轮次**：R4（`output/ROGUE-EXPANSION-EXECUTION-PLAN.md` §3.2 R4）
- **契约**：`output/ROGUE-CONTRACTS.md` §5 / §6.2 / §7 / §9（严格遵守，含 C1「图不进 `raid`」、C2「局部 RNG，绝不碰 `s.rng`」）
- **交付物**：`scripts/rogue_graph.gd`（新建）、`tests/rogue_graph.gd`（新建）
- **源码指纹（SHA256 前 16 位）**：`rogue_graph.gd AE6CE9E5E52B56BD` / `tests/rogue_graph.gd FAF9E8A52D6F985C`
- **未改动任何既有源码 / 既有文档 / `.md`**（`git status` 中本轮的 `??` 只有上面这两个文件；`build/r4/` 是日志目录，`output/` 只新增本文件）

---

## 1. 交付内容

### 1.1 契约冻结的 5 个静态 API（逐字实现，未改名/改类型/改默认值）

| 函数 | 说明 |
| --- | --- |
| `build(seed_value: int, floor: int) -> Dictionary` | 纯函数；返回 `{floor, entry, boss, order, nodes}`，节点为 `{id, kind, depth, next}` 四个键，**与契约 §5 完全一致**（无附加键） |
| `kinds() -> Array` | 10 种非 boss 房间类型：`combat/elite/shop/treasure/talent/curse/event/forge/gamble/mirror`，**不含 `boss`** |
| `neighbors(g, id) -> Array` | 后继 id（有序）；未知 id → `[]` |
| `node(g, id) -> Dictionary` | 节点字典深拷贝；未知 id → `{}` |
| `signature(g) -> String` | 由 `floor/entry/boss + order + kind/depth/next` 拼出后取 SHA256；**不依赖 Dictionary 插入顺序，JSON 往返后不变** |

### 1.2 追加的 3 个兼容辅助（契约允许“只追加”，用于满足本次验收第 ⑥ 条「与 7 区等价映射」）

| 追加项 | 说明 |
| --- | --- |
| `const LEGACY_ROUTE` | 旧版每层槽位模板 `["combat","talent","elite","shop","combat","treasure","boss"]`（= `roguelike.gd:59` `new_floor()` 写的那一串） |
| `legacy_areas(g) -> Array` | 把图按「一个深度 = 一个区」投影成旧版相容视图 `[{area, room, kinds, exits}]`：R5 移植旧断言的桥 |
| `from_route(route, floor_index = 1) -> Dictionary` | 由显式房间列表构造「每层 1 节点」的链式图；`from_route(LEGACY_ROUTE)` 证明节点图能**逐槽**表达既有 7 区关卡。少于 2 槽 → `{}` |

> 建议在 `ROGUE-CONTRACTS.md` 的 CHANGE-LOG 追加一条：**v2 / R4：`RogueGraph` 追加 `LEGACY_ROUTE`、`legacy_areas()`、`from_route()` 三个纯函数；冻结的 5 个签名与返回键未变。**

### 1.3 结构设计（为什么这样能满足地图侧的硬约束）

分层 DAG，深度 `1..D`：

- 第 1 层恒为**唯一入口**，`kind == "combat"`（对应旧 `route[0]`）；
- 第 D 层恒为**唯一 boss**，`next == []`；
- 中间层每层 1~2 个节点；**深度 d 的每个节点与深度 d+1 的全部节点相连** ⇒ 每个非 boss 节点的出口数恰好 = 下一层节点数 ∈ `[1,2]`；
  - `ground-manifest.json` 每个 region key 恰好 2 个出口、`rogue_map.exit_position(index)` 只支持 0/1（`rogue_map.gd:112`）⇒ **不会出现 3 出口**；
  - `rogue_map.gd:94-95` 的 `assert(joined.size()==1)` 不会被触发（出口数不超 2）；
- 全图**无环**（边只连向 `depth+1`）、**无死路**（除 boss）、**从入口全可达**；
- 节点数 = `D + extra` ∈ `[7,10]`（`D ∈ [7,9]`，`extra ∈ {0,1}` 表示某一中间层放两个节点，玩家二选一）；
- 房间类型分配规则：入口 `combat`；紧邻 boss 的那层只放 `combat/elite`；新房间有**最小深度**限制（`curse/event/forge ≥ 3`、`gamble ≥ 4`、`mirror ≥ 5`），每种新房间**每层最多 1 个**；`talent` 每层最多 2 个；**每层保底 ≥1 个商店/宝藏补给节点**；
- **确定性**：`rng.seed = (seed_value*1103515245 + floor*12345 + 0x5F3759DF) & 0x7FFFFFFF`，用**独立 `RandomNumberGenerator` 实例**，不调用任何全局 `randi()/randf()`，不读写 `s.rng`（契约 C2/§6.2 第 2 条）。

节点 id 形如 `f{floor}-d{depth}-{index}`（自带层号，跨层混用时可自查）。

---

## 2. 验收（原始输出）

### 2.1 本轮定向测试

```
> & "D:\game\CrimsonTide-godot\Godot_v4.7.2-stable_win64_console.exe" `
      --headless --path . --check-only --script scripts/rogue_graph.gd
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
exit=0                     # 无 ERROR / SCRIPT ERROR

> & ... --headless --path . --check-only --script tests/rogue_graph.gd
exit=0

> & ... --headless --path . --script tests/rogue_graph.gd
ROGUE GRAPH 83608 checks / 0 failures | nodes 7..10 depths 7..9 distinct(floor1) 200/200 seven-chain 172 kinds 11
exit=0                     # stderr 0 行（无任何 push_error）
```

- 墙钟耗时 **0.73s**（`Measure-Command`），远低于 `run_all_tests.ps1` 的 60s/测试上限。
- 原始日志：`build/r4/rogue_graph.out.txt` / `.err.txt`（另有 `-timed.*` 一份）。

### 2.2 测试覆盖了什么（对应任务书的 6 条验收）

| # | 验收要求 | 落地断言 | 实测 |
| --- | --- | --- | --- |
| ① | 同种子同 floor → 图完全相同（逐字段 diff） | 100 种子 × 5 层，两次 `build` 做**规范化逐字段转储比对** + `signature` 相等 | 1000/1000 通过 |
| ② | 不同种子 → 图不同 | 200 个种子的 floor 1 签名去重，区间断言 `≥50` | **200/200 全不同** |
| ③ | 出口数 ∈ `[1,2]`、无死路、全图可达 | 每节点校验 + BFS 可达性（`reached == nodes.size()`） | 1000 张图全过 |
| ④ | 每层恰 1 个 boss 且最深、可达 | `boss_ids.size()==1`、`boss.depth==max_depth`、`boss.next 为空`、根 `boss` 字段指向它 | 1000 张图全过 |
| ⑤ | 所有房间类型都能抽到（含 5 种新） | 200 种子 × 5 层 = 1000 张图累计 `seen_kinds`，逐类型 `≥1` | **kinds 11/11**（10 种非 boss + boss） |
| ⑥ | 与「7 区」等价映射成立 | ①`from_route(LEGACY_ROUTE)` → `legacy_areas` 恰 7 区、逐槽房间名一致、每区 1 节点、第 7 区是 boss；②1000 张图中 **172 张本身就是 7 节点单层链**，对这些图断言 `legacy_areas().size()==7` | 通过 |
| 附加 | 节点数 `[7,10]` / 层数 `[7,9]` 全覆盖 | 采样区间端点比对 | `nodes 7..10`、`depths 7..9` |
| 附加 | 只许用局部 RNG | 全局 `seed(20261005)` + `randi()` 前后取值比对，`build()` 不得扰动全局序列 | 通过 |
| 附加 | 图必须 JSON 可序列化（联机/存档前提） | 每张图 `JSON.stringify` → `parse_string` → `signature` 不变 | 1000/1000 通过 |
| 附加 | 每层 ≥1 补给、新房间深度下限、新房间每层唯一、层内边只连 `depth+1`、`order` 无重复且覆盖全节点 | 逐项断言 | 全过 |

---

## 3. 回归（含并发污染说明）

命令：`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/<name>.gd`，单条 180s 上限，日志 `build/r4/<name>.out.txt|.err.txt`。

| 测试 | 本轮实测 | R1 基线（`TEST-BASELINE.md` §1） | 判定 |
| --- | --- | --- | --- |
| `roguelike_seven_rooms` | **1856 / 0** | 1856 / 0 | 一致 |
| `roguelike_routes` | **5219 / 5** | 5219 / 5 | 一致（失败集合未变） |
| `rogue_build_growth` | **4066 / 0**（宝箱样本 `[182,489]`） | 4066 / 0（样本 `[213,500]`） | 失败数一致；样本落在既有宽区间 `[140,261] / [420,581]` 内 |
| `systems` | **10812 / 0** | 10812 / 0 | 一致 |
| `rogue_build_progression` | **533 / 41**（连跑两次同值） | 505 / 39 | **漂移 ≠ 本轮引起**，见下 |

### 3.1 `rogue_build_progression` 漂移的取证

| 时刻 | checks / failures | 期间发生了什么 |
| --- | --- | --- |
| R1（19:2x） | 505 / 39 | 基线测量 |
| 本轮第一次跑 | 520 / 39 | — |
| 本轮随后两次跑 | 533 / 41（两次完全相同） | `git status` 显示 `scripts/roguelike.gd`、`scripts/session.gd`、`scripts/profile.gd` **已被并发轮次（R2/R3/R5?）修改** |

**证据链**：

1. 本轮只**新增**两个文件，且全仓库 `grep 'RogueGraph|rogue_graph'` **只命中 `output/*.md` 文档**——没有任何既有源码/测试引用它们，不可能改变 progression 的执行路径。
2. `git status --short`（源码子集）：`M scripts/roguelike.gd`、`M scripts/session.gd`、`M scripts/profile.gd`（A 集合 W1 的文件），另有 W7 表现层 8 个文件被改。
3. 同一测试在本轮内**先 520/39、后 533/41**，且 533/41 可重复 ⇒ 是**别的轮次在测量窗口内改 A 集合**导致的漂移，符合 `TEST-BASELINE.md` §0.1 已预警的并发污染模式。
4. 该测试的 39 条既存失败本就归属 **R5**（节点图接管推进后统一移植口径，见基线 §2.1）。

> **给 R5/R18 的建议**：把 progression 的 checks 计数**永久标记为"随并发写者浮动"**，门禁只比对 `failures`（39→41 的 +2 需在 R5 移植时一并归零或登记），不要比对 checks。

### 3.2 未跑的两个红项（按基线豁免，未重复踩坑）

- `rogue_build_rules`：断言第 1 条即崩且**不调 `quit()` → 进程挂死**（`TEST-BASELINE.md` §2.3），本轮不跑。
- `rogue_build_pack`：资产红（`W001` 图标缺失），与本轮无关，本轮不跑。

---

## 4. 待接线清单（提交者 W6：轮次 R4）

> 格式按 `ROGUE-CONTRACTS.md` §8.1。**R4 只新建文件，未接线**；下列每条都要等**文件所有者轮次**来落。

### 4.1 `scripts/roguelike.gd`（所有者 **W1**，建议由 R5 落）

```
- 目标文件: scripts/roguelike.gd
- 目标函数/锚点: new_floor()（第 57-59 行）/ enter()（第 61-114 行）
- 期望插入代码:
    const RogueGraph = preload("res://scripts/rogue_graph.gd")
    # new_floor(): 用节点图取代 7 槽模板
    s.rogue_graph = RogueGraph.build(int(s.seed_value), int(s.raid.floor))
    s.raid.graph_floor = int(s.raid.floor)
    s.raid.node = str(s.rogue_graph.entry)
    # 推进：raid.node 从 RogueGraph.node(g, node).next 里二选一，depth += 1
- 依赖的契约: §2 raid.node / raid.depth / raid.graph_floor；C1「图放 s.rogue_graph，不进 raid」
- 验收断言: tests/rogue_graph.gd 全绿 + 移植后的 tests/roguelike_seven_rooms.gd
- 未接线时的临时状态: 旧 route[] 仍然生效，RogueGraph 未被任何源码引用，游戏行为零变化
```

### 4.2 `scripts/rogue_map.gd`（所有者 **W4**，C3 ①）

```
- 目标文件: scripts/rogue_map.gd
- 目标函数/锚点: static func region_key(floor_index, area, room)（第 50-54 行），映射表在第 51 行
- 期望插入代码（冻结映射，必须指向 ground-manifest.json 里已存在的 key）:
    curse→"f{n}-treasure"、event→"f{n}-talent"、forge→"f{n}-shop"、
    gamble→"f{n}-treasure"、mirror→"f{n}-talent"
- 依赖的契约: §7.2 ①
- 验收断言: 5 个新 room 名各自的 region_key 命中 manifest 现存 key（即顶层断言不为空）
- 未接线时的临时状态: 新 room 会被当成 -a{artwork_area} 战斗长房（不崩，但与设计不符）
```

### 4.3 `scripts/roguelike.gd:76`（所有者 **W1**，C3 ②）

```
- 目标文件: scripts/roguelike.gd
- 目标函数/锚点: enter() 第 76 行 `s.ruins.configure(..., room not in ["shop","treasure","talent"], room)`
- 期望插入代码: 谓词扩成 room not in ["shop","treasure","talent","curse","event","forge","gamble","mirror"]
- 依赖的契约: §7.2 ②
- 验收断言: 新房间进入后不刷怪、走 clear_room() 分支
- 未接线时的临时状态: 新房间变成战斗长房
```

### 4.4 `scripts/session.gd`（所有者 **W1**）

```
- 目标文件: scripts/session.gd
- 目标函数/锚点: 顶层变量区（`var bullets: Array = []` 附近，第 45 行）——**不要**加进 snapshot 白名单（session.gd:1467）
- 期望插入代码: var rogue_graph: Dictionary = {}
- 依赖的契约: C1（图不进每 0.1s 快照；客户端用 RogueGraph.build(seed_value, floor) 本地重建）
- 验收断言: snapshot() 的白名单数组长度仍为 12/13 项；tests/roguelike_network 不因此报错
- 未接线时的临时状态: 无 s.rogue_graph，R4 的图只在测试里用
```

### 4.5 ⚠ 类名缓存（**R5 前必须先做一次**，否则标识符用不了）

实测：`& .\tools\check_class_cache.ps1 -ProjectPath . -CheckOnly`
→ `[setup] Stale Godot class cache: 4 class(es) missing -> RogueCurses, RogueEvents, RogueGraph, RogueVariants`（exit 1）

**含义**：本仓库的 `class_name` 靠 `.godot/global_script_class_cache.cfg`（该文件被 gitignore）。在 headless `--script` 下缓存**不会**自动重建，所以**别的脚本直接写 `RogueGraph.build(...)` 会在解析期报「找不到标识符」**。

**两种解法（任选，建议等所有 W6 模块落地后一次性做）**：

1. `& .\tools\check_class_cache.ps1 -ProjectPath .`（内部执行 `--headless --path . --import` 重建缓存）；
2. **或者**在所有消费方用 `const RogueGraph = preload("res://scripts/rogue_graph.gd")`（本测试就是这么写的，**不依赖缓存**）。

`tests/rogue_graph.gd` 走的是第 2 条，所以本轮验收不受该问题影响。

---

## 5. 风险与观察（给 R5/R18）

1. **`legacy_areas()` 的语义边界**：它把「一层」当成「一个区」，所以层里有 2 个节点时 `kinds` 有 2 个元素而 `room` 取第一个。R5 移植 `tests/roguelike_seven_rooms.gd` 时应把断言从「`route.size()==7`」改成「`RogueGraph.build(...).nodes.size() ∈ [7,10]`」，用 `legacy_areas()` 只为「旧结构仍可表达」提供证明，不要把它当运行时 API。
2. **补给保底替换会吃掉一个新房间**：若某层没有 shop/treasure，代码会随机替换一个中间层节点——被替换掉的如果恰好是某种新房间，`used_new` 已置位，该层不会再抽第二种新房间（略降低新房间出现率，但不破坏任何不变量）。
3. **新房间不产生第 3 个出口**：本设计保证出口数 = 下一层节点数 ≤ 2，与 `ground-manifest.json` 的 2 出口一一对应；R5 若给某层放 3 个节点，**必须先改 `exit_position`/manifest**，否则 `rogue_map.configure` 的合并断言会崩。
4. **`s.rng` 消耗零变化**：`RogueGraph` 不碰 `s.rng`，所以 R5 接入后，只要不改 `enter()` 里既有的消耗顺序（契约 §6.2），同种子复现性不受影响。
