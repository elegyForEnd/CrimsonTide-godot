# R14 · 守层者（Boss）池扩容：5 → 8 个身份 / 每局抽 5 个（交付记录）

- **轮次**：R14（派单范围：`rogue_combat.gd` / `boss_choreography.gd` / `boss_effect_art.gd` / `boss_effect_staging.gd` / `boss_damage_visual.gd` / `sound.gd` / `tests/roguelike_bosses.gd` + 自有新测试）
- **实际写入面**（`git status --porcelain -- scripts tests`）：
  - `M scripts/rogue_combat.gd`（+216/−38 区间）· `M scripts/boss_choreography.gd`（+153）· `M scripts/boss_effect_art.gd`（+11/−1）
  - `M tests/roguelike_bosses.gd`（移植口径，+18）· `M tests/boss_choreography.gd`（**修一条 R6 遗留的过期断言**，见 §5）
  - `?? tests/rogue_boss_pool.gd`（新建，2305 断言）
- **未改动**：`roguelike.gd` / `session.gd` / `profile.gd`（W1）、`main.gd` / `rogue_field.gd`（W2）、`rogue_map.gd`（W4）、`combat_visuals.gd` 等 G 集合（W7 弹幕回炉在改）、`sound.gd`（本轮无需改动，见 §3.4）、`boss_effect_staging.gd` / `boss_damage_visual.gd`（并发轮次在改，未触碰）、`assets/**`（零新美术）、任何既有 `.md`。未 `git commit`。

---

## 1. 扩容后的 8 个守层者

前五个索引与扩容前**逐位一致**（`Art.ROGUE[0..4]`），新身份**追加**在末尾，因此既有美术/音频/小怪/伤害路径全部不受影响。

| 索引 | identity（美术 key） | 名称 | motif | 7 招（槽 0..6；**5/6 为二阶段专属**） |
| --- | --- | --- | --- | --- |
| 0 | `grove` | 幽蕈古王 | roots·spore·bloom·mycelium | 古根横扫 / 幽光孢雨 / 根须牢笼 / 林王践踏 / 菌林复苏 / **孢云窒息** / **菌林献祭** |
| 1 | `furnace` | 熔炉暴君 | chain·rivets·hammer·kiln | 熔锤震地 / 炽铁散射 / 地火喷涌 / 锁链冲撞 / 熔炉火环 / **锁链绞轮** / **熔心过载** |
| 2 | `astral` | 星镜女皇 | prism·refraction·starfall·orrery | 星棱贯穿 / 三镜折光 / 陨星坠落 / 星轨轮舞 / 幻镜跃迁 / **万镜回廊** / **星轨崩塌** |
| 3 | `wing` | 雷翼舰长 | gust·return·cyclone·helm | 雷翼斩 / 折返雷链 / 游走飓风 / 疾风俯冲 / 天穹雷罚 / **折返风暴** / **天穹断翼** |
| 4 | `obsidian` | 黑曜剑圣 | scar·echo·rain·seal | 王庭三连斩 / 暗影拔刀 / 黑剑落雨 / 禁咒轮印 / 终焉十字 / **千刃返照** / **终末绝影** |
| 5 | `bell`（新增） | 暮钟司祭 | pendulum·score·fracture·dial | 钟摆葬列 / 止声错拍 / 敲钟者 / 九刻终祷 / 裂钟回响 / **丧钟连祷** / **终末叩响** |
| 6 | `earth`（新增） | 岩窟冢主 | furrow·plate·stalactite·fault | 钻地折返 / 断层立壁 / 穹顶坠岩 / 蜕甲震穴 / 碎岩倾轧 / **地脉封锁** / **终末崩落** |
| 7 | `abyss`（新增） | 湮潮之主 | maw·current·tide·devour | 潮汐吸引 / 错齿吞噬 / 蛇流换岸 / 噬月深潜 / 逆流绞杀 / **万潮归寂** / **终末深潜** |

- **零新美术**：三个新身份直接复用 `boss_effect_art.KEYS` 里既有的 ImageGen key（`bell` / `earth` / `abyss`，共 17 个 key 里的 3 个），`MOTIFS`/`asset_path`/`color` 全部沿用，没有新增任何贴图或 shader。
- **编排复用与新增**：新身份的前四招复用该身份**既有**的战役时间线骨架（`TIMELINE_BASE := {"rq_bell":"bell","rq_earth":"earth","rq_abyss":"abyss"}`），槽 4/5/6 为本轮新写的编排（`boss_choreography.gd` 的 `"rq_*"` 分支）。招式名、伤害表仍来自各自独立的 7 招名单。
- **音效**：`cue()` 仍是 `rogue-<rogue_skin=楼层>-<槽>-<charge|release>`，即**沿用既有回落策略**——新身份借用该楼层的录音（`assets/audio/rogue/` 里现成的 5×5×{charge,release}）。因此 `sound.gd` 无需改动，`tests/roguelike_bosses.gd` 的「Dedicated audio resource exists」仍然成立。

---

## 2. 每局选池：确定性、无副作用、可重建

`scripts/rogue_combat.gd` 新增（全部**纯函数/整数运算**）：

```
mix_seed(value, salt) -> int                  // FNV 风格整数混合，无全局随机
boss_pool(seed_value) -> Array                // 8 取 5 的确定性洗牌（Fisher–Yates，整数 LCG）
boss_art_for(seed_value, floor_index) -> int   // 第 floor 层的身份索引（0..7）
pool_seed(s, e) -> int                        // 只读既有字段：会话 seed_value 或敌人 run_seed
moves_of(e) -> Array                          // 7 招表改按“身份”取，不再按“楼层”取
```

- **不消耗 `s.rng`**：整个派生只用整数运算 + 局部 LCG，一行都不碰会话 RNG（测试断言 `s.rng.state` 前后不变）。这样 `rogue_build_growth` 的宝箱样本仍是基线的 `[213,500]`（逐位一致）。
- **不写任何新 `raid` 键**：测试对 `raid.keys()` 排序后前后比对，断言选池不往快照里加字段。
- **客户端重建**：身份 = `Art.ROGUE[boss_art_for(seed_value, floor)]`，而 `seed_value` 由 `begin` RPC 下发（`session.gd:1386/1412`）、`floor` 在快照里 → 两端各自本地计算即得同一个守层者，**不需要新通道**。敌人字典同时携带 `boss_art` / `art_key` / `boss_name`，即使字典本身被复制也能直接读出身份。
- **`rogue_skin` 语义不变**：仍然是**楼层索引**（`e.rogue_skin == floor_index`），所以楼层驱动的表现/音频/小怪/伤害缩放**全部字节不变**；身份另由 `boss_art`（int）+ `art_key`（String）表达。
- **编排键与美术键解耦**：`boss_choreography.choreo_key(e)` = `e.choreo_key`（若有且已在 `MOVES` 里）否则 `Art.identity(e)`。战役身份行为因此**完全不变**（`choreo_key == identity`）。`choose()` 的 7 招轮换分支额外加了 `rogue_guardian 或 choreo_key` 守卫，战役/精英/Boss 池的 `[0,1,0,2,3]` / `[2,0,3,1,4]` 一字未动。

---

## 3. 验收

### 3.1 新增用例 `tests/rogue_boss_pool.gd`（**不依赖 TideSession**）

```
ROGUE BOSS POOL 2305 checks / 0 failures    (exit=0, stderr 0 行, 无 --quit-after 也能正常 quit)
```

覆盖：
1. 池：8 个身份、前五个索引不变、`MOVES` 比 `Art.KEYS` 多 3 行；同种子同池；恰好 5 个且互不重复；200 个种子里 ≥190 个池不同。
2. 身份与楼层解耦：5 个种子 × 5 层 —— `boss_art == boss_art_for(seed,floor)`、`Art.identity(e)==Art.ROGUE[boss_art]`、`boss_name==NAMES[boss_art]`、`rogue_skin==floor`；一局 5 层 5 个不同身份；**`s.rng.state` 不变**；**`raid` 键集合不变**。
3. 兼容：不传会话时 `boss_art==floor`、`Art.identity==Art.ROGUE[floor]`（扩容前的“楼层即身份”逐位保留）。
4. **8 个身份各 7 招全部真打一遍**：起手有预警、伤害延迟（`delay>0 and not active`）、预警带 `art_key`、**没有任何 `hit_radius`/`hit_scale`/`collision_radius`**、释放确有实弹/伤害区/构造物、有真实后摇窗口、实弹 `hit_radius` 恒为 **18.0**。
5. 二阶段门槛：`skill_for_cursor` 一阶段 24 次游标全部 <5 且覆盖 5 招；`choose()` 一阶段永不返回终结技；`phase=2` 时 5 与 6 都出现。
6. 客户端复原：`boss_art_for(seed,floor)` 与房主抽到的一致；`boss_name` 足以在客户端宣告身份。
7. 全池可达：1000 个种子的并集覆盖全部 8 个身份（不是只有那 5 个）。

### 3.2 `tests/roguelike_bosses.gd` 口径移植

- `combat.MOVES[floor_index].size()==7` → `combat.moves_of(e).size()==7`（身份≠楼层后原写法失效）。
- 召唤/弹幕判定从「`floor_index==0 and skill==4` 特例」改为**读 `e.choreo_steps` 的 op**（`projectile` / `summon`），池化后仍然成立。
- 新增 4 条 ×5 层一致性断言：身份落在 8 元池内、名称/美术/招式表指向同一守层者、`rogue_skin` 仍是楼层。
- 结果：**463 checks / 0 failures**（原 443 + 20）。

### 3.3 回归（原始输出，`--headless --quit-after 20000 --script`）

| 测试 | 本轮实测 | 参考基线 | 判定 |
| --- | --- | --- | --- |
| `rogue_boss_pool`（新） | **2305 / 0** | — | 新增全绿 |
| `rogue_boss_phase2` | **406 / 0** | 406 / 0 | 一致 |
| `roguelike_bosses` | **463 / 0** | 443 / 0 | +20 条新断言，仍 0 失败 |
| `boss_choreography` | **1365 / 0** | 1365 / **1**（R6 遗留） | 见 §5，已修 |
| `boss_readability` | 241 / 0 | — | 全绿 |
| `boss_tactics` | 186 / **1** | 186 / **1** | 既存红不变（玩家子弹正面格挡） |
| `enemy_body` | 379 / 0 | 379 / 0 | 一致 |
| `combat` | 78 / 0 | 78 / 0 | 一致 |
| `systems` | 10812 / 0 | 10812 / 0 | 一致 |
| `expedition` | 79 / 0 | 79 / 0 | 一致 |
| `audio` | 386 / 0 | 386 / 0 | 一致 |
| `rogue_graph` | 83608 / 0 | 83608 / 0 | 一致 |
| `rogue_variants` | 495 / 0 | 495 / 0 | 一致 |
| `rogue_curses` / `rogue_events` | 218 / 0 · 484 / 0 | 同 | 一致 |
| `rogue_wiring` | 123 / 0 | 123 / 0 | 一致 |
| `rogue_build_system` | 440 / 0 | 440 / 0 | 一致 |
| `rogue_build_growth` | 4066 / 0（宝箱样本 **[213,500]**） | 4066 / 0（[213,500]） | **逐位一致**（证明没用 `s.rng`） |
| `rogue_growth` / `rogue_rooms` / `rogue_daily` / `rogue_profile_migration` | 6886/0 · 1299/0 · 132/0 · 113/0 | 同 | 一致 |
| `rogue_ui` | 160 / 0 | 160 / 0 | 一致 |
| `roguelike_art` / `roguelike_vfx` | 90/0 · 99/0 | — | 全绿 |

未跑：`rogue_build_progression` / `roguelike_seven_rooms` / `roguelike_routes`（R5 的域，数字在动）、`*_visual` 窗口用例、`rogue_build_rules` / `rogue_build_pack`（豁免）。

> **后续更新**：W1b 把 `setup_boss(...,s)` 接上、池真正生效后，本用例第一版有 2 条失败（466/2），
> 已在 **§8** 修好并加强为 **1462 / 0**。下表 `roguelike_bosses` 一行的数字是接线前的快照。

### 3.4 判定几何零变化（用户硬要求）

- `MOVES` 三个新行**不写任何判定字段**；`session.gd` 里 `hit_radius` 默认 **18.0** 一行未动；编排弹沿用 `boss_choreography.advance()` 原有的显式 `"hit_radius":18.0`。
- 新测试对 8 个身份 × 7 招 = 56 次起手断言：预警字典中**没有** `hit_radius`/`hit_scale`/`collision_radius`；释放出的实弹 `hit_radius` 恒为 18.0。
- 所有新招只用既有 `zone()/projectile()/construct()/motion()` 通道（形状仍来自 `circle/cone/lane/ring/...` 既有集合），没有新增几何原语。
- `sound.gd` 未改（音效走楼层回落），`boss_effect_staging.gd` / `boss_damage_visual.gd` 未改。

---

## 4. 上游需要做的两件事（待接线，不在我的写入面）

```
## 待接线清单（提交者 W3：轮次 R14）
1) 目标文件: scripts/roguelike.gd   (W1)  :296
   现状: combat.setup_boss(s.enemies.back(),floor_index)
   期望: combat.setup_boss(s.enemies.back(),floor_index,s)     # 一行
   影响: 这一步就是 R6 待接线项 2 的同一处；**接线后选池才会真正生效**
   未接线时的状态: 池逻辑与测试已就绪，但运行时回落到“楼层即身份”（=扩容前行为），
                   玩家暂时看不到新守层者。测试里已用桩会话验证过接线后的行为。
2) 目标文件: scripts/roguelike.gd   (W1)  :302
   现状: s.message.emit(combat.NAMES[floor_index]+"降临！")
   期望: s.message.emit(str(s.enemies.back().boss_name)+"降临！")
   影响: 池生效后 NAMES[floor_index] 会报错名（`defeated()` 已经用的是 boss_name，正确）
3) 目标文件: scripts/enemy_body.gd + scripts/rogue_art.gd  (非 W3)
   现状: rogue_art.boss_animation(int(e.rogue_skin),index)  ← 按**楼层**取身体动画
   期望: 身体帧也按身份走（例如优先 e.boss_art / e.art_key，缺帧时回落到楼层帧）
   未接线的表现: 新守层者的**特效/颜色/招式名/构建物**都按抽到的身份渲染，
                 但**身体立绘**仍是该楼层的原守层者 → 出现“钟形特效配蕈王身体”的不一致。
   说明: 身体动画只有 boss-hd-0..4 五套现成资源（零新美术约束下无法为 3 个新身份补帧），
         所以这条是本轮**已知局限**，需要一次显式取舍（补帧 or 接受回落）。
```

---

## 5. 越界但必要的一处修正：`tests/boss_choreography.gd` 的 `==73`

- 该用例枚举 `Art.KEYS`（17 个）× `Choreo.MOVES[key]` 并断言唯一招式名总数 **`==73`**。
- 算术：`73 = 12×4 + 5×5` —— 正是**守层者还是 5 招表**时的数量。R6 把 5 个守层者从 5 招扩到 7 招后真值变成 `12×4 + 5×7 = 83`，但这条断言没跟着改，于是从 R6 起就一直是红的（R6 的回归清单里没有它）。
- 本轮只把它改成 **83** 并加注释说明来源；R14 新增的三个编排键是独立的 `rq_*`，**不参与这个枚举**，所以计数与我的改动无关（改前改后枚举集合完全相同）。
- 修正后：`BOSS CHOREOGRAPHY 1365 checks, 0 failures`（exit=0，stderr 0 行）。

---

## 6. 其他观察到的既存红（非本轮引入，附不可达性论证）

| 测试 | 结果 | 为什么与本轮无关 |
| --- | --- | --- |
| `boss_tactics` | 186 / **1** | 失败断言 `Real projectile collision uses frontal guard once`（玩家子弹正面格挡）。弹幕轮已用 stash 基线复现过同一红；本轮没碰子弹/格挡路径。 |
| `boss_redesign` | 744 / **3** | 三条全是**美术资源**断言：`Native HD art`（某 key 的 4 张图不是 1024²）、`No shared reskin source`（两张图指向同一文件）、`Seventeen bosses each have four original effects`（`paths.size()==68` 因上面的 `continue` 而偏小）。本轮 `asset_path/KEYS/ROLES` 一行未改、未新增任何贴图。 |
| `roguelike_minion_skills` | 103 / **1** | 失败断言 `Healer prioritizes injured ally`（小怪治疗 AI 选招）。该用例不构造任何守层者（全文件无 `setup_boss`），且本轮不消耗任何随机数、不改小怪 AI；重复运行结果相同（确定性红）。 |
| `roguelike_animations` | exit=0，1 条 SCRIPT ERROR | `Invalid call. Nonexistent function 'spell_animation' in base 'rogue_art.gd'` —— 用例调用了 `rogue_art.gd` 里**已不存在**的方法，属既存过期用例（`rogue_art.gd` 不在本轮写入面）。 |

---

## 7. 风险 / 未覆盖

1. **身体立绘回落**（见 §4.3）是本轮最大可见缺口，需要产品取舍。
2. 新身份的**数值手感**未做人肉评估：7 招的伤害系数沿用同一套 `damage` 公式（`20+floor*4` 的 `build_base_damage` 回落），只调各招倍率即可微调。
3. 新身份的**音效**是楼层回落（借用该层原守层者的录音）——这是「零新录音」的既定策略，`sound.gd` 会在真有 `rogue-{id}-{slot}-{charge,release}.wav` 时自动优先使用，无需改码。
4. 池抽取只依赖 `seed_value`：**同一种子的两局会抽到同一组守层者**（设计上正确：种子可复现），但注意官方「每日挑战」用的是固定种子，因此每天的守层者组合是确定的。
5. 未跑窗口可视化用例（`rogue_boss_choreography_visual.gd` / `roguelike_hd_visual.gd`）——需要真实窗口，留给全量门禁。
