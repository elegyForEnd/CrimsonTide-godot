# R6 · 守层者半血「二阶段换招表」+ 敌人侧变数钩子（交付记录）

- **轮次**：R6（派单范围：`rogue_combat.gd` / `boss_choreography.gd` + 自有测试；G 集合只读）
- **产出**：
  - `scripts/rogue_combat.gd`（+129/−27 区间）· `scripts/boss_choreography.gd`（+73）· `scripts/sound.gd`（+7/−2）
  - `tests/rogue_boss_phase2.gd`（**新建**，406 checks / 0 failures）
  - `tests/roguelike_bosses.gd`（按新口径移植：5→7 招 + boss 入口改为节点图的 boss 节点）
- **未改动**：`roguelike.gd`/`session.gd`/`profile.gd`(W1)、`main.gd`/`rogue_field.gd`(W2)、`rogue_map.gd`(W4)、
  `resources/rogue_build_content.json`(生成物)、G 集合（W7）、任何既有 `.md`。未 `git commit`。

---

## 1. 二阶段换招表（R6 核心）

### 1.1 七招表 = 原五招 + 两招只在半血后出现的终结技

`scripts/rogue_combat.gd` `MOVES` 每行 5→7（守卫者序号 → 新增两招）：

| 守层者 | identity | 原有 5 招 | 新增（index 5 / 6） |
| --- | --- | --- | --- |
| 幽蕈古王 | `grove` | 古根织网·孢荚播散·菌冠滋养·藤须迁行·菌林召生 | **孢云窒息** / **菌林献祭** |
| 熔炉暴君 | `furnace` | 锁链拖拽·炽铆连射·泄压熔井·链锤摆荡·熔心过载 | **锁链绞轮** / **熔炉过载** |
| 星镜女皇 | `astral` | 棱星折光·镜轨环游·三拍陨星·星棱换位·星镜碎界 | **万镜回廊** / **星轨崩塌** |
| 雷翼舰长 | `wing` | 逆风航道·折返雷矢·游走风眼·折线俯冲·天穹失速 | **折返风暴** / **天穹断翼** |
| 黑曜剑圣 | `obsidian` | 墨影三易·悬剑落墨·禁庭四角·黑曜拔刀·绝剑留白 | **千刃返照** / **终末绝影** |

- 编排时间线写进 `boss_choreography.gd` 的 `match key:` → `match index:` 的 `5:` / `6:`（每个 identity 两组）。
- **零新美术**：所有 `zone()/projectile()/construct()` 只复用该 identity 既有 `MOTIFS` 里的 role
  （`boss_effect_art.gd` 的 4 个 motif）与既有 shape（`circle/cone/lane/ring/gap_ring`），
  通道仍走 `Choreography.zone() → rogue_combat.zone()`，**没有新增文件、没有新增贴图 key**。
- **音频**：`sound.gd` 的守层者 cue 循环 5→7；`5/6` 若没有独立录音则回落到该守卫者第 5 招的录音
  （与既有"借用 queen 的 take"同一策略），保证"每一招都有起手/命中线索"在 7 招表下仍成立。

### 1.2 阶段状态机（只触发一次，不回退）

- `update_boss()`：`if not e.boss_enraged and e.hp <= e.max_hp*0.5` → 置 `boss_enraged=true` **且** `e["phase"]=2`，
  播 `rogue-boss-phase` 冠印 + 专属 phase 音 + 提示「进入二阶段！招式全开」。
- 守卫是**单调**的：`boss_enraged` 只置位不复位，`phase` 由它派生（`boss_phase()`），
  因此**回血 / 反复跨越 50% 都不会退回一阶段，也不会重复播冠印**（`rogue_boss_phase2` 用 40 次交替血量验证：冠印事件恒为 1 次）。
- 起手顺序：
  - 一阶段 `PHASE1_CURSOR = [0,1,2,3,4]`（**与旧版 `move_cursor % 5` 逐位一致，一阶段行为零变化**）；
  - 二阶段 `PHASE2_CURSOR = [5,2,6,0,3,1,4]`（7 招全覆盖，终结技打头）。
- `Choreography.choose()`：`pool.size()>=7` 时一阶段 `[0,1,2,3,4]`、二阶段 `[5,2,6,0,3,1,4]`；
  其余（战役/精英/Boss 池）保持原 `[0,1,0,2,3]` / `[2,0,3,1,4]` **一字未动**。
- `visual_move()` 与 `begin_skill()` 的索引 clamp 由写死的 `0..4` 改为 `size()-1`，
  避免 7 招表下 legacy 回落路径越界。

### 1.3 判定几何零变化（用户硬要求）

- 新招**不写任何判定字段**：`zone()` 产出的 telegraph 只有 `radius/inner/direction/end/delay`，
  没有 `hit_radius`/`hit_scale`/`collision_radius`（测试对 10 个终结技的每条 telegraph 逐条断言）。
- 守层者瞬发弹（`bolt()`）沿用 `session.gd:3434` 的默认 `hit_radius=18.0`——**从不写这个键**；
  编排弹（`boss_choreography.advance()`）保持它原有的显式 `"hit_radius":18.0`，有无变数都恒等于 18.0。
- 伤害仍是同一套 `contains()`（`choreographed → BossGeometry.contains`），新招只是新的编排组合。

---

## 2. 深渊变数的敌人侧钩子（R8 待接线清单 c / d）

`rogue_combat.gd` 新增只读换算 + 幂等应用：

| 函数 | 语义 | 上限 |
| --- | --- | --- |
| `enemy_hp_scale(s)` | `1 + mods.enemy_hp` | `[0.5, 3.0]` |
| `enemy_tempo(s)` | `1 + mods.enemy_speed`（出手/移动节奏除数） | `[0.5, 2.0]` |
| `bullet_speed_scale(s)` | `1 + mods.bullet_speed` | `[0.5, 2.0]` |
| `bullet_visual_scale(s)` | `1 + mods.bullet_size`（**下限锁 1.0，弹幕永不缩小**） | `[1.0, 3.0]` |

- `mods` 来自 `preload("res://scripts/rogue_variants.gd").modifiers_of([raid.variant])`；**用 preload，不写裸类名**。
- **应用点**：
  - `setup_boss(e, floor, s=null)` / `setup_minion(..., s=null)`：传了 `s` 就在**生成时**生效；
    没传（W1 尚未改签名）时由 `update()` 首次**补应用一次**（`variant_stats_applied` 幂等守卫，绝不逐帧叠加）。
  - `update_boss()` 的出手节奏：`cd = (1.0 if enraged else 1.65) / enemy_tempo(s)`。
  - `bolt()`：`v = dir * speed * bullet_speed_of(e)`，并写表现层键 `bullet_visual`。
  - `boss_choreography.advance()` 的编排弹：同一份 `boss_bullet_speed` / `boss_bullet_visual`
    （在 `begin_skill()` 起手时按当前变数缓存一次，逐帧不再取），**只作用于 rogue 守卫者**，
    战役 Boss 的弹道字节不变。
- **无变数时行为完全不变**：换算恒为 1.0，敌人字典只多一个 bool 标记；测试用 18 条变数全表断言四个倍率都落在文档区间内。

---

## 3. 验收（实跑，引擎 `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script`）

### 3.1 新增用例

```
ROGUE BOSS PHASE2 406 checks / 0 failures     (exit=0)
```

**刻意不依赖 TideSession**（用最小桩会话驱动真实 `RogueCombat`/`BossChoreography`），
因此 R5 在飞时 session.gd/roguelike.gd 编译失败也不影响 R6 的可复跑性。断言族：

① 5 个守卫者各 7 招、招式名唯一、`PHASE1_MOVES=5`/`PHASE2_MOVES=7`、专属招 = `[5,6]`；
② 一阶段三条路径（`skill_for_cursor` / `choose` / `begin_skill` 索引）都拿不到终结技；
③ 半血切换一次、冠印恰好 1 次、专属 phase cue、回血不回退、反复跨阈值不重触发；
④ 10 个终结技逐条：有预警形状、全部 `choreographed`、伤害延迟、无判定键、
   `contains()` 覆盖宣告危险区且排除远端安全区、推进后确实释放实弹或伤害区、
   实弹 `hit_radius==18.0`；
⑤ 真实 AI 循环（500 tick）确认二阶段**确实打出** index 5 与 6，且永不越出 7 招表；
⑥ 变数：18 条全表的四个倍率区间、`bedrock +20%` / `frenzy −8%·+12%` / `fog −20%·+25%` 精确数值、
   生成时应用、首次 update 补应用、`不逐帧叠加`、小怪生命与冷却；
⑦ 判定不变：同一发弹在有/无变数下 `life/damage/owner/boss_source/fx_move/rogue_tone/rogue_guardian` 全同，
   仅 `bullet_visual` 与弹速不同；编排弹在 `fog` 下 `hit_radius` 仍恒等 18.0。

### 3.2 回归（failures 一个未增）

| 测试 | R1 基线 | R6 复跑 | 判定 |
| --- | --- | --- | --- |
| `rogue_boss_phase2` | — | **406 / 0** | 本轮新增全绿 |
| `roguelike_bosses` | （无基线，计划称 414 项） | **443 / 0** | 按新口径移植后全绿（见 §4.2） |
| `boss_tactics` | 186 / **1** | 186 / **1** | **不变**（既存红：玩家子弹正面格挡，与本轮无关） |
| `combat` | 78 / 0 | 78 / 0 | 一致 |
| `enemy_body` | 379 / 0 | 379 / 0 | 一致 |
| `rogue_graph` | 83608 / 0 | 83608 / 0 | 一致 |
| `rogue_wiring` | 117 / 0 | **123 / 0** | 增加 6 条（R5 追加），仍 0 failures |
| `rogue_variants` | 495 / 0 | 495 / 0 | 一致 |
| `rogue_curses` / `rogue_events` | 218 / 0 · 484 / 0 | 218 / 0 · 484 / 0 | 一致 |
| `rogue_profile_migration` | 113 / 0 | 113 / 0 | 一致 |
| `rogue_build_growth` | 4066 / 0（样本 `[213,500]`） | **4066 / 0（样本 `[213,500]`）** | **逐位一致** |
| `rogue_build_system` | 440 / 0 | 440 / 0 | 一致 |
| `systems` | 10812 / 0 | 10812 / 0 | 一致 |
| `expedition` | 79 / 0 | 79 / 0 | 一致 |
| `audio` / `audio_mix` | — | 386 / 0 · `MIXER TESTS: 0 failures` | `sound.gd` 改动未回归 |
| `rogue_build_progression`（R5 迁移中） | 505 / **39** | **818 / 0** | R5 已完成口径移植 |
| `roguelike_seven_rooms`（R5 迁移中） | 1856 / 0 | **11832 / 0** | R5 已完成口径移植 |
| `roguelike_routes`（R5 迁移中） | 5219 / **5** | 5220 / **2** | **R5 在飞**，非本轮引入（本轮无任何 route/exit 改动） |

`rogue_build_rules`（崩溃挂死）与 `rogue_build_pack`（资产缺失）按基线豁免未跑。

---

## 4. 需要上游知道的三件事

### 4.1 与计划行 R6-② 的措辞差异（已按派单为准）
计划文档写「`choose` 在 `phase>=2` 时**只**返回备用表内招式 / 不再出现第一阶段招式」，
但派单正文写「二阶段招表 **7 招 = 5 原招 + 2 招专属**」。**按派单实现**：
二阶段 7 招全部可用，被强制的不变量是「**两招专属终结技在一阶段绝不出现**」（三条路径都有断言）。
若确实想要"二阶段只打新招"，改一行 `PHASE2_CURSOR` / `choose` 的 order 即可。

### 4.2 `tests/roguelike_bosses.gd` 除了 5→7 还要移植一处
该用例原来靠 `s.raid.area=5` 直接进 boss 区。**节点图接管后这条前提不成立了**
（`resolve_node()` 把 `area=depth` 解析成图上第 5 个深度的节点，那里通常不是 boss），
于是 `spawn_wave()` 不满足 `room=="boss" and wave==3`，`s.enemies[0]` 不是守卫者 →
`:38 e.boss_name` 报错且**永不调用 `quit()` → 进程挂死**（与 `rogue_build_rules` 同一症状）。
本轮按新契约改为进入 `s.rogue_graph["boss"]` 节点，改完 443/0。**这不是 R6 引入的红**。

### 4.3 待接线清单（W1 / W2 / W7）

```
## 待接线清单（提交者 W3：轮次 R6）
1) 目标文件: scripts/session.gd   (W1)
   目标函数/锚点: 敌人开火 :3346  "v":e.attack_aim*245
   期望改动: 乘 combat.bullet_speed_of(e)（或 (1.0+mods.bullet_speed)），并写 "bullet_visual"
   依赖: 契约 CHANGE-LOG 的 bullet_visual；R8 待接线清单 (d)
   未接线时的临时状态: 普通小怪弹幕不吃 fog/surge 的弹速与尺寸，守层者已生效
2) 目标文件: scripts/roguelike.gd (W1)
   目标函数/锚点: :296 combat.setup_boss(s.enemies.back(),floor_index) / :328 setup_minion(...)
   期望改动: 追加第 3/第 6 个实参 s（生成时即应用变数属性）
   未接线时的临时状态: 由 update() 首次补应用，数值正确、仅晚一帧
3) 目标文件: G 集合（W7，只读回传）
   目标: combat_visuals.gd:367 / effect_semantics.gd:22-43 / boss_effect_staging.gd
   期望改动: 按子弹字典的 "bullet_visual"（float，缺省 1.0）放大"绘制"
   硬约束: 绝不改 hit_radius（session.gd:3434 默认 18.0）
4) 目标文件: scripts/rogue_field.gd (W2)
   目标: :308 的 "· 狂暴" 文案
   期望改动: 与 R6 语义对齐（二阶段换招表），非必须
```

---

## 5. 风险 / 未覆盖

1. 二阶段终结技的**难度手感**未做人肉评估：新招普遍比一阶段慢而重，若嫌过强，只需调各招的 `damage*.x` 系数。
2. `sound.gd` 里 5/6 招回落借用第 5 招录音；若日后补录 `rogue-{f}-{5,6}-{charge,release}.wav`，代码会自动优先使用真录音（无需改码）。
3. 名称为 `"phase"` 的敌人字段沿用战役 Boss 的既有约定（`e.phase`），未新增任何 `raid`/`players` 键，
   因此**不需要**契约 CHANGE-LOG 的键表变更（`bullet_visual` 的登记请求来自 R8，本轮只是消费方）。
