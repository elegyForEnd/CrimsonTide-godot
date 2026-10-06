# 肉鸽构筑素材（assets/rogue/build）反推 · 生成 · 验收报告

结论：`assets/rogue/build/` 已从「7 字节占位 manifest + 一张 2.8MB 占位图」变成**完整可用的生成物**
（13 张图集 / 252 个图标 / 4 张英雄跳跃表 / 血瓶图标 / 两份运行时清单），
两个长期豁免的用例现已**全绿且不再挂死**，`main.gd` 可独立编译。

---

## 1. 反推出的 schema（附证据行号）

### 1.1 `atlas-manifest.json` —— `Art.icon(id)` 的唯一索引

```json
{"version": 1,
 "regions": {"W001": {"file": "res://assets/rogue/build/weapons-light-v1.png",
                      "region": [x, y, w, h], "cell": [x, y, cw, ch]}}}
```

| 事实 | 证据 |
| --- | --- |
| 路径固定为 `res://assets/rogue/build/atlas-manifest.json`，在**静态初始化**时解析 | `scripts/rogue_build_art.gd:3` |
| 取 `manifest["regions"][id]`，为空则 `icon()` 返回 `null` | `scripts/rogue_build_art.gd:9-10` |
| `entry.file` 交给 `load()`；`region` 是 `[x,y,w,h]` 四个数 → `AtlasTexture.region` | `scripts/rogue_build_art.gd:11-16` |
| `cell` 键存在但运行时不用（供索引/校验） | `tools/index_rogue_build_art.py:30` 同时写 `region` 与 `cell` |
| 顶层必须有 `version:1` 与 `regions` | `tools/index_rogue_build_art.py:35` |
| 必须正好 252 个区域 | `tools/index_rogue_build_art.py:34`（`assert len(regions)==252`） |
| 每个 id 的图标非空、宽高 >4px、`resource_path+region` 两两不同 | `tests/rogue_build_rules.gd:45-52` |
| 物品栏/赠礼/场地图标都走它（`W%03d` / `E%03d` 由 `build_id`、`weapon-599`、`rogue_id+1` 推） | `scripts/rogue_build_art.gd:21-25`；调用方 `scripts/rogue_build_ui.gd:80,121,139,172`、`scripts/rogue_field.gd:240,300`、`scripts/rogue_art.gd:131,133`、`tests/rogue_build_pack.gd:27-31` |

### 1.2 `generation-record.json` —— 索引器的输入

`tools/index_rogue_build_art.py:7` 读取，逐条 plan 用 `plan["ids"]`、`plan["columns"]`、`plan["rows"]`、
`plan["final_file"]`（第 11-30 行），并断言 `len(ids)==columns*rows`（第 17 行）、每个格子
alpha≥24 的包围盒面积 >100（第 27 行）、整张图集至少 10% 完全透明像素（第 32 行）。
没有 `ids` 键的条目会被跳过（第 11 行）。

### 1.3 `jump-manifest.json` —— 英雄跳跃帧

```json
{"0": {"file": "res://assets/rogue/build/hero-0-jump-v1.png",
       "standing_height": 92,
       "frames": [{"cell": [l,t,w,h], "pivot": [cx,cy], "body_height": h}, ...6 项]}}
```

| 事实 | 证据 |
| --- | --- |
| 静态解析 `res://assets/rogue/build/jump-manifest.json` | `scripts/rogue_jump_frames.gd:3` |
| 键是英雄序号字符串（`manifest[str(hero)]`），取 `spec.file` / `spec.standing_height` / `spec.frames` | `scripts/rogue_jump_frames.gd:6-12` |
| 每帧 `cell` 切 `AtlasTexture`，`pivot` 是格内像素坐标，`scale = standing_height / spec.standing_height` | `scripts/rogue_jump_frames.gd:12-17` |
| 索引器把 6 帧切成 3 列 × 2 行，`pivot=[(x0+x1)/2,(cell_h)*.94]`，`body_height=y1-y0`，`standing_height=frames[-1].body_height` | `tools/index_rogue_jump_art.py:14-23` |
| 索引器要求每格 alpha≥80 的包围盒非空 | `tools/index_rogue_jump_art.py:18` |
| 4 名英雄 × 4 种速度都要能取到非空 `pose.texture` | `tests/rogue_build_pack.gd:32-35` |

### 1.4 `blood-flask-v1.png` —— 编译期依赖

`scripts/main.gd:163 preload(rogue_field.gd)` → `scripts/rogue_field.gd:12 preload(rogue_art.gd)`
→ **`scripts/rogue_art.gd:4 preload("res://assets/rogue/build/blood-flask-v1.png")`**。
这是 `preload`，属于**编译期**依赖：文件缺失时 `main.gd` 直接 `Compilation failed`，几乎所有用例一起红。

### 1.5 13 张图集的 id 划分（来自上游 `generation-plan.json`，与内容表一致）

| 图集 | 布局 | ids |
| --- | --- | --- |
| `weapons-light/heavy/ranged/staff-v1.png` | 4×3 | W001–W048（每张 12） |
| `gear-armor/focus/boots-v1.png` | 4×6 | E001–E072（每张 24） |
| `talents-1..4-v1.png` | 4×6 | T001–T096（每张 24） |
| `engravings-v1.png` | 4×6 | I001–I024 |
| `weapon-cores-v1.png` | 4×3 | WC001–WC012 |

合计 252，`resources/rogue_build_content.json` 实测 `weapons 48 / gear 72 / talents 96 / engravings 24 / cores 12`，
id 全局唯一，`version=3`。

**关于 1024×1024**：那个约束只针对**Boss 美术**（`tests/boss_redesign.gd:18` 检查的是 Boss 贴图），
`assets/rogue/build/` 的消费端没有任何尺寸下限，只要求单格包围盒 >4px（`tests/rogue_build_rules.gd:50`）。
本次取 160px 单元格（图集 640×480 / 640×960），兼顾清晰度与体积。

---

## 2. 生成器与产物

新增脚本：**`tools/generate_rogue_build_art.py`**（确定性 + 幂等；重跑产出逐字节相同，已用 PNG SHA256 前后对比验证）。
它读取 `resources/rogue_build_content.json` + `assets/rogue/build/generation-plan.json` 绘制图集，
写 `generation-record.json` / `jump-generation-record.json`，最后**调用项目原有的两个索引器**
（`tools/index_rogue_build_art.py`、`tools/index_rogue_jump_art.py`，均未修改）产出运行时清单。

生成命令（一条即可重建全部）：

```powershell
F:\python\python.exe tools\generate_rogue_build_art.py
```

绘制策略（区分度优先）：**轮廓档位 × 12 色相环 × 装饰件**
- 武器 4 图集各 4 种轮廓（直剑/弯刀/双匕首/细剑；巨刃/战锤/战斧/斩首刀；步枪/长弓/短枪/弩；法球杖/晶杖/矛杖/权杖），
  档位内再叠 12 色相与 4 种装饰件（条/三珠/菱形/折线）。
- 装备按槽位（甲/护符/靴）× 模板字母 4 种轮廓，再叠 12 色相与装饰件。
- 天赋按学派 12 色 + 8 种变化；铭刻 8 种符文 × 6 色；核心按武器族 + 掌握点数。
- 全部走 4× 超采样后 LANCZOS 缩小，带深色描边，深/浅底都可辨。

产物清单与体积（**整目录 1.53 MB**，比原来单张 2.8MB 占位图还小）：

| 类别 | 文件 | 说明 |
| --- | --- | --- |
| 图集 | 13 张 PNG（47–143 KB） | 252 个图标 |
| 跳跃表 | `hero-0..3-jump-v1.png`（24–25 KB） | 4×6 姿态 |
| 图标 | `blood-flask-v1.png`（6.3 KB，原占位 2.8 MB） | 编译期 preload |
| 清单 | `atlas-manifest.json`（62 KB）、`jump-manifest.json`（5.4 KB） | 运行时索引 |
| 记录 | `generation-record.json`（49 KB）、`jump-generation-record.json`、`validation.json` | 生成记录与校验 |
| 文档 | `README.md`（新建） | schema + 一键重建 + 限制 |

清单自检（python 交叉核对）：`regions` = **252**、与内容表 id **完全一致（missing=[] extra=[]）**、
**13** 个图集文件、region 尺寸 31 种（3864–18603 px²）；`jump-manifest` 4 名英雄 × 6 帧、`standing_height=92`。

---

## 3. 两个豁免用例的验收（改前 → 改后，原始输出）

| 用例 | 改前 | 改后 |
| --- | --- | --- |
| `tests/rogue_build_rules.gd` | 第 1 个 check 崩溃（`Painted icon exists: W001` → `Nil.atlas`），随后**不 quit 挂死**，有效覆盖 0 | **`BUILD RULES: 565 checks, 0 failures`，EXIT=0** |
| `tests/rogue_build_pack.gd` | `Missing exported icon W001`，exit=1（8s） | **`BUILD PACK: main scene, five build tabs,252 icons,4 hero jump sheets, sanctuary choices, XP leveling, attribute shards and JSON data loaded`，EXIT=0** |

`rogue_build_rules` 在素材补齐后把被掩盖的 126+ 条断言**全部跑通且 0 失败**（这条用例原本属于
「崩溃掩盖一切」，现在它是真实回归信号）。

## 4. `main.gd` 独立编译证据

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --check-only --script scripts/main.gd
→ EXIT=0（stderr 无 Compilation failed）
```
另外 `scripts/rogue_art.gd`、`scripts/rogue_build_art.gd`、`scripts/rogue_jump_frames.gd`
的 `--check-only` 均 EXIT=0。

## 5. 相邻回归（未被素材改动破坏）

```
rogue_build_growth : BUILD GROWTH: 4066 checks, 0 failures; chest samples [205, 499]  EXIT=0
rogue_build_system : ROGUE BUILD: 440 checks, 0 failures                              EXIT=0
rogue_ui           : ROGUE UI: 161 checks, 0 failures                                 EXIT=0
```

---

## 6. 持久化决策

* `assets/rogue/build/` 早在 2026-10-05 就有 `.gitignore` 例外（`.gitignore:5 !/assets/rogue/build/`），
  实测 `git check-ignore -v` 对图集 PNG / 清单 / README **全部返回 exit 1（未被忽略）**，
  `git status --porcelain -- assets/rogue/build` 显示新文件为 `??`、清单与血瓶为 `M` → **可以随仓库分发**。
* 已删除 `PLACEHOLDER-README.txt`（它自己写明「拿到真实素材后删掉本文件」），
  改为 `assets/rogue/build/README.md`：记录 schema、一键重建命令、以及"换真美术只需覆盖
  PNG 并重跑索引器"的流程。
* 即使整个目录被误删/`git clean -fdx`，恢复只需**一条命令**
  （`F:\python\python.exe tools\generate_rogue_build_art.py`），因为生成脚本已入库。
* 未执行任何 `git add/commit`（按派单约束）。

## 7. 已知限制与后续建议（未擅自改动）

1. **图标是程序化占位级美术**，清晰可辨但不是手绘成图；要换真美术时保持文件名与
   `columns/rows/ids` 布局不变即可覆盖，然后重跑索引器。
2. **英雄跳跃帧是简笔人形**，动作区分度有限（游戏内角色约 26–30px 高，实际观感尚可）。
3. **导出过滤串缺图集 PNG**：`export_presets.cfg:10` 的 `include_filter` 只列了
   `assets/rogue/build/atlas-manifest.json` 与 `jump-manifest.json`，没有列图集 PNG。
   `tests/rogue_build_pack.gd:2` 声明自己可以「对导出的 EXE/PCK 运行」，而图集是运行时
   `load()` 的动态路径，导出时可能被剔除 → 发布构建前建议补 `assets/rogue/build/*.png`。
   （属导出配置，未在本轮改动。）
4. **既有文档已过时**（按派单未改）：`PROJECT-GUIDE.md:181,191,476`、`ROGUE-BUILD-IMPLEMENTATION.md:64-66`
   仍写「`assets/rogue/build/` 被 gitignore、需先跑索引器才有 manifest」。现在这些生成物**已入库**，
   建议后续把这些行改成「已入库，可用 `tools/generate_rogue_build_art.py` 一键重建」。
5. 图集单元格 160px、图集 640×480/640×960；若将来要更高分辨率真美术，只需改
   `tools/generate_rogue_build_art.py` 顶部的 `CELL` 常量后重跑。
