# CLASSNAME-GUARD · 重复 class_name 防御 + E029 文案对齐 + rogue_equipment 用例退役重写

轮次记录（由子会话直接执行，未再下委派）。工作目录 `D:\game\CrimsonTide-godot`。

## A. `tools/check_class_cache.ps1`：新增「重复 class_name」硬失败

### 事故背景（本次要防的东西）
验证轮把 HEAD 快照拷贝丢进 gitignore 的 `build/`（例如 `build/triage/head-session.gd`、
`build/r0-verify/combat_visuals.HEAD.gd`），这些拷贝仍然声明 `class_name TideSession` /
`CombatVisuals`。一次 `--import` 就会把**拷贝**登记进
`.godot/global_script_class_cache.cfg`，真实现被静默遮蔽，于是"新接线全都不生效"。
**重建缓存修不了重复**——它只会挑一个赢家，所以必须由脚本拒绝重建并点名冲突路径。

### 新增行为
| 检查 | 行为 | 退出码 |
|---| ---| --- |
| 同名 `class_name` 出现在 >1 个 `*.gd` | 打印「类名 → 所有声明路径」冲突表，**拒绝重建** | **1** |
| 缓存里某类的 `path` 不在 `res://scripts/` 下，**且该类名确有 `res://scripts/` 声明** | 判定为遮蔽特征，打印「类 → 被指到的路径 + 真实声明路径」 | **1** |
| 缓存里某类的 `path` 不在 `res://scripts/` 下，但无同名 `res://scripts/` 声明 | 仅 `[warn]`（informational，不判红） | 0 |
| 原有「缺登记 → 重建」逻辑 | 不变（仅在无重复/无遮蔽时才会重建） | 0 / 2 |

`Get-ClassClaims()` 递归扫描**全项目** `*.gd`（含 `build/`、`output/` 等 gitignore 目录，仅排除
`.godot/`），这正是污染源所在；`Get-CacheEntries()` 按 `{...}` 块解析缓存，逐块取 `"class"` 与 `"path"`。

### 实跑证据
```
$ powershell -NoProfile -ExecutionPolicy Bypass -File tools\check_class_cache.ps1 -ProjectPath . -CheckOnly
[setup] Godot class cache is up to date (32 classes registered).
exit=0
```
**故意注入重复后**（临时创建 `build/_a_task/dup_probe.gd`，内容 `extends RefCounted` + `class_name TideSession`）：
```
[error] 1 class name(s) are declared by more than one script:
  TideSession:
      build/_a_task/dup_probe.gd
      scripts/session.gd
[error] A rebuild cannot fix this - Godot would register whichever copy it loads first,
...
exit=1
```
删除探针后立刻恢复 `exit=0`（探针与夹具已全部删除，`fakeproj=False`）。

**遮蔽分支夹具验证**（`build/_a_task/fakeproj`，用完即删）：
- 缓存 `Foo -> res://scratch/foo_copy.gd` → `[error] ... backed by a script outside res://scripts/`，`exit=1`；
- 缓存 `Foo -> res://scripts/foo.gd` + `Bar -> res://addons/bar.gd` → `[warn] 1 cache entr(ies) live outside res://scripts/`，`exit=0`。

真实缓存现状：**32 条注册路径，0 条落在 `res://scripts/` 之外**（当前无遮蔽）。

## B. E018 / E029 文档-代码偏差

### E018「逐风披肩」——**不存在偏差，无需改动**
派单称"文档写两段效果、代码只实现了移速那半"。实测**两段都已实现**：
- 移速：`scripts/rogue_build.gd:576` `if gear(p,18): grant(p,"speed",18,2,now)`，位于 `if token=="D"`（闪避令牌）分支内 → 「闪避后 2 秒移速 +18」✓
- 移动惩罚：`scripts/session.gd:2863` `... else 1.0 if RogueBuild.gear(p,18) and Catalog.weapon_family(p.weapon)==1 else .8` → 轻刃（family==1）普攻出手时倍率由 `0.8` 变 `1.0`，**恰好是"减少 20 个百分点"** ✓
因此 `ROGUE-BUILD-SYSTEM-DESIGN.md:324` 与代码一致，**未改动**。（同族条目 E055/WC004 负责重刃那一路，措辞风格一致。）

### E029「血契针盘」——**改文案（唯一改动）**
- 代码：`scripts/rogue_build.gd:387` `if blood>=3 and gear(p,29) and ready(s,p,"E029",4): add_status(...)` → **要求目标出血 ≥3 层**。
- 原文档：`普攻命中出血目标，每 4 秒追加出血 1 层`（读起来只要"出血 >0"）。
- 处置：**只改文案**（改代码要动 `scripts/rogue_build.gd`，该文件正被并发轮次修改，按派单走安全路径），并把措辞对齐同表 E030 的写法：
  `| E029 | 血契针盘 | F1 | 普攻命中出血≥3 层的目标，每 4 秒追加出血 1 层 |`（`ROGUE-BUILD-SYSTEM-DESIGN.md:340`）
- 影响：文案成为运行时物品描述（生成器第 49 行 `text=c[3]`），玩家读到的是真实条件；**未改变任何数值与行为**。

### 重新生成与幂等核对
`F:\python\python.exe tools\build_rogue_content.py` → `Compiled 252 entries`。
与改动前的 json 逐条对比：

| 指标 | 结果 |
|---|---|
| 条目总数 | 252（48 武器 / 72 装备 / 96 天赋 / 24 铭刻 / 12 核心） |
| 缺失 / 多余 id | 无 / 无 |
| 变化字段数 | **恰好 1**：`E029.text: 普攻命中出血目标…` → `普攻命中出血≥3 层的目标…` |
| `E018.text` | 未变（与代码一致） |
| `passive` 键 | 仍然不存在（本次未新增字段） |

`tests/rogue_build_rules`（565/0）与 `tests/rogue_build_pack`（exit 0）均通过 → 内容表未被破坏。

## C. `tests/rogue_equipment.gd`：按真实现重写（不再红、不再误导）

### 为什么必须处理
原用例是"被动等于没实现"这个误判的源头：它用**被弃用的遗留 API** `Equipment.damage_multiplier()`
断言 `1.18 / 1.20 / 1.15` 之类的被动倍率，而该函数是惰性桩（恒 `1.0`）；并且硬访问
`Equipment.GEAR[i].passive`，而内容表**从未有 `passive` 键**（本轮再次确认：json 里 `"passive"` 出现 0 次）→ 运行时 `Invalid access`。

真实现是按 **1 基编号**散落在 `scripts/rogue_build.gd` 的 `gear(p,N)`（`:46`）/`engraving(p,N)`（`:51`），
外围接线在 `session.gd` / `roguelike.gd` / `rogue_combat.gd`。行为断言已由 `tests/rogue_passives.gd` 覆盖（21/0）。

### 重写后的三段结构（35 checks）
1. **编号与构造约定**：72 件 `make_gear(i)` 全部产出 `E%03d`（1 基）且 `rogue_id==i`；槽位保持作者设定；`definition()` 全解析；品质只对 `hp/mana/speed` 单调放大、`damage/defense/crit` 保持模板常量；`make_gear` 钳制越界索引与 tier；`engrave()` **不就地修改**原物品、按 `kind` 分流到铭刻池、钳制符文索引。
2. **数学与 session 口径**：空装备贡献 0；`total()` 等于 `items()` 逐件 `value()` 之和；`session.rogue_equipment_stat()` 与 `total()` 同值；`raid.mode="expedition"` 时 session 侧恒 0、而 `total()` 本身与模式无关；属性文本/目录描述含「独特被动」；`has(last_stand/mana_guard/clear_mind)` 与 `Build.gear(p,2/3/4)` 逐一对齐，未知名字不臆造，换装后旧映射立即失效。
3. **遗留钩子必须惰性且零调用者**：`damage_multiplier()` 在满蓝/空蓝两种状态下都恒 `1.0`；`tick/spent/hit` 调用前后 `var_to_str(p)` 与 `hp` 完全不变；**结构断言**遍历 `res://scripts/*.gd`，确认除 `rogue_equipment.gd` 自身外**没有任何脚本调用**这四个钩子（防双重结算）。

### `scripts/rogue_equipment.gd` 改动
**本轮未改动**。它已由上一轮标注好（文件头与 :72-83 的 LEGACY 段落写明"遗留钩子零调用者、不得接入管线"），
本轮只对这个事实**加了可执行的断言**。
`git status` 里它显示为 `M` 是**上一轮被动轮**留下的：mtime `12:51:57`，早于本轮全部写入（`13:12`–`13:15`）。

## 验收原始数字（全部实跑）

**测量时点：2026-10-06 13:13–13:16。** 当时树上有并发写者（`scripts/rogue_combat.gd` /
`rogue_field.gd` mtime `13:09:56`、`tools/run_rogue_gate.ps1` mtime `13:15:36`），
所以本表只覆盖与它们无关的用例；`rogue_combat` / `rogue_field` 相关的门禁数字**不应以本表为准**。

| 用例 | 结果 | 说明 |
|---|---|---|
| `tests/rogue_equipment` | **35 checks / 0 failures**（exit 0） | 本轮重写，改前红 |
| `tests/rogue_passives` | 21 / 0 | 被动真实现的既有覆盖 |
| `tests/rogue_build_rules` | 565 / 0 | 内容表校验（含 E029 文案） |
| `tests/rogue_build_system` | 440 / 0 | |
| `tests/rogue_build_growth` | 4066 / 0（宝箱样本 [205,499]） | |
| `tests/rogue_ui` | 163 / 0 | |
| `tests/rogue_build_pack` | exit 0（success line） | 主场景 + 252 图标 |
| `tests/systems` | 10812 / 0 | |
| `check_class_cache -CheckOnly` | exit 0（32 类，0 重复，0 遮蔽） | |

## 留给父会话的两件事
1. **建议把 `rogue_equipment` 登记进门禁 baseline**：`'rogue_equipment' = @{ checks = 35; failures = 0 }`。
   `tools/run_rogue_gate.ps1` 正被并发轮次修改，本会话按派单**未触碰**该文件。
2. **`tests/rogue_equipment_visual.gd` 不在本轮范围**（它不引用遗留 API，grep 全仓库只有旧
   `tests/rogue_equipment.gd` 命中 `damage_multiplier|.passive`），如需一并核对请另派。
