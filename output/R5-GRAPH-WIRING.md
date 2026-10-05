# R5 · 节点图接线 + 旧口径移植（交付记录）

- **轮次**：R5（`output/ROGUE-EXPANSION-EXECUTION-PLAN.md` §3.2 R5；「最小可用里程碑 R1→R2→R4→R5」的收口轮）
- **契约**：`output/ROGUE-CONTRACTS.md`（C1/C2/C3、§2/§3、§6.2、§7、§8、§9）+ **CHANGE-LOG v2**：
  新增第 13 个 `s.raid` 键 `variants_seen`（Array，默认 `[]`，由本轮落地）
- **基线**：`output/TEST-BASELINE.md` §1；R4 交付 `output/R4-ROGUE-GRAPH.md`；R2 交付 `output/R2-WIRING.md`
- **状态**：交付完成。`rogue_build_progression` **505/39 → 818/0**（目标达成）、`roguelike_seven_rooms` 1856/0 → 11832/0、
  `roguelike_routes` 5219/5 → 5220/2（仅剩既存几何红）、`rogue_wiring` 117/2 → 123/0。
- **注意（写者交棒）**：本记录描述的是**本轮交付时刻**的版本。之后 W1b 轮已开始写 `scripts/roguelike.gd`
  （`git diff --stat` 从本轮交付的 200 行涨到 464 行）与 `scripts/session.gd`（6 行 → 63 行），
  因此下文行号是**本轮交付时的锚点**，与当前工作区可能已漂移（漂移对照见 §9.1）。

---

## 0. 一句话

固定 7 槽 `route` 被 `RogueGraph.build(seed_value, floor)` 取代：每层 7~9 行、每行 1~2 个节点、守卫是最深且唯一死路；
`raid.node` / `raid.depth` / `raid.graph_floor` 成为权威推进状态，整张图放在**非快照**字段 `s.rogue_graph`；
5 个新房间在两处登记且走"非战斗房"分支；`variants_seen` 作为第 13 个 raid 键落地。

---

## 1. 改动文件与精确行号（本轮交付时刻）

| 文件 | 行 | 改动 |
| --- | --- | --- |
| `scripts/roguelike.gd` | 3-7 | 新增 `const NodeGraph = preload("res://scripts/rogue_graph.gd")`（preload，不依赖 class cache） |
| | 13-31 | `ROOM_NAMES` 扩到 11 种房间；新增 `ROOM_DESCS`；新增 `const SAFE_ROOMS := ["shop","treasure","talent","curse","event","forge","gamble","mirror"]` |
| | 36 | `reset()` 的 raid 字面量新增第 13 键 `"variants_seen":[]` |
| | 108-160 | `new_floor()` 改为建图（`NodeGraph.build` → `dress_floor` → `node=entry` → `fill_floor_route`） |
| | 118-160 | 新增 `dress_floor()`：把"保底补给行 / 保底圣坛行"钉在**单节点行**上（只改 `kind`，不动深度/边/守卫） |
| | 162-176 | 新增 `fill_floor_route()`：`route` 变成"每层房型模板"（index = depth-1），保留调用方已写入的条目作为显式覆盖 |
| | 178-183 | 新增 `depth_count(s) -> int`；`node_at_depth(graph, depth) -> String` |
| | 185-201 | 新增 `resolve_node(s)`（含"按 `raid.area` 向前跳行"的兼容路径）、`room_for(s, info)` |
| | 203-253 | `enter()`：`fresh` 判定 → 建图/抽变数 → 解析节点 → `depth/area` 由节点派生 → `configure(..., room not in SAFE_ROOMS, room)` → 非战斗房统一 `clear_room()` |
| | 205-211 | 唯一新增 `s.rng` 消耗点仍在此：`if fresh:` → `Variants.roll(s)` → `variants_seen.append`（在 `exit_choices()` 之前） |
| | 686-700 | `choose()`：`rogue_next` 把门的 `node` 写进 `raid.node`、把房型写进 `route[area]`（有界检查按 `route.size()`） |
| | 702-720 | `exit_choices()`：由图的**后继**决定门；无后继 → 下一层/凯旋；唯一后继为守卫 → 守层者 / 守层者·挑战 两扇门（保留挑战门语义） |
| | 753-766 | `advance()`：按 `raid.depth >= depth_count(s)` 判层末；真实换层才清空 `route`，门决定的房型写回第 1 行 |
| `scripts/rogue_map.gd` | 50-55 | 新增 `const SPECIAL_REGIONS`（`curse→treasure`、`event→talent`、`forge→shop`、`gamble→treasure`、`mirror→talent`），使用点 `:57-58`（C3 ①） |
| `scripts/session.gd` | 1501 | 客户端 `ruins.configure(...)` 的"非战斗房"谓词补齐 5 个新房间名（与 C3 ② 同表；**唯一一处 session.gd 改动**） |
| `scripts/rogue_build.gd` | 855-863 | `Build.award()` 的"核心"发放从"第 2 层第 2 区"改为"第 2 层首座圣坛"（`p.build_core_granted` 守卫，见 §8） |
| `tests/rogue_build_progression.gd` | 见 §3.1 | 6 组陈旧断言移植 + 核心口径 + 门序号 + guard 150→400 |
| `tests/roguelike_seven_rooms.gd` | 见 §3.2 | 槽模板断言 → 图结构断言 + 全行驱动 |
| `tests/roguelike_routes.gd` | 见 §3.3 | 门数/导航/换层断言重写；`:88`×2 既存几何红**未动** |
| `tests/rogue_wiring.gd` | 见 §3.4 | 2 条"R5 之前 node 未接线"的过期断言按新语义改写（未删更强断言） |
| `tests/roguelike_exit_alignment.gd` | 见 §3.5 | 额外移植（原依赖"第 2 区必为圣坛"） |
| `tests/roguelike.gd` | 见 §3.6 | 额外移植（`cleared==25` / `coins==550` 两处硬编码数值） |

**没有新建 `scenes/*.tscn`、没有新增 autoload、没有改 `rogue_build_content.json`、没有改任何既有 `.md`。**

---

## 2. 接线设计（为什么这样最不容易踩）

1. **图不进快照（C1）**：`s.rogue_graph` 是 session 顶层非白名单字段；`raid` 只带 `node`/`depth`/`graph_floor`。
   客户端照旧用 `snapshot` 里的 `floor/area/room` 重建地图（`session.gd:1495-1501`），**不需要图也不需要图 RNG**。
2. **图不碰 `s.rng`（C2）**：`NodeGraph.build()` 用局部 `RandomNumberGenerator`（`rogue_graph.gd:82-83`）。
3. **变数抽取仍是唯一新增消耗点**：`fresh` 为真（换层/首层）时 `Variants.roll(s)` 一次，位置仍在
   `exit_choices()` 之前；`s.rng.seed` 没有任何新写入点。
4. **推进不变量**：每层恰 1 个 `boss`、`boss.depth == depth_count`、`boss.next` 为空；
   非守卫节点后继 ∈[1,2]（`ground-manifest.json` 每个 region key 只有 2 个出口 + `exit_position` 只支持 0/1 ⇒ **没有第 3 扇门**）。
5. **`raid.area` 语义保持**：`area == depth`（1-based 行号），所以 `main.gd` / `rogue_field.gd` / `Build.award` 的
   `raid.area` 读取不用改；旧调用方若**直接写 `raid.area` 向前跳行**（测试、调试视图），`resolve_node()` 会取该行的第一个节点（兼容路径，见 §3.5/§3.6）。
6. **`route` 语义**：从"7 槽模板"变成"每层房型模板（index=depth-1）"；`enter()` 每行都会写回实际房型，
   调用方预先写入的合法房型视为**显式覆盖**（`rogue_build_pack.gd:37` / `rogue_build_visual.gd:34` / `roguelike_paths_visual.gd:29` / `roguelike_spawn_spacing.gd:25` 因此不需要改）。

---

## 3. 断言移植逐条留痕（**本轮最关键交付物**）

### 3.1 `tests/rogue_build_progression.gd`（505/39 → **818/0**）

| # | 原文（行号 + 文案，基线次数） | 新断言 | 理由 |
| --- | --- | --- | --- |
| 1 | `:33` `exits.size()==1 and exits[0].room=="talent"` — "Every possible route must enter the first sanctuary"（10 次） | 每层首行对 `s.rogue_graph` 断言：节点数 ∈[7,10]、有 `boss`、有 `shop|treasure`、有 `combat|elite`、有 `talent`、入口门数 ∈[1,2] | 旧断言描述"每层 5 区 + 首区必为圣坛"的槽模板；节点图入口恒为 `combat`（`rogue_graph.gd:27`），真实不变量是"每层必有守卫/补给/战斗/圣坛" |
| 2 | `:35` `exits.all(room in ["combat","elite"])` — "Two combat areas remain guaranteed"（10 次） | 合并进上条 `kinds.has("combat") or kinds.has("elite")` | 战斗行不再集中在前两行，但"每层至少 1 个战斗节点"仍成立（入口保证） |
| 3 | `:37` `exits[0] in ["shop","treasure"] and exits[1]=="talent"` — "Fourth area offers supplies or a second sanctuary"（8 次） | `kinds.has("shop") or kinds.has("treasure")` + 逐扇门 `door.room == Graph.node(graph,door.node).kind` | R4 生成器只保底"每层 ≥1 补给节点"，不再保证第 4 行；门的房型必须与图一致 |
| 4 | `:100` `rooms==25 and cleared==25`（2 次） | `rooms==expected_rooms and cleared==expected_rooms`，`expected_rooms = Σ depth_count(每层)`（≥35） | 每层由固定 7 区变为 7~9 行 |
| 5 | `:101` `sanctuary_counts[floor]==(2 if even else 1)`（7 次） | `seen_sanctuaries ∈ [1,2]`（按**走过**的圣坛计） | 圣坛数由图 roll 决定（生成器上限 2 + `dress_floor` 保底 1 个在单节点行），不再是奇偶模板 |
| 6 | `:102` `talent_choices==14*count and core_choices==count`（2 次） | `talent_choices==2*visited_sanctuaries*count and core_choices==count` | 14 = 2×7 座圣坛的模板常数；新口径用"实际走过的圣坛 × 每人 2 选 × 人数"表达同一会计不变量 |
| 7 | `:50` `personal_cores==(1 if floor_index==2 and s.raid.area==2 else 0)` | `==(1 if floor_index==2 and sanctuary_counts[floor]==1 else 0)` | 核心不再绑定"第 2 层第 2 区"，改为"第 2 层首座圣坛"（配合 `rogue_build.gd` 的 `build_core_granted`，见 §8） |
| 8 | `:97` `exit_index := 1 if area==3 and floor%2==0 else 0` | `mini(1, s.raid.exits.size()-1)`；`guard 150 → 400` | 单门行的门序号 1 会越界 → 请求被丢弃 → 流程空转打满 guard（本轮第一次跑就复现成 420s 超时） |

### 3.2 `tests/roguelike_seven_rooms.gd`（1856/0 → **11832/0**）

| # | 原文 | 新断言 | 理由 |
| --- | --- | --- | --- |
| 1 | `:26-31` 100 种子 × 5 区调用 `exit_choices` 断"两个不同随机目的地"，`seen.size()==5` | 200 种子 × 5 层直接对 `Graph.build()` 断言：节点数 ∈[7,10]；非守卫节点后继 ∈[1,2]；守卫唯一死路且无后继；累计房间种类 **==11** | 门不再由 `random_destinations` 产生，而是图的边；房间种类由 5 → 10（+boss） |
| 2 | `:37` `route.size()==7` — "Seven slots per floor" | `depth_total ∈[7,9]` 且每层走完全部行 | 行数来自图深度 |
| 3 | `:42` `room=="boss" if area==7 else room!="boss"` — "Boss is seventh" | `(s.raid.room=="boss")==(depth==depth_total)` | 守卫在"该层最深节点" |
| 4 | `:43` `exits.size()==(1 if f==4 and area==7 else 2)` | `exits.size() ∈[1,2]` | 门数 = 当前节点后继数；**未引入第 3 扇门** |
| 5 | `:38` 固定 `for area in range(1,8)` | 按 `depth_total` 驱动（`s.raid.floor==f+1 and s.raid.area==depth` 保留） | 行数可变 |

### 3.3 `tests/roguelike_routes.gd`（5219/5 → **5220/2**）

| # | 原文 | 新断言 | 理由 |
| --- | --- | --- | --- |
| 1 | `:15` `exits.size()==2` — "Two destinations are prepared" | `doors ∈[1,2]`；"另一扇门"的两条断言改在 `doors==2` 时执行 | 单门行合法 |
| 2 | `:33` `s.raid.area=4`（旧 5 区时代的"守卫前一区"） | `s.raid.area=depth_total-1` + `enter()`，并断言守卫门**恒为 2 扇** | 守卫前一行的唯一后继就是守卫；兼容路径负责跳行 |
| 3 | `:54` `floor==2 and area==1 and room=="shop"` | 先断"换层落到下一层第 1 行"，再显式把第 1 行入口房型置为 `shop` 后 `enter()` 验证商店路线 | 换层的门只决定**入口房型**，入口房型是随机门（不再保证 shop）；拆两步保留覆盖 |
| 4 | `:40`/`:48`（挑战门 + 守卫 +25% 生命） | **未改**，随新导航自然转绿 | 语义等价 |
| 5 | `:88`×2 `Player can walk continuously along each branch in long and compact rooms` | **未改，保持红** | 既存几何红：R1 基线同断言同行号同次数（§5.2），且 `:71-88` 只 `map.configure(0,2,long_room)`（room 为空 → 走未改的旧分支），不经 session/节点图。按计划 §4.1「`:88` 数字变化即说明误动 ground profile」——**数字未变即未误动** |

### 3.4 `tests/rogue_wiring.gd`（R2 交付物；117/2 → **123/0**）

| # | 原文 | 新断言 | 理由 |
| --- | --- | --- | --- |
| 1 | `:57` `str(s.raid["node"])==""` — "node stays unwired until R5" | `node!=""` **且** `node == s.rogue_graph.entry` | 该断言自述"直到 R5 之前"，R5 正是接线轮；新断言更强（锚到权威图） |
| 2 | `:124` `str(decoded_raid.get("node",""))==""` — "Only node/depth ride inside raid" | `typeof(node)==TYPE_STRING and node!=""` **+** `decoded_raid.has("variants_seen")` | 真正意图是"raid 里只允许标量、绝不允许整张图"；原有更强的三条（`size==13`、无 `graph`、无 `rogue_graph`、客户端 `rogue_graph` 保持空）**一条未删**，此处只把"node 必须为空"换成"node 必须是 String" |
| 3 | `RAID_KEYS` 常量 | 追加 `"variants_seen":TYPE_ARRAY` | CHANGE-LOG v2 新增键纳入覆盖 |

### 3.5 `tests/roguelike_exit_alignment.gd`（**未指派，额外移植**；706/0）

| 原文 | 新断言 | 理由 |
| --- | --- | --- |
| `:39-48` `area=2` → `enter()` → 断言"圣坛奖励开出口 / 2 扇门 / 按 E 走对角门 → area==3" | 按图定位：① 找到 `kind=="talent"` 的单节点行做圣坛流程（断言 `phase=="rogue_exit"`）；② 跳到 `depth_total-1` 行（守卫门）断言 2 扇门 + 按 E 进入 `depth_total` 行且 `room==exits[1].room` | `area=2` 不再必为圣坛；`exits.size()==2` 只在守卫门恒成立 |

### 3.6 `tests/roguelike.gd`（**未指派，额外移植**；见 §7 已知问题）

| 原文 | 新断言 | 理由 |
| --- | --- | --- |
| `:64` `cleared==25` | `expected_cleared>=35 and cleared==expected_cleared`（每层首行累加 `depth_count`） | 总房数 25 → 35~45 |
| `:65`/`:68` `results[1].coins==550` | `== expected_cleared*12+250` | 结算公式本身随 `cleared` 变化 |

### 3.7 未改动的断言（保持通过）

`rogue_build_growth`(4066/0)、`rogue_build_system`(440/0)、`systems`(10812/0)、`expedition`(79/0)、
`roguelike_spawn_spacing`(6166/0)、`rogue_graph`(R4 自己的 83608/0) 全部原样通过。

---

## 4. 回归原始结果（`--headless --path . --script tests/<n>.gd`，日志 `build/r5/`、`build/r5b/`）

| 测试 | R1 基线 | R5 实测 | 判定 |
| --- | --- | --- | --- |
| `rogue_build_progression` | 505 / **39** | **818 / 0** | ✅ 目标达成（39 → 0） |
| `roguelike_seven_rooms` | 1856 / 0 | **11832 / 0** | ✅（check 数上升是新增图结构采样） |
| `roguelike_routes` | 5219 / **5** | **5220 / 2** | ✅ 3 条陈旧红转绿，剩 2 条既存几何红（§3.3 #5） |
| `rogue_wiring` | 117 / 2（R2 交付后） | **123 / 0** | ✅ |
| `rogue_build_growth` | 4066 / 0 | **4066 / 0**（样本 `[213,500]`） | ✅（样本漂移见 §6） |
| `rogue_build_system` | 440 / 0 | **440 / 0** | ✅ |
| `systems` | 10812 / 0 | **10812 / 0** | ✅ |
| `expedition` | 79 / 0 | **79 / 0** | ✅ |
| `roguelike_exit_alignment` | 未登记 | **706 / 0** | ✅ 额外移植后绿 |
| `roguelike_spawn_spacing` | 未登记 | **6166 / 0** | ✅ |
| `roguelike_bosses` | 未登记 | 门禁轮独立复跑 **443 / 0** | ✅（该文件并发被 R6 修改过） |
| `roguelike`（`tests/roguelike.gd`） | 未登记 | **TIMEOUT + 3 failures** | ⚠ 非本轮引入，见 §7 |
| 豁免项 | `rogue_build_rules`（挂死）、`rogue_build_pack`（资产红）、两个 network 单跑噪声 | 未跑 | 按基线 §5 |

---

## 5. 编译自洽证据（原始 `--check-only`）

```
> & Godot_v4.7.2-stable_win64_console.exe --headless --path . --check-only --script scripts/roguelike.gd
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
exit=0
> ... --check-only --script scripts/session.gd
exit=0
> ... --check-only --script scripts/rogue_map.gd
exit=0
> ... --check-only --script scripts/rogue_build.gd
exit=0
> ... --check-only --script tests/rogue_wiring.gd / tests/roguelike_seven_rooms.gd /
      tests/roguelike_routes.gd / tests/rogue_build_progression.gd
ok / ok / ok / ok        （四条测试脚本均无 ERROR）
```

此外整轮期间**每次改完 `roguelike.gd` 都复跑 `--check-only`**（含 20:0x 修复 `var fresh :=` 类型推断那次），
交付时刻 `scripts/roguelike.gd` 与 `scripts/session.gd` 均为 exit=0 且自洽。

---

## 6. RNG 取证（回答"变数抽取是否还在扰动 `s.rng`"）

**结论：仍消耗 `s.rng`，每层恰好 1 次；我**没有**改 `scripts/rogue_variants.gd`（该文件属 R8）。**

- 调用点 `scripts/roguelike.gd:205-211`：`fresh`（换层/首层）→ `Variants.roll(s)` → `variants_seen.append`，仍在 `exit_choices()` 之前。
- `scripts/rogue_variants.gd:269 static func roll(s)` → `:275 pick(s.rng,floor,seen)`；`:244 static func pick(rng,…)` → `:245 var roll_value := rng.randf()`（首句、无条件）⇒ **恰好 1 次 `s.rng.randf()`**。
- **实测**（探针 `build/r5/rng_probe.gd`，用"全新 RNG 从 `seed=value+71` 逐次比对原始 `state`"计数 `launch(false,813)` 的消耗）：
  - 正常代码：`draws_consumed_by_launch=1178`，`variant=surge serial=1`
  - 把 `:209` 临时换成 `pass`：`draws_consumed_by_launch=1177`，`serial=0`
  ⇒ 变数抽取**确实多消耗 1 次**；这条 `pass` 仅存在约 2 分钟用于取数并已还原（`git diff` 现为 `+ Variants.roll(s)`）。
- 因此 `rogue_build_growth` 样本回到 `[213,500]`（R1 基线值）**无法由本轮 diff 解释**：本轮没有减少任何一次消耗。
  测量窗口内 `main.gd`/`rogue_combat.gd`/`boss_choreography.gd`/`sound.gd`/`profile.gd` 等被并发轮次修改
  （其中 `rogue_combat.gd`/`sound.gd` 正在 `spawn_enemy`/`setup_minion`/`cue` 链路上），归因需要 bisect。
  若要把"既有序列零扰动"做成硬保证，契约 §6.2 的另一条路是让 `roll()` 改用局部 RNG —— 那属于 R8 的文件，本轮未动。
  （门禁轮已按"已记录偏差"入账，不再要求本轮处理。）

---

## 7. 已知问题（不是本轮引入，交棒后需处理）

1. **`tests/roguelike.gd` TIMEOUT + 3 failures**（日志 `build/r5b/roguelike.err.txt`）：
   - `:21 "Starting purchases applied"`：探针 `build/r5/starter_probe.gd` 实测
     `solo({"rogue_rerolls":2,"rogue_weapon":1})` 后 `rerolls=3`、`weapon=600`（既不是 2 也不是 1）
     ⇒ **开局武器/重掷的配置项被别的轮次的接线覆盖**（成长树/开局经济方向），与本轮改动无关（本轮未碰该路径）。
   - `:65 "Unexpected phase"` + `:66` + `:67` `Out of bounds get index '1'`：循环首轮 `raid.phase=="rogue_prepare"`
     （`reset()` 末尾固定置位，早于本轮就存在）不被该测试的分支覆盖 → `break` → 运行未结算 → `s.results[1]` 不存在 → 脚本报错中断 → 进程挂死（TIMEOUT）。
   - 本轮对该文件的移植（`:64-68`）已在位，但**因上述两条先决问题无法验绿**，建议在 W1b/成长树接线稳定后由门禁轮复跑并补 `rogue_prepare` 分支。
2. **`tests/roguelike_bosses.gd` 在本轮批次里曾 420~600s 超时**：该文件当时正被 R6 并发修改（`git status` 可见 `M tests/roguelike_bosses.gd`）；
   门禁轮后来独立复跑得到 **443/0**，因此以门禁轮数字为准，本条只作并发写者记录。
3. **并发写者对测量窗口的污染**：本轮多次测量期间 `scripts/roguelike.gd` 与 `scripts/session.gd` 被 R2/R8/R9/R10/R12/W1b 反复写入，
   因此 §4 的每个数字都建议以"门禁轮独立复跑"为准（已复现：818/0、11832/0、123/0、5220/2、443/0）。

---

## 8. 越权 / 额外改动声明

| 文件 | 是否本轮所有权内 | 说明 |
| --- | --- | --- |
| `scripts/roguelike.gd`、`scripts/rogue_map.gd` | ✅ W1/W4 | 派单指定 |
| `tests/rogue_build_progression.gd`、`tests/roguelike_seven_rooms.gd` | ✅ 派单指定 | — |
| `tests/roguelike_routes.gd` | ✅ 计划 R5 行已列为 R5 范围 | 3 条陈旧红转绿 |
| `tests/rogue_wiring.gd`（R2 交付物） | ⚠ 额外 | 只改 2 条"R5 之前 node 未接线"的过期断言 + 补 `variants_seen` 键，**未重构其它部分** |
| `tests/roguelike_exit_alignment.gd`、`tests/roguelike.gd` | ⚠ 额外 | 两者都被"行数/房型不再固定"打破；按新口径最小移植，否则纳入新增失败 |
| `scripts/session.gd` | ⚠ 1 行 | 客户端"非战斗房"谓词必须与服务端同表（C3 ② 的客户端副本），否则联机两端地图代型不一致；**仅此 1 行** |
| `scripts/rogue_build.gd` | ⚠ 1 处 | `Build.award()` 的"核心"发放绑定 `floor==2 and area==2`，节点图下第 2 区不再保证是圣坛 ⇒ 核心可能整局不发。改为"第 2 层首座圣坛"（`p.build_core_granted` 守卫）。**该文件在契约 §8 里没有所有者，属权属空白**，请 W1b 复核 |
| `scripts/rogue_variants.gd` | ❌ 未写入 | 全程未修改（§6 已证） |

---

## 9. 给 W1b 的待接线清单

### 9.1 本轮落地、W1b 必须知道的锚点（含当前漂移后的行号）

| 锚点 | 本轮交付时 | 当前工作区（W1b 已改写） |
| --- | --- | --- |
| `const SAFE_ROOMS` | `roguelike.gd:29`（当前 36） | 内容未变，仍是 8 个非战斗房名 |
| `variants_seen`（raid 字面量） | `roguelike.gd:48-50`（当前 99-100） | 仍是第 13 键 |
| **唯一新增 `s.rng` 消耗点** | `roguelike.gd:205-211`（当前 266-270） | `if fresh:` → `Variants.roll(s)` → append；**必须保持在 `exit_choices()` 之前、每层恰好 1 次、不得重置 `s.rng.seed`** |
| `depth_count(s)` | `roguelike.gd:178`（当前 210） | 行数 = 守卫深度，7~9 |
| `resolve_node()` 的"按 `raid.area` 跳行"兼容路径 | `roguelike.gd:185-201`（当前 223-238） | 生产流不会命中；测试/调试视图依赖它 |
| `room_for()` 的 `route` 覆盖语义 | `roguelike.gd:203`（当前 240） | `route[depth-1]` 的合法房型 = 显式覆盖 |
| `dress_floor()` 保底行 | `roguelike.gd:118-160`（当前 158-195） | 补给/圣坛保底只落在**单节点行** |
| `exit_choices()` 的门 | `roguelike.gd:702-720` | 门 = 图后继；守卫门 2 扇（含 challenge）；**禁止第 3 扇门** |
| `advance()` 换层 | `roguelike.gd:753-766` | 换层清 `route`；门决定入口房型 |

### 9.2 需要别的所有者落的接线（本轮只读，未改）

1. **`main.gd`（W2 / R7）**：`main.gd:1559` HUD "第 %d / %d 区" 仍取 `AREAS_PER_FLOOR`（=7），
   而每层实际 7~9 行 → 请改为按 `raid.depth / depth_count(s)` 显示（或显示"节点"）；`AREAS_PER_FLOOR` 本轮**故意保留未删**，仅用于该 HUD 文案与向后兼容。
2. **新房间的真实玩法（R9/R10 → W1b）**：`curse/event/forge/gamble/mirror` 目前由 `enter()` 统一走 `clear_room()`
   （进房即给一个宝箱、不刷怪）。契约 §7.3 要求"复用 `clear_room()` + `raid.pending_*`，**不要新增 phase 名**"
   （`main.gd:1561`、`tests/*`、`progression:57/85/87` 都在做 phase 字符串匹配）。
   请把 `raid.pending_event/pending_forge/pending_gamble/mirror_state` 的写入点放在 `clear_room()` 或其调用链里。
3. **变数/诅咒经济钩子（W1b）**：`Variants.active(s)` 已可用；`raid.variants_seen` 已由本轮维护（只追加）。
   诅咒的 `RogueCurses.damage_taken_scale(p)` 需要接到 `session.incoming_damage` **既有的减伤池**（契约 §2/§9.3），不要新开乘数。
4. **换层门的语义变化**：门的 `room` 现在只决定"下一层入口行的房型"（入口节点默认 `combat`，由 `advance()` 覆写）；
   若 W1b 要把"下一层"也做成图，请改 `advance()` 而不要再引入 `route[0]=` 之外的写法。

---

## 10. 风险与建议（本轮实测发现，需要上层决策）

1. **玩家选择性下降（最重要）**：`RogueGraph.build()` 每层只在**一个**深度放 2 个节点（且 50% 概率），
   其余行都是单节点 ⇒ 一层里玩家**平均只有 0.5 次真正的二选一**，其余行是"走到门口按 E 进唯一那间房"；
   旧模板是"每行都在 2 个随机目的地里选"。这是 R4 生成器的结构决定的，R5 忠实接线后暴露出来。
   **建议**：另开一轮（R4b，`scripts/rogue_graph.gd`，W6）让 2 节点层变多（例如深度 5~7 层里放 2~4 个双节点行，
   总数仍 ≤10、每节点出口仍 ≤2），或把 `MIN/MAX_DEPTHS` 下调到 5~7 换取更多分叉；这属于生成器，不在 R5 权属内。
2. **`dress_floor()` 是 R5 在 `roguelike.gd` 里做的"楼层补装"**（保底补给行 + 保底圣坛行）：
   它只改 `kind`，保证"走在主路上的队伍一定遇到补给与圣坛"（旧模板的 area 2 圣坛语义），
   并且把生成器上限 2 座圣坛的约束保持住。**但它让 `s.rogue_graph` 的 kind 与 `NodeGraph.build()` 的原值不同**，
   若有别处（如 R4 的签名比对）拿 `build()` 重算，需知悉这一事实。建议后续把这段逻辑上移进 `RogueGraph`（R4b）。
3. **`tests/roguelike_routes.gd:88` 的 2 条几何红**长期存在（长房左右分叉的连续可行走性），
   R1 基线即红；本轮未动。若上层希望彻底转绿，需单开地图几何轮。
