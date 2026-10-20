# assets/hunt —— HUNT 美术素材（AI 生成）

来源：`D:\dsh\GPT-image-2去脏\generated\hunt`，提示词见该仓库的 `HUNT-ART-PROMPTS.md`。
生成通道：rolldek `gpt-image-2.5-sunburst`，2K，逐张串行生成（每次只 1 张）。

## 目录

| 目录 | 内容 | 数量 | 规格 |
|---|---|---|---|
| `backgrounds/` | 8 个地区的 day/dusk/night 场景背景 | 24 | 2048×1152（16:9） |
| `map/` | 区域大地图（羊皮纸风） | 1 | 2048×1152 |
| `enemies/` | 敌人动作表（4 列 × 3 行 = 12 帧：正面/侧面/攻击/背面） | 5 | 2048×1536（4:3），品红底 |
| `enemies/individual/` | 动作表切好的单帧 `*_r1c1.png …` | 60 | 256×256，透明 |
| `icons/` | 物品图标表 | 5 | 2048×2048（1:1），品红底 |
| `icons/individual/` | 切好的单个图标 | 65 | 256×256，透明 |
| `ui/` | 面板 / 三态按钮 / 血条 / 交互点 / 提示条 | 6 | 见文件尺寸，品红底 |
| `ui/individual/` | 三态按钮拆开后的单体 | 6 | 原始裁切尺寸，透明 |
| `ui/crops/` | 运行时实际使用的九宫格小图（脚本裁） | 11 | 见下节「接入」 |
| `portraits/` | 隐藏角色墓煜立绘（1 张常规 + 7 表情差分） | 8 | 1152×2048（9:16），品红底 |
| `events/` | 互动事件窗里的物件插图（reliquary/astrolabe/music_box/balance/ledger/surgery/cage/blood_clock） | 8 | 900×900（1:1），**纯黑底**（暗色面板上直接铺，不需要抠图） |

## 抠图 / 切图说明

- `*_alpha.png`：品红底抠成透明。用 `_build/key-clean.py`，做了**反预乘**（把已知品红背景从边缘像素里减回去）**+ 边缘去紫**，实测边缘残余紫色分量的 95 分位从 48 降到 6，白底/深底上都不再有紫边。
- `individual/`：用 `_build/slice-alpha.py` 按 alpha 连通域切格（不是等分切）。图标按 4×4、敌人按 3×4、按钮按 3×1 的网格把每个连通域归到格子里再取联合 bbox，碎片/飘带/越界武器都不会被切掉。

## 命名约定

- 背景：`<地区>_<时段>.png`，如 `hospital_night.png`
- 敌人：`<敌人>_sheet.png`（动作表），`<敌人>_sheet_alpha.png`（品红已抠成透明）
- 图标：`<分类>.png` / `<分类>_alpha.png`
- UI：`<部件>.png` / `<部件>_alpha.png`
- 立绘：`portrait_<表情>.png` / `portrait_<表情>_alpha.png`，表情为 `neutral/joy/sad/angry/afraid/pain/smirk/tired`

## 接入血潮深潜

正式素材已经接到 `scripts/hunt/` 里，运行时取图统一走 `hunt_art.gd`：

| 素材 | 入口 | 说明 |
|---|---|---|
| `backgrounds/<area>_<phase>.png` | `Art.background()` → `hunt_stage.gd` 画片模式 | 有图就整屏铺一张，原 3D 箱庭不生成；缺图才回退 CC0 拼装 |
| `map/region_map.png` | `Art.map_texture()` → `hunt_map_view.gd` | 8 个 `map_at` 已按图上暗圈重标（旧坐标是提示词阶段的近似值） |
| `icons/individual/*.png` | `Art.icon()` + `ICON_SHEETS` | 65 张按提示词表格顺序映射到物品 id；彩色图不再乘物品色 |
| `enemies/individual/<id>_sheet_r1c1.png` | `Art.enemy_texture()` | 战斗面板用正面待机帧；旧 4×3 表只在缺图时回退 |
| `portraits/portrait_<expr>_alpha.png` | `Art.portrait_texture(3, expr)` | 只有隐藏角色**墓煜**用这套 8 表情；其余三位仍走 vn-full-v3 |
| `ui/crops/panel.png` | `Art.panel_style()` | 只取内圈石板 + 细金边，16px 九宫格；外面那圈 140px 厚木框留给以后的版式 |
| `ui/crops/button_*_set_*.png` | `Art.button_style()` | 左/右 46px、上/下 0 的九宫格（按钮会被压到 40px 高） |
| `ui/crops/toast.png` | `Art.toast_style()` | 裁掉 16:9 画布空白，44px 高的浮动提示条 |
| `ui/crops/hotspot_*.png` | `EventMarker._draw()` | ready / used / locked 三态互动圆环；随机事件点只显示问号 |
| `events/<art>.png` | `Art.event_texture()` → `hunt_screen._build_event_window()` | 事件窗左侧插图；缺图返回 null，窗口只显示文字 |
| `ui/bar.png` | 暂未接入 | 2K 条压到 9~14px 会糊成一条，细条继续用自绘 `Bar` |

- 裁图脚本：`python tools/build_hunt_ui_crops.py`。改完任何 `*_alpha.png` 后重跑它，再让 Godot `--import` 一次。
- 小图尺寸：panel 512×503、toast 512×118、hotspot 256×宽等比、按钮 512×宽等比。
- 表情映射：规则层的 `smile/determined/worried/surprised/shy` 在墓煜身上分别落到 `joy/smirk/afraid/afraid/sad`（见 `hunt_art.HUNT_EXPRESSIONS`）。

## 注意

1. 透明版已做过反预乘去紫，边缘干净；如果游戏里用了**线性色彩空间**（Godot 默认 sRGB 贴图），不需要额外处理。
2. `icons/individual`、`enemies/individual` 都是 256×256 等大方图，可直接塞进 `Sprite2D` / `TextureRect`；原表留作改切/参考。
3. 背景图是 16:9；深潜 SubViewport 是 1440×900（16:10），画片模式用 `STRETCH_KEEP_ASPECT_COVERED`，左右各裁掉约 5%。
4. Godot 首次导入 PNG 会自动生成 `.import`；带 alpha 的 PNG 默认就是无损压缩。
5. `events/` 是 2026-10-20 新加的一批：提示词明确要求**纯黑背景**，为的是直接融进深色互动面板；不要当透明图用，也不要做品红抠图。
6. 事件插图与事件 id 的对应写在 `hunt_data.EVENTS[*].art`，一个 `art` 可以被多个事件复用；加图时只改这里和 `hunt_art.EVENT_DIR`。

## 生成记录

逐张记录（提示词、耗时、来源文件）在源仓库的 `generated/hunt/manifest.jsonl`。
