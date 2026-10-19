class_name MapWorld
extends Ruins
## Ruins-compatible adapter for a generated TerrainMap.
##
## Presentation and session code keep reading the legacy field names; collision,
## biome and region queries delegate to the authoritative TerrainMap. Legacy
## Ruins is untouched and remains the fallback/test baseline.

func generate(value: int) -> void:
	var target: Vector2 = extent
	var result := MapGen.try_generate(value, {"extent": target})
	if bool(result.get("ok", false)):
		apply_terrain(result.terrain)
	else:
		super.generate(value)

func apply_terrain(t: TerrainMap) -> void:
	terrain = t
	generated = true
	map_seed = t.seed_value
	extent = t.extent
	layout_scale = 1.0
	layout_version = t.layout_version
	layout_hash = t.layout_hash
	spawn = t.spawn
	center = t.extent * 0.5
	city_gate = t.city_gate

	coast = t.coast
	river = t.rivers[0].polygon if not t.rivers.is_empty() else PackedVector2Array()
	rivers = t.rivers
	lakes = t.lakes
	bridges = t.bridges
	roads = t.roads
	features = t.features
	walls = t.walls
	building_footprints = t.building_footprints
	decor = t.decor
	regions = t.regions
	sites = t.sites
	chests = t.chests
	shrines = t.shrines
	exits = t.exits
	exit_names.clear()
	for name in t.exit_names:
		exit_names.append(name)
	sealed_exits = t.sealed_exits.duplicate()
	interior = false

func blocked(pos: Vector2, radius: float = 15.0) -> bool:
	if terrain != null:
		return terrain.blocked(pos, radius)
	return super.blocked(pos, radius)

func move(from: Vector2, velocity: Vector2, radius: float = 15.0) -> Vector2:
	if terrain != null:
		return terrain.move(from, velocity, radius)
	return super.move(from, velocity, radius)

func clear_line(a: Vector2, b: Vector2) -> bool:
	if terrain != null:
		return terrain.clear_line(a, b)
	return super.clear_line(a, b)

func biome_at(pos: Vector2) -> int:
	if terrain != null:
		return terrain.biome_at(pos)
	return super.biome_at(pos)

func region_at(pos: Vector2) -> int:
	if terrain != null:
		return terrain.region_at(pos)
	return super.biome_at(pos)

func exit_open(index: int) -> bool:
	if generated:
		return not (index in sealed_exits)
	return true
