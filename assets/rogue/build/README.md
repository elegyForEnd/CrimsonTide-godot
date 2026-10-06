# assets/rogue/build —— 肉鸽构筑素材（生成物，可一键重建）

本目录是**生成物**，但已通过 `.gitignore` 例外（`!/assets/rogue/build/`）纳入版本控制：
干净 clone 拿到这里的内容就能让 `main.gd` 编译通过、252 个构筑图标与英雄跳跃帧全部可解析。

## 一键重建

```powershell
F:\python\python.exe tools\generate_rogue_build_art.py
```

脚本是**确定性且幂等**的：重跑产出逐字节相同。它内部还会调用项目原有的两个索引器
（`tools/index_rogue_build_art.py`、`tools/index_rogue_jump_art.py`）来生成运行时清单，
所以不需要手动再跑它们。

## 目录内容

| 文件 | 说明 |
| --- | --- |
| `weapons-{light,heavy,ranged,staff}-v1.png` | 4 张武器图集，各 4×3 = 12 件（W001–W048） |
| `gear-{armor,focus,boots}-v1.png` | 3 张装备图集，各 4×6 = 24 件（E001–E072） |
| `talents-{1..4}-v1.png` | 4 张天赋图集，各 4×6 = 24 条（T001–T096） |
| `engravings-v1.png` | 24 条铭刻（I001–I024） |
| `weapon-cores-v1.png` | 12 个武器核心（WC001–WC012） |
| `hero-{0..3}-jump-v1.png` | 4 张英雄跳跃表，各 3×2 = 6 姿态 |
| `blood-flask-v1.png` | 血瓶图标（`scripts/rogue_art.gd:4` 的**编译期 preload**，缺它 main.gd 直接编译失败） |
| `generation-plan.json` | 上游计划（`tools/plan_rogue_build_art.py` 依 `resources/rogue_build_content.json` 生成） |
| `generation-record.json` | 每张图集的 `final_file`/`columns`/`rows`/`ids`，被 `tools/index_rogue_build_art.py:7` 读取 |
| `jump-generation-record.json` | 4 名英雄跳跃表的生成记录 |
| `atlas-manifest.json` | **运行时清单**：252 个 id → `{file, region[x,y,w,h], cell[x,y,cw,ch]}` |
| `jump-manifest.json` | **运行时清单**：4 名英雄 → `{file, standing_height, frames[{cell,pivot,body_height}]}` |
| `validation.json` | 每张图集的不透明比例与图标数校验报告 |

## 清单 schema（由消费端反推，证据见括号）

`atlas-manifest.json`：

```json
{"version": 1,
 "regions": {"W001": {"file": "res://assets/rogue/build/weapons-light-v1.png",
                      "region": [x, y, w, h], "cell": [x, y, cw, ch]}}}
```

* 消费者：`scripts/rogue_build_art.gd:3,9-19`（`Art.icon(id)` 取 `regions[id]`，`load(entry.file)` 后切 `AtlasTexture`）。
* 断言：`tests/rogue_build_rules.gd:45-52` 要求 252 个 id 的图标非空、宽高 >4px，且
  `atlas.resource_path + region` 两两不同；`tools/index_rogue_build_art.py:34` 断言 `len(regions)==252`。

`jump-manifest.json`：

```json
{"0": {"file": "res://assets/rogue/build/hero-0-jump-v1.png",
       "standing_height": 92,
       "frames": [{"cell": [l, t, w, h], "pivot": [cx, cy], "body_height": h}, ...6 项]}}
```

* 消费者：`scripts/rogue_jump_frames.gd:3,6-19`（`scale = standing_height / spec.standing_height`，
  `pivot` 是格内像素坐标，脚底固定在该格高度 94% 处），经 `scripts/character_frames.gd:14,216-217` 调用。
* 断言：`tests/rogue_build_pack.gd:32-35` 要求 4 名英雄 × 4 种速度都能取到非空 `pose.texture`。

## 已知限制

* 图标由 `tools/generate_rogue_build_art.py` **程序化绘制**（轮廓档位 × 12 色相环 × 装饰件），
  属于清晰可辨的占位级美术，不是手绘/生成式成图；要换成真美术时，保持文件名与
  `columns/rows/ids` 布局不变即可直接覆盖 PNG，然后重跑两个索引器。
* 英雄跳跃帧是简笔人形，动作区分度有限（游戏内角色高度约 26–30px，实际观感尚可）。
* `export_presets.cfg:10` 的 `include_filter` 目前只列了两个 manifest，没列图集 PNG；
  打包导出时若图集未被引用可能被剔除（`tests/rogue_build_pack.gd` 支持直接对导出的
  EXE/PCK 运行）。需要发布构建时请在该过滤串里补 `assets/rogue/build/*.png`。
