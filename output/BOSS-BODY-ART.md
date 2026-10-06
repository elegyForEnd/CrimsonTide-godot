# 守层者身体立绘：新身份不再回落（BOSS-BODY-ART）

轮次：R14 收尾（身体立绘按身份取帧 + 生成缺失素材）。工作目录 `D:\game\CrimsonTide-godot`。

## 1. 反推出的帧表 schema（含证据行号）

| 事实 | 证据 |
|---|---|
| 立绘按 **索引** 取帧：`boss_animation(index, frame)`，键名 `boss-hd-<index>`；`frame<8` 用身体表，`frame>=8` 用 `boss-hd-<index>-skill-<(frame-8)/8>` | `scripts/rogue_art.gd:63-79` |
| 是否走 HD 表**完全取决于 `packed_sheets` 里有没有该文件名**；没登记就静默回落到旧版 `boss-<i>` / `boss-skills-<i>` | `scripts/rogue_art.gd:65,69,76,78` |
| `packed_sheets` 来自 `assets/rogue/animations/packed-manifest.json` 与 `hd-packed-manifest.json` 的 `assets[].file` | `scripts/rogue_art.gd:81-88` |
| 每帧用 manifest 里的 `content`/`cell` 建 `AtlasTexture`（不重新切图） | `scripts/rogue_art.gd:16-33` |
| 身体表只取前 8 帧 | `scripts/rogue_art.gd:39` |
| 立绘调用方：守层者身体 | `scripts/enemy_body.gd:24`（原来传 `e.rogue_skin`） |
| 立绘调用方：尸体 | `scripts/rogue_field.gd:192`（传 `corpse.floor`） |
| 身份索引表 `ROGUE = [grove,furnace,astral,wing,obsidian,bell,earth,abyss]`（0..7） | `scripts/boss_effect_art.gd:9` |
| 身份由 `(seed_value, floor)` 纯函数派生，`boss_art` 进快照、`rogue_skin` 仍是楼层 | `scripts/rogue_combat.gd:96-106,120-135` |

`hd-packed-manifest.json` 条目形状（实测）：

```json
{"file":"boss-hd-2.png","columns":4,"rows":2,"cell_size":448,"padding":64,
 "frames":[{"cell":[0,0,448,448],"content":[121,153,205,231],"source_cell":[21,0,205,231]}, ...8 帧]}
```

- 身体表：4×2、**8 帧**、`cell_size` 随表而异（hd-1=384、hd-0/2/3/4=448），实测尺寸 1536×768 / 1792×896。
- 招式表：`boss-hd-<i>-skill-<k>.png`（k=0..4），4×2、8 帧、`cell_size=640`、2560×1280（个别更大）。
- **这些表没有 1024×1024 约束**（`tests/boss_redesign.gd` 的 1024² 断言针对 `assets/bosses/imagegen/*`，不在本目录）。
- 新增 PNG **必须** 有 `.import` 才会被 `load()` 找到（否则 `No loader found for resource`）；登记 manifest 则决定走不走 HD 路径。两者缺一不可。

## 2. 生成的素材

脚本：`tools/generate_rogue_boss_bodies.py`（幂等，可反复跑）

| 身份 | 名称 | 源表 | 实测源主色相 | 目标 | 调参（Pillow HSV，0..255） |
|---|---|---|---|---|---|
| 5 | bell | `boss-hd-2`（astral） | 261.9° | 银青 | hue −51 / sat 0.45 / val 1.15 |
| 6 | earth | `boss-hd-1`（furnace） | 13.5° | 赭金 | hue +15 / sat 0.70 / val 0.88 |
| 7 | abyss | `boss-hd-4`（obsidian） | 352.9° | 深紫 | hue −55 / sat 1.35 / val 0.72 |

- 产出 **18 张 PNG**：`boss-hd-{5,6,7}.png` + `boss-hd-{5,6,7}-skill-{0..4}.png`。
- 做法是**只重映射 HSV、不动 alpha**，所以每帧的 `content`/`cell` 矩形逐字有效 → manifest 条目**原样复制**，只改 `file`，另记 `derived_from` / `derived_tuning`；manifest 顶层加 `generated_bodies` 记账。`assets` 由 70 → 88。
- 复核：派生表与源表的 alpha bbox **逐位相同**、`frames` 数组 `==` 相等（`build\_verify_bodies.py` 的原始输出）。

## 3. 接线改动

| 文件:行 | 改动 |
|---|---|
| `scripts/rogue_art.gd:63-68` | `boss_animation(body_index, frame, fallback_index=-1)`：按身份取表；`fallback_index>=0` 且该身份的 HD 表不存在时回落（保持扩容前行为），其余逻辑不变 |
| `scripts/enemy_body.gd:24` | 传 `int(e.get("boss_art", e.rogue_skin))` 与第三参 `int(e.rogue_skin)` |
| `scripts/rogue_field.gd:308-315` | **顺带修一个真 bug**：守层者血条上的招式名原来用 `MOVES[int(boss.rogue_skin)]`（楼层索引）读 8 行招式表 → 池生效后显示错招名；改用 `combat.moves_of(boss)`（按身份）并加越界守护 |
| `export_presets.cfg:10` | `include_filter` 补 `assets/rogue/build/*.png`、`assets/rogue/animations/boss-hd-*.png` |
| `PROJECT-GUIDE.md:181,191,476`、`ROGUE-BUILD-IMPLEMENTATION.md:67` | 把"该目录被 gitignore、需先跑索引器"改成"已入库 + `tools/generate_rogue_build_art.py` 一键重建" |

## 4. 验收（原始输出）

```
--check-only scripts/rogue_art.gd / enemy_body.gd / rogue_field.gd / main.gd   → 全部 exit=0
tests/rogue_boss_bodies.gd（新增）      ROGUE BOSS BODIES 389 checks / 0 failures   exit=0
  8 身份 × 48 帧 = 384 条全部来自自己的图集；含"只知楼层仍回落""未知身份回落""施法走身份招式表"
roguelike_bosses 1462/0 · rogue_boss_pool 2305/0 · rogue_boss_phase2 406/0
boss_readability 241/0 · systems 10812/0 · enemy_body 379/0 · audio 386/0
rogue_build_pack exit=0（"252 icons ... loaded"，该用例此前是可编译性哨兵）
```

真实窗口截图（`tools/preview_rogue_boss_body.gd`，`--path . --script`，非 headless）：`build\rogue-boss-bodies.png`（1280×800）。
同一层并排站 4 个身份：0（grove，原楼层图，未变）· 5（bell，银青）· 6（earth，赭金）· 7（abyss，深紫）。已用 `read_image` 亲眼确认四者互不相同、无空白、无贴图错位。

## 5. 已知局限（如实）

1. 新身份是**既有 5 套的重上色**，不是重新绘制：若一局同时抽到 `astral(2)` 与 `bell(5)`（或 `furnace(1)`／`earth(6)`、`obsidian(4)`／`abyss(7)`），**剪影会重复**，只靠配色区分。彻底解决需要重新绘制三套身体帧。
2. **尸体**仍走楼层：`rogue_field.gd:192` 用 `corpse.floor`，而尸体字典由 `scripts/rogue_combat.gd:539` 写入且不含身份（该文件本轮明确禁止改动）→ 抽池后守层者死亡瞬间的尸体会是**该楼层原本的身体**。
3. 新增 PNG 后必须跑一次 `--import`；该次导入同时刷新了大量 `assets/vendor/**/*.import`（构建元数据，非业务改动）。
4. `tests/roguelike_animations.gd` 仍是 `NO-SUMMARY`（调用已不存在的 `rogue_art.spell_animation`），与本轮无关，未修。
