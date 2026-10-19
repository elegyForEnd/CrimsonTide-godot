class_name TerrainMap
extends RefCounted
## Authoritative generated terrain. One instance per raid.
##
## All gameplay queries (blocked/move/clear_line/region/biome) live here. The
## Ruins adapter (MapWorld) exposes the legacy field names but never owns a
## second copy of collision data.
##
## Determinism: every field is filled by MapGen passes from per-pass RNG. This
## class itself never randomizes. canonical_summary() is the only payload used
## for the multiplayer layout hash.

const GRID := 32.0
const CHUNK := 1600.0
const WADE_DEPTH := 24.0
const SHALLOW_SLOW := 0.65

var seed_value: int = 0
var layout_version: int = 1
var extent := Vector2(9600, 7200)
var cols: int = 0
var rows: int = 0

# --- per-cell fields (cols*rows) --------------------------------------------
var land := PackedByteArray()
var water_depth := PackedFloat32Array()
## 1 for cells inside a lake polygon (rivers stay 0). Roads never cross lakes.
var lake_mask := PackedByteArray()
var height := PackedFloat32Array()
var fold := PackedFloat32Array()
var ridge := PackedFloat32Array()
var danger := PackedFloat32Array()
var region_id := PackedInt32Array()
var depth := PackedByteArray()

# --- outlines and network ----------------------------------------------------
var coast := PackedVector2Array()
var land_polygon := PackedVector2Array()
var rivers: Array = []
var lakes: Array = []
var bridges: Array[Rect2] = []
var roads: Array = []
var features: Array = []
var walls: Array[Rect2] = []
var building_footprints: Array[Rect2] = []
var decor: Array = []

# --- regions / POI -----------------------------------------------------------
var regions: Array = []
var sites: Array = []
var chests: Array = []
var shrines: Array = []
var exits: Array[Vector2] = []
var exit_names: Array[String] = []
var sealed_exits: Array[int] = []
var docks: Array = []
var guardians: Array = []
var cores: Array = []
var boss: Dictionary = {}
var royal_city: Dictionary = {}
var city_gate := Vector2.ZERO
var spawn := Vector2.ZERO
var spawn_region: int = -1

# --- indexes / output --------------------------------------------------------
var chunk_index: Dictionary = {}
var warnings: Array[String] = []
var layout_hash: String = ""

var _solid_index: Dictionary = {}
var _feature_index: Dictionary = {}
var _polygon_cache: Dictionary = {}

func configure(value_extent: Vector2, value_seed: int, version: int) -> void:
	extent = value_extent
	seed_value = value_seed
	layout_version = version
	cols = int(ceil(extent.x / GRID))
	rows = int(ceil(extent.y / GRID))
	var n := cols * rows
	land.resize(n)
	land.fill(1)
	water_depth.resize(n)
	water_depth.fill(0.0)
	lake_mask.resize(n)
	lake_mask.fill(0)
	height.resize(n)
	height.fill(0.0)
	fold.resize(n)
	fold.fill(0.0)
	ridge.resize(n)
	ridge.fill(0.0)
	danger.resize(n)
	danger.fill(0.0)
	region_id.resize(n)
	region_id.fill(-1)
	depth.resize(n)
	depth.fill(0)
	chunk_index.clear()
	_solid_index.clear()
	_feature_index.clear()
	_polygon_cache.clear()

func index_of(p: Vector2) -> int:
	if not in_bounds(p):
		return -1
	var x := int(floor(p.x / GRID))
	var y := int(floor(p.y / GRID))
	return y * cols + x

func cell_center(i: int) -> Vector2:
	if i < 0 or i >= cols * rows:
		return Vector2.ZERO
	var x := i % cols
	var y := int(i / cols)
	return Vector2((x + 0.5) * GRID, (y + 0.5) * GRID)

func in_bounds(p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x < extent.x and p.y < extent.y

func land_at(p: Vector2) -> bool:
	var i := index_of(p)
	return i >= 0 and land[i] != 0

func water_depth_at(p: Vector2) -> float:
	var i := index_of(p)
	return 0.0 if i < 0 else water_depth[i]

func is_deep_water(p: Vector2) -> bool:
	return water_depth_at(p) > WADE_DEPTH

func speed_factor_at(p: Vector2) -> float:
	var d := water_depth_at(p)
	if d <= 0.0:
		return 1.0
	if d <= WADE_DEPTH:
		return SHALLOW_SLOW
	return 0.0

func height_at(p: Vector2) -> float:
	return _sample_bilinear(height, p)

func danger_at(p: Vector2) -> float:
	return _sample_bilinear(danger, p)

func level_at(_p: Vector2) -> int:
	# P1 is flat. P4 replaces this with a real height/level lookup.
	return 0

func region_at(p: Vector2) -> int:
	var i := index_of(p)
	return -1 if i < 0 else region_id[i]

func biome_at(p: Vector2) -> int:
	var id := region_at(p)
	if id < 0 or id >= regions.size():
		return 0
	return int(regions[id].get("biome", 0))

func region_polygon(id: int) -> PackedVector2Array:
	if id < 0 or id >= regions.size():
		return PackedVector2Array()
	if _polygon_cache.has(id):
		return _polygon_cache[id]
	var polygon: PackedVector2Array = regions[id].get("polygon", PackedVector2Array())
	_polygon_cache[id] = polygon
	return polygon

func can_traverse(from: Vector2, to: Vector2, radius: float = 15.0) -> bool:
	if blocked(to, radius):
		return false
	if water_depth_at(from) > WADE_DEPTH or water_depth_at(to) > WADE_DEPTH:
		return false
	return true

func blocked(pos: Vector2, radius: float = 15.0) -> bool:
	if not in_bounds(pos):
		return true
	if not land_at(pos):
		return true
	var on_bridge := false
	for bridge in bridges:
		if bridge.has_point(pos):
			on_bridge = true
			break
	if not on_bridge and water_depth_at(pos) > WADE_DEPTH:
		return true
	var cell := chunk_of(pos)
	for rect in _solid_index.get(cell, []):
		var r: Rect2 = rect
		if r.grow(radius).has_point(pos):
			return true
	for feature in _feature_index.get(cell, []):
		var f: Dictionary = feature
		var at: Vector2 = f.p
		var feature_radius: float = f.radius
		if pos.distance_to(at) > feature_radius * 1.25 + radius:
			continue
		var polygon: PackedVector2Array = f.polygon
		if polygon.size() >= 3 and Geometry2D.is_point_in_polygon(pos, polygon):
			return true
		for i in polygon.size():
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i + 1) % polygon.size()]
			if Geometry2D.get_closest_point_to_segment(pos, a, b).distance_to(pos) < radius:
				return true
	return false

func move(from: Vector2, velocity: Vector2, radius: float = 15.0) -> Vector2:
	var result := from
	var steps := maxi(1, int(ceil(velocity.length() / 9.0)))
	var step := velocity / steps
	for _i in steps:
		var x := result + Vector2(step.x, 0.0)
		if not blocked(x, radius):
			result = x
		var y := result + Vector2(0.0, step.y)
		if not blocked(y, radius):
			result = y
	return result

func clear_line(a: Vector2, b: Vector2, radius: float = 2.0) -> bool:
	var steps := maxi(1, int(a.distance_to(b) / 12.0))
	for i in range(1, steps + 1):
		if blocked(a.lerp(b, float(i) / steps), radius):
			return false
	return true

func nearest_open(p: Vector2, radius: float, max_distance: float) -> Vector2:
	if not blocked(p, radius):
		return p
	var rings := maxi(1, int(max_distance / GRID))
	for ring in range(1, rings + 1):
		var distance := float(ring) * GRID
		for i in 24:
			var at := p + Vector2.from_angle(TAU * float(i) / 24.0) * distance
			if not blocked(at, radius):
				return at
	return p

func chunk_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CHUNK)), int(floor(p.y / CHUNK)))

func chunk_rect(chunk: Vector2i) -> Rect2:
	return Rect2(Vector2(chunk) * CHUNK, Vector2.ONE * CHUNK)

func build_solid_index() -> void:
	chunk_index.clear()
	_solid_index.clear()
	_feature_index.clear()
	for wall in walls:
		_index_rect(wall)
	for footprint in building_footprints:
		_index_rect(footprint)
	for feature in features:
		if str(feature.get("kind", "cliff")) != "cliff":
			continue
		var f: Dictionary = feature
		var at: Vector2 = f.p
		var r: float = f.radius
		_index_feature(Rect2(at - Vector2.ONE * r, Vector2.ONE * r * 2.0), f)
	for key in _solid_index.keys():
		chunk_index[key] = true

func _index_rect(rect: Rect2) -> void:
	var first := chunk_of(rect.position)
	var last := chunk_of(rect.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var key := Vector2i(x, y)
			if not _solid_index.has(key):
				_solid_index[key] = []
			_solid_index[key].append(rect)

func _index_feature(rect: Rect2, feature: Dictionary) -> void:
	var first := chunk_of(rect.position)
	var last := chunk_of(rect.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var key := Vector2i(x, y)
			if not _feature_index.has(key):
				_feature_index[key] = []
			_feature_index[key].append(feature)

func _sample_bilinear(field: PackedFloat32Array, p: Vector2) -> float:
	if cols <= 0 or rows <= 0 or field.size() < cols * rows:
		return 0.0
	var fx := clampf(p.x / GRID - 0.5, 0.0, float(cols - 1))
	var fy := clampf(p.y / GRID - 0.5, 0.0, float(rows - 1))
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var x1 := mini(x0 + 1, cols - 1)
	var y1 := mini(y0 + 1, rows - 1)
	var tx := fx - x0
	var ty := fy - y0
	var a: float = field[y0 * cols + x0]
	var b: float = field[y0 * cols + x1]
	var c: float = field[y1 * cols + x0]
	var d: float = field[y1 * cols + x1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

func canonical_summary() -> Dictionary:
	var region_rows: Array = []
	for region in regions:
		region_rows.append([
			int(region.id),
			str(region.name),
			str(region.type),
			int(region.biome),
			int(region.depth),
			snappedf(float(region.area), 1.0),
			_v2(region.center),
			bool(region.get("fragment", false)),
		])
	var site_rows: Array = []
	for site in sites:
		site_rows.append([
			_v2(site.p),
			int(site.get("region", -1)),
			str(site.get("blueprint", "")),
			int(site.get("tier", 1)),
		])
	var exit_rows: Array = []
	for i in exits.size():
		exit_rows.append([_v2(exits[i]), i in sealed_exits])
	var river_rows: Array = []
	for river in rivers:
		var points: PackedVector2Array = river.get("points", PackedVector2Array())
		var point_rows: Array = []
		for point in points:
			point_rows.append(_v2(point))
		var width_rows: Array = []
		for width in river.get("widths", PackedFloat32Array()):
			width_rows.append(snappedf(float(width), 0.1))
		river_rows.append([snappedf(float(river.get("width", 0.0)), 0.1), point_rows, width_rows])
	var lake_rows: Array = []
	for lake in lakes:
		lake_rows.append([
			_v2(lake.get("center", Vector2.ZERO)),
			snappedf(float(lake.get("radius", 0.0)), 0.1),
			bool(lake.get("navigable", false)),
		])
	var road_rows: Array = []
	for road in roads:
		var points: PackedVector2Array = road
		var point_rows: Array = []
		for point in points:
			point_rows.append(_v2(point))
		road_rows.append(point_rows)
	var bridge_rows: Array = []
	for bridge: Rect2 in bridges:
		bridge_rows.append([_v2(bridge.position), _v2(bridge.size)])
	return {
		"layout_version": layout_version,
		"seed": seed_value,
		"extent": _v2(extent),
		"spawn": _v2(spawn),
		"city_gate": _v2(city_gate),
		"regions": region_rows,
		"sites": site_rows,
		"exits": exit_rows,
		"rivers": river_rows,
		"lakes": lake_rows,
		"roads": road_rows,
		"bridges": bridge_rows,
		"boss": _v2(boss.get("center", Vector2.ZERO)),
		"royal_city": _v2(royal_city.get("center", Vector2.ZERO)),
	}

func _v2(p: Vector2) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01)]
