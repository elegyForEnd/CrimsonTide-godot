# 魔境扩展 · 系统 × 接线状态台账（R19 文档轮）

- 日期：2026-10-05 晚；工作副本 `D:\game\CrimsonTide-godot`。
- 来源：源码逐处 grep 核对 + 本轮实测（引擎 `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/<n>.gd`），
  另有各轮交付记录（`output/R5-*.md` … `output/W1c-*.md`、`output/ROGUE-CONTRACTS.md`、`output/CONTRACT-CHANGELOG.md`）。
- ⚠ **测量时点在飞**：本轮实测期间（20:27–20:31）仍有写者（`roguelike.gd`、`tests/rogue_build_progression.gd`、
  `tests/rogue_variants.gd`、G 集合 5 个渲染文件）。同一用例在 1 分钟内出现过 812/6 → 717/0 的自愈，
  因此**下表数字只作参考，正式门禁数字必须在所有写者停止 ≥5 分钟后重测**（见 `output/GATE-POLICY.md` 规则 8）。
- 状态词：`已接线`＝运行时真的会生效；`部分接线`＝部分消费点缺失；`仅数据层`＝无消费者。

---

## 表 1 · 系统 × 接线状态

| 系统 | 数据层 | 已接线（运行时生效） | 未接线 / 回落行为 | 关键位置 | 验收用例与数字（本轮实测） |
|---|---|---|---|---|---|
| 层间节点图 | `rogue_graph.gd` | **已接线**：`new_floor()/enter()` 用 `RogueGraph.build(seed_value,floor)` 取代固定 7 槽；`raid.node/depth/graph_floor` 推进；图**不进快照** | 无（客户端按 `seed_value`+floor 本地重建） | `scripts/rogue_graph.gd`、`roguelike.gd` `new_floor/enter`、`session.gd:77` `rogue_graph` 非快照字段 | `rogue_graph` **83608/0**、`roguelike_seven_rooms` **11832/0**、`rogue_wiring` 122 检查（见注①） |
| 深渊变数（18 条） | `rogue_variants.gd` | **已接线**：每层 1 条（局部 RNG，**不消耗 `s.rng`**）、`raid.variant`+`variants_seen` 去重；受击 / 普攻 / 移速 / 敌人生命·移速·伤害 / 金币·经验·商店价·掉率·精英率 / 敌人弹速 | **敌人弹幕尺寸无画面效果**：`bullet_visual` 只有产出端、**全仓库无绘制端消费者**（详见局限 2） | `rogue_variants.gd`（`pick/_derive_seed/modifiers_of`）、`session.gd:465,485,540,2667,3038,3401`、`roguelike.gd:64,331,366,430,479,514,603,700,915`、`ecology.gd:113,170` | `rogue_variants` **507/0**、`rogue_hooks_session` **44/0**、`rogue_hooks_ecology` **40/0**、`rogue_hooks_roguelike` **55/0** |
| 诅咒回廊（10 条 CU01–CU10） | `rogue_curses.gd` | **已接线**：`open_room()` 进房每人 1 条 + 对称回报；受击走 `defense_penalty` **与既有减伤池同池相减**（不开新乘数） | 无 | `rogue_curses.gd`、`roguelike.gd:954-963`、`session.gd:540-549` | `rogue_curses` **218/0** |
| 幽暗异事（9 事件 / 25 选项） | `rogue_events.gd` | **已接线**：`open_room()`→`Events.roll_offer`；`choose()` 的 `rogue_event` 走 `matches_revision`→`apply`（在 `revision` 守卫之后） | 无 | `rogue_events.gd`、`roguelike.gd:964-966,797-800`、`main.gd:3510` `RogueEventOption%d` | `rogue_events` **484/0** |
| 游方锻炉 / 赌徒营帐 / 镜中挑战 | `rogue_rooms.gd` | **已接线**：`raid.pending_forge/pending_gamble/mirror_state`；`choose()` 的 `rogue_forge/gamble/mirror` → `room_action()/mirror_action()` → `apply_room_delta()`（换阶同步 `refresh_max_hp()`+`rogue_inventory_revision`） | 无 | `rogue_rooms.gd`、`roguelike.gd:968-1059`、`main.gd` 房间界面 | `rogue_rooms` **1299/0** |
| 守层者半血二阶段 | `rogue_combat.gd` | **已接线**：半血 → `boss_enraged`+`phase=2`（单调、只触发一次），7 招表，两个终结技一阶段绝不出现；一阶段与扩容前逐位一致 | 无 | `rogue_combat.gd`、`boss_choreography.gd`、`sound.gd` | `rogue_boss_phase2` **406/0** |
| 守层者池 5→8 身份 | `rogue_combat.gd` / `boss_effect_art.gd`（8 项，零新美术） | **已接线**：`setup_boss(...,floor_index,**s**)` 已传参（`roguelike.gd:365`），降临播报改用 `boss_name`（`:371`）；身份由 `(seed_value,floor)` 确定性派生、不消耗 `s.rng` | 身体立绘仍按楼层取帧（局限 3） | `rogue_combat.gd`（`NAMES`/`boss_pool`/`moves_of`）、`boss_effect_art.gd:9`、`boss_choreography.gd` | `rogue_boss_pool` **2305/0**；`roguelike_bosses` **466/2（待修，见表 2）** |
| 种子分享与每日挑战 | `rogue_daily.gd` | **部分接线**：分享串 `CT-`+8 位十六进制+校验；UTC 每日种子由房主下发，写 `raid.daily`/`raid.seed_shared`；UI 拒绝空/0/越界/乱码 | **打卡未生效**：`profile.data["daily"]` 未在 `profile.gd` 注册默认值，而 `record_daily()` 只在键已存在时写 → 空操作（局限 1） | `rogue_daily.gd`、`roguelike.gd:105-106,1064-1068`、`main.gd` 种子页 | `rogue_daily` **132/0** |
| 灰烬与永久成长树（14 节点 / 满树 7305） | `rogue_growth.gd` | **已接线**：`settle()`（唯一结算点、`raid.ended` 守卫）→ `Growth.grant`；`reset()` 用 `power()` 加成开局金币/刷新卡；UI 弹窗本地购买并落盘；`profile.ashes/growth` 已落地且 `version` 仍为 1 | 无（`session.gd:115 profile_data()` 通道已存在） | `rogue_growth.gd`、`profile.gd:10,122-133`、`roguelike.gd:109,925`、`main.gd:3608` `GrowthBuy_<id>` | `rogue_growth` **6886/0**、`rogue_profile_migration` **113/0** |
| HUD / 入口界面 | `rogue_ui_model.gd` | **已接线**：HUD 5 行（变数/诅咒/灰烬/路线/种子）、幽暗异事面板、种子页、成长树弹窗；所有动作带 `raid.revision` | 无 | `rogue_ui_model.gd`、`main.gd:1199-1214,3392-3608` | `rogue_ui` **161/0**、`rogue_ui_visual`（窗口）**13/0** |
| 敌人弹幕可读性（用户主诉） | — | **回炉中**：普通敌弹 1.8× + 描边/双光晕/3 段拖尾 + 去渐显（**该因果解释经复核为错**）、魔境矢量弹 2.0×、Boss 弹 shell；判定几何经独立复核**认定零变化** | 见局限 2（未消费 `bullet_visual`）；回炉要求：光晕 Ø113 需收敛到判定圈 Ø36 量级、`#ffb3c0` 近白粉换高饱和危险色、补「弹幕+地面预警同框」取证 | G 集合：`combat_visuals.gd`、`effect_semantics.gd`、`rogue_enemy_vfx.gd`、`boss_effect_staging.gd`、`boss_damage_visual.gd`、两个 boss shader | 复核报告 `output/R0-BULLET-VERIFY.md`；`combat` 78/0、`enemy_body` 379/0、`effect_semantics` 1365/0、`boss_effect_staging` 246/0 |

注①：`rogue_wiring` 本轮首次测得 **122/1**（`seed_shared starts empty` 过期），1 分钟后复测 **122/0**；`rogue_build_progression`
同窗口内 812/6 → **717/0**（测试文件 20:30:39 被重写）。两者都属"写者在飞"，需重测后再更新门禁。

---

## 表 2 · 已知红与豁免清单（逐条核对过失败原文）

| 用例 | 实测 | 归因 | 证据 | 是否本轮引入 |
|---|---|---|---|---|
| `roguelike_bosses` | **466/2** | **R14 测试迁移缺口**：`:96` 用 shape 反推"危险区内一点"的启发式按旧身份写；`:118` 直接用 `contact.p` 断言站进危险区会掉血，实际掉血 0 | 两次运行同值；`ERROR: Damage geometry includes advertised danger area`、`ERROR: Standing inside released danger actually takes damage: 4/3 幽蕈深潜` | **是（待修）**：池在 `setup_boss(...,s)` 接线后真正生效，两条断言失效 |
| `boss_tactics` | 186/**1** | 既存红：玩家子弹正面格挡路径（`session.update_bullets()` 与用例均不在弹幕 diff 中） | R1 基线同为 186/1；弹幕轮 `git stash` 复现同值 | 否 |
| `roguelike_routes` | 5220/**2** | 既存几何红：`tests/roguelike_routes.gd:88`「每段分支连续可行走」，只 `import rogue_map.gd`、`room==""` 走未改动分支 | R1 基线同一行号同次数；节点图迁移后 `:40/:48/:54` 三条已转绿、`:=88` 两条原样 | 否 |
| `tests/roguelike.gd` | **NO-SUMMARY** + `SCRIPT ERROR: Out of bounds get index '1'`（`:67`） | 旧口径（"五层 25 区"）未随节点图移植；3 条断言失败 `Starting purchases applied`/`Unexpected phase`/`All five floors and every graph row completed` | 本轮实测（帧上限内无汇总行） | 属节点图迁移的**遗留未移植**（R5 未覆盖该用例） |
| `roguelike_animations` | **NO-SUMMARY**（94s 空转到帧上限） | 用例仍在调用已移除的 `rogue_art.spell_animation` | 本轮实测 | 否 |
| `balance` | 159/**6** | 战役路径：`Attack delivery scales once for species 4`、`Boss attacks at least eleven times in thirty seconds`；魔境钩子在非魔境下恒等（`solo` 模式 mods 必空） | W1c 给出"逻辑不可能受影响"论证；**未做 stash 对照**（会破坏并发写者） | 未确定（此前从未登记进基线） |
| `boss_redesign` | 744/**3** | 美术资源断言（非 1024²、共享 reskin 源、`paths.size()==68`） | R14 报告 + 本轮实测同值 | 否 |
| `roguelike_minion_skills` | 103/**1** | 治疗 AI 选招；**可能与变数抽取扰动 `s.rng` 有关**（R8 已把 `roll()` 改局部 RNG，需重测确认是否转绿） | 本轮实测 | **未确定**（待重测） |
| `roguelike_attack_timing` | 55/**30** | **未核实**（本轮扫描新发现，未做归因） | 本轮实测 | 未确定 |
| `rogue_build_balance` | **NO-SUMMARY** + 90s TIMEOUT | **未核实** | 本轮实测 | 未确定 |
| `rogue_chest_rewards` | **NO-SUMMARY**（47.7s，scriptErr=1） | **未核实** | 本轮实测 | 未确定 |
| `rogue_build_rules` | NO-SUMMARY，有效覆盖 0 | **豁免**：`assets/rogue/build/` 被 gitignore 且只有 7 字节 `{}` 占位 manifest，第 1 个 check 就崩、126+ 断言零执行 | `GATE-POLICY.md` §4 | 否 |
| `rogue_build_pack` | NO-SUMMARY，`Missing exported icon W001` | **豁免**：生成图标未提交 | 同上 | 否 |
| `roguelike_network` / `rogue_build_network` | 单跑 NO-SUMMARY | **豁免**：需 `-- --server --four` 多进程 | 同上 | 否 |

---

## 表 3 · 已知局限 + 未能验证的部分

| # | 局限 / 未验证 | 事实与位置 |
|---|---|---|
| 1 | **每日挑战打卡未生效** | `profile.gd:_init()` 无 `daily` 默认键（契约 v3-1 状态＝"计划中·未生效"）；`roguelike.gd:1064-1068 record_daily()` 明确"只在键已存在时才写"，故当前是**空操作**而非假成功 |
| 2 | **`bullet_visual` 无绘制端消费者** | 产出：`session.gd:493`、`rogue_combat.gd:432`、`boss_choreography.gd:570`；`combat_visuals.gd` / `effect_semantics.gd` / `boss_effect_staging.gd` 均不读它 → 「雾障/狂潮」的弹幕尺寸变化**在画面上看不出来**（弹速变化有效） |
| 3 | 新守层者身体立绘按楼层取帧 | `enemy_body.gd → rogue_art.boss_animation(int(e.rogue_skin))` 只有 5 套帧（`boss-hd-0..4`）；零新美术下新身份的**特效/颜色/招式名/构建物**按身份渲染，**身体立绘回落** |
| 4 | 弹幕视觉与判定圈的尺度 | 独立复核：普通敌弹光晕 **Ø113.2** 是判定圈 **Ø36** 的 **3.14×**，且没有任何一层等于 36px；body 用近白粉 `#ffb3c0`，浅色地形靠暗描边撑对比 → 回炉中 |
| 5 | 变数抽取的 `s.rng` 位移 | R8 已按 v2-11 改为**局部 RNG**（`_derive_seed`，不读不写 `s.rng`）；但此前依赖随机序列的旧断言（如疑似 `roguelike_minion_skills`）**需重测确认** |
| 6 | CU08「迷雾」的 `vision` 无接线点 | 来自 W1a 报告的缺口（**我未独立复核**） |
| 7 | 移速加成进有上限的池 | `session.gd:2667` 同一 `minf` 池，接近上限时部分失效（既有设计，未改） |
| 8 | 弹幕会被墙体遮挡而墙体不挡伤害 | 既有取舍，本次未变好变坏，但与"看得清就躲得掉"直接冲突（复核报告 §剩余风险） |
| 9 | 成长树敌人倍率恒 ≤ 1.0 | `RogueGrowth.power()` 的 `enemy_hp/enemy_damage ∈ [0.70,1.0]`，成长树**永不**让敌人更强（设计选择，非缺陷） |
| 10 | 服务端不校验 `ashes`/`growth` | `server/app.py` 只硬校验 `version == 1` 与 `attributes` 白名单；手改客户端可上传离谱灰烬（R3 实测 8/8 PASS 含 `1e12`） |
| 11 | **联机多进程路径未验证** | 两个 network 用例单跑无汇总行，本轮**未跑** `-- --server --four` 四进程验证 |
| 12 | `rogue_build_rules` 有效覆盖为 0 | 恢复 `assets/rogue/build/` 真实生成物（252 图标 + manifest）之前无法作为回归信号 |
| 13 | 可视化只覆盖特定场景 | `rogue_ui_visual`（5 张）、弹幕预览（4 张）、`combat_visual`（14 张）为定点截图；**没有**"弹幕 + 地面预警同框"的取证 |
| 14 | 本轮所有数字带"在飞"风险 | 见文首 ⚠；`progression`/`wiring`/`roguelike_bosses` 的正式数字需在写者停止 ≥5 分钟后用 `& .\tools\run_rogue_gate.ps1` 重测 |

---

## 本轮的写入面与验证方式

- **写入**：`ROGUELIKE.md`（订正过时表述 + 追加「魔境扩展」章节）、本文件、`tools/run_rogue_gate.ps1`（**仅 baseline 表**）。
  未改任何 `scripts/*.gd`、`tests/*.gd`、`resources/*`。
- **实测**：30 个用例逐跑（`--quit-after 12000`，日志 `build/r19-measure/`）+ 窗口用例 `rogue_ui_visual` + 18 个补充用例扫描（`build/r19-sweep/`）。
- **源码核对**：`rogue_graph/rogue_variants/rogue_curses/rogue_events/rogue_rooms/rogue_growth/rogue_daily/rogue_combat/boss_choreography/boss_effect_art/profile/roguelike/session/ecology/main/rogue_ui_model` 逐处 grep 消费者。
