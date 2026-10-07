# 肉鸽 Bug 扫荡报告（BUG-SWEEP）

- 被测树：`HEAD 7bbaf04`，测量时点 **2026-10-06 12:45–13:05**。
- ⚠ 测量期间**另有轮次在并发改同一棵树**（门禁的写者检测报 `scripts\rogue_build.gd`、`scripts\rogue_equipment.gd`、`scripts\session.gd`、`tests\roguelike.gd`、`tests\rogue_passives.gd` 在近 5 分钟内被写过）。本报告的**事件房缺陷**已在改后树上复跑确认仍然成立（`scripts\roguelike.gd` / `scripts\rogue_events.gd` 的 mtime 仍是 10/5 21:15）。
- 抓取方式：无头压测（5 个种子 × 完整 5 层到结算）+ 真实窗口截图（13 个房间）+ 定向复现探针。**没有靠读代码下结论**。
- 探针（gitignore 内，未入库）：`build\bugsweep.gd`、`build\bugsweep_visual.gd`、`build\bugsweep_visual2.gd`、`build\kind_stats.gd`；日志 `build\bugsweep*.out.txt`；截图 `build\sweep-*.png`。

---

## 结论摘要（按严重度）

| # | 严重度 | 一句话 | 状态 |
|---|---|---|---|
| BUG-1 | **CRITICAL** | 幽暗异事永远结算不了（revision 错位），且未清空的 `pending_event` 会把**此后每个房间**的面板顶掉，锻炉/赌徒/镜像**一个按钮都点不到** | **已修 + 已验证**（含真实窗口复现与门禁 23 PASS） |
| BUG-2 | LOW | 灰烬赌注禁用时提示「需 0」 | **已修**（一行文案） |
| BUG-3 | LOW（门禁口径） | `rogue_build_rules` 的豁免说明已过期（现在能跑完：565/0，不再挂死） | 只报告 |
| BUG-4 | LOW（内容可达性） | 镜像试炼在 **28.2%** 的局里完全不出现（实测 400 局） | 只报告 |

另附：**已验证无问题的怀疑清单**（节点图相机/换层、服务房面板不串台、HUD 变数一致、诅咒上限、守层者池+二阶段、灰烬/每日落盘）与 **3 条已排除的误报**，见下文。

## BUG-1 [CRITICAL · 已修并验证] 幽暗异事永远结算不了，并把整局后续房间的面板全部顶掉

**现象**
1. 事件房里点任何选项都**没有任何反应**（不扣钱、不加血、pending 不消失）。
2. 面板不消失：从这一刻起，**后续每一个房间**都画着幽暗异事面板，HUD 右列（变数/诅咒/灰烬/路线/种子）与房间面板被盖住。
3. **锻炉/赌徒/镜像房彻底不能用**：`main.gd` 的面板派发在异事面板处就 `return`，服务房的按钮根本不会被创建 —— 实测 `app.rogue_room_buttons == 0`。

**复现（真实窗口，`build\bugsweep_visual2.gd`）**
```
NOTE event at floor4/depth5
NOTE after click: still_pending=true          # 点了，没结算
NOTE forge at floor2/depth5 room=forge event_active=true
NOTE forge rows visible? rogue_room_buttons=0  # 锻炉房一个按钮都没有
NOTE gamble at floor3/depth4 room=gamble event_active=true
NOTE gamble rows visible? rogue_room_buttons=0
```
截图：`build\sweep-after-event-forge.png` —— 人在**熔炉工坊**（顶栏「魔焰铸炉 · 熔炉工坊 / 第 2/5 层 · 第 5/8 区」），画面上却是**幽暗异事**面板（「迷途魂灯」三选一），锻炉面板完全不存在。
截图：`build\sweep-lingering-event-panel.png` —— 人在**魔物围猎**战斗房（「剩余魔物 6 · 第 1/3 段遭遇」），异事面板盖在战场中央。

**无头复现（`build\bugsweep.gd`，5 个种子全部命中）**
```
FINDING[CRITICAL][EVENT-CLICK-DEAD] seed 1: pending.revision=287 / raid.revision=288
FINDING[CRITICAL][EVENT-CLICK-DEAD] seed 7: pending.revision=138 / raid.revision=139
FINDING[CRITICAL][EVENT-CLICK-DEAD] seed 1729: pending.revision=240 / raid.revision=241
FINDING[CRITICAL][EVENT-CLICK-DEAD] seed 813: pending.revision=17 / raid.revision=18（以及 137/138）
FINDING[CRITICAL][EVENT-CLICK-DEAD] seed 20261005: pending.revision=186 / raid.revision=187
FINDING[HIGH][EVENT-LINGER] 离开事件房后在 elite / combat / curse 房间仍留着 pending_event
```

**根因（精确到行）**
- `scripts\rogue_events.gd:119`：`roll_offer()` 把 `"revision" = int(s.raid.get("revision",0))` 写进 `raid.pending_event`（记作 R）。
- `scripts\roguelike.gd:310-318`：进专属房的顺序是 `open_room(s)`（抽事件 → pending.revision=R）→ `clear_room(s)`，而 `clear_room()` 在 `scripts\roguelike.gd:499` 把 `s.raid.revision += 1`（变成 R+1）→ 再 `refresh_dedicated(s)`。
- `scripts\roguelike.gd:794` 先用 `payload.revision == raid.revision` 过外层防重放守卫（UI 送的是面板构建时的 `raid.revision` = R+1），到 `scripts\roguelike.gd:798` 又要求 `Events.matches_revision(s, R+1)`，而它（`scripts\rogue_events.gd:94-96`）要求 `pending.revision == R`。
  ⇒ **R+1 == R 恒不成立**，事件永远走不到 `Events.apply()`，`pending_event` 永不清空。

**为什么"顶掉整局面板"**：`scripts\rogue_ui_model.gd:123-124` 的 `event_active()` 只判断 `pending_event` 非空，**不看房间、不看 revision**；`scripts\main.gd:3485-3487` 的派发顺序是 选择面板 → 异事面板 → 房间面板，命中即 `return`。

**第二个独立触发路径（即使修好 revision 也还在）**：`choose("rogue_next")`（`scripts\roguelike.gd:823-828`）只校验落点、队友状态与待选奖励，**不要求 pending_event 已结算**；`finish_rewards()`（`:873-890`）也不检查它。所以"玩家不点选项、直接走出去"同样会让 `pending_event` 残留到后续房间，症状与上面完全一样。

**建议修法**（三处，建议 A+B 一起做，C 作为防御）
- **A. 让 pending 的 revision 与玩家能看到的一致**（`scripts\roguelike.gd`）：把 `enter()` 里 `open_room(s)` 移到 `clear_room(s)` 之后；或在 `refresh_dedicated()` 里给事件补一次盖章 `pending_event["revision"] = int(s.raid.revision)`。两者都不改 `raid.revision` 的递增次数，回归面最小。
- **B. 离开房间即作废未结算的事件**：在 `enter()` 换房时清 `pending_event`（`raid["pending_event"] = {}`），或在 `clear_room()`/`advance()` 里清。
- **C. 面板派发加房间/revision 守卫**（`scripts\rogue_ui_model.gd` + `scripts\main.gd`）：`event_active()` 增加 `str(raid.get("room",""))=="event"` 且 `pending.revision == raid.revision` 的条件；`choose()` 的 `rogue_event` 分支也可顺手要求 `raid.room=="event"`（与 forge/gamble/mirror 三个分支的写法对齐）。
  注意：**B/C 会改变既有用例**（`tests\rogue_hooks_roguelike.gd:342`、`tests\final_e2e_roguelike.gd:222-231`、`tests\rogue_ui.gd:74` 都手工摆 `pending_event` 并期望能点，不改它们会红；但它们摆的是"同一 revision"，A 方案下仍然通过）。

**归属**：`scripts\roguelike.gd`（主）、`scripts\rogue_events.gd`、`scripts\rogue_ui_model.gd`、`scripts\main.gd`。

**已实施的修复（两处小改，都在 `scripts\roguelike.gd`）**
1. `refresh_dedicated()` 增加 `"event"` 分支，在进房流程末尾把 `pending_event["revision"]` 重新盖章为当前 `raid.revision` —— 与 forge/gamble 走同一条既有不变量（先例：`tests\rogue_hooks_roguelike.gd:169-177` 明确断言"服务房报价必须晚于 `clear_room` 的 revision 自增"）。不改任何 revision 递增次数，不动 offer/id。
2. `enter()` 的"进房即清"块（`offers` / `reward_claims` / `reward_chest` / `room_rewarded` / `reward_drops` 旁边）增加 `s.raid["pending_event"]={}`，堵住"不选就离开 ⇒ 面板残留"的第二条触发路径；事件房自己随后会重新 roll 一份。

**修复验证（全部实跑）**
```
# 无头：5 个种子各跑完 5 层到结算
ok event resolved (gold 5035 -> 5035)          # 点击真的生效了
seed 1/7/1729/813/20261005 结算完成 cleared=37~40 floors=5
FINDING 里 EVENT-CLICK-DEAD / EVENT-LINGER 全部消失（只剩下面那条已排除的误报）

# 真实窗口：事件房点完再进服务房
NOTE after click: still_pending=false
NOTE forge  room=forge  event_active=false  rogue_room_buttons=4   # 锻炉面板回来了
NOTE gamble room=gamble event_active=false  rogue_room_buttons=3

# 用例与门禁
rogue_events 484/0 · rogue_hooks_roguelike 85/0 · rogue_graph 83608/0 ·
final_e2e_roguelike 120/0/0-gaps · rogue_ui 161/0 · rogue_wiring/rogue_room_ui exit 0
& .\tools\run_rogue_gate.ps1 → 23 PASS / 0 judged-FAIL / 4 EXEMPT（写者检测：无源码写入，树静止）
```

**仍建议后续补的（防御性，我没做）**：`scripts\rogue_ui_model.gd:123` 的 `event_active()` 只判断 pending 非空、不看房间与 revision；即使上面两处修好，将来任何"pending 残留"都会重演"面板顶掉整局"。建议加 `room=="event"` + revision 匹配的判断，并同步改 `tests\rogue_ui.gd:74`、`tests\rogue_ui_visual.gd:58`（它们在没有 `room=="event"` 的状态下摆 pending 事件，加守卫后会红）。

---

## BUG-2 [LOW · 已修] 灰烬赌注显示"需 0"

- 现象：赌徒营帐第三行（押灰烬）禁用时提示「本局灰烬不足（**需 0**）」。
- 截图：`build\sweep-gamble.png`。
- 根因：`scripts\rogue_room_ui.gd:149` 用 `cost` 生成提示，而灰烬赌注的 `"cost"` 是 **0**（它的要求写在 `"stake"`，见 `scripts\rogue_rooms.gd:257-260`）。
- **已修（一行）**：改为 `% maxi(0, int(offer.get("stake", cost)))`。
- 验证：`--check-only scripts/rogue_room_ui.gd` → exit 0；`tests\rogue_room_ui.gd` → **32 checks / 0 failures**（该用例只断言 `contains("灰烬不足")`，不受影响）。

---

## BUG-3 [LOW · 门禁口径] `rogue_build_rules` 的豁免说明已过期

- `tools\run_rogue_gate.ps1` 仍写着 "aborts on check 1 … effective coverage = 0"，但本次实测该用例已经能跑完：**`rogue_build_rules` = 565 checks / 0 failures**（不再挂死）。
- 说明占位 manifest 已被别的轮次补上；`rogue_build_pack` 仍缺 `W001`，该豁免仍然有效。
- 建议：复核后把 `rogue_build_rules` 从豁免挪回判定集合（否则它会一直不被门禁管着）。**未改**（属门禁维护，不是游戏 bug）。

---

## BUG-4 [LOW · 内容可达性] 镜像试炼在 28% 的局里完全不出现

- 实测（`build\kind_stats.gd`，400 局 × 5 层，纯 `RogueGraph.build`）：

| 房型 | 单局出现率 | 5 层总节点数 |
|---|---|---|
| combat / elite / boss | 100% | 4465 / 2371 / 2000 |
| treasure / shop | 99.5% | 1715 / 1660 |
| talent | 96.3% | 1346 |
| forge | 93.5% | 840 |
| event | 93.3% | 840 |
| curse | 91.0% | 776 |
| gamble | 85.3% | 638 |
| **mirror** | **71.8%** | **434** |

- 根因：`scripts\rogue_graph.gd:35` 把 `mirror` 的最小深度设为 **5**，而中间槽只落在 `d ∈ [2, depths-2]`（`rogue_graph.gd:103-118`），`depths ∈ [7,9]`（`:86`）⇒ 每层只有 1~3 个槽能抽到它；且 `used_new` 使每种新房型**每层最多一次**（`:112-113`）。
- 影响：不是崩溃，是"新内容见不到"。玩家实测 5 层内可能一次都碰不到镜像房（我这次用的 seed 20261005 就是）。
- 建议：把 `NEW_KIND_MIN_DEPTH["mirror"]` 降到 4，或给新房间做"本局至少出现 N 种"的保底，或把 mirror 的权重提高。**未改**（数值/设计决策）。

---

## 已验证"没问题"的怀疑项（逐条给证据）

| 怀疑项 | 结论 | 证据 |
|---|---|---|
| 节点图接管后相机/落脚/换层是否还正确；会不会走不通/原地打转/跳过房间 | **正常** | 5 个种子（1/7/1729/813/20261005）各跑完整 5 层到结算：`cleared=37~40`、达到第 5 层、`raid.ended=true`、无卡死（停滞检测 30 步阈值未触发）、**全程 0 条 `SCRIPT ERROR`/`ERROR:`**（stdout 45 行、stderr 0 行） |
| 三种专属房的 `pending_*` 残留会不会在别的房间弹错面板 | 服务房**不会**（`main.gd:3469/3488` 按 `RogueRoomUi.handled(room)` 派发）；**只有 `pending_event` 会**（见 BUG-1） | `build\bugsweep_visual.gd` 依次进 11 种房间截图，服务房面板只在自己的房间出现 |
| HUD 显示的变数与实际生效的是否同一条 | **同一条** | 两者都读 `raid.variant`；`tests\final_e2e_roguelike.gd` §1/§2 有对照 |
| 多条诅咒叠加后减伤池是否被夹到上限 | **正常** | `tests\rogue_hooks_session.gd` 44/0（4×CU01 后池归零，不反转成收益） |
| 守层者池：客户端/房主是否算出同一个 Boss；二阶段是否只触发一次 | **正常** | `build\sweep-boss-phase2.png`：守层者血条显示「熔炉暴君 · 狂暴」；探针 `boss 熔炉暴君 enraged=true phase=2`；`tests\rogue_boss_phase2.gd` 406/0 |
| 灰烬/每日结算是否真的写入、重复结算是否重复加 | **正常** | `tests\rogue_profile_migration.gd` 113/0；门禁 `rogue_profile_migration` PASS |
| 弹幕三条管线是否可见、是否遮挡 HUD | **本轮未覆盖**（这次截图没捕到在飞弹幕） | 前序轮次的对照图仍在：`build\enemy-bullets-readability*.png` |

**门禁一次跑（`& .\tools\run_rogue_gate.ps1`，12:53:04）**：**23 PASS / 0 judged-FAIL / 4 EXEMPT**，全部与登记基线一致（既存红仅 `boss_tactics 186/1`、`roguelike_routes 5220/2`）。我的那行文案修复没有影响任何门禁用例。

---

## 已排除的误报（免得后续轮次重复怀疑）

1. **"押装备升阶后 max_hp 没重算"** —— 我的探针假设错了：`RogueBuild.hp_multiplier()`（`scripts\rogue_build.gd:100-101`）只认天赋 48/80，**武器阶不影响最大生命**；而 `rogue_inventory_revision` 确实递增（`apply_room_delta`，`scripts\roguelike.gd:1043-1049`）⇒ 界面刷新链路是通的，**不是 bug**。
2. **"HUD 深渊变数显示『未显现』"** —— 探针在同一会话里反复重进 1~5 层，把 `variants_seen` 撑过 18 条导致抽取池空。真实一局只有 5 次抽取（`variants_seen` 由 `reset()` 每局清空），**不会发生**。
3. **"诅咒回廊里弹出了灵契圣坛卡片面板"**（`build\sweep-curse.png`）—— 那是诅咒的对称回报（天赋三选一）触发的个人选择面板，属既有 `rogue_selection` 机制，**不是面板串台**。

---

## 未覆盖 / 未验证

- **并发写者造成的瞬时假红（不是 bug，但会误导别人）**：测量期间 `scripts\session.gd` / `rogue_build.gd` / `rogue_equipment.gd` 正被别的轮次改写，我一度看到 `tests\rogue_ui.gd` 报 `Invalid access to property 'rogue_graph' on TideSession`（161/2）与 `final_e2e_roguelike` 报 `Class "CombatVisuals" hides a global script class`——**几分钟后原样复跑两个都全绿**（161/0、120/0）。这类失败来自类缓存/脚本重载的中间态，排查时先复跑再归因。
- 联机多进程路径（需要 `-- --server --four`）本轮没跑；BUG-1 的客户端/房主一致性没有联机验证。
- 弹幕在飞的可见性与遮挡（本轮截图没捕到）。
- `rogue_equipment.gd` 被动体系（另一轮次正在改，我按纪律没碰）。
- 我这次没跑全仓库 171 个用例，只跑了门禁集合，因此门禁集合外的红（`balance`/`boss_redesign`/`rogue_inventory`/`rogue_chest_rewards`/`roguelike_animations` 等，前序轮次已分诊为既存）没有重新判定。
