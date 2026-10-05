# W1a — 深渊变数 / 诅咒 接入 `session.gd` 战斗数值路径

工作副本：`D:\game\CrimsonTide-godot`　｜　轮次：W1a　｜　状态：**已交付，44/44 自测通过，回归零新增失败**

## 1. 改动面（只有 `scripts/session.gd` + 一个新测试）

| 位置 | before | after |
|---|---|---|
| `session.gd:423-424`（新增常量） | — | `const RogueVariants = preload(...rogue_variants.gd)`、`const RogueCurses = preload(...rogue_curses.gd)` |
| `session.gd:465-483`（**新增** `rogue_mods(p)`） | 全仓库没有变数/诅咒的集中入口（消费者 = 0） | 合成「本层变数（全队共享）」+「该玩家诅咒（个人）」为一张数值表；额外给出 `defense_penalty`、`curse_count`；非魔境返回空表 |
| `session.gd:485-497`（**新增** `rogue_enemy_bolt(bolt)`） | — | 敌人普通弹幕钩子：`v *= (1+bullet_speed)`、`bullet_visual = 1+bullet_size`；中性 mods **原样返回** |
| `session.gd:540-549`（`incoming_damage` 魔境分支） | `maxf(0,damage)*(1-stat_defense(p))*(1-RogueBuild.conditional_defense(self,p))` | `pool = conditional_defense`；`pool = clampf(pool - defense_penalty, 0, MAX_POOL)`（**同池相减**）；再乘 `(1+player_damage_taken)` |
| `session.gd:2667-2668`（玩家移速合成） | `speed=minf(HERO+70, speed+RogueBuild.stat(self,p,"speed"))` | 同一个加法池内再加 `+ move_bonus`（`mods.move_speed`），仍在同一处 `minf` 之内 |
| `session.gd:3038-3041`（`damage_enemy` 玩家来源） | `damage*=RogueBuild.hit_multiplier(...)` | 先 `damage *= (1+mods.player_damage)`，再照旧乘 `hit_multiplier` |
| `session.gd:3401`（type-1 敌人开火） | `bullets.append({...})` | `bullets.append(rogue_enemy_bolt({...}))` |

**未改动**：`session.gd:3530` 的命中判定 `float(b.get("hit_radius",18.0))` 一字未动；伤害公式、弹数、发射逻辑、`life`、`owner` 全部保持原值。

## 2. 设计要点

* **单入口**：所有魔境数值修正都从 `rogue_mods(p)` 取，调用点不各写一套。
* **同池相减**（已冻结裁决）：诅咒的「受伤加重」不新开乘数，而是从既有减伤池里减掉；池不会被压成负数（4×CU01 时池恰好归零，等价"无减伤"，不会反转成收益）。
* **中性恒等**：无变数且无诅咒时，上面每一处都走"原公式"分支（`penalty==0`、`taken==0`、`move_bonus==0`、`speed_scale==visual_scale==1.0` → 返回原字典），所以搜打撤/战役模式与魔境的无变数情形**逐位不变**。
* **不消耗随机**：`rogue_mods`/`rogue_enemy_bolt`/`incoming_damage` 全程不碰 `s.rng`（用 `RandomNumberGenerator.state` 断言）；本轮的 rng 消耗点仍只有 R2 在 `roguelike.enter()` 里那一处。
* **弹幕**：`bullet_visual` 是**表现层**字段；`bullets` 本就在快照 `data[2]` 里，所以它会随快照自动同步到客户端（无需新增快照键）。`bullet_speed` 只缩放 `v`（与 R6 对守层者弹幕「缩放速度、保留 life」的口径一致）。
* 变数 `bullet_size` 合成本来就锁 0.0 下限（永不缩小敌人弹幕），本轮再 clamp 一次 `[0,1]`。

## 3. 验收（原始输出）

`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/<n>.gd`

| 用例 | 结果 | 基线 | 判定 |
|---|---|---|---|
| `tests/rogue_hooks_session.gd`（新增） | **ROGUE HOOKS 44 checks / 0 failures**, exit=0 | — | 本轮交付 |
| `combat` | 78 / 0 | 78/0 | 一致 |
| `enemy_body` | 379 / 0 | 379/0 | 一致 |
| `boss_tactics` | 186 / **1** | 186/**1** | 既存红未变 |
| `systems` | 10812 / 0 | 10812/0 | 一致 |
| `expedition` | 79 / 0 | 79/0 | 一致 |
| `rogue_wiring` | 123 / 0 | 123/0 | 一致 |
| `rogue_variants` | 495 / 0 | 495/0 | 一致 |
| `rogue_curses` | 218 / 0 | 218/0 | 一致 |
| `rogue_events` | 484 / 0 | 484/0 | 一致 |
| `rogue_build_growth` | 4066 / 0，宝箱样本 `[213,500]` | 4066/0 `[213,500]` | 一致 |
| `rogue_build_system` | 440 / 0 | 440/0 | 一致 |
| `rogue_boss_phase2` | 406 / 0 | 406/0 | 一致 |
| `roguelike_bosses` | 463 / 0 | 443/0（R14 扩容中） | failures 未增 |
| 参考（R5 域，非门禁） | `rogue_build_progression` 818/0 · `roguelike_seven_rooms` 11832/0 · `roguelike_routes` 5220/**2** | — | 与 R10 观测一致 |

**负向对照（证明测试会咬）**：把 `damage_enemy` 里的 `player_damage` 乘子临时改成 `if false and ...` 后，同一用例变成 **44 / 1 failures**（失败断言 `player_damage multiplies outgoing damage end to end`），随后已还原。

### 新用例覆盖的六项
1. **非魔境逐项恒等**：`rogue_mods` 空表；`incoming_damage` 与字段公式逐位一致；敌人弹字典不新增键、速度不变。
2. **魔境数值正确**：`fog` → `bullet_size=0.25`、`bullet_speed=-0.20`；`CU02` → `move_speed=-18.0`；`CU01` → `defense_penalty=1-1/1.15≈0.130435`；`austerity` → `player_damage_taken=0.10`；`apocalypse` → `player_damage=0.15`。
3. **判定几何零变化**：弹字典只有 `hit_radius` 缺省 18.0；mod 表不含任何 `FORBIDDEN_KEYS`；源码断言 `float(b.get("hit_radius",18.0))` 仍在、且钩子从不写 `bolt["hit_radius"]`。
4. **不消耗 `s.rng`**：调用前后 `rng.state` 完全一致。
5. **同池相减 + 上限**：构造确定性池 0.10 → 单条 CU01 后 `with_one = base*(1-clamp(0.10-0.130435,0,0.75))` 且 `> without`、且 `≠ without*1.15`（证明不是第二层乘数）；4×CU01 时池归零 → 等于"零减伤"，不会反转成收益。
6. **中性不写多余键**：`bullet_visual` 在无变数时不出现；`bullet_speed` 中性时 `v` 不变。

另有源码结构断言把三处接线点钉死（防止后续轮次悄悄拆掉接线）。

## 4. 给 W1b（`roguelike.gd` 侧）的接口约定

* 集中入口签名：**`func rogue_mods(p: Dictionary = {}) -> Dictionary`**（`session.gd:465`）。`p` 可省，省了就只有全队共享的变数部分。
* 返回表里可直接读的键：变数 12 键（`enemy_damage/enemy_hp/enemy_speed/player_damage/player_damage_taken/loot_tier/shop_price/gold/xp_gain/elite_chance/bullet_size/bullet_speed`）+ 诅咒键（`damage_taken/move_speed/gold_income/shop_price/chest_drop/heal_scale/flask_max/vision/cooldown`，同名键已相加）+ `defense_penalty`/`curse_count`/`sources`。
* **`enemy_hp`/`enemy_speed`/`bullet_speed`/`bullet_size` 的换算口径与 R6 一致**：乘数分别取 `(1+key)`；R6 已在 `rogue_combat.gd`/`boss_choreography.gd` 里用 `enemy_hp_scale/enemy_tempo/bullet_speed_scale/bullet_visual_scale` 消费，**不要重复乘**。
* 已有的会话内钩子：受击 `incoming_damage`、输出 `damage_enemy`、移速（`session.gd:2667` 的池）、普通敌人弹幕（`session.gd:3401`）。**尚未接线**：金币/经验/商店价/宝箱掉率/精英率/掉落品质（属 `roguelike.gd` 经济路径）、`Ecology` 生态怪的弹幕（`ecology.gd:113,170` 仍是原始 `owner:0` 字典）、`session.gd:2961/3027` 的玩家弹幕（不需要变数）。
* 表现层消费方（W7）：读 `bullet["bullet_visual"]`（缺省 1.0）放大**绘制**，绝不改 `hit_radius`。

## 5. 已知缺口 / 风险

1. **`Ecology` 弹幕未接入**：`type>=5` 的生态怪走 `ecology.gd`，其子弹不在本轮钩子内，因此 `fog/surge` 只影响 `type==1` 的普通远程怪与（R6 已接的）守层者弹幕。
2. **`vision`（CU08 迷雾）没有接线点**（与 R9 的结论一致），目前只在数据层存在。
3. 移速加成进入的是**有上限**的池（`minf(HERO+70, ...)`），所以移速加成在接近上限时会部分失效——这是既有设计，本轮未改。
4. `damage_enemy` 里玩家来源的 `player_damage` 只对 `players.has(owner)` 生效（环境伤害/自伤不受影响），这是刻意的。
5. 本轮未改 `roguelike.gd`（W1b 域）、未改任何表现层文件（W7 域）。
