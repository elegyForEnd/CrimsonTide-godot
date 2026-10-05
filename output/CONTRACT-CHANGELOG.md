# 魔境扩展 · 契约变更汇总（v1 / v2 / v3 一览）

- **用途**：`output/ROGUE-CONTRACTS.md` 是权威契约及其 CHANGE-LOG；本文件是它的**可读汇总**，
  给后续轮次快速定位"现在要遵守什么、什么已经生效、什么还没接线"。
- **维护轮次**：R1b（契约维护轮，由顶层调度指派）；日期 2026-10-05；工作副本 `D:\game\CrimsonTide-godot`。
- **本轮写入面**：只写 `output/ROGUE-CONTRACTS.md`（**追加** CHANGE-LOG v2/v3）与本文件；**未改任何源码/测试/其它 md**。
- **状态词**：`已生效`＝源码已落地且已进调用路径；`已落地·待接线`＝模块已交付、尚无消费者（玩法未生效）；
  `计划中·未生效`＝已裁决、尚未执行；`已取代`＝v1 描述已作废，以新条目为准。

---

## 1. 三条速查结论

1. **数据层基本齐了**：`RogueGraph`(R4 83608/0)、`RogueVariants`(R8 495/0)、`RogueCurses`(R9 218/0)、
   `RogueEvents`(R9 484/0)、`RogueDaily`(R11 132/0)、`RogueGrowth`(R12 6886/0)、`RogueRooms`(R10，进行中) 均已交付且自带 0-failure 用例。
2. **玩法层还没通**：`RogueCurses`/`RogueEvents`/`RogueGrowth`/`RogueDaily`/`RogueRooms` **目前零消费者**；
   `RogueVariants` 只接进了敌人侧（`rogue_combat.gd:96`），`session.gd` 的玩家侧与经济钩子尚未接。
   → **"拓展肉鸽玩法"对玩家可见的效果，取决于还没做的 W1 钩子接线轮**。
3. **判定几何红线全程未被触碰**：所有新模块都自带 `FORBIDDEN_KEYS` 守卫；敌人弹命中半径仍是硬编码 `hit_radius = 18.0`；
   `bullet_visual` 只被允许作为**表现层**字段。

---

## 2. CHANGE-LOG v2 条目一览（详版见 `ROGUE-CONTRACTS.md`）

| 条目 | 来源轮次 | 内容 | 状态 | 影响的既有契约 |
| --- | --- | --- | --- | --- |
| v2-1 | R4 | `RogueGraph` 追加 `LEGACY_ROUTE`、`legacy_areas(g)`、`from_route(route, floor_index=1)` | **已生效** | §5 追加，不改冻结签名 |
| v2-2 | R2 提案 / 顶层裁决 / R5 落地 | `raid` 第 13 键 `variants_seen: Array[String] = []`（本局变数去重） | **已生效** | §2 的"12 键"→**13 键** |
| v2-3 | R8 提案 / R6 落地 | 子弹字典表现层字段 `bullet_visual: float`（**严禁**进入判定几何） | **部分生效** | §1/§9 的"判定不变"字段级落地 |
| v2-4 | R8 | `RogueVariants` 追加 12 个纯函数；`bullet_size` 合成下限锁 `0.00`；`_mod_cache` 记忆化 | **已生效（模块内）** | §5 追加；§6 的 rng 描述见 v2-11 |
| v2-5 | R9 + 顶层裁决 | `raid.pending_event` 追加 `"id": String` | **已生效** | §2 的 `pending_event` 形状 |
| v2-6 | R9 提案 + 顶层裁决 | 诅咒接入既有减伤池＝**同池相减**（`defense_penalty`），**不新开乘数** | **计划中·未生效** | §5 `damage_taken_scale` 的取用方式 |
| v2-7 | R9 | 登记 2 个新 `s.rng` 消耗点（`RogueCurses.roll`、`RogueEvents.roll_offer`，各恒定 1 次） | **已落地·待接线** | §6.2 配方扩充 |
| v2-8 | R3 | `profile.apply_data` 改为"任意 Dictionary 尽力导入 + `version` 强制归一为 1"；新增 `sanitize_growth()` | **已生效** | **取代 §4.1 的"整段跳过"描述** |
| v2-9 | R12 | `RogueGrowth`：14 节点、`cost*(level+1)`、满树 7305、`power()` 恰好 4 键、新增 `ash_bonus` 键 | **已落地·待接线** | §5 追加；§4 `ashes`/`growth` 语义细化 |
| v2-10 | R10 | `RogueRooms`：forge/gamble/mirror 三房行为数据层 | **进行中·provisional** | §7 房间类型的玩法层 |
| v2-11 | 顶层裁决 | `RogueVariants.roll()` 改用**局部 RNG**（消除对 `s.rng` 序列的位移） | **计划中·未生效** | §6.2 配方；执行者＝R8 |
| v2-12 | R1b | 所有权表补充（W6/W7/W8 的文件清单） | **已生效** | **取代 §8 的 F、G 两行** |
| v2-13 | R1b | 新纪律：改过 `roguelike.gd`/`session.gd` 后**立刻**跑 `--check-only` | **新增纪律** | §9 通用纪律追加 |
| v2-14 | R1b | 接线状态总表（源码实测） | 记录 | — |
| v2-15 | R1b | 交付记录与源码的不一致清单 | 记录 | — |

## 3. CHANGE-LOG v3 条目一览

| 条目 | 来源轮次 | 内容 | 状态 |
| --- | --- | --- | --- |
| v3-1 | R11 提案 + 顶层裁决 | `profile.data` 新增第 3 个顶层键 `daily`（`{}`，键 `"daily:YYYY-MM-DD"`，值 `{"best":int,"plays":int}`）；**`version` 仍为 1** | **计划中·未生效** |
| v3-2 | 顶层裁决 | 每日挑战**统一 UTC**（`utc_today()`/`global_daily_seed()`）+ **房主随 `begin` 下发**；`0` 表示随机局，UI 必须非零校验 | **新增冻结** |
| v3-3 | 顶层裁决 | 每日记录**只能在 `settle()` 写一次**（与灰烬共用 `ended` 守卫） | **新增冻结** |
| v3-4 | R1b | 种子分享串格式冻结：`CT-` + 8 位大写十六进制 + `-` + 1 位校验字符（**与早期"`CT-XXXX-XXXX`"描述不同**） | **冻结规格** |
| v3-5 | R1b | 待执行清单汇总（13 项，含认领轮次与目标文件） | 待认领 |

---

## 4. 顶层调度已裁决事项（裁决人＝顶层调度；来源＝各轮提案）

| # | 裁决 | 提案方 | 状态 | 备注 |
| --- | --- | --- | --- | --- |
| A1 | 新增 `raid.variants_seen` 为第 13 键 | R2 | 已落地 | R5 实施（`roguelike.gd:48-50,180-182`） |
| A2 | 新增表现层字段 `bullet_visual`，**判定几何零变化** | R8 | 部分落地 | 产出面见 v2-15 第 4 条 |
| A3 | `pending_event` 追加 `"id"` 键 | R9 | 已落地 | `rogue_events.gd:119` |
| A4 | 诅咒走 `defense_penalty` **同池相减**（否掉"再乘一层"） | R9 | 未接线 | 公式见契约 v2-6 |
| A5 | 登记 2 个新 `s.rng` 消耗点（房间分支内） | R9 | 待接线 | 不破坏 §6.2 的 `enter()` 顺序 |
| A6 | `RogueVariants.roll()` 改局部 RNG（还原 progression 至 505/39） | R2 建议 | 未执行 | 执行者＝R8，见 v2-11 |
| A7 | `profile.data` 第 3 键 `daily` | R11 | 未接线 | 键/值形状见 v3-1 |
| A8 | 每日挑战日期口径**统一 UTC** + 房主下发 | R11 | 冻结 | 见 v3-2 |
| A9 | 每日记录只在 `settle()` 写一次 | R11 | 冻结 | 见 v3-3 |
| A10 | **接受** R3 对 `apply_data` 的语义改写（不再"整段跳过"，改为"尽力导入 + version 归一"） | R3 | 已落地 | 代价：将来真引入 v2 格式会被按 v1 读回；权衡后优于"静默丢档" |
| A11 | **接受** `RogueGrowth` 新增效果键 `ash_bonus`（仓库无同义词） | R12 | 已落地 | 只影响结算产出 |

---

## 5. 交付记录与源码的不一致（R1b 逐项核对结果）

| # | 不一致 | 事实 | 影响 |
| --- | --- | --- | --- |
| 1 | `output/R9-ROGUE-CURSES-EVENTS.md:13,89` 写"9 个事件房（**22** 个选项）" | 其 §5.2 自身明细 `3/3/3/3/2/3/3/3/2` 合计 **25**；源码 `rogue_events.gd:20-64` 实测 **25** 个 option | 文档数字错；测试只断言 `2 ≤ options ≤ 3`，故仍全绿 |
| 2 | R10 无交付记录 | `scripts/rogue_rooms.gd` 已存在（396 行），但 `output/R10-NEW-ROOMS.md` 不存在 | 该模块签名视为 **provisional** |
| 3 | class cache 再次陈旧 | `.godot/global_script_class_cache.cfg` 仅登记 4 个新类（RogueCurses/RogueEvents/RogueGraph/RogueVariants）；**RogueDaily/RogueGrowth/RogueRooms 未登记** | 裸类名引用会解析失败；当前所有消费方都是 `preload`，暂无故障 |
| 4 | `bullet_visual` 产出面与 R8 待接线清单不符 | R8 指向 `session.gd:3346`（普通远程敌人弹），实际落在 `rogue_combat.gd:355` 与 `boss_choreography.gd:498` | **普通敌人弹幕仍无该字段** |
| 5 | `modifiers_of()` 有隐藏状态 | `static var _mod_cache` 记忆化，交付记录未强调 | 后续轮次不得假设它无状态 |

**核对一致、仅供追溯的关键数字**：`RogueVariants` 18 条变数、`RogueCurses` 10 条（CU01–CU10）、
`RogueEvents` 9 个事件、`RogueGrowth` 14 节点且 `total_cost()=7305`（R1b 用 `cost*max*(max+1)/2` 算术复核通过）、
`rogue_wiring` 117/0、`rogue_variants` 495/0、`rogue_curses` 218/0、`rogue_events` 484/0、
`rogue_daily` 132/0、`rogue_growth` 6886/0、`rogue_graph` 83608/0。

---

## 6. 接线状态总表（2026-10-05 源码实测）

| 模块 / 字段 | 已落地的消费者 | 状态 |
| --- | --- | --- |
| `RogueGraph` | `roguelike.gd:7,89,91,99-114,123,136,176,716` | **已生效**（节点图已接管推进） |
| `raid.variants_seen` | `roguelike.gd:48-50,180-182`；只读 `rogue_variants.gd:274` | **已生效** |
| `s.rogue_graph`（非快照字段） | `session.gd:77` + `roguelike.gd` 多处 | **已生效**（R2 有"不进快照"硬断言） |
| `profile.ashes` / `profile.growth` | `profile.gd:10,55,122-133,144` | **已生效（存档层）**，尚无战斗/结算消费 |
| `RogueVariants` | `roguelike.gd`（roll + variants_seen）、`rogue_combat.gd:96` | **部分生效**：敌人侧 `enemy_hp`/`enemy_speed`/弹速已接；玩家侧与经济钩子、普通弹 `bullet_size` 未接 |
| `bullet_visual` | 产出：`rogue_combat.gd:355`、`boss_choreography.gd:498`；**消费端：无** | **部分生效**（数值已备、画面未变） |
| `RogueCurses` | 无 | **已落地·待接线** |
| `RogueEvents` | 无 | **已落地·待接线** |
| `RogueGrowth` | 无 | **已落地·待接线** |
| `RogueDaily` | 无 | **已落地·待接线** |
| `RogueRooms` | 无 | **进行中** |
| `profile.daily` | `profile.gd` 中不存在该键 | **未接线** |
| C3 ① region key | `rogue_map.gd:53-58` | **已生效** |
| C3 ② 非战斗房谓词 | `roguelike.gd:29,188,222` | **已生效** |

---

## 7. 流程教训（已固化进契约 v2-13）

- **一个解析错误会连带全仓库测试变红**：R5 在飞时 `roguelike.gd:176` 的 `var fresh := ... or s.rogue_graph.is_empty()`
  因 Variant 类型推断失败报 `Parse Error`，把 `session.gd` 拖成 `Compilation failed`，
  导致 `rogue_wiring`/`rogue_variants`/`rogue_curses`/`rogue_events`/`rogue_build_growth`/`rogue_build_system`/`systems`/`expedition` **全线失败**。
  R1b 复核：该行**现已修正**（`var fresh: bool = ...`）。
- **应对纪律**：① 改过 `roguelike.gd`/`session.gd` 后立刻 `--check-only`；
  ② 门禁**只比 failures、不比 checks**（并发写者会让 checks 计数浮动）；
  ③ "测试全线编译失败"先查脚本解析错误，别当玩法回归。
- **所有权仲裁记录**：R2 曾误建 `scripts/rogue_variants.gd`（属 W6/R8），顶层仲裁后 R2 停写、不回退不覆盖，
  该文件最终内容由 R8 交付；R2 已声明未覆盖。

---

## 8. 未决 / 遗留（R1b 判定，需顶层或后续轮次处理）

1. **`rogue_build_progression` 的 39 项陈旧断言**：属"每层 5 区年代"口径，由 R5 移植到新口径（目标 failures=0）；
   该测试在并发写者期间出现过 505/39 → 533/41 的漂移，且已确证是 §6.2 那一次 `s.rng` 抽取造成的序列位移（见 v2-11）。
2. **`rogue_build_rules` / `rogue_build_pack` 不可用**：依赖未提交的 `assets/rogue/build/`（`ATLAS/manifest` 为空），
   必须**豁免**而非"待修绿"；恢复素材前它们不能当门禁（C5）。
3. **服务端不校验 `ashes`/`growth`**：手改客户端可上传离谱灰烬；是否加校验属 W5，本轮未改（v2-8 末条）。
4. **G 集合（W7）仍在被弹幕视觉任务独占**：所有"按 `bullet_visual` 放大绘制"的改动必须等它释放所有权或并入其后续轮次。
5. **v2-10（`RogueRooms`）**：R10 交付记录落盘后需回填最终签名并复核三种赌法期望 ≤ 100%。

---

## 9. 本轮的验证方式（可复现）

- **源码核对**：R1b 直接读取并 grep 了 `scripts/rogue_{graph,variants,curses,events,daily,growth,rooms}.gd`、
  `roguelike.gd`、`session.gd`、`profile.gd`、`rogue_map.gd`、`rogue_combat.gd`、`boss_choreography.gd`
  与 `.godot/global_script_class_cache.cfg`，逐条核对导出函数、常量、默认值与消费者（见 §5、§6）。
- **`total_cost()=7305`** 用 `Σ cost*max*(max+1)/2` 逐节点算术复核（14 节点，与源码 `cost_for()` 一致）。
- **未跑引擎**：本轮为纯文档轮次，且并发轮次正在反复运行 `--script` 测试，R1b 不与其争用引擎；
  所有数字均标注来源（R1b 实测／各轮上报）。
- **写入面自证**：`output/ROGUE-CONTRACTS.md` 只做**追加**（v1 原文未删改），另新建本文件；
  用 `git status --porcelain` 复核未触碰任何源码/测试（见下）。

```
$ git status --porcelain -- scripts tests tools project.godot server resources
（应无 output/*.md 以外的改动属于本轮；源码改动均来自其它并发轮次）
```
