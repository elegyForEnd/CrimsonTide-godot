# 装备 / 铭刻被动体系 · 实现位置审计 + 一处环境级 BUG 的修复

工作副本：`D:\game\CrimsonTide-godot`（Godot 4.7.2，引擎在仓库根，不在 PATH）。

## 0. 结论速览

1. **96 条被动（E001–E072、I001–I024）全部已经实现**，位置是 `scripts/rogue_build.gd` 里就地判定的
   `gear(p,N)`（第 N 件装备已装）与 `engraving(p,N)`（武器 `rogue_id == N-1`），外围接线分散在
   `session.gd` / `roguelike.gd` / `rogue_combat.gd` / `boss_choreography.gd`。逐条见 §3。
2. 「装备被动等于没实现」这个结论是**错的**，它由三件事叠出来：
   - `scripts/rogue_equipment.gd` 里躺着 `damage_multiplier()≡1.0`、`tick/spent/hit` 全 `pass` 的遗留桩；
   - `session.gd` 有三处 `RogueEquipment.has(p,"clear_mind"/"last_stand"/"mana_guard")` 调用，而内容表
     从来没有 `passive` 字段 → 恒为 false（两处还是永远到不了的死分支）；
   - **一处环境级类缓存污染（§1）**：运行期 `TideSession` 实际被解析到 `build/` 下的 HEAD 快照拷贝，
     于是从源码启动时跑的是**旧版 session.gd**。
3. 本轮实际改动：`scripts/session.gd`（删 3 处死代码）、`scripts/rogue_equipment.gd`（头注释 + `has()` 变真实）、
   新增 `tests/rogue_passives.gd`（21 断言），以及**删除 2 个污染类缓存的 scratch 拷贝并重建缓存**。

## 1. 环境级 BUG：`build/` 下的 scratch 拷贝劫持了全局类缓存（本轮最重要的修复）

**现象**：`roguelike.gd:148` 的 `s.rogue_graph = NodeGraph.build(...)` 报
`Invalid assignment of property or key 'rogue_graph' ... on a base object of type 'Node (TideSession)'`，
即新加的节点图字段在运行期根本不存在。

**取证**（探针：创建 `TideSession` 后打印 `s.get_script().resource_path`）：

```
script path=res://build/triage/head-session.gd len=161113
has raid=true has players=true has rogue_graph=false
source contains var rogue_graph: false
```

**根因**：早先的验证轮把 HEAD 版本拷到 `build/` 下做对照，而这些拷贝**也声明了 `class_name`**：

```
build\triage\head-session.gd          -> class_name TideSession
build\r0-verify\combat_visuals.HEAD.gd -> class_name CombatVisuals
```
Godot 会把项目里所有 `class_name` 脚本登记进 `.godot/global_script_class_cache.cfg`，
`build/` 虽被 gitignore 但仍在项目内，于是这两个过期拷贝**覆盖了真正的实现**。
后果：从源码启动（`游戏启动.cmd` / `源码版启动.cmd`）与 headless 测试都可能跑着**旧版 session.gd 和旧版弹幕渲染**，
表现就是「新手写的东西没生效 / 肉鸽到处是 bug」。

**修复**：删除这两个 scratch 拷贝 → 删掉 `.godot/global_script_class_cache.cfg` → `--headless --path . --import` 重建。
修复后验证：

```
script path=res://scripts/session.gd len=164351
has rogue_graph=true   source contains var rogue_graph: true
cache 中不再有 res://build/... 条目；TideSession -> res://scripts/session.gd
```

**教训**：任何放进项目目录的对照拷贝都会参与 `class_name` 注册。对照文件必须放在项目外，
或至少改掉 `class_name` 行。

## 2. 源码级修复：三处死代码（其中一处是潜在的重复结算）

| 位置 | 原代码 | 处置 | 为什么安全 |
|---|---|---|---|
| `session.gd` `recover_mana` 搜打撤分支（旧 :547） | `bonus = 1.5 if roguelike.active(self) and has(p,"clear_mind") and hp>=80% else 1.0` | 删除，恢复为固定 `0.06` 系数 | 魔境在函数顶部已 `return`，这里是搜打撤/战役路径，`roguelike.active(self)` 恒 false → bonus 恒 1.0 |
| `session.gd` `incoming_damage` 搜打撤分支（旧 :561） | `bonus = 0.75 if roguelike.active(self) and has(p,"last_stand") and hp<35% else 1.0` | 删除 | 同上，恒 1.0；E002 的真正实现是 `RogueBuild.conditional_defense`（`gear(p,2)`） |
| `session.gd` `hurt`（旧 :3461-3465） | `if roguelike.active(self) and has(p,"mana_guard"): 吸收 30% 伤害` | 删除 | 同一函数上一行的 `RogueBuild.incoming()` 已按设计实现 E003（`absorb_ratio := .20 if gear(p,3)`，先耗法力再耗盾）；这段一旦生效会**双重扣蓝** |

`scripts/rogue_equipment.gd` 的 `has()` 从「比对不存在的 `passive` 字段」改成映射到真实实现
（`last_stand → gear(p,2)`、`mana_guard → gear(p,3)`、`clear_mind → gear(p,4)`），并保留数据字段回退；
四个遗留钩子（`damage_multiplier/tick/spent/hit`）加注「零调用者、**不得接入管线**，否则与 `hit_multiplier`/`hit_event` 重复结算」。

## 3. 96 条被动的实现位置（自动从当前源码提取）

| 条目 | 名称 | 设计文档效果 | 实现位置 |
|---|---|---|---|
> 说明：位置列是**实际执行该效果**的代码行（自动提取、已剔除注释行与 `rogue_equipment.gd` 的兼容映射）。`rogue_equipment.gd` 的 `has()` 只是把 `clear_mind`/`last_stand`/`mana_guard` 三个历史名字映射回 `gear(p,4/2/3)`，不是实现处，故不列。
| E001 | 血棘战衣 | 普攻直击吸血 4%，每次最多 2% HP，ICD 2 秒；不计算 DoT | rogue_build.gd:377 |
| E002 | 余烬壁垒 | HP<35% 时条件减伤 +15%；离开阈值立即停止 | rogue_build.gd:108 |
| E003 | 星纱法袍 | 法力吸收减伤后伤害的 20%，1 蓝吸收 1 伤害，先耗法力再耗临时盾 | rogue_build.gd:527 |
| E004 | 晨露护衣 | HP≥80% 时回蓝速度 +25%，受回蓝速度上限 | rogue_build.gd:94 |
| E005 | 赤刃誓衣 | 5 层出血的敌人被自己直击时 C+12% | rogue_build.gd:305 |
| E006 | 断誓锁甲 | 每次实际受击失去≥8% HP 后，下次重刃普攻 C+20%；有效 4 秒，ICD 8 秒 | rogue_build.gd:544 |
| E007 | 熔炉围裙 | 由敌人灼烧和岩浆造成的伤害额外降低 20%；不叠入一般条件减伤，不作用于直接火焰重击 | roguelike.gd:457 |
| E008 | 烛火祭袍 | 自己施加的灼烧持续 +1 秒，刷新时上限 5 秒；不提高层数 | rogue_build.gd:233 |
| E009 | 星霜斗篷 | 自己造成冻结后获 6% 护盾/4 秒，ICD 8 秒；Boss 满冰缓同样触发但不冻结 | rogue_build.gd:241 |
| E010 | 霜骨胸铠 | 自己直击冰缓≥3 层敌人后条件减伤 +8%/2 秒，刷新不叠 | rogue_build.gd:370 |
| E011 | 雷翼轻甲 | 闪避后下一次普攻命中加感电 2 层，有效 3 秒，ICD 4 秒 | rogue_build.gd:412 |
| E012 | 雷骸绝缘衣 | 当前 HP 扣除一次敌方直接雷击后得 5% 护盾/4 秒，ICD 8 秒；雷击标签由敌人技能… | rogue_build.gd:545 |
| E013 | 星泉长袍 | MP≥75% 时施法消耗 -10%；结算前判断高蓝，扣蓝后再计算伤害条件 | rogue_build.gd:214 |
| E014 | 空鸣术衣 | MP≤30% 时首次普攻命中回 4 蓝，ICD 3 秒；不是施法前赠蓝 | rogue_build.gd:384 |
| E015 | 终焉祭衣 | 右键直击 HP≤30% 目标 C+18%，不强化 Q | rogue_build.gd:301 |
| E016 | 黑曜戒甲 | 每 8 秒获得一次守势，下一次敌方直接伤害降低 12%；不作用于 DoT/岩浆 | rogue_build.gd:526 |
| E017 | 镜轨战袍 | 右键成功扣蓝后 3 秒内下一次普攻追加 0.18P，ICD 6 秒 | rogue_build.gd:581 |
| E018 | 逐风披肩 | 闪避后 2 秒移速 +18，且近战普攻出手移动惩罚减少 20 个百分点 | rogue_build.gd:576<br>session.gd:2863 |
| E019 | 引魂葬衣 | 自己召唤实体存活时条件减伤 +6%；多实体不叠 | rogue_build.gd:111 |
| E020 | 冥庭长衣 | 自己合格击杀后得 4% 护盾/4 秒，ICD 6 秒；Boss 直击每 10 秒可替代触发一… | rogue_build.gd:485<br>rogue_build.gd:1004 |
| E021 | 晨钟礼服 | 自身施法扣蓝≥12 后，距自己≤240 的最低血角色回复 2% HP，ICD 6 秒；自己可… | rogue_build.gd:201<br>rogue_build.gd:203 |
| E022 | 巡夜救援甲 | 救援交互时条件减伤 +15%；单人时血瓶受疗+15%（不增加容量），计入血瓶专用受疗池 | rogue_build.gd:112<br>rogue_build.gd:1018 |
| E023 | 孤星旅袍 | 320 内无其他存活玩家时 A+8%；不是单人专属，远离队友也生效 | rogue_build.gd:91 |
| E024 | 共鸣织甲 | 240 内有其他存活玩家时自身常态减伤 +4%；单人改为最大 HP +10，换模式不补当前 … | rogue_build.gd:89<br>rogue_build.gd:92 |
| E025 | 星泉棱镜 | MP≥70% 时直击 C+12% | rogue_build.gd:311 |
| E026 | 祈愿圣印 | 一次实际扣蓝≥12 回复 2% HP，ICD 5 秒 | rogue_build.gd:199 |
| E027 | 弑王瞄具 | 对守层者直击 C+16%；小怪和构造物无收益 | rogue_build.gd:312 |
| E028 | 终焉沙漏 | 对 HP<30% 目标直击 C+18% | rogue_build.gd:313 |
| E029 | 血契针盘 | 普攻命中出血目标，每 4 秒追加出血 1 层 | rogue_build.gd:387 |
| E030 | 赤月刻印 | 对出血≥3 层目标暴击率 +6%；仍受暴击率上限 | rogue_build.gd:334 |
| E031 | 裂阵楔石 | 重刃普攻的破势积累 +12；不提高伤害 | rogue_build.gd:425 |
| E032 | 守誓铁徽 | 自己制造破势窗口时得 6% 护盾/4 秒，ICD 10 秒 | rogue_build.gd:496 |
| E033 | 银鸦准星 | 距离≥220 的普攻暴击伤害 +0.10 | rogue_build.gd:339 |
| E034 | 猎令罗盘 | 攻击未被自己标记目标，普攻根命中后给标记，ICD 3 秒 | rogue_build.gd:388 |
| E035 | 熔心烛台 | 自身灼烧持续 +1 秒，与其他延长累计最多 6 秒 | rogue_build.gd:233 |
| E036 | 余烬火瓶 | 合格敌人带自身灼烧死亡时，在死亡处留下半径 90/2 秒火圈；每秒 0.06P，ICD 4 … | rogue_build.gd:1006 |
| E037 | 星霜六棱 | 对冰缓≥3 层目标法术直击 C+12% | rogue_build.gd:307 |
| E038 | 寂冬挂钟 | 冻结 ICD 从 8 秒减到 7 秒；全局最低 6 秒，Boss 不获得冻结 | rogue_build.gd:239 |
| E039 | 雷翼线圈 | 第 4 次普攻根命中追加一次 0.18P 雷击，ICD 2 秒，主目标 1 人 | rogue_build.gd:397 |
| E040 | 风眼电容 | 自己消耗感电层触发雷裂后回 4 蓝，ICD 4 秒 | rogue_build.gd:512 |
| E041 | 空鸣音叉 | MP≤30% 时右键直击 C+16% | rogue_build.gd:302 |
| E042 | 镜轨残片 | 战技 CDR+8%，Q 不受益 | rogue_build.gd:95 |
| E043 | 禁咒薄册 | 法杖普攻消耗 -10%，最低 1 蓝；物理/右键/Q 不受益 | rogue_build.gd:216 |
| E044 | 黑曜封印 | 首次从无盾变有盾时，下次普攻 C+14%/3 秒，ICD 6 秒；续盾不触发 | rogue_build.gd:171 |
| E045 | 引魂骨铃 | 召唤总伤害 +10%，该项进入召唤专用加算池，上限 +40% | rogue_build.gd:703 |
| E046 | 冥庭令牌 | Q 成功施放时现有灵体持续 +1 秒，每次召唤总延长最多 2 秒 | rogue_build.gd:591 |
| E047 | 晨钟圣杯 | 自身受疗效果 +10%，最终仍检查共享受疗预算 | rogue_build.gd:1018 |
| E048 | 盟约旗扣 | 240 内队友战技命中时自己回 2 蓝，ICD 5 秒；单人时自己战技命中触发 | rogue_build.gd:467 |
| E049 | 逐风长靴 | 距离≥220 时普攻 C+12% | rogue_build.gd:287 |
| E050 | 踏阵铁靴 | 距离≤100 时近战普攻 C+10% | rogue_build.gd:288 |
| E051 | 引魂轻履 | 合格击杀回 4 蓝，ICD 2 秒；守层者普攻命中每 8 秒替代一次 | rogue_build.gd:484<br>rogue_build.gd:1003 |
| E052 | 逆潮战靴 | HP<50% 时直击 C+12% | rogue_build.gd:314 |
| E053 | 赤刃舞履 | 第三段轻刃普攻命中后移速 +20/2 秒，ICD 3 秒 | rogue_build.gd:385 |
| E054 | 血棘绑腿 | 直击自身出血目标后条件减伤 +6%/2 秒，ICD 3 秒 | rogue_build.gd:386 |
| E055 | 破阵重靴 | 重刃挥击时移动速度惩罚减轻 15 个百分点，不提高最大移速 | session.gd:2860 |
| E056 | 裂地钉履 | 受敌方击退距离 -30%；不免疫伤害和地形约束 | boss_choreography.gd:655<br>rogue_combat.gd:528<br>rogue_combat.gd:529 |
| E057 | 猎印软靴 | 装填期间移速惩罚减轻 30 个百分点 | session.gd:2862 |
| E058 | 银鸦伏靴 | 完成装填后 2 秒下一次枪弓普攻 C+18%，ICD 5 秒 | rogue_build.gd:611 |
| E059 | 余烬踏鞋 | 岩浆持续伤害 -20%，与熔炉围裙同池加算，上限 -30% | roguelike.gd:457 |
| E060 | 烛影灰履 | 闪避经过的路径留下半径 50 火点/2 秒，每秒 0.04P，ICD 4 秒，最多 2 个火… | rogue_build.gd:577 |
| E061 | 霜镜滑靴 | 闪避距离 +12%，不可越过边界/障碍 | session.gd:2851 |
| E062 | 寂冬静履 | 自己冻结或使 Boss 达到 5 层冰缓时回 4 蓝，ICD 8 秒 | rogue_build.gd:243 |
| E063 | 雷翼踏板 | 闪避后下一次普攻向主目标追加 0.15P，窗口 2 秒，ICD 4 秒 | rogue_build.gd:414 |
| E064 | 风眼云靴 | 受到的移动减速量 -25%；不缩短硬控或取消走位要求 | boss_choreography.gd:653<br>session.gd:2685 |
| E065 | 星泉行履 | 最后一次消耗蓝量后额外恢复的等待从 1.5 秒减至 1.2 秒 | session.gd:538 |
| E066 | 空鸣步靴 | 右键成功施放后移速 +24/2 秒，ICD 4 秒 | rogue_build.gd:582 |
| E067 | 黑曜盾靴 | 闪避结束后得 4% 护盾/2 秒，ICD 6 秒 | rogue_build.gd:678 |
| E068 | 余烬守城靴 | 连续 6 秒未失去 HP 后自然回复 1% HP，ICD 6 秒；战斗治疗子预算有效 | rogue_build.gd:683 |
| E069 | 逐风刻靴 | 闪避基础 CD -8%，计入专用闪避 CDR 池，上限 20% | rogue_build.gd:96 |
| E070 | 夜鸦返履 | 完美闪避后下一次普攻 C+18%/2 秒，ICD 5 秒 | rogue_build.gd:516 |
| E071 | 冥庭巡履 | 召唤实体移动速度 +25%，不加攻击频率或传送穿墙 | rogue_build.gd:686 |
| E072 | 晨钟同行靴 | 距离倒地队友≤300 时朝其移动速度 +25；单人时 HP<40% 获移速 +15 | rogue_build.gd:93<br>rogue_build.gd:680 |
| I001 | 破晓 | 对 HP≥90% 目标直击 C+14% | rogue_build.gd:315 |
| I002 | 猎痕 | 对 HP<60% 目标直击 C+10% | rogue_build.gd:316 |
| I003 | 荣光 | HP≥80% 时直击 C+10% | rogue_build.gd:317 |
| I004 | 空鸣 | MP≤30% 时直击 C+12% | rogue_build.gd:318 |
| I005 | 血线 | 每第 4 次普攻根命中加出血 1 层，ICD 2 秒 | rogue_build.gd:454 (pair 循环) |
| I006 | 烛芯 | 每第 3 次普攻根命中加灼烧 1 层，ICD 2 秒 | rogue_build.gd:454 (pair 循环) |
| I007 | 霜痕 | 每第 3 次普攻根命中加冰缓 1 层，ICD 2 秒 | rogue_build.gd:454 (pair 循环) |
| I008 | 雷纹 | 每第 3 次普攻根命中加感电 1 层，ICD 2 秒 | rogue_build.gd:454 (pair 循环) |
| I009 | 裂阵 | 重刃普攻破势 +10；其他普攻 +3 | rogue_build.gd:425<br>rogue_build.gd:428 |
| I010 | 银鸦 | 完成装填或施放右键后，下次普攻根命中加标记，ICD 5 秒 | rogue_build.gd:457 |
| I011 | 蚀骨 | 自身出血和灼烧持续 +0.5 秒，受各自持续上限 | rogue_build.gd:233<br>rogue_build.gd:234 |
| I012 | 溯泉 | 每 4 次普攻根命中回 2 蓝，ICD 3 秒 | rogue_build.gd:455 |
| I013 | 返声 | 右键首次有效命中退其实际消耗的 10%，受总退蓝上限 | rogue_build.gd:465 |
| I014 | 回环 | 右键 CDR+5%，不提高 Q | rogue_build.gd:95 |
| I015 | 星耀 | MP≥75% 时法术直击 C+12%，物理无增益 | rogue_build.gd:319 |
| I016 | 定星 | 暴击率 +4%；HP<50% 时该增益取消 | rogue_build.gd:334 |
| I017 | 狩王 | 对守层者直击 C+12% | rogue_build.gd:320 |
| I018 | 终焉 | 对 HP≤25% 目标直击 C+16% | rogue_build.gd:321 |
| I019 | 血誓 | HP≤40% 时直击 C+14%，不提供回血 | rogue_build.gd:322 |
| I020 | 踏风 | 闪避后首个普攻 C+12%/2 秒，ICD 4 秒 | rogue_build.gd:574 |
| I021 | 盾誓 | 每 8 秒一次，右键成功施放得 4% 护盾/3 秒 | rogue_build.gd:583 |
| I022 | 引魂 | 召唤加算伤害 +8%，不增加数量或持续 | rogue_build.gd:703 |
| I023 | 晨祷 | 右键实际扣蓝≥12 后自身回 1% HP，ICD 6 秒 | rogue_build.gd:584 |
| I024 | 镜轨 | 每第 5 次普攻根命中追加 0.15P，单目标，ICD 3 秒 | rogue_build.gd:456 |

## 4. 与设计文档的行为偏差（保留原样，供设计侧裁决）

- **E029** 文档「普攻命中出血目标，每 4 秒追加出血 1 层」，代码要求 `blood>=3`（`rogue_build.gd:387`）——比文档更严格。
- **E018** 文档两段效果（闪避后移速 +18、近战出手移动惩罚 −20 个百分点），代码只实现移速那半（`rogue_build.gd:576`）。
- **E003** 文档「先耗法力再耗临时盾」，代码顺序一致；吸收比例取文档的 20%（旧 `session.gd` 那段 30% 是另一套，已删）。
- 其余抽查（E001 吸血 4%/封顶 2% HP/ICD 2s、E002 阈值、E004 阈值、I001–I004 条件、I005–I008 每第 4/3 次、I011 持续、I016 高血条件）与文档一致。

## 5. 新增回归用例与实测数字（全部在**修复类缓存之后**、对着真源码测得）

`tests/rogue_passives.gd` → **21 checks / 0 failures**，钉住：

- 72 件装备的 1 基编号约定（`make_gear(i)` → `E{i+1}`，整套 `gear(p,N)` 判定依赖它）；
- 24 个铭刻槽位与 `engraving(p,N)` 的一一对应（无别名、无越界命中）；
- 备用行囊 12 格上限与「满了拒绝换装且不动身上武器」；
- E002 阈值增伤、E003 恰好 20% 且**不重复吸收**、E004 仅高血 +25%、E001 吸血封顶 2% 与 2 秒 ICD；
- I005/I006 按「第 4 / 第 3 次普攻根命中」触发、每次 1 层、2 秒 ICD 内不再触发。

同批实测（真源码）：`systems 10812/0`、`combat 78/0`、`enemy_body 379/0`、`expedition 79/0`、`attributes 204/0`、
`rogue_build_system 440/0`、`rogue_build_growth 4066/0`、`rogue_wiring 122/0`、`rogue_hooks_session 44/0`、
`rogue_hooks_ecology 40/0`、`rogue_hooks_roguelike 85/0`、`rogue_variants 507/0`、`rogue_curses 218/0`、
`rogue_events 484/0`、`rogue_rooms 1299/0`、`rogue_growth 6886/0`、`rogue_daily 132/0`、
`rogue_profile_migration 113/0`、`rogue_build_progression 717/0`、`roguelike_seven_rooms 11832/0`、
`rogue_ui 161/0`、`rogue_room_ui 32/0`、`rogue_boss_phase2 406/0`、`rogue_boss_pool 2305/0`、
`roguelike_bosses 1462/0`。

**既存红（与本轮无关，未改）**：`roguelike_routes 5220/2`（长房分支可行走的几何断言）、`boss_tactics 186/1`、
`rogue_equipment`（`tests\rogue_equipment.gd:29` 用 `.passive` 硬访问一个不存在的字段——它测的是被废弃的遗留 API）。

## 6. 建议下一步（未做）

- `tests/rogue_equipment.gd` 应当**按真实实现重写**（改成驱动 `gear(p,N)`/`engraving(p,N)` 的行为断言），
  否则它会继续把「被动没实现」的错误结论带给下一个读代码的人。本轮未动它（派单要求不修既存红）。
- E029 / E018 的两处文档-代码偏差需要设计裁决：是改代码还是改文档。
- 建议给 `tools/check_class_cache.ps1` 增加一条「项目内出现重复 `class_name` 就报错」的检查，
  从机制上防止 §1 那种污染再次发生。