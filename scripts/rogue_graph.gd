class_name RogueGraph
extends RefCounted

## 魔境「层间节点图」生成器（R4 / 契约见 output/ROGUE-CONTRACTS.md §5、§6.2、§7）。
##
## 纯逻辑模块：不读会话、不写会话、**绝不消耗 `s.rng`**。
## 种子由 (seed_value, floor) 纯函数派生，两端（房主/客户端）各自本地重建都能得到
## 逐字段相同的图 —— 这是"整张图不进每 0.1s 快照"（契约 C1）的前提。
##
## 结构：分层 DAG，深度 1..D。
##   * 第 1 层只有 1 个入口节点，kind 恒为 `combat`（对应旧 `route[0]`）。
##   * 第 D 层只有 1 个 boss 节点，`next` 为空。
##   * 中间层每层 2 个节点；深度 d 的每个节点与深度 d+1 的**全部**节点相连，
##     所以每个非 boss 节点的出口数是 1~2。
##       - `ground-manifest.json` 里每个 region key 恰好 2 个出口，
##         `rogue_map.exit_position(index)` 也只支持 0/1（`rogue_map.gd:112`）；
##       - `rogue_map.gd:94-95` 有 `assert(joined.size()==1)`，出口数不能超 2。
##   * 全图无环、无死路（boss 除外）、从入口全可达。
##   * 每条路线仍走 7~9 个房间；两条分支的节点总数 ∈ [12, 16]。
##
## 与旧「每层 7 区」的等价性：
##   `legacy_areas()` 把图按"一个深度 = 一个区"投影成旧版相容视图；
##   `from_route()` 能把旧版 7 槽 route 模板逐槽还原成一张链式图，
##   两者一起证明节点图**能表达**既有的 7 区关卡（R5 移植旧断言的桥）。

const BOSS := "boss"
const ENTRY_KIND := "combat"
## 旧版每层槽位模板（`roguelike.gd:59` `new_floor()` 写的就是这一串）。
const LEGACY_ROUTE := ["combat", "talent", "elite", "shop", "combat", "treasure", "boss"]
## 非 boss 的可出现房间类型（= `kinds()` 的返回值）。
const MIDDLE_KINDS := ["combat", "elite", "shop", "treasure", "talent", "curse", "event", "forge", "gamble", "mirror"]
## 紧邻 boss 的那一层只放常规战斗房，避免"守层者门前是商店/赌徒"的节奏问题。
const PREBOSS_KINDS := ["combat", "elite"]
## 新房间允许出现的最小深度（1-based）；mirror 更晚，避免开局就被镜像挑战打断。
const NEW_KIND_MIN_DEPTH := {"curse": 3, "event": 3, "forge": 3, "gamble": 4, "mirror": 5}
const SUPPLY_KINDS := ["shop", "treasure"]
const MIN_DEPTHS := 7
const MAX_DEPTHS := 9
const MIN_NODES := 12
const MAX_NODES := 16
const MAX_SUCCESSORS := 2

## 全部可出现的非 boss 房间类型。
static func kinds() -> Array:
	return MIDDLE_KINDS.duplicate()

## 节点字典（深拷贝；未知 id → 空字典）。
static func node(g: Dictionary, id: String) -> Dictionary:
	var nodes: Dictionary = g.get("nodes", {})
	var found: Dictionary = nodes.get(id, {})
	if found.is_empty():
		return {}
	return found.duplicate(true)

## 后继节点 id（有序；未知 id → 空数组）。
static func neighbors(g: Dictionary, id: String) -> Array:
	var found: Dictionary = node(g, id)
	if found.is_empty():
		return []
	return (found.get("next", []) as Array).duplicate()

## 稳定摘要：只由 order/kind/depth/next 与 floor/entry/boss 拼出，供两端与测试比对。
## 不依赖 Dictionary 的插入顺序，JSON 往返后摘要不变。
static func signature(g: Dictionary) -> String:
	var lines: Array = [
		"floor=%d" % int(g.get("floor", 0)),
		"entry=%s" % str(g.get("entry", "")),
		"boss=%s" % str(g.get("boss", "")),
	]
	var nodes: Dictionary = g.get("nodes", {})
	for id in g.get("order", []):
		var n: Dictionary = nodes.get(str(id), {})
		var nexts: Array = []
		for nid in n.get("next", []):
			nexts.append(str(nid))
		lines.append("%s|%s|%d|%s" % [str(id), str(n.get("kind", "")), int(n.get("depth", 0)), ",".join(nexts)])
	return "\n".join(lines).sha256_text()

## 按契约生成一层的节点图。同一 (seed_value, floor) 永远得到逐字段相同的结果。
static func build(seed_value: int, floor: int) -> Dictionary:
	var floor_index := maxi(1, int(floor))
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for(int(seed_value), floor_index)

	# 每个中间深度提供两个真实目的地，避免地图有分叉却只有一条出口。
	var depths := MIN_DEPTHS + rng.randi_range(0, MAX_DEPTHS - MIN_DEPTHS)
	var sizes: Array[int] = []
	for i in depths:
		sizes.append(1 if i==0 or i==depths-1 else 2)

	# 逐层分配房间类型。
	var kinds_by_depth: Array = []
	for _d in range(1, depths + 1):
		kinds_by_depth.append([])
	kinds_by_depth[0] = [ENTRY_KIND]
	kinds_by_depth[depths - 1] = [BOSS]
	var used_new := {}
	var talent_used := 0
	var middle_slots: Array = []
	for d in range(2, depths):
		for i in sizes[d - 1]:
			var kind := ""
			if d == depths - 1:
				kind = str(PREBOSS_KINDS[rng.randi_range(0, PREBOSS_KINDS.size() - 1)])
				if i > 0 and kind == str(kinds_by_depth[d - 1][0]):
					kind = str(PREBOSS_KINDS[1]) if str(kinds_by_depth[d - 1][0]) == str(PREBOSS_KINDS[0]) else str(PREBOSS_KINDS[0])
			else:
				kind = _pick_kind(rng, d, used_new, talent_used)
				if kind in NEW_KIND_MIN_DEPTH:
					used_new[kind] = true
				if kind == "talent":
					talent_used += 1
			kinds_by_depth[d - 1].append(kind)
			if d <= depths - 2:
				middle_slots.append([d, kinds_by_depth[d - 1].size() - 1])
	# 保底：每层至少一个商店/宝藏补给节点（旧模板的 route[3]/route[5] 语义）。
	var has_supply := false
	for d in range(2, depths):
		for kind in kinds_by_depth[d - 1]:
			if str(kind) in SUPPLY_KINDS:
				has_supply = true
	if not has_supply and not middle_slots.is_empty():
		var slot: Array = middle_slots[rng.randi_range(0, middle_slots.size() - 1)]
		kinds_by_depth[int(slot[0]) - 1][int(slot[1])] = str(SUPPLY_KINDS[rng.randi_range(0, SUPPLY_KINDS.size() - 1)])

	# 建节点，再一次性接边（layer d → layer d+1 全连）。
	var nodes := {}
	var order: Array = []
	var ids_by_depth: Array = []
	for d in range(1, depths + 1):
		var ids: Array = []
		for i in sizes[d - 1]:
			var id := _node_id(floor_index, d, i)
			ids.append(id)
			order.append(id)
			nodes[id] = {"id": id, "kind": str(kinds_by_depth[d - 1][i]), "depth": d, "next": []}
		ids_by_depth.append(ids)
	for d in range(1, depths):
		var next_ids: Array = []
		for nid in ids_by_depth[d]:
			next_ids.append(str(nid))
		for id in ids_by_depth[d - 1]:
			nodes[str(id)]["next"] = next_ids.duplicate()
	return {
		"floor": floor_index,
		"entry": str(ids_by_depth[0][0]),
		"boss": str(ids_by_depth[depths - 1][0]),
		"order": order,
		"nodes": nodes,
	}

## 把节点图投影成"旧版每层若干区"的相容视图：一个深度 = 一个区。
## 只用于证明节点图能表达既有 7 区关卡（R5 移植旧断言时的桥），不参与游戏逻辑。
## 返回 [{"area":int, "room":String, "kinds":Array, "exits":Array}]，按深度升序。
static func legacy_areas(g: Dictionary) -> Array:
	var nodes: Dictionary = g.get("nodes", {})
	var layers := {}
	var depths := 0
	for id in g.get("order", []):
		var n: Dictionary = nodes.get(str(id), {})
		if n.is_empty():
			continue
		var depth := int(n.get("depth", 0))
		depths = maxi(depths, depth)
		if not layers.has(depth):
			layers[depth] = []
		layers[depth].append(str(id))
	var areas: Array = []
	for d in range(1, depths + 1):
		var ids: Array = layers.get(d, [])
		var kinds: Array = []
		for id in ids:
			kinds.append(str(nodes[str(id)].get("kind", "")))
		var exits: Array = []
		if not ids.is_empty():
			for nid in nodes.get(str(ids[0]), {}).get("next", []):
				var target: Dictionary = nodes.get(str(nid), {})
				exits.append(str(target.get("kind", "")))
		areas.append({
			"area": d,
			"room": str(kinds[0]) if not kinds.is_empty() else "",
			"kinds": kinds,
			"exits": exits,
		})
	return areas

## 由显式房间列表构造"每层 1 个节点"的链式图。
## 用途：① 证明节点图能逐槽表达旧版 7 区关卡（`from_route(LEGACY_ROUTE)`）；
##      ② R5 在需要退回旧结构时的兼容构造。少于 2 槽（入口 + 终点都放不下）→ 空字典。
static func from_route(route: Array, floor_index: int = 1) -> Dictionary:
	if route.size() < 2:
		return {}
	var nodes := {}
	var order: Array = []
	var layers: Array = []
	for i in route.size():
		var id := _node_id(floor_index, i + 1, 0)
		order.append(id)
		layers.append(id)
		nodes[id] = {"id": id, "kind": str(route[i]), "depth": i + 1, "next": []}
	for i in range(route.size() - 1):
		nodes[str(layers[i])]["next"] = [str(layers[i + 1])]
	return {
		"floor": floor_index,
		"entry": str(layers[0]),
		"boss": str(layers[layers.size() - 1]),
		"order": order,
		"nodes": nodes,
	}

static func _pick_kind(rng: RandomNumberGenerator, depth: int, used_new: Dictionary, talent_used: int) -> String:
	var candidates: Array = []
	for kind in MIDDLE_KINDS:
		if kind in NEW_KIND_MIN_DEPTH:
			if depth < int(NEW_KIND_MIN_DEPTH[kind]) or used_new.has(kind):
				continue
		if kind == "talent" and talent_used >= 2:
			continue
		candidates.append(kind)
	if candidates.is_empty():
		return ENTRY_KIND
	return str(candidates[rng.randi_range(0, candidates.size() - 1)])

static func _node_id(floor_index: int, depth: int, index: int) -> String:
	return "f%d-d%d-%d" % [floor_index, depth, index]

static func _seed_for(seed_value: int, floor_index: int) -> int:
	# 纯整数混合（不用字符串散列，避免依赖其实现细节）：同输入必得同种子。
	return (int(seed_value) * 1103515245 + int(floor_index) * 12345 + 0x5F3759DF) & 0x7FFFFFFF
