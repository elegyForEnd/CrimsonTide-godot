# R7b · 三个专属房间的界面 + profile 通道接通

用户诉求：**不需要测试，直接把功能做好，他自己测**。所以只做了 `--check-only` + 一次真实窗口截图，
没有跑大回归集合。

## 1. 三个新房间现在有界面了

改动前：`forge` / `gamble` / `mirror` 三种房间在 `main.gd` 里**没有任何面板**，进房点不了
（`roguelike.gd` 的 `open_room()` 已经写好了 `pending_forge` / `pending_gamble` / `mirror_state`，
`choose()` 也已经实现了三个动作，缺的只有界面）。

| 文件 | 内容 |
|---|---|
| `scripts/rogue_room_ui.gd`（**新建**） | 房间视图模型：`handled/action_for/room_name/title/body/context_of/rows/unavailable_reason/payload/mirror_payload/signature/footer`。不写 `class_name`（class cache 对新模块仍是陈旧的），一律 `preload` |
| `scripts/main.gd:46-50`（新增 5 行） | `const RogueRoomUi := preload(...)` |
| `scripts/main.gd:70-71` | `var rogue_room_buttons: Array = []` |
| `scripts/main.gd:3443-3452` | HUD 重建签名加上 `room:<kind>:<revision>:<金币>:<锻造>:<灰烬>:<阶位>:<镜像是否 active>`，房间种类变化一定会重画 |
| `scripts/main.gd:3462-3467` | 面板派发：事件房 → 专属房 → 游商；专属房画完即 `return`，不会和游商面板叠在一起 |
| `scripts/main.gd:3524-3562`（新增 `rogue_room_panel()`） | 面板本体：标题、说明、`魔晶 / 锻造 +N / 本局灰烬` 一行、每项服务一行（名称 + 描述 + 价格 + 不可用原因）、底部提示行、非 active 玩家提示 |

### 动作契约（名字由顶层冻结，未改）
- `rogue_forge` / `rogue_gamble`：payload `{"index":int,"revision":int}`
- `rogue_mirror`：payload `{"revision":int}`（镜像只有"应战 / 结算"两次点击语义，不需要 index）
- 三者都走 `session.action()`；`roguelike.choose()`（`roguelike.gd:779`）先比对 `revision` 再动手，
  所以过期点击会被丢弃而不是重放。
- 按钮命名：`RogueRoomOption0..N`（沿用 R7 的 `RogueEventOption%d` 风格，便于以后按名查找）。

### 界面细节（截图可核）
- 铁匠铺四项：熔炼 1 点 / 熔炼 3 点套餐 / 当场锻打 +1 级 / 转移锻造（免费）。
  钱不够时**按钮禁用并在描述里写出原因**（截图里 180 魔晶 < 183 套餐，显示「（魔晶不足（需 183））」）。
- 赌徒三样：掷币押魔晶（胜率 48% · 期望回报 96%）、押装备升阶（胜率 40% · 期望 -0.20 阶）、押灰烬
  （胜率 32% · 期望回报 96%）——胜率与期望都印在描述里，不藏赔率。
- 镜像：第一次点击显示「镜中挑战」并给出预估胜率与奖励；`mirror_state.active` 之后同一位置变成
  「结算镜像决斗」；`p.rogue_mirror_used` 之后禁用并写「本局已经挑战过镜像」。
- 面板优先使用 `raid.pending_forge.offers` / `pending_gamble.stake`（那是结算时真正要比对的 revision），
  拿不到才按 context 现算，保证面板永不空白。

## 2. profile 通道：灰烬不入账 + 成长树起始加成是空操作

`session.gd:115` 的 `profile_data()` 读的是 `get_meta("profile_data")`，而 `main.gd` **从未把 profile 交给 session**，
于是：`RogueGrowth.grant()` 拿不到存档（灰烬只涨在 `p.rogue_ash_run`，HUD 看着对、实际不落盘），
`roguelike.reset()` 用空 growth 表缩放起始金币/刷新券（买过的节点完全无效）。

| 位置 | 改动 |
|---|---|
| `scripts/main.gd:3405-3413`（新增 `attach_profile()`） | `session.set_meta("profile_data",profile.data)`；只挂**数据字典**，不挂 `Profile` 对象，所以 session 不会自己写文件 |
| `scripts/main.gd:3380` | `show_rogue_setup()` 进魔境就挂一次 |
| `scripts/main.gd:3430` | `start_rogue()` 在 `configure/launch` 之前再挂一次 |
| `scripts/main.gd:3112-3116` | `on_finished()` 在魔境结算后再 `save_profile()` 一次（灰烬与每日记录真的落盘，`version` 仍为 1） |

## 3. 验证（轻量，按用户要求）

```
--check-only scripts/rogue_room_ui.gd  → EXIT=0
--check-only scripts/main.gd           → EXIT=0
--check-only scripts/session.gd        → EXIT=0

tests/rogue_room_ui.gd          ROGUE ROOM UI: 32 checks, 0 failures   EXIT=0
tests/rogue_room_ui_visual.gd   ROGUE ROOM UI VISUAL: 4 captures, 9 checks, 0 failures  EXIT=0
tests/rogue_ui.gd（相邻既有用例）  ROGUE UI: 161 checks, 0 failures      EXIT=0
```

`tests/rogue_room_ui.gd` 里最关键的三条：
- `the ash is banked through the profile channel, not only into p.rogue_ash_run`；
- `the growth tree's starting gold actually applies now (it used to be a silent no-op)`——用
  `Growth.buy()` 真买 `coin_purse` 再 `reset()`，比较 `p.rogue_gold` 与空 growth 的差值等于 `power().start_coins`；
- `the forge payload carries the index plus the raid revision` / `the quoted revision is the one the guard will compare`。

截图（真实窗口，`res://build/`）：
`rogue-room-forge.png` · `rogue-room-gamble.png` · `rogue-room-mirror.png` · `rogue-room-mirror-active.png`

## 4. 没做 / 已知局限
- 没跑大回归集合（用户明确不需要）；只跑了相邻的 `rogue_ui.gd` 做冒烟。
- 三个房间的**动作本身**由 `roguelike.choose()` 实现，本轮只做界面 + payload；端到端"点一下就真扣钱"
  需要对着真实局内点击，我没有在无头环境里模拟点击（但 payload 与 revision 与守卫逐字对齐，并有断言）。
- 铁匠铺"转移锻造"是免费项，按钮写「确认」而不是价格，这是 0 成本的既有语义。
