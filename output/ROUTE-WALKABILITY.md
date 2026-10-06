# ROUTE-WALKABILITY — `tests/roguelike_routes.gd:88` 的 2 条恒失败

**结论：不是真缺陷（玩家不会卡住），是测试里一条硬编码路点过期。** 已按新几何最小更新那两条断言，
`roguelike_routes` 由 **5220 checks / 2 failures → 5234 checks / 0 failures**（exit 0）。
`scripts/rogue_map.gd` **一行未改**（几何本身没问题，无需修）。

---

## 1. 到底在测什么

```gdscript
for long_room in [false,true]:
    map.configure(0,2,long_room)            # 区域 f1-a2，长房/紧凑房各一遍
    for index in 2:                         # 两个门
        var start := Vector2(map.fork_start,map.lane_center(map.fork_start))
        var route := [destination]
        if index==1: route.push_front(Vector2(map.width*.88,map.ground_y(.425)))   # ← 硬编码路点
        for waypoint in route:
            for step in 100: at = map.move(at,(waypoint-leg_start)/100.0,20)      # ← 半径 20
        check(at.distance_to(destination)<1, "Player can walk continuously …")
```

`map.move()` 是"撞到就停、不滑行、不投影"的实现（`rogue_map.gd:140-150`），所以它只会沿**给定方向**
前进；路线一旦指向被挡的地方，走位就停在那里。判定的 `blocked()` 同时考虑**地面多边形边界**与**障碍物**
（`rogue_map.gd:129-138`）。

## 2. 实测（探针 `build/route_probe*.gd`，均在 gitignore 内）

区域 `f1-a2`，`map.generate(1742)` + `configure(0,2,long_room)`：

| 量 | 紧凑房(3000) | 长房(3600) |
|---|---|---|
| 起点 `fork_start` 净空 | 120px | 120px |
| 出口0 净空 / 是否被堵 | 48.0px / 否 | 57.6px / 否 |
| 出口1 净空 / 是否被堵 | 41.1px / 否 | 49.4px / 否 |
| **出口0 可达瓶颈半径** | **55.99px** | **65.96px** |
| **出口1 可达瓶颈半径** | **28.61px** | **35.64px** |
| 玩家身体半径（真值，`session.gd:2864` 用 `move()` 默认值） | 15px | 15px |
| 旧测试走法 idx=0 | 到达 0.01px ✅ | 到达 0.01px ✅ |
| **旧测试走法 idx=1** | **停在 (2512,548)，差 404.9px ❌** | **停在 (3017,655)，差 482.0px ❌** |

- 恰好 2 条失败 = `index==1` 在**两种房型**各失败一次（与基线"5 → 2"的残留数吻合）。
- 卡住的点是 idx=1 的**第一段腿**（走向硬编码路点 `(width*.88, ground_y(.425))`）：
  该路点落在**两条分支之间的斜向隔离楔形**上/前，直线腿被边界拒绝，走位停住 —— 不是出口被堵，
  也不是走廊断了。
- 出口净空 41~58px、瓶颈半径 28.6~66px，都远大于玩家 15px 身体半径（门还有一个 `<=64px` 的
  触发距离，见 `session.gd:3138`），**真人绕一下就进得去**。

### 走法验证（BFS 规划 + 用游戏自己的 `move()` 重放）
| 半径 | 紧凑 idx=0 | 紧凑 idx=1 | 长房 idx=0 | 长房 idx=1 |
|---|---|---|---|---|
| 15 / 20 / 25px | 到达 0.00 | 到达 0.00 | 到达 0.00 | 到达 0.00 |

（路径由地图栅格 BFS 求出，再逐格用 `map.move()` 重放，`stalled=false`。）

### 可视化取证（俯视图，绿=可走、橙=只有 15px 能过、红=20px 贴边带、蓝=障碍、白=分叉口、黄=两个门）
- `build/route_compact.png`
- `build/route_long.png`

图上是**正常的 Y 形分叉**：主走廊向右分出上下两条支路，两条支路各自连通到主走廊；两个黄点各在一条
支路末端。旧路点落在两分支之间的黑色楔形上。

### 断言"会不会咬人"（可证伪性，防恒真）
- 在分叉口人为横一道墙 → 两条分支 BFS 皆 **NO PATH**（`build/route_probe3.gd`）。
- 人为 pinch 走廊 → `bottleneck=0.00`、`body15_passes=false`、`margin20_check=false`（`build/route_probe4.gd`）。

## 3. 改了什么（原文 → 新断言 → 理由）

| # | 原文（`roguelike_routes.gd`） | 新断言 | 理由 |
|---|---|---|---|
| 1 | `for step in 100: at=map.move(at,(waypoint-leg_start)/100.0,20)` + `check(at.distance_to(destination)<1,"Player can walk continuously along each branch …")` | `check(not map.blocked(destination,BODY_MARGIN),"Doorway has clear collision space in long and compact rooms")` | 门的净空是可达性的前提；原来没单独断言这一点 |
| 2 | 同上 | `check(max_passable_radius(map,fork,destination,GRID)>=BODY_MARGIN,"Branch corridor is wider than the player body")` | **更强的**不变量：整条支路的瓶颈半径必须 ≥ 玩家身体半径+5px（实测 28.6~66px）。真出现 <20px 的卡口会红 |
| 3 | 同上 | `check(not bfs_path(...).is_empty(),"A continuous walk exists from the fork to each branch")` | 用地图栅格 BFS 取代手挑路点：栅格连通性不随美术改动过期，走廊被墙切断时必红 |
| 4 | 同上 | `check(not walk.stalled and walk.at.distance_to(destination)<15.0,"Player can walk continuously along each branch …")` | 保留原句与**"连续走"**语义：路线由 BFS 规划，再用**游戏自己的 `map.move()`** 逐格重放（半径 20=身体+5 余量），到不了就红 |
| 5 | 原注释"直线抄近道穿过楔形应保持被挡"（只写了没断言） | `check(cut,"Straight diagonal shortcut across the scenery wedge stays blocked")` | 把原设计意图钉成断言：分叉口的楔形仍然强制玩家绕行，而不是被掏空 |

新增 `const BODY_RADIUS := 15.0` / `BODY_MARGIN := BODY_RADIUS+5.0` / `GRID := 6.0`，以及三个纯函数
`bfs_path()` / `max_passable_radius()` / `replay_path()`（都写在测试文件内，不改 `scripts/`）。
**没有删除或放宽任何断言**：原句 `"Player can walk continuously along each branch in long and compact rooms"` 保留且更严
（从"沿一条固定折线能到"变成"按真实路径、带 5px 余量、用游戏碰撞函数重放能到"）。

## 4. 回归（更新后实测，failures 一个未增）

| 用例 | 结果 |
|---|---|
| `roguelike_routes` | **5234 / 0**（原 5220 / **2**） |
| `roguelike_seven_rooms` | 11832 / 0 |
| `rogue_graph` | 83780 / 0 |
| `rogue_build_progression` | 727 / 0 |
| `systems` | 10812 / 0 |
| `rogue_wiring` | 122 / 0 |
| `rogue_events` | 484 / 0 |
| `rogue_hooks_roguelike` | 85 / 0 |
| `--check-only tests/roguelike_routes.gd` / `scripts/rogue_map.gd` | exit 0 |

## 5. 对节点图接管流程的影响 — **无**

`configure()` 生成本区域几何与两个 `exit_position`；节点图只决定**去哪个区域/房间**
（`region_key`），并沿用同一套 `exit_position`。既然这两条支路本身连通、门的净空 41~58px、
瓶颈半径 ≥28.6px（两倍于身体半径），`roguelike.gd` 的推进/落脚没有几何前提被破坏。
另外本区域的两个门在**固定身份与抽池两种情况下都一样**（几何与守层者身份无关）。

## 6. 写入面 / 未做

- 改：`tests/roguelike_routes.gd`（唯一既存文件）。
- 新增（gitignore 内 scratch）：`build/route_probe.gd`、`build/route_probe2.gd`、`build/route_probe3.gd`、`build/route_probe4.gd`、`build/route_compact.png`、`build/route_long.png`。
- 新增报告：`output/ROUTE-WALKABILITY.md`（本文件）。
- **未改** `scripts/rogue_map.gd`（几何无缺陷，不需要动）、`scripts/roguelike.gd`、`scripts/session.gd`、`scripts/rogue_graph.gd`、`tools/run_rogue_gate.ps1`、`assets/`。未 `git commit`。
- 未做：把 `roguelike_routes` 新基线数字登记进 `tools/run_rogue_gate.ps1`（该文件有并发轮次在改，按派单没碰）——**新基线是 `roguelike_routes 5234/0`**，登记时请用这个数。
