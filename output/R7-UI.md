# R7 · 魔境 UI / HUD 与入口界面（交付记录）

- **轮次**：R7（肉鸽拓展计划，契约 CHANGE-LOG v2/v3）
- **日期**：2026-10-05 · 工作副本 `D:\game\CrimsonTide-godot`
- **引擎**：`Godot_v4.7.2-stable_win64_console.exe`（不在 PATH）

## 1. 写入面

| 文件 | 状态 | 说明 |
| --- | --- | --- |
| `scripts/rogue_ui_model.gd` | **新建** | 无窗口可测的 view-model：HUD 文案、事件房视图、成长树行、种子/每日助手、冻结动作名与 payload |
| `scripts/main.gd` | 修改 `+237 / -7` | HUD 五行、幽暗异事面板、种子页、成长树弹窗、旧口径文案修正 |
| `tests/rogue_ui.gd` | **新建** | 无窗口验收：**160 checks / 0 failures**（exit 0） |
| `tests/rogue_ui_visual.gd` | **新建** | 真实窗口截图：**5 captures / 13 checks / 0 failures**（exit 0） |
| `build/rogue-ui-*.png` | 产物 | 5 张截图（在 `.gitignore` 的 `build/` 下，磁盘可见） |

**未触碰**：`session.gd`、`roguelike.gd`（R5 正在写）、`profile.gd`（R3）、`rogue_combat.gd` / `boss_choreography.gd`（R6）、G 集合（W7 弹幕任务）、以及全部 `scripts/rogue_*.gd` 数据层模块（只读调用）。

## 2. main.gd 改动锚点

| 行 | 内容 |
| --- | --- |
| 46-48 | `RogueUi` / `RogueGrowth` / `RogueGraph` 三个 `preload`（不写裸类名：class cache 对 `RogueDaily/RogueGrowth/RogueRooms` 仍是陈旧状态） |
| 67-71 | 新增状态：`rogue_seed_pending` / `rogue_daily_pending` / `rogue_seed_field` / `rogue_event_buttons` / `rogue_growth_buttons` |
| 1193-1202 | `on_started()` 魔境分支新增 5 个具名 HUD 标签：`RogueVariant` / `RogueCurses` / `RogueAsh` / `RogueNode` / `RogueSeedLine`（带 `hud.has(...)` 守卫，非魔境局不创建） |
| 1594 | 顶栏层/区进度改用 `RogueUi.floor_line(..., roguelike.depth_count(session))`——**分母不再是写死的 `AREAS_PER_FLOOR=7`**（节点图每层 7~10 个房间，旧写法会出现「第 8 / 7 区」） |
| 1599-1603 | `update_hud()` 魔境分支刷新 5 行 HUD |
| 3386-3397 | 出发页新增两个入口按钮：`RogueSeedButton`（文字随所选种子变化）与 `RogueGrowthButton` |
| 3376-3380 | 出发页文案改为节点图口径（原「每层五区」是 R5 之前的旧设计） |
| 3418-3432 | `start_rogue()`：把 `rogue_seed` / `rogue_daily` 并入 `config()` payload，并在房主本地用 `session.launch(false, seed)` 指定种子 |
| 3114 / 3638-3645 | 结算面板「已完成 %d / 25 区」→ 分母由 `rogue_total_nodes()` 按本局种子逐层求和算出（35~50，不再是写死的 25） |
| 3457 / 3490-3521 | `update_rogue_hud()` 增加事件房分支 + `rogue_event_panel()` |
| 3523-3613 | `show_rogue_seed_page()` / `choose_daily_seed()` / `apply_custom_seed()` / `copy_seed_text()` / `rogue_launch_seed()` / `show_growth_tree()` / `buy_growth_node()` |

## 3. 冻结动作契约与**必须由 W1 实现的 handler**

统一走 `session.action()` → `session.perform()`（`session.gd:1540` 把 `rogue_*` 转发给 `roguelike.choose()`）。`roguelike.choose()` 在 `roguelike.gd:681` 已有 `payload.revision != raid.revision → return` 的重放守卫。

| 动作名 | payload（UI 实际发出的形状） | 现状 | W1 必须做的 |
| --- | --- | --- | --- |
| `rogue_event` | `{"index": int, "revision": int}` | `choose()` 里**没有**分支 → 命中 revision 后静默无操作（安全） | 在 revision 守卫**之后**加：`elif kind==RogueUi.ACTION_EVENT: if not RogueEvents.matches_revision(s,payload.revision): return; RogueEvents.apply(s,p,int(payload.index))` |
| `rogue_growth` | `{"id": String, "applied": true, "revision": int}` | 同上（静默无操作） | 收到后**只做审计/记录**：`applied:true` 表示客户端已本地扣费落盘，**绝不能再扣一次** |
| `rogue_seed` | `{"text": String, "revision": int}` | 同上（静默无操作） | 见 §4 的口径说明 |
| `rogue_daily` | `{"daily": bool, "revision": int}` | 同上（静默无操作） | 见 §4 的口径说明 |

**未知动作安全性（已实测）**：`tests/rogue_ui.gd` 断言 —— 过期 revision 不改变 `raid.revision` / `pending_event` / `rogue_gold`；未实现的动作不改变 revision；结算后 `hp>=1`、`rogue_gold>=0`。未知 kind 会穿过所有 `elif` 落到函数尾，**不崩、不污染状态**。

## 4. 与派单的**口径偏差**（需要契约记一笔）

1. **`rogue_seed` / `rogue_daily` 只能是「出发前」意图，不能是局内 `choose()` 动作。**
   `roguelike.choose()` 第 667 行开头就是 `if p.status!="active" or not s.running or s.raid.ended: return`，而 `session.perform()` 也要求 `running` —— 选种子发生在**开局之前**，此时发这两个动作必然是空操作。因此 R7 的实现是：
   - 种子/每日意图并入 `config()` 的 `rogue_seed` / `rogue_daily` 两个键（`start_rogue()` 里）；
   - 房主本地直接 `session.launch(false, seed)`（`session.gd:1386` 是唯一把种子写进 `seed_value` 的地方）；
   - **待 W1 补的缺口**：非房主 / 联机路径。当前非房主点「出发」走 `request_launch()`（不带种子）并提示「指定种子需要由房主发起」；若要队友也能用队长选的种子，需要在 `launch()/request_launch()` 或 `begin` RPC 上开一个从 `local_config` 读种子的入口。**种子串一旦发布不可更改**（`CT-` + 8 位十六进制 + 校验位）。
2. **`rogue_growth` 的 `applied: true`。** 灰烬与成长树是**本地档案**数据，且本局敌人倍率在 `reset()` 时已固定，局内购买不影响当前局。所以 UI 先本地 `RogueGrowth.buy()` + `save_profile()`（立即可用），再把这笔购买作为审计事件发出；payload 里的 `applied: true` 是给房主的硬约束。
3. **种子 0 的处理**：`session.gd:1386` 用 `0` 表示随机局，所以 UI 对空值 / `0` / 负数 / 越界 / 乱码一律**提示并拒绝出发**（`RogueUi.seed_error()`），绝不静默变随机局。已断言。

## 5. 验收（原始输出）

```
--check-only --script scripts/main.gd                                   exit=0
--headless --script tests/rogue_ui.gd              ROGUE UI: 160 checks, 0 failures   exit=0
--script tests/rogue_ui_visual.gd（真实窗口）      ROGUE UI VISUAL: 5 captures, 13 checks, 0 failures   exit=0
```

回归（**门禁只比 failures**；均为原始输出行）：

| 测试 | 基线 | 本轮 | 判定 |
| --- | --- | --- | --- |
| systems | 10812/0 | 10812/**0** | 一致 |
| expedition | 79/0 | 79/**0** | 一致 |
| rogue_build_growth | 4066/0 | 4066/**0**（样本 `[213,500]`） | 一致 |
| rogue_build_system | 440/0 | 440/**0** | 一致 |
| rogue_wiring | 117/0（R2） | 123/**0** | R5 已把 2 条过期断言改到新口径 |
| rogue_graph | 83608/0 | 83608/**0** | 一致 |
| rogue_variants | 495/0 | 495/**0** | 一致 |
| rogue_curses | 218/0 | 218/**0** | 一致 |
| rogue_events | 484/0 | 484/**0** | 一致 |
| rogue_growth | 6886/0 | 6886/**0** | 一致 |
| rogue_daily | 132/0 | 132/**0** | 一致 |
| rogue_profile_migration | 113/0 | 113/**0** | 一致 |
| rogue_rooms（R10） | 1299/0 | 1299/**0** | 一致 |
| rogue_boss_phase2（R6） | 401/0 | 401/**0** | 一致 |
| combat | 78/0 | 78/**0** | 一致 |
| enemy_body | 379/0 | 379/**0** | 一致 |
| boss_tactics | 186/**1** | 186/**1** | 既存红，未增加 |
| rogue_build_pack | 豁免（素材缺失） | exit=1，唯一 ERROR 仍是 `Missing exported icon W001` | main.tscn 实例化与 `on_started` 全程跑通，未引入新错 |

**新增失败 = 0。** 未把 `rogue_build_progression` / `roguelike_seven_rooms` / `roguelike_routes` 当门禁（R5 正在改口径）。

## 6. 截图

| 文件 | 内容 |
| --- | --- |
| `build/rogue-ui-hud.png` | 局内 HUD：深渊变数（雾障）、4 条诅咒满位、灰烬本局/累计、路线（第 3 层 · 深度 4 · 诅咒回廊）、分享种子 |
| `build/rogue-ui-event.png` | 幽暗异事面板：3 个选项 + 门槛文案（需生命 ≥ 20% / 需诅咒位空余）+ 选择按钮 |
| `build/rogue-ui-growth.png` | 灰烬成长树：14 节点双列，等级/上限、每级效果、价格或「需要前置节点」原因 |
| `build/rogue-ui-seed.png` | 种子 · 每日挑战页：UTC 日期、每日种子串、分享串输入框、使用/复制按钮、当前选择 |
| `build/rogue-ui-setup.png` | 魔境出发页：底部四个入口（返回营地 / 种子 · 每日挑战 / 灰烬成长树 / 全队闯关 · 出发） |

## 7. 已知外观问题（不阻塞）

1. **瞬时 toast 带**（`toast.position.y=157`）会短暂压到居中弹窗的标题行（成长树弹窗）。事件面板已从 y=150 下移到 y=176 规避；成长树弹窗的标题仍在 toast 带内，但 toast 只显示约 2.5 秒。若要彻底消除，需要给弹窗一个避开 toast 带的顶边距（属布局重构，留给后续轮次）。
2. **HUD 右列宽度只有 252px**：深渊变数长文案会折成 2 行；4 条诅咒满位时是「1 行表头 + 4 行」共 5 行，实测在 12px 字号、88px 框高内能完整显示（截图已验），但更长的诅咒描述会被 `clip_text` 截断。
3. `rogue_ui_model.gd` **故意不写 `class_name`**：`.godot` class cache 对 `RogueDaily/RogueGrowth/RogueRooms/RogueUiModel` 仍是陈旧状态，裸类名会在解析期失败。**后续轮次请一律 `preload`。**

## 8. 给后续轮次的钩子

- HUD 新增的 5 个标签都有 `name`（`RogueVariant` / `RogueCurses` / `RogueAsh` / `RogueNode` / `RogueSeedLine`），事件选项按钮是 `RogueEventOption%d`，成长树按钮是 `GrowthBuy_<节点id>`，种子页控件 `RogueSeedInput` / `RogueSeedApply` / `RogueSeedCopy` / `RogueDailyPick` / `RogueSeedClear` —— 截图与自动化验收可以直接按名字找节点。
- `WH1` 接线完成后，`tests/rogue_ui.gd` 里那条「未实现 handler 是安全空操作」的分支断言会自动走 `consumed` 一侧，不需要改测试。
