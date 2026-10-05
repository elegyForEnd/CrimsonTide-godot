# 魔境扩展 · 接口契约（冻结版 v1）

- **冻结轮次**：R1（`output/ROGUE-EXPANSION-EXECUTION-PLAN.md` §3.2 R1）
- **冻结日期**：2026-10-05
- **状态**：**FREEZE**。从 R2 开始，所有轮次必须按本文档的字段名/类型/默认值/API 签名实现；
  需要改动只能**追加**（本文档底部 CHANGE-LOG），**不得改名、不得改类型、不得改默认值**。
- **适用范围**：`scripts/roguelike.gd`、`scripts/session.gd`、`scripts/profile.gd`、`scripts/rogue_combat.gd`、
  `scripts/rogue_map.gd`、`scripts/rogue_field.gd`、`scripts/main.gd`、`server/app.py`，
  以及 W6 新模块 `rogue_graph.gd` / `rogue_variants.gd` / `rogue_curses.gd` / `rogue_growth.gd` /
  `rogue_daily.gd` / `rogue_events.gd` / `rogue_boss_pool.gd` / `*_ui.gd`。
- **本文件由 R1 只读勘察产出**：所有行号均在本工作副本实测复核（复核清单见 §0），未修改任何源码。

---

## 0. R1 决议：对计划文档的 5 处纠正（以此处为准）

| # | 计划文档的说法 | R1 复核结果 | 冻结决议 |
| --- | --- | --- | --- |
| C1 | §3.1 把 `graph`(Dictionary) 列为 `s.raid` 新增键 | **自相矛盾**：`s.raid` 整体就是快照包 `data[11]`（`scripts/session.gd:1467`），进 `raid` 就等于每 0.1s 同步整张图；而 §5.2 明令不许把图放进快照 | **`graph` 不进 `s.raid`**。权威图放**新的非快照字段** `s.rogue_graph`（`session.gd` 顶层 var，**不在白名单里**）；客户端一律用 `RogueGraph.build(seed_value, floor)` 本地重建（确定性，见 §5）。`s.raid` 只保留 `node`/`depth` |
| C2 | §3.1 RNG 配方要求 `enter()` 里 `[抽变数]→[节点图]→[exits]→[spawn_wave]` | 若节点图消耗 `s.rng`，客户端本地重建将依赖与服务端**完全一致**的 `s.rng` 消耗序列，极其脆弱 | **`RogueGraph` 使用自己的局部 RNG**（种子由 `seed_value`/`floor` 纯函数派生），**绝不触碰 `s.rng`**。`s.rng` 里只新增"每层首区抽变数"这一次消耗点，位置固定见 §6 |
| C3 | §3.1/§3.2 只说要给 `curse/event/forge/gamble/mirror` 映射 region key | 复核实测：`RogueMap.region_key()`（`scripts/rogue_map.gd:50-54`）对非 `shop/treasure/talent` 的 room 会走 `-a{artwork_area}` 分支（**不是崩溃，而是变成战斗长房**），真正的开/闭长房开关在 `roguelike.gd:76` 的 `room not in ["shop","treasure","talent"]` | 新房间名**必须同时**登记到两处：①`region_key()` 的映射表；②`enter()` 的"非战斗房"谓词。两处漏一处即"新房间变成战斗长房"，与设计不符 |
| C4 | §0/§4.2 未登记 `boss_tactics` 基线 | 实测 **186 checks / 1 failure**（`Real projectile collision uses frontal guard once`），且测量时并发渲染任务正在改 `combat_visuals.gd`（19:33:38 写入，测试 19:35:03 运行） | 该值记为**临时值**，渲染任务落定后必须复测并正式登记；R6/R14 改 `rogue_combat.gd` 时必须以**复测后**的数字为基线 |
| C5 | §0 说 `rogue_build_rules` = 「1 failure + SCRIPT ERROR」 | 结论正确但**严重低估**：SCRIPT ERROR 发生在该测试的**第 1 个 debug check**（`tests/rogue_build_rules.gd:50-51`，W001 图标为 `null` → 读 `.atlas` 崩溃），脚本随即中断且**从不调用 `quit()`**，进程挂死（60s/180s 均超时被杀）。后续 100+ 条断言**从未执行** | `rogue_build_rules` 当前**有效覆盖为零**，不能按"1 failure"计入门禁；R18 前必须先恢复肉鸽构建美术（见 `TEST-BASELINE.md` §3），否则该测试永远不能当回归依据 |

---

## 1. 联机与快照硬约束（所有新状态的"可观测性"前提）

实测位置全部复核过：

| 约束 | 位置 | 含义 |
| --- | --- | --- |
| 快照是**白名单式顶层数组** | `scripts/session.gd:1467` | `[players,enemies,bullets,world_drops,chests,shrines,elapsed,objectives,threat,results,map_id,raid,ruins.sites]`。**只有进 `raid` 或 `players[*]` 的状态才会同步**；新的顶层 session 变量不会 |
| 接收端只接受两种长度 | `scripts/session.gd:1487` | `data.size() not in [12,13]` → 直接 return。**禁止新增顶层元素** |
| `players` 是整表替换 | `scripts/session.gd:1505` | `players=data[0]`，所以 `players[*]` 加字段是安全的（整表传）；但**必须是 JSON/`var_to_bytes` 可序列化类型** |
| 客户端重建地图只用 `floor/area/room + seed_value` | `scripts/session.gd:1494-1497` | `ruins.generate(seed_value+floor*100+area)` + `ruins.configure(floor-1,area,room not in [shop,treasure,talent],room)`。**新增 room 名会走到客户端这条分支** → 必须与 C3 的两处登记一致 |
| `seed_value` 必须全队一致 | `scripts/session.gd:1374,1397-1399,1408` | `launch()` 定种子 → `begin(seed_value,...)` → 联机 `begin.rpc(seed_value,...)`。**每日挑战的种子必须由房主算好随 `begin` 下发**，禁止各客户端按本地日期各算 |
| `s.rng` 只在 `begin()` 设一次 | `scripts/session.gd:64,1415` | `var rng := RandomNumberGenerator.new()`；`rng.seed=value+71`。**任何新代码不得重置 `s.rng.seed`** |
| 表现层走 `raid["visual_*"]` 每 0.1s 重发 | `scripts/session.gd:1464-1466,1502-1504` | `raid["visual_effects"]/["visual_missiles"]`。**状态真相不得走这里** |
| 相机/推进依赖 `region.exits` 恰好 2 个出口 | `scripts/rogue_map.gd:112-113`、`roguelike.gd:580-581`、`assets/rogue/regions/ground-manifest.json`（实测 50 个 key **每个都是 2 个 exit**） | **禁止做 3 出口**（计划 §3.3 已列为禁项，此处再钉死） |
| 合并断言 | `scripts/rogue_map.gd:94-95` | `assert(joined.size()==1,"Both level paths must join the same floor")`——用错 region key 会**直接断言崩溃**，联机时只在客户端崩 |

---

## 2. `s.raid` 新增键（冻结）

`reset()`（`scripts/roguelike.gd:24-25`）**必须**一次性写全下表所有键（含默认值），否则 `snapshot()`/`bytes_to_var` 往返与客户端读取都会拿到 `null`。

| 键 | 类型 | 默认值 | 语义 | 写入者 | 快照位置 |
| --- | --- | --- | --- | --- | --- |
| `variant` | String | `""` | 当前层生效的"深渊变数" id；`""`＝无（第 1 层首区抽取，整层不变） | W1（`reset`/每层首区 `enter`） | `raid`（自动同步） |
| `variant_serial` | int | `0` | 变数抽取序号，用于 UI 的"本层新变数"提示，单调递增 | W1 | `raid` |
| `curse_serial` | int | `0` | 诅咒施加序号，用于一次性提示与去重 | W1 | `raid` |
| `seed_shared` | String | `""` | 展示/分享用的种子串（可空，不参与逻辑） | W2（R11 UI） | `raid` |
| `daily` | bool | `false` | 本局是否为每日挑战（仅标记；种子仍由 `seed_value` 承载） | W1 | `raid` |
| `node` | String | `""` | 节点图当前节点 id；`""` 表示"未接管"（过渡态，R5 完成后不得出现） | W1 | `raid` |
| `depth` | int | `1` | 当前节点在**本层**的深度（1-based） | W1 | `raid` |
| `pending_event` | Dictionary | `{}` | 事件房待选状态：`{"offer":Array,"revision":int}`；空＝无待选 | W1 | `raid` |
| `pending_forge` | Dictionary | `{}` | 铁匠铺待选：`{"offers":Array,"revision":int}` | W1 | `raid` |
| `pending_gamble` | Dictionary | `{}` | 赌徒待选：`{"stake":int,"revision":int}` | W1 | `raid` |
| `mirror_state` | Dictionary | `{}` | 镜像挑战：`{"active":bool,"owner":int,"round":int,"settled":bool}` | W1 | `raid` |
| `graph_floor` | int | `0` | 权威图对应的层号（用于 `s.rogue_graph` 失效判定；见 §5） | W1 | `raid` |

**明确不进 `s.raid` 的东西**：

- 整张节点图 → 放 `s.rogue_graph`（非快照，确定性重建，见 C1/§5）。
- 每层变数**定义表**（纯静态数据）→ 放 `RogueVariants.table()`，不入存档、不入快照。
- 灰烬与成长树进度 → 属于**局外存档** `profile.data`，见 §4；`s.raid` 里只放本局计数 `rogue_ash_run`（见 §3）。

---

## 3. `s.players[*]` 新增键（冻结）

`players` 是整表替换（`session.gd:1505`），加字段安全；但要在 `roguelike.reset()`（`scripts/roguelike.gd:27-49` 的 `for p in s.players.values()` 循环内）写出默认值。

| 键 | 类型 | 默认值 | 语义 | 写入者 |
| --- | --- | --- | --- | --- |
| `rogue_curses` | Array（元素为 String） | `[]` | 本局该玩家身上的诅咒 id 列表（诅咒是**个人**的；变数是**全队**的） | W1（`reset`）+ `RogueCurses.apply()` |
| `rogue_ash_run` | int | `0` | 本局已累计、尚未结算进 `profile.ashes` 的灰烬 | `RogueGrowth.grant()`，仅由 `settle()` 调用一次 |
| `rogue_mirror_used` | bool | `false` | 本次镜像挑战是否已领奖（防重复击杀重复发奖） | W3/W6 镜像逻辑 |

---

## 4. `profile.data` 新增键（冻结）＋ 存档迁移

| 键 | 类型 | 默认值 | 语义 |
| --- | --- | --- | --- |
| `ashes` | int | `0` | 局外货币"灰烬"总额（只加不减，扣除时不得低于 0） |
| `growth` | Dictionary | `{}` | 成长树进度：`{节点id:String -> 等级:int}`；等级上限由 `RogueGrowth.tree()` 定义 |

### 4.1 迁移规则（**保持 `version == 1`**，只新增键）

实测依据：

- `scripts/profile.gd:6` 是默认 `data` 字典；`_init()`（`:20-23`）补 `home`/`warehouse`/`trade_history`。
- `scripts/profile.gd:32` `if parsed is Dictionary and parsed.get("version",0) == 1:` —— **不成立就整段跳过**，
  紧接着 `sanitize_storage()` 用默认值覆盖 → **改版本号＝老档全丢**。
- `scripts/profile.gd:37-39` 逐键 `typeof(parsed[key]) == typeof(data[key])` 才赋值 → **新键必须先在 `_init()` 给出同类型默认值**，否则第一次存档时该键被静默丢弃。
- `scripts/profile.gd:41-43` 对 `coins/xp/...` 做 `is float or is int` → `maxi(0,int(...))` 纠正（JSON 数字是 float）。
  → **`ashes` 必须加入这个列表**（或等价处理），否则存档里会出现 `0.0` 这种 float。
- `scripts/profile.gd:107-116` `save_profile()` 是 `JSON.stringify` 落盘整份 `data`。
- `scripts/online_service.gd:65,74-82` 上传 `profile.data.duplicate(true)`，用 `JSON.stringify` 比较 dirty
  → 新键**必须 JSON 可序列化**（禁止 `Vector2`/`Object`/`NaN`/`INF`）。
- `server/app.py:409` `data.get('version') != 1` → 400 `存档格式错误` → **改版本号必须同轮改服务端**，
  "保持 version 1"是省事且安全的路线。
- `server/app.py:420-431` `attributes` 有 key 白名单（`vigor/mind/endurance/strength/dexterity/intelligence/arcane`）
  与"属性点不超等级预算"校验 → **`ashes`/`growth` 绝不可塞进 `attributes`**，必须独立顶层键。
- `server/app.py:408-448` 全文实测**不拒绝未知顶层键** → 新增 `ashes`/`growth` 不需要改服务端。

### 4.2 迁移验收（R3 必须逐条给出原始输出）

1. 构造 **老档 JSON**（`version:1`，无 `ashes`/`growth`）→ `Profile.apply_data(...)` → 断言
   `coins/xp/runs/extracts/hero/gear/talents/attributes/warehouse/pocket/bags/home/unlocks/trade_history`
   **逐项不变**，且 `ashes == 0`、`growth == {}`。
2. 老档 → `save_profile()` → 重新 `load_profile()` → 再断言一次（"老档 读→存→再读" 回环）。
3. 构造 `version:2` 档 → 断言当前实现**不会**静默丢档（按 §4.1，v2 会被整段跳过 → 属于禁止行为，
   实现必须保证永远写 1）。
4. 用 `validate_profile`（可直接 `python -c` 导入 `server/app.py`）喂新档 → 断言**不抛 400**。

---

## 5. 新模块静态 API（签名一次定死）

约定：`s` 一律是 `TideSession` 实例；`p` 是 `players[id]` 字典；返回值**不得**是裸 `Object`/`Vector2`
（要进快照/存档的必须是 JSON 可序列化类型）。

```gdscript
# scripts/rogue_graph.gd  —— class_name RogueGraph, extends RefCounted
static func build(seed_value: int, floor: int) -> Dictionary
#   返回: {"floor":int, "entry":String, "boss":String, "order":Array[String],
#          "nodes":{ id:String -> {"id":String,"kind":String,"depth":int,"next":Array[String]} }}
#   约束: 每层恰好 1 个 boss；boss 深度最大且 next 为空；无环；节点数 ∈ [7,10]；
#         入口到 boss 至少 1 条路径；每层至少 1 个 shop/treasure 补给节点；
#         同 (seed_value,floor) 两次调用 hash 相同（用局部 RNG，不得触碰 s.rng）
static func kinds() -> Array          # 可出现的非 boss kind 列表（含 combat/elite/shop/treasure/talent/curse/event/forge/gamble/mirror）
static func neighbors(g: Dictionary, id: String) -> Array   # 后继节点 id（有序）；未知 id → []
static func node(g: Dictionary, id: String) -> Dictionary   # 节点字典；未知 id → {}
static func signature(g: Dictionary) -> String              # 稳定摘要（用 order+kind+depth+next 拼接），供测试比对
# 副作用: 无（纯函数，不读写 s）

# scripts/rogue_variants.gd —— class_name RogueVariants, extends RefCounted
static func table() -> Array                        # 纯数据: [{"id":String,"name":String,"desc":String,"effect":Dictionary}]
static func roll(s) -> Dictionary                   # 唯一 s.rng 消耗点（见 §6）；副作用: 写 s.raid.variant / variant_serial；返回被抽中的定义
static func active(s) -> Dictionary                 # 只读；返回当前变数定义，无则 {}

# scripts/rogue_curses.gd —— class_name RogueCurses, extends RefCounted
static func table() -> Array
static func apply(s, p: Dictionary, curse: String) -> bool      # 副作用: p.rogue_curses 追加 + s.raid.curse_serial += 1
static func damage_taken_scale(p: Dictionary) -> float          # 只读；供 session.incoming_damage 复用既有减伤池
static func reward_scale(s) -> float                            # 只读；供 clear_room/掉落使用

# scripts/rogue_events.gd —— class_name RogueEvents, extends RefCounted
static func roll_offer(s) -> Dictionary                         # 事件房三选一；副作用: 写 s.raid.pending_event
static func apply(s, p: Dictionary, index: int) -> bool          # 结算所选事件；副作用: 清空 pending_event + 发放奖励

# scripts/rogue_growth.gd —— class_name RogueGrowth, extends RefCounted
static func tree() -> Dictionary                                 # {id -> {"cost":int,"max":int,"requires":Array[String],"effect":Dictionary}}
static func power(profile_data: Dictionary) -> Dictionary        # 只读；{"enemy_hp":float,"enemy_damage":float,"start_coins":int,"start_rerolls":int}
static func can_buy(profile_data: Dictionary, id: String) -> bool
static func buy(profile_data: Dictionary, id: String) -> bool     # 副作用: 扣 ashes + growth[id]+=1（不落盘，由调用方 save_profile）
static func ashes_on_settle(s, p: Dictionary) -> int              # 只读；本局应得灰烬
static func grant(s, p: Dictionary) -> int                        # 副作用: p.rogue_ash_run += 值 + 累加 profile.data.ashes；仅 settle() 调用一次

# scripts/rogue_daily.gd —— class_name RogueDaily, extends RefCounted
static func today() -> String                                    # "YYYY-MM-DD"（房主本地时间）
static func seed_for(date_string: String) -> int                  # 纯函数；同一天同值、跨天不同值；非法输入 → 0
static func parse_seed(text: String) -> int                       # 分享串解析；非法输入 → 0（不崩）

# scripts/rogue_boss_pool.gd —— class_name RogueBossPool, extends RefCounted
static func keys() -> Array                                      # 复用 assets 既有 17 个 art key（见 boss_effect_art.gd KEYS）
static func skin_index(floor: int) -> int                         # 返回 rogue_skin（**必须仍是 int**）；不得改 rogue_skin 类型
```

**新模块必须 `class_name` + `extends RefCounted`**（与本仓库既有 `RogueBuild`/`RogueContent` 风格一致），
且**不得**新增 autoload（`project.godot` 无 `[autoload]` 段，本次也不新增）。

---

## 6. RNG 消耗配方（同种子可复现的硬规则）

### 6.1 现状清单（实测 `grep '\.rng\.' scripts/*.gd`）

| 文件 | 行 | 时机 |
| --- | --- | --- |
| `scripts/roguelike.gd` | 134,143,171 | `spawn_wave()` 选怪/洗牌/撒点 |
| `scripts/roguelike.gd` | 287,302,313,314,318,327,333,335 | `roll_offers()`/奖励抽卡/铭刻 |
| `scripts/roguelike.gd` | 379 | 宝箱属性碎片掉落 |
| `scripts/roguelike.gd` | 611 | `random_destinations()`（出口） |
| `scripts/rogue_build.gd` | 330,999 | 暴击判定、纪念品发现 |
| `scripts/rogue_minions.gd` | 105,108,123,124,125 | **物理帧内**的小怪出手节奏 |
| `scripts/expedition.gd` | 35,109,117,120,154,155,218,281 | 战役模式，与本目标无关 |

**结论**：`s.rng` 在**战斗模拟的每一帧**都会被 `rogue_minions` 消耗，所以"整条序列"不可能跨进程逐步对齐；
可行的纪律只有一条 —— **服务端是唯一随机源，随机结果必须落在会同步的字段里。**

### 6.2 冻结配方

1. **`enter()`（`scripts/roguelike.gd:61`）里的消耗顺序固定为**：
   `[若 depth==1 且是新层：RogueVariants.roll(s)] → [s.raid["exits"]=exit_choices(s)] → [spawn_wave(s)]`。
   其余任何位置**不得**新增 `s.rng` 消耗。当前实现顺序是 `exits`(第 84 行) → `spawn_wave`(第 113 行)，
   所以**变数抽取必须插在第 84 行之前**。
2. **`RogueGraph.build()` 不得使用 `s.rng`**（用局部 RNG，种子由 `seed_value`/`floor` 派生）。
3. **`RogueGrowth.power()`/`RogueSeed`/每日挑战、事件房三选一、赌徒下注、镜像是新的随机点**：
   - 凡结果要进 `raid`/`players`（会被同步）的 → 允许用 `s.rng`，但必须是**唯一确定的调用位置**，
     并在 `tests/` 里用固定种子断言"同种子同结果"。
   - 凡**不影响状态真相**的（如赌徒的期望值统计）→ 也必须用 `s.rng`，**禁止 `randi()`/`randf()` 全局函数**。
4. **禁止重置 `s.rng.seed`**（唯一写点是 `session.gd:1415`）。测试里若要复现，用 `s.rng.seed=固定值`
   仅限测试脚本自身（既有测试如 `tests/roguelike_seven_rooms.gd:25,32` 就是这么做的，允许）。
5. **客户端不得消耗 `s.rng`**：客户端只走 `snapshot()` 的 `ruins.generate/configure`（后者用 `rogue_map.gd:71-72`
   的局部 RNG），**不调用** `roguelike.enter()`。

---

## 7. 房间类型与 region key 契约

### 7.1 房间名合法集合（冻结）

`combat` / `elite` / `shop` / `treasure` / `talent` / `boss`（现有）
＋ `curse` / `event` / `forge` / `gamble` / `mirror`（新增）。

### 7.2 新房间必须同时登记的两处

| 处 | 文件:行 | 规则 |
| --- | --- | --- |
| ① region key 映射 | `scripts/rogue_map.gd:50-54` | 新房间**必须**显式返回一个**已存在于** `assets/rogue/regions/ground-manifest.json` 的 key。冻结映射：`curse→f{n}-treasure`、`event→f{n}-talent`、`forge→f{n}-shop`、`gamble→f{n}-treasure`、`mirror→f{n}-talent` |
| ② 非战斗房谓词 | `scripts/roguelike.gd:76` | `room not in ["shop","treasure","talent"]` 必须扩成包含 `curse/event/forge/gamble/mirror`，否则新房间会被 `configure(..., long_room=true, ...)` 当成战斗长房 |

**已实测**：`ground-manifest.json` 共 50 个 key（`f1..f5` 各 `a1..a7`、`shop`、`treasure`、`talent`），
**每个 key 的 `exits` 恰好 2 个** → 出口数不因新房间而变，`exit_position(index)` 只支持 0/1。

### 7.3 战斗/非战斗的后果差异（写实现前必读）

- 非战斗房走 `enter()` 的 `elif` 分支 → `clear_room(s)`（`:109`），**不刷怪**。
- 战斗房走 `spawn_wave(s)`（`:113`），`'shop'` 走 `roll_offers`（`:107`）。
- 新房间若要"进房立刻给三选一"，应复用 `clear_room()` + `raid.pending_*`，**不要**新增 phase 名
  （`phases` 被 `main.gd:1561`、`tests/*`、`rogue_build_progression.gd:57/85/87` 等多处字符串匹配）。

---

## 8. 文件所有权（防互相踩的硬规则）

**规则**：每个文件在任何时刻只有一个"所有者轮次"在写；其他轮次**只读**，需要改就回传**待接线清单**。

| 集合 | 文件 | 所有者 |
| --- | --- | --- |
| **A 核心状态与入场** | `roguelike.gd`、`session.gd`、`profile.gd` | W1（R2/R3/R5/R16 排队） |
| **B HUD 与界面** | `main.gd`、`rogue_field.gd` | W2（R7→R13） |
| **C 战斗与呈现** | `rogue_combat.gd`、`boss_choreography.gd`、`boss_effect_art.gd`、`sound.gd` | W3（R6→R14→R15） |
| **D 地图** | `rogue_map.gd`、`rogue_art.gd` | W4 |
| **E 内容/数据** | `resources/rogue_build_content.json`、`tools/build_rogue_content.py`、`ROGUE-BUILD-SYSTEM-DESIGN.md`、`server/app.py`、`ROGUELIKE.md` | W5 |
| **F 新文件** | `rogue_graph.gd`、`rogue_variants.gd`、`rogue_curses.gd`、`rogue_events.gd`、`rogue_growth.gd`、`rogue_daily.gd`、`rogue_boss_pool.gd`、`rogue_*_ui.gd` | W6（可并行） |
| **G 弹幕/表现（本次新增，冲突面最大）** | `combat_visuals.gd`、`effect_semantics.gd`、`rogue_enemy_vfx.gd`、`boss_effect_staging.gd`、`boss_damage_visual.gd`、`boss_vfx.gd`、`battlefield.gd`、`attack_telegraph.gd`、`resources/boss_damage_shape.gdshader`、`resources/boss_entity_birth.gdshader` | **W7＝正在进行的并发"敌人弹幕视觉"任务独占**；其余轮次（含 R0 验收、R6/R14/R15）**只读**，需要改就回传清单 |
| **H 计划与基线文档** | `output/*.md` | 各轮只追加自己的文件；**不得改写他人已产出的基线数字**（只允许追加"更正"小节） |

> G 集合的存在是 R1 实测确认的：`scripts/combat_visuals.gd`(19:33:38)、`effect_semantics.gd`(19:27:45)、
> `boss_effect_staging.gd`(19:27:22)、`rogue_enemy_vfx.gd`(19:27:42)、`boss_damage_visual.gd`(19:27:58)、
> `battlefield.gd`、`boss_vfx.gd`、两个 shader 均已被并发任务修改（`git status` 可见），
> 另新增未跟踪文件 `scripts/attack_telegraph.gd`、`tests/attack_telegraph_visual.gd`。

### 8.1 待接线清单格式（非所有者回传用，必须逐条照填）

```
## 待接线清单（提交者 W?：轮次 R?）
- 目标文件: scripts/roguelike.gd
- 目标函数/锚点: enter()，第 84 行 `s.raid["exits"]=exit_choices(s)` 之前
- 期望插入代码: if int(s.raid.depth)==1: RogueVariants.roll(s)
- 依赖的契约: §2 raid.variant / §5 RogueVariants.roll
- 验收断言: tests/rogue_variants.gd 的"同种子同层抽出同一变数"（100 种子）
- 未接线时的临时状态: s.raid.variant 恒为 ""，玩法不生效但测试可跑
```

---

## 9. 通用编码纪律（对所有轮次生效）

1. **新增会进快照/存档的字段**：只用 `int`/`float`/`bool`/`String`/`Array`/`Dictionary`，
   且 `int` 就是 `int`（`float` 用于会变化的数值），`Dictionary` 的键必须是 `String`。
2. **UI 动作必须带 `revision`**：`roguelike.choose()` 在 `scripts/roguelike.gd:565` 校验
   `int(payload.get("revision",-1))!=int(s.raid.revision)` 就丢弃。新增 `rogue_event`/`rogue_forge`/
   `rogue_gamble`/`rogue_mirror`/`rogue_growth`/`rogue_daily` 动作**必须**携带并校验 `revision`，
   否则联机下会出现"过期点击生效"。
3. **结算只有一个出口**：`settle()`（`scripts/roguelike.gd:649-659`）有 `if s.raid.ended: return` 守卫。
   灰烬、每日挑战记录、成长树解锁**只能**在这里发，且只发一次。
4. **不得新增 autoload**；不得新增 `scenes/*.tscn` 依赖。
5. **不得改 `rogue_skin` 的类型**（现为 `int`，`rogue_combat.gd:46,103,149,200,207,209`、
   `sound.gd:87-94` 的字符串拼接 `rogue-%d-...` 都按 int 索引）。Boss 池扩容＝把 `rogue_effect_art.gd`
   的 `ROGUE` 列表扩长 + 放宽 `clampi(...,0,4)`，**不是**换 key。
6. **禁止 3 出口**、**禁止把节点图放进每 0.1s 快照**、**禁止改 `data.version`**（见 §1、§4.1、C1）。
7. **`resources/rogue_build_content.json` 是生成物**：源是 `ROGUE-BUILD-SYSTEM-DESIGN.md` +
   `tools/build_rogue_content.py`（该脚本第 57 行有 `assert == 252`）。加内容必须改源，不能手改 JSON。
8. **`tests/rogue_build_rules.gd` 目前不可用**（见 C5）：任何以它为门禁的轮次必须先处理资产或明确排除。

---

## CHANGE-LOG

- **v1 / 2026-10-05 / R1**：首次冻结。含 C1–C5 五处对计划文档的纠正；
  固化 `s.raid` 12 个新键、`players[*]` 3 个新键、`profile.data` 2 个新键、5 个新模块的静态签名、
  RNG 配方（含"变数抽取必须插在 `roguelike.gd:84` 之前"）、region key 双向登记规则、
  W1–W8 所有权（新增 W7 表现层、W8 文档）、以及 §9 的 8 条通用纪律。
- （后续轮次请在此追加，格式：`vN / 日期 / 轮次：变更点 + 影响的既有契约条目`）

---

## CHANGE-LOG v2（追加；v1 原文一字未改）

- **合并轮次**：R1b（契约维护轮），由顶层调度指派；日期 2026-10-05；工作副本 `D:\game\CrimsonTide-godot`。
- **本附录只做两件事**：①把各轮"只允许追加"的实现**追认**进契约；②把**顶层调度已裁决**的事项固定成条目。
  **不修改、不删除 v1 的任何一行**（v1 全文保留以便追溯）。
- **冲突处理**：与 v1 冲突处以本附录为准，并**逐条标注被取代的 v1 位置**（见 v2-8 取代 §4.1 描述、v2-12 取代 §8 的 F/G 两行）。
- **状态词约定**：`已生效`＝源码已落地且已进调用路径；`已落地·待接线`＝模块已交付、**尚无消费者**（玩法未生效）；
  `计划中·未生效`＝已裁决、尚未执行。
- **R1b 已逐条打开源码核对**（`rogue_graph.gd`/`rogue_variants.gd`/`rogue_curses.gd`/`rogue_events.gd`/`rogue_daily.gd`/
  `rogue_growth.gd`/`rogue_rooms.gd`/`roguelike.gd`/`session.gd`/`profile.gd`/`rogue_map.gd`/`rogue_combat.gd`/
  `boss_choreography.gd`），下文行号均为本工作副本实测；**发现与交付记录不符处集中在 v2-15**。

### v2-1 / R4 / `RogueGraph` 的追加 API（**已生效**）

除 §5 已冻结的 `build/kinds/neighbors/node/signature` 外，`scripts/rogue_graph.gd` **追加**以下三项（契约允许"只追加"）：

| 追加项 | 签名 | 定位与限制 |
| --- | --- | --- |
| `LEGACY_ROUTE` | `const Array` = `["combat","talent","elite","shop","combat","treasure","boss"]` | **仅**用于证明"节点图能逐槽表达旧版 7 区关卡"；不是运行时数据源 |
| `legacy_areas(g)` | `-> Array`，返回 `[{"area":int,"room":String,"kinds":Array,"exits":Array}]`（按深度升序） | **兼容投影，非运行时 API**。已知局限：`room` 只取该深度**第一个**节点的 kind；`exits` 只取该深度第一个节点的后继 kind |
| `from_route(route, floor_index=1)` | `-> Dictionary` | 由显式房间列表构造**链式**（每层 1 节点）图；`route.size() < 2` → `{}`；仅用于验收/兼容构造 |

另登记其常量语义（供后续轮次对齐，改动须谨慎）：`MIN_DEPTHS=7`、`MAX_DEPTHS=9`、`MIN_NODES=7`、`MAX_NODES=10`、
`MAX_SUCCESSORS=2`、`MIDDLE_KINDS`（10 种非 boss 房）、`NEW_KIND_MIN_DEPTH={curse:3,event:3,forge:3,gamble:4,mirror:5}`、
`ENTRY_KIND="combat"`、`SUPPLY_KINDS=["shop","treasure"]`。
**出口数 = 下一层节点数 ≤ `MAX_SUCCESSORS` = 2**，因此结构上不可能产生 §1 禁止的 3 出口。

### v2-2 / 顶层调度裁决（R2 提案、R5 落地）/ `raid.variants_seen`（**已生效**）

- **批准把 `raid` 的新增键从 12 个扩为 13 个**：`variants_seen`，类型 `Array`（元素为 String），默认 `[]`，
  语义＝本局已出现过的变数 id，用于"同一局内不重复抽到同一条变数"。
- 写入面：`reset()` 建键（`scripts/roguelike.gd:48-50`）；`enter()` 在变数抽取成功后 append（`scripts/roguelike.gd:180-182`）。
- 读取面：`RogueVariants.roll()` 只读（`scripts/rogue_variants.gd:274`），不写。
- 快照影响：**无**。`raid` 整体是快照元素 `data[11]`，键数变化不改变 `data.size()`（`session.gd:1487` 的 12/13 判定不受影响）。
- 契约影响：**§2 的 12 键清单现为 13 键**，其余 12 键的名称/类型/默认值一律不变。

### v2-3 / R8 提案、R6 落地 / 子弹字典表现层键 `bullet_visual`（**部分生效**）

- **批准新增子弹字典字段 `bullet_visual`（float）**，语义＝**纯表现层**放大系数（1.0 = 原尺寸）。
- **硬约束（本条是"用户要求：命中判定不变"的字段级落地）**：
  1. **只有表现层（G 集合）可以读它**；
  2. **严禁**任何判定几何读取或从它派生判定：`session.gd` 里敌人弹的命中半径仍是硬编码默认 `hit_radius = 18.0`
     （契约 §1 与 `scripts/session.gd:3434` 一带），`zone()/contains()/bolt()` 一律不得改；
  3. 它不得被写入 `raid`/`profile`（不做状态真相）。
- 落地现状（**部分生效**，消费端由 W7 独占）：
  - 产出者：`scripts/rogue_combat.gd:107/125-133/238-240/354-355`（魔境小怪与守层者弹）、
    `scripts/boss_choreography.gd:497-498`（编排弹，字段名 `boss_bullet_visual` → 写入 `bullet_visual`）；
  - **尚未产出**：普通远程敌人弹（§ 契约 §6 提到的 `session.gd:3346` 一带）仍不带该字段；
  - 消费端：G 集合（W7）**尚未**按该字段改造绘制 → 目前"数值已备好、画面未变大"。

### v2-4 / R8 / `RogueVariants` 追加纯函数与不变量（**已生效（模块内）**）

- 表规模：**18 条**变数（前 5 条为 R2 冻结条目，id/name/desc/effect 一字未改，仅追加 `kind/weight/min_floor`）。
- 追加纯函数（源码逐字核对）：`ids()`、`canonical_keys()`、`bounds()`、`integer_keys()`、`polarity_map()`、
  `forbidden_keys()`、`polarity_score(id)`、`effect_text(id)`、`describe(id)`、`weight_total(floor, exclude)`、
  `pick(rng, floor, exclude)`、`modifiers_of(ids)`。
- 不变量（均已在 R8 的 `tests/rogue_variants.gd` 中钉死，495/0）：
  1. 抽取**恰好消耗 1 次**随机（当前实现消耗的是 `s.rng`，见 v2-11）；
  2. `modifiers_of()` 先**加法合成**再按 `bounds()` **clamp**；`INTEGER_KEYS=["loot_tier"]` 合成后取整；
  3. **`bullet_size` 合成下限锁 `0.00`**（`bounds()` 实测）——变数**永不**把敌人弹幕缩小；
  4. `FORBIDDEN_KEYS` 守卫（16 个判定几何/歧义键，精确匹配）：变数效果不得出现命中判定几何字段；
  5. `modifiers_of()` 带**记忆化缓存** `static var _mod_cache`（键＝ids 拼接串）：虽返回深拷贝，但它**是有状态实现细节**，
     后续轮次不得依赖"每次调用都重算"。
- 效果键词汇（`LABELS` 的 12 个键，冻结，不许另造）：`enemy_damage`/`enemy_hp`/`enemy_speed`/`player_damage`/
  `player_damage_taken`/`loot_tier`/`shop_price`/`gold`/`xp_gain`/`elite_chance`/`bullet_size`/`bullet_speed`。

### v2-5 / R9 提案 + 顶层调度裁决 / `raid.pending_event` 追加 `"id"`（**已生效**）

- **批准** `raid.pending_event` 由 §2 的 `{"offer":Array,"revision":int}` 扩为
  **`{"offer":Array,"revision":int,"id":String}`**（`"id"`＝被抽中的事件 id，结算必须知道它；向后兼容）。
- 源码依据：`scripts/rogue_events.gd:119`。旧读者若只取 `offer`/`revision` 不受影响。

### v2-6 / R9 提案 + 顶层调度裁决 / 诅咒接入既有减伤池＝**同池相减**（**计划中·未生效**）

- 两种候选取用方式，**裁决取 (a)**：
  - **(a) 同池相减（采用）**：`pool = clampf(RogueBuild.conditional_defense(self,p) - RogueCurses.defense_penalty(p), 0.0, RogueCurses.MAX_POOL)`，
    再 `damage * (1 - pool)`。**不新开第二层乘数**。
  - (b) 直接乘 `RogueCurses.damage_taken_scale(p)`（**不采用**：会与既有减伤池形成乘算，叠出预期外的收益/损失）。
- 等价关系（`scripts/rogue_curses.gd:113-120` 实测）：`defense_penalty(p) = clampf(1 - 1/damage_taken_scale(p), 0.0, MAX_POOL=0.75)`。
  `damage_taken_scale()` 保留为"可读表达"，**不得**作为第二处乘数同时使用。
- 未接线时的临时状态：诅咒可被施加、可随快照同步、可在 HUD 显示，但**不产生任何数值影响**。

### v2-7 / R9 / 登记两个新的 `s.rng` 消耗点（**已落地·待接线**）

- 并入 §6.2 配方：`RogueCurses.roll(s, exclude)`（`rogue_curses.gd:181`）与 `RogueEvents.roll_offer(s)`（`rogue_events.gd:114-121`）
  各**恒定消耗 1 次** `s.rng.randi_range`，触发时机是"进入诅咒房/事件房"这一房间分支内，**不属于** §6.2 第 1 条
  `enter()` 的固定顺序，因此不破坏该顺序。
- 仍适用 §6.2 第 4 条：**禁止重置 `s.rng.seed`**。

### v2-8 / R3 / `profile.apply_data` 语义更新（**已生效；取代 §4.1 中"整段跳过"的描述**）

> **取代声明**：§4.1 第一句"`if parsed is Dictionary and parsed.get("version",0) == 1:` —— **不成立就整段跳过**"描述的是
> **R3 之前的旧行为**；现行为如下，**以本条为准**（§4.1 其余关于 typeof 匹配、float→int 纠正、`attributes` 白名单、
> 服务端不拒未知顶层键的结论仍然有效）。

- 新语义：对**任意 Dictionary** 尽力逐键导入（按 `typeof` 匹配），**唯独不导入 `version`**，函数末尾强制
  `data["version"] = 1`；`save_profile()` 落盘前同样强制 `data["version"] = 1`（`scripts/profile.gd:50,64,144`）。
  即"能读的都读回来，但只认/只写 version 1"——**消除了"version 不符 → 内存回落默认值 → 下次存档静默覆盖老档"的丢档路径**。
- 新增 `sanitize_growth()`（`scripts/profile.gd:122-133`，在 `sanitize_storage()` 与 `save_profile()` 各调一次）：
  `ashes` 非数值/负数 → `0`（**无上限**）；`growth` 非 Dictionary → `{}`，逐项只保留 `int`/`float` 且 **> 0** 的等级、键 `str()` 化；
  **逐节点等级上限不在此处**，由 `RogueGrowth` 负责（见 v2-9 的 `sanitize()`/`level_of()`）。
- `ashes` 已加入 float→int 纠正列表（`scripts/profile.gd:55`），避免存档出现 `17.0`。
- **遗留风险（R1b 记录，未修）**：`server/app.py` 的 `validate_profile` 对 `ashes`/`growth` **不做任何校验**，
  手改客户端可上传离谱 `ashes`（服务端不拒）。是否加服务端校验属 W5 范围，本轮不改。

### v2-9 / R12 / `RogueGrowth` 追加事实（**已落地·待接线**）

- 表规模：**14 个节点**；`tree()` 返回**恰好** 4 键 `{cost,max,requires,effect}`（深拷贝）。
- 花费曲线：`cost_for(id, level) = cost * (level + 1)`（第 1 级付 `cost`、第 2 级付 `2*cost`…）；满级/未知 id → `-1`。
  **全树满级 `total_cost() = 7305`**（R1b 用 `cost * max * (max+1) / 2` 逐节点算术复核，与源码一致）。
- `power(profile_data)` 返回**恰好 4 键**：`enemy_hp`(float)、`enemy_damage`(float)、`start_coins`(int)、`start_rerolls`(int)。
  **成长树永不增强敌人**：`enemy_hp`/`enemy_damage` 是乘性缩放且 clamp 到 `[MIN_ENEMY_SCALE=0.70, 1.0]`。
- `effects()` 的规范键集＝`SCALE_KEYS`(10) + `INT_KEYS`(3) + `FLOAT_KEYS`(1) = **14 键**，按 `BOUNDS` clamp：
  `enemy_hp`/`enemy_damage` ∈ `[-0.30, 0.00]`、`player_damage` ∈ `[0.00, 0.40]`、`player_damage_taken` ∈ `[-0.40, 0.00]`、
  `gold`/`xp_gain`/`chest_drop`/`heal_scale` ∈ `[0.00, 0.40~0.50]`、`shop_price` ∈ `[-0.40, 0.00]`、
  `ash_bonus` ∈ `[0.00, 1.00]`、`move_speed` ∈ `[0.00, 90.0]`、`start_coins` ∈ `[0, 400]`、`start_rerolls` ∈ `[0, 6]`、
  `loot_tier` ∈ `[0, 3]`。
- **新增效果键 `ash_bonus`**（仓库内无既有同义词）：**只影响结算产出**，不影响任何战斗数值。
- 结核算式（纯函数）：`earn_for_run({cleared,floor,won,ash_bonus}) = max(0, round((12*cleared + 30*floor + (150 if won)) * (1 + clamp(ash_bonus,0,1))))`。
- 追加纯函数：`ids/has/label/describe/max_level/cost_for/cost_to_max/total_cost/level_of/can_buy_reason/spent_on/
  total_spent/reset_cost/reset/effects/ash_bonus/earn_for_run/sanitize/forbidden_keys/canonical_keys`。
  `buy()`/`reset()` 是**不可变风格的原地写**（失败路径零变化）；`grant()` **不自带幂等守卫**，
  幂等性由 §9.3 的 `settle()` 唯一出口负责。
- `FORBIDDEN_KEYS`（6 个）：`effects()`/`power()` **永不**产出 `hit_radius`/`collision_radius`/`hurt_radius`/`radius`/`zone`/`hitbox`。

### v2-10 / R10 / `RogueRooms` 模块（**进行中·provisional，待交付记录落盘**）

- **状态说明**：`scripts/rogue_rooms.gd`（396 行）已存在于工作副本，但 **R10 的交付记录 `output/R10-NEW-ROOMS.md` 尚未落盘**，
  且该文件当前仍由 R10 轮次持有。以下签名**以 R1b 当次源码为准，可能再变**。
- `class_name RogueRooms, extends RefCounted`；`KINDS = ["forge","gamble","mirror"]`；
  `MIN_DEPTH = {forge:3, gamble:4, mirror:5}`（与 `RogueGraph.NEW_KIND_MIN_DEPTH` 同源，**改动必须两边同步**）。
- 冻结/自定常量：`FORGE_MAX_LEVEL=5`、`GAMBLE_METHODS=["coin","tier","ash"]`、
  `GAMBLE_ODDS={coin:{win:0.48,multiplier:2.0}, tier:{win:0.40}, ash:{win:0.32,multiplier:3.0}}`、
  `GAMBLE_MAX_STAKE=220`、镜像奖励上限（gold 400 / ash 60 / gear 1）、
  `DELTA_KEYS=["gold","forge_points","forge_level","bind","weapon_tier","ash","gear_reward"]`。
- 主要接口：`kinds()/min_depth()/appears_at()/context_of()/describe()/offers()/resolve(kind,index,ctx,rng=null)`，
  以及 `forge_*`（点价/包裹/直锻/等级上限/报价/结算）、`gamble_*`（stake/odds/return_ratio/expectation/offers/roll/from_roll）、
  `mirror_*`（allowed/offer/accept/resolve/from_roll）。
- 三种赌法期望均 ≤ 100%（`coin` 0.48×2.0=96%、`ash` 0.32×3.0=96%、`tier` 期望 −0.20 档）——**不许出现正期望白嫖口子**。

### v2-11 / 顶层调度 / 待执行：`RogueVariants.roll()` 改用局部 RNG（**计划中·未生效**）

- **背景（R2 的对照实验，已取证）**：当前 `roll()` 消耗一次 `s.rng`，会位移既有随机流；关闭该抽取后
  `rogue_build_progression` 精确回到 `505 checks / 39 failures`，打开则 `533/41`；`rogue_build_growth` 的宝箱样本
  也由 `[213,500]` 移为 `[204,498]`（仍在既有宽区间内，0 failures）。
- **裁决**：把 `RogueVariants.roll()` 改为**局部 RNG**（种子由 `seed_value`/`floor` 纯函数派生，与 `RogueGraph` 同理），
  **语义不变**（仍由房主抽取、结果仍随 `raid.variant` 同步、同种子仍确定）。
- **执行者**：`scripts/rogue_variants.gd` 的文件所有者（R8）；执行后必须在本条补"已生效 + 复跑数字"，并同步更新
  `tests/rogue_variants.gd` 中"恰好消耗 1 次 `s.rng`"的断言（改为"不消耗 `s.rng`"）与 §6.2 的配方描述。
- **风险**：`pick(rng, floor, exclude)` 是**冻结签名**（接收 `RandomNumberGenerator`），改为局部 RNG **不需要**改该签名，
  只需 `roll()` 内部换成自己 new 的 RNG 实例。

### v2-12 / R1b / 文件所有权表的补充与确认（**取代 §8 的 F、G 两行**）

> **取代声明**：§8 表格的 F 行（"新文件"）与 G 行（"弹幕/表现"）以本表为准；§8 原文保留以便追溯，A–E、H 行不变。

| 集合 | 文件（**以工作副本实际存在的文件名为准**） | 所有者 |
| --- | --- | --- |
| **W6 新模块** | `rogue_graph.gd`、`rogue_variants.gd`、`rogue_curses.gd`、`rogue_events.gd`、`rogue_growth.gd`、`rogue_daily.gd`、`rogue_rooms.gd`、**尚未创建**的 `rogue_boss_pool.gd` 与 `rogue_*_ui.gd`；以及各自 `tests/rogue_*.gd` | W6（可并行；**同一文件同一时刻只有一个写者**） |
| **W7 弹幕/表现（冲突面最大）** | `combat_visuals.gd`、`effect_semantics.gd`、`rogue_enemy_vfx.gd`、`boss_effect_staging.gd`、`boss_damage_visual.gd`、`boss_vfx.gd`、`battlefield.gd`、`attack_telegraph.gd`、`resources/boss_damage_shape.gdshader`、`resources/boss_entity_birth.gdshader`、`tests/attack_telegraph_visual.gd` | **W7＝并发的"敌人弹幕视觉"任务独占**；其余轮次（含 R0 验收、R6/R14/R15）**只读**，需要改就回传清单 |
| **W8 文档** | `output/*.md` | 各轮只**追加**自己的文件；不得改写他人已产出的基线数字（只允许追加"更正"小节） |

- 追加纪律：W6 模块之间**不得**互相"顺手重构"（R2 曾误建 `scripts/rogue_variants.gd`，已由顶层仲裁移交 R8，
  该文件最终内容为 R8 所写，R2 声明未覆盖）。
- **W7 的附属产物（R1b 用 `git status` 实测，一并归 W7，避免被误当成"无主文件"）**：
  `resources/boss_projectile_shell.gdshader`（新增）、`tests/attack_telegraph_visual.gd`、
  `tools/preview_enemy_bullets.gd`、`tools/verify_enemy_bolt_readability.gd`、
  `tools/measure_alpha_bbox.py`、`tools/measure_bolt_blobs.py`、`ATTACK-TELEGRAPH.md`。
  另：R2 为修复 class cache 跑过一次 `tools/check_class_cache.ps1 -ProjectPath .`，因此 `project.godot` 与
  大量 `*.import` 出现改动——**那是构建缓存刷新，不是玩法改动**（R18 门禁判定时必须按此口径解释）。

### v2-13 / R1b / 流程纪律（**新增，对所有轮次生效**）

- 任何轮次**只要写过 `scripts/roguelike.gd`（或 `scripts/session.gd`），必须立刻跑**：
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . --check-only --script scripts/roguelike.gd`
  与 `... --check-only --script scripts/session.gd`，确认 stderr 无 `Failed to load script`。
- **理由（本计划真实发生过）**：R5 在飞时 `roguelike.gd:176` 出现
  `var fresh := ... or s.rogue_graph.is_empty()` 的 Variant 类型推断失败（`Parse Error: Cannot infer the type of "fresh"`），
  连带把 `session.gd` 拖成 `Compilation failed`，**所有依赖 TideSession 的 `--script` 用例一起失败**
  （`rogue_wiring`/`rogue_variants`/`rogue_curses`/`rogue_events`/`rogue_build_growth`/`rogue_build_system`/`systems`/`expedition`）。
  修法＝显式标注类型 `var fresh: bool = ...`。R1b 复核：该行**现已修正**（`scripts/roguelike.gd:176` 为 `var fresh: bool = ...`）。
- 推论：**门禁只比 failures、不比 checks**；且"测试全线编译失败"应首先怀疑脚本解析错误，而不是玩法回归。

### v2-14 / R1b / 接线状态总表（2026-10-05 源码复核）

| 模块/字段 | 已落地的消费者（源码实测） | 状态 |
| --- | --- | --- |
| `RogueGraph` | `roguelike.gd:7`（preload）、`:89`（build 写入 `s.rogue_graph`）、`:91,99-114,123,136`（resolve/默认路线）、`:176`（失效判定）、`:716` | **已生效**（节点图已接管推进） |
| `raid.variants_seen` | `roguelike.gd:48-50`（建键）、`:180-182`（append）；`rogue_variants.gd:274`（只读） | **已生效** |
| `s.rogue_graph`（非快照字段） | `session.gd:77`（声明）、`roguelike.gd` 多处 | **已生效**（R2 用包长度 13 + `data[11]` 无该键断言证明不进快照） |
| `profile.ashes` / `profile.growth` | `profile.gd:10`（默认值）、`:55`（int 纠正）、`:122-133`（清洗）、`:144`（强制 version=1） | **已生效**（存档层；**尚无战斗/结算消费**） |
| `RogueVariants` | `roguelike.gd`（`roll` + `variants_seen`）；`rogue_combat.gd:96`（`modifiers_of([variant_id])`） | **部分生效**：敌人侧 `enemy_hp`/`enemy_speed`/弹幕速度已接（W3/R6）；`session.gd` 的 `player_damage`/`player_damage_taken`/`gold`/`shop_price`/`xp_gain`/`elite_chance` 与**普通敌人弹的 `bullet_size`** 未接 |
| `bullet_visual` | `rogue_combat.gd:355`、`boss_choreography.gd:498`（产出）；**无消费端** | **部分生效**（数值已备，G 集合尚未按它绘制） |
| `RogueCurses` | **无任何消费者** | **已落地·待接线** |
| `RogueEvents` | **无任何消费者** | **已落地·待接线** |
| `RogueGrowth` | **无任何消费者** | **已落地·待接线** |
| `RogueDaily` | **无任何消费者** | **已落地·待接线** |
| `RogueRooms` | **无任何消费者** | **进行中**（文件已存在、交付记录未落盘） |
| `profile.daily`（v3-1） | `profile.gd` 中**不存在该键** | **未接线** |
| C3 ① region key 登记 | `rogue_map.gd:53-54`（`SPECIAL_REGIONS` 含 5 个新房间）、`:56-58`（拼成 `f{n}-{x}`） | **已生效** |
| C3 ② 非战斗房谓词 | `roguelike.gd:29`（`SAFE_ROOMS` 含 5 个新房间）、`:188`（configure）、`:222`（房间分支） | **已生效** |

### v2-15 / R1b / 交付记录与源码的不一致清单（逐条列出）

1. **R9 的事件选项数写错**：`output/R9-ROGUE-CURSES-EVENTS.md:13,89` 写"9 个事件房（**22** 个选项）"，
   但其 §5.2 自身明细 `3/3/3/3/2/3/3/3/2` 合计 **25**，且源码 `scripts/rogue_events.gd:20-64` 实测**25 个 option**。
   正确数字＝**9 个事件 / 25 个选项**（R9 的测试只断言 `2 ≤ options ≤ 3`，未钉住总数，故测试仍全绿）。
2. **R10 交付记录缺失**：`scripts/rogue_rooms.gd` 已在工作副本（396 行），但 `output/R10-NEW-ROOMS.md` 不存在；
   该轮仍在飞，签名见 v2-10 并视为 provisional。
3. **class cache 再次陈旧**：`.godot/global_script_class_cache.cfg` 只登记 **4** 个新类
   （`RogueCurses`/`RogueEvents`/`RogueGraph`/`RogueVariants`，R2 重建时的结果）；
   **R2 之后新增的 `RogueDaily`/`RogueGrowth`/`RogueRooms` 未登记** → 按裸类名引用它们会在解析期失败。
   两条出路：再跑一次 `powershell -NoProfile -File tools\check_class_cache.ps1 -ProjectPath .`（会写 `.godot/` 与大量 `*.import`），
   或**统一继续用 `preload("res://scripts/rogue_*.gd")`**（R1b 复核：当前全部消费方都是 `preload`，故暂无实际故障）。
4. **`bullet_visual` 的产出面与 R8 待接线清单不同**：R8 清单指向 `session.gd:3346` 的普通远程敌人弹，
   实际落地在 `rogue_combat.gd:355`（魔境/守层者）与 `boss_choreography.gd:498`；
   **普通敌人弹幕仍无该字段**（R1b 全仓库 grep 复核）。
5. **`RogueVariants.modifiers_of()` 有隐藏状态**：带 `static var _mod_cache` 记忆化（v2-4 第 5 条）；
   交付记录未强调，后续轮次不得假设它无状态。
6. 已核对**一致**的关键数字（无偏差，仅供追溯）：`RogueVariants` 18 条、`RogueCurses` 10 条（CU01–CU10）、
   `RogueGrowth` 14 节点 / `total_cost()=7305`、`RogueDaily` 132/0、`RogueGrowth` 6886/0、
   `RogueGraph` 83608/0、`rogue_wiring` 117/0。

---

## CHANGE-LOG v3（追加；v1/v2 原文一字未改）

- **合并轮次**：R1b；**来源**：R11 的提案原文（`output/R11-DAILY-SEED.md` §7）+ 顶层调度裁决。

### v3-1 / R11 提案 + 顶层调度裁决 / `profile.data` 新增第三个顶层键 `daily`（**计划中·未生效**）

- **批准**新增顶层键 `daily`：类型 `Dictionary`，默认 `{}`；
  键＝`"daily:YYYY-MM-DD"`（由 `RogueDaily.record_key()` 生成，常量 `RECORD_PREFIX = "daily:"`），
  值＝`{"best":int,"plays":int}`（JSON 可序列化）。
- **`version` 仍必须为 1**；**必须**在 `profile.gd` 的 `_init()` 给出同类型默认值 `{}`，否则会被 `apply_data` 的 `typeof` 匹配静默丢弃。
- 服务端 `server/app.py` 不校验未知顶层键（R1 复核、R3 实测 8/8 PASS）→ **无需改服务端**。
- 现状（R1b 复核）：`scripts/profile.gd` **尚无** `daily` 键 → 待 W1 接线。
- 长期事项（R11 建议，未做）：记录随游玩天数增长，未来需裁剪（如只保留最近 400 天，`MAX_LOOKBACK=400` 已备好）。

### v3-2 / 顶层调度裁决 / 每日挑战日期口径＝**统一 UTC + 房主下发**（**新增冻结**）

- **挑战种子与打卡记录统一用 UTC**：`RogueDaily.global_daily_seed()`（`= seed_for(utc_today())`）与
  `RogueDaily.utc_today()` + `record_key()` 必须成对使用，避免"挑战日 ≠ 打卡日"。
- `today()` / `host_daily_seed()`（本地口径，§5 冻结签名）**保留但不得用于每日挑战的种子与记录键**。
- **必须由房主算好、随 `begin` RPC 下发**（§1：`seed_value` 必须全队一致）；
  **禁止**各客户端按本地日期/本地时区自行计算（跨零点与时区会错位）。
- 种子域 `[1, 2147483647]`（`MAX_SEED = 0x7FFFFFFF`）；**`0` 表示"随机局"** →
  UI 输入框必须做**非零校验**，否则 `parse_seed` 非法输入返回 0 会**静默变成随机局**。
- 顺带冻结（R11 实现细节）：`encode()` 对 `seed <= 0` 或 `> MAX_SEED` 返回 `""`（不可分享）。

### v3-3 / 顶层调度裁决 / 每日记录只写一次

- 每日记录**只能**在 `settle()`（§9.3 唯一结算点、`if s.raid.ended: return` 守卫）写一次；
  与灰烬（`RogueGrowth.grant()`）、成长树解锁共用一个出口，**不得**在别的路径重复写入。
- 写入形式：`profile.data["daily"] = RogueDaily.apply_result(profile.data.get("daily", {}), RogueDaily.utc_today(), score)`；
  `score` 口径由后续轮次（R13/R16）定义。

### v3-4 / 冻结规格 / 种子分享串格式（**发布后不可更改**）

以源码 `scripts/rogue_daily.gd` 为准（**注意：与"`CT-XXXX-XXXX`"的早期口头描述不同**）：

- 形式：`PREFIX + "%08X" % seed + "-" + 校验字符`，即 **`CT-` + 8 位十六进制（大写）+ `-` + 1 个校验字符**，
  例：`CT-0000ABCD-x`（`HEX_DIGITS = 8`、`CHECK_SALT = 7`，校验字符取自 `ALPHABET`）。
- 解析容错：大小写、首尾与中间空白、`#` 前缀十进制、直接粘贴十进制种子；非法/截断/篡改校验位 → `parse_seed()` 返回 `0`、`is_valid()` 为 `false`，**不崩不抛**。
- 日期串合法性域：`MIN_YEAR=1970`、`MAX_YEAR=9999`；`normalize_date()`/`is_date_string()` 负责校验。

### v3-5 / R1b / 待执行清单（v2+v3 汇总，供后续轮次认领）

| 待执行项 | 目标文件（所有者） | 认领轮次 | 参考条目 |
| --- | --- | --- | --- |
| 变数数值钩子接入 `incoming_damage()`/`damage_enemy()` | `scripts/session.gd`（W1） | W1 钩子接线轮 | v2-4、v2-14 |
| 诅咒同池相减公式落地 | `scripts/session.gd`（W1） | W1 钩子接线轮 | v2-6 |
| 事件房动作 `rogue_event` + `revision` 校验 | `scripts/roguelike.gd`（W1） | W1 钩子接线轮 | v2-5、§9.2 |
| 诅咒房/事件房/新房间入池与 `clear_room` 分流 | `scripts/roguelike.gd`（W1） | W1 钩子接线轮 | §7.3、v2-10 |
| `RogueGrowth.grant()` 接入 `settle()`（只一次） | `scripts/roguelike.gd`（W1） | R13 成长树闭环 | v2-9、§9.3 |
| `profile.data["daily"]` 建键 + 结算写入 | `scripts/profile.gd`/`roguelike.gd`（W1） | W1 / R13 | v3-1、v3-3 |
| 每日种子由房主随 `begin` 下发 + `raid.daily`/`seed_shared` | `scripts/session.gd`（W1） | W1 钩子接线轮 | v3-2 |
| `RogueVariants.roll()` 改用局部 RNG | `scripts/rogue_variants.gd`（**R8**） | 顶层调度指派 | v2-11 |
| 表现层按 `bullet_visual` 放大**绘制**（判定不动） | G 集合（**W7**） | 弹幕视觉任务 / 其后续 | v2-3 |
| 普通远程敌人弹写入 `bullet_visual` | `scripts/session.gd`（W1） | W1 钩子接线轮 | v2-15 第 4 条 |
| `RogueBossPool` + Boss 池扩容 + `sound.gd` | `scripts/rogue_combat.gd` 等（W3/W6） | R14/R15 | §9.5 |
| class cache 重建（或继续统一 `preload`） | `.godot/` | R18 门禁轮 | v2-15 第 3 条 |
| 恢复肉鸽构建美术（253 图标/manifest）→ `rogue_build_rules`/`pack` 转绿 | 素材（W5） | R18 前 | C5、`TEST-BASELINE.md` |
| 每日记录裁剪（保留最近 N 天） | `scripts/rogue_daily.gd` / `profile.gd` | R16 之后 | v3-1 末条 |
