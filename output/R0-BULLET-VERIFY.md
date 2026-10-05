# R0 · 敌人弹幕可读性改动 · 独立对抗性复核

复核对象：子智能体「默认路线：敌人弹幕视觉放大加显眼」的自述报告（无编号文档，仅回传正文）。
复核人：独立子会话（未参与该改动，未读取其推理过程）。
复核时间：本工作副本当时状态；HEAD = `b034286 feat: 更新肉鸽玩法、家园系统、战斗动画与游戏素材`（2026-10-05 17:05:24）。
**本报告只做了取证与判定，没有修改任何源码 / 测试 / 既有 md。** 唯一新建文件是本报告；对比用的 HEAD 副本与截图裁剪件写在 `build\r0-verify\`（该目录本来就在 `.gitignore` 里），清单见文末。

> 重要前提：这是一个**多写者并发**的工作副本。当时同时在改的有 R2/R5（`session.gd`/`roguelike.gd`/`profile.gd`）、R6（`rogue_combat.gd`/`boss_choreography.gd`）、以及一套**先于本次会话存在**的未提交改动（见第 8 条）。所以"改动没碰判定"这句话必须**按文件归属**去判，不能拿整棵树的 diff 一概而论。

---

## 一、结论表

| # | 被核验主张 | 认定 | 关键证据 | 反例 / 不确定点 |
|---|---|---|---|---|
| 1 | 命中判定几何零变化：`session.gd` 仍是 `float(b.get("hit_radius",18.0))`、`boss_choreography.gd` 仍是 `"hit_radius":18.0`；未改伤害/弹速/弹数/发射逻辑 | **认定（判定几何部分）；带保留（"未改伤害/弹速"只对弹幕任务自己的文件成立）** | `session.gd:3438` 现文 = `...<float(b.get("hit_radius",18.0))`，且该行**不在** `git diff -- scripts/session.gd` 的 4 处改动里（该 diff 只有 3 行注释 + `var rogue_graph` + `ruins.configure(...)` 的房间名白名单）；`boss_choreography.gd:496` 新旧值都是 `"hit_radius":18.0`（diff 的 `-`/`+` 成对行里都含该项，只有 `speed` 换成 `shot_speed`） | 并发轮次 R6 在 `rogue_combat.gd`/`boss_choreography.gd` 里**确实**动了伤害/弹速（深渊变数钩子：`+bullet_visual`、`shot_speed`），但那是 R6 的任务，不是弹幕任务；弹幕任务自己的文件（G 集合）里没有任何 `bullets.append/erase`、`damage`、`spawn` 改动 |
| 1b | 弹幕任务没有碰 `session.gd`/`rogue_combat.gd`/`roguelike.gd`/`profile.gd` | **认定** | 这四个文件的改动 hunk 逐条看：`session.gd` = R2 的 `var rogue_graph` + R5 的房间名谓词；`roguelike.gd`/`profile.gd` = R2/R3/R5；`rogue_combat.gd`/`boss_choreography.gd` = R6（变数倍率、Boss 二阶段、`bullet_visual`）。四处均与"渲染描边/光晕/拖尾"无关 | 无法从 diff 单独证明"是谁按键写下的"，只能证明**内容与弹幕渲染无关**；结合时间戳（这些文件写入时间落在 R2/R5/R6 的活动窗口）判定归属成立 |
| 2 | 玩家子弹路径逐字未变；`stamp()` 新增 `alpha=-1.0` 默认值不影响其它调用 | **认定（结论），但报告的"12 处调用"计数有误** | 当前 `combat_visuals.gd:409-415` 与 `HEAD:combat_visuals.gd:356-362` **逐字相同**，且这些行不在 diff 中；`stamp()` 实现改为 `clampf(tint.a*1.5,0,1) if alpha<0.0 else alpha`，默认 `-1.0` 时与旧式完全等价；`combat_visuals.gd` 内共 **4** 处 `stamp(` 调用（354/355/359/403）全部使用默认值 | **"其它 12 处调用"实测不成立**：`combat_visuals.gd` 内只有 4 处 `stamp(` 调用；`boss_vfx.gd:95` / `boss_cinematic.gd:89` / `ultimate_cinematic.gd:185` 的同名 `stamp` 是各自文件的独立方法。全仓库 `\.stamp\(` 命中 **0** 处 → `CombatVisuals.stamp` 没有跨文件调用者。计数错，结论对 |
| 3 | 确实变大变显眼，且量级如报告所述（bbox 412×800、旧 13.7×26.6px、新 24.6×47.8px） | **认定（数字逐位复现）** | 我自己用 PIL 量：native 1024×1024；alpha bbox = `(540,101,952,901)` = **412×800**；a≥160 核心 = `(551,478,942,897)` = **391×419**；`vfx_library.gd:49-51` `fitted_size` = `native*min(bx/nx,by/ny)`（等比）。旧框 65×34 → 拟合 34.0×34.0 → ink **13.68×26.56**；新框 117×61.2 → 拟合 61.2×61.2 → ink **24.62×47.81**。线性 1.8× | 报告的**因果解释错**：它说"旧弹体是命中后才渐显、因为 `coverage()` 吃了一个没人写的 `visual_age`"。实测 HEAD 的敌人分支是 `stamp(2,bullet.p,Vector2(65,34),...,Color(1,.5,.6))`（`HEAD:combat_visuals.gd:364`），**根本没有 coverage**；`visual_age` 在 HEAD 与工作区里**只出现一次**（`combat_visuals.gd:415`／HEAD:362，玩家分支），且**全仓库没有任何写入者**。→ "去掉渐显"实际是**空操作**，变大变亮靠的是尺寸与配色改动 |
| 3b | 出生即完整可见 | **认定（就新代码而言）** | `draw_enemy_bolt()` 的 body/halo/trail 均不含 age 输入，body 用固定 `ENEMY_BOLT_CORE` 全 alpha 绘制 | 同上：这是"保持"而非"修复"，旧代码本来也不是渐显 |
| 4 | 公平性：36px 判定圈"看得出来"，超出部分是低 alpha 光晕 | **部分认定 → 倾向否定"判定圈看得出来"** | 我自己算的各层（新尺寸）：实心 body ink **24.6×47.8px**；暗色描边层 = 61.2×1.24 → ink **30.5×59.3px**；光晕 `reach=61.2/2=30.6`，外圈半径 **56.6px（Ø113.2）** alpha .14、内圈 **Ø79.2** alpha .18；拖尾 3 段在 **18.4 / 36.7 / 55.1px** 之后，尺寸 44.1 框 → ink 17.7×34.4，alpha .42/.28/.14。判定圈 **Ø36**。→ 横向 24.6 < 36；纵向 47.8 = 1.33×；**光晕 Ø113.2 = 3.14×** | 光晕 alpha 虽低（.14/.18），但在实机截图里它就是**最显眼的形状**（见第五节的观感）；而"实心 body = 判定圈"并不成立：body 本来就是为了发光的白色星芒图（`common_2.png` 是白色星形/火花素材），配 `ENEMY_BOLT_CORE=#ffb3c0`（近白粉）→ 在浅色石板上对比度很低，真正抢眼的是那层 Ø113 的淡粉光盘。**没有哪一层等于 36px**，"看到什么就吃到什么"未被满足 |
| 5 | 测试数字：combat 78/0、enemy_body 379/0、effect_semantics 1365/0、boss_effect_staging 246/0、systems 10812/0 | **认定（我自己复跑，逐项一致）** | 见第二节原始尾行 | 无 |
| 6 | `boss_tactics` 的 1 条失败是既存红 | **倾向认定"不是弹幕改动引入"；但"是否在我方所有改动之前就红"无法用非破坏手段确证** | 失败断言 `boss_tactics.gd:180`「Real projectile collision uses frontal guard once」走的是 `s.update_bullets()`（在 `session.gd`，**该函数不在 diff 中**）+ `boss_tactics.gd`（**该文件不在 diff 中**）。整条路径上的代码与 HEAD 逐字一致 | 报告说它用 `git stash` 复现过基线——我**无权也无法**独立复核该实验（stash 会破坏并发轮次，被禁止）；我只能证明"弹幕改动不可能引入它"（渲染改动不在该路径上），不能证明"在我方全部改动之前就存在"。R1 的基线在 19:35 就已测得 186/1，可作为旁证 |
| 8 | `combat_visuals.gd` 里的 `Telegraph` 预载 / `Telegraph.tint()` / 粒子数量翻倍 / `trauma` 震屏"不是弹幕任务写的" | **认定** | 见第六节：这是一套**先于本会话存在**的未提交改动（18:18–18:44 时间戳 + 自带文档 + 自成完整特性） | 唯一无法用 mtime 单独区分的地方：`combat_visuals.gd` 这个**文件**的 mtime 是 19:47:23（弹幕任务写的），所以它"保留"了那些先行 hunk；但 `ATTACK-TELEGRAPH.md`(18:44:36) 逐字描述了这些 hunk，足以定源 |

---

## 二、我自己跑的原始输出（相对仓库根；引擎 `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/<n>.gd`）

```
combat                 exit=0  1.3s   COMBAT TESTS: 78 checks, 0 failures
enemy_body             exit=0  2.7s   ENEMY BODY: 379 checks, 0 failures
effect_semantics       exit=0  8.9s   EFFECT SEMANTICS 1365 checks / 0 failures
boss_effect_staging    exit=0  0.4s   BOSS EFFECT STAGING 246 checks, 0 failures
boss_tactics           exit=1  1.4s   BOSS TACTICS 186 checks, 1 failures
                                        [0] check (res://tests/boss_tactics.gd:10)
                                        [1] run (res://tests/boss_tactics.gd:180)
systems                exit=0  9.0s   SYSTEM TESTS: 10812 checks, 0 failures
```
完整日志：`build\r0-verify\<name>.out.txt`。

判定几何取证（原始行）：
```
session.gd:3438: if p.status=="active" and Geometry2D.get_closest_point_to_segment(p.p,old,b.p).distance_to(p.p)<float(b.get("hit_radius",18.0)):
boss_choreography.gd:496: var b := {... ,"hit_radius":18.0, ...}   # diff 的 -/+ 两侧都是 18.0
git diff -- scripts/session.gd  → 仅 4 行：3 行注释 + `var rogue_graph: Dictionary = {}` + ruins.configure(...) 房间名谓词
```

`visual_age` 全仓库取证（HEAD 与工作区各一次）：
```
git grep -n visual_age HEAD -- "*.gd"
  HEAD:scripts/combat_visuals.gd:362: Motion.draw(...,Motion.coverage(float(bullet.get("visual_age",.1)),.3,.03),"forward",...)
工作区：
  scripts/combat_visuals.gd:415:      （上面那行的同一处，属玩家分支）
  tools/verify_enemy_bolt_readability.gd:47,56  （弹幕任务自己的检查脚本里提到它）
→ 没有任何 .gd 给 visual_age 赋值
```
`effect_motion.gd:16-17`：`coverage(age,life,birth)=smoothstep(0,min(birth,life*.40),max(0,age))`；玩家分支传 `age=0.1, birth=.03` → `min=.03` → smoothstep 到 1.0 → **满覆盖**。即：玩家分支也没有渐变，旧敌人弹更没读过这个字段。

---

## 三、我自己算出的像素数字（不依赖对方脚本）

| 项 | 值 |
|---|---|
| `assets/combat/standalone/common_2.png` | 1024×1024；alpha bbox `(540,101,952,901)`；a≥160 核心 `(551,478,942,897)`；a≥64 覆盖 47627px = 4.54%；淡边 16≤a<64 = 1507px = 0.14% |
| `fitted_size` 语义 | `native * min(bx/nx, by/ny)`（等比缩放，`vfx_library.gd:49-51`） |
| 旧框 65×34 | 拟合 34.0×34.0（s=0.0332）→ ink 13.68×26.56px，核心 12.98×13.91px |
| 新框 65×34×1.8 = 117×61.2 | 拟合 61.2×61.2（s=0.0598）→ ink 24.62×47.81px，核心 23.37×25.04px |
| 暗色描边层（×1.24） | 框 75.9 → ink 30.5×59.3px，色 `#4a0512` |
| 光晕层 | `reach=30.6`；外圈半径 56.6（**Ø113.2**）α=.14；内圈 Ø79.2 α=.18，色 `#ff3350` |
| 拖尾 | 3 段，距弹心 18.4 / 36.7 / 55.1px，框 44.1（ink 17.7×34.4），α=.42/.28/.14 |
| 判定圆（不变） | `hit_radius=18` → **Ø36** |
| 比值 | 光晕 3.14×判定圆；内光晕 2.20×；纵向 ink 1.33×；横向 ink 0.68× |
| 亮核偏心 | 核心 bbox 中心 y=687.5 vs ink 中心 y=501 → 偏 186.5 native px → 绘制后 **11.2px**（沿垂直于速度方向偏，因 `+Y` 被 angle 旋转）。11.2 < 18，仍在判定圆内 |

实机像素校验（`enemy-bullets-readability.png`，2304×1440）：4 个淡粉光盘直径约 **175px** ≈ 110 世界像素（×1.6 缩放），与算出的 Ø113.2 一致（误差 <5%）。判定圆在同一画面应约 57.6px → 光盘约为其 **3 倍**。

---

## 四、命中/伤害面复核（针对"没改伤害、弹速、弹数、发射逻辑"）

- 弹幕任务自己改的文件：`combat_visuals.gd`、`effect_semantics.gd`、`rogue_enemy_vfx.gd`、`boss_effect_staging.gd`、`boss_damage_visual.gd`、两个 shader、新增 `resources/boss_projectile_shell.gdshader`。逐个看 diff：只有绘制半径/线宽/颜色/层数/`draw_*` 调用、以及"发光外壳"节点。
- `boss_effect_staging.gd` 从 `inner*2.0` 改成 `inner*2.5`：`Staging.pose()` 的**唯一**消费点是 `boss_damage_visual.gd:180`（绘制）；`boss_damage_visual.gd:40` 读的是 `field.session.raid.get("hazards",[]).duplicate()`（**副本**），`:49` 的 `"inner":float(b.get("hit_radius",18))` 是**只读**子弹字典。→ 该改动不可能回写模拟层。
- 全仓库 `\.stamp\(` 无跨文件调用；`effect_semantics.shot()/projectile()` 都是 `target: CanvasItem` 的纯绘制静态函数。
- 结论：**在弹幕任务的文件范围内，"只改表现层"成立**。注意区分：同树里 `rogue_combat.gd`/`boss_choreography.gd` 出现 `damage`/`shot_speed`/`bullet_visual` 改动，那是 R6 的深渊变数钩子（有 `BULLET_SPEED_BOUNDS`/`BULLET_VISUAL_BOUNDS` 钳制，且断言要求判定字段不变），不属于本次核验对象。

---

## 五、4 张截图：我实际看到了什么

1. **`build/enemy-bullets-readability.png`（2304×1440，搜打撤「风铃原野·血月之夜」）**
   场景中央是玩家；上方一排**均匀间隔的 4 个淡粉色柔光盘**（直径约 175px），每个盘中心有**白色星芒**；最左那个盘上还压着一段**暗枣红色胶囊状墨影**（描边层）。画面最左侧另有一条**淡蓝色长条弹体**（按 `tools/preview_enemy_bullets.gd:45-47`，那是走 Boss shader 管线的 `boss_projectile`（`art_key:"knight"`/`vfx_role:"lance"`），不是普通敌弹）。
   判断：**普通敌弹确实一眼可见、再也不是"细针"**；但观感上更像"地上摊开的淡粉光盘/花"，而不是"飞行的红色弹丸"——因为 `common_2.png` 是白色**星芒**素材，配 `#ffb3c0` 近白粉，在浅色石板上对比度低；真正抢眼的是 Ø113 的淡粉光盘。4 个盘的位置（间隔 140 世界像素）与预览脚本 stage 的 4 发普通弹完全对应，可确认为普通敌弹。
2. **`build/enemy-bullets-readability-rogue.png`（1280×800，魔境）**
   深色废墟地面上 5 发**颜色各异、形状各异**的矢量弹（青绿/橙/紫/青/红），每发长约 55–70px、粗约 20px，外裹一层半径约 32px 的低 alpha 光晕；形状按 `fx_move` 区分（胶囊、折线、箭头、菱形等）。
   判断：**这张是最有力的正面证据**——深浅背景都清晰、彼此不混淆、与背景装饰（枯树/石墙）分离良好。注意它们的**长轴 ~1.5–1.9× 判定圆**，属"视觉略大于判定"。
3. **`build/enemy-bullets-closeup.png`（900×560，搜打撤局部裁切）**
   同场景局部：左下是那条淡蓝色 Boss 弹体（可见柔和白光描边），上方是粉色光盘边缘。**没有**出现任何**红色高饱和**的敌弹实体；普通敌弹在这个裁切里只剩光盘边缘。
4. **`build/enemy-boss-bolt-closeup.png`（700×420，Boss 弹特写）**
   浅色石板上的淡蓝色长条 Boss 弹（带柔软白晕）+ 两个大的粉色地面盘（与预警同色系的手绘盘）。
   判断：Boss 弹在**浅色地面**上属于"能看见但对比度一般"；它比旧的 2.0×inner 大了 25%，但仍是低饱和淡蓝。**没有"看起来很大其实打不到"的实体误导**（因为它是长条弹体），不过地面粉盘与预警光效同源，长时间对战中可能被读成"危险区域"。

**综合观感**：可读性目标达成（尤其魔境 5 色弹与普通敌弹的"一眼可见"）；但出现两个新的**反向风险**：① 普通敌弹在浅色地形上由"看不见"变成"一整块淡粉光盘"，**视觉体积（Ø113）是判定圈（Ø36）的 3 倍**，且最亮的部分不是弹体核心而是星芒+光盘，玩家可能按光盘外缘做走位；② 它与地面预警/爆闪的"淡盘+白色放射"语言高度同源，风格上更像地面危险区而不是飞行物。

---

## 六、第 8 条：`Telegraph` 那批改动到底是谁写的

**我认定：它们属于一套先于本会话存在、且与本次弹幕任务无关的未提交特性「敌人攻击预警 · Attack Telegraph」。依据如下：**

| 证据 | 内容 |
|---|---|
| 时间戳（`Get-Item ... LastWriteTime`） | `scripts\battlefield.gd` **18:18:51**、`scripts\boss_vfx.gd` **18:19:16**、`scripts\attack_telegraph.gd` **18:21:03**、`tests\attack_telegraph_visual.gd` **18:22:12**、`ATTACK-TELEGRAPH.md` **18:44:36**。而本会话第一个委派（弹幕任务与计划任务）发生在 **19:2x**，弹幕任务自己的产物时间戳是 19:25:49 / 19:33 / 19:45 / 19:47 / 20:03。**18:18–18:44 这一串早于本会话任何子智能体。** |
| 文档自证 | `ATTACK-TELEGRAPH.md`（18:44:36，`??` 未跟踪）第 31–32 行逐字写着："`combat_visuals.gd` 的聚气/释放粒子改用同一套危险色，**粒子数量翻倍**，并补一层白色核心爆发；释放时按与本机镜头的距离给一次轻微震屏（`combat.trauma`，**0.14 / 0.22 / 0.30**）"——这正是 `combat_visuals.gd` diff 里那几处 hunk（`particles.start` 24,25→32,44；`burst` 18/11→30/20 + 白色 spark；`kick` 0.30/0.22/0.14）。 |
| 自成完整特性 | `attack_telegraph.gd`(16.5KB) + `battlefield.gd` 的"danger pass"重写（删掉 17 个种族各自的手绘预警、改调 `telegraph.paint()`）+ `boss_vfx.gd` 的 `hazard()` 呼吸/白炽芯线 + 一个专门的视觉验收用例 + 一份 58 行设计说明。这不是弹幕任务能顺手写出来并"顺带"文档化的东西。 |
| 弹幕任务自述 | 它列的改动面里**没有** `attack_telegraph.gd`/`battlefield.gd`/`boss_vfx.gd`/`ATTACK-TELEGRAPH.md`；本次复核也未见它在这几个文件上有写入痕迹（`boss_vfx.gd` 的 mtime 停在 18:19）。 |

**归属订正**（给上层记账用）：`scripts/battlefield.gd`、`scripts/boss_vfx.gd`、`scripts/attack_telegraph.gd`、`tests/attack_telegraph_visual.gd`、`ATTACK-TELEGRAPH.md` 应记为**会话前既存未提交工作**；合约里把它们划给"W7 弹幕视觉任务"是不准确的（虽然确实是表现层，但不是本轮产物）。

**无法确定的部分**：`combat_visuals.gd` 里 `const Telegraph = preload(...)` 等 hunk 究竟是谁在**哪一次写入**加进去的——该文件 19:47:23 被弹幕任务重写，mtime 无法回溯；但既然这些 hunk 的内容与 18:44 的文档逐条对应、且只对**预警粒子/震屏**生效，我判定它们来自那套先行特性，弹幕任务只是**保留**了它们（这一点它自述也说"不是我写的"）。

---

## 七、剩余风险与我没能核实的部分

1. **普通敌弹的光晕过大（Ø113 vs 判定 Ø36）**：这是我认为**该回炉或至少记录**的一点。建议二选一：把 `ENEMY_BOLT_HALO` 从 1.85 降到 ≈1.2–1.35（光晕 Ø73–83，约 2× 判定圈），或把实心 body 换成"实心内核 ≈ 判定圈 + 淡描边"的构图，让"看到什么就吃到什么"成立。
2. **浅色地形对比度**：body 用 `#ffb3c0` 近白粉，在浅色石板上主要靠 `#4a0512` 描边撑轮廓。我没有做**逐像素对比度统计**，只有观感判断；若要把"深浅背景都清晰"变成可验收指标，需要新增一个按背景亮度分层的对比度断言。
3. **"不可见即不可命中"**：弹幕会被墙体遮挡（截图 1 中最左盘被墙压住），而墙体**不阻挡伤害**（`ATTACK-TELEGRAPH.md` 已在"已知取舍"里承认这是引擎层既有表现）。本次改动**没有**让这个问题变好或变坏，但它与"看得清就躲得掉"的目标直接冲突，值得单独立项。
4. **截图证据的完整性**：4 张图能证明"魔境 5 色弹清晰""普通敌弹变成大淡粉光盘"，但**没有一张包含"普通敌弹 + 地面预警同框"**的画面，因此"新弹幕会不会被误读成地面预警"只能算我的**推断**，未实证。建议补一张同框图（把预警与飞行中的普通敌弹放进同一帧）。
5. **`boss_tactics` 既存红**：我证明的是"弹幕改动不可能引入它"（该断言路径上的 `session.update_bullets()`、`tests/boss_tactics.gd` 都不在 diff 中）；"在我方全部改动之前就存在"我**没有**独立复核（禁止 stash），只有 R1 在 19:35 的基线 186/1 作为旁证。
6. **报告里两处不实描述**（不影响结果，但会影响后续维护者）：
   - "旧弹体命中后才渐显 / `visual_age` 只在命中时写入" → **错**。`visual_age` 全仓库**无人写入**，且旧敌人分支根本没读它；"去渐显"是空操作。同一错误解释也被写进了**源码注释**（`scripts/combat_visuals.gd:293-298`），建议一并订正。
   - "`stamp()` 其它 12 处调用" → **计数错**，`combat_visuals.gd` 内只有 4 处，全仓库无跨文件调用者。
7. 我**没有**核实的：`boss_damage_shape.gdshader` / `boss_entity_birth.gdshader` / 新增 `boss_projectile_shell.gdshader` 的着色器数值是否与描述一致（只确认了它们被 Boss 弹绘制管线使用、且不参与判定）；也没有测量 Boss 弹在实机中的最终像素尺寸（它走 shader 外壳，静态像素测量不可靠）。

---

## 八、我新建的文件（全部在 `build\r0-verify\`，`.gitignore` 覆盖；无源码/测试/文档改动）

| 文件 | 用途 |
|---|---|
| `build\r0-verify\combat_visuals.HEAD.gd` | `git show HEAD:scripts/combat_visuals.gd` 的副本，用于逐字比对玩家分支 |
| `build\r0-verify\readability-crop.png` | 截图局部 2× 放大（用于看清普通敌弹） |
| `build\r0-verify\rogue-shots-crop.png` | 魔境 5 色弹局部 2× 放大 |
| `build\r0-verify\<test>.out.txt` ×6 | 上面 6 个测试的原始输出 |

`git status --porcelain -- scripts tests resources` 中**没有任何条目属于本次复核**（全部来自并发的 R2/R3/R5/R6/R7 与那套既存的预警特性）。
