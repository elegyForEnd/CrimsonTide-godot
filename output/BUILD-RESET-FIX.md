# `Build.reset()` 覆盖调用方配置 → `tests/roguelike.gd` TIMEOUT（已修）

工作目录 `D:\game\CrimsonTide-godot`（Godot 4.7.2，引擎在仓库根，**不在 PATH**；本机无 `pwsh`）。

## 1. 修实现：`scripts/rogue_build.gd`

原文（`reset()` 的合并字面量结尾）：

```gdscript
"flask_refills":0,"flask_combat_awards":0,"flask_elite_award":false,"build_vitality_healed":0,"flask_shop_floor":0,"build_respec_floor":0,"rogue_rerolls":3},true)
```

`p.merge({...}, true)` 的 `overwrite=true` 会把调用方**显式配置**的 `rogue_rerolls` 抹成 `3`。改动：

- 从字面量里删掉 `"rogue_rerolls":3`；
- 合并之后补一行 `if not p.has("rogue_rerolls"): p["rogue_rerolls"]=3`（只在键缺失时给默认值）。

影响链（这才是真 bug 的全貌）：

| 位置 | 作用 |
|---|---|
| `session.gd:320` | 把营地配置写进 `player["rogue_rerolls"]`（`clampi(config, 0, 5)`） |
| `roguelike.gd:127` | 再加成长树 `RogueGrowth.power().start_rerolls` |
| `roguelike.gd:133` | `Build.reset(s,p)` ← 原文在这里把上面两样**一起抹成 3** |

所以"买了刷新卡没用"和"成长树的起始刷新券没用"是同一个 bug。

`Build.reset` 的调用点（全仓库仅两处）：

1. `scripts/roguelike.gd:133`（真实开局）→ 现在保留配置值 + 成长树加成；
2. `tests/rogue_build_growth.gd:27`（`Build.reset(s,ally)`，ally 上没有该键）→ 仍取默认 3，行为不变。

## 2. 修挂死：`tests/roguelike.gd`

### 根因（三层叠加）

1. `Build.reset` 覆盖 → 原 `:21` 的 `p.weapon==1 and p.rogue_rerolls==2` 必败；
2. `launch()` 结束停在 `rogue_prepare`（开局武器三选一），测试从不派发它 → `roguelike.tick()` 里的
   "所有人选完才切 `rogue_combat`"永不满足 → 循环落到 `else: check(false,"Unexpected phase"); break`；
3. `s.results[1]` 越界抛运行期错误 → `run()` 被中断 → **没有任何 `quit()`** → SceneTree 空转到被 harness 杀掉。

另外老驱动 `tests/rogue_reward_flow.gd:claim()` 内部是 `while s.raid.phase=="rogue_reward"`，它在下面这条
链路上会**无限空转**（探针 `build/fix-probe4.gd` 逐步落盘实测，角色停在 `stash=12`）：

```
rogue_selection_take → apply_offer → equip()
  → p.rogue_stash.size()>=12 → return false
  → selection_action 直接 return，**不清空 p.rogue_selection**
  → loot_interact 首行 "有 pending 选择就不许拾取" → 地上那只空报价 drop 永远捡不到
  → finish_rewards 要求"没有任何空报价 drop" → 房间永久出不去
```

（玩家侧有逃生口：`scripts/rogue_reward_ui.gd:192` 的"丢弃"按钮走 `rogue_selection_drop`，会把报价放回地面；
`apply_offer` 的失败还有一条 `s.message.emit("备用行囊已满：先分享或丢弃一件装备")`。）

### 改动（每处都留痕）

| # | 原文 | 新写法 | 理由 |
|---|---|---|---|
| 1 | `func run()` 直接是测试体，结尾才 `quit()` | `func run()` 只 `await _body()` + `check(completed,…)` + `quit()`；测试体改名 `_body()`，最后一句置 `completed=true` | 运行期错误中断 `_body()` 后，`await` 仍会恢复：没有这个标志，"只跑了 15 条"会被报成 `0 failures` |
| 2 | `while s.running:` | 加 `steps` 计数，超过 **600** 判红并 break，每 50 步打印进度 | 该循环不向引擎让帧，`--quit-after` 对它无效 |
| 3 | （无 `rogue_prepare` 分支） | 新增分支：取走 `category=="starter"` 的三选一，再 `s.simulate(0.01)` 让 tick 切到 `rogue_combat` | `launch()` 结束就是 `rogue_prepare`；`tick()` 需要一帧才推进 |
| 4 | `p.weapon==1` | `str(p.equipped.get("weapon",{}).get("build_id",""))=="W001"` | 装备后 `p.weapon` 是 **Content 域**（`WEAPON_BASE+index`=600+i），Catalog 索引 `==1` 永不成立；`build_id` 表达同一意图且稳定 |
| 5 | `var first_packet: bool=not s.raid.reward_chest.opened` | `not stale_checked and not bool(s.raid.get("reward_chest",{}).get("opened",false))` | 非战斗房（圣坛等）没有宝箱，直接访问会抛错并中断整个 `_body()` |
| 6 | `preload(...).claim(s,p)` | 有界 24 步收尾：`pick` → 取走 → 取不走就 `rogue_selection_drop` | `claim()` 的 `while` 会无限空转（见根因链） |
| 7 | 商店 `check(p.rogue_gold==before-50,…)` | 读**该格报价** `p.rogue_shop_offers[i].price`，并选第一个"买得起且未售出"的格子 | `roll_offers()` 现在按 `maxi(1, scale_int(65+10*floor, 1+shop_price))` 定价（`roguelike.gd:709`），不再固定 50 |
| 8 | 商店断言前无夹具 | `if p.rogue_stash.size()>=12: p.rogue_stash.pop_back()` | 行囊满时 `equip()` 会拒绝装备类商品，计价断言会被"满仓拒绝"掩盖（等同于玩家分享/丢弃一件备用） |
| 9 | 死亡：`s.simulate(0.1)` | `for step in 40: s.simulate(0.1)` | `session.gd:2783-2788`：魔境要"没人站着持续 **≥3 秒**"才 `settle()` |
| 10 | 死亡前不派发开局选择 | 先取走 starter 再 `simulate` | 否则死亡发生在 `rogue_prepare`，`s.running` 不会翻转 |

**结果**：`ROGUELIKE 153 checks / 0 failures`，exit 0，**约 1 秒**（原来是 TIMEOUT）。

## 3. 顺手修的工具与兜底

- `tests/rogue_reward_flow.gd:pick()`：`s.raid.reward_chest.opened` / `.p` 直接访问 → 安全取值。
  非战斗房没有宝箱时原文会抛错并**提前返回**（外面只表现为"没捡到东西"）。
- `tests/rogue_inventory.gd`：加同一套 `quit()` 兜底（`completed` 标志）。它原来因 `:72`
  （`p.rogue_boons.rogue_damage`）的运行期错误**挂死**；现在 8 秒内以 `18 checks / 10 failures`
  退出（10 = 既存 9 条 + 新增的"body 跑到底"1 条），挂死变成可观察的红。
- `tests/camp_modes.gd:32`：`players[1].weapon==1` → `equipped.weapon.build_id=="W001"`（同域问题）。
  现在 `10 checks / 1 failure`（原来 2 条）。
- `tests/rogue_hooks_roguelike.gd`：把"`Build.reset` 会把刷新卡强制成 3"的过时注释改成事实（纯注释）。

## 4. 回归（`--headless --path . --quit-after 20000 --script`，failures 口径）

| 用例 | 结果 |
|---|---|
| `roguelike` | **153 / 0**（原 TIMEOUT） |
| `rogue_build_system` | 440 / 0 |
| `rogue_build_growth` | 4066 / 0（宝箱样本 `[205,499]`，在既有宽区间内） |
| `rogue_build_progression` | 727 / 0 |
| `systems` | 10812 / 0 |
| `rogue_wiring` | 122 / 0 |
| `rogue_hooks_roguelike` | 85 / 0 |
| `camp_modes` | 10 / **1**（见 §5） |
| `rogue_inventory` | 18 / **10**（既存夹具过期 + 1 条"body 跑到底"） |
| `rogue_chest_rewards` | 3 条失败（既存，未动） |

以上 failures 相对修复前的基线**均未增加**；`roguelike` 从挂死变成全绿。

## 5. 还没做的（建议下一轮）

1. `tests/camp_modes.gd:33` 的 `profile.data.coins==100`：该用例只设 `rogue_cards/rogue_weapon`，
   **从不设** `main.gd:3434` 的 `rogue_pending_cost`，所以 `main.gd:1111-1112` 的扣费分支根本不跑。
   要修得在测试里补 `app.rogue_pending_cost=<cost>`（属 `main.gd` 的营地流程，本次派单禁止改 `main.gd`）。
2. `rogue_inventory` 的既存失败：魔境 `spend("medicine")` 恒 false、治疗走 `RogueBuild.commit_flask()` 提交制；
   `apply_offer` 只认 `attribute_points/talent_id/flask_refill/item`。属夹具过期（与三月的 triage 结论一致）。
3. **产品取舍**：行囊满 12 件时"取不走"只发一条 message，玩家必须自己点"丢弃"才能离开房间。
   若要更稳，可在 `selection_action` 里把失败原因回传，或对 personal 选择开放 `rogue_selection_return`
   —— 这两处都在 `scripts/roguelike.gd`，本次派单明确禁止修改。
4. 同类挂死风险：任何"运行期错误 → `run()` 中断 → 没有 `quit()`"的测试都会空转（本仓库已见到
   `roguelike`、`rogue_inventory`、`rogue_build_rules`、`roguelike_animations`）。建议统一加 `completed` 兜底；
   本次只顺手补了实际触发的 `rogue_inventory`。
