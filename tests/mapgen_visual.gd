extends SceneTree
## Visual audit for the generated continent. Writes to build/ (gitignored).

const W := 960
const H := 720

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var started := Time.get_ticks_msec()
	var result: Dictionary = MapGen.try_generate(20261019, {"extent": Vector2(9600, 7200)})
	if not bool(result.get("ok", false)):
		push_error("visual map generation failed")
		quit(1)
		return
	var t: TerrainMap = result.terrain
	_save_terrain(t, "build/mapgen-terrain.png")
	_save_regions(t, "build/mapgen-regions.png")
	_save_minimap(t, "build/mapgen-minimap.png")
	_save_river_plan(t, "build/mapgen-river-plan.png")
	print("MAPGEN VISUAL: ", Time.get_ticks_msec() - started, " ms")
	quit(0)

func _base_image() -> Image:
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	image.fill(Color("101820"))
	return image

func _save_terrain(t: TerrainMap, path: String) -> void:
	var image := _base_image()
	for y in H:
		for x in W:
			var at := Vector2((float(x) + 0.5) / W * t.extent.x, (float(y) + 0.5) / H * t.extent.y)
			var color := Color("15232f")
			if t.land_at(at):
				var water := t.water_depth_at(at)
				if water > 0.0:
					var depth := clampf(water / 90.0, 0.0, 1.0)
					color = Color("2c5266").lerp(Color("0d2638"), depth)
				else:
					var h := clampf(t.height_at(at) / 120.0, 0.0, 1.0)
					var d := clampf(t.danger_at(at), 0.0, 1.0)
					color = Color("5c6f58").lerp(Color("a6a17c"), h)
					color = color.lerp(Color("7c343d"), d * 0.55)
			image.set_pixel(x, y, color)
	_draw_roads(image, t, Color(0.78, 0.70, 0.50, 0.55))
	for exit in t.exits:
		_dot(image, t, exit, Color("8ff0d0"), 5)
	for site in t.sites:
		_dot(image, t, site.p, Color("ead6a6"), 3)
	_dot(image, t, t.spawn, Color("ffffff"), 6)
	_dot(image, t, t.boss.get("center", Vector2.ZERO), Color("ff7b8c"), 7)
	image.save_png(path)

func _save_regions(t: TerrainMap, path: String) -> void:
	var image := _base_image()
	for y in H:
		for x in W:
			var at := Vector2((float(x) + 0.5) / W * t.extent.x, (float(y) + 0.5) / H * t.extent.y)
			var color := Color("15232f")
			if t.land_at(at):
				if t.water_depth_at(at) > 0.0:
					color = Color("244a5c")
				else:
					var region := t.region_at(at)
					if region >= 0 and region < t.regions.size():
						color = _region_color(str(t.regions[region].type))
					else:
						color = Color("3b4148")
			image.set_pixel(x, y, color)
	_draw_roads(image, t, Color(0.80, 0.75, 0.60, 0.35))
	for region in t.regions:
		_dot(image, t, region.center, Color("f3e6cd"), 3)
	image.save_png(path)

func _save_minimap(t: TerrainMap, path: String) -> void:
	var fog := MapFog.new()
	fog.configure(t.extent)
	fog.reveal(t.spawn, MapFog.REVEAL_RADIUS)
	fog.reveal(t.boss.get("center", Vector2.ZERO), MapFog.REVEAL_RADIUS)
	for site in t.sites:
		fog.reveal(site.p, MapFog.REVEAL_RADIUS * 0.55)
	var image := _base_image()
	for y in H:
		for x in W:
			var at := Vector2((float(x) + 0.5) / W * t.extent.x, (float(y) + 0.5) / H * t.extent.y)
			var color := Color("0d151d")
			if t.land_at(at):
				if t.water_depth_at(at) > 0.0:
					color = Color("2c5266")
				else:
					color = Color("64705c")
					var region := t.region_at(at)
					if region >= 0 and region < t.regions.size():
						color = color.lerp(_region_color(str(t.regions[region].type)), 0.22)
			if not fog.is_revealed(at):
				color = color.lerp(Color("05080c"), 0.82)
			image.set_pixel(x, y, color)
	_draw_roads(image, t, Color(0.78, 0.70, 0.50, 0.40))
	for site in t.sites:
		if fog.is_revealed(site.p):
			_dot(image, t, site.p, Color("ead6a6"), 3)
	for exit in t.exits:
		if fog.is_revealed(exit):
			_dot(image, t, exit, Color("8ff0d0"), 5)
	_dot(image, t, t.spawn, Color("ffffff"), 6)
	_dot(image, t, t.boss.get("center", Vector2.ZERO), Color("ff7b8c"), 7)
	image.save_png(path)

func _save_river_plan(t: TerrainMap, path: String) -> void:
	if t.rivers.is_empty():
		return
	var points: PackedVector2Array = t.rivers[0].get("points", PackedVector2Array())
	if points.size() < 8:
		return
	var best := points[points.size() / 2]
	var best_score := -INF
	for point: Vector2 in points:
		var lake_gap := INF
		for lake in t.lakes:
			lake_gap = minf(lake_gap, point.distance_to(lake.center) - float(lake.radius))
		var site_gap := INF
		for site in t.sites:
			site_gap = minf(site_gap, point.distance_to(site.p))
		var bridge_gap := INF
		for bridge: Rect2 in t.bridges:
			bridge_gap = minf(bridge_gap, _plan_rect_gap(bridge, point))
		var score := minf(lake_gap, 900.0) + minf(site_gap, 900.0) * 0.8 + minf(bridge_gap, 900.0)
		if score > best_score:
			best_score = score
			best = point
	var span := 2.5
	var origin := best - Vector2(W, H) * span * 0.5
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var at := origin + Vector2(x + 0.5, y + 0.5) * span
			var color := Color("131d26")
			if t.land_at(at):
				var water := t.water_depth_at(at)
				if water > 0.0:
					var depth := clampf(water / 90.0, 0.0, 1.0)
					color = Color("3d8894").lerp(Color("0d2638"), depth)
				else:
					var h := clampf(t.height_at(at) / 120.0, 0.0, 1.0)
					color = Color("5c6f58").lerp(Color("a6a17c"), h)
					color = color.lerp(Color("7c343d"), clampf(t.danger_at(at), 0.0, 1.0) * 0.35)
			image.set_pixel(x, y, color)
	for bridge: Rect2 in t.bridges:
		var x0 := int((bridge.position.x - origin.x) / span)
		var y0 := int((bridge.position.y - origin.y) / span)
		var x1 := int((bridge.end.x - origin.x) / span)
		var y1 := int((bridge.end.y - origin.y) / span)
		for x in range(maxi(0, x0), mini(W - 1, x1) + 1):
			for y in [y0, y1]:
				if y >= 0 and y < H:
					image.set_pixel(x, y, Color("b79a74"))
		for y in range(maxi(0, y0), mini(H - 1, y1) + 1):
			for x in [x0, x1]:
				if x >= 0 and x < W:
					image.set_pixel(x, y, Color("b79a74"))
	for road in t.roads:
		var line: PackedVector2Array = road
		for i in range(line.size() - 1):
			_plan_line(image, origin, span, line[i], line[i + 1], Color(0.82, 0.75, 0.58, 0.9), 2)
	image.save_png(path)

func _plan_rect_gap(rect: Rect2, at: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - at.x, 0.0), at.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - at.y, 0.0), at.y - rect.end.y)
	return Vector2(dx, dy).length()

func _plan_line(image: Image, origin: Vector2, span: float, a: Vector2, b: Vector2, color: Color, width: int) -> void:
	var pa := (a - origin) / span
	var pb := (b - origin) / span
	var steps := maxi(1, int(pa.distance_to(pb)))
	for i in range(steps + 1):
		var p := pa.lerp(pb, float(i) / steps)
		for dy in range(-width, width + 1):
			for dx in range(-width, width + 1):
				if dx * dx + dy * dy > width * width:
					continue
				var x := int(p.x) + dx
				var y := int(p.y) + dy
				if x >= 0 and y >= 0 and x < W and y < H:
					image.set_pixel(x, y, color)

func _region_color(type: String) -> Color:
	match type:
		"newbie":
			return Color("6f9a6c")
		"fight":
			return Color("a86b4f")
		"trap":
			return Color("7e5fa0")
		"high":
			return Color("7e3f4a")
		_:
			return Color("8b8b6e")

func _draw_roads(image: Image, t: TerrainMap, color: Color) -> void:
	for road in t.roads:
		var points: PackedVector2Array = road
		for i in range(points.size() - 1):
			_line(image, t, points[i], points[i + 1], color, 1)

func _line(image: Image, t: TerrainMap, a: Vector2, b: Vector2, color: Color, width: int) -> void:
	var steps := maxi(1, int(a.distance_to(b) / 24.0))
	for i in range(steps + 1):
		var at := a.lerp(b, float(i) / steps)
		_dot(image, t, at, color, width)

func _dot(image: Image, t: TerrainMap, at: Vector2, color: Color, radius: int) -> void:
	var x := int(at.x / t.extent.x * W)
	var y := int(at.y / t.extent.y * H)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var px := x + dx
			var py := y + dy
			if px >= 0 and py >= 0 and px < W and py < H:
				image.set_pixel(px, py, color)
