# V2 终验 · 新肉鸽玩法的端到端验真

- 用例：`tests/final_e2e_roguelike.gd`（新建，**只新增这一个测试文件**，未改任何既有源码/测试/文档）
- 结果：**106 checks / 0 failures / 2 KNOWN-GAP**
- 门禁：`& .\tools\run_rogue_gate.ps1` → **23 PASS, 0 judged-FAIL, 4 EXEMPT**（exit 0）
- 引擎：`Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit-after 4000 --script tests/final_e2e_roguelike.gd`
- 原始日志：`build/v2-verify/final-e2e.txt`、`build/v2-verify/gate-run.txt`（`build/` 在 gitignore 内）
- **测量时点：2026-10-05 20:35–20:40，工作树里仍有写者**（见下）

> ⚠ **测量时点在飞**：门禁脚本自己的写者检测在 20:35:03 报出 8 个文件在 5 分钟内被写过
> （`scripts/roguelike.gd` 20:30:31、`scripts/effect_semantics.gd` 20:30:04、`scripts/rogue_enemy_vfx.gd` 20:30:17、
> `scripts/boss_effect_staging.gd` 20:30:32、`scripts/boss_damage_visual.gd` 20:30:27、
> `tests/rogue_build_progression.gd` 20:30:39、`tests/rogue_hooks_roguelike.gd` 20:34:59、`tests/final_e2e_roguelike.gd`）。
> 下游消费这些数字时请重跑一次"无写者 ≥5 分钟"的门禁。本报告里所有 failures 都 ≤ 基线，未出现判红。

---

## 一、逐项结论（派单的 9 项 + 我补的第 10/11 项）

| # | 项目 | 结论 | 关键证据（实测） | 「如果没接线会怎样」 |
|---|---|---|---|---|
| 1 | 开局抽变数 + HUD 显示 | **真实可用** | 真实 `launch(false,4242)` 后 `raid.variant=iron_law`、`variants_seen=["iron_law"]`；`UiModel.variant_line()` 含该条 label；路线/诅咒/灰烬/层数四行都有内容 | 没接线时 `raid.variant` 恒为 `""`，HUD 只会打印占位「深渊变数 · 未显现」 |
| 2 | 变数真的作用于战斗 | **真实可用** | `fog`：真实 `update_enemies()` 打出的子弹速度 245→196（×0.8）、`bullet_visual=1.25`、无 `hit_radius`；`bedrock`：真实刷出的小怪 `max_hp` ×1.200（实测 1.000→1.200）；开关变数时 `hit_radius` 默认值两边完全一致 | 不接线时弹速/生命恒等于基础值、子弹字典里不会有 `bullet_visual` |
| 3 | 诅咒真的生效 | **真实可用** | 构造确定性减伤池 0.10：`incoming_damage` 恰好等于 `base×(1-clamp(pool-penalty))`，**不等于** `without×1.15`；4 层同诅咒把池压到 0 且不反转成收益；带诅咒清房金币 > 无诅咒 | 不接线时 `defense_penalty` 无处可减，诅咒只是 HUD 文字 |
| 4 | 幽暗异事（事件房） | **真实可用** | `open_room()` 产出带 `id` 的 `pending_event`（选项 ≥2）；**过期 revision** 点击不动 pending、不动钱包；正确 revision 点击真的解决事件；`index=99` 安全失败且保留 pending | 不接线时 `choose()` 会落到函数尾静默返回，按钮点了没反应 |
| 5 | 三个新房间 | **真实可用** | 锻炉：按 `Rooms.forge_point_price(3)` 精确扣费并给 1 锻造点、revision 前进；赌徒押魔晶结果恰为 `±stake`；**押阶**结果 3→4/2，`rogue_inventory_revision` +1 且 `max_hp` 被重算；镜像两步走、第二次结算、本局已用则不再出奖励 | 不接线时四个动作都不存在，房间只会在 HUD 上显示名字 |
| 6 | 灰烬 / 局外成长树 | **部分接线（真实对局不通）** ⚠ | 机制本身对：注入 profile 后 `settle()` 发的灰烬 = 入账灰烬、重复结算不再发；`growth.coin_purse=2` 让开局钱袋 60→110。**但真实对局里 `main.gd` 从未把 `profile.data` 交给 session** → 见 §二 GAP-1、GAP-2 | 不接线时 `RogueGrowth.power({})` 全 0、`grant()` 的 `data.is_empty()` 直接不写 `ashes`：玩家只会看到「本局 N · 累计 0」，永远买不动成长树之外的任何东西 |
| 7 | 每日挑战 / 种子分享 | **部分接线** | `encode→parse` 往返恒等；空串/乱码返回 0；房主用 `global_daily_seed()` 开局 → `raid.daily==true`，非每日种子 → false；种子 0 落到随机局 | 打卡落盘这一环没接（GAP-2）；非房主的联机带种子路径**本轮未验证**（需多进程） |
| 8 | 守层者池 + 半血二阶段 | **真实可用** | 真实 `spawn_wave()`：`boss_art == boss_art_for(seed,floor)`、`boss_name == NAMES[art]`、`rogue_skin` 仍是楼层、编排表 7 条；把血打到 50% 以下 → `boss_enraged=true`、`boss_phase==2`，**回血不回退**；一阶段 40 次游标扫描拿不到 5/6，二阶段必定出现 5/6 | 不接线时 `setup_boss` 缺第 3 个实参 → 回归"楼层即身份"，二阶段不会切招表 |
| 9 | `bullet_visual` 的绘制消费端 | **真实可用** | `CombatVisuals.bolt_layers()`：倍率 1.0/1.25/1.5 下**实心内核恒为 36.0px**（=18px 判定半径×2），而贴图框 61.2→76.5→91.8、外光晕 76.5→95.6→114.7 单调增长；clamp `[1.0,3.0]`；`EffectSemantics.visual_of()` 同样消费；`boss_effect_staging` 的 `size` 乘同一倍率；独立自检工具 `tools/verify_enemy_bolt_readability.gd` **36 checks / 0 failures** 复现同一结论 | 若无人消费，变数只改速度与数据，"更大"看不出来（这正是 R0 复核当时的状态） |
| 10（补） | 结构钉死 | **通过** | `session.gd` 含 `bullets.append(rogue_enemy_bolt(` 与 `float(b.get("hit_radius",18.0))`；`roguelike.gd` 含 `rogue_event/rogue_forge/rogue_gamble/rogue_mirror` 四个分支 + `Growth.grant(s,p)` + `record_daily(s,p`；`ecology.gd` 含 `rogue_enemy_bolt(` | 防止后继改动悄悄拆掉接线点 |
| 11（补） | 逐层抽取的确定性/不扰动 RNG/去重 | **真实可用** | 同种子两局第 1 层变数相同；`RogueVariants.roll()` 前后 `s.rng.state` **逐位不变**（已改用局部派生 RNG）；同一层重复 `enter()` 不重抽（`fresh` 守卫）、`variants_seen` 不膨胀；连走 5 层后 seen 内互不重复 | 若用 `s.rng` 抽取，会把既有随机流整体位移（曾导致 `rogue_build_growth` 样本 `[213,500]`→`[204,498]`） |

### 一处被我用例纠正的"想当然"
我最初断言"同一层重复调用 `roll()` 结果不变"，**实测失败**：`roll()` 会把刚抽到的 id 当作 `exclude`，手动再抽必然换一条。
这是**有意的去重语义**，运行期的"每层恰好一次"由 `enter()` 的 `fresh` 守卫保证（`roguelike.gd:264-270`），不是靠 `roll()` 自身幂等。
我把断言改成测那条真正的不变量（重复 `enter()` 不重抽），已通过。**不是缺陷**。

---

## 二、KNOWN-GAP（只报告、不修）

### GAP-1 · `main.gd` 从未把 `profile.data` 交给 session（局外成长/灰烬全线断在最后一米）
- 位置：`scripts/main.gd:3403` `start_rogue()`（到 `:3430`）；`session.configure(payload)` `:3420`；`session.launch(false,seed)` `:3422`。
- 现状：全文件 **0 处** `set_meta("profile_data", …)`，`payload` 里也只有 `mode/rogue_rerolls/rogue_weapon/rogue_seed/rogue_daily`。
- 读取方：`scripts/rogue_growth.gd:465-475 _session_profile_data()`（方法 → meta → `{}`）、`scripts/roguelike.gd:74-82 profile_data_of()`（同探测链）、`scripts/roguelike.gd:109 Growth.power(profile_data_of(s))`。
- 复现：`new_session(6161, {"growth":{"coin_purse":2}})` → 开局 `rogue_gold==110`（✓）；而真实 `start_rogue()` 路径下 meta 不存在 → `power({})` 全 0 → 开局恒为 60。
- 影响：① 成长树 14 个节点的**战斗/开局效果全部不生效**（节点能买、能存盘、HUD 显示等级，但买了个寂寞）；② `settle()` 里 `Growth.grant()` 因 `data.is_empty()` 只写 `p.rogue_ash_run`，`profile.data.ashes` **永远不增加**（`rogue_growth.gd:238-240`）；③ 于是 `main.gd:3396` 的成长树摘要与 HUD 的"累计"永远是 0。
- 期望行为：`start_rogue()`（或 `config()`）在 `session.configure()` 之前调用 `session.set_meta("profile_data", profile.data)`；并在会话结束后回写（`settle()` 已经原地改的就是这个字典，`save_profile()` 即可落盘）。
- 注意：这是**一行接线 + 一次回写**，但属于 W1/W2 的文件，我按派单没有改。

### GAP-2 · `profile.gd` 的默认档里没有 `daily` 键 → 每日挑战永远不打卡
- 位置：`scripts/profile.gd:7-10`（默认只有 `ashes`/`growth`，没有 `daily`）；`scripts/roguelike.gd:1064-1068 record_daily()` 主动探 `data.has("daily")`，没有键就直接 `return`。
- 现状：契约 CHANGE-LOG v3-1 已批准 `profile.data["daily"]`（Dictionary、默认 `{}`、键 `daily:YYYY-MM-DD`），但 `profile.gd` 还没落地这个默认值。
- 复现：注入 `{"ashes":0,"growth":{}, "daily":{}}` 时 `settle()` 会写下 `daily:2026-10-05`（✓，本用例已断言）；而用真实 `profile.gd` 造出来的档没有该键 → 打卡被静默跳过。
- 影响：每日挑战的"打卡/最好成绩/连胜"永远为空；由于 `apply_data()` 只做 typeof 匹配，即便以后手写进存档也会被清洗掉。
- 期望行为：`profile.gd` 的 `_init()` 默认表加 `"daily":{}`，并把 `daily` 加进清洗白名单（未知日期键、非字典值丢弃）。
- 相关的第三处（同源风险，未单独计为 GAP）：GAP-1 一旦修好，`record_daily()` 还需要 `raid.daily` 为真——本用例已证明"房主用每日种子开局 → `raid.daily==true`"这条派生是对的。

---

## 三、门禁实测（`run_rogue_gate.ps1`，20:35:03，含写者告警）

| 用例 | checks | failures | 基线 | 判定 |
|---|---|---|---|---|
| rogue_graph | 83608 | 0 | ≤0 | PASS |
| rogue_variants | 507 | 0 | ≤0 | PASS（checks 由 495 升到 507：R8 改用局部 RNG 后更新了断言） |
| rogue_curses / rogue_events | 218 / 484 | 0 / 0 | ≤0 | PASS |
| rogue_wiring | 122 | 0 | ≤0 | PASS（checks 由 123 降到 122，见下） |
| rogue_growth / rogue_rooms / rogue_daily / rogue_profile_migration | 6886 / 1299 / 132 / 113 | 全 0 | ≤0 | PASS |
| rogue_build_growth / rogue_build_system | 4066 / 440 | 0 / 0 | ≤0 | PASS |
| roguelike_seven_rooms | 11832 | 0 | ≤0 | PASS |
| rogue_build_progression | 717 | 0 | ≤0 | PASS（checks 由 818 降到 717，见下） |
| systems / expedition / combat / enemy_body | 10812 / 79 / 78 / 379 | 全 0 | ≤0 | PASS |
| boss_tactics | 186 | **1** | ≤1 | PASS（既存红，非本轮） |
| roguelike_routes | 5220 | **2** | ≤2 | PASS（既存几何红，非本轮） |
| rogue_boss_phase2 / rogue_ui / rogue_hooks_session / rogue_hooks_ecology | 406 / 161 / 44 / 40 | 全 0 | ≤0 | PASS |
| rogue_build_rules / rogue_build_pack / 两个 network | — | — | — | EXEMPT（资产目录未提交 / 需多进程） |

**结论：没有新增失败。** 两个 checks 计数下降（`rogue_wiring` 123→122、`rogue_build_progression` 818→717）**不是**失败增加，而是写者在删/改断言；门禁按设计"只比 failures"，我按派单只报告：
- `rogue_wiring` 少 1 条：R8 把"恰好消耗 1 次 `s.rng`"改成"不消耗"时通常会同数替换，少 1 条更像是删掉了一条合并断言 —— 建议由该文件所有者确认是否**有断言被静默删除**（这是我的观察，不是判定）。
- `rogue_build_progression` 818→717：R5 的旧口径移植在 20:30:39 又被写过一次，checks 大幅下降需要它自己交代"是合并了重复断言还是删了断言"。**failures 仍为 0**，所以不影响门禁结论。

---

## 四、我没能验证的部分（诚实清单）

1. **联机多进程**：`roguelike_network` / `rogue_build_network` 单跑是 NO-SUMMARY，需要 `-- --server --four`；我**没有**跑。因此"非房主带种子开局""变数在客户端不重抽""灰烬只在房主侧结算"这些联机性质**未验证**。
2. **像素级观感**：本轮是 headless，没有出图。`bullet_visual` 的消费我是用"内核恒 36px / 外壳单调增长"的数值 + 既有自检工具证明的，**不是**看图证明；弹幕是否"一眼能看出差别"需人工看截图（已有 `build/enemy-bullets-readability*.png`）。
3. **`daily` 落盘闭环**：因为 `profile.gd` 还没有该键，我只能用注入字典证明"机制对"，**无法**验证真实存档里写入→`save_profile()`→再读回环。
4. **成长树节点的战斗效果**（如 `hunt_instinct` 的我方伤害 +4%）：`power()` 的数值合成有 R12 的 6886 条断言，但**没有**任何一条"成长树 → 实际伤害数值"的端到端断言；在 GAP-1 修好前也测不出来。
5. **`rogue_skin` 与身体立绘的回退**（R14 已知局限）：新守层者的特效/招式名按身份走，但身体立绘按楼层取帧。需要人眼确认图标/立绘是否明显错配。
6. **Boss 弹的实机像素尺寸**：它是 shader 外壳，我只核了 `size = inner*2.5*bullet_visual` 这条链与数值增长（45.0→56.3），未从截图连通域实测。

---

## 五、一句话总结

除"灰烬/局外成长树"与"每日打卡"这两处**同一根因**的最后一米断线（`main.gd` 不交 `profile.data`、`profile.gd` 缺 `daily` 键）之外，本轮新增的肉鸽玩法——**节点图推进、18 条深渊变数、10 条诅咒、9 个幽暗异事、锻炉/赌徒/镜像三个房间、8 个守层者 + 半血二阶段、种子分享与每日挑战的种子口径、HUD/界面**——都已能在真实会话里跑通并有断言为证。
