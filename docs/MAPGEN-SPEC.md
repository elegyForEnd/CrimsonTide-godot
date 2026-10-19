# 三日远征 · 随机大陆生成规范 v0.2

> 状态：**v0.2-final · 已签字（2026-10-19）**；P1 可以开工
> 日期：2026-10-19
> 上游权威：`docs/MAPGEN-HANDOVER.md`（决策与验收）
> 下游：P1 生成器骨架（本文件签字后才开工）
> 适用范围：主模式 **三日远征（搜打撤）** 的局内地图。
> 不包含：潜入血潮（原血潮猎场）、魔境闯关、赤月遗书、血潮猎场；也不包含 10× 实装、流式加载、Z 轴（分别是 P2–P4）。

本文件把交接文档 §5 的 v0.1 生成规范细化成**可实现的契约**：每个 pass 的函数签名、输入/输出、随机源、数值表、验证清单、失败回退、联机/分块接口与测试清单。数值冲突时以本文件为准；本文件没写的，以 `docs/MAPGEN-HANDOVER.md` 为准。

---

## 0. 签字页

用户已于 2026-10-19 逐条确认（Q1–Q9、Q11 按推荐；Q10 按“30fps 底线 + 画质不影响联机模拟”执行）。本文件升为 v0.2-final，P1 开工。

- [x] **全部按 §15 推荐值执行**（Q10 以用户批注为准）
- [x] 逐条批注（见 §15 “用户选择”列）

签字前允许改本文件，不允许新建 `map_*.gd`、不允许改 `session/expedition/battlefield` 的地图路径。

变更记录：

| 版本 | 日期 | 变更 |
|---|---|---|
| v0.1 | 2026-10-18 | 交接文档里的生成规范草案 |
| v0.2 | 2026-10-19 | 本文件：数据结构、pass 签名、数值表、测试与回退契约 |
| v0.2-final | 2026-10-19 | 用户确认 §15；Q10 采用 30fps 底线且画质不得影响联机模拟 |

---

## 1. 范围与不做什么

### 1.1 P1 做什么

1. `MapGen` 生成器骨架：P0–P11 全管线，headless 可跑，同种子同图。
2. `TerrainMap` 权威地势数据 + 块内空间索引；`MapWorld` 适配成现有 `Ruins` 消费者。
3. `MapBlueprints`：把现有 18 个据点转成数据图版，带 Z 轴 schema 预留。
4. `MapValidate`：连通/配额/可达/水域/出口/Boss 验证，失败自动重试并回退 legacy。
5. 程序化小地图 + 迷雾位图（不读 viewport、不预渲染气泡点亮）。
6. 5 个撤离点、每局封 2 个；3 神龛；3 地图守卫；1 Boss；0–1 王城；3 渡船码头。
7. 新测试 `tests/mapgen_rules.gd`、`tests/mapgen_visual.gd`、`tests/mapgen_integration.gd`。
8. legacy 固定图与现有测试基线保持可用。

### 1.2 P1 明确不做

- **不做 10×**（30,400×22,800）：P1 默认当前 9,600×7,200，`extent` 参数可传 2× 做压力测试。
- **不做流式加载**：P1 仍一次性建当前尺寸的地势；分块索引只用于碰撞/查询，不用于按需建网格。
- **不做 Z 轴**：P1 全部 `level=0`，只保留 schema 与 API。
- **不做新美术**：图版复用现有 18 个据点的美术与 `scene_asset_layout`。
- **不改魔境/猎场/剧情**：`roguelike.gd`、`hunt/`、`scarlet/` 的地图路径不动。
- **不做 10× 性能优化**：P1 只保证当前尺寸可玩；P2 再做气泡与增量网格。
- **不做“越靠中心越难”**：`danger` 永远没有径向项。

### 1.3 硬规则（继承 AGENTS.md）

- 提交只显式 add 本轮文件，禁止 `git add .`；两个 CRLF 幽灵文件永不 add。
- 不往项目树写带 `class_name` 的临时快照；对比脚本写 `$env:TEMP`。
- 新 `raid` 键必须在 `expedition.reset()` / `session.begin()` 给默认值。
- 权威端才做规则；表现层只读。
- 不碰 `output/ROGUE-CONTRACTS.md` 的契约。

---

## 2. 已锁定决策（不要再翻案）

以下 15 条来自 `docs/MAPGEN-HANDOVER.md` §2，逐条保留：

| # | 决策 |
|---|---|
| 1 | 只做主模式三日远征；本轮不碰潜入血潮 |
| 2 | 最终 10 倍面积：约 30,400×22,800 |
| 3 | 单局 45 分钟：三天 18 / 16 / 11；Boss 战停表 |
| 4 | 35–42 大区 + 8–10 碎块，总数 45–52 |
| 5 | 水域小一点：陆地面积 6–10% |
| 6 | 水：1–2 条宽河（互不重叠）+ 2–5 湖；无细溪；至少 1 个可通航水体 |
| 7 | 渡船是唯一快速移动；3 码头；不做滑索/坐骑/传送门 |
| 8 | 5 个撤离点，每局随机封 2 个；开放 3 个覆盖至少 2 象限 |
| 9 | 难度不按“离中心多近”排；Boss/潮心从高危核心随机选 |
| 10 | 迷雾只亮身边固定半径；区域探索 80% 才给名字；情报点不给方位 |
| 11 | 三层分离：地脉 / 地势 / 图版 |
| 12 | 玩家小地图 = 地势 + 迷雾，不是抽象格子 |
| 13 | 未来 Z 轴/可爬地势；本轮 schema 预留，P1 平地 |
| 14 | 加载：分块流式 + 气泡；联机各渲染各的，汇合再合并 |
| 15 | 先生成器骨架，再流式，再 10×；不许先把 `world_3d.rebuild()` 放大 10 倍 |

---

## 3. 术语与三层分离

| 词 | 本规范中的精确定义 | 不是什么 |
|---|---|---|
| **地脉（LeyMap）** | 一局地图的抽象骨架：陆块意图、折轴、水预算、危险核心、区域种子、配额、特殊结构意图 | 不是高度场，不是玩家地图 |
| **地势（TerrainMap）** | 真实的高度/折层/水域/陆块/区域归属/道路/地基；小地图与碰撞的数据源 | 不是抽象模板 |
| **图版（Blueprint）** | 可复用手工模块：18 据点、竞技场、陷阱场、王城、渡口、神龛 | 不是噪声，不是区域 |
| **地物（Props）** | 树、石、家具、雾、血迹等摆件 | 不参与规则 |
| **织脉** | 生成一张地脉的动作 | 不是“画地形” |

三层之间的唯一方向：

```
LeyMap（抽象意图）
   → TerrainMap（真实地势；唯一权威）
   → MapWorld（Ruins 适配层，给 session/渲染读）
   → Blueprint 盖在地势上（图版是地势的消费者，不反向改地势规则）
```

硬约束：**玩家小地图只读 TerrainMap/MapFog，不读 LeyMap**；LeyMap 的任何热图/抽象格子不得进入玩家 UI。

---

## 4. 总体架构

### 4.1 模块图

```
scripts/map_gen.gd          class_name MapGen           P0–P11 编排、RNG、layout_hash
scripts/map_ley.gd          class_name LeyMap           抽象地脉
scripts/map_terrain.gd      class_name TerrainMap       地势数据 + 查询 + 块索引
scripts/map_blueprints.gd   class_name MapBlueprints    图版注册/盖印
scripts/map_validate.gd     class_name MapValidate      验证与失败原因
scripts/map_fog.gd          class_name MapFog           探索位图/区域探索度
scripts/map_minimap.gd      class_name MapMinimap       程序化小地图纹理
scripts/map_chunks.gd       class_name MapChunks        分块接口（P2 实装，P1 只建索引）
scripts/map_world.gd        class_name MapWorld          extends Ruins，适配层
scripts/map_factory.gd      class_name MapFactory        创建/重试/legacy 回退
```

依赖方向（禁止反向）：

```
MapWorld → MapGen → (LeyMap, TerrainMap, MapBlueprints, MapValidate)
MapFactory → MapGen + MapWorld + Ruins
MapGen 不 preload MapWorld（避免 class_name 循环）
```

> 如果 GDScript 的 preload 循环让 `MapGen` 不得不引用 `MapWorld`，把工厂留在 `MapFactory`，`MapGen` 只返回 `TerrainMap`。

### 4.2 数据流

```
MapFactory.create(seed, {generated, extent})
  → MapGen.try_generate(seed, options)
      → P0  LeyMap
      → P1..P9 填 TerrainMap
      → P10 MapValidate.check
          ├─ ok   → P11 块索引 + layout_hash
          └─ fail → seed+1 重试（≤8）
                      └─ 仍失败 → Ruins legacy 固定图
  → MapWorld.new().apply_terrain(terrain)
  → session / battlefield / world_3d / world_art 只读
```

### 4.3 运行时开关

- `TideSession.mapgen_enabled := false`（字段默认值）。
- `main.gd` 的 `on_camp_launch()` 在 `selected_mode=="expedition"` 时把它设为 `true`；魔境/剧情/猎场永不设。
- `session.launch()` 把 `mapgen_enabled` 传给 `begin()`；`begin.rpc()` 多一个 `generated:bool` 参数，保证联机客户端同开关。
- 直接调用 `session.launch()` 的测试/工具默认走 legacy，**不用改 200 个旧测试**。
- `MapFactory.create` 收到 `generated=false` 或生成失败时返回 `Ruins`；返回后读 `ruins.generated` 判断。
- 失败时 `push_warning` 记录原因，玩家永远看到一张能玩的图（legacy 兜底）。

### 4.4 为什么用 `MapWorld` 而不是直接把 Ruins 改烂

现有 `session/battlefield/world_3d/world_art` 都按 `Ruins` 的字段写。`MapWorld extends Ruins`：

- 保留所有旧字段名（`sites/chests/shrines/exits/regions/roads/river/bridges/walls/decor/features/coast`）；
- 用 `TerrainMap` 覆盖碰撞/ biome / 生成；
- legacy `Ruins.new().generate()` 一行不改，旧测试与固定图继续绿。

---

## 5. 数据结构

### 5.1 `LeyMap`（抽象地脉）

```gdscript
class_name LeyMap
extends RefCounted

var seed_value: int = 0
var layout_version: int = 4
var extent: Vector2 = Vector2(9600, 7200)
var area_scale: float = 1.0          # extent 面积 / 30,400×22,800
var linear_scale: float = 1.0        # sqrt(area_scale)

# 陆块意图
var land_center: Vector2
var land_radius: Vector2
var land_noise_seed: int
var coast_seed: int

# 折层意图
var fold_axis: Vector2
var fold_wavelength: float
var fold_secondary: float
var ridge_bias: float

# 水域意图
var water_fraction: float
var water_budget: float
var river_count: int
var stream_count: int # 固定 0：细溪已移除
var lake_count: int
var ferry_docks: int

# 危险意图
var danger_core_count: int
var safe_pocket_count: int
var exposed_core_count: int

# 区域意图
var region_count: int
var big_region_count: int
var fragment_count: int
var depth_target: PackedFloat32Array   # [0.55, 0.28, 0.13, 0.04]

# 类型配额
var newbie_count: int
var high_count: int
var fight_count: int
var trap_count: int

# 特殊结构
var exit_count: int
var sealed_exit_count: int
var shrine_count: int
var guardian_count: int
var boss_candidate_count: int
var royal_city_count: int
var site_budget: int
var chest_budget: int

var pass_salts: Dictionary             # pass_id -> int
var options: Dictionary
```

`LeyMap` 只存意图与预算，不存逐像素高度/水域。逐像素数据全部在 `TerrainMap`。

### 5.2 `TerrainMap`（地势，唯一权威）

```gdscript
class_name TerrainMap
extends RefCounted

const GRID := 32.0
const CHUNK := 1600.0

var seed_value: int = 0
var layout_version: int = 4
var extent: Vector2 = Vector2(9600, 7200)
var cols: int = 0
var rows: int = 0

# 逐格场（长度 cols*rows）
var land: PackedByteArray          # 1 陆地，0 海
var water_depth: PackedFloat32Array # 像素；0 干，>0 水
var height: PackedFloat32Array      # 垂直像素；P1 地形逻辑高度 0，字段留给 P2/P4
var fold: PackedFloat32Array        # 0..1
var ridge: PackedFloat32Array       # 0..1
var danger: PackedFloat32Array      # 0..1，无径向项
var region_id: PackedInt32Array     # -1 未分配
var depth: PackedByteArray          # 0..3

# 轮廓与网络
var coast: PackedVector2Array
var land_polygon: PackedVector2Array
var rivers: Array = []              # {points, polygon, width, order, name}
var lakes: Array = []               # {polygon, center, radius, navigable}
var bridges: Array[Rect2] = []
var roads: Array = []               # Array[PackedVector2Array]
var features: Array = []            # 悬崖/湖的兼容视图 {p,radius,polygon,kind}
var walls: Array[Rect2] = []
var building_footprints: Array[Rect2] = []
var decor: Array = []

# 区域/POI
var regions: Array = []             # 见 5.2.1
var sites: Array = []
var chests: Array = []
var shrines: Array = []
var exits: Array[Vector2] = []
var exit_names: Array[String] = []
var sealed_exits: Array[int] = []
var docks: Array = []               # 渡船码头
var guardians: Array = []           # 3 个候选 site index
var boss: Dictionary = {}           # {core, arena, entrances, danger}
var royal_city: Dictionary = {}     # 0 或 1 个
var city_gate: Vector2 = Vector2.ZERO
var spawn: Vector2 = Vector2.ZERO
var spawn_region: int = -1

# 索引/输出
var chunk_index: Dictionary = {}    # Vector2i -> Array[Rect2]/cliff ids
var warnings: Array[String] = []
var layout_hash: String = ""
```

#### 5.2.1 区域记录

```gdscript
{
    "id": int,
    "name": String,
    "center": Vector2,
    "polygon": PackedVector2Array,
    "area": float,                 # px²
    "type": String,                # newbie/explore/fight/trap/high
    "fragment": bool,
    "biome": int,                  # 0..5，兼容 Ecology.POOLS
    "danger": float,
    "depth": int,
    "expose": bool,
    "seed": Vector2,
    "sub_seeds": Array[Vector2],   # 2–4 个
    "named": bool,                 # 探索 ≥80% 才 true
}
```

#### 5.2.2 兼容字段

- `site` 继续保留 `p/rect/name/biome/tier/prop/engaged/cleared/defeated`；新增 `region`（生成区域 id）、`blueprint`、`loot_profile`、`enemy_budget`。
- `site.biome` 永远是 **0..5 的生态群系**，不是 45–52 的区域 id。区域 id 放 `site.region`。
- `world.regions` 是 45–52 条生成区域；`world.biome_at(p)` 返回 `regions[region_at(p)].biome`（0..5），`world.region_at(p)` 返回区域 id。
- `exits` 保持 `Array[Vector2]`，名字/封锁状态另存，避免改 `for pos in ruins.exits` 的旧代码。

#### 5.2.3 查询 API（必须实现）

```gdscript
func configure(extent: Vector2, seed_value: int, layout_version: int) -> void
func index_of(p: Vector2) -> int
func cell_center(i: int) -> Vector2
func in_bounds(p: Vector2) -> bool
func land_at(p: Vector2) -> bool
func water_depth_at(p: Vector2) -> float
func height_at(p: Vector2) -> float          # 双线性
func level_at(p: Vector2) -> int             # P1 恒 0
func danger_at(p: Vector2) -> float          # 双线性
func region_at(p: Vector2) -> int            # -1 = 海/未分配
func region_polygon(id: int) -> PackedVector2Array
func can_traverse(from: Vector2, to: Vector2, radius: float = 15.0) -> bool
func blocked(pos: Vector2, radius: float = 15.0) -> bool
func move(from: Vector2, velocity: Vector2, radius: float = 15.0) -> Vector2
func clear_line(a: Vector2, b: Vector2) -> bool
func nearest_open(p: Vector2, radius: float, max_distance: float) -> Vector2
func chunk_of(p: Vector2) -> Vector2i
func chunk_rect(chunk: Vector2i) -> Rect2
func canonical_summary() -> Dictionary
```

`blocked()` 的判定顺序：

1. 越界 → 阻挡；
2. `land_at()` 为 0 → 阻挡（海）；
3. `water_depth_at() > WADE_DEPTH` → 阻挡（深水）；浅水不挡，只减速；
4. 块索引里的墙/建筑/悬崖 → 阻挡；
5. 否则通行。

> 10× 时 `blocked()` 不允许再遍历全量 features；P1 就要建 `chunk_index`，P2 直接复用。

### 5.3 `Blueprint`（图版）

```gdscript
{
    "id": "old_chapel",
    "kind": "site",                  # site/arena/trap/ferry/royal_city/shrine/city_gate
    "size": Vector2(500, 400),
    "foundation": Rect2(...),        # 盖章前压平地基；相对图版原点
    "levels": [
        {"z": 0.0, "floor_polygon": PackedVector2Array()},
        # P4 预留：{"z": 3.2, ...}
    ],
    "links": [
        # P4 预留：ramp/ladder
    ],
    "walls": Array[Rect2],
    "props": Array,
    "entrances": Array[Vector2],
    "clear_radius": float,           # Boss/竞技场净空；普通据点 0
    "loot_profile": "tier1_outdoor",
    "enemy_budget": 2,
    "tags": ["explore", "indoor", "shrine"]
}
```

注册表：

```gdscript
static func all() -> Array                 # 18 个现有据点 + 特殊结构
static func get(id: String) -> Dictionary
static func sites() -> Array               # 只取 kind=="site"
static func stamp(world: MapWorld, bp: Dictionary, at: Vector2,
                  rot: int, rng: RandomNumberGenerator) -> bool
static func can_place(world: MapWorld, bp: Dictionary, at: Vector2,
                      rot: int, clearance: float = 80.0) -> bool
```

`stamp()` 的约束：

- 只允许 `rot ∈ {0, 90, 180, 270}`；矩形/点用统一旋转helper；
- 地基内每个 32px 采样点必须 `land_at`、非深水、坡度 ≤ `MAX_FOUNDATION_SLOPE`（P1 平地恒过）；
- 与已有 `building_footprints`/`walls`/深水/悬崖的间距 ≥ `clearance`；
- 盖章后追加 `sites`、`walls`、`decor`、`building_footprints`、`shrines`（若带 shrine 标签）；
- 图版几何按 `blueprint_scale = max(1.0, linear_scale / 0.316)` 缩放：P1 当前尺寸 = 1.0，10× ≈ 3.16。

### 5.4 `MapFog`（迷雾）

```gdscript
class_name MapFog
extends RefCounted

const CELL := 16.0
const REVEAL_RADIUS := 900.0

var cols: int = 0
var rows: int = 0
var bits: PackedByteArray          # 1 bit / cell
var revision: int = 0

func configure(extent: Vector2) -> void
func reveal(pos: Vector2, radius: float = REVEAL_RADIUS) -> void
func reveal_capsule(a: Vector2, b: Vector2, radius: float = REVEAL_RADIUS) -> void
func is_revealed(p: Vector2) -> bool
func region_coverage(t: TerrainMap, region_id: int) -> float  # 12×12 可行走采样
func serialize() -> PackedByteArray
func merge(other: PackedByteArray) -> void
func clear() -> void
```

硬规则：

- `REVEAL_RADIUS = 900.0`，按 1440×900 标准镜头标定；**永不读 viewport、永不读预渲染气泡**。
- 1 bit / 16px；P1 当前尺寸 600×450 cell ≈ 33.8 KB；10× 285 块约 350 KB。
- 队伍共享：`merge()` 做 OR；Boss 场参战者强制点亮由 session 调 `reveal()`，不绕过半径规则。

### 5.5 `ValidationReport`

```gdscript
{
    "ok": bool,
    "errors": Array[String],       # 错误码，见 §8.3
    "warnings": Array[String],
    "metrics": {
        "regions": int,
        "big_regions": int,
        "fragments": int,
        "water_fraction": float,
        "rivers": int, "streams": int, "lakes": int,
        "exits": int, "open_exits": int,
        "sites": int, "chests": int,
        "depth_mix": PackedFloat32Array,
        "layout_hash": String
    }
}
```

### 5.6 `MapWorld`（适配层）

```gdscript
class_name MapWorld
extends Ruins

# 以下字段在 Ruins 基类声明一次，MapWorld 只赋值、不重复声明：
#   terrain / generated / layout_version / layout_hash
#   spawn / center / city_gate / exit_names / sealed_exits
#   rivers / lakes
# 这样 legacy Ruins 也能被 session 读 ruins.spawn / ruins.center / ruins.rivers。

func generate(value: int) -> void                 # override：调 MapGen，填 terrain
func apply_terrain(t: TerrainMap) -> void         # 填旧字段；不深拷贝 sites/chests/shrines
func blocked(pos: Vector2, radius: float = 15.0) -> bool
func move(from: Vector2, velocity: Vector2, radius: float = 15.0) -> Vector2
func clear_line(a: Vector2, b: Vector2) -> bool
func biome_at(pos: Vector2) -> int                # 0..5，兼容 Ecology
func region_at(pos: Vector2) -> int
func exit_name(i: int) -> String
func exit_open(i: int) -> bool
```

`apply_terrain()` 的字段映射：

| `Ruins` 字段 | 来源 |
|---|---|
| `extent` / `map_seed` / `layout_scale` | `t.extent` / `t.seed_value` / `1.0` |
| `coast` | `t.coast`（`t.land` 位图留在 `terrain`，不复制成旧字段） |
| `river` | 最长一条 `t.rivers[i].polygon`（兼容 `world_3d` 的单河绘制） |
| `rivers` / `lakes` | `t.rivers` / `t.lakes`（新） |
| `bridges` / `roads` / `features` | 直接引用 |
| `walls` / `building_footprints` / `decor` | 直接引用 |
| `regions` / `sites` / `chests` / `shrines` | 直接引用（session 的修改要能被 terrain 看见） |
| `exits` / `exit_names` / `sealed_exits` | 直接引用 / 拷贝 |
| `spawn` / `center` / `city_gate` | `t.spawn` / `t.extent/2` / `t.city_gate` |

> **不要深拷贝** `sites/chests/shrines`：session 会写 `cleared/engaged/items/open`，深拷贝会让 terrain 与小地图/验证脱节。

### 5.7 `layout_hash`（联机一致性）

```gdscript
static func layout_hash(t: TerrainMap) -> String:
    var payload: Dictionary = t.canonical_summary()
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    ctx.update(JSON.stringify(payload).to_utf8_buffer())
    return ctx.finish().hex_encode()
```

`canonical_summary()` 的规范化规则：

- 所有浮点先 `snappedf(v, 0.01)`；距离/面积同理；
- `regions` 按 `id` 升序；`exits` 按数组下标；`sites` 按 `id`；`chests` 按生成顺序；
- 不含 `open/cleared/engaged/items` 等局内可变状态；
- 不含 `Array[Dictionary]` 的字典键顺序；所有字典在序列化前转成**固定顺序数组**；
- `layout_version` 参与哈希；改 pass 逻辑必须 `layout_version += 1`；
- `bridges` 也参与哈希（按数组顺序写 `[position, size]`）：桥面影响可走性，不能只让两端各自生成。

---

## 6. 生成管线 P0–P11

### 6.0 随机源与确定性

```gdscript
const LAYOUT_VERSION := 4

static func stable_hash(text: String) -> int:
    # FNV-1a 32-bit，不用内置 hash()，避免版本差异
    var h: int = 2166136261
    for b in text.to_utf8_buffer():
        h = (h ^ int(b)) * 16777619
        h = h & 0xffffffff
    return h

static func pass_rng(seed_value: int, pass_id: String, salt: int = 0) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = stable_hash("%d|%s|%d" % [seed_value, pass_id, salt])
    return rng
```

规则：

- 每个 pass 独立 `pass_rng(seed, "P<n>", salt)`；改一个 pass 不重排全图。
- `FastNoiseLite` 的 seed 从该 pass 的 `rng.randi()` 取；不得用全局 `randf()`。
- 所有 `Dictionary` 遍历若影响生成，必须先排序键；禁止依赖插入顺序。
- 不读 `Time`、不读 `OS`、不读玩家配置（除显式 `options`）。
- 同种子同 `layout_version` 必须同 `layout_hash`。

### 6.1 Pass 总表

| Pass | 函数签名 | 输入 | 输出 | 失败 |
|---|---|---|---|---|
| P0 | `static func p0_contract(seed_value:int, extent:Vector2, options:Dictionary) -> LeyMap` | seed、extent、options | `LeyMap` | 参数非法 → 返回空/抛错由 `try_generate` 捕获 |
| P1 | `static func p1_land(ley:LeyMap, t:TerrainMap, rng:RandomNumberGenerator) -> void` | 陆块意图 | `land/coast/land_polygon` | 陆块过小 → `E_LAND_COMPONENT` |
| P2 | `static func p2_height(ley:LeyMap, t:TerrainMap, rng:RandomNumberGenerator) -> void` | 折轴/噪声 | `height/fold/ridge` | 场退化 → 重试 |
| P3 | `static func p3_water(ley:LeyMap, t:TerrainMap, rng:RandomNumberGenerator) -> void` | 高度/水预算 | `water_depth/rivers/lakes/docks` | `E_WATER_COUNT/E_WATER_FRACTION` |
| P4 | `static func p4_danger(ley:LeyMap, t:TerrainMap, rng:RandomNumberGenerator) -> void` | 折场/核心 | `danger/cores` | 核心不足 → 重试 |
| P5 | `static func p5_regions(ley:LeyMap, t:TerrainMap, rng:RandomNumberGenerator) -> void` | 陆块/danger | `region_id/regions` | `E_REGION_COUNT/E_REGION_AREA` |
| P6 | `static func p6_depth(ley:LeyMap, t:TerrainMap, rng:RandomNumberGenerator) -> void` | 区域掩码 | `depth/sub_seeds` | `E_DEPTH_MIX` |
| P7 | `static func p7_types(ley:LeyMap, t:TerrainMap, rng:RandomNumberGenerator) -> void` | danger/depth/expose | 区域类型/名字 | `E_QUOTA` |
| P8 | `static func p8_roads(ley:LeyMap, t:TerrainMap, rng:RandomNumberGenerator) -> void` | 区域/高度/水 | 道路/图版/箱子 | `E_ROAD_CONNECT/E_SITE_REACH` |
| P9 | `static func p9_specials(ley:LeyMap, t:TerrainMap, rng:RandomNumberGenerator) -> void` | 区域/水/危险核心 | 出口/神龛/Boss/王城/渡船/守卫/出生点 | 对应错误码 |
| P10 | `static func p10_validate(t:TerrainMap, options:Dictionary) -> Dictionary` | 全图 | `ValidationReport` | 任意 error → 重试 |
| P11 | `static func p11_chunks(t:TerrainMap) -> void` | 地势 | `chunk_index/layout_hash` | 无 |

### 6.2 P0 种子/契约

- 计算 `area_scale = extent.x*extent.y / (30400*22800)`；`linear_scale = sqrt(area_scale)`。
- 区域数：`region_count` 取 45–52；`big_region_count` 35–42；`fragment_count = region_count - big_region_count`，必须 8–10。
- 水预算：`land_estimate = extent.x*extent.y*0.92`；`water_budget = land_estimate*water_fraction`。
- 出口 5、封 2、神龛 3、守卫 3、Boss 候选 3、王城 0–1、渡船 3。
- 图版预算：`site_budget = clamp(round(lerp(18, 100, area_scale)), 18, 100)`；P1 当前尺寸约 26，10× 100。
- 箱子预算：`chest_budget = clamp(round(lerp(8, 24, area_scale)), 8, 24)`；P1 当前尺寸约 10。
- 所有 `pass_salts` 从 `seed` 派生；`layout_version` 写死 4，改逻辑时 +1。

### 6.3 P1 陆块

- `FastNoiseLite` 4 octaves + 域扭曲；阈值调到陆地约 88–93%。
- 用 BFS 保留**最大陆块**；其他小岛可留作装饰，但不参与区域/图版/出口。
- 提取海岸：对 `land` 掩码跑 marching squares，得到 `coast/land_polygon`；外轮廓顺时针。
- 出生点/出口的候选必须在大陆块内。
- 失败条件：最大陆块面积 < `55% * extent 面积`。

### 6.4 P2 高度/折层

- 折轴 `fold_axis = Vector2.from_angle(rng.randf_range(0, TAU))`。
- 主波长 `fold_wavelength = rng.randf_range(0.10, 0.18) * min(extent)`。
- `fold(p) = 0.5 + 0.5*sin(dot(p-fold_center, fold_axis)/wavelength*TAU + warp(p)*2.0)`。
- 次级折 1–2 条，振幅 0.25–0.4；`ridge = 1 - abs(2*fold-1)` 再混 0.2 的 fBm。
- `height = fBm*0.5 + fold*0.35 + ridge*0.15`，再做海岸衰减；P1 只存场，不抬高地面。
- 不做径向项；中心可以低、可以高。

### 6.5 P3 水域

数量：`river_count ∈ [1,2]`、`stream_count = 0`、`lake_count ∈ [2,5]`；至少 1 个可通航水体。**不再生成细溪**：在本图比例下细河像划痕；所有河必须是宽河。

河：

- 源点从高地/折脊取，沿最陡下降 + 蜿蜒噪声走；遇海/湖停止；
- 长度 ≥ `0.18*min(extent)`；宽度 `2.0–3.0% * min(extent)`；
- **河流互不重叠、不相交**：候选河与已放置河的最小间距按最终水宽留足余量；自身折返交叉也拒绝；
- 河道下切，两岸形成浅滩；P3 每条河按河长放 1–3 个过河桥/浅滩（边长 2.2×河宽的方形，`blocked()` 把桥面视作可走），P8 道路过河时另建桥并挖干桥下水；
- 不要求横穿地图。

湖：

- 找低洼盆地（height 低、非海）或直接放 2–5 个盆地再灌水；
- 大湖半径 `5–10% * min(extent)`，小湖 `3–5%`；
- 至少 1 个湖与河/渡船连通；
- 湖岸做浅水带（0.2×半径），深水在内部。

渡船：

- 选最大可通航水体（湖或宽河）；3 个码头在岸上、彼此有水面路径；
- 固定班次（P3 实装；P1 只存码头与 `schedule=180.0`）；
- 不做滑索/坐骑/传送门。

水面栅格化：

- 河流用 capsule 沿折线 stamp，避免逐点 `is_point_in_polygon`；
- 湖泊用扫描线填充；海用 `land=0`；
- 计算 `water_area`，若不在 6–10% 陆地面积，调整河宽/湖半径，最多 8 次内部重试，仍失败交 P10。

### 6.6 P4 危险场

```
danger = clamp(0.45*fold + 0.35*ridge + 0.20*fbm, 0, 1)
```

- **没有径向项**，也没有“离中心距离”的隐式项。
- 15–20 个馅料核心：取 `danger` 局部极大值，蓝噪声最小间距 `0.07*min(extent)`；允许靠海。
- 1–2 个“深处安全窝”：低 danger 被高 danger 包围；1–2 个“靠海露馅”：高 danger 且 `coast_distance < 0.08*min(extent)`。
- 核心记录 `{p, radius, danger, expose}`；Boss 候选取 danger top 3，不按几何中心。

### 6.7 P5 撒米（大区 + 碎块）

- 种子用 Bridson 蓝噪声，权重 `1 + 2*fold_core_density`；最小间距 `sqrt(area/region_count)*0.72`。
- 保证：1 个种子在出生点附近（新手区）、至少 1 个在高 danger 核心、碎块靠近高危/海岸。
- `region_id` 用“最近种子 + 域扭曲”栅格化；每个区域取最大连通块，其余格子重分配给邻区。
- 区域面积按 10× 标定，再乘 `area_scale`：
  - 大区 25–40M → P1 2.5–4.0M；
  - 中区 10–20M → P1 1.0–2.0M；
  - 小大区 4–10M → P1 0.4–1.0M；
  - 碎块 2–8M → P1 0.2–0.8M。
- 任何区域 `area > 35M*area_scale` 或 `> 2.5*median` → 切 2–4 块；切完超 52 个就合并最小相邻碎块。
- 区域 polygon 用 marching squares 提取，缓存；`region_polygon(id)` 不重复计算。
- `region.biome`：按类型确定性映射到 0..5，保证 6 个生态群系都出现；`newbie` 固定 0（风铃原野）。

### 6.8 P6 口→回（深度）

- 对每个区域做到边界的距离变换；`ring_width = max(2*GRID, 0.18*equiv_radius)`。
- `depth = clamp(floor(distance/ring_width), 0, 3)`；父区域 id/polygon 不变。
- 每个 d≥1 的区域内再撒 2–4 个子种子，子种子周围 `+0.15 danger`、loot tier +1；存 `sub_seeds`。
- 全局深度占比向 `[55,28,13,4]%` 靠；允许 ±6 个百分点，超出就调 `ring_width`/子种子数，重跑本 pass。

### 6.9 P7 类型/配额

| 类型 | 规则 | 保底 |
|---|---|---|
| 新手 newbie | 离出生点最近、danger < 0.25、不与 high 相邻 | 1 |
| 探索 explore | 默认 | 其余 |
| 打架 fight | danger > 0.52 | ≥3 |
| 陷阱 trap | fold/ridge 高、expose=false | ≥3 |
| 高难 high | danger > 0.72 或 top 1–3 | 1–3 |

- 碎块偏向 trap/fight/high，不做 newbie。
- 配额不足时：把 danger 最高/最低的区域提升/降级，重跑 P6/P7，最多 8 次。
- 区域名从 64 个名字池取，按 `region_id` 确定性洗牌；不重复；`named=false` 直到迷雾覆盖 ≥80%。
- `expose`：`coast_distance < 0.08*min(extent)`；高 danger 核心中 30–35% 为 `expose=true`。

### 6.10 P8 道路/据点

- 可通行代价栅格：深水/悬崖 = ∞；浅水 `+9`；坡度 `+5*slope`；danger `+0.8*danger`。
- 节点：大区中心 + 图版入口；Prim MST 连所有大区；再加 6 条最低代价非 MST 边形成环路；碎块一条支路连最近大区。
- 每条边 A*；路径按 `clear_line` 简化，但保持 `radius=40` 净空；道路宽 `0.4%*min(extent)`（P1 ≈38px）。
- 过河：路径跨河时在桥下挖干水面并记录桥；桥面取跨岸距离 + `2×64` 的方形，边长 clamp 到 `1.2%–4.5%*min(extent)`（旧的整个湿段 AABB 会盖住整条河），渲染为 4 块木地板；跨不过就绕行/重算。
- 图版：每个大区 2–3 个（10×）/ 按 `site_budget` 比例（P1 当前约 0.7 个/大区）；优先靠路、平地、离水 ≥ `80`；尝试 64 次，仍失败记 warning。
- 城市门：1 个，靠地图边缘/主路，`world.city_gate`；不占 Boss 核心。
- 箱子：`chest_budget` 个，靠路、离据点 ≥ 700*linear_scale、每个 2–3 区一个；`cache_tier` 按区域 danger 分档。
- 据点必须连到路网：>250px 时加一条支路。

### 6.11 P9 特殊结构

- **出口 5**：沿外围分散，`p` 在陆地、靠岸但不进深水；每个连路；随机封 2 个；开放 3 个至少覆盖 2 个象限；从出生点可达且存在“不经过 high 区”的路线。
- **神龛 3**：explore/fight/high 各至少 1 个；用图版 shrine 偏移或独立点；可达。
- **Boss**：从 top 3 danger 核心随机 1 个；竞技场半径 `800*linear_scale` 净空；至少 2 条入口；压平地基；连路。
- **王城 0–1**：选一个非 Boss 的高危核心；独立 interior 图版；全图唯一；P1 可只预留记录，不开放进入。
- **守卫 3**：从 site 候选中选 3 个，间距 ≥ `2200*linear_scale`；存 `world.guardians`。
- **出生点**：陆地、非水、非墙、半径 120 净空、靠路、danger 低、在大陆块内；落在 newbie 区或相邻；`world.spawn`。
- **渡船**：3 码头；固定班次 180s；只画码头与船，不画跨陆直线。

### 6.12 P10 验证

见 §8。任何 error → `try_generate` 用 `seed+1` 重试，最多 8 次；仍失败 → legacy。验证不通过的地图**绝不交给玩家**。

### 6.13 P11 分块/输出

- `MapChunks.build_index(t)`：把墙/建筑/悬崖按 1600px 块建索引；`blocked()` 只查当前块及邻块。
- `layout_hash` 按 §5.7 计算；`t.canonical_summary()` 只含静态地势。
- P1 不建渲染块；`MapChunks` 的接口先固定，P2 填 `build_mesh/interest_set`。
- `MapMinimap.build(t)` 生成 1024×768 以内的地势草图纹理；P1 只在 `WorldArt.atlas` 消费。

---

## 7. 数值表

### 7.1 世界/网格

| 项 | 10× 目标（P3） | P1 默认（当前尺寸） | 说明 |
|---|---|---|---|
| extent | 30,400×22,800 | 9,600×7,200 | `options.extent` |
| 面积 | 693.12M px² | 69.12M px² | `area_scale=0.0997` |
| 采样网格 | 32 px | 32 px | cols×rows = 950×713 / 300×225 |
| 块 | 1600×1600 | 1600×1600 | 19×15=285 / 6×5=30 |
| 图版几何缩放 | ×3.16 | ×1.0 | `max(1, linear_scale/0.316)` |
| 迷雾 cell | 16 px | 16 px | 1 bit |

### 7.2 区域/深度/配额

| 项 | 10× 目标 | P1 当前（×0.0997） |
|---|---|---|
| 总区域 | 45–52 | 45–52 |
| 大区 | 35–42 | 35–42 |
| 碎块 | 8–10 | 8–10 |
| 大区面积 | 25–40M | 2.5–4.0M |
| 中区面积 | 10–20M | 1.0–2.0M |
| 小大区面积 | 4–10M | 0.4–1.0M |
| 碎块面积 | 2–8M | 0.2–0.8M |
| 强制切分 | >35M 或 >2.5×中位数 | >3.5M 或 >2.5×中位数 |
| 深度占比 | 55/28/13/4 % | 同左，±6 点 |
| 子种子 | 2–4/区 | 同左 |
| 新手/高难 | 1 / 1–3 | 同左 |
| 打架/陷阱 | ≥3 / ≥3 | 同左 |
| 图版落点 | 80–120 | 18–30（按 `site_budget`） |
| 箱子 | 20–24 | 8–12（按 `chest_budget`） |
| 神龛 | 3 | 3 |
| 守卫 | 3 | 3 |
| Boss | 1 | 1 |
| 王城 | 0–1 | 0–1 |

### 7.3 水域

| 项 | 值 |
|---|---|
| 水域占陆地 | 6–10%，目标 8% |
| 河 | 1–2 条宽河，长度 ≥ 0.18×min(extent) |
| 溪 | 0 条（已移除细溪） |
| 湖 | 2–5 个 |
| 河宽 | 2.0–3.0% × min(extent) |
| 大湖半径 | 5–10% × min(extent) |
| 小湖半径 | 3–5% × min(extent) |
| 可通航 | 至少 1 个；宽 ≥ 2.5% × min(extent) |
| 浅水 | 深度 ≤ 24 px；减速 35% |
| 深水 | 深度 > 24 px；阻挡 |
| 渡船 | 3 码头；固定 180s 一班 |

### 7.4 道路/图版

| 项 | 值 |
|---|---|
| 道路宽 | 0.4% × min(extent)（P1 ≈38px） |
| A* 代价 | `1 + 9*water + 5*slope + 0.8*danger` |
| 连接 | 大区 MST + 6 条环路；碎块 1 条支路 |
| 桥 | 跨岸方形，边长 `clamp(跨岸距+128, 1.2%–4.5% min(extent))`；渲染 4 块木地板 |
| 图版间距 | ≥80px（P1）/ ≥253px（10×） |
| 据点距路 | ≤250px（P1）/ ≤790px（10×） |
| Boss 净空 | 800×linear_scale（P1 ≈253px，10× 800px） |
| 守卫间距 | 2200×linear_scale（P1 ≈695px，10× 2200px） |

### 7.5 迷雾

| 项 | 值 |
|---|---|
| 揭示半径 | 900 px |
| 位图 | 1 bit / 16 px |
| 区域命名 | 12×12 可行走采样中 ≥80% |
| 小地图纹理 | ≤1024×768 |
| 更新 | 玩家移动时；最慢 4Hz；Boss 场强制点亮 |

### 7.6 性能预算

| 项 | P1 目标 | P2/P3 目标 |
|---|---|---|
| 生成（headless，当前尺寸） | P1 实测约 1.0s（上限 1.2s）；P2 目标 <500 ms | — |
| 生成（10×） | 不做 | <2 s |
| `blocked()` | O(1) 块索引 | 同左 |
| 小地图重建 | <100 ms | 同左 |
| 迷雾更新 | <0.5 ms/帧 | 同左 |
| 地形块建网格 | 不做 | <4 ms/帧 |
| 模拟 | 不做 | <8 ms/帧 |
| 帧率底线 | 当前尺寸 4 人极端负荷 ≥30fps（目标 60） | 4 人极端负荷 ≥30fps（目标 60）；10× 同底线 |

> **性能底线（用户 2026-10-19 确认）**：尽可能优化；**30fps 是接受底线**，4 人联机正常游玩的极端负荷下不得低于 30fps。
>
> **画质与模拟解耦（硬规则）**：画面设置（分辨率、阴影、特效密度、视距、粒子上限等）**只能影响本地表现**，绝不允许影响联机怪物的形成/生成/数量/AI/掉落/伤害等权威模拟。`GraphicsQuality` 仍是本地表现设置，不进存档、不进网络；模拟预算不随画质档位变化。
>
> 不达标时只允许降**表现**（视距、刷新率、特效密度、网格 LOD），不允许删怪、减 AI、改生成规则或让客户端决定怪物形成。

---

## 8. 验证与失败回退

### 8.1 必过清单

1. 最大陆块 ≥ 55% extent 面积；出生点在大陆块内。
2. 区域总数 45–52；大区 35–42；碎块 8–10。
3. 区域面积在 §7.2 范围内；无 >3.5M（P1）/ >35M（10×）或 >2.5×中位数。
4. 深度占比 55/28/13/4，容差 ±6 点。
5. 类型配额：新手 1、高难 1–3、打架 ≥3、陷阱 ≥3；新手不直连高难。
6. 水：河 1–2（宽河、互不重叠、无细溪）、湖 2–5；水域 6–10%；至少 1 个可通航；湖/河连通。
7. 出口 5、封 2、开放 3；开放出口覆盖 ≥2 象限；出生点可达；存在不经过 high 区的路线。
8. 神龛 3；explore/fight/high 各 ≥1；可达。
9. Boss 在 top 3 danger 核心；竞技场净空；≥2 入口；可达。
10. 出生点：陆地、非水、非墙、120 净空、靠路、低 danger。
11. 图版：数量在预算内；95% 可达；不卡墙/水；不重叠；每个大区至少 1 个（10×）/ 尽量（P1）。
12. 箱子/神龛/出口/守卫全部可达；道路 MST 连通所有大区。
13. 渡船 3 码头；水面路径存在；班次参数存在。
14. 城市门 1 个；王城 0–1；守卫 3。
15. 同种子两次 `layout_hash` 相同；改 seed 必不同。
16. 4 人局箱子/掉落预算 ≥ 2 人局的 1.8 倍（P1 只验证公式，不改经济）。

### 8.2 重试与回退

```
for attempt in 0..7:
    t = generate(seed + attempt, extent)
    report = MapValidate.check(t)
    if report.ok:
        return t (seed = seed + attempt)
return legacy Ruins(seed)
```

- 每次失败记录 `E_*` 与关键 metrics；`MapGen.last_report` 保留最后一次，供开发者模式查看。
- 联机：房主决定 `actual_seed`；`raid.map_seed` 同步；客户端用同一算法重试，`layout_hash` 不一致就拒绝加入。
- 玩家 UI 不显示“生成失败”；只显示 legacy 地图。开发者模式可看 `last_report`。

### 8.3 错误码

| 码 | 含义 |
|---|---|
| `E_LAND_COMPONENT` | 最大陆块太小 |
| `E_REGION_COUNT` | 区域数不在 45–52 |
| `E_REGION_AREA` | 区域面积越界 |
| `E_DEPTH_MIX` | 深度占比偏离 |
| `E_QUOTA` | 类型配额不足 |
| `E_WATER_COUNT` | 河/湖数量不对（河 1–2、湖 2–5） |
| `E_WATER_THIN` | 出现细溪或河宽 < 1.2% × min(extent) |
| `E_WATER_FRACTION` | 水域占比不在 6–10% |
| `E_NAVIGABLE` | 没有可通航水体 |
| `E_EXIT_COUNT` | 出口不是 5 |
| `E_EXIT_SEAL` | 封锁不是 2 |
| `E_EXIT_QUADRANT` | 开放出口不足 2 象限 |
| `E_EXIT_REACH` | 出口不可达/路线穿高难 |
| `E_SHRINE` | 神龛不足或不可达 |
| `E_BOSS` | Boss 缺失/不在高危核心 |
| `E_ARENA` | 竞技场净空/入口不足 |
| `E_SPAWN` | 出生点非法 |
| `E_SITE_REACH` | 图版不可达 |
| `E_SITE_OVERLAP` | 图版重叠/卡墙/入水 |
| `E_ROAD_CONNECT` | MST 未连通 |
| `E_FERRY` | 渡船码头/水路失败 |
| `E_DETERMINISM` | 同种子哈希不一致 |
| `E_LEGACY` | 回退 legacy 的兜底标记（不是地图错误） |

---

## 9. 联机 / 快照 / 分块接口

### 9.1 P1 握手

- `raid` 新增键（必须在 `expedition.reset()` / `session.begin()` 给默认值）：
  ```gdscript
  "map_seed": int,
  "layout_version": int,
  "layout_hash": String,
  "sealed_exits": Array[int],
  ```
- 房主生成后把 `actual_seed`、`layout_version`、`layout_hash` 写进 `raid`；客户端从快照读。
- 客户端重建：`MapFactory.create(raid.map_seed, {"generated": true, "extent": ...})`；算 `layout_hash`，不一致 → `message.emit("地图版本不一致")` + 断开/拒绝加入。
- 静态地势不同步；只同步动态实体（玩家/敌人/子弹/掉落/箱子状态/神龛/raid）。
- `session.snapshot` 的包形状不变（13 项）；新键走 `raid`。
- 客户端不信任快照里的 `sites/chests` 位置？P1 可继续用服务端的；P2 改成本地同种子重建 + 动态覆盖。

### 9.2 P2 分块/气泡（接口先定）

```gdscript
class_name MapChunks
extends RefCounted

static func build_index(t: TerrainMap) -> void
static func chunk_of(p: Vector2) -> Vector2i
static func rect(chunk: Vector2i) -> Rect2
static func interest_set(cameras: Array[Vector2], radius_chunks: int) -> Array[Vector2i]
static func build_mesh(t: TerrainMap, chunk: Vector2i) -> Node3D
```

- 视觉气泡：相机周围 2–3 块（3200–4800px）；超出 4 块卸载；滞回。
- 模拟气泡：主机只在玩家周围 1.5 屏内模拟；气泡外冻结/回收；Boss 强制气泡。
- 汇合：两人距离 <2 块合并；分开各自独立。
- 过场：预载目标块，0.3–0.5s 淡入，不黑屏。
- 每帧最多建 1–2 块网格；超预算排队。

---

## 10. 迷雾与小地图

### 10.1 点亮

- `MapFog.reveal_capsule(prev, current, 900)` 沿移动路径画胶囊；每帧或 4Hz。
- 不读 viewport 尺寸、不读相机缩放、不读预渲染气泡。
- 联机：队伍共享 `merge()`；Boss 场参战者强制点亮。

### 10.2 小地图

- 数据源：`TerrainMap` 的 `land/water/height/region/roads/POI`，不是 `LeyMap`。
- `MapMinimap.build(t)` 生成地势草图：海/陆地/水/河/湖/道路/区域淡色；不画区域轮廓，不画未探索区域形状。
- 玩家打开地图时叠加 `MapFog` 暗层；只显示已点亮格。
- 区域名：`MapFog.region_coverage(t, id) >= 0.80` 后 `regions[id].named=true`；名字画在**已点亮的对应区域内**（优先质心；质心未点亮就取该区域第一个已点亮可行走采样点），不画轮廓。
- 情报点：只给区域名 + 一句模糊传闻；不给方位/轮廓。
- 小地图纹理 ≤1024×768；迷雾暗层单独纹理，按块更新。

### 10.3 现有 `explored` 字典

- legacy 继续用 `battlefield.explored`（160px 格）。
- 生成图用 `MapFog`；`battlefield` 在 `map_changed` 时 `fog.clear()`。
- `battlefield.draw_map` 对生成图走 `world_art.atlas_generated()`；对 legacy 走原 `atlas()`。
- 站点/箱子是否显示：生成图用 `fog.is_revealed(p)`；legacy 用 `explored`。

---

## 11. 地势 / Z 轴

- P1 全部 `level=0`、地形逻辑高度 0；`level_at(p)` 恒 0；`can_traverse` 只查水/墙/悬崖。P2 起 `height` 场可以写入用于小地图/视觉，但不参与 P1 移动。
- 图版 schema 从第一天带 `levels/links/foundation`；P1 只使用 `foundation` 压平。
- P4 实现：
  - `height_at/level_at/can_traverse` 走真实高度；
  - 坡道自动走、楼梯自动上、梯子按交互键；
  - Boss 场强制压平；建筑 `foundation` 压平；坡度过大不盖多层图版。
- 不做跳跃键。

---

## 12. 与现有代码的改造清单

| 文件/符号 | 现状 | P1 改法 | 验证 |
|---|---|---|---|
| `scripts/ruins.gd:4-15` 常量 | `SIZE/SPAWN/CENTER/EXIT_NAMES` 固定 | 保留；新增实例 `spawn/center/city_gate/exit_names/sealed_exits/rivers/lakes/generated/layout_version/layout_hash/terrain` | `tests/map.gd` 不变 |
| `scripts/ruins.gd:38 generate()` | 固定手绘 | 不改；`MapWorld.generate()` override | legacy 图一致 |
| `scripts/ruins.gd:239 blocked()` / `:260 move()` / `:271 clear_line()` | 全量 features 多边形 | 不改；`MapWorld` override 走 `TerrainMap` + 块索引 | `mapgen_rules` 碰撞 |
| `scripts/ruins.gd:228 biome_at()` | 6 区域 | 不改；`MapWorld` override 返回生态群系 0..5 | `ecology` 测试 |
| `scripts/session.gd:41 ruins` | `Ruins.new()` | `MapFactory.create()` | — |
| `scripts/session.gd:72 selected_mode` | — | 新增 `var mapgen_enabled := false` | — |
| `scripts/session.gd:1542 launch()` | 固定 spawn | `begin` 后按 `ruins.spawn` 重排玩家 | `mapgen_integration` |
| `scripts/session.gd:1575 begin()` | `Ruins.new().generate()` | `MapFactory.create(value, {generated, extent})`；新 `generated` 参数；写 `raid.map_*` | 联机快照 |
| `scripts/session.gd:1635 snapshot()` | 13 项包 | 包形状不变；`raid` 带 `map_seed/layout_version/layout_hash/sealed_exits` | `mapgen_integration` |
| `scripts/session.gd:3357 safe_radius()` | `Ruins.SIZE` | `ruins.extent` | 缩圈 |
| `scripts/session.gd:3342 safe_center()` | `Ruins.CENTER` 兜底 | `ruins.center` | 缩圈 |
| `scripts/session.gd:3370 can_extract()` | 只按天 | 保留；新增 `can_extract_at(i)` 查 `raid.sealed_exits` | 出口测试 |
| `scripts/session.gd:3759` 撤离循环 | `can_extract()` | `can_extract_at(i)` | 出口封锁 |
| `scripts/session.gd:4295 portal_position()` | `CITY_GATE` | `ruins.city_gate`（border） | 城市往返 |
| `scripts/expedition.gd:24` / `:54` / `:142` | `Ruins.SPAWN/CENTER` | `s.ruins.spawn` / `s.ruins.center` | `expedition` 测试 |
| `scripts/expedition.gd:129 arena()` | 固定 site 列表 | 生成图用 `ruins.sites`（已适配） | `expedition` 测试 |
| `scripts/expedition.gd:53 reset()` | 无出口键 | `sealed_exits`、`map_seed/layout_version/layout_hash` 默认值 | 快照 |
| `scripts/expedition.gd:105 guardians` | 固定 site 索引 | 用 `ruins.guardians` 候选；保留 `guardian_site` 兜底 | 守卫测试 |
| `scripts/battlefield.gd:14 camera` | `Ruins.SPAWN` | `session.ruins.spawn` | 进场 |
| `scripts/battlefield.gd:175 explored` | 160px 字典 | legacy 保留；生成图走 `MapFog` | 迷雾 |
| `scripts/battlefield.gd:544 draw_map()` | `world_art.atlas()` | 生成图走 `world_art.atlas_generated()`；出口用 `exit_name(i)`/`exit_open(i)` | 地图 UI |
| `scripts/battlefield.gd:567 regions[site.biome]` | 6 区域 | 用 `site.get("region", site.biome)`，加 bounds | 生态视图 |
| `scripts/world_3d.gd:170 rebuild()` | 4×3 固定地板 | 按 `world.extent/chunk` 算地板；河/湖循环 `world.rivers/lakes` | 场景 |
| `scripts/world_art.gd:35 terrain()` | `Ruins.river_x` 静态河 | 生成图迭代 `world.rivers`；legacy 保留旧线 | 场景 |
| `scripts/world_art.gd:103 atlas()` | `atlas.jpg` | 生成图走 `MapMinimap` 纹理 + 迷雾 | 小地图 |
| `scripts/main.gd:1624` | `Ruins.SPAWN` | `session.ruins.spawn` | 进场 |
| `scripts/main.gd:1153 on_camp_launch()` | — | `session.mapgen_enabled = selected_mode=="expedition"` | 正常游玩 |
| `scripts/dragon_boss.gd:13` / `mini_bosses.gd:14` / `wild_bosses.gd:13` | `sites[choice]` | choice 来自 `guardian_site`，P1 不改；确认越界保护 | 守卫 |
| `tests/map.gd` | legacy 固定断言 | 不改；`session.launch` 默认 legacy | 537 项 |
| `tests/mapgen_*.gd` | 无 | 新增三件套 | 新基线 |
| `PROJECT-GUIDE.md` | 无生成器章节 | P1 完成、验收后更新 §4.D/§5/§11/§12 | `verify_anchors.py` |

### 12.1 兼容语义

- `world.biome_at(p)` 仍是 0..5；`world.region_at(p)` 才是 0..51。
- `site.biome` 仍是 0..5；`site.region` 是区域 id。
- `exits` 仍是 `Array[Vector2]`；`exit_names/sealed_exits` 另存。
- `Ruins.SPAWN/CENTER/SIZE` 常量保留给 legacy 与旧测试；生成图一律读实例字段。
- `world_art`/`world_3d`/`battlefield` 只在 `world.generated` 时走新路径。

---

## 13. 测试清单

### 13.1 `tests/mapgen_rules.gd`（headless，必须 0 失败）

至少覆盖：

1. `MapGen.generate(20261019, Vector2(9600,7200))` 两次 `layout_hash` 相同；换 seed 不同。
2. `MapGen.try_generate` 返回 `ok`、`actual_seed`、`attempts`。
3. 区域 45–52；大区 35–42；碎块 8–10；无区域面积越界。
4. 深度占比在 ±6 点内。
5. 类型配额：新手 1、高难 1–3、打架 ≥3、陷阱 ≥3；新手不直连高难。
6. 河 1–2（宽河、互不重叠、无细溪）、湖 2–5；水域 6–10%；可通航 ≥1；湖/河连通。
7. 出口 5、封 2、开放 3、≥2 象限；出生点可达；存在避 high 路线。
8. 神龛 3；explore/fight/high 各 ≥1；可达。
9. Boss 在 top 3 danger；净空；≥2 入口；可达。
10. 出生点合法；图版 95% 可达；箱子/守卫/渡船可达；MST 连通。
11. 城市门 1；王城 0–1；守卫 3。
12. `MapWorld` 的 `blocked/move/clear_line`：海、深水、墙、悬崖；浅水可走。
13. `biome_at` 0..5；`region_at` -1/0..N。
14. `MapFog` reveal/coverage/serialize/merge；`REVEAL_RADIUS==900`。
15. 损坏图（删出口/改区域数）→ `MapValidate.check` 对应 `E_*`。
16. 强制失败 → `MapFactory` 回退 `Ruins` 且 `generated=false`。
17. legacy `Ruins.new().generate(1729)` 仍是 9600×7200、18 据点、6 区域、4 出口。

### 13.2 `tests/mapgen_visual.gd`（出图，不参与逻辑红绿）

输出到 `build/`（gitignore）：

- `build/mapgen-terrain.png`：高度/水/危险合成；
- `build/mapgen-regions.png`：区域类型色块 + 编号；
- `build/mapgen-minimap.png`：小地图 + 迷雾；
- `build/mapgen-three-panel.png`：地脉模板 / 地势 / 迷雾三联。

用 `Image` 逐像素画，不依赖 viewport；每张 ≤2048×1536。

### 13.3 `tests/mapgen_integration.gd`

- `TideSession` + `solo` + `mapgen_enabled=true` + `launch(false, seed)`。
- `ruins is MapWorld`；`raid.map_seed/layout_hash` 存在；5 出口封 2。
- 玩家在 `ruins.spawn`；出生点不 blocked；3 个开放出口的 `can_extract_at` 正确。
- 快照往返后客户端 `layout_hash` 一致；不一致时拒绝。
- 切换城市/回边境后地图不重建（`map_states` 保留）。
- 第 2/3 天缩圈中心/半径用 `ruins.extent`，不越界。
- `MapGen` 关闭（默认）时仍是 legacy，旧测试不受影响。

### 13.4 回归

- 先跑新三件套 0 失败。
- 再跑 legacy 基线：`tests/map.gd`、`tests/systems.gd`、`tests/expedition.gd`、`tests/ecology.gd`、`tests/area_rewards.gd`、`tests/map_visual.gd`、`tests/world_3d.gd`。
- 已知无关红（`systems.gd` 3 项等）不得因本轮变多；记录在案。
- 最后跑 `python tools/verify_anchors.py --guide PROJECT-GUIDE.md --root . --summary`。

---

## 14. P1 实施顺序与验收

### 14.1 顺序（每步可单独跑 headless）

1. **数据结构**：`map_ley.gd`、`map_terrain.gd`（字段 + 查询 + 块索引），先不生成。
2. **P0–P2**：契约、陆块、高度/折层；出 `mapgen-terrain` 草图。
3. **P3–P4**：水域、危险场；验证水域占比/核心。
4. **P5–P7**：区域、深度、类型；验证数量/面积/配额。
5. **P8–P9**：道路、图版、出口/神龛/Boss/渡船/出生点。
6. **P10–P11**：验证、重试、哈希、块索引。
7. **适配层**：`map_world.gd`、`map_factory.gd`、`session/expedition/battlefield/world_3d/world_art/main` 接线。
8. **迷雾/小地图**：`map_fog.gd`、`map_minimap.gd`、`world_art.atlas_generated()`。
9. **测试/出图/路牌**：三件套 + legacy 回归 + `PROJECT-GUIDE` 更新。

### 14.2 P1 验收

- [ ] 同种子同图；`layout_hash` 稳定；换 seed 必不同。
- [ ] 45–52 区（35–42 大区 + 8–10 碎块）。
- [ ] 1–2 条宽河（互不重叠、无细溪）+ 2–5 湖；水域 6–10%；≥1 可通航。
- [ ] 5 出口封 2；开放 3 覆盖 ≥2 象限；出生点可达。
- [ ] 3 神龛、3 守卫、1 Boss、0–1 王城、3 码头。
- [ ] 95% 图版可达；Boss 场净空/2 入口；MST 连通。
- [ ] 新手区不直连高难；Boss 可偏、不按中心。
- [ ] 迷雾 900px / 16px 位图；小地图是地势 + 迷雾，不是抽象格子。
- [ ] `MapWorld` 能被 session/战场/3D/小地图直接消费；legacy 全绿。
- [ ] 生成失败自动回退 legacy，不把坏图交给玩家。
- [ ] 当前尺寸 4 人极端负荷 ≥30fps（目标 60）；画质设置改动不影响联机怪物形成/生成/AI/掉落/伤害。
- [ ] 生成耗时：P1 当前尺寸实测约 1.0s（上限 1.2s）；P2 再压到 <500ms。
- [ ] `tests/mapgen_rules.gd` / `mapgen_integration.gd` 0 失败；`mapgen_visual` 出图。
- [ ] `PROJECT-GUIDE.md` 已更新并通过锚点自检。

### 14.3 P1 完成后的默认值

- 正常游玩（营地“搜打撤 · 出发”）默认走生成图。
- 测试/工具直接 `session.launch()` 默认 legacy；新测试显式 `mapgen_enabled=true`。
- P1 验收通过后再决定是否把默认翻到 true；翻默认必须单独提交并补测试。

### 14.4 P1 实装状态（2026-10-19）

- [x] `map_gen.gd` / `map_terrain.gd` / `map_ley.gd` / `map_blueprints.gd` / `map_validate.gd` / `map_world.gd` / `map_factory.gd` / `map_fog.gd` / `map_minimap.gd` / `map_chunks.gd` 已建。
- [x] P0–P11 全管线、`layout_hash`、8 次重试、legacy 回退。
- [x] 45–52 区、1–2 条宽河（互不重叠、无细溪）+ 2–5 湖、5 出口封 2、3 神龛、3 守卫、1 Boss、0–1 王城、3 码头。
- [x] `session/expedition/battlefield/world_3d/world_art/main` 接线；`MapFog` 900px/16px/1bit；程序化小地图。
- [x] `tests/mapgen_rules.gd` 235 项、`tests/mapgen_integration.gd` 21 项 0 失败；出图三件套。
- [x] legacy 回归：`tests/map.gd` 208/0、`expedition` 79/0、`area_rewards` 3630/0、`ecology` 1082/0、`roguelike` 194/0、`map_visual` 通过。
- [ ] P2 流式/气泡、P3 10×、P4 Z 轴、渡船实际班次（后续阶段）。

---

## 15. 待确认决策（§12 十问 + P1 尺寸）

> 推荐值已写进正文；用户确认后把“用户选择”列填上，本文件升 v0.2-final。

| # | 问题 | 推荐 | 备选 | 用户选择 |
|---|---|---|---|---|
| Q1 | 水域占比 | **目标 8%，硬范围 6–10%** | 5.5%（4–7%，更干） | **目标 8%，硬范围 6–10%** |
| Q2 | 区域名显示 | **探索 ≥80% 后在已点亮区域内浮名 + 日志** | 只进日志；只给情报点 | **已点亮区域内浮名 + 日志** |
| Q3 | 渡船班次 | **固定 180s 一班，3 码头，到站引怪** | 120s；呼叫式（等 60s） | **固定 180s 一班** |
| Q4 | Boss/潮心 | **top 3 高危核心随机 1 个，允许靠海** | 仅 top 1；3 候选玩家二选一 | **top 3 随机 1 个，允许靠海** |
| Q5 | 王城 | **0–1 座，落在高危核心（非几何中心），全图唯一；P1 先预留** | 固定中心；P1 不做 | **0–1 座，高危核心，P1 预留** |
| Q6 | 潮汐改路 | **P3 先只做圆形缩圈；水线/淹低地/切桥留 P4/P5 试验** | P3 直接水线；只淹低地不切桥 | **P3 先只做圆形缩圈** |
| Q7 | 区域类型权重 | **P1 固定权重表；人数只缩放箱子/敌人预算，不改类型权重** | 按人数调；按难度调 | **P1 固定权重表** |
| Q8 | 图版清单 | **18 个现有据点全转蓝图，另加竞技场/陷阱场/渡口/王城，共 22–26 种** | 先 12 个；只转 18，特殊结构单独写 | **18 个全转 + 特殊结构，共 22–26 种** |
| Q9 | 测试迁移 | **保留 `tests/map.gd` legacy 全绿，新增生成器测试；P1 后再迁移** | 逐步替换；只写新测试 | **保留 legacy，新增生成器测试** |
| Q10 | 10× 性能 | **尽可能优化；30fps 是接受底线；4 人正常游玩极端负荷不低于 30fps；画质设置不得影响联机怪物形成/生成/AI/掉落等模拟** | 先测基准再定；30fps 可接受 | **用户 2026-10-19：按推荐底线执行，画质只影响表现，不影响联机怪物形成等** |
| Q11 | P1 尺寸 | **当前 9,600×7,200（保 parity、测试快），`extent` 可传 2× 压测** | 2× 19,200×14,400（区域密度更接近 10×） | **当前 9,600×7,200** |

---

## 16. 风险与禁止事项

### 16.1 已知风险

1. **区域密度**：当前尺寸下 45–52 区会让每区较小；P1 用面积缩放保密度，P3 放大到 10× 后恢复设计尺寸。不要在 P1 为了“好看”偷偷减区域数。
2. **图版密度**：P1 图版预算 18–30，10× 才 80–120；不要在当前尺寸硬塞 100 个据点。
3. **生态群系索引**：`site.biome` 必须保持 0..5；区域 id 放 `site.region`。改错会让 `Ecology.POOLS` 越界。
4. **小地图整图绘制**：10× 不许画整图 `chart`；P1 就按地势纹理 + 迷雾做，别留整图后路。
5. **`blocked()` 全量多边形**：P1 必须建块索引；不要等 P2 再补。
6. **`world_3d.rebuild()` 放大**：P3 前不许直接改 30,400×22,800；先把 P2 气泡做完。
7. **确定性**：不要用全局 `randf()`、不要遍历未排序字典、不要读时间；否则联机哈希对不上。
8. **`layout_version`**：改任何影响地形的 pass 都必须 +1；否则旧种子/旧客户端会静默错位。

### 16.2 禁止事项

- 不在签字前写 P1 代码。
- 不动潜入血潮/魔境/猎场/剧情地图。
- 不删 legacy 固定图；它是测试基线和失败兜底。
- 不做“越靠中心越难”的径向项。
- 不把迷雾半径绑到 viewport/预渲染气泡。
- **不把画质设置接进模拟**：怪物的形成/生成/数量/AI/掉落/伤害只能由权威端规则决定；画质档位只降表现，不降模拟。
- 不往项目树写带 `class_name` 的临时快照；对比脚本写 `$env:TEMP`。
- 不 `git add .`；幽灵文件永不 add。
- 不先做 10× 再补流式。

---

## 17. 附录

### 17.1 常量索引

| 常量 | 值 | 位置 |
|---|---|---|
| `LAYOUT_VERSION` | 4 | `map_gen.gd` |
| `GRID` | 32.0 | `map_terrain.gd` |
| `CHUNK` | 1600.0 | `map_terrain.gd` |
| `REVEAL_RADIUS` | 900.0 | `map_fog.gd` |
| `FOG_CELL` | 16.0 | `map_fog.gd` |
| `WADE_DEPTH` | 24.0 | `map_terrain.gd` |
| `EXIT_COUNT` | 5 | `map_gen.gd` |
| `SEALED_EXITS` | 2 | `map_gen.gd` |
| `SHRINE_COUNT` | 3 | `map_gen.gd` |
| `GUARDIAN_COUNT` | 3 | `map_gen.gd` |
| `BOSS_CANDIDATES` | 3 | `map_gen.gd` |
| `FERRY_DOCKS` | 3 | `map_gen.gd` |
| `FERRY_PERIOD` | 180.0 | `map_gen.gd`（P3 实装） |

### 17.2 与交接文档的差异

本文件相对 `docs/MAPGEN-HANDOVER.md` §5 的细化/修正：

1. 明确 **当前尺寸 P1** 与 10× 的 `area_scale` 换算；区域/图版/箱子数量按面积缩放，区域数不变。
2. 明确 `site.biome`（0..5）与 `site.region`（0..51）分离，避免生态索引越界。
3. 明确 `MapWorld` 适配层与 `MapFactory` 回退；旧测试默认 legacy。
4. 明确 `MapFog` 1 bit/16px、900px、12×12 采样 80% 命名。
5. 明确 `layout_hash` 的规范化与联机握手。
6. 明确 P1 图版预算（18–30）与 10×（80–120）的区别；P1 不硬塞 10× 密度。
7. 明确 `can_extract_at(i)` 与 `raid.sealed_exits`，不把“封锁”做成全局开关。
8. 明确 `blocked()` 的块索引在 P1 就建，不等到 P2。

### 17.3 签字前最后检查

- [x] §15 每项都有用户选择。
- [x] 没有与 `docs/MAPGEN-HANDOVER.md` §2 冲突的条款。
- [x] 没有把 P2/P3/P4 的内容写进 P1 验收。
- [x] 数值表与 pass 签名能一一对应。
- [x] 用户确认 `docs/MAPGEN-SPEC.md` 为 v0.2-final 后，开始 P1。
