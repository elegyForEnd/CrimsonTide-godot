class_name MapBlueprints
extends RefCounted
## Reusable authored modules for the generated continent. P1 converts the 18
## existing landmarks to data blueprints and stamps them onto TerrainMap.
##
## Geometry is authored in legacy (current-size) units. At 10x the stamper scales
## it by max(1, linear_scale / 0.316), so rooms, walls and props keep the same
## relation to character size.

const AssetLayout = preload("res://scripts/scene_asset_layout.gd")

const SITE_NAMES := [
	"风铃驿站", "巡礼礼拜堂", "白花营地", "失落书库", "晨钟大桥", "晨曦王城",
	"月晶矿场", "观星高塔", "银月营地", "蔷薇温室", "花眠庭院", "红棘修道院",
	"雾汐药圃", "沉钟遗迹", "月舟码头", "圣血大教堂", "白蔷王庭", "月蚀宝库",
]
const SITE_TIERS := [1, 1, 1, 1, 1, 2, 2, 2, 1, 1, 1, 2, 1, 2, 1, 2, 2, 2]
const SITE_PROPS := [6, 0, 7, 0, 3, 8, 2, 7, 2, 3, 1, 0, 4, 0, 6, 0, 5, 7]
const SHRINE_SITES := [3, 10, 15]

static func specs() -> Array:
	var output: Array = []
	for i in SITE_NAMES.size():
		var size := Vector2(500, 400)
		if i in [5, 15]:
			size = Vector2(780, 620)
		var walls: Array[Rect2] = []
		if i % 3 != 2:
			for side in [-1, 1]:
				for end in [-1, 1]:
					walls.append(Rect2(Vector2(side * size.x / 2.0 - 12.0, end * size.y / 2.0 - 75.0), Vector2(24, 150)))
					walls.append(Rect2(Vector2(end * size.x / 2.0 - 100.0, side * size.y / 2.0 - 12.0), Vector2(200, 24)))
		var landmark_size := 210.0
		if i == 5:
			landmark_size = 510.0
		elif i == 15:
			landmark_size = 290.0
		output.append({
			"id": "site_%02d" % i,
			"kind": "site",
			"name": SITE_NAMES[i],
			"size": size,
			"tier": SITE_TIERS[i],
			"prop": SITE_PROPS[i],
			"walls": walls,
			"shrine": i in SHRINE_SITES,
			"landmark_offset": Vector2(0, -110),
			"landmark_size": landmark_size,
			"loot_profile": "tier2_indoor" if SITE_TIERS[i] == 2 else "tier1_outdoor",
			"enemy_budget": 2 if SITE_TIERS[i] == 2 else 1,
			"tags": ["site"],
		})
	return output

static func place_sites(t: TerrainMap, rng: RandomNumberGenerator, budget: int) -> void:
	t.sites.clear()
	t.walls.clear()
	t.decor.clear()
	t.building_footprints.clear()
	var templates := specs()
	var placed := 0
	var order: Array[int] = []
	for region in t.regions:
		order.append(int(region.id))
	order.sort_custom(func(a, b): return float(t.regions[a].danger) > float(t.regions[b].danger))
	var site_index := 0
	for region_id in order:
		if placed >= budget:
			break
		if bool(t.regions[region_id].fragment):
			continue
		var desired := 2 if placed < int(budget * 0.65) else 1
		for _k in desired:
			if placed >= budget:
				break
			var template: Dictionary = templates[site_index % templates.size()]
			var rot: int = [0, 90, 180, 270][rng.randi_range(0, 3)]
			var at := _find_site_position(t, region_id, template, rot, rng)
			if at == Vector2.ZERO:
				continue
			_stamp_site(t, template, at, rot, region_id)
			placed += 1
			site_index += 1
	if placed == 0:
		# Last-resort placement at the least dangerous open region.
		for region in t.regions:
			if t.regions[region.id].fragment:
				continue
			var at := t.nearest_open(region.center, 40.0, 900.0)
			if not t.blocked(at, 50.0):
				_stamp_site(t, templates[0], at, 0, int(region.id))
				break

static func _find_site_position(t: TerrainMap, region_id: int, template: Dictionary, rot: int, rng: RandomNumberGenerator) -> Vector2:
	var candidates: Array[Vector2] = []
	var region: Dictionary = t.regions[region_id]
	var center: Vector2 = region.center
	candidates.append(center)
	# Road points inside this region are the strongest anchoring candidates.
	for road in t.roads:
		var points: PackedVector2Array = road
		if points.is_empty():
			continue
		for i in range(0, points.size(), maxi(1, int(points.size() / 6))):
			if t.region_at(points[i]) == region_id:
				candidates.append(points[i])
	for _i in 60:
		var angle := rng.randf_range(0.0, TAU)
		var radius := sqrt(rng.randf()) * sqrt(float(region.area) / PI) * 0.75
		var at := center + Vector2.from_angle(angle) * radius
		if t.region_at(at) == region_id:
			candidates.append(at)
	var size: Vector2 = template.size
	if rot == 90 or rot == 270:
		size = Vector2(size.y, size.x)
	for candidate in candidates:
		var at := t.nearest_open(candidate, 45.0, 280.0)
		if _can_place(t, at, size, template, rot):
			return at
	return Vector2.ZERO

static func _can_place(t: TerrainMap, at: Vector2, size: Vector2, template: Dictionary, rot: int) -> bool:
	var half := size * 0.5
	if not t.land_at(at) or t.water_depth_at(at) > 0.0:
		return false
	for x in [-0.5, -0.25, 0.0, 0.25, 0.5]:
		for y in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			var sample := at + Vector2(x * size.x, y * size.y)
			if not t.land_at(sample) or t.water_depth_at(sample) > 0.0:
				return false
			if t.blocked(sample, 18.0):
				return false
	for site in t.sites:
		if at.distance_to(site.p) < maxf(size.length(), float(site.rect.size.length())) * 0.55 + 120.0:
			return false
	for footprint in t.building_footprints:
		if footprint.grow(60.0).has_point(at):
			return false
	for wall in t.walls:
		if wall.grow(24.0).has_point(at):
			return false
	# Keep the three boss-candidate cores clear for the arena (P9 picks one).
	var area_scale := (t.extent.x * t.extent.y) / (30400.0 * 22800.0)
	var arena_radius := 800.0 * sqrt(area_scale)
	var cores: Array = t.cores.filter(func(core): return str(core.get("kind", "core")) == "core")
	cores.sort_custom(func(a, b): return float(a.danger) > float(b.danger))
	for i in mini(3, cores.size()):
		if at.distance_to(cores[i].p) < arena_radius + size.length() * 0.55:
			return false
	# Prospective walls must not cross an already stamped site centre.
	for wall in template_walls(template, at, rot):
		for site in t.sites:
			if wall.grow(18.0).has_point(site.p):
				return false
	return true

static func template_walls(template: Dictionary, at: Vector2, rot: int) -> Array[Rect2]:
	var output: Array[Rect2] = []
	var walls: Array[Rect2] = template.walls
	for wall in walls:
		var position := _rotate_point(wall.position, rot)
		var wall_size := wall.size
		if rot == 90 or rot == 270:
			wall_size = Vector2(wall.size.y, wall.size.x)
		output.append(Rect2(at + position, wall_size))
	return output

static func _stamp_site(t: TerrainMap, template: Dictionary, at: Vector2, rot: int, region_id: int) -> void:
	var size: Vector2 = template.size
	if rot == 90 or rot == 270:
		size = Vector2(size.y, size.x)
	var rect := Rect2(at - size * 0.5, size)
	t.sites.append({
		"p": at,
		"rect": rect,
		"name": template.name,
		"biome": int(t.regions[region_id].biome),
		"region": region_id,
		"tier": int(template.tier),
		"prop": int(template.prop),
		"engaged": false,
		"cleared": false,
		"defeated": 0,
		"blueprint": str(template.id),
		"loot_profile": str(template.loot_profile),
		"enemy_budget": int(template.enemy_budget),
	})
	var walls: Array[Rect2] = template_walls(template, at, rot)
	for wall in walls:
		t.walls.append(wall)
	var decor := {
		"p": at + Vector2(0.0, -110.0),
		"type": int(template.prop),
		"size": float(template.landmark_size),
		"landmark": true,
	}
	t.decor.append(decor)
	var building: Dictionary = AssetLayout.building(decor)
	if not building.is_empty():
		t.building_footprints.append(building.rect)

static func _rotate_point(p: Vector2, rot: int) -> Vector2:
	match rot:
		90:
			return Vector2(-p.y, p.x)
		180:
			return -p
		270:
			return Vector2(p.y, -p.x)
		_:
			return p

static func place_chests(t: TerrainMap, rng: RandomNumberGenerator, budget: int) -> void:
	t.chests.clear()
	var attempts := 0
	while t.chests.size() < budget and attempts < 2400:
		attempts += 1
		var at := Vector2(rng.randf_range(0.08, 0.92) * t.extent.x, rng.randf_range(0.08, 0.92) * t.extent.y)
		at = t.nearest_open(at, 24.0, 500.0)
		if t.blocked(at, 24.0):
			continue
		var near_site := false
		for site in t.sites:
			if at.distance_to(site.p) < 700.0:
				near_site = true
				break
		if near_site:
			continue
		var near_chest := false
		for chest in t.chests:
			if at.distance_to(chest.p) < 700.0:
				near_chest = true
				break
		if near_chest:
			continue
		var region := t.region_at(at)
		var danger := 0.35
		if region >= 0 and region < t.regions.size():
			danger = float(t.regions[region].danger)
		var tier := clampi(int(floor(danger * 4.0)), 0, 4)
		t.chests.append({
			"p": at,
			"key": "container",
			"items": [],
			"open": false,
			"searched": 0,
			"bonus": false,
			"class": 1,
			"cache_tier": tier,
			"title": "野外遗落物资箱 · %d档" % (tier + 1),
		})
