extends SceneTree
## P1 rules baseline for the generated continent. Headless only; no viewport.

var checks := 0
var failures := 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var started := Time.get_ticks_msec()
	var result: Dictionary = MapGen.try_generate(20261019, {"extent": Vector2(9600, 7200)})
	check(bool(result.get("ok", false)), "generator produces a valid map")
	var t: TerrainMap = result.get("terrain", null)
	check(t != null, "terrain returned")
	if t == null:
		print("MAPGEN RULES: ", checks, " failures: ", failures)
		quit(1)
		return

	# Determinism and hash.
	var again := MapGen.generate(20261019, Vector2(9600, 7200))
	check(again.layout_hash == t.layout_hash, "same seed same layout hash")
	var other := MapGen.generate(20261020, Vector2(9600, 7200))
	check(other.layout_hash != t.layout_hash, "different seed different layout hash")
	check(t.layout_hash.length() == 64, "layout hash is sha256 hex")

	# Regions.
	check(t.regions.size() >= 45 and t.regions.size() <= 52, "region count in 45..52")
	var big := 0
	var fragments := 0
	var types := {"newbie": 0, "explore": 0, "fight": 0, "trap": 0, "high": 0}
	var area_max := 35_000_000.0 * ((9600.0 * 7200.0) / (30400.0 * 22800.0))
	for region in t.regions:
		if bool(region.fragment):
			fragments += 1
		else:
			big += 1
		check(float(region.area) <= area_max, "region area within P1 cap")
		types[str(region.type)] = int(types.get(str(region.type), 0)) + 1
		check(region.polygon.size() >= 3, "region polygon exists")
	check(big >= 35 and big <= 42, "big region count in 35..42")
	check(fragments >= 8 and fragments <= 10, "fragment count in 8..10")
	check(int(types.newbie) == 1, "exactly one newbie region")
	check(int(types.high) >= 1 and int(types.high) <= 3, "high region count in 1..3")
	check(int(types.fight) >= 3, "at least three fight regions")
	check(int(types.trap) >= 3, "at least three trap regions")

	# Water.
	var rivers := 0
	var streams := 0
	for river in t.rivers:
		if str(river.get("kind", "river")) == "river":
			rivers += 1
		else:
			streams += 1
		check(river.polygon.size() >= 4, "river polygon exists")
	check(rivers >= 1 and rivers <= 3, "river count in 1..3")
	check(streams == 0, "no thin streams")
	var min_dim := minf(t.extent.x, t.extent.y)
	for river in t.rivers:
		check(float(river.get("width", 0.0)) >= min_dim * 0.012, "river is wide enough")
	for i in t.rivers.size():
		for j in range(i + 1, t.rivers.size()):
			var a_points: PackedVector2Array = t.rivers[i].points
			var b_points: PackedVector2Array = t.rivers[j].points
			var too_close := false
			for a in a_points:
				for b in b_points:
					if a.distance_to(b) < 80.0:
						too_close = true
						break
				if too_close:
					break
			check(not too_close, "rivers never overlap")
	check(t.lakes.size() >= 2 and t.lakes.size() <= 5, "lake count in 2..5")
	check(MapShapes.loaded(), "baked water shape library loads")
	check(MapShapes.lake_count() == MapShapes.LAKE_COUNT, "50 baked lake shapes")
	check(MapShapes.river_count() == MapShapes.RIVER_COUNT, "50 baked river shapes")
	var navigable := false
	for lake in t.lakes:
		if bool(lake.get("navigable", false)):
			navigable = true
		var polygon: PackedVector2Array = lake.get("polygon", PackedVector2Array())
		check(polygon.size() >= 24, "lake silhouette is authored, not a low-poly circle")
		var nearest := 1e9
		var farthest := 0.0
		for point: Vector2 in polygon:
			var distance := point.distance_to(lake.center)
			nearest = minf(nearest, distance)
			farthest = maxf(farthest, distance)
		check(farthest / maxf(nearest, 1.0) > 1.25, "lake shoreline is irregular")
	check(navigable, "at least one navigable lake")
	check(t.docks.size() == 3, "three ferry docks")
	# Roads in this raid are dry: water and road never share a cell.
	var wet_road := false
	for road in t.roads:
		for point: Vector2 in road:
			if t.water_depth_at(point) > 0.0:
				wet_road = true
				break
		if wet_road:
			break
	check(not wet_road, "roads never overlap water")

	# Exits.
	check(t.exits.size() == 5, "five exits")
	check(t.sealed_exits.size() == 2, "two exits sealed")
	check(t.exit_names.size() == 5, "five exit names")
	var open := 0
	for i in t.exits.size():
		if not (i in t.sealed_exits):
			open += 1
	check(open == 3, "three exits open")

	# Special structures.
	check(t.shrines.size() == 3, "three shrines")
	check(not t.boss.is_empty(), "boss arena exists")
	var boss_entrances: Array = t.boss.get("entrances", [])
	check(boss_entrances.size() >= 2, "boss arena has two entrances")
	check(t.royal_city.is_empty() or t.royal_city.has("center"), "royal city record is optional but valid")
	check(t.spawn != Vector2.ZERO, "spawn exists")
	check(not t.blocked(t.spawn, 22.0), "spawn is walkable")
	check(t.city_gate != Vector2.ZERO, "city gate exists")

	# Sites/chests/roads.
	check(t.sites.size() >= 18, "at least 18 blueprint placements")
	check(t.chests.size() >= 8, "at least 8 wilderness chests")
	check(t.roads.size() >= t.regions.size() - 1, "road network covers regions")
	for site in t.sites:
		check(not t.blocked(site.p, 18.0), "site centre is walkable: " + str(site.name))
		check(site.has("region") and site.has("blueprint"), "site keeps region/blueprint metadata")
	for chest in t.chests:
		check(not t.blocked(chest.p, 18.0), "chest is walkable")

	# Query semantics.
	check(t.region_at(t.spawn) >= 0, "spawn has a region")
	check(t.biome_at(t.spawn) >= 0 and t.biome_at(t.spawn) <= 5, "biome is 0..5")
	check(not t.land_at(Vector2(-40, -40)), "outside world is not land")
	check(t.blocked(Vector2(-40, -40)), "outside world is blocked")
	var moved := t.move(t.spawn, Vector2(120, 0), 15.0)
	check(moved.distance_to(t.spawn) <= 120.5, "move never exceeds requested velocity")

	# MapWorld adapter.
	var world := MapWorld.new()
	world.generate(20261019)
	check(world.generated, "MapWorld is generated")
	check(world.extent == t.extent, "MapWorld keeps extent")
	check(world.spawn == t.spawn, "MapWorld keeps spawn")
	check(world.exits.size() == 5, "MapWorld keeps five exits")
	check(world.regions.size() == t.regions.size(), "MapWorld keeps regions")
	check(not world.blocked(world.spawn, 15.0), "MapWorld collision delegates")
	check(world.biome_at(world.spawn) >= 0 and world.biome_at(world.spawn) <= 5, "MapWorld biome is ecology biome")
	check(world.region_at(world.spawn) >= 0, "MapWorld region id")
	check(world.exit_open(t.sealed_exits[0]) == false, "MapWorld reports sealed exit")

	# Factory default + opt-in.
	var legacy := MapFactory.create(1729, {})
	check(not legacy.generated, "factory defaults to legacy")
	check(legacy.sites.size() == 18, "legacy has 18 sites")
	var generated := MapFactory.create(20261019, {"generated": true})
	check(generated.generated, "factory opt-in creates generated world")

	# Fog.
	var fog := MapFog.new()
	fog.configure(t.extent)
	check(not fog.is_revealed(t.spawn), "fog starts dark")
	fog.reveal(t.spawn, MapFog.REVEAL_RADIUS)
	check(fog.is_revealed(t.spawn), "spawn is revealed")
	check(not fog.is_revealed(t.spawn + Vector2(MapFog.REVEAL_RADIUS * 1.5, 0)), "outside radius stays dark")
	fog.refresh_names(t)
	var serialized := fog.serialize()
	var merged := MapFog.new()
	merged.configure(t.extent)
	merged.merge(serialized)
	check(merged.is_revealed(t.spawn), "fog merge keeps team reveal")

	# Validation rejects a broken map.
	var broken := MapGen.generate(20261019, Vector2(9600, 7200))
	broken.exits.clear()
	var report := MapGen.p10_validate(broken)
	check("E_EXIT_COUNT" in report.get("errors", []), "validator catches missing exits")

	# Legacy Ruins baseline.
	var fixed := Ruins.new()
	fixed.generate(1729)
	check(fixed.extent == Ruins.SIZE, "legacy extent")
	check(fixed.sites.size() == 18, "legacy 18 sites")
	check(fixed.regions.size() == 6, "legacy six regions")
	check(fixed.exits.size() == 4, "legacy four exits")
	check(fixed.exit_name(0) == "西境驿站", "legacy exit name")

	print("MAPGEN RULES: ", checks, " failures: ", failures, " ms=", Time.get_ticks_msec() - started)
	quit(1 if failures else 0)
