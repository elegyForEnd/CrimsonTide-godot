extends SceneTree

## R4 验收：魔境层间节点图生成器（`scripts/rogue_graph.gd`）。
## 覆盖：确定性（同种子逐字段相同）、结构不变量（1 boss / 无环 / 无死路 / 出口 1~2 /
## 节点数 [14,16] / 入口可达 / 每层 ≥1 补给）、房间类型可抽性（含 5 种新房间）、
## 与旧「每层 7 区」的等价映射、以及"只许用局部 RNG、不许碰全局随机/会话"。

const Graph = preload("res://scripts/rogue_graph.gd")

var checks := 0
var failures := 0

const AUDIT_SEEDS := 200
const DETERMINISM_SEEDS := 100
const FLOORS := 5

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func dump(g: Dictionary) -> String:
	var lines: Array = [
		"floor=%d" % int(g.get("floor", -1)),
		"entry=%s" % str(g.get("entry", "")),
		"boss=%s" % str(g.get("boss", "")),
	]
	var nodes: Dictionary = g.get("nodes", {})
	for id in g.get("order", []):
		var n: Dictionary = nodes.get(str(id), {})
		var nexts: Array = []
		for nid in n.get("next", []):
			nexts.append(str(nid))
		lines.append("%s|%s|%d|%s" % [str(id), str(n.get("kind", "")), int(n.get("depth", -1)), ",".join(nexts)])
	return "\n".join(lines)

func audit(g: Dictionary, tag: String, seen_kinds: Dictionary) -> Dictionary:
	var nodes: Dictionary = g.get("nodes", {})
	var order: Array = g.get("order", [])
	var max_depth := 0
	var layer_sizes := {}
	var boss_ids: Array = []
	var supplies := 0
	var new_kinds := {}
	var seen_ids := {}
	check(nodes.size() >= Graph.MIN_NODES and nodes.size() <= Graph.MAX_NODES, "%s node count must stay in [%d,%d] (got %d)" % [tag, Graph.MIN_NODES, Graph.MAX_NODES, nodes.size()])
	check(order.size() == nodes.size(), "%s order must list every node exactly once" % tag)
	for id in order:
		var sid := str(id)
		check(not seen_ids.has(sid), "%s duplicate node in order: %s" % [tag, sid])
		seen_ids[sid] = true
		var n: Dictionary = nodes.get(sid, {})
		check(not n.is_empty(), "%s order references a missing node: %s" % [tag, sid])
		if n.is_empty():
			continue
		check(str(n.get("id", "")) == sid, "%s node id field must match its key" % tag)
		var kind := str(n.get("kind", ""))
		var depth := int(n.get("depth", 0))
		max_depth = maxi(max_depth, depth)
		layer_sizes[depth] = int(layer_sizes.get(depth, 0)) + 1
		seen_kinds[kind] = int(seen_kinds.get(kind, 0)) + 1
		if kind == Graph.BOSS:
			boss_ids.append(sid)
		if kind in Graph.SUPPLY_KINDS:
			supplies += 1
		if kind in Graph.NEW_KIND_MIN_DEPTH:
			check(not new_kinds.has(kind), "%s each new room appears at most once per floor (%s)" % [tag, kind])
			new_kinds[kind] = true
			check(depth >= int(Graph.NEW_KIND_MIN_DEPTH[kind]), "%s new room %s must not appear before depth %d" % [tag, kind, int(Graph.NEW_KIND_MIN_DEPTH[kind])])
		var nexts: Array = n.get("next", [])
		if kind == Graph.BOSS:
			check(nexts.is_empty(), "%s the boss must be a terminal node" % tag)
		else:
			check(nexts.size() == (1 if depth == Graph.node(g, str(g.boss)).depth - 1 else 2), "%s non-boss exits must offer both branches except at the guardian (maximum %d, got %d)" % [tag, Graph.MAX_SUCCESSORS, nexts.size()])
		for nid in nexts:
			var target: Dictionary = nodes.get(str(nid), {})
			check(not target.is_empty(), "%s exit points at a missing node: %s" % [tag, str(nid)])
			check(int(target.get("depth", 0)) == depth + 1, "%s exits may only reach the next depth (%s -> %s)" % [tag, sid, str(nid)])
	# Exactly one boss, deepest, and reachable from the entry.
	check(boss_ids.size() == 1, "%s each floor must own exactly one boss (got %d)" % [tag, boss_ids.size()])
	check(boss_ids.size() == 1 and str(g.get("boss", "")) == str(boss_ids[0]), "%s root boss field must point at that node" % tag)
	check(int(nodes.get(str(g.get("boss", "")), {}).get("depth", 0)) == max_depth, "%s the boss must sit on the deepest layer" % tag)
	var entry := str(g.get("entry", ""))
	var entry_node: Dictionary = nodes.get(entry, {})
	check(not entry_node.is_empty(), "%s the entry node must exist" % tag)
	check(int(entry_node.get("depth", 0)) == 1 and str(entry_node.get("kind", "")) == Graph.ENTRY_KIND, "%s the entry must be a depth-1 %s" % [tag, Graph.ENTRY_KIND])
	var reached := {entry: true}
	var queue: Array = [entry]
	while not queue.is_empty():
		var current := str(queue.pop_front())
		for nid in nodes.get(current, {}).get("next", []):
			if not reached.has(str(nid)):
				reached[str(nid)] = true
				queue.append(str(nid))
	check(reached.size() == nodes.size(), "%s every node must be reachable from the entry (%d/%d)" % [tag, reached.size(), nodes.size()])
	check(supplies >= 1, "%s every floor needs at least one supply node" % tag)
	# 旧「每层 7 区」投影：一个深度 = 一个区。
	var areas: Array = Graph.legacy_areas(g)
	check(areas.size() == max_depth, "%s area view must match the layer count" % tag)
	if areas.size() >= 2:
		check(str(areas[0].room) == Graph.ENTRY_KIND, "%s first area must be the entry kind" % tag)
		check(str(areas[areas.size() - 1].room) == Graph.BOSS, "%s last area must be the boss" % tag)
		for i in areas.size():
			var exits: Array = areas[i].exits
			if i == areas.size() - 1:
				# The boss is terminal: the final area offers no way onwards.
				check(exits.is_empty(), "%s the final area must be terminal" % tag)
			else:
				check(exits.size() >= 1 and exits.size() <= Graph.MAX_SUCCESSORS, "%s area %d exits must stay in [1,%d]" % [tag, i + 1, Graph.MAX_SUCCESSORS])
				check(exits.size() == int(layer_sizes.get(i + 2, 0)), "%s area %d must offer every next-layer room" % [tag, i + 1])
	# 图必须能被 JSON 往返（联机快照/存档只认 JSON 可序列化类型）。
	var text := JSON.stringify(g)
	var back = JSON.parse_string(text)
	check(text.length() > 0 and back is Dictionary, "%s the graph must survive JSON serialization" % tag)
	check(back is Dictionary and Graph.signature(back) == Graph.signature(g), "%s the signature must survive JSON round trip" % tag)
	var singles := 0
	for depth in layer_sizes:
		if int(layer_sizes[depth]) == 1:
			singles += 1
	return {"nodes": nodes.size(), "depths": max_depth, "singles": singles}

func run() -> void:
	# ① 对外契约：kinds() / node() / neighbors() / signature() 的边界行为。
	var kinds: Array = Graph.kinds()
	check(kinds.size() == 10, "kinds() must advertise ten non-boss room types (got %d)" % kinds.size())
	for kind in ["combat", "elite", "shop", "treasure", "talent", "curse", "event", "forge", "gamble", "mirror"]:
		check(kind in kinds, "kinds() must contain %s" % kind)
	check(not (Graph.BOSS in kinds), "kinds() must not contain the boss itself")
	check(Graph.signature({}).length() == 64, "signature() must digest even an empty graph")
	var sample: Dictionary = Graph.build(7, 1)
	check(Graph.node(sample, "missing").is_empty(), "node() must return {} for an unknown id")
	check(Graph.neighbors(sample, "missing").is_empty(), "neighbors() must return [] for an unknown id")
	check(Graph.node(sample, str(sample.entry)).size() == 4, "node() must expose the frozen id/kind/depth/next fields")
	check(Graph.neighbors(sample, str(sample.entry)) == Graph.node(sample, str(sample.entry)).next, "neighbors() must mirror the node next list")

	# ② 确定性：同 (seed, floor) 逐字段相同，且不同 (seed, floor) 之间不共享可变状态。
	var identical := 0
	for seed_value in DETERMINISM_SEEDS:
		for f in range(1, FLOORS + 1):
			var a: Dictionary = Graph.build(seed_value, f)
			var b: Dictionary = Graph.build(seed_value, f)
			check(dump(a) == dump(b), "same seed must rebuild the identical graph (seed=%d floor=%d)" % [seed_value, f])
			check(Graph.signature(a) == Graph.signature(b), "same seed must digest identically (seed=%d floor=%d)" % [seed_value, f])
			identical += 1
	check(identical == DETERMINISM_SEEDS * FLOORS, "determinism sample must cover %d graphs" % (DETERMINISM_SEEDS * FLOORS))

	# ③ 不同种子必须产出不同的图（区间断言，避免点估计）。
	var distinct := {}
	# ④ 结构不变量 + 房间类型覆盖。
	var seen_kinds := {}
	var min_nodes := 99
	var max_nodes := 0
	var min_depths := 99
	var max_depths := 0
	for seed_value in AUDIT_SEEDS:
		for f in range(1, FLOORS + 1):
			var g: Dictionary = Graph.build(seed_value, f)
			var tag := "seed=%d floor=%d" % [seed_value, f]
			var info: Dictionary = audit(g, tag, seen_kinds)
			min_nodes = mini(min_nodes, int(info.nodes))
			max_nodes = maxi(max_nodes, int(info.nodes))
			min_depths = mini(min_depths, int(info.depths))
			max_depths = maxi(max_depths, int(info.depths))
			if f == 1:
				distinct[Graph.signature(g)] = true
	check(distinct.size() >= 50, "different seeds must produce different graphs (got %d distinct out of %d)" % [distinct.size(), AUDIT_SEEDS])
	check(min_nodes == Graph.MIN_NODES and max_nodes == Graph.MAX_NODES, "the sample must span the [%d,%d] node-count range (got %d..%d)" % [Graph.MIN_NODES, Graph.MAX_NODES, min_nodes, max_nodes])
	check(min_depths == Graph.MIN_DEPTHS and max_depths == Graph.MAX_DEPTHS, "the sample must span the [%d,%d] depth range (got %d..%d)" % [Graph.MIN_DEPTHS, Graph.MAX_DEPTHS, min_depths, max_depths])
	for kind in Graph.kinds():
		check(int(seen_kinds.get(kind, 0)) >= 1, "every advertised room type must be sampled: %s" % kind)
	check(int(seen_kinds.get(Graph.BOSS, 0)) == AUDIT_SEEDS * FLOORS, "every sampled floor must contribute exactly one boss")

	# ⑤ 只许用局部 RNG：生成图不得消耗全局随机序列。
	seed(20261005)
	var before := randi()
	seed(20261005)
	var untouched: Dictionary = Graph.build(12345, 3)
	var after := randi()
	check(not untouched.is_empty(), "the projection probe must still build a graph")
	check(before == after, "build() must not consume the global random sequence (local RNG only)")

	# ⑥ 与旧「每层 7 区」的等价映射：旧槽位模板必须能被逐槽表达。
	var legacy: Dictionary = Graph.from_route(Graph.LEGACY_ROUTE)
	check(legacy.size() == 5, "from_route() must return the frozen graph shape")
	var areas: Array = Graph.legacy_areas(legacy)
	check(areas.size() == Graph.LEGACY_ROUTE.size(), "the legacy template must project onto %d areas" % Graph.LEGACY_ROUTE.size())
	for i in Graph.LEGACY_ROUTE.size():
		check(str(areas[i].room) == str(Graph.LEGACY_ROUTE[i]), "legacy area %d must keep its original room" % (i + 1))
		check((areas[i].kinds as Array).size() == 1, "legacy area %d must map to exactly one node" % (i + 1))
		check((areas[i].exits as Array).size() <= Graph.MAX_SUCCESSORS, "legacy area %d must not exceed two exits" % (i + 1))
	check(str(areas[areas.size() - 1].room) == Graph.BOSS, "the legacy seventh area must be the boss")
	check(str(Graph.node(legacy, str(legacy.entry)).kind) == str(areas[0].room), "the legacy chain entry must be the first area")
	check(str(Graph.node(legacy, str(legacy.boss)).kind) == str(areas[areas.size() - 1].room), "the legacy chain boss must be the last area")
	check(Graph.from_route([]).is_empty(), "an empty route must not fabricate a graph")
	check(Graph.from_route(["combat"]).is_empty(), "a single-slot route must not fabricate a graph")
	check(Graph.signature(Graph.from_route(Graph.LEGACY_ROUTE)) == Graph.signature(Graph.from_route(Graph.LEGACY_ROUTE)), "from_route() must be deterministic")

	print("ROGUE GRAPH ", checks, " checks / ", failures, " failures", " | nodes ", min_nodes, "..", max_nodes, " depths ", min_depths, "..", max_depths, " distinct(floor1) ", distinct.size(), "/", AUDIT_SEEDS, " kinds ", seen_kinds.size())
	quit(1 if failures else 0)
