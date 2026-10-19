class_name MapGen
extends RefCounted
## Deterministic generator for the three-day expedition continent.
##
## Pipeline (see docs/MAPGEN-SPEC.md):
##   P0 contract -> P1 land -> P2 height/fold -> P3 water -> P4 danger
##   -> P5 regions -> P6 depth -> P7 types -> P8 roads/sites/chests
##   -> P9 specials -> P10 validate -> P11 chunks/hash
##
## All randomness comes from pass_rng(seed, pass_id, salt). This file never
## calls randf()/randi_range() on the global RNG and never reads time/viewport.

const LAYOUT_VERSION := 4
const DEFAULT_EXTENT := Vector2(9600, 7200)
const TARGET_EXTENT := Vector2(30400, 22800)
const GRID := 32.0

const EXIT_NAMES := ["西境驿站", "东岸渡口", "北境钟门", "晨钟归途", "南岸暗门"]
const REGION_NAME_A := ["风铃", "白垩", "月晶", "蔷薇", "雾汐", "圣血", "晨钟", "沉钟"]
const REGION_NAME_B := ["原野", "旧城", "高地", "庭域", "湿地", "王庭", "废墟", "谷地"]

const MAX_ATTEMPTS := 8
const WATER_FRACTION := 0.08
const WATER_MIN := 0.06
const WATER_MAX := 0.10

static var last_report: Dictionary = {}
static var last_attempts: int = 0

static func generate(seed_value: int, extent: Vector2 = DEFAULT_EXTENT, options: Dictionary = {}) -> TerrainMap:
	var ley := p0_contract(seed_value, extent, options)
	var t := TerrainMap.new()
	t.configure(extent, seed_value, LAYOUT_VERSION)
	p1_land(ley, t, _pass(ley, "P1"))
	p2_height(ley, t, _pass(ley, "P2"))
	p3_water(ley, t, _pass(ley, "P3"))
	p4_danger(ley, t, _pass(ley, "P4"))
	p5_regions(ley, t, _pass(ley, "P5"))
	p6_depth(ley, t, _pass(ley, "P6"))
	p7_types(ley, t, _pass(ley, "P7"))
	p8_roads(ley, t, _pass(ley, "P8"))
	p9_specials(ley, t, _pass(ley, "P9"))
	p11_chunks(t)
	t.layout_hash = layout_hash(t)
	return t

static func try_generate(seed_value: int, options: Dictionary = {}) -> Dictionary:
	var extent: Vector2 = options.get("extent", DEFAULT_EXTENT)
	var attempts: int = int(options.get("attempts", MAX_ATTEMPTS))
	var last_errors: Array[String] = []
	for i in attempts:
		var actual_seed := seed_value + i
		var t := generate(actual_seed, extent, options)
		var report := p10_validate(t, options)
		last_report = report
		last_attempts = i + 1
		if bool(report.get("ok", false)):
			return {
				"ok": true,
				"terrain": t,
				"seed": actual_seed,
				"attempts": i + 1,
				"report": report,
			}
		last_errors = report.get("errors", [])
	return {
		"ok": false,
		"terrain": null,
		"seed": seed_value,
		"attempts": attempts,
		"errors": last_errors,
	}

# --- P0 ---------------------------------------------------------------------

static func p0_contract(seed_value: int, extent: Vector2, options: Dictionary = {}) -> LeyMap:
	var ley := LeyMap.new()
	ley.seed_value = seed_value
	ley.layout_version = LAYOUT_VERSION
	ley.extent = extent
	ley.area_scale = clampf((extent.x * extent.y) / (TARGET_EXTENT.x * TARGET_EXTENT.y), 0.02, 1.0)
	ley.linear_scale = sqrt(ley.area_scale)
	ley.options = options.duplicate(true)

	var rng := pass_rng(seed_value, "P0")
	ley.fragment_count = rng.randi_range(8, 10)
	ley.big_region_count = rng.randi_range(35, 42)
	ley.region_count = ley.big_region_count + ley.fragment_count
	if ley.region_count > 52:
		ley.big_region_count = 52 - ley.fragment_count
		ley.region_count = 52
	if ley.region_count < 45:
		ley.big_region_count = 45 - ley.fragment_count
		ley.region_count = 45

	ley.water_fraction = float(options.get("water_fraction", WATER_FRACTION))
	ley.river_count = rng.randi_range(1, 2)
	ley.stream_count = 0
	ley.lake_count = rng.randi_range(2, 5)
	ley.danger_core_count = rng.randi_range(15, 20)
	ley.safe_pocket_count = rng.randi_range(1, 2)
	ley.exposed_core_count = rng.randi_range(1, 2)
	ley.high_count = rng.randi_range(1, 3)
	ley.fight_count = rng.randi_range(3, 5)
	ley.trap_count = rng.randi_range(3, 5)
	ley.site_budget = clampi(roundi(lerpf(18.0, 100.0, ley.area_scale)), 18, 100)
	ley.chest_budget = clampi(roundi(lerpf(8.0, 24.0, ley.area_scale)), 8, 24)
	ley.royal_city_count = 1 if rng.randf() < 0.65 else 0

	var min_dim := minf(extent.x, extent.y)
	ley.land_center = extent * 0.5 + Vector2(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04)) * min_dim
	ley.land_radius = Vector2(extent.x * rng.randf_range(0.42, 0.48), extent.y * rng.randf_range(0.42, 0.48))
	ley.land_noise_seed = rng.randi()
	ley.coast_seed = rng.randi()
	ley.fold_axis = Vector2.from_angle(rng.randf_range(0.0, TAU))
	ley.fold_wavelength = rng.randf_range(0.10, 0.18) * min_dim
	ley.fold_secondary = rng.randf_range(0.22, 0.4)
	ley.ridge_bias = rng.randf_range(0.28, 0.42)

	for id in ["P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "P9", "P10", "P11"]:
		ley.pass_salts[id] = rng.randi()
	return ley

# --- P1 land ----------------------------------------------------------------

static func p1_land(ley: LeyMap, t: TerrainMap, rng: RandomNumberGenerator) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = ley.land_noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.9
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.55

	var warp := FastNoiseLite.new()
	warp.seed = ley.coast_seed
	warp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp.frequency = 1.4
	warp.fractal_octaves = 2

	var min_dim := minf(t.extent.x, t.extent.y)
	for y in t.rows:
		for x in t.cols:
			var p := Vector2((x + 0.5) * GRID, (y + 0.5) * GRID)
			var nx := (p.x - ley.land_center.x) / maxf(ley.land_radius.x, 1.0)
			var ny := (p.y - ley.land_center.y) / maxf(ley.land_radius.y, 1.0)
			var radial := sqrt(nx * nx + ny * ny)
			var envelope := clampf(1.0 - pow(radial, 2.6), 0.0, 1.0)
			var wx := warp.get_noise_2d(p.x * 1.7, p.y * 1.7) * min_dim * 0.05
			var wy := warp.get_noise_2d(p.x * 1.7 + 311.0, p.y * 1.7 - 197.0) * min_dim * 0.05
			var base := noise.get_noise_2d((p.x + wx) / min_dim * 3.4, (p.y + wy) / min_dim * 3.4) * 0.5 + 0.5
			var value := base * 0.45 + envelope * 0.75
			var i := y * t.cols + x
			t.land[i] = 1 if value > 0.55 else 0

	# Keep only the largest land component; small islands become sea.
	var best: Array[int] = []
	var visited := PackedByteArray()
	visited.resize(t.cols * t.rows)
	visited.fill(0)
	for start in t.cols * t.rows:
		if t.land[start] == 0 or visited[start] != 0:
			continue
		var component: Array[int] = []
		var queue: Array[int] = [start]
		visited[start] = 1
		var cursor := 0
		while cursor < queue.size():
			var current: int = queue[cursor]
			cursor += 1
			component.append(current)
			var cx := current % t.cols
			var cy := int(current / t.cols)
			for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var nx2: int = cx + delta.x
				var ny2: int = cy + delta.y
				if nx2 < 0 or ny2 < 0 or nx2 >= t.cols or ny2 >= t.rows:
					continue
				var next := ny2 * t.cols + nx2
				if t.land[next] == 0 or visited[next] != 0:
					continue
				visited[next] = 1
				queue.append(next)
		if component.size() > best.size():
			best = component
	var keep := {}
	for i in best:
		keep[i] = true
	for i in t.cols * t.rows:
		if t.land[i] != 0 and not keep.has(i):
			t.land[i] = 0

	t.coast = _extract_mask_contour(t, "land")
	t.land_polygon = t.coast
	if t.coast.size() < 8:
		t.warnings.append("land_contour_short")

# --- P2 height/fold ----------------------------------------------------------

static func p2_height(ley: LeyMap, t: TerrainMap, rng: RandomNumberGenerator) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.85
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4

	var warp := FastNoiseLite.new()
	warp.seed = rng.randi()
	warp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp.frequency = 1.2

	var min_dim := minf(t.extent.x, t.extent.y)
	for y in t.rows:
		for x in t.cols:
			var p := Vector2((x + 0.5) * GRID, (y + 0.5) * GRID)
			var i := y * t.cols + x
			var warp_value := warp.get_noise_2d(p.x, p.y)
			var phase := (p.dot(ley.fold_axis) / maxf(ley.fold_wavelength, 1.0)) * TAU + warp_value * 2.4
			var primary := 0.5 + 0.5 * sin(phase)
			var second_phase := (p.dot(Vector2(-ley.fold_axis.y, ley.fold_axis.x)) / maxf(ley.fold_wavelength * 1.7, 1.0)) * TAU
			var secondary := 0.5 + 0.5 * sin(second_phase + warp_value * 1.3)
			var n := noise.get_noise_2d(p.x / min_dim * 5.0, p.y / min_dim * 5.0) * 0.5 + 0.5
			t.fold[i] = clampf(primary * 0.72 + secondary * ley.fold_secondary + n * 0.16, 0.0, 1.0)
			t.ridge[i] = clampf((1.0 - absf(2.0 * t.fold[i] - 1.0)) * 0.72 + n * ley.ridge_bias, 0.0, 1.0)
			var coast_fade := 1.0
			if t.land[i] == 0:
				coast_fade = 0.0
			t.height[i] = (t.fold[i] * 0.55 + t.ridge[i] * 0.45) * 120.0 * coast_fade

# --- P3 water ---------------------------------------------------------------

static func p3_water(ley: LeyMap, t: TerrainMap, rng: RandomNumberGenerator) -> void:
	var land_count := 0
	for i in t.cols * t.rows:
		if t.land[i] != 0:
			land_count += 1
	var min_dim := minf(t.extent.x, t.extent.y)

	var rivers: Array = []
	var lakes: Array = []

	# Only real, wide rivers. Thin streams are intentionally gone: at this map
	# scale they read as scratches, and the user wants a river network that
	# never overlaps itself or another river.
	var attempts := 0
	while rivers.size() < ley.river_count and attempts < 80:
		attempts += 1
		var source := _random_high_land(t, rng)
		if source == Vector2.ZERO:
			continue
		var traced := _trace_downhill(t, source, rng, 420)
		if traced.size() < 8:
			continue
		var shaped := _shape_river(t, traced, MapShapes.river(rng), min_dim, rng)
		if shaped.points.size() < 8:
			continue
		if _polyline_length(shaped.points) < min_dim * 0.18:
			continue
		var width := min_dim * rng.randf_range(0.020, 0.030)
		if not _river_fits(shaped.points, width, rivers):
			continue
		rivers.append({
			"points": shaped.points,
			"mults": shaped.widths,
			"width": width,
			"kind": "river",
			"order": rivers.size(),
			"name": "长河",
			"shape": shaped.shape,
		})

	# Lakes: one of the 50 baked outlines, randomly rotated and squashed. The
	# result is never a circle, and its shore is guaranteed to sit on dry land.
	attempts = 0
	while lakes.size() < ley.lake_count and attempts < 420:
		attempts += 1
		var at := _random_low_land(t, rng)
		if at == Vector2.ZERO:
			continue
		var large := lakes.size() < 2
		var want := min_dim * (rng.randf_range(0.052, 0.088) if large else rng.randf_range(0.030, 0.050))
		var shape := MapShapes.lake(rng)
		var squash := Vector2(rng.randf_range(0.86, 1.0), rng.randf_range(0.62, 0.94))
		var polygon := _place_lake(shape.points, at, want, rng.randf_range(0.0, TAU), squash)
		if polygon.size() < 8:
			continue
		var radius := 0.0
		for point: Vector2 in polygon:
			radius = maxf(radius, point.distance_to(at))
		if not _lake_polygon_fits(t, polygon, at, radius, rivers, lakes):
			continue
		lakes.append({
			"center": at,
			"radius": radius,
			"polygon": polygon,
			"navigable": radius >= min_dim * 0.035,
			"family": str(shape.family),
		})
	if lakes.is_empty():
		var fallback_at := t.extent * 0.5
		var fallback_shape := MapShapes.lake(rng)
		var fallback_polygon := _place_lake(fallback_shape.points, fallback_at, min_dim * 0.06, 0.0, Vector2.ONE)
		lakes.append({
			"center": fallback_at,
			"radius": min_dim * 0.06,
			"polygon": fallback_polygon,
			"navigable": true,
			"family": str(fallback_shape.family),
		})

	# Water area is tuned by a single global scale, then rasterized again.
	var scale := 1.0
	for _round in 8:
		_rasterize_water(t, rivers, lakes, scale)
		var water_count := 0
		for i in t.cols * t.rows:
			if t.land[i] != 0 and t.water_depth[i] > 0.0:
				water_count += 1
		var fraction := float(water_count) / maxf(float(land_count), 1.0)
		if fraction >= WATER_MIN and fraction <= WATER_MAX:
			break
		if fraction < WATER_MIN:
			scale = minf(scale * 1.14, 2.3)
		else:
			scale = maxf(scale * 0.88, 0.45)

	# Keep the final geometry used by rendering.
	t.rivers.clear()
	for river in rivers:
		var points: PackedVector2Array = river.points
		var mults: PackedFloat32Array = river.mults
		var base_width: float = float(river.width) * scale
		var widths := PackedFloat32Array()
		for value: float in mults:
			widths.append(base_width * value)
		t.rivers.append({
			"points": points,
			"polygon": _river_polygon(points, widths),
			"width": base_width,
			"widths": widths,
			"kind": river.kind,
			"order": river.order,
			"name": river.name,
			"shape": river.shape,
		})
	t.lakes.clear()
	for lake in lakes:
		t.lakes.append({
			"center": lake.center,
			"radius": float(lake.radius) * scale,
			"polygon": _scaled_polygon(lake.polygon, lake.center, scale),
			"navigable": bool(lake.navigable),
			"family": str(lake.get("family", "lake")),
		})
	_build_docks(t, rng)
	_build_bridges(t, rng)

static func _rasterize_water(t: TerrainMap, rivers: Array, lakes: Array, scale: float) -> void:
	for i in t.cols * t.rows:
		t.water_depth[i] = 0.0
		t.lake_mask[i] = 0
	for river in rivers:
		var mults: PackedFloat32Array = river.mults
		var widths := PackedFloat32Array()
		for value: float in mults:
			widths.append(float(river.width) * value * scale)
		if widths.size() >= 2:
			_stamp_polyline(t, river.points, widths, 26.0 if str(river.kind) == "river" else 15.0)
	for lake in lakes:
		var polygon := _scaled_polygon(lake.polygon, lake.center, scale)
		_stamp_lake_polygon(t, polygon, 24.0)

static func _stamp_polyline(t: TerrainMap, points: PackedVector2Array, widths: PackedFloat32Array, depth_base: float) -> void:
	if points.size() < 2 or widths.size() < points.size():
		return
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var half_width := (widths[i] + widths[i + 1]) * 0.25
		if half_width <= 0.0:
			continue
		var bounds := Rect2(a, Vector2.ZERO).expand(b).grow(half_width + GRID)
		var x0 := maxi(0, int(floor(bounds.position.x / GRID)))
		var y0 := maxi(0, int(floor(bounds.position.y / GRID)))
		var x1 := mini(t.cols - 1, int(floor(bounds.end.x / GRID)))
		var y1 := mini(t.rows - 1, int(floor(bounds.end.y / GRID)))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var ci := y * t.cols + x
				if t.land[ci] == 0:
					continue
				var center := Vector2((x + 0.5) * GRID, (y + 0.5) * GRID)
				var distance := Geometry2D.get_closest_point_to_segment(center, a, b).distance_to(center)
				if distance > half_width:
					continue
				var value := depth_base + (half_width - distance) * 0.55
				if value > t.water_depth[ci]:
					t.water_depth[ci] = value

static func _stamp_lake_polygon(t: TerrainMap, polygon: PackedVector2Array, depth_base: float) -> void:
	if polygon.size() < 3:
		return
	var bounds := _polygon_bounds(polygon)
	var x0 := maxi(0, int(floor(bounds.position.x / GRID)))
	var y0 := maxi(0, int(floor(bounds.position.y / GRID)))
	var x1 := mini(t.cols - 1, int(floor(bounds.end.x / GRID)))
	var y1 := mini(t.rows - 1, int(floor(bounds.end.y / GRID)))
	var crossings := PackedFloat32Array()
	var count := polygon.size()
	for y in range(y0, y1 + 1):
		var scan_y := (y + 0.5) * GRID
		crossings.clear()
		for i in count:
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i + 1) % count]
			if (a.y <= scan_y and b.y > scan_y) or (b.y <= scan_y and a.y > scan_y):
				var u := (scan_y - a.y) / (b.y - a.y)
				crossings.append(a.x + u * (b.x - a.x))
		if crossings.size() < 2:
			continue
		crossings.sort()
		var pair := 0
		while pair + 1 < crossings.size():
			var left := maxi(x0, int(ceil(crossings[pair] / GRID - 0.5)))
			var right := mini(x1, int(floor(crossings[pair + 1] / GRID - 0.5)))
			for x in range(left, right + 1):
				var ci := y * t.cols + x
				if t.land[ci] == 0:
					continue
				var edge := minf(float(x - left), float(right - x)) * GRID
				var value := depth_base + minf(edge, 150.0) * 0.30
				if value > t.water_depth[ci]:
					t.water_depth[ci] = value
				t.lake_mask[ci] = 1
			pair += 2

static func _random_high_land(t: TerrainMap, rng: RandomNumberGenerator) -> Vector2:
	var best := Vector2.ZERO
	var best_height := -1.0
	for _i in 120:
		var at := Vector2(rng.randf_range(0.08, 0.92) * t.extent.x, rng.randf_range(0.08, 0.92) * t.extent.y)
		if not t.land_at(at):
			continue
		if t.water_depth_at(at) > 0.0:
			continue
		var h := t.height_at(at)
		if h > best_height:
			best_height = h
			best = at
	return best

static func _random_low_land(t: TerrainMap, rng: RandomNumberGenerator) -> Vector2:
	var best := Vector2.ZERO
	var best_height := 1e9
	for _i in 160:
		var at := Vector2(rng.randf_range(0.10, 0.90) * t.extent.x, rng.randf_range(0.10, 0.90) * t.extent.y)
		if not t.land_at(at):
			continue
		if t.water_depth_at(at) > 0.0:
			continue
		var h := t.height_at(at)
		if h < best_height:
			best_height = h
			best = at
	return best

static func _trace_downhill(t: TerrainMap, start: Vector2, rng: RandomNumberGenerator, max_steps: int) -> PackedVector2Array:
	var points := PackedVector2Array([start])
	var current := start
	var last_dir := Vector2.ZERO
	for _step in max_steps:
		if not t.land_at(current) or t.water_depth_at(current) > 0.0:
			break
		var best := current
		var best_height := t.height_at(current) + 0.4
		for k in 12:
			var angle := TAU * float(k) / 12.0 + rng.randf_range(-0.14, 0.14)
			var direction := Vector2.from_angle(angle)
			if last_dir != Vector2.ZERO and direction.dot(last_dir) < 0.15:
				continue
			var candidate := current + direction * GRID * 1.8
			if not t.land_at(candidate):
				continue
			if t.water_depth_at(candidate) > 0.0:
				continue
			var h := t.height_at(candidate) + rng.randf_range(0.0, 0.6)
			if h < best_height:
				best_height = h
				best = candidate
		if best == current:
			# Nudge out of a local minimum with a deterministic meander.
			var nudge := Vector2.from_angle(rng.randf_range(0.0, TAU)) * GRID * 1.3
			var candidate := current + nudge
			if t.land_at(candidate) and t.water_depth_at(candidate) <= 0.0:
				best = candidate
			else:
				break
		last_dir = (best - current).normalized()
		current = best
		points.append(current)
	return points

static func _lake_polygon_fits(t: TerrainMap, polygon: PackedVector2Array, center: Vector2, radius: float, rivers: Array, lakes: Array) -> bool:
	var bounds := _polygon_bounds(polygon)
	if bounds.position.x < 180.0 or bounds.position.y < 180.0:
		return false
	if bounds.end.x > t.extent.x - 180.0 or bounds.end.y > t.extent.y - 180.0:
		return false
	if bounds.get_area() < radius * radius * 0.35:
		return false
	for i in polygon.size():
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		if not t.land_at(a) or t.water_depth_at(a) > 0.0:
			return false
		if not t.land_at(b) or not t.land_at((a + b) * 0.5):
			return false
	for river in rivers:
		for point: Vector2 in river.points:
			if point.distance_to(center) < radius * 0.85 + 140.0:
				return false
	for other in lakes:
		if center.distance_to(other.center) < radius + float(other.radius) * 0.85:
			return false
	return true

static func _place_lake(unit_points: PackedVector2Array, center: Vector2, radius: float, rotation: float, squash: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var ca := cos(rotation)
	var sa := sin(rotation)
	for point: Vector2 in unit_points:
		var x := point.x * squash.x
		var y := point.y * squash.y
		out.append(center + Vector2(x * ca - y * sa, x * sa + y * ca) * radius)
	return out

static func _scaled_polygon(polygon: PackedVector2Array, center: Vector2, scale: float) -> PackedVector2Array:
	if is_equal_approx(scale, 1.0):
		return polygon
	var out := PackedVector2Array()
	for point: Vector2 in polygon:
		out.append(center + (point - center) * scale)
	return out

static func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		rect = rect.expand(point)
	return rect

## Fit a baked meander onto a terrain-following trace. The trace keeps the river
## in a downhill valley; the baked profile adds bays, bends and width variation
## that a per-vertex random walk never produces.
static func _river_fits(points: PackedVector2Array, width: float, rivers: Array) -> bool:
	# Self-overlap (a meander folding back onto itself) is not a river.
	if _polyline_self_overlaps(points, width * 0.55):
		return false
	for other in rivers:
		if _polylines_overlap(points, width, other.points, float(other.width)):
			return false
	return true

static func _polyline_self_overlaps(points: PackedVector2Array, clearance: float) -> bool:
	var count := points.size()
	for i in range(count - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		for j in range(i + 6, count - 1):
			if Geometry2D.segment_intersects_segment(a, b, points[j], points[j + 1]) != null:
				return true
	return false

static func _polylines_overlap(a: PackedVector2Array, width_a: float, b: PackedVector2Array, width_b: float) -> bool:
	# Use a generous clearance: the final global water scale can widen both
	# rivers, and they must still not touch.
	var clearance := (width_a + width_b) * 1.1 + 120.0
	var bounds_a := Rect2(a[0], Vector2.ZERO)
	for point: Vector2 in a:
		bounds_a = bounds_a.expand(point)
	var bounds_b := Rect2(b[0], Vector2.ZERO)
	for point: Vector2 in b:
		bounds_b = bounds_b.expand(point)
	if not bounds_a.grow(clearance).intersects(bounds_b):
		return false
	for i in range(a.size() - 1):
		for j in range(b.size() - 1):
			if Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[j], b[j + 1]) != null:
				return true
	for point_a: Vector2 in a:
		for point_b: Vector2 in b:
			if point_a.distance_to(point_b) < clearance:
				return true
	return false

static func _shape_river(t: TerrainMap, base: PackedVector2Array, shape: Dictionary, min_dim: float, rng: RandomNumberGenerator) -> Dictionary:
	var template: PackedVector2Array = shape.get("points", PackedVector2Array())
	var mults: PackedFloat32Array = shape.get("widths", PackedFloat32Array())
	var family := str(shape.get("family", "river"))
	if template.size() < 6:
		return {"points": base, "widths": PackedFloat32Array([1.0]), "shape": family}
	# A dense, smoothed centreline is what keeps the 3D ribbon from folding into
	# hard wedges at the sharp turns of the raw downhill trace. Chaikin cutting
	# removes the 90° steps of the grid walk; the baked profile then adds the
	# meander on top of a genuinely smooth curve.
	var count := 81
	var stride := maxi(1, base.size() / 12)
	var controls := PackedVector2Array()
	for i in range(0, base.size(), stride):
		controls.append(base[i])
	if controls.is_empty() or controls[controls.size() - 1] != base[base.size() - 1]:
		controls.append(base[base.size() - 1])
	var smooth := _chaikin(controls, 4)
	var sampled := _resample_polyline(smooth, count)
	if sampled.size() != count:
		return {"points": base, "widths": PackedFloat32Array([1.0]), "shape": family}
	var profile := _resample_polyline(template, count)
	if profile.size() != count:
		profile = template
	var amplitude := min_dim * rng.randf_range(0.026, 0.040)
	var out := PackedVector2Array()
	for i in count:
		var factor := float(i) / float(count - 1)
		var envelope := pow(sin(PI * factor), 0.75)
		var previous := sampled[maxi(0, i - 1)]
		var following := sampled[mini(count - 1, i + 1)]
		var direction := (following - previous).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		var candidate := sampled[i] + direction.orthogonal() * float(profile[i].y) * amplitude * envelope
		if t.land_at(candidate) and t.water_depth_at(candidate) <= 0.0:
			out.append(candidate)
		else:
			out.append(sampled[i])
	for _pass in 3:
		out = _smooth_polyline(out)
	for i in out.size():
		if not t.land_at(out[i]):
			out[i] = sampled[i]
	var widths := _resample_widths(mults, count)
	# Taper the source and mouth instead of ending in a blunt rectangle.
	for i in widths.size():
		var edge := minf(float(i), float(widths.size() - 1 - i))
		var taper := clampf(edge / 5.0, 0.0, 1.0)
		widths[i] *= 0.18 + 0.82 * taper
	return {"points": out, "widths": widths, "shape": family}

static func _smooth_polyline(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var out := PackedVector2Array()
	out.append(points[0])
	for i in range(1, points.size() - 1):
		out.append((points[i - 1] + points[i] * 2.0 + points[i + 1]) * 0.25)
	out.append(points[points.size() - 1])
	return out

static func _chaikin(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var current := points
	for _iteration in iterations:
		if current.size() < 2:
			return current
		var out := PackedVector2Array()
		out.append(current[0])
		for i in range(current.size() - 1):
			var a: Vector2 = current[i]
			var b: Vector2 = current[i + 1]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		out.append(current[current.size() - 1])
		current = out
	return current

static func _resample_widths(values: PackedFloat32Array, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if values.is_empty():
		out.resize(count)
		out.fill(1.0)
		return out
	for i in count:
		var position := float(i) / float(count - 1) * float(values.size() - 1)
		var low := int(floor(position))
		var high := mini(low + 1, values.size() - 1)
		out.append(lerpf(values[low], values[high], position - float(low)))
	return out

static func _resample_polyline(points: PackedVector2Array, count: int) -> PackedVector2Array:
	if points.size() < 2 or count < 2:
		return points
	var total := _polyline_length(points)
	if total <= 0.0:
		return points
	var out := PackedVector2Array()
	var step := total / float(count - 1)
	var segment := 0
	var walked := 0.0
	for i in count:
		var target := step * float(i)
		segment = mini(segment, points.size() - 2)
		while segment < points.size() - 1:
			var segment_length := points[segment].distance_to(points[segment + 1])
			if walked + segment_length >= target or segment == points.size() - 2:
				var u := 0.0 if segment_length <= 0.0 else clampf((target - walked) / segment_length, 0.0, 1.0)
				out.append(points[segment].lerp(points[segment + 1], u))
				break
			walked += segment_length
			segment += 1
	return out

static func _polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

static func _river_polygon(points: PackedVector2Array, widths: PackedFloat32Array) -> PackedVector2Array:
	if points.size() < 2:
		return PackedVector2Array()
	if widths.size() < points.size():
		return PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in points.size():
		var previous := points[maxi(0, i - 1)]
		var following := points[mini(points.size() - 1, i + 1)]
		var direction := (following - previous).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		var normal := direction.orthogonal() * maxf(widths[i], 1.0) * 0.5
		left.append(points[i] + normal)
		right.append(points[i] - normal)
	var polygon := PackedVector2Array()
	for point: Vector2 in left:
		polygon.append(point)
	for i in range(right.size() - 1, -1, -1):
		polygon.append(right[i])
	return polygon

static func _circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		points.append(center + Vector2.from_angle(TAU * float(i) / float(segments)) * radius)
	return points

static func _build_bridges(t: TerrainMap, rng: RandomNumberGenerator) -> void:
	# Fords that make the wide rivers crossable: `TerrainMap.blocked()` treats a
	# bridge rect as walkable, so each deck is sized to the river's local width
	# (2.2–2.6×) and a short river gets one deck instead of a cluster of three.
	var min_dim := minf(t.extent.x, t.extent.y)
	for river in t.rivers:
		var points: PackedVector2Array = river.get("points", PackedVector2Array())
		if points.size() < 8:
			continue
		var length := _polyline_length(points)
		var count := 1
		if length > min_dim * 0.50:
			count = 3
		elif length > min_dim * 0.30:
			count = 2
		var widths: PackedFloat32Array = river.get("widths", PackedFloat32Array())
		for i in count:
			if t.bridges.size() >= 9:
				return
			var step := float(i + 1) / float(count + 1)
			var index := clampi(int(points.size() * step), 2, points.size() - 3)
			var at: Vector2 = points[index]
			var width := float(river.get("width", min_dim * 0.024))
			if index < widths.size():
				width = float(widths[index])
			var span := maxf(width * 2.2, min_dim * 0.014)
			t.bridges.append(Rect2(at - Vector2.ONE * span * 0.5, Vector2.ONE * span))

static func _build_docks(t: TerrainMap, rng: RandomNumberGenerator) -> void:
	t.docks.clear()
	var body: Dictionary = {}
	for lake in t.lakes:
		if bool(lake.get("navigable", false)) and (body.is_empty() or float(lake.radius) > float(body.radius)):
			body = lake
	if body.is_empty() and not t.rivers.is_empty():
		body = t.rivers[0]
	if body.is_empty():
		return
	if body.has("polygon"):
		var polygon: PackedVector2Array = body.polygon
		var center: Vector2 = body.center
		for i in 3:
			var angle := TAU * float(i) / 3.0 + rng.randf_range(-0.18, 0.18)
			var best := Vector2.ZERO
			var best_delta := INF
			for point: Vector2 in polygon:
				var delta := absf(wrapf((point - center).angle() - angle, -PI, PI))
				if delta < best_delta:
					best_delta = delta
					best = point
			var outward := (best - center).normalized()
			if outward == Vector2.ZERO:
				outward = Vector2.RIGHT
			var open := t.nearest_open(best + outward * 90.0, 24.0, 320.0)
			t.docks.append({"p": open, "body": i, "schedule": 180.0})
		return
	var center := t.extent * 0.5
	var radius := minf(t.extent.x, t.extent.y) * 0.06
	if body.has("center"):
		center = body.center
	if body.has("radius"):
		radius = float(body.radius)
	elif body.has("points"):
		var points: PackedVector2Array = body.points
		if not points.is_empty():
			center = points[points.size() / 2]
			radius = maxf(float(body.get("width", 1.0)) * 1.4, 180.0)
	for i in 3:
		var angle := TAU * float(i) / 3.0 + rng.randf_range(-0.2, 0.2)
		var at := center + Vector2.from_angle(angle) * (radius + 70.0)
		var open := t.nearest_open(at, 24.0, 260.0)
		t.docks.append({"p": open, "body": i, "schedule": 180.0})

# --- P4 danger ---------------------------------------------------------------

static func p4_danger(ley: LeyMap, t: TerrainMap, rng: RandomNumberGenerator) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.9
	noise.fractal_octaves = 3
	var min_dim := minf(t.extent.x, t.extent.y)
	for y in t.rows:
		for x in t.cols:
			var i := y * t.cols + x
			if t.land[i] == 0:
				t.danger[i] = 1.0
				continue
			var p := Vector2((x + 0.5) * GRID, (y + 0.5) * GRID)
			var n := noise.get_noise_2d(p.x / min_dim * 4.0, p.y / min_dim * 4.0) * 0.5 + 0.5
			t.danger[i] = clampf(0.45 * t.fold[i] + 0.35 * t.ridge[i] + 0.20 * n, 0.0, 1.0)

	var cores: Array = []
	var candidates: Array = []
	for y in range(2, t.rows - 2):
		for x in range(2, t.cols - 2):
			var i := y * t.cols + x
			if t.land[i] == 0:
				continue
			var value := t.danger[i]
			if value < 0.45:
				continue
			var is_peak := true
			for dy: int in [-2, 0, 2]:
				for dx: int in [-2, 0, 2]:
					if dx == 0 and dy == 0:
						continue
					var ni := (y + dy) * t.cols + (x + dx)
					if t.danger[ni] > value:
						is_peak = false
						break
				if not is_peak:
					break
			if is_peak:
				candidates.append({"p": Vector2((x + 0.5) * GRID, (y + 0.5) * GRID), "danger": value})
	candidates.sort_custom(func(a, b): return float(a.danger) > float(b.danger))
	var min_spacing := min_dim * 0.07
	for candidate in candidates:
		if cores.size() >= ley.danger_core_count:
			break
		var at: Vector2 = candidate.p
		var okay := true
		for core in cores:
			if at.distance_to(core.p) < min_spacing:
				okay = false
				break
		if okay:
			cores.append({"p": at, "radius": min_dim * 0.055, "danger": candidate.danger, "expose": false, "kind": "core"})

	# Exposed high-danger cores: near the coast, at least one.
	var exposed := 0
	for core in cores:
		if exposed >= ley.exposed_core_count:
			break
		if _distance_to_coast(t, core.p) < min_dim * 0.08:
			core.expose = true
			exposed += 1
	# Deep safe pocket: low danger, surrounded by higher danger.
	if ley.safe_pocket_count > 0:
		var safe := _find_safe_pocket(t, rng)
		if safe != Vector2.ZERO:
			cores.append({"p": safe, "radius": min_dim * 0.06, "danger": 0.05, "expose": false, "kind": "safe"})
	t.cores = cores

static func _find_safe_pocket(t: TerrainMap, rng: RandomNumberGenerator) -> Vector2:
	var best := Vector2.ZERO
	var best_score := -1.0
	for _i in 180:
		var at := Vector2(rng.randf_range(0.2, 0.8) * t.extent.x, rng.randf_range(0.2, 0.8) * t.extent.y)
		if not t.land_at(at):
			continue
		var local := t.danger_at(at)
		var ring := 0.0
		for k in 8:
			ring += t.danger_at(at + Vector2.from_angle(TAU * float(k) / 8.0) * 420.0)
		ring /= 8.0
		var score := ring - local * 1.4
		if score > best_score:
			best_score = score
			best = at
	return best

static func _distance_to_coast(t: TerrainMap, p: Vector2) -> float:
	if t.coast.is_empty():
		return 1e9
	var best := 1e9
	for i in range(t.coast.size() - 1):
		var distance := Geometry2D.get_closest_point_to_segment(p, t.coast[i], t.coast[i + 1]).distance_to(p)
		if distance < best:
			best = distance
	return best

# --- P5 regions --------------------------------------------------------------

static func p5_regions(ley: LeyMap, t: TerrainMap, rng: RandomNumberGenerator) -> void:
	var seeds: Array[Vector2] = []
	var area := t.extent.x * t.extent.y
	var min_distance := sqrt(area / float(maxi(ley.region_count, 1))) * 0.68
	var relax := 0
	while seeds.size() < ley.region_count and relax < 8:
		var attempts := 0
		while seeds.size() < ley.region_count and attempts < 12000:
			attempts += 1
			var at := Vector2(rng.randf_range(0.04, 0.96) * t.extent.x, rng.randf_range(0.04, 0.96) * t.extent.y)
			if not t.land_at(at) or t.water_depth_at(at) > 0.0:
				continue
			var okay := true
			for seed in seeds:
				if at.distance_to(seed) < min_distance:
					okay = false
					break
			if okay:
				seeds.append(at)
		if seeds.size() < ley.region_count:
			min_distance *= 0.88
			relax += 1
	while seeds.size() < ley.region_count:
		var at := Vector2(rng.randf_range(0.08, 0.92) * t.extent.x, rng.randf_range(0.08, 0.92) * t.extent.y)
		if t.land_at(at) and t.water_depth_at(at) <= 0.0:
			seeds.append(at)

	_rasterize_regions(t, seeds)
	_rebuild_region_records(t, ley, seeds)
	# One pass collects every region's boundary edges, then each contour is chained.
	var boundary := _region_boundary_edges(t)
	for id in t.regions.size():
		t.regions[id].polygon = _chain_edges(boundary.get(id, []))

static func _rasterize_regions(t: TerrainMap, seeds: Array[Vector2]) -> void:
	for y in t.rows:
		for x in t.cols:
			var i := y * t.cols + x
			if t.land[i] == 0:
				t.region_id[i] = -1
				continue
			var at := Vector2((x + 0.5) * GRID, (y + 0.5) * GRID)
			if t.water_depth[i] > 0.0:
				t.region_id[i] = -1
				continue
			var best := -1
			var best_distance := INF
			for id in seeds.size():
				var distance := at.distance_squared_to(seeds[id])
				if distance < best_distance:
					best_distance = distance
					best = id
			t.region_id[i] = best

static func _clean_region_components(t: TerrainMap, count: int) -> void:
	var n := t.cols * t.rows
	for id in count:
		var visited := PackedByteArray()
		visited.resize(n)
		visited.fill(0)
		var best: Array[int] = []
		for start in n:
			if t.region_id[start] != id or visited[start] != 0:
				continue
			var component: Array[int] = []
			var queue: Array[int] = [start]
			visited[start] = 1
			var cursor := 0
			while cursor < queue.size():
				var current: int = queue[cursor]
				cursor += 1
				component.append(current)
				var cx := current % t.cols
				var cy := int(current / t.cols)
				for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var nx := cx + delta.x
					var ny := cy + delta.y
					if nx < 0 or ny < 0 or nx >= t.cols or ny >= t.rows:
						continue
					var next := ny * t.cols + nx
					if t.region_id[next] != id or visited[next] != 0:
						continue
					visited[next] = 1
					queue.append(next)
			if component.size() > best.size():
				best = component
		if best.is_empty():
			continue
		var keep := {}
		for cell in best:
			keep[cell] = true
		for start in n:
			if t.region_id[start] != id or keep.has(start):
				continue
			var cx := start % t.cols
			var cy := int(start / t.cols)
			var replacement := -1
			for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var nx := cx + delta.x
				var ny := cy + delta.y
				if nx < 0 or ny < 0 or nx >= t.cols or ny >= t.rows:
					continue
				var neighbor := ny * t.cols + nx
				if t.region_id[neighbor] >= 0 and t.region_id[neighbor] != id:
					replacement = t.region_id[neighbor]
					break
			if replacement >= 0:
				t.region_id[start] = replacement

static func _rebuild_region_records(t: TerrainMap, ley: LeyMap, seeds: Array[Vector2]) -> void:
	t.regions.clear()
	var counts: Array[int] = []
	var centers: Array[Vector2] = []
	var danger_sum: Array[float] = []
	counts.resize(seeds.size())
	centers.resize(seeds.size())
	danger_sum.resize(seeds.size())
	counts.fill(0)
	centers.fill(Vector2.ZERO)
	danger_sum.fill(0.0)
	for i in t.cols * t.rows:
		var id := t.region_id[i]
		if id < 0 or id >= seeds.size():
			continue
		counts[id] += 1
		centers[id] += t.cell_center(i)
		danger_sum[id] += t.danger[i]
	for id in seeds.size():
		var center := seeds[id]
		if counts[id] > 0:
			center = centers[id] / float(counts[id])
		t.regions.append({
			"id": id,
			"name": "",
			"center": center,
			"polygon": PackedVector2Array(),
			"area": float(counts[id]) * GRID * GRID,
			"type": "explore",
			"fragment": id >= ley.big_region_count,
			"biome": 0,
			"danger": danger_sum[id] / maxf(float(counts[id]), 1.0),
			"depth": 0,
			"expose": false,
			"seed": seeds[id],
			"sub_seeds": [],
			"named": false,
		})

static func _extract_region_contour(t: TerrainMap, id: int) -> PackedVector2Array:
	var edges: Array = []
	for y in t.rows:
		for x in t.cols:
			var i := y * t.cols + x
			if t.region_id[i] != id:
				continue
			var cx := x
			var cy := y
			if _region_neighbor(t, cx, cy - 1) != id:
				edges.append([Vector2i(cx, cy), Vector2i(cx + 1, cy)])
			if _region_neighbor(t, cx + 1, cy) != id:
				edges.append([Vector2i(cx + 1, cy), Vector2i(cx + 1, cy + 1)])
			if _region_neighbor(t, cx, cy + 1) != id:
				edges.append([Vector2i(cx + 1, cy + 1), Vector2i(cx, cy + 1)])
			if _region_neighbor(t, cx - 1, cy) != id:
				edges.append([Vector2i(cx, cy + 1), Vector2i(cx, cy)])
	return _chain_edges(edges)

static func _region_boundary_edges(t: TerrainMap) -> Dictionary:
	var edges := {}
	for y in t.rows:
		for x in t.cols:
			var i := y * t.cols + x
			var id := t.region_id[i]
			if id < 0:
				continue
			if not edges.has(id):
				edges[id] = []
			if _region_neighbor(t, x, y - 1) != id:
				edges[id].append([Vector2i(x, y), Vector2i(x + 1, y)])
			if _region_neighbor(t, x + 1, y) != id:
				edges[id].append([Vector2i(x + 1, y), Vector2i(x + 1, y + 1)])
			if _region_neighbor(t, x, y + 1) != id:
				edges[id].append([Vector2i(x + 1, y + 1), Vector2i(x, y + 1)])
			if _region_neighbor(t, x - 1, y) != id:
				edges[id].append([Vector2i(x, y + 1), Vector2i(x, y)])
	return edges

static func _region_neighbor(t: TerrainMap, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= t.cols or y >= t.rows:
		return -2
	return t.region_id[y * t.cols + x]

static func _extract_mask_contour(t: TerrainMap, mode: String) -> PackedVector2Array:
	var edges: Array = []
	for y in t.rows:
		for x in t.cols:
			var i := y * t.cols + x
			var inside := (t.land[i] != 0) if mode == "land" else (t.region_id[i] >= 0)
			if not inside:
				continue
			if not _mask_neighbor(t, x, y - 1, mode):
				edges.append([Vector2i(x, y), Vector2i(x + 1, y)])
			if not _mask_neighbor(t, x + 1, y, mode):
				edges.append([Vector2i(x + 1, y), Vector2i(x + 1, y + 1)])
			if not _mask_neighbor(t, x, y + 1, mode):
				edges.append([Vector2i(x + 1, y + 1), Vector2i(x, y + 1)])
			if not _mask_neighbor(t, x - 1, y, mode):
				edges.append([Vector2i(x, y + 1), Vector2i(x, y)])
	return _chain_edges(edges)

static func _mask_neighbor(t: TerrainMap, x: int, y: int, mode: String) -> bool:
	if x < 0 or y < 0 or x >= t.cols or y >= t.rows:
		return false
	if mode == "land":
		return t.land[y * t.cols + x] != 0
	return t.region_id[y * t.cols + x] >= 0

static func _chain_edges(edges: Array) -> PackedVector2Array:
	if edges.is_empty():
		return PackedVector2Array()
	var outgoing := {}
	for index in edges.size():
		var edge: Array = edges[index]
		var start: Vector2i = edge[0]
		if not outgoing.has(start):
			outgoing[start] = []
		outgoing[start].append(index)
	var used := {}
	var best := PackedVector2Array()
	for first in edges.size():
		if used.has(first):
			continue
		var loop := PackedVector2Array()
		var current := first
		while current >= 0 and not used.has(current):
			used[current] = true
			var edge: Array = edges[current]
			var start: Vector2i = edge[0]
			var end: Vector2i = edge[1]
			if loop.is_empty():
				loop.append(Vector2(start) * GRID)
			loop.append(Vector2(end) * GRID)
			if end == start:
				break
			var next := -1
			for candidate in outgoing.get(end, []):
				if not used.has(candidate):
					next = candidate
					break
			current = next
		if loop.size() > best.size():
			best = loop
	if best.size() > 1 and best[0] == best[best.size() - 1]:
		best.remove_at(best.size() - 1)
	return best

# --- P6 depth ----------------------------------------------------------------

static func p6_depth(ley: LeyMap, t: TerrainMap, rng: RandomNumberGenerator) -> void:
	for y in t.rows:
		for x in t.cols:
			t.depth[y * t.cols + x] = 0
	var cells_by_region: Array = []
	for _id in t.regions.size():
		cells_by_region.append([])
	for i in t.cols * t.rows:
		var rid := t.region_id[i]
		if rid >= 0 and rid < cells_by_region.size():
			cells_by_region[rid].append(i)
	for region in t.regions:
		var id: int = region.id
		var cells: Array = cells_by_region[id]
		if cells.is_empty():
			continue
		var distance := {}
		var queue: Array[int] = []
		for cell in cells:
			var cx: int = int(cell) % t.cols
			var cy: int = int(int(cell) / t.cols)
			var boundary := false
			for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _region_neighbor(t, cx + delta.x, cy + delta.y) != id:
					boundary = true
					break
			if boundary:
				distance[cell] = 0
				queue.append(cell)
		var cursor := 0
		while cursor < queue.size():
			var current: int = queue[cursor]
			cursor += 1
			var cx := current % t.cols
			var cy := int(current / t.cols)
			var next_distance: int = int(distance[current]) + 1
			for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var nx := cx + delta.x
				var ny := cy + delta.y
				if nx < 0 or ny < 0 or nx >= t.cols or ny >= t.rows:
					continue
				var neighbor := ny * t.cols + nx
				if t.region_id[neighbor] != id or distance.has(neighbor):
					continue
				distance[neighbor] = next_distance
				queue.append(neighbor)
		var ring_width := maxf(2.0, 0.23 * sqrt(float(region.area) / PI) / GRID)
		for cell in cells:
			t.depth[cell] = clampi(int(floor(float(distance.get(cell, 0)) / ring_width)), 0, 3)
		var sub_count := rng.randi_range(2, 4)
		var candidates: Array[int] = []
		for cell in cells:
			if int(t.depth[cell]) >= 1:
				candidates.append(cell)
		if candidates.is_empty():
			for cell in cells:
				candidates.append(int(cell))
		for _k in sub_count:
			var pick: int = candidates[rng.randi_range(0, candidates.size() - 1)]
			var at := t.cell_center(pick)
			region.sub_seeds.append(at)
			var cx := pick % t.cols
			var cy := int(pick / t.cols)
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var nx := cx + dx
					var ny := cy + dy
					if nx < 0 or ny < 0 or nx >= t.cols or ny >= t.rows:
						continue
					var ni := ny * t.cols + nx
					if t.land[ni] != 0:
						t.danger[ni] = clampf(t.danger[ni] + 0.06, 0.0, 1.0)

# --- P7 types ----------------------------------------------------------------

static func p7_types(ley: LeyMap, t: TerrainMap, rng: RandomNumberGenerator) -> void:
	var order: Array[int] = []
	for region in t.regions:
		region.expose = _distance_to_coast(t, region.center) < minf(t.extent.x, t.extent.y) * 0.08
		order.append(region.id)
	order.sort_custom(func(a, b): return float(t.regions[a].danger) > float(t.regions[b].danger))

	var assigned := {}
	var highs := 0
	var fights := 0
	var traps := 0
	for id in order:
		if highs >= ley.high_count:
			break
		if float(t.regions[id].danger) < 0.62:
			continue
		t.regions[id].type = "high"
		assigned[id] = true
		highs += 1
	if highs == 0:
		t.regions[order[0]].type = "high"
		assigned[order[0]] = true

	var newbie := -1
	var high_ids: Array[int] = []
	for id in assigned.keys():
		if str(t.regions[int(id)].type) == "high":
			high_ids.append(int(id))
	for i in range(order.size() - 1, -1, -1):
		var id: int = order[i]
		if assigned.has(id) or bool(t.regions[id].fragment):
			continue
		var touches_high := false
		for high_id in high_ids:
			if _regions_adjacent(t, id, high_id):
				touches_high = true
				break
		if touches_high:
			continue
		newbie = id
		break
	if newbie < 0:
		for i in range(order.size() - 1, -1, -1):
			var id: int = order[i]
			if not assigned.has(id) and not bool(t.regions[id].fragment):
				newbie = id
				break
	if newbie < 0:
		newbie = order[order.size() - 1]
	t.regions[newbie].type = "newbie"
	assigned[newbie] = true
	for id in order:
		if fights >= ley.fight_count:
			break
		if assigned.has(id):
			continue
		if float(t.regions[id].danger) < 0.45:
			continue
		t.regions[id].type = "fight"
		assigned[id] = true
		fights += 1
	for id in order:
		if traps >= ley.trap_count:
			break
		if assigned.has(id):
			continue
		if bool(t.regions[id].expose):
			continue
		if float(t.regions[id].danger) < 0.35:
			continue
		t.regions[id].type = "trap"
		assigned[id] = true
		traps += 1

	for region in t.regions:
		if not assigned.has(region.id):
			region.type = "explore"
		if bool(region.fragment) and region.type == "explore":
			var danger: float = float(region.danger)
			region.type = "high" if danger > 0.68 else ("fight" if danger > 0.48 else "trap")

	# Ecology biomes: 0..5, independent from generated region ids.
	var used_biomes := {}
	for region in t.regions:
		var biome := 0
		match str(region.type):
			"newbie":
				biome = 0
			"explore":
				biome = [0, 1, 4][int(region.id) % 3]
			"fight":
				biome = [2, 3][int(region.id) % 2]
			"trap":
				biome = [4, 5][int(region.id) % 2]
			"high":
				biome = 5
		region.biome = biome
		used_biomes[biome] = true
	var missing: Array[int] = []
	for biome in 6:
		if not used_biomes.has(biome):
			missing.append(biome)
	for region in t.regions:
		if missing.is_empty():
			break
		if region.type == "explore" and int(region.biome) != missing[0]:
			region.biome = missing[0]
			missing.pop_front()

	var used_names := {}
	var name_index := 0
	for region in t.regions:
		var candidate: String = REGION_NAME_A[name_index % REGION_NAME_A.size()] + REGION_NAME_B[int(name_index / REGION_NAME_A.size()) % REGION_NAME_B.size()]
		name_index += 1
		var suffix := 1
		while used_names.has(candidate):
			suffix += 1
			candidate = "%s·%d" % [REGION_NAME_A[region.id % REGION_NAME_A.size()] + REGION_NAME_B[(region.id + suffix) % REGION_NAME_B.size()], suffix]
		used_names[candidate] = true
		region.name = candidate

# --- P8 roads / sites / chests ----------------------------------------------

static func p8_roads(ley: LeyMap, t: TerrainMap, rng: RandomNumberGenerator) -> void:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, t.cols, t.rows)
	grid.cell_size = Vector2.ONE * GRID
	grid.offset = Vector2.ONE * GRID * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in t.rows:
		for x in t.cols:
			var at := Vector2((x + 0.5) * GRID, (y + 0.5) * GRID)
			var solid := not t.land_at(at)
			if not solid:
				# Lakes are impenetrable for roads: no causeways across open water.
				solid = t.lake_mask[y * t.cols + x] != 0
			if not solid:
				for feature in t.features:
					if feature.get("kind", "cliff") == "cliff" and Geometry2D.is_point_in_polygon(at, feature.polygon):
						solid = true
						break
			grid.set_point_solid(Vector2i(x, y), solid)
			if not solid:
				var depth := t.water_depth_at(at)
				grid.set_point_weight_scale(Vector2i(x, y), 40.0 if depth > TerrainMap.WADE_DEPTH else (9.0 if depth > 0.0 else 1.0))

	var centers: Array[Vector2] = []
	for region in t.regions:
		centers.append(region.center)
	var edges: Array = []
	if centers.size() > 1:
		var in_tree := {0: true}
		while in_tree.size() < centers.size():
			var best_from := -1
			var best_to := -1
			var best_distance := INF
			for a in in_tree.keys():
				for b in centers.size():
					if in_tree.has(b):
						continue
					var distance := centers[a].distance_to(centers[b])
					if distance < best_distance:
						best_distance = distance
						best_from = a
						best_to = b
			if best_to < 0:
				break
			in_tree[best_to] = true
			edges.append([best_from, best_to])
		var pairs: Array = []
		for a in centers.size():
			for b in range(a + 1, centers.size()):
				if _edge_exists(edges, a, b):
					continue
				pairs.append({"a": a, "b": b, "distance": centers[a].distance_to(centers[b])})
		pairs.sort_custom(func(x, y): return float(x.distance) < float(y.distance))
		for i in mini(6, pairs.size()):
			edges.append([pairs[i].a, pairs[i].b])
	# Fragments branch to the nearest big region.
	for region in t.regions:
		if not bool(region.fragment):
			continue
		var nearest := -1
		var nearest_distance := INF
		for other in t.regions:
			if bool(other.fragment):
				continue
			var distance: float = region.center.distance_to(other.center)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = other.id
		if nearest >= 0:
			edges.append([region.id, nearest])

	t.roads.clear()
	for edge in edges:
		var a: Vector2 = centers[int(edge[0])]
		var b: Vector2 = centers[int(edge[1])]
		var path := _road_path(grid, t, a, b)
		if path.size() >= 2:
			# Rivers may be forded only on a bridge deck: carve the deck dry so
			# water and road never occupy the same cell.
			_dry_road(t, path)
			t.roads.append(path)
	MapBlueprints.place_sites(t, rng, ley.site_budget)
	MapBlueprints.place_chests(t, rng, ley.chest_budget)
	t.build_solid_index()

static func _edge_exists(edges: Array, a: int, b: int) -> bool:
	for edge in edges:
		if (int(edge[0]) == a and int(edge[1]) == b) or (int(edge[0]) == b and int(edge[1]) == a):
			return true
	return false

static func _road_path(grid: AStarGrid2D, t: TerrainMap, a: Vector2, b: Vector2) -> PackedVector2Array:
	var first := Vector2i(int(a.x / GRID), int(a.y / GRID))
	var last := Vector2i(int(b.x / GRID), int(b.y / GRID))
	first = _nearest_open_cell(grid, first)
	last = _nearest_open_cell(grid, last)
	if first.x < 0 or last.x < 0:
		return PackedVector2Array()
	if not grid.is_in_boundsv(first) or not grid.is_in_boundsv(last):
		return PackedVector2Array()
	return grid.get_point_path(first, last, true)

static func _nearest_open_cell(grid: AStarGrid2D, cell: Vector2i) -> Vector2i:
	if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
		return cell
	for distance in range(1, 12):
		for y in range(-distance, distance + 1):
			for x in range(-distance, distance + 1):
				var at := cell + Vector2i(x, y)
				if grid.is_in_boundsv(at) and not grid.is_point_solid(at):
					return at
	return Vector2i(-1, -1)

static func _dry_road(t: TerrainMap, path: PackedVector2Array) -> void:
	var i := 0
	while i < path.size():
		if t.water_depth_at(path[i]) <= 0.0:
			i += 1
			continue
		var start := i
		while i < path.size() and t.water_depth_at(path[i]) > 0.0:
			i += 1
		var end := i - 1
		# A road crossing is a bridge: remove the water under its deck.
		var half := maxf(64.0, GRID * 2.0)
		for index in range(start, end):
			_carve_segment(t, path[index], path[index + 1], half)
		if start == end:
			_carve_disc(t, path[start], half)
		_carve_disc(t, path[maxi(0, start - 1)], half)
		_carve_disc(t, path[mini(path.size() - 1, end + 1)], half)
		var rect := Rect2(path[start], Vector2.ZERO)
		for index in range(start, end + 1):
			rect = rect.expand(path[index])
		rect = rect.grow(half)
		# Keep the visible deck tight to the crossing. The old AABB of every wet
		# path point grew into a plaza-sized slab that read as a building.
		var bank_a: Vector2 = path[maxi(0, start - 1)]
		var bank_b: Vector2 = path[mini(path.size() - 1, end + 1)]
		var min_dim := minf(t.extent.x, t.extent.y)
		var span := clampf(bank_a.distance_to(bank_b) + half * 2.0, min_dim * 0.012, min_dim * 0.045)
		var center := (bank_a + bank_b) * 0.5
		rect = Rect2(center - Vector2.ONE * span * 0.5, Vector2.ONE * span)
		var duplicate := false
		for existing: Rect2 in t.bridges:
			if existing.get_center().distance_to(rect.get_center()) < 140.0:
				duplicate = true
				break
		if not duplicate:
			t.bridges.append(rect)

static func _carve_segment(t: TerrainMap, a: Vector2, b: Vector2, half: float) -> void:
	var bounds := Rect2(a, Vector2.ZERO).expand(b).grow(half + GRID)
	var x0 := maxi(0, int(floor(bounds.position.x / GRID)))
	var y0 := maxi(0, int(floor(bounds.position.y / GRID)))
	var x1 := mini(t.cols - 1, int(floor(bounds.end.x / GRID)))
	var y1 := mini(t.rows - 1, int(floor(bounds.end.y / GRID)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var ci := y * t.cols + x
			if t.water_depth[ci] <= 0.0:
				continue
			var center := Vector2((x + 0.5) * GRID, (y + 0.5) * GRID)
			if Geometry2D.get_closest_point_to_segment(center, a, b).distance_to(center) <= half:
				t.water_depth[ci] = 0.0

static func _carve_disc(t: TerrainMap, at: Vector2, radius: float) -> void:
	var x0 := maxi(0, int(floor((at.x - radius) / GRID)))
	var y0 := maxi(0, int(floor((at.y - radius) / GRID)))
	var x1 := mini(t.cols - 1, int(floor((at.x + radius) / GRID)))
	var y1 := mini(t.rows - 1, int(floor((at.y + radius) / GRID)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var ci := y * t.cols + x
			if t.water_depth[ci] <= 0.0:
				continue
			var center := Vector2((x + 0.5) * GRID, (y + 0.5) * GRID)
			if center.distance_to(at) <= radius:
				t.water_depth[ci] = 0.0

# --- P9 special structures ---------------------------------------------------

static func p9_specials(ley: LeyMap, t: TerrainMap, rng: RandomNumberGenerator) -> void:
	# --- exits: spread around the coast -------------------------------------
	var samples: Array[Vector2] = []
	var reachable := _bfs_open(t, t.spawn)
	if not t.coast.is_empty():
		var step := maxi(1, int(t.coast.size() / 220))
		for i in range(0, t.coast.size(), step):
			var at := t.nearest_open(t.coast[i], 28.0, 700.0)
			var cell := t.index_of(at)
			if not t.blocked(at, 28.0) and cell >= 0 and reachable[cell] != 0:
				samples.append(at)
	var exits: Array[Vector2] = []
	if not samples.is_empty():
		exits.append(samples[0])
		while exits.size() < ley.exit_count:
			var best := -1
			var best_distance := -1.0
			for i in samples.size():
				var candidate := samples[i]
				var nearest := INF
				for existing in exits:
					nearest = minf(nearest, candidate.distance_to(existing))
				if nearest > best_distance:
					best_distance = nearest
					best = i
			if best < 0:
				break
			exits.append(samples[best])
			samples.remove_at(best)
	while exits.size() < ley.exit_count:
		var at := Vector2(rng.randf_range(0.1, 0.9) * t.extent.x, rng.randf_range(0.1, 0.9) * t.extent.y)
		at = t.nearest_open(at, 28.0, 900.0)
		if not t.blocked(at, 28.0):
			exits.append(at)
	t.exits = exits
	t.exit_names.clear()
	for name in EXIT_NAMES:
		t.exit_names.append(name)
	var indices: Array[int] = [0, 1, 2, 3, 4]
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := indices[i]
		indices[i] = indices[j]
		indices[j] = swap
	t.sealed_exits.clear()
	for i in mini(ley.sealed_exit_count, indices.size()):
		t.sealed_exits.append(indices[i])

	# --- shrines: explore / fight / high each at least one -------------------
	var used_sites := {}
	for type in ["explore", "fight", "high"]:
		var site_index := _site_of_region_type(t, type, used_sites)
		if site_index < 0:
			site_index = _nearest_unused_site(t, used_sites)
		var at := Vector2.ZERO
		if site_index >= 0:
			used_sites[site_index] = true
			at = t.nearest_open(t.sites[site_index].p + Vector2(0.0, 95.0), 22.0, 420.0)
		else:
			var region := _region_of_type(t, type)
			at = t.nearest_open(region.center if not region.is_empty() else t.extent * 0.5, 22.0, 700.0)
		t.shrines.append({"p": at, "done": false, "progress": 0.0})

	# --- boss: random one of the top three danger cores ----------------------
	var cores: Array = t.cores.filter(func(core): return str(core.get("kind", "core")) == "core")
	cores.sort_custom(func(a, b): return float(a.danger) > float(b.danger))
	var candidates := mini(ley.boss_candidate_count, cores.size())
	var arena_radius := 800.0 * ley.linear_scale
	if candidates > 0:
		var start := rng.randi_range(0, candidates - 1)
		var chosen: Dictionary = cores[start]
		var center := t.nearest_open(chosen.p, 58.0, 900.0)
		for offset in candidates:
			var candidate: Dictionary = cores[(start + offset) % candidates]
			var candidate_center := t.nearest_open(candidate.p, 58.0, 900.0)
			candidate_center = _find_clear_arena(t, candidate_center, arena_radius)
			if not _point_clear(t, candidate_center, arena_radius):
				_flatten_arena(t, candidate_center, arena_radius)
			if _point_clear(t, candidate_center, arena_radius):
				chosen = candidate
				center = candidate_center
				break
		t.boss = {"center": center, "danger": float(chosen.danger), "core": chosen.p, "radius": arena_radius}
	else:
		var center := _highest_danger_point(t)
		t.boss = {"center": center, "danger": t.danger_at(center), "core": center, "radius": arena_radius}
	var entrances: Array[Vector2] = []
	for i in 8:
		var at: Vector2 = t.boss.center + Vector2.from_angle(TAU * float(i) / 8.0) * 165.0
		if not t.blocked(at, 20.0):
			entrances.append(at)
		if entrances.size() >= 2:
			break
	t.boss["entrances"] = entrances

	# --- royal city: reserved high-danger core, never the boss core ---------
	t.royal_city = {}
	if ley.royal_city_count > 0 and cores.size() > 1:
		var pick: Dictionary = cores[cores.size() - 1]
		for core in cores:
			if core.p.distance_to(t.boss.get("center", Vector2.ZERO)) > 900.0:
				pick = core
				break
		t.royal_city = {
			"center": t.nearest_open(pick.p, 58.0, 900.0),
			"danger": float(pick.danger),
			"blueprint": "royal_city",
		}

	# --- three map guardians, spread apart ----------------------------------
	t.guardians.clear()
	var available: Array[int] = []
	for i in t.sites.size():
		available.append(i)
	while t.guardians.size() < ley.guardian_count and not available.is_empty():
		var best := -1
		var best_distance := -1.0
		for index in available:
			var at: Vector2 = t.sites[index].p
			var nearest := INF
			for chosen in t.guardians:
				nearest = minf(nearest, at.distance_to(t.sites[chosen].p))
			if nearest > best_distance:
				best_distance = nearest
				best = index
		if best < 0:
			break
		t.guardians.append(best)
		available.erase(best)

	# --- spawn: inside the newbie region, near a road -----------------------
	var newbie := _region_of_type(t, "newbie")
	var spawn_at := t.extent * 0.5
	if not newbie.is_empty():
		spawn_at = newbie.center
		t.spawn_region = int(newbie.id)
	spawn_at = t.nearest_open(spawn_at, 22.0, 900.0)
	if t.blocked(spawn_at, 22.0):
		spawn_at = _find_spawn(t, rng)
	t.spawn = spawn_at

	# --- city gate: edge-facing site, road-connected ------------------------
	var gate := _pick_city_gate(t)
	t.city_gate = gate

static func _site_of_region_type(t: TerrainMap, type: String, used: Dictionary) -> int:
	for i in t.sites.size():
		if used.has(i):
			continue
		var region := int(t.sites[i].get("region", -1))
		if region < 0 or region >= t.regions.size():
			continue
		if str(t.regions[region].type) == type:
			return i
	return -1

static func _nearest_unused_site(t: TerrainMap, used: Dictionary) -> int:
	for i in t.sites.size():
		if not used.has(i):
			return i
	return -1

static func _region_of_type(t: TerrainMap, type: String) -> Dictionary:
	for region in t.regions:
		if str(region.type) == type:
			return region
	return {}

static func _highest_danger_point(t: TerrainMap) -> Vector2:
	var best := t.extent * 0.5
	var best_danger := -1.0
	for y in range(2, t.rows - 2):
		for x in range(2, t.cols - 2):
			var i := y * t.cols + x
			if t.land[i] == 0:
				continue
			if t.danger[i] > best_danger:
				best_danger = t.danger[i]
				best = Vector2((x + 0.5) * GRID, (y + 0.5) * GRID)
	return best

static func _find_clear_arena(t: TerrainMap, center: Vector2, radius: float) -> Vector2:
	if _point_clear(t, center, radius):
		return center
	for ring in range(1, 9):
		for i in 16:
			var at := center + Vector2.from_angle(TAU * float(i) / 16.0) * float(ring) * 140.0
			if _point_clear(t, at, radius):
				return at
	return center

static func _flatten_arena(t: TerrainMap, center: Vector2, radius: float) -> void:
	var walls: Array[Rect2] = []
	for wall in t.walls:
		if wall.get_center().distance_to(center) > radius + wall.size.length() * 0.5:
			walls.append(wall)
	t.walls = walls
	var footprints: Array[Rect2] = []
	for footprint in t.building_footprints:
		if footprint.get_center().distance_to(center) > radius + footprint.size.length() * 0.5:
			footprints.append(footprint)
	t.building_footprints = footprints
	t.build_solid_index()

static func _find_spawn(t: TerrainMap, rng: RandomNumberGenerator) -> Vector2:
	for _i in 300:
		var at := Vector2(rng.randf_range(0.15, 0.85) * t.extent.x, rng.randf_range(0.15, 0.85) * t.extent.y)
		if t.land_at(at) and not t.blocked(at, 22.0) and t.danger_at(at) < 0.35:
			return at
	return t.extent * 0.5

static func _pick_city_gate(t: TerrainMap) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	for site in t.sites:
		var at: Vector2 = site.p
		var distance := minf(minf(at.x, t.extent.x - at.x), minf(at.y, t.extent.y - at.y))
		if distance < best_distance:
			best_distance = distance
			best = at
	if best == Vector2.ZERO and not t.roads.is_empty():
		var road: PackedVector2Array = t.roads[0]
		if not road.is_empty():
			best = road[0]
	return best

# --- P10 validation ----------------------------------------------------------

static func p10_validate(t: TerrainMap, options: Dictionary = {}) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var area_scale := clampf((t.extent.x * t.extent.y) / (TARGET_EXTENT.x * TARGET_EXTENT.y), 0.02, 1.0)
	var area_max := 35_000_000.0 * area_scale
	var region_count := t.regions.size()
	if region_count < 45 or region_count > 52:
		errors.append("E_REGION_COUNT")
	var big := 0
	var fragments := 0
	var types := {"newbie": 0, "explore": 0, "fight": 0, "trap": 0, "high": 0}
	for region in t.regions:
		if bool(region.fragment):
			fragments += 1
		else:
			big += 1
		if float(region.area) > area_max:
			errors.append("E_REGION_AREA")
		var type := str(region.type)
		types[type] = int(types.get(type, 0)) + 1
	if big < 35 or big > 42 or fragments < 8 or fragments > 10:
		errors.append("E_REGION_COUNT")
	if int(types["newbie"]) != 1:
		errors.append("E_QUOTA")
	if int(types["high"]) < 1 or int(types["high"]) > 3:
		errors.append("E_QUOTA")
	if int(types["fight"]) < 3:
		errors.append("E_QUOTA")
	if int(types["trap"]) < 3:
		errors.append("E_QUOTA")

	# Depth mix over land cells.
	var depth_counts := [0, 0, 0, 0]
	var land_count := 0
	var water_count := 0
	for i in t.cols * t.rows:
		if t.land[i] == 0:
			continue
		land_count += 1
		depth_counts[clampi(int(t.depth[i]), 0, 3)] += 1
		if t.water_depth[i] > 0.0:
			water_count += 1
	var depth_mix := PackedFloat32Array()
	for count in depth_counts:
		depth_mix.append(float(count) / maxf(float(land_count), 1.0))
	var depth_target := [0.55, 0.28, 0.13, 0.04]
	for i in 4:
		if absf(depth_mix[i] - float(depth_target[i])) > 0.08:
			errors.append("E_DEPTH_MIX")
			break

	var water_fraction := float(water_count) / maxf(float(land_count), 1.0)
	if water_fraction < WATER_MIN or water_fraction > WATER_MAX:
		errors.append("E_WATER_FRACTION")
	var river_count := 0
	var stream_count := 0
	for river in t.rivers:
		if str(river.get("kind", "river")) == "river":
			river_count += 1
		else:
			stream_count += 1
	if river_count < 1 or river_count > 3:
		errors.append("E_WATER_COUNT")
	if stream_count != 0:
		errors.append("E_WATER_THIN")
	var min_dim := minf(t.extent.x, t.extent.y)
	for river in t.rivers:
		if float(river.get("width", 0.0)) < min_dim * 0.012:
			errors.append("E_WATER_THIN")
			break
	if t.lakes.size() < 2 or t.lakes.size() > 5:
		errors.append("E_WATER_COUNT")
	var navigable := false
	for lake in t.lakes:
		if bool(lake.get("navigable", false)):
			navigable = true
			break
	if not navigable:
		errors.append("E_NAVIGABLE")

	if t.exits.size() != 5:
		errors.append("E_EXIT_COUNT")
	if t.sealed_exits.size() != 2:
		errors.append("E_EXIT_SEAL")
	var open_exits: Array[Vector2] = []
	for i in t.exits.size():
		if not (i in t.sealed_exits):
			open_exits.append(t.exits[i])
	if open_exits.size() != 3:
		errors.append("E_EXIT_SEAL")
	var quadrants := {}
	for at in open_exits:
		quadrants[_quadrant(t, at)] = true
	if quadrants.size() < 2:
		errors.append("E_EXIT_QUADRANT")

	var reachable := _bfs_open(t, t.spawn)
	if not _is_reachable(t, reachable, t.spawn):
		errors.append("E_SPAWN")
	for at in open_exits:
		if not _is_reachable(t, reachable, at):
			errors.append("E_EXIT_REACH")
			break
	if t.shrines.size() != 3:
		errors.append("E_SHRINE")
	for shrine in t.shrines:
		if not _is_reachable(t, reachable, shrine.p):
			errors.append("E_SHRINE")
			break
	if t.boss.is_empty() or not _point_clear(t, t.boss.get("center", Vector2.ZERO), maxf(40.0, 800.0 * sqrt(area_scale))):
		errors.append("E_BOSS")
	var boss_entrances: Array = t.boss.get("entrances", [])
	if boss_entrances.size() < 2:
		errors.append("E_ARENA")
	if t.royal_city.is_empty():
		pass

	if t.sites.size() < mini(18, 26):
		warnings.append("W_SITE_COUNT")
	var reachable_sites := 0
	for site in t.sites:
		if _is_reachable(t, reachable, site.p):
			reachable_sites += 1
		if t.blocked(site.p, 18.0):
			errors.append("E_SITE_OVERLAP")
			break
	if t.sites.size() > 0 and float(reachable_sites) / float(t.sites.size()) < 0.95:
		errors.append("E_SITE_REACH")
	for chest in t.chests:
		if not _is_reachable(t, reachable, chest.p):
			errors.append("E_SITE_REACH")
			break
	if t.docks.size() < 3:
		errors.append("E_FERRY")
	if t.roads.size() < maxi(1, t.regions.size() - 1):
		errors.append("E_ROAD_CONNECT")
	for road in t.roads:
		var wet := false
		for point: Vector2 in road:
			if t.water_depth_at(point) > 0.0:
				wet = true
				break
		if wet:
			errors.append("E_ROAD_WATER")
			break
	if t.spawn == Vector2.ZERO or t.city_gate == Vector2.ZERO:
		errors.append("E_SPAWN")
	if int(types["newbie"]) == 1:
		var newbie_region := _region_of_type(t, "newbie")
		if not newbie_region.is_empty():
			for other in t.regions:
				if str(other.type) == "high" and _regions_adjacent(t, int(newbie_region.id), int(other.id)):
					errors.append("E_QUOTA")
					break

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"metrics": {
			"regions": region_count,
			"big_regions": big,
			"fragments": fragments,
			"water_fraction": water_fraction,
			"rivers": river_count,
			"streams": stream_count,
			"lakes": t.lakes.size(),
			"exits": t.exits.size(),
			"open_exits": open_exits.size(),
			"sites": t.sites.size(),
			"chests": t.chests.size(),
			"depth_mix": depth_mix,
			"layout_hash": t.layout_hash,
		},
	}

static func _quadrant(t: TerrainMap, p: Vector2) -> int:
	var x := 1 if p.x >= t.extent.x * 0.5 else 0
	var y := 1 if p.y >= t.extent.y * 0.5 else 0
	return y * 2 + x

static func _point_clear(t: TerrainMap, p: Vector2, radius: float) -> bool:
	if t.blocked(p, 20.0):
		return false
	for i in 16:
		if t.blocked(p + Vector2.from_angle(TAU * float(i) / 16.0) * radius, 20.0):
			return false
	return true

static func _bfs_open(t: TerrainMap, start: Vector2) -> PackedByteArray:
	var visited := PackedByteArray()
	visited.resize(t.cols * t.rows)
	visited.fill(0)
	var cell := Vector2i(int(start.x / GRID), int(start.y / GRID))
	if cell.x < 0 or cell.y < 0 or cell.x >= t.cols or cell.y >= t.rows:
		return visited
	var queue: Array[int] = [cell.y * t.cols + cell.x]
	visited[queue[0]] = 1
	var cursor := 0
	while cursor < queue.size():
		var current: int = queue[cursor]
		cursor += 1
		var cx := current % t.cols
		var cy := int(current / t.cols)
		for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nx: int = cx + delta.x
			var ny: int = cy + delta.y
			if nx < 0 or ny < 0 or nx >= t.cols or ny >= t.rows:
				continue
			var next: int = ny * t.cols + nx
			if visited[next] != 0:
				continue
			if t.blocked(t.cell_center(next), 15.0):
				continue
			visited[next] = 1
			queue.append(next)
	return visited

static func _is_reachable(t: TerrainMap, visited: PackedByteArray, p: Vector2) -> bool:
	var origin := Vector2i(int(p.x / GRID), int(p.y / GRID))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell := origin + Vector2i(dx, dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= t.cols or cell.y >= t.rows:
				continue
			var index := cell.y * t.cols + cell.x
			if index >= 0 and index < visited.size() and visited[index] != 0:
				return true
	return false

static func _regions_adjacent(t: TerrainMap, a: int, b: int) -> bool:
	for y in t.rows:
		for x in t.cols:
			if t.region_id[y * t.cols + x] != a:
				continue
			for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _region_neighbor(t, x + delta.x, y + delta.y) == b:
					return true
	return false

# --- P11 chunks / hash -------------------------------------------------------

static func p11_chunks(t: TerrainMap) -> void:
	MapChunks.build_index(t)

static func layout_hash(t: TerrainMap) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(JSON.stringify(t.canonical_summary(), "", true).to_utf8_buffer())
	return ctx.finish().hex_encode()

static func stable_hash(text: String) -> int:
	var h: int = 2166136261
	for b in text.to_utf8_buffer():
		h = (h ^ int(b)) * 16777619
		h = h & 0xffffffff
	return h

static func pass_rng(seed_value: int, pass_id: String, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = stable_hash("%d|%s|%d" % [seed_value, pass_id, salt])
	return rng

static func _pass(ley: LeyMap, pass_id: String) -> RandomNumberGenerator:
	return pass_rng(ley.seed_value, pass_id, int(ley.pass_salts.get(pass_id, 0)))


