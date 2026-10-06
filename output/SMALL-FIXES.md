# SMALL-FIXES（父会话派单 A/B/C + 追加登记）

工作树：`D:\game\CrimsonTide-godot`，HEAD `7bbaf04`，引擎 `Godot_v4.7.2-stable_win64_console.exe`（不在 PATH；本机无 `pwsh`）。
测量时点：2026-10-06 13:13（门禁日志 `build/gate-20261006-131311`）。
**注意**：门禁开跑时报 `[warn] 9 source file(s) changed in the last 5 min`（`scripts/rogue_combat.gd`、`scripts/rogue_field.gd`、`resources/rogue_build_content.json`、`tests/rogue_boss_bodies.gd`、`tests/rogue_boss_pool.gd` 等属**并发轮次**在写，不是本次改动），所以下表数字属"写者仍在飞"的时点值；判定只比 failures，本次 32 PASS / 0 judged-FAIL。

---

## A. 镜中挑战出现率 71.8% → **100%**

### 改动
`scripts/rogue_graph.gd`
- `build()` 在**补给保底之后**追加"每局指定层保底一次 mirror"：由 `seed_value` 派生指定层，在该层挑一个"深度 ≥ `NEW_KIND_MIN_DEPTH["mirror"]`(5) 且不是 pre-boss 层"的中间槽写入 `mirror`；若顶掉了唯一补给，就地补一个（不与 mirror 同槽）。
- 新增 3 个纯函数辅助：`_mirror_floor_for(seed_value)`（`((seed*40503+17) & 0x7FFFFFFF) % 3 + 1` → 落在第 1~3 层，短局也吃得到）、`_mirror_slot(depths, sizes, kinds_by_depth)`、`_depth_has_supply(kinds_by_depth, depths)`。

### 硬约束核对
- **确定性**：派生只用整数运算（不碰字符串散列）；保底在 `build()` 内、同 (seed, floor) 必同 → `tests/rogue_graph.gd` 的"同种子重建逐字段相同"100 seed × 5 层全过。
- **不新增 `s.rng` 消耗**：保底不调用任何随机；`rogue_graph.gd` 依旧只用局部 RNG（测试里"不得消耗全局随机序列"那条仍过）。
- **既有不变量**：保底槽位满足 `depth >= NEW_KIND_MIN_DEPTH["mirror"]`、每层至多一次、每层仍 ≥1 补给、节点数/深度区间不变 → 该用例 0 failures。
- **不新增出口**：不动 `next`，出口数仍 ∈[1,2]。

### 出现率对照（400 局 × 5 层，`build/mirror_rate.gd`）
"加保底前"由脚本**本地复刻旧算法**得到；复刻的忠实性由"复刻(带保底) == 真实现 `Graph.build()`"的逐层 kinds 比对证明：**port mismatches 0**。

| 房间 | 单局出现率(前) | 单局出现率(后) | 单层出现率(前) | 单层出现率(后) |
|---|---|---|---|---|
| **mirror** | 288/400 = **72.0%** | **400/400 = 100.0%** | 435/2000 = 21.8% | 744/2000 = 37.2% |
| curse | 364 = 91.0% | 361 = 90.3% | 38.8% | 37.4% |
| event | 372 = 93.0% | 370 = 92.5% | 41.9% | 40.4% |
| forge | 374 = 93.5% | 372 = 93.0% | 41.9% | 40.4% |
| gamble | 342 = 85.5% | 337 = 84.3% | 31.9% | 29.9% |

**如实说明的副作用**：其余 4 种新房间的单局出现率各降 0.5~1.2 个百分点 —— 指定层上 mirror 会占掉一个候选槽。若要做到"零挤占"只能给该层加冗余节点，那会改 `MIN_NODES/MAX_NODES` 与既有断言，代价更大，故按"最不破坏既有"的选择保留并记录。

### 用例数字
`tests/rogue_graph.gd`：**83780 checks / 0 failures**（改动前 83608/0）。checks **+172** 的原因：`audit()` 里"每个新房间每层至多一次"的 `check` 只在真的出现该房间时才执行，mirror 出现次数变多 → 该断言执行次数变多。failures 0 不变。

---

## B. `event_active()` 加守卫

### 改动
`scripts/rogue_ui_model.gd:123` 附近 → 必须同时满足：**现在就在事件房**（`raid.room == "event"`）、报价非空、**报价 revision == 当前 revision**（`RogueEvents.roll_offer()` 与 `roguelike.refresh_dedicated()` 都按当前 revision 盖章）。
`scripts/main.gd:3485` 的派发不用改（守卫收在 `event_active()` 里）。

### 断言更新留痕（只按新语义最小更新，未删、未放宽）
`tests/rogue_ui.gd`（模型段，:73 起）
- 原文：`var pending := {"pending_event":{...}}` → `check(Model.event_active(pending), ...)`
  新断言：`pending` 补上 `"room":"event"` 与 `"revision":9`（报价 revision 也是 9）后才断言为 true。理由：新语义要求房间与 revision 双匹配。
- **新增两条**（更强，不是放宽）：
  - `leftover = {"room":"forge", "revision":9, "pending_event":{...revision:9...}}` → 断言 `event_active` 为 **false**（"an offer left over in another room must not hijack the panel"）。
  - `stale = {"room":"event", "revision":12, "pending_event":{...revision:9...}}` → 断言 **false**（"an offer stamped with an older revision keeps the panel closed"）。

`tests/rogue_ui.gd`（app 段，:231 起）
- 原文：直接 `Events.roll_offer(app.session)` 后断言事件面板有按钮。
  新断言：先保持上一段留下的 `room="curse"` 抽一次报价，断言 `app.find_child("RogueEventOption0")==null`（**残留报价不会接管面板**）；再 `room="event"` 重新抽报价，然后沿用原有按钮计数/命名断言。理由：同上，且这条正好复现"整局面板被顶掉"的现场。

`tests/rogue_ui_visual.gd`（:57 起）
- 原文：`Events.roll_offer(app.session)` 后截图。
  新断言：截图前先 `app.session.raid["room"]="event"`（上一段为 HUD 把 room 设成了 `curse`）。理由：同上。

### 用例数字
`tests/rogue_ui.gd`：**163 checks / 0 failures**（原 160/0，+3 条新断言）。
`tests/rogue_ui_visual.gd`（真实窗口）：**5 captures / 13 checks / 0 failures**。
`tests/rogue_events.gd`：484/0（未受影响）。

---

## C. 门禁 baseline 更新（`tools/run_rogue_gate.ps1`，只改登记，不动逻辑）

### 从豁免挪回判定
- `rogue_build_rules`：**565 checks / 0 failures**（素材补齐后跑到底，不再挂死）→ 加入 `$baseline`。
- `rogue_build_pack`：实测 **exit=0**（`BUILD PACK: main scene, five build tabs,252 icons,...`），但它**不打印 `<n> checks, <n> failures` 汇总行**，而本门禁的判定完全基于汇总行解析 → 若挪进判定集合会被记成 `FAIL:NO-SUMMARY`（假红）。因此**保留在豁免表**，但把理由改成准确描述（"无汇总行；exit=0 由人工核对"），并在脚本头部注释里删掉"缺 W001 图标"的过时说法。

### 新增/更新登记（数字均为本次复跑实测）
| 用例 | checks | failures | 备注 |
|---|---|---|---|
| roguelike_bosses | 1462 | 0 | 新登记（旧报告 463/0 已过时） |
| rogue_boss_pool | 2313 | 0 | 新登记（父会话给的 2305，实测 2313） |
| rogue_boss_bodies | 389 | 0 | 新登记 |
| rogue_hooks_roguelike | 85 | 0 | 新登记 |
| rogue_room_ui | 32 | 0 | 新登记 |
| final_e2e_roguelike | 120 | 0 | 新登记 |
| rogue_build_rules | 565 | 0 | 从豁免挪回 |
| rogue_ui | 163 | 0 | checks 160 → 163（B 的新断言） |
| rogue_ui_visual | 13 | 0 | 窗口用例，加入 `$visualTests`（需 `-IncludeVisual`） |
| rogue_room_ui_visual | 9 | 0 | 窗口用例，加入 `$visualTests`（需 `-IncludeVisual`） |

### 门禁汇总（`& .\tools\run_rogue_gate.ps1 -IncludeVisual`）
**32 PASS / 0 judged-FAIL / 3 EXEMPT / 35 rows**，exit 0。全部 32 行 failures 与基线一致（`boss_tactics 186/1`、`roguelike_routes 5220/2` 是既存红，按现失败数入基线不许变差）。日志：`build/gate-20261006-131311`。

其余与登记值的漂移（非本次改动引入，属并发写者，checks 只作参考不判红）：`rogue_graph` 83608→**83780**、`rogue_wiring` 123→**122**、`rogue_rooms` 1299→**1318**、`rogue_build_progression` 818→**727**。

---

## 未做 / 遗留
- 未跑 `tools/verify_rogue_build.ps1`（它对任意 `ERROR:` 行即 throw，本树不能当门禁）。
- 未改 `roguelike.gd` 的 `pending_event` 清理逻辑（bug sweep 那轮已加"进房即清"），本次只在 UI 侧加守卫，两道防线并存。
- 未改 `export_presets.cfg` / 文档等其它轮次的收尾项。
