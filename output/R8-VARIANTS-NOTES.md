# R8 · 深渊变数数据层（`RogueVariants`）交付记录

- **轮次**：R8（契约 §5/§6.2；派单：数据层 + 纯函数，**本轮不接线**）
- **产出文件**：
  - `scripts/rogue_variants.gd`（**新建后与 R2 的通道版本合并**；SHA256 前 16 位 `C9035ADD861A43B0`，279 行）
  - `tests/rogue_variants.gd`（新建验收用例）
  - 本文件
- **未改动**：`tests/rogue_wiring.gd`（R2 交付物，原样）、`roguelike.gd`、`session.gd`、`main.gd`、
  `resources/rogue_build_content.json`（生成物）、G 集合（W7 独占）、任何既有 `.md`。

## 0. 与 R2 的所有权重叠：合并决议（已获顶层仲裁批准）

R2 轮已经创建过 `scripts/rogue_variants.gd`（5 条变数 + `table()/roll()/active()` 通道，并已接进
`roguelike.enter()`，验收在 `tests/rogue_wiring.gd`）。契约 §8 把该文件列在 F 集合＝W6（R8），
因此出现"同文件双写者"。顶层裁决：**文件判给 R8（唯一写者），R2 停止写入**。合并原则：

| 项目 | 处理 |
| --- | --- |
| `table()/roll()/active()` 签名 | **冻结不变**（R2 的 `enter()` 调用面继续有效） |
| `roll()` 消耗纪律 | 仍**恰好 1 次** `s.rng` 抽取；仍只写 `raid.variant` / `raid.variant_serial` |
| R2 的 5 条变数 | id/name/desc/effect **原样保留**，仅追加 `kind/weight/min_floor` |
| effect 键词汇 | **沿用 R2 已选**（`enemy_damage/loot_tier/bullet_size/gold/...`），不另造一套 |
| 选择算法 | 由"均匀 `randi_range`"改为"**加权 + `min_floor` 门控 + 可选 `variants_seen` 去重**，固定 1 次 `randf`" |
| 已知影响 | 「某个种子抽到哪一条」可能变化；`tests/rogue_wiring.gd` 的断言**实测仍全绿**（113/0，见 §2） |

## 1. 变数全表（18 条，正负都有）

`weight` 为抽取权重，`min_floor` 为最早可出现的层。总权重 115。

| id | 名称 | kind | weight | min_floor | effect |
| --- | --- | --- | --- | --- | --- |
| `blood_moon` | 血月 | mixed | 8 | 1 | enemy_damage +15% · loot_tier +1 |
| `rust` | 锈蚀 | mixed | 8 | 1 | player_damage -10% · shop_price -30% |
| `fog` | 雾障 | boon | 8 | 1 | **bullet_size +25%** · bullet_speed -20% |
| `bounty` | 丰饶 | boon | 8 | 1 | gold +25% |
| `frenzy` | 狂暴 | mixed | 7 | 1 | enemy_speed +12% · enemy_hp -8% |
| `starlight` | 星辉 | boon | 7 | 1 | xp_gain +30% |
| `iron_law` | 铁律 | boon | 7 | 1 | player_damage_taken -12% |
| `stasis` | 静滞 | mixed | 6 | 1 | bullet_speed -25% · enemy_damage +8% |
| `wolves` | 群狼 | mixed | 6 | 2 | elite_chance +12% · loot_tier +1 |
| `austerity` | 苦修 | mixed | 6 | 1 | player_damage_taken +10% · gold +40% |
| `surge` | 狂潮 | mixed | 6 | 1 | bullet_speed +15% · **bullet_size +10%** |
| `abundance` | 余裕 | boon | 6 | 1 | gold +20% · xp_gain +20% |
| `bargain` | 议价 | mixed | 6 | 2 | shop_price -25% · loot_tier -1 |
| `apocalypse` | 天启 | boon | 5 | 3 | player_damage +15% |
| `blood_debt` | 血债 | bane | 5 | 2 | player_damage_taken +12% |
| `sanctuary` | 圣佑 | boon | 5 | 3 | player_damage_taken -10% · enemy_hp -10% |
| `bedrock` | 顽石 | bane | 6 | 2 | enemy_hp +20% |
| `famine` | 饥荒 | bane | 5 | 2 | xp_gain -20% · gold -15% |

- 正/负分布：boon 7 条、bane 3 条、mixed 8 条（`kind` 与效果极性由断言强制自洽）。
- **与弹幕可读性咬合**：`fog`（更大更慢）与 `surge`（更大更快）两条。二者的键只允许
  `bullet_size` / `bullet_speed`，由断言钉死；`bullet_size` 的合成下限锁 `0.0`
  —— **变数永远不许把敌人弹幕缩小**（用户要求：弹幕只能更显眼）。

## 2. 验收与回归（全部实跑，引擎 `Godot_v4.7.2-stable_win64_console.exe`，`--headless --path . --script`）

| 测试 | R1 基线 | R8 复跑 | 结论 |
| --- | --- | --- | --- |
| `tests/rogue_variants.gd`（本轮新增） | — | **495 checks / 0 failures** | 新增全绿 |
| `tests/rogue_wiring.gd`（R2 交付，未改） | — | **113 checks / 0 failures** | 合并后未回归 |
| `rogue_build_growth` | 4066 / 0 | **4066 / 0**（chest samples [204,498]） | 一致 |
| `rogue_build_system` | 440 / 0 | **440 / 0** | 一致 |
| `systems` | 10812 / 0 | **10812 / 0** | 一致 |
| `expedition` | 79 / 0 | **79 / 0** | 一致 |

**新增失败 = 0。**

`tests/rogue_variants.gd` 覆盖的断言族：
① 表形状/唯一 id/R2 冻结 5 条仍在/kind 与极性自洽/`table()` 深拷贝；
② 判定几何守卫（每个 effect 键必须属 canonical 集、不得属 FORBIDDEN_KEYS；弹幕键只能是
   `bullet_size`/`bullet_speed`；`modifiers_of` 输出无 `hit_radius`/`collision_radius`）；
③ 描述与数值一致（`label` 必须含每个效果键的真实数字，`describe` 深拷贝、未知 id 返回 `{}`）；
④ `modifiers_of` 加法合成、上下限 clamp（±0.6 / -0.3 等）、`loot_tier` 为 `int`、未知 id 忽略、
   字符串入参、缓存不泄露可变引用；
⑤ **确定性**：同 (seed, floor) 重复 1000 次结果完全一致；`pick()`/`roll()` 各**恰好消耗 1 次** rng
   （用 `RandomNumberGenerator.state` 比对证明，含"无候选时也照抽 1 次"）；
⑥ `min_floor` 门控（floor 1/2/3/5 × 400 样本无一越级）；
⑦ **≥1000 样本全覆盖**：floor 5 抽 1000 次，18 条**每条都被抽到**，且无单条占比 > 40%；
⑧ `exclude` 去重（排除后仍确定、排除全部返回 `""`、`weight_total` 归零）；
⑨ `roll` 写 `raid.variant`/`variant_serial`、`active()` 与之一致、无 `raid` 键时也能工作、`null` 安全；
⑩ 真实 `TideSession` 接线（R2 通道）不回归（含 `load()` 守卫，避免被并发 W1 编辑连带崩）。

## 3. 公开 API（本轮产出）

契约既有（冻结）：`table() -> Array`、`roll(s) -> Dictionary`、`active(s) -> Dictionary`。

R8 追加（纯函数/只读，均可被测试与后续轮次调用）：
`pick(rng, floor, exclude) -> String`、`describe(id) -> Dictionary`、`modifiers_of(ids) -> Dictionary`、
`effect_text(id) -> String`、`canonical_keys() -> Array`、`bounds() -> Dictionary`、
`integer_keys() -> Array`、`polarity_map() -> Dictionary`、`forbidden_keys() -> Array`、
`ids() -> Array`、`weight_total(floor, exclude) -> float`、`polarity_score(id) -> float`。

## 4. 待接线清单（R8 提交；非所有者只读，照抄即可）

> **调用纪律（R8 实测）**：stale class cache 下 headless **不会**重建 `class_name` 注册表，
> 直接写 `RogueVariants.xxx` 会在解析期报「找不到标识符」。所有接线一律用
> `const Variants = preload("res://scripts/rogue_variants.gd")` 再走 `Variants.xxx`
> —— R2 的 `roguelike.gd`、R4 的测试、R8 的 `tests/rogue_variants.gd` 都是这么过的。
> `tools\check_class_cache.ps1 -CheckOnly` 目前仍报 4 个缺失 class
> （`RogueCurses/RogueEvents/RogueGraph/RogueVariants`），与本轮改动无关；
> R8 的 495/0 与 R2 的 113/0 都是在**不依赖类名注册**的前提下跑出来的。

```
## 待接线清单（提交者 W6：轮次 R8）
```

### 4.1 每层抽取（W1，R2 已落地，R8 不改）
- 目标文件: `scripts/roguelike.gd`
- 目标函数/锚点: `enter()`，`s.raid["exits"]=exit_choices(s)` 之前
- 现状: 已 `Variants.roll(s)`，且"每层恰好一次、同层不重抽"由 `tests/rogue_wiring.gd` 断言
- 契约: §2 `raid.variant`/`variant_serial`、§6.2 顺序
- 验收断言: `tests/rogue_wiring.gd:53,87-92,96,105`

### 4.2 变数**效果**接线（R8 只交数据，效果需下列各轮落实）
| # | 目标文件（所有者） | 锚点 | 期望改动 | 依据键 |
| --- | --- | --- | --- | --- |
| a | `scripts/session.gd`（W1） | `incoming_damage()` **:496-499** roguelike 分支 | 在既有减伤池里乘 `(1.0+mods.player_damage_taken)`，与诅咒同乘，**不得新开独立乘数** | `player_damage_taken` |
| b | `scripts/session.gd`（W1） | `damage_enemy()` **:2977**（玩家来源分支） | 伤害乘 `(1.0+mods.player_damage)` | `player_damage` |
| c | `scripts/rogue_combat.gd`（W3） | `setup_minion()` / `setup_boss()` | `hp *= (1.0+mods.enemy_hp)`；出手/移动节奏乘 `(1.0+mods.enemy_speed)` | `enemy_hp` / `enemy_speed` |
| d | `scripts/session.gd`（W1） | 敌人开火 **:3346** `"v":e.attack_aim*245` | `*245*(1.0+mods.bullet_speed)`，并把 `mods.bullet_size` 写进子弹字典新字段（建议 `bullet_visual`） | `bullet_speed` / `bullet_size` |
| e | G 集合（**W7 独占，只读回传**） | `combat_visuals.gd:367`（普通敌人弹）/ `boss_effect_staging.gd` / `effect_semantics.gd:22-43` | 按 `bullet_visual` 倍率放大**绘制**；**绝不改 `hit_radius`（session.gd:3434）** | `bullet_size` |
| f | `scripts/roguelike.gd`（W1） | `roll_tier()` **:285** | 返回值 `+ int(mods.loot_tier)`，clamp 到既有 tier 上限 5 | `loot_tier` |
| g | `scripts/roguelike.gd`（W1） | 商店报价 **:476-478** | `price = maxi(1, roundi(price*(1.0+mods.shop_price)))` | `shop_price` |
| h | `scripts/roguelike.gd`（W1） | 清房奖励 **:260** 与 `settle()` 的 `coins` | 乘 `(1.0+mods.gold)` 取整 | `gold` |
| i | `scripts/roguelike.gd`（W1） | 结算 **:656** 的 `xp` 与小怪 `build_xp_reward`（:152/:214） | 乘 `(1.0+mods.xp_gain)` 取整 | `xp_gain` |
| j | `scripts/roguelike.gd`（W1） | `spawn_minion(...,elite)` 判定处 **:210** | 精英概率 `+ mods.elite_chance` | `elite_chance` |
| k | `scripts/main.gd`（W2） | 魔境 HUD | 顶部 `const Variants = preload(...)`，显示 `Variants.describe(str(s.raid.variant)).label`，`variant_serial` 变化时提示一次 | — |
| l | `scripts/roguelike.gd`（W1，**追加项**） | `reset()` / `enter()` | 若要层间去重：`reset()` 写 `raid["variants_seen"]=[]`，抽中后 `append`。`roll()` **已支持读取该字段** | — |

- **性能提示**：`incoming_damage()` 是逐帧调用点，请把 `modifiers_of([variant])` 的结果缓存在
  `raid` 或本地（每层只变一次）；`modifiers_of` 内部已有静态记忆化，但逐帧取深拷贝仍不划算。
- **未接线时的临时状态**：`raid.variant` 有值但全项目无人读取其 `effect`，玩法不生效、测试可跑。
- **契约追加请求**（按 §8 CHANGE-LOG 流程）：① `raid["variants_seen"]`（Array[String]，可选）；
  ② 子弹字典新字段 `bullet_visual`（float，仅表现层读，不得进入任何判定计算）。

## 5. 已知风险 / 未覆盖

1. 本轮的 `modifiers_of` 只做**加法合成 + clamp**；与 `rogue_build.gd` 既有减伤池的**交互方式**
   由 4.2(a) 决定（必须复用同一池），本轮无法验证，需 W1 接线后补断言。
2. `loot_tier` 与 `shop_price` 的"每层商店只有 1 个"等既有规则未触碰，仅提供倍率。
3. `variants_seen` 去重未启用（R2 未维护该字段），所以同一局内**可能重复抽到同一条变数**；
   需要的轮次按 4.2(l) 追加。
