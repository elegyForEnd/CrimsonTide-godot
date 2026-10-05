# 魔境扩展 · 测试基线（R1 实测登记）

- **测量轮次**：R1
- **测量时间**：2026-10-05 19:27–19:36（下表的 `.out/.err` 文件 mtime 即逐条时间戳）
- **引擎**：`D:\game\CrimsonTide-godot\Godot_v4.7.2-stable_win64_console.exe`
  （`Godot Engine v4.7.2.stable.official.ed1daf0bf`，**不在 PATH**）
- **统一命令模板**（工作目录＝仓库根 `D:\game\CrimsonTide-godot`）：

  ```
  & "D:\game\CrimsonTide-godot\Godot_v4.7.2-stable_win64_console.exe" `
      --headless --path . --script tests/<name>.gd
  ```

  执行方式：`Start-Process -PassThru -NoNewWindow` + `WaitForExit(180000)`，单条 **180s 上限**，超时即杀
  （`run_all_tests.ps1` 用的是 60s；计划 §4.4 建议的 `--quit-after 600` **本次未使用**，
  因为本仓库测试是 `extends SceneTree` 自管退出，加它会改变退出时机）。
- **原始日志**：`build\r1-baseline\<name>.out.txt` / `<name>.err.txt`（stdout/stderr 分离），
  `rogue_build_rules` 的复核重跑：`build\r1-baseline\rules-rerun.out.txt` / `.err.txt`。
- **被测源码指纹**（SHA256 前 16 位，供"哪一份代码跑出的基线"取证）：
  `session.gd 83A51B7B44350A83` / `roguelike.gd 95A639F030A9247B` /
  `profile.gd BA94FEB95397A22E` / `rogue_combat.gd 8148879232C1DA9F`

---

## 0. ⚠ 两条必须先读的口径说明

### 0.1 并发任务污染（`combat`/`enemy_body`/`boss_tactics` 记为**临时值**）

测量期间并发"敌人弹幕视觉"任务正在写 G 集合（见 `ROGUE-CONTRACTS.md` §8）。实测证据：

| 文件 | LastWriteTime |
| --- | --- |
| `scripts/effect_semantics.gd` | 19:27:45 |
| `scripts/boss_effect_staging.gd` | 19:27:22 |
| `scripts/rogue_enemy_vfx.gd` | 19:27:42 |
| `scripts/boss_damage_visual.gd` | 19:27:58 |
| `scripts/combat_visuals.gd` | **19:33:38** |
| `boss_tactics` 用例运行时刻 | **19:35:03** |

`git status` 确认被改：`battlefield.gd`、`boss_damage_visual.gd`、`boss_effect_staging.gd`、`boss_vfx.gd`、
`combat_visuals.gd`、`effect_semantics.gd`、`rogue_enemy_vfx.gd`、`resources/boss_damage_shape.gdshader`、
`resources/boss_entity_birth.gdshader`；新增未跟踪：`scripts/attack_telegraph.gd`、`tests/attack_telegraph_visual.gd`。
**`scripts/session.gd` 与 `scripts/rogue_combat.gd` 未被修改**（不在 `git status` 里）。

→ 因此 `combat` / `enemy_body` / `boss_tactics` 三个数字**只是临时值**，必须等该任务落定后复测并正式登记。
其余 `rogue_build_*` / `roguelike_*` / `systems` / `expedition` 按**正式基线**记录。

### 0.2 被测资产的硬前提（决定 `*_rules` / `*_pack` 能不能绿）

`assets/rogue/build/` 是被 `.gitignore` 忽略的**生成物目录**（实测 `git check-ignore -v
assets/rogue/build/atlas-manifest.json` → `.gitignore:2: build/`），本工作副本里**只有占位文件**
（`assets/rogue/build/PLACEHOLDER-README.txt`，创建于 2026-10-05 18:21:40/18:44:39）：

```
atlas-manifest.json  7 字节  → 内容就是 {}
jump-manifest.json   7 字节  → 内容就是 {}
blood-flask-v1.png   2.8 MB  → 从 assets/rogue/crystal.png 复制的占位图
```

`generation-record.json` **不存在**，目录里只有 **1 个 PNG**（占位图）。
→ `tools/index_rogue_build_art.py`（第 7 行读 `generation-record.json`，第 34 行 `assert len(regions)==252`）
**当前无法运行**，所以"252 个图标"这件事在本工作副本里**不可能满足**。
→ 这是 `rogue_build_rules` / `rogue_build_pack` 变红的根因，**不是代码 bug**（详见 §3）。
→ 修复路径（**已在 README 中写明，R1 未执行**，因为 R1 禁止改文件）：
`python tools/build_rogue_content.py` → `python tools/index_rogue_build_art.py` → `python tools/index_rogue_jump_art.py`
（需要先有真实生成物；工作副本里没有，故可能需要重跑 `tools/plan_rogue_build_art.py` + 图像生成步骤。）

---

## 1. 基线总表

| # | 测试 | checks | failures | 退出/超时 | 口径 | 原始日志 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `rogue_build_growth` | **4066** | **0** | 正常退出 | 正式 | `build/r1-baseline/rogue_build_growth.out.txt` |
| 2 | `rogue_build_system` | **440** | **0** | 正常退出 | 正式 | `.../rogue_build_system.out.txt` |
| 3 | `rogue_build_progression` | **505** | **39** | 正常退出（exit 1） | 正式 | `.../rogue_build_progression.err.txt` |
| 4 | `rogue_build_rules` | **1**（有效） | **1**（已红） | **超时被杀**（180s/60s 两次均未退出） | 正式（但覆盖为零，见 §3） | `.../rogue_build_rules.err.txt`、`rules-rerun.err.txt` |
| 5 | `rogue_build_pack` | —（无汇总行） | 1 条 `push_error` | **exit=1，耗时 8s** | 正式（资产红） | `.../rogue_build_pack.err.txt` |
| 6 | `roguelike_seven_rooms` | **1856** | **0** | 正常退出 | 正式 | `.../roguelike_seven_rooms.out.txt` |
| 7 | `roguelike_routes` | **5219** | **5** | 正常退出 | 正式 | `.../roguelike_routes.err.txt` |
| 8 | `roguelike_network` | —（无汇总行） | 1 条 `ERROR`（超时） | 正常退出 | 正式（**需多进程参数**） | `.../roguelike_network.err.txt` |
| 9 | `rogue_build_network` | —（无汇总行） | 1 条 `ERROR`（超时） | 正常退出 | 正式（**需多进程参数**） | `.../rogue_build_network.err.txt` |
| 10 | `combat` | **78** | **0** | 正常退出 | **临时值** | `.../combat.out.txt` |
| 11 | `enemy_body` | **379** | **0** | 正常退出 | **临时值** | `.../enemy_body.out.txt` |
| 12 | `boss_tactics` | **186** | **1** | 正常退出 | **临时值** | `.../boss_tactics.err.txt` |
| 13 | `systems` | **10812** | **0** | 正常退出 | 正式 | `.../systems.out.txt` |
| 14 | `expedition` | **79** | **0** | 正常退出 | 正式 | `.../expedition.out.txt` |

**汇总**：正式口径下 **已红 = 6 个测试**（`rogue_build_progression` 39、`roguelike_routes` 5、
`rogue_build_rules` 1 且挂死、`rogue_build_pack` 1、两个 network 各 1 条超时 ERROR）；
临时口径下再加 `boss_tactics` 1。
**新增失败=0 的门禁必须以本表 §1 的"已红集合"为差集基准**，不得以"全绿"为目标。

---

## 2. 失败断言清单（原文 + 行号，逐条实测）

### 2.1 `rogue_build_progression`（505 / 39，`tests/rogue_build_progression.gd`）

| 次数 | 断言原文 | 断言行号 | 判定 |
| --- | --- | --- | --- |
| 10 | `Every possible route must enter the first sanctuary` | **:33** | 陈旧断言（描述"每层 5 区 + 首区必为圣坛"年代；现 `route[0]=="combat"`，`roguelike.gd:59`） |
| 10 | `Two combat areas remain guaranteed` | **:35** | 陈旧断言（旧模板假设） |
| 8 | `Fourth area offers supplies or a second sanctuary` | **:37** | 陈旧断言（旧模板假设） |
| 7 | `Every floor has one or two sanctuaries` | **:101** | 陈旧断言（随圣坛房数量变化） |
| 2 | `Dedicated-room total choices are personal` | **:102** | 陈旧断言（`14*count` 由"两座圣坛各两轮"推出） |
| 2 | `Five complete floors /25 rooms` | **:100** | **旧数值**：实际 `AREAS_PER_FLOOR := 7`（`roguelike.gd:11`）→ 每层 7 区、共 **35** 区 |
| — | 合计 39 | — | 与 `505 checks / 39 failures` 完全对齐 |

> 归零责任：计划 §4.1 已定性为"旧设计断言"，归属 **R5**（节点图接管推进后统一移植）。
> 注意：`:100/:101/:102` 三条是**数值**过期，`:33/:35/:37` 三条是**模板**过期，移植时必须分开处理。

### 2.2 `roguelike_routes`（5219 / 5，`tests/roguelike_routes.gd`）

| 次数 | 断言原文 | 断言行号 |
| --- | --- | --- |
| 1 | `Challenge gate keeps required floor guardian` | **:40** |
| 1 | `Challenge guardian has advertised health` | **:48** |
| 1 | `Floor transition supports shop route` | **:54** |
| 2 | `Player can walk continuously along each branch in long and compact rooms` | **:88** |

> 计划 §4.1 已定性：前 3 条与两阶段/挑战规则耦合，后 2 条是**几何回归**。
> **R1 判定建议**：后 2 条（`:88`）若在 R5 后**数字发生变化**，说明动到了 `rogue_map.configure`/`region_key`
> 的 ground profile（`rogue_map.gd:74`），须立即回滚该映射，而不是改断言。

### 2.3 `rogue_build_rules`（**挂死**，`tests/rogue_build_rules.gd`）

原始 stderr（两次运行完全一致）：

```
ERROR: Painted icon exists: W001
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] check (res://tests/rogue_build_rules.gd:13)
       [1] run (res://tests/rogue_build_rules.gd:50)
SCRIPT ERROR: Invalid access to property or key 'atlas' on a base object of type 'Nil'.
   at: run (res://tests/rogue_build_rules.gd:51)
```

**机理（R1 结论，比计划文档更严重）**：

1. `:50` 的 `check(icon!=null, ...)` 是**该用例的第 1 个 check**（`run()` 第 44 行 `reset()` 之后直接进图标循环，
   之前没有任何 check）。
2. `Art.icon("W001")` 返回 `null` → 第 51 行 `str(icon.atlas...)` **脚本级崩溃**。
3. 崩溃发生在 `run()` 内部 → 第 157 行的 `quit(...)` 永不执行 → `SceneTree` 空转 →
   **进程永不退出**（180s 与 60s 两次都被超时杀掉）。
4. ⇒ 该文件里后续 **126+ 个断言从未跑过**，`rogue_build_rules` 目前 **有效覆盖＝0，
   不能作为任何轮次的回归依据**。

### 2.4 `rogue_build_pack`（exit=1，`tests/rogue_build_pack.gd`）

```
ERROR: Missing exported icon W001
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] run (res://tests/rogue_build_pack.gd:31)
```

两次运行（180s 批次 + 4.2 节复核）**结果一致**：exit=1、耗时 8s、**只有这一条 ERROR**。

### 2.5 两个 network 用例（需多进程参数）

```
roguelike_network.err.txt : ERROR: network timeout at stage 0
       [0] check (res://tests/roguelike_network.gd:19)
       [1] _process (res://tests/roguelike_network.gd:35)
rogue_build_network.err.txt : ERROR: Network timeout at stage0
       [0] check (res://tests/rogue_build_network.gd:16)
       [1] _process (res://tests/rogue_build_network.gd:30)
```

两者都**不打印 checks/failures 汇总行**（无最后 print），单跑只会在 stage0 超时。
计划 §3.2 R19 的正确跑法是 `-- --server --four` 多进程；**单进程跑出来的这 2 条 ERROR 不能算回归**，
但必须登记为"单跑已知噪声"，否则 R18 的"新增失败=0"会被它误伤。

### 2.6 `boss_tactics`（186 / 1，**临时值**）

```
ERROR: Real projectile collision uses frontal guard once
       [0] check (res://tests/boss_tactics.gd:10)
       [1] run (res://tests/boss_tactics.gd:180)
```

`:178-180` 构造的是**玩家子弹**（`owner:1`、`weapon:0`）打"正面格挡"，断言格挡伤害恰为 3 且子弹被消耗。
该用例与敌人弹幕**视觉**无直接关系，且 `rogue_combat.gd`/`session.gd` 均未被并发任务修改
（见 §0.1）→ **很可能是既存红**。但 R1 不能排除并发任务影响，故标记临时值，
**R6/R14 动 `rogue_combat.gd` 之前必须复测一次并正式登记**。

---

## 3. 与计划文档（`output/ROGUE-EXPANSION-EXECUTION-PLAN.md`）的不一致清单

| # | 计划文档写 | R1 实测 | 处理 |
| --- | --- | --- | --- |
| D1 | §0 `rogue_build_growth` 4066/0，样本 `[213, 500]` | **完全一致** | 采纳 |
| D2 | §0 `rogue_build_system` 440/0 | **完全一致** | 采纳 |
| D3 | §0 `roguelike_seven_rooms` 1856/0 | **完全一致** | 采纳 |
| D4 | §0 `roguelike_routes` 5219/5 | **完全一致**（另给出 4 条断言的行号） | 采纳并补行号 |
| D5 | §0 `rogue_build_progression` 505/39 | **完全一致**（另给出 6 组断言的次数分解） | 采纳并补分解 |
| D6 | §0 说 progression 是"每层 5 区年代的 6 组陈旧断言" | 一致；但其中 **2 条是纯数值过期**（`:100` 25→35 区、`:102` 14×count），可独立先修 | 补注 |
| D7 | §0 `rogue_build_rules` = "1 failure + SCRIPT ERROR" | **结论对，量级低估**：崩溃点就是第 1 个 check，脚本不 `quit()` → **进程挂死、后续 126+ 断言零执行** | **更正**（见 §2.3，且已写入契约 C5） |
| D8 | §0 `rogue_build_pack` = **2 failures**（`Failed to load script main.gd "Compilation failed"` + `Missing exported icon W001`） | **实测只有 1 条 ERROR**（`Missing exported icon W001`，`pack.gd:31`），exit=1/8s，**没有编译错误**；全仓库搜索 `Compilation failed` 只命中计划文档自身（3 处），**没有任何日志/产物佐证** | **更正**（见 §4） |
| D9 | §0 `roguelike_network` / `rogue_build_network` = "0 errors" | 单进程跑**各 1 条 ERROR**（stage0 超时）；需 `-- --server --four` 才真正跑 | **更正**：登记为"单跑噪声" |
| D10 | §0 未登记 `combat`/`enemy_body`/`boss_tactics`/`systems`/`expedition` 基线 | 实测 78/0、379/0、186/**1**、10812/0、79/0；其中 `boss_tactics` **已红 1** | **补登**（`boss_tactics` 标临时值） |
| D11 | §4.2 回归红线列 `tests/combat.gd`(78/0)、`tests/expedition.gd`(79/0) | 一致 | 采纳 |
| D12 | §0 "会话/服务端行号"校验（`session.gd:1467`、`:1487`、`:1505`；`profile.gd:31/37-39`；`app.py:409/420-431`） | **全部逐条复核为真**（另有 `online_service.gd:65/74-82` 为真） | 采纳 |
| D13 | §0 `rogue_map.configure:95` 的 `assert(joined.size()==1,...)` | 实测在 `rogue_map.gd:94-95`（`merge_polygons` 在 `:94`） | 微调行号 |
| D14 | §0/§4.1 `rogue_combat.gd` 的 `boss_enraged` 在 `:205-209` | 实测一致（`:205 if not e.boss_enraged and e.hp<=e.max_hp*0.5`、`:206 e.boss_enraged=true`） | 采纳 |
| D15 | §0 说 `assets/rogue/build/` 缺失导致 `main.gd` 编译失败 | **机制成立且已定位**：`PLACEHOLDER-README.txt` 明说该目录被 gitignore、从未提交、缺文件会导致 `main.gd` 编译失败；静态链路证实 `main.gd:163` `preload(rogue_field.gd)` → `rogue_field.gd:12` `preload(rogue_art.gd)` → `rogue_art.gd:4` **`preload("res://assets/rogue/build/blood-flask-v1.png")`**（`preload` 缺失＝编译期错误）。**2026-10-05 18:21:40 起已被占位文件遮蔽**，所以现在编译正常 | **更正为"当时为真、现已被占位文件遮蔽"**，并列入 §3 的硬前提 |

---

## 4. 定向复核结论：`scripts/main.gd` 能不能编译？

**结论：能。`main.gd` 当前编译通过，`rogue_build_pack` 里那条 "Compilation failed" 在本工作副本已不可复现。**

复现命令与原始输出（工作目录＝仓库根）：

```
> & "D:\game\CrimsonTide-godot\Godot_v4.7.2-stable_win64_console.exe" `
      --headless --path . --check-only --script scripts/main.gd
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
exit=0                      ← 无任何 ERROR/SCRIPT ERROR

> & ... --headless --path . --check-only --script scripts/session.gd
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
exit=0

> & ... --headless --path . --quit-after 3        # 载入 boot 场景与 autoload
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
exit=0
```

**行为级证据（比 `--check-only` 更强）**：`tests/rogue_build_pack.gd` 在 headless 下

- `:8` `load("res://scenes/main.tscn").instantiate()` **成功**，
- `:10-14` `app.session.solo(...)` + `app.session.launch(false,512)` + `rogue_selection_take` + `tick()` **全部执行成功**，
- `:16-30` `rogue_build_ui.gd` 的 5 个页签、`rogue_build_art.gd`/`rogue_content.gd` 也加载成功，
- 直到 `:31` 才因 **252 图标缺失**（`art.icon("W001")==null`）而 `quit(1)`。

若 `main.gd` 真的编译失败，`:8/:10` 就会立刻炸，不可能跑到 `:31`。

**那计划文档为什么会看到它**：因为 `assets/rogue/build/` 被 `.gitignore`（`.gitignore:2: build/`）忽略、
从未提交，缺文件时 `rogue_art.gd:4` 的 `preload` 是**编译期**错误，会顺着
`main.gd:163 → rogue_field.gd:12 → rogue_art.gd:4` 把 `main.gd` 一起拖成 "Compilation failed"。
本工作副本在 **18:21:40** 被放入了占位 `blood-flask-v1.png` + `{}` 两个 manifest，这个症状就被遮蔽了。

**对后续轮次的影响（必须写进验收前提）**：

1. `main.gd` 的"能编译"**依赖于未提交的占位文件**。任何 `git clean -fdx` / 换新克隆 / 清理
   `assets/rogue/build/` 的操作都会让 `main.gd` 再次编译失败 → **全部测试一起红**。
   这是本仓库最脆弱的一环，验收报告里必须声明当次工作副本的该目录状态。
2. 但"能编译"≠"肉鸽美术可用"：manifest 是 `{}` → `Art.icon(任意 id) == null`
   → `rogue_build_rules` 崩溃挂死、`rogue_build_pack` exit 1。**这两条在恢复真实生成物之前不可能变绿**。
3. 因此计划 §4.4 的门禁必须把 `rogue_build_rules` / `rogue_build_pack` 列为**豁免项**
   （登记为既存红、且规则测试当前零覆盖），而不是"待修绿"。

---

## 5. 每轮门禁用法（替代"全绿"，与计划 §4.4 对齐）

```powershell
# 1) 本轮定向测试（单条，180s 上限；注意 rules 会挂死，复测时给 60s 上限并接受 TIMEOUT）
& "D:\game\CrimsonTide-godot\Godot_v4.7.2-stable_win64_console.exe" `
    --headless --path . --script tests/<本轮测试>.gd

# 2) 回归红线（正式基线，必须是"数字与 §1 完全一致"）
#    rogue_build_growth 4066/0、rogue_build_system 440/0、roguelike_seven_rooms 1856/0、
#    systems 10812/0、expedition 79/0

# 3) 每 3~4 轮全量：tools/run_all_tests.ps1 → build/exp-report-runs.txt
#    判定规则：报告中 failures>0 的测试集合 ⊆ §1 已红集合（progression, routes, rules, pack）
#    且新增测试全绿。visual 类必须以 _visual 结尾才会走窗口模式。
```

**豁免/噪声清单（不得计入"新增失败"）**：
`rogue_build_progression`(39)、`roguelike_routes`(5)、`rogue_build_rules`(挂死)、`rogue_build_pack`(资产)、
`roguelike_network`/`rogue_build_network` 单跑时的各 1 条 stage0 超时、
以及渲染任务落定前的 `combat`/`enemy_body`/`boss_tactics` 临时值。

**已知噪声的处置责任轮次**：
`progression`/`routes` → R5；`rules`/`pack` → R18（或在此之前明确豁免）；
`boss_tactics` → 渲染任务落定后立即复测，若仍红则归 R6/R14 处理。
