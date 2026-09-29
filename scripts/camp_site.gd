extends Node3D
## 初始营地 · 雷霆要塞（The Thunderhold）
##
## A standalone pre-raid map. It owns its camera, its storm, its interactable
## stations and its hero/NPC billboards, and shares nothing with the raid map but
## the CC0 scene-asset library — so nothing here can move a collision rectangle
## in Ruins or RoyalCity.
##
## Layout convention matches the rest of the project: simulation space is 2D in
## "pixels" with 100 px = 1 m, and simulation (x, y) maps to 3D (x, 0, z).

const UNIT := 0.01
const AssetLibrary = preload("res://scripts/scene_assets.gd")
const Frames = preload("res://scripts/character_frames.gd")

const GROUND := "res://assets/world/ground-1-1.jpg"
const GROUND_FAR := "res://assets/world/ground-0-1.jpg"
const SKY := preload("res://resources/storm_sky.gdshader")
const BOLT := preload("res://resources/storm_bolt.gdshader")
const BURST := preload("res://resources/energy_burst.gdshader")

const CENTRE := Vector2(2800, 2800)
const SPAWN := Vector2(2800, 3640)
const CAMP_RADIUS := 1560.0
# The same rig the raid's presentation camera uses: 24 up / 19 back, i.e. a
# 51.7-degree pitch. Matching it means a hero is drawn exactly as tall in the camp
# as in battle, so camp art and combat art cannot drift apart.
const PITCH := 0.9025
const CAMERA_DISTANCE := 17.0

const STATION_TABLE := "table"
const STATION_FORGE := "forge"
const STATION_QUARTER := "quarter"
const STATION_CODEX := "codex"
const STATION_GATE := "gate"

var assets := AssetLibrary.new()
var frames = Frames.new()
var scenery := Node3D.new()
var storm := Node3D.new()
var camp_camera: Camera3D
var world_environment: WorldEnvironment
var sky_material: ShaderMaterial
var moon: DirectionalLight3D
var hero_lamp: OmniLight3D
var flash_light: OmniLight3D
var stations: Array = []
# Every raised surface records its footprint and top, so an actor can be planted
# on the stone it is actually standing on instead of the y=0 plane.
var plates: Array = []
var obstacles: Array = []
var occluders: Array = []
const OCCLUDER_SHADER = preload("res://resources/camp_occluder.gdshader")
const ACTOR_RADIUS := 24.0
var sprites: Array[Sprite3D] = []
var shadows: Array[MeshInstance3D] = []
var soft_blob_texture: GradientTexture2D
var used := 0
var flames: Array = []
var braziers: Array = []
var materials: Dictionary = {}
var built := false
var extras: Array = []
var npc_plan: Array = []
var npc_sprites: Array = []

# Camp roster state, owned by the screen and read here.
var hero := 0
var squad: Array = []
var hero_at := SPAWN
var site_focus := CENTRE
var hero_facing := 1.0
var hero_walking := false
var hero_phase := 0.0
# A sigil under the player, tinted by the selected hero: the camp is a character
# showcase, so the controlled figure is the one thing that always glows.
var hero_ring: MeshInstance3D
var hero_ring_material: StandardMaterial3D
var clock := 0.0
var routine := 0.0

# Storm state.
var time := 0.0
var flash := 0.0
var flash_bias := 0.0
var next_strike := 1.6
var bolts: Array = []
var strike_tally := 0
## Test hook: 0.0 freezes the current strike so a capture is deterministic.
var storm_age := 1.0
var storm_salt := 0

# Audio: every clip is generated at runtime, so the repository gains no binaries.
var audio_root: Node
var bus: Dictionary = {}
var wind_player: AudioStreamPlayer
var rumble_player: AudioStreamPlayer
var thunder_players: Array = []
var thunder_cursor := 0


func _ready() -> void:
	# Two catalog models live outside models.json; register them like world_3d does.
	assets.registry["nature/tree_1"] = "res://assets/vendor/quaternius/NormalTree_1.fbx"
	assets.registry["nature/tree_3"] = "res://assets/vendor/quaternius/NormalTree_3.fbx"
	scenery.name = "Scenery"
	storm.name = "Storm"
	add_child(scenery)
	add_child(storm)
	_build_lighting()
	_build_audio()


# ---------------------------------------------------------------- coordinates

func point(p: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(p.x * UNIT, height * UNIT, p.y * UNIT)


func project(p: Vector2) -> Vector2:
	return camp_camera.unproject_position(point(p))


func unproject(screen: Vector2) -> Vector2:
	var hit: Variant = Plane(Vector3.UP, 0).intersects_ray(
		camp_camera.project_ray_origin(screen), camp_camera.project_ray_normal(screen))
	if hit == null:
		return Vector2.ZERO
	return Vector2(hit.x, hit.z) / UNIT


## Ground-space basis for a 2D overlay, so HUD captions stay glued to the floor.
func ground_transform() -> Transform2D:
	var origin := project(Vector2.ZERO)
	return Transform2D((project(Vector2.RIGHT * 100) - origin) / 100,
		(project(Vector2.DOWN * 100) - origin) / 100, origin)


## Height of the stone under a simulation point, in simulation units (cm).
func ground_height(at: Vector2) -> float:
	var top := 0.0
	for entry in plates:
		if Geometry2D.is_point_in_polygon(at, entry.polygon):
			top = maxf(top, float(entry.top))
	return top


## Oriented footprints share the visible props' fitted size and rotation.
func is_walkable(at: Vector2) -> bool:
	for obstacle in obstacles:
		var local: Vector2 = (at - obstacle.at).rotated(-float(obstacle.angle))
		var half: Vector2 = obstacle.half
		var nearest := local.clamp(-half, half)
		if local.distance_squared_to(nearest) < ACTOR_RADIUS * ACTOR_RADIUS:
			return false
	return true


func safe_position(at: Vector2) -> Vector2:
	if is_walkable(at):
		return at
	for radius in range(32, 1025, 16):
		for i in 32:
			var candidate := at + Vector2.from_angle(PI * 0.5 + i * TAU / 32) * radius
			if is_walkable(candidate):
				return candidate
	return SPAWN


func move_actor(at: Vector2, displacement: Vector2) -> Vector2:
	# Substeps prevent a sprint or a long frame from tunnelling through a wall.
	var steps := maxi(1, ceili(displacement.length() / 10.0))
	var step := displacement / steps
	for i in steps:
		var candidate := at + step
		if is_walkable(candidate):
			at = candidate
		else:
			if is_walkable(at + Vector2(step.x, 0)):
				at.x += step.x
			if is_walkable(at + Vector2(0, step.y)):
				at.y += step.y
	return at


## Keep original materials intact: catalog instances share their materials.
func register_occluder(node: Node3D) -> void:
	var parts: Array = []
	for mesh in assets.meshes(node):
		var originals: Array = []
		for surface in mesh.mesh.get_surface_count():
			originals.append(mesh.get_active_material(surface))
		parts.append({"mesh": mesh, "box": mesh.get_aabb(), "materials": originals,
			"faded": [], "override": mesh.material_override})
	if not parts.is_empty():
		occluders.append({"node": node, "parts": parts, "opacity": 1.0})


func occludes_actor(entry: Dictionary) -> bool:
	var feet := point(hero_at, ground_height(hero_at) + 6)
	var projection := maxf(0.1, camp_camera.global_basis.y.dot(Vector3.UP))
	# Sample feet, torso and head, including the two sides of the silhouette.
	for offset in [Vector2(0, 12), Vector2(0, 38), Vector2(0, 66), Vector2(-20, 38), Vector2(20, 38)]:
		var target := feet + Vector3(offset.x * UNIT, offset.y * UNIT / projection, 0)
		var origin := target + camp_camera.global_basis.z * 100.0
		for part in entry.parts:
			var inverse: Transform3D = part.mesh.global_transform.affine_inverse()
			if part.box.intersects_segment(inverse * origin, inverse * target) != null:
				return true
	return false


func update_occlusion(dt: float) -> void:
	for entry in occluders:
		var target := 0.25 if occludes_actor(entry) else 1.0
		var opacity := move_toward(float(entry.opacity), target, dt * 4.0)
		if is_equal_approx(opacity, float(entry.opacity)):
			continue
		entry.opacity = opacity
		for part in entry.parts:
			var mesh: MeshInstance3D = part.mesh
			if opacity >= 1.0:
				mesh.material_override = part.override
				for surface in part.materials.size():
					mesh.set_surface_override_material(surface, part.materials[surface])
				continue
			if part.faded.is_empty():
				for original in part.materials:
					var faded: Material = original.duplicate()
					if faded is ShaderMaterial:
						faded.shader = OCCLUDER_SHADER
					elif faded is StandardMaterial3D:
						faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					part.faded.append(faded)
			mesh.material_override = null
			for surface in part.faded.size():
				var faded: Material = part.faded[surface]
				if faded is ShaderMaterial:
					faded.set_shader_parameter("occlusion_opacity", opacity)
				elif faded is StandardMaterial3D:
					faded.albedo_color.a = opacity
				mesh.set_surface_override_material(surface, faded)


func camera_focus() -> Vector2:
	return Vector2(camp_camera.position.x, camp_camera.position.z) / UNIT


## Orthographic height in metres: the full design height stays visible at every
## window aspect, exactly like the raid map's presentation camera.
func sync_viewport() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	camp_camera.size = float(viewport.get_visible_rect().size.y) * UNIT


func set_camera_focus(at: Vector2, instant: bool = false) -> void:
	var target := point(at)
	# A fixed rig: the camera keeps its own yaw and pitch and only translates, so
	# WASD directions and the size of the orthographic box never change.
	camp_camera.position = Vector3(target.x, CAMERA_DISTANCE * sin(PITCH), target.z + CAMERA_DISTANCE * cos(PITCH))
	camp_camera.rotation = Vector3(-PITCH, 0.0, 0.0)


# ------------------------------------------------------------------ materials

## Camp surfaces are lit much darker than the raid map's, so every textured
## material carries a real albedo tint instead of a nominal one the texture
## would otherwise override.
func material(color: Color, texture: Texture2D = null, rough: float = 0.92,
		uv_scale: float = 2.6) -> StandardMaterial3D:
	var key := str(color) + ":" + str(texture.get_instance_id() if texture else 0) + ":" + str(rough) + ":" + str(uv_scale)
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = texture
	if texture:
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * uv_scale
	mat.roughness = rough
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[key] = mat
	return mat


func glow_material(color: Color, energy: float = 2.4) -> StandardMaterial3D:
	var key := "glow:" + str(color) + ":" + str(energy)
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.35
	materials[key] = mat
	return mat


func mesh_node(mesh: Mesh, at: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	(parent if parent else scenery).add_child(node)
	if (mesh is BoxMesh or mesh is CylinderMesh) and mesh.get_aabb().size.y > 0.12:
		register_occluder(node)
	return node


func prop(key: String, at: Vector2, size: Vector3, tint: Color = Color.WHITE,
		foliage: Color = Color.WHITE, angle: float = 0.0, base: float = 0.0, parent: Node3D = null) -> Node3D:
	var node := assets.place(parent if parent else scenery, key, point(at, maxf(base, ground_height(at))), size * UNIT, tint, foliage, angle)
	# Floors and overhead arches remain traversable; columns block their supports.
	if not ("floor" in key or "arch" in key or "waterplant" in key or "tree" in key or "torch" in key or "banner" in key):
		var fitted: Vector3 = node.get_meta("fitted_size") / UNIT
		obstacles.append({"at": at, "half": Vector2(fitted.x, fitted.z) * 0.5, "angle": -angle})
	if "floor" not in key and "waterplant" not in key:
		register_occluder(node)
	return node


# ------------------------------------------------------------------ primitives

func pad(points: PackedVector2Array, height: float, color: Color, base: float = 0.0,
		textured: bool = false) -> void:
	if base > 0.0:
		prism(points, base, color.darkened(0.34))
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(point(points[index], base + height))
	mesh_node(surface.commit(), Vector3.ZERO,
		material(color, load(GROUND) if textured else null, 0.95, 0.5))


func prism(points: PackedVector2Array, height: float, color: Color) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var a := point(points[i])
		var b := point(points[(i + 1) % points.size()])
		var c := b + Vector3.UP * height * UNIT
		var d := a + Vector3.UP * height * UNIT
		for vertex in [a, b, c, a, c, d]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	mesh_node(surface.commit(), Vector3.ZERO, material(color.darkened(0.18)))


func band(centre: Vector2, radius: float, height: float, thickness: float, color: Color,
		segments: int = 44, base: float = 0.0) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var dir := Vector2.from_angle(i * TAU / segments)
		outer.append(centre + dir * radius)
		inner.append(centre + dir * maxf(4.0, radius - thickness))
	# Build only the annulus; a filled disc would paint over the walkable floor.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a := point(inner[i], base + height)
		var b := point(outer[i], base + height)
		var c := point(outer[(i + 1) % segments], base + height)
		var d := point(inner[(i + 1) % segments], base + height)
		for vertex in [a, b, c, a, c, d]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	mesh_node(surface.commit(), Vector3.ZERO, material(color.darkened(0.3)))


## Chamfered rectangular plate: the stronghold never reads as a plain box.
func plate(centre: Vector2, half: Vector2, color: Color, thickness: float = 26.0) -> void:
	var cut := minf(half.x, half.y) * 0.30
	var points := PackedVector2Array([
		centre + Vector2(-half.x + cut, -half.y), centre + Vector2(half.x - cut, -half.y),
		centre + Vector2(half.x, -half.y + cut), centre + Vector2(half.x, half.y - cut),
		centre + Vector2(half.x - cut, half.y), centre + Vector2(-half.x + cut, half.y),
		centre + Vector2(-half.x, half.y - cut), centre + Vector2(-half.x, -half.y + cut)])
	plates.append({"polygon": points, "top": 24.0 + thickness})
	pad(points, thickness, color, 24.0, true)


# ---------------------------------------------------------------------- build

func build() -> void:
	if built:
		return
	built = true
	_harvest()
	_build_ground()
	_build_stronghold()
	_build_gate()
	_build_tents()
	_build_forge()
	_build_depot()
	_build_codex()
	_build_scatter()
	_build_signal_fire()
	_build_stations()
	_build_rain()
	_build_hero_ring()
	hero_at = safe_position(hero_at)
	# Only the smith is kept: he is a working silhouette at the forge, while idle
	# figures standing around the war table only crowded the player's own station.
	npc_plan = [
		{"at": Vector2(3560, 3255), "hero": 2, "facing": -1.0},
	]
	for item in npc_plan:
		npc_sprites.append(_new_sprite())


func _harvest() -> void:
	# Wall fragments and dead trees are lifted out of the real generator and
	# re-laid around the camp. The generator's own instance is never touched.
	var world := Ruins.new()
	for i in 4:
		world.generate(1337 + i * 977)
		for wall in world.walls:
			extras.append({"kind": "wall", "rect": wall})
		for item in world.decor:
			if int(item.type) == 4:
				extras.append({"kind": "dead_tree", "at": item.p, "size": float(item.size)})
		if extras.size() > 60:
			break


func _build_lighting() -> void:
	camp_camera = Camera3D.new()
	camp_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camp_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camp_camera.near = 0.1
	camp_camera.far = 300.0
	add_child(camp_camera)
	camp_camera.make_current()
	sync_viewport()
	if not get_viewport().size_changed.is_connected(sync_viewport):
		get_viewport().size_changed.connect(sync_viewport)
	site_focus = SPAWN - Vector2(0, 700)
	set_camera_focus(site_focus)

	var dome := SphereMesh.new()
	dome.radius = 230.0
	dome.height = 460.0
	dome.radial_segments = 48
	dome.rings = 20
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY
	var sky_node := MeshInstance3D.new()
	sky_node.name = "Thunderhead"
	sky_node.mesh = dome
	sky_node.material_override = sky_material
	sky_node.position = Vector3(0, 40, 0)
	add_child(sky_node)

	moon = DirectionalLight3D.new()
	moon.name = "BloodMoon"
	moon.rotation_degrees = Vector3(-54, -36, 0)
	moon.light_color = Color("c9b0c8")
	moon.light_energy = 0.32
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 55.0
	add_child(moon)

	hero_lamp = OmniLight3D.new()
	hero_lamp.name = "HeroLamp"
	hero_lamp.light_color = Color("b9cdf2")
	hero_lamp.light_energy = 0.9
	hero_lamp.omni_range = 6.0
	hero_lamp.shadow_enabled = false
	add_child(hero_lamp)

	flash_light = OmniLight3D.new()
	flash_light.name = "FlashLight"
	flash_light.light_color = Color("dfeaff")
	flash_light.light_energy = 0.0
	flash_light.omni_range = 140.0
	flash_light.position = Vector3(0, 28, 0)
	add_child(flash_light)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("060a11")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4a5f7d")
	env.ambient_light_energy = 0.215
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# A night storm has to stay dark: heavy fog here would wash the map to grey.
	env.fog_enabled = true
	env.fog_light_color = Color("33465c")
	env.fog_light_energy = 0.55
	env.fog_density = 0.0014
	env.glow_enabled = true
	env.glow_intensity = 0.95
	env.glow_bloom = 0.06
	env.glow_strength = 1.1
	env.glow_hdr_threshold = 0.7
	world_environment = WorldEnvironment.new()
	world_environment.environment = env
	add_child(world_environment)


func _build_ground() -> void:
	# One 14.5 m painted cobble tile per cell: a texture per tile keeps the scale
	# honest, where a single stretched plane would smear the courtyard into haze.
	var tiles := ["4a5260", "454d5b", "515866", "484f5d", "4d5564", "434a58", "4f5765", "4a5260"]
	for y in 4:
		for x in 4:
			var tile := Rect2(560 + x * 1450, 560 + y * 1450, 1450, 1450)
			var mesh := PlaneMesh.new()
			mesh.size = tile.size * UNIT
			var mat: StandardMaterial3D = material(Color(tiles[(y * 4 + x) % tiles.size()]),
				load(GROUND), 0.94).duplicate()
			mat.uv1_triplanar = false
			mat.uv1_scale = Vector3.ONE
			mesh_node(mesh, point(tile.get_center(), 0.0), mat)
	# Furrowed approach road from the departure gate to the parade ground.
	pad(PackedVector2Array([Vector2(2560, 5200), Vector2(3040, 5200), Vector2(2960, 3300), Vector2(2640, 3300)]),
		0.5, Color("3f454e"), 0.0, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9091
	# The camp sits inside a shattered crater rim; rocks break the silhouette at
	# every camera height instead of ringing it with a clean circle.
	for i in 22:
		var angle := i * TAU / 22 + rng.randf_range(-0.05, 0.05)
		var at: Vector2 = CENTRE + Vector2.from_angle(angle) * (CAMP_RADIUS + rng.randf_range(-40, 90))
		var scale := rng.randf_range(1.5, 2.9)
		prop(["medieval/rock_single_A", "medieval/rock_single_B", "dungeon/rubble_large"][i % 3],
			at, Vector3(scale * 100, scale * 90, scale * 100), Color("9aa1b2"), Color.WHITE, angle)
	for i in 30:
		var angle2 := i * TAU / 30 + 0.11
		var far: Vector2 = CENTRE + Vector2.from_angle(angle2) * (CAMP_RADIUS + rng.randf_range(430, 920))
		var tall := rng.randf_range(2.4, 5.6)
		prop("medieval/rock_single_B", far, Vector3(tall * 105, tall * 130, tall * 105),
			Color("6f7787"), Color.WHITE, angle2)
	for i in 18:
		var angle3 := i * TAU / 18 + 0.4
		var at3: Vector2 = CENTRE + Vector2.from_angle(angle3) * rng.randf_range(2150, 2480)
		prop("halloween/tree_dead_large" if i % 3 else "halloween/tree_dead_medium",
			at3, Vector3(0, rng.randf_range(250, 430), 0), Color("9fa6bb"), Color.WHITE, angle3)


func _build_stronghold() -> void:
	plate(CENTRE, Vector2(1180, 1000), Color("3a414e"), 34.0)
	band(CENTRE, 940, 2.0, 26.0, Color("4a5260"), 52, 34.0)
	band(CENTRE, 640, 2.0, 14.0, Color("424a58"), 48, 34.0)
	band(CENTRE, 320, 2.0, 12.0, Color("3d4451"), 40, 34.0)
	_build_war_table()
	# Four corner bastions with torch pillars: the camp reads as fortified.
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var at: Vector2 = CENTRE + Vector2(corner.x * 1120, corner.y * 950)
		plate(at, Vector2(210, 210), Color("3c4350"), 62.0)
		prop("dungeon/pillar_decorated", at, Vector3(120, 180, 120), Color("b8bed0"))
		prop("dungeon/torch_lit", at + Vector2(corner.x * 150, corner.y * 130), Vector3(0, 150, 0),
			Color("ecdbc6"))
		_brazier(at + Vector2(corner.x * 150, corner.y * 130), 0.9)
	# Palisade teeth across the north edge: cheap, hard, readable at a glance.
	for i in 13:
		prop("dungeon/column", Vector2(1900.0 + i * 150.0, 1780), Vector3(78, 150 + (i % 3) * 22, 78),
			Color("a3a9ba"), Color.WHITE, 0.0, 30.0)
	# Generator wall fragments as hard cover around the parade ground.
	var index := 0
	for extra in extras:
		if extra.kind != "wall":
			continue
		var wall: Rect2 = extra.rect
		var angle := (index % 12) * TAU / 12 + 0.09
		var at: Vector2 = CENTRE + Vector2.from_angle(angle) * 1420
		var length := clampf(maxf(wall.size.x, wall.size.y), 200, 430)
		prop("dungeon/wall_cracked" if index % 2 else "dungeon/wall_broken",
			at, Vector3(length, 96, 46), Color("a8aec0"), Color.WHITE, angle + PI * 0.5)
		index += 1
		if index >= 12:
			break


## The war table is the camp's landmark: a stone drum, a carved slab and a lit
## map surface the three camp figures stand around.
func _build_war_table() -> void:
	var at := CENTRE
	obstacles.append({"at": at, "half": Vector2(215, 215), "angle": 0.0})
	for i in 3:
		var drum := CylinderMesh.new()
		drum.bottom_radius = 1.55 - i * 0.06
		drum.top_radius = 1.55 - i * 0.06
		drum.height = 0.24
		drum.radial_segments = 24
		mesh_node(drum, point(at, ground_height(at) + 36 + i * 24), material(Color("5a6272"), null, 0.85))
	var slab := CylinderMesh.new()
	slab.bottom_radius = 2.15
	slab.top_radius = 2.05
	slab.height = 0.22
	slab.radial_segments = 32
	mesh_node(slab, point(at, ground_height(at) + 124), material(Color("757d8b"), load(GROUND), 0.8))
	# Lit map surface: a disc that reads as the campaign chart.
	var chart := CylinderMesh.new()
	chart.bottom_radius = 1.86
	chart.top_radius = 1.86
	chart.height = 0.05
	chart.radial_segments = 32
	var chart_node := mesh_node(chart, point(at, ground_height(at) + 150), glow_material(Color("7fd0ff"), 0.5))
	chart_node.name = "WarChart"
	var rim := CylinderMesh.new()
	rim.bottom_radius = 1.94
	rim.top_radius = 1.94
	rim.height = 0.03
	rim.radial_segments = 32
	mesh_node(rim, point(at, ground_height(at) + 118), glow_material(Color("e8c98a"), 1.6))
	for i in 4:
		var corner := Vector2.from_angle(i * TAU / 4 + PI * 0.25)
		prop("dungeon/column", at + corner * 330, Vector3(86, 190, 86), Color("b6bdd0"))
		prop("dungeon/torch_lit", at + corner * 300, Vector3(0, 150, 0), Color("e4d7c2"))
		if i % 2 == 0:
			_brazier(at + corner * 430, 0.7)
	# Benches around the drum, where the three camp figures stand.
	for i in 2:
		prop("halloween/bench_decorated", at + Vector2(0, 300 - i * 600), Vector3(0, 74, 0),
			Color("b0a9b6"), Color.WHITE, 0.0 if i == 0 else PI)
	prop("dungeon/banner_red", at + Vector2(-520, 0), Vector3(0, 145, 0), Color("ccd2e0"), Color.WHITE, PI * 0.5)
	prop("dungeon/banner_red", at + Vector2(520, 0), Vector3(0, 145, 0), Color("ccd2e0"), Color.WHITE, -PI * 0.5)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("9fd4ff")
	lamp.light_energy = 1.7
	lamp.omni_range = 6.5
	lamp.position = point(at, ground_height(at) + 210)
	scenery.add_child(lamp)
	braziers.append({"light": lamp, "energy": 1.7, "seed": 1.7})

func _build_gate() -> void:
	var at := Vector2(2800, 4420)
	plate(at, Vector2(430, 150), Color("767e8e"), 48.0)
	for side in [-1, 1]:
		var spot := at + Vector2(side * 330, 0)
		plate(spot, Vector2(95, 95), Color("c6cdde"), 96.0)
		prop("dungeon/column", spot, Vector3(120, 320, 120), Color("c0c7d8"))
		prop("dungeon/chest_gold", spot + Vector2(side * 100, -130), Vector3(0, 62, 0), Color("c6cdde"))
	# The arch itself, plus a plank causeway so the threshold is walkable-looking.
	prop("halloween/arch", at, Vector3(660, 430, 130), Color("b4bbc9"))
	for i in 8:
		prop("dungeon/floor_wood_large", Vector2(at.x - 350 + i * 100, at.y),
			Vector3(104, 16, 250), Color("9fa6b4"))
	band(at + Vector2(0, 230), 215, 1.2, 16.0, Color("7ee0ff"), 40, ground_height(at + Vector2(0, 230)) + 1.0)
	var sigil: Texture2D = load("res://assets/world/landmarks/extraction-sigil.png")
	var quad := QuadMesh.new()
	quad.size = Vector2(4.6, 4.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = sigil
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission_texture = sigil
	mat.emission = Color("8fe6ff")
	mat.emission_energy_multiplier = 2.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var node := mesh_node(quad, point(at + Vector2(0, 230), 1.8), mat)
	node.rotation.x = -PI / 2


func _build_tents() -> void:
	var plan := [
		{"at": Vector2(1880, 2280), "angle": 0.30, "tint": "c4c0cb"},
		{"at": Vector2(2360, 1900), "angle": -0.40, "tint": "b6b3bf"},
		{"at": Vector2(3300, 1980), "angle": 2.70, "tint": "bfbcc8"},
		{"at": Vector2(3760, 2380), "angle": -2.90, "tint": "b2afbb"},
		{"at": Vector2(1900, 3300), "angle": 0.62, "tint": "c8c5d0"},
		{"at": Vector2(3690, 3340), "angle": -0.58, "tint": "bab7c3"},
	]
	for item in plan:
		var at: Vector2 = item.at
		prop("medieval/tent", at, Vector3(0, 215, 0), Color(item.tint), Color.WHITE, float(item.angle))
		if item.angle > 0.0:
			_brazier(at + Vector2(0, 320), 0.75)
		prop("halloween/bench_decorated", at + Vector2(240, 190), Vector3(0, 72, 0), Color("b0a9b6"),
			Color.WHITE, float(item.angle) + 0.4)
		prop("dungeon/banner_red", at + Vector2(-200, 130), Vector3(0, 135, 0), Color("ccd2e0"),
			Color.WHITE, float(item.angle))
	# The command tent sits due west of the war table: tallest thing on the plate.
	prop("medieval/tent", Vector2(2020, 2800), Vector3(0, 265, 0), Color("bcc4d4"))
	prop("dungeon/banner_shield_red", Vector2(2020, 2530), Vector3(0, 195, 0), Color("d2d8e6"))
	for side in [-1, 1]:
		prop("dungeon/torch_lit", Vector2(2020 + side * 155, 3030), Vector3(0, 152, 0), Color("e4d7c2"))


func _build_forge() -> void:
	var at := Vector2(3560, 3150)
	plate(at, Vector2(290, 240), Color("737a86"), 54.0)
	prop("dungeon/table_long_decorated_A", at + Vector2(0, 60), Vector3(215, 98, 94), Color("b6b2bb"))
	prop("dungeon/chest_gold", at + Vector2(-220, -170), Vector3(0, 72, 0), Color("c9bea2"))
	prop("dungeon/shelf_small_candles", at + Vector2(-270, 140), Vector3(0, 98, 0), Color("c6c0c8"),
		Color.WHITE, -0.5)
	# Anvil on a stump: the one hard, unmistakable silhouette in the corner.
	var anvil_at := at + Vector2(150, 80)
	obstacles.append({"at": anvil_at, "half": Vector2(100, 36), "angle": 0.0})
	var stump := CylinderMesh.new()
	stump.bottom_radius = 0.36
	stump.top_radius = 0.31
	stump.height = 0.64
	mesh_node(stump, point(anvil_at, ground_height(anvil_at) + 32), material(Color("574f45"), null, 0.85))
	var anvil_mesh := BoxMesh.new()
	anvil_mesh.size = Vector3(1.15, 0.36, 0.52)
	var anvil := mesh_node(anvil_mesh, point(anvil_at, ground_height(anvil_at) + 82), material(Color("3d434e"), null, 0.45))
	anvil.name = "Anvil"
	anvil.set_meta("anvil", anvil_at)
	var horn := CylinderMesh.new()
	horn.bottom_radius = 0.19
	horn.top_radius = 0.03
	horn.height = 0.5
	var horn_node := mesh_node(horn, point(anvil_at, ground_height(anvil_at) + 82) + Vector3(0.78, 0, 0), material(Color("3d434e"), null, 0.45))
	horn_node.rotation.z = PI * 0.5
	_brazier(at + Vector2(215, -185), 1.3)


func _build_depot() -> void:
	var at := Vector2(2180, 3560)
	plate(at, Vector2(310, 215), Color("6f7584"), 46.0)
	prop("dungeon/table_long_decorated_A", at, Vector3(235, 94, 98), Color("b7b4bc"))
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		prop("dungeon/chest" if i % 2 else "dungeon/chest_gold",
			at + Vector2(side * (185 + (i % 3) * 65), -155 + i * 78), Vector3(0, 66, 0),
			Color("c4c9d6"), Color.WHITE, side * 0.2)
	prop("dungeon/shelf_small_candles", at + Vector2(320, 130), Vector3(0, 104, 0), Color("cbc4cb"))
	prop("halloween/lantern_standing", at + Vector2(-340, 130), Vector3(0, 172, 0), Color("ddd4d0"))
	_brazier(at + Vector2(0, 250), 0.9)


func _build_codex() -> void:
	var at := Vector2(2820, 3340)
	plate(at, Vector2(240, 175), Color("747a86"), 56.0)
	prop("halloween/crypt", at + Vector2(0, -50), Vector3(0, 310, 0), Color("b8becc"), Color.WHITE, 0.0, 56.0)
	prop("halloween/shrine_candles", at + Vector2(0, 160), Vector3(0, 132, 0), Color("ccc6cc"), Color.WHITE, 0.0, 56.0)
	for side in [-1, 1]:
		prop("halloween/lantern_standing", at + Vector2(side * 215, 150), Vector3(0, 180, 0), Color("ddd2ce"))
	var sigil: Texture2D = load("res://assets/world/landmarks/shrine-sigil.png")
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = sigil
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission_texture = sigil
	mat.emission = Color("b9dcff")
	mat.emission_energy_multiplier = 2.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node(quad, point(at + Vector2(0, -50), 250), mat).name = "CodexSigil"


func _build_scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 30:
		var angle := rng.randf_range(0, TAU)
		var at: Vector2 = CENTRE + Vector2.from_angle(angle) * rng.randf_range(1150, 1520)
		var pick := rng.randi_range(0, 3)
		if pick == 0:
			prop("halloween/gravestone", at, Vector3(0, rng.randf_range(62, 98), 0), Color("aab0bc"),
				Color.WHITE, rng.randf_range(-0.5, 0.5))
		elif pick == 1:
			prop("dungeon/rubble_large", at, Vector3(0, rng.randf_range(52, 80), 0), Color("a4aab5"),
				Color.WHITE, rng.randf_range(-1.0, 1.0))
		elif pick == 2:
			prop("medieval/waterplant_A", at, Vector3(0, rng.randf_range(70, 120), 0), Color("8fb0b8"))
		else:
			prop("dungeon/column", at, Vector3(70, rng.randf_range(90, 155), 70), Color("9ea4b1"),
				Color.WHITE, rng.randf_range(-0.4, 0.4))
	for i in 12:
		var at2: Vector2 = CENTRE + Vector2.from_angle(i * TAU / 12 + 0.2) * rng.randf_range(880, 1120)
		prop("dungeon/chest" if i % 3 else "dungeon/chest_gold", at2, Vector3(0, 58, 0),
			Color("bcc2cf"), Color.WHITE, rng.randf_range(-1.0, 1.0))
	# Dead trees harvested from the generator gather behind the tents.
	var placed := 0
	for extra in extras:
		if extra.kind != "dead_tree":
			continue
		var angle := (placed % 14) * TAU / 14 + 0.22
		var at: Vector2 = CENTRE + Vector2.from_angle(angle) * (CAMP_RADIUS + randf_range(140, 420))
		prop("halloween/tree_dead_large", at, Vector3(0, maxf(240.0, extra.size * 2.6), 0), Color("9ca2b0"))
		placed += 1


func _brazier(at: Vector2, scale: float) -> void:
	var group := Node3D.new()
	group.name = "Brazier"
	group.position = point(at, ground_height(at))
	obstacles.append({"at": at, "half": Vector2.ONE * 44 * scale, "angle": 0.0})
	scenery.add_child(group)
	var bowl := CylinderMesh.new()
	bowl.bottom_radius = 0.30 * scale
	bowl.top_radius = 0.44 * scale
	bowl.height = 0.26 * scale
	mesh_node(bowl, Vector3(0, 0.64 * scale, 0), material(Color("4b4a52"), null, 0.6), group)
	var stem := CylinderMesh.new()
	stem.bottom_radius = 0.11 * scale
	stem.top_radius = 0.09 * scale
	stem.height = 0.52 * scale
	mesh_node(stem, Vector3(0, 0.26 * scale, 0), material(Color("3d3f47"), null, 0.6), group)
	for i in 2:
		var mesh := QuadMesh.new()
		mesh.size = Vector2(1.3, 1.7) * scale * (1.0 - i * 0.3)
		var mat := ShaderMaterial.new()
		mat.shader = BURST
		mat.set_shader_parameter("form", 0)
		mat.set_shader_parameter("tint", [Color(0.55, 0.78, 1.0, 0.9), Color(0.86, 0.94, 1.0, 0.6)][i])
		mat.set_shader_parameter("life", 0.85 + i * 0.25)
		mat.set_shader_parameter("seed", randf() * 10.0)
		var node := mesh_node(mesh, Vector3(0, 1.15 * scale + i * 0.2, 0), mat, group)
		node.set_meta("flame", true)
		node.set_meta("life", 0.85 + i * 0.25)
		flames.append(node)
	var light := OmniLight3D.new()
	light.light_color = Color("9fc6ff")
	light.light_energy = 1.5 * scale
	light.omni_range = 4.6 * scale
	light.position = Vector3(0, 1.05 * scale, 0)
	group.add_child(light)
	braziers.append({"light": light, "energy": light.light_energy, "seed": randf() * 6.0})


func _build_signal_fire() -> void:
	var group := Node3D.new()
	group.name = "SignalFire"
	group.position = point(CENTRE, 34)
	scenery.add_child(group)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 9:
		var angle := i * TAU / 9 + rng.randf_range(-0.1, 0.1)
		var log := CylinderMesh.new()
		log.bottom_radius = 0.13
		log.top_radius = 0.16
		log.height = 2.7
		var node := mesh_node(log, Vector3(0, 0.72, 0), material(Color("3f332c")), group)
		node.rotation = Vector3(deg_to_rad(62), angle, 0)
	var bed := CylinderMesh.new()
	bed.bottom_radius = 1.55
	bed.top_radius = 1.55
	bed.height = 0.12
	mesh_node(bed, Vector3(0, 0.40, 0), material(Color("292521")), group)
	var tints := [Color(0.72, 0.86, 1.0, 0.85), Color(0.45, 0.66, 1.0, 0.75), Color(0.88, 0.95, 1.0, 0.6)]
	for i in 3:
		var mesh := QuadMesh.new()
		mesh.size = Vector2(4.8 - i * 1.2, 5.8 - i * 1.4)
		var mat := ShaderMaterial.new()
		mat.shader = BURST
		mat.set_shader_parameter("form", 0)
		mat.set_shader_parameter("tint", tints[i])
		mat.set_shader_parameter("life", 0.9 + i * 0.22)
		mat.set_shader_parameter("seed", 3.0 + i * 2.0)
		var node := mesh_node(mesh, Vector3(0, 3.2 + i * 0.18, 0), mat, group)
		node.set_meta("flame", true)
		node.set_meta("life", 0.9 + i * 0.22)
		node.set_meta("spin", (i - 1) * 0.35)
		flames.append(node)
	var light := OmniLight3D.new()
	light.light_color = Color("a8c8ff")
	light.light_energy = 3.0
	light.omni_range = 13.0
	light.position = Vector3(0, 3.1, 0)
	group.add_child(light)
	braziers.append({"light": light, "energy": light.light_energy, "seed": 2.5})
	# Sparks and smoke: the fire is never a still image.
	var sparks := GPUParticles3D.new()
	sparks.amount = 110
	sparks.lifetime = 2.4
	sparks.position = Vector3(0, 2.4, 0)
	var spark_quad := QuadMesh.new()
	spark_quad.size = Vector2(0.10, 0.10)
	var spark_surface := StandardMaterial3D.new()
	spark_surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_surface.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_surface.albedo_color = Color("cfe6ff")
	spark_surface.emission_enabled = true
	spark_surface.emission = Color("bcd8ff")
	spark_surface.emission_energy_multiplier = 3.0
	spark_surface.vertex_color_use_as_albedo = true
	spark_quad.material = spark_surface
	sparks.draw_pass_1 = spark_quad
	var spark_process := ParticleProcessMaterial.new()
	spark_process.direction = Vector3(0, 1, 0)
	spark_process.spread = 34.0
	spark_process.initial_velocity_min = 2.2
	spark_process.initial_velocity_max = 5.4
	spark_process.gravity = Vector3(0, -1.4, 0)
	spark_process.scale_min = 0.5
	spark_process.scale_max = 1.5
	spark_process.color = Color(0.82, 0.90, 1.0, 0.9)
	sparks.process_material = spark_process
	group.add_child(sparks)
	var smoke := GPUParticles3D.new()
	smoke.amount = 52
	smoke.lifetime = 5.2
	smoke.position = Vector3(0, 3.6, 0)
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(2.8, 3.6)
	var smoke_surface := StandardMaterial3D.new()
	smoke_surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_surface.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_surface.albedo_color = Color(0.34, 0.36, 0.44, 0.26)
	smoke_surface.vertex_color_use_as_albedo = true
	smoke_quad.material = smoke_surface
	smoke.draw_pass_1 = smoke_quad
	var smoke_process := ParticleProcessMaterial.new()
	smoke_process.direction = Vector3(0.4, 1, 0.2)
	smoke_process.spread = 28.0
	smoke_process.initial_velocity_min = 0.7
	smoke_process.initial_velocity_max = 1.7
	smoke_process.scale_min = 0.7
	smoke_process.scale_max = 1.9
	smoke_process.color = Color(0.36, 0.38, 0.46, 0.28)
	smoke.process_material = smoke_process
	group.add_child(smoke)


func _build_rain() -> void:
	var rain := GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 2600
	rain.lifetime = 1.15
	rain.visibility_aabb = AABB(Vector3(-42, -24, -42), Vector3(84, 70, 84))
	rain.position = Vector3(0, 28, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.78)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.72, 0.82, 1.0, 0.40)
	mat.emission_enabled = true
	mat.emission = Color(0.62, 0.74, 1.0)
	mat.emission_energy_multiplier = 0.6
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	rain.draw_pass_1 = quad
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(40, 1.0, 40)
	process.direction = Vector3(-0.10, -1, -0.04)
	process.spread = 2.5
	process.initial_velocity_min = 25.0
	process.initial_velocity_max = 35.0
	process.gravity = Vector3(-0.6, -9.0, -0.2)
	process.scale_min = 0.7
	process.scale_max = 1.6
	process.color = Color(0.74, 0.84, 1.0, 0.5)
	rain.process_material = process
	add_child(rain)


# ------------------------------------------------------------------ stations

func _build_stations() -> void:
	stations = [
		{"id": STATION_TABLE, "name": "作战会议桌", "en": "WAR TABLE", "no": "01",
			"at": Vector2(2800, 2800), "offset": Vector2(430, 0), "radius": 250.0,
			"hint": "编队 · 换装 · 天赋", "tint": Color("ffd9a6"), "icon": "command", "action": "table"},
		{"id": STATION_FORGE, "name": "锻炉", "en": "THE FORGE", "no": "02",
			"at": Vector2(3560, 3150), "offset": Vector2(150, 80), "radius": 215.0,
			"hint": "灵契天赋 · 永久成长", "tint": Color("9fd0ff"), "icon": "forge", "action": "forge"},
		{"id": STATION_QUARTER, "name": "军需官", "en": "QUARTERMASTER", "no": "03",
			"at": Vector2(2180, 3560), "offset": Vector2(0, 0), "radius": 215.0,
			"hint": "补给 · 急救针", "tint": Color("bfeecb"), "icon": "supply", "action": "quarter"},
		{"id": STATION_CODEX, "name": "晨钟书匣", "en": "THE CODEX", "no": "04",
			"at": Vector2(2820, 3340), "offset": Vector2(0, 260), "radius": 205.0,
			"hint": "守夜手册", "tint": Color("dcc7ff"), "icon": "codex", "action": "codex"},
		{"id": STATION_GATE, "name": "出征闸门", "en": "THE DEPARTURE", "no": "05",
			"at": Vector2(2800, 4420), "offset": Vector2(0, 230), "radius": 265.0,
			"hint": "全队出发", "tint": Color("8fe6ff"), "icon": "launch", "action": "launch"},
	]
	for station in stations:
		var quad := QuadMesh.new()
		quad.size = Vector2(1.95, 1.95)
		var mat := StandardMaterial3D.new()
		var icon := station_icon(str(station.icon), station.tint)
		mat.albedo_texture = icon
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission_texture = icon
		mat.emission = station.tint
		mat.emission_energy_multiplier = 2.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var node := mesh_node(quad, point(station.at + station.offset, 255), mat)
		node.name = "Station_" + str(station.id)
		station["node"] = node
		band(station.at + station.offset, float(station.radius) * 0.62, 1.6, 10.0, station.tint, 34, ground_height(station.at + station.offset) + 1.0)


## Station badges are procedural gradients, so the camp ships without new PNGs
## and every badge can be re-tinted by an icon's own colour.
func station_icon(kind: String, tint: Color) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	var gradient := Gradient.new()
	match kind:
		"forge":
			# Anvil: a hard core inside a ring.
			gradient.colors = PackedColorArray([Color(0, 0, 0, 0), tint, tint, Color(0, 0, 0, 0), tint, Color(0, 0, 0, 0)])
			gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.44, 0.52, 0.66, 0.76])
			texture.fill = GradientTexture2D.FILL_RADIAL
			texture.fill_from = Vector2(0.5, 0.5)
			texture.fill_to = Vector2(1.0, 0.5)
		"supply":
			# Crate: two stacked blocks.
			gradient.colors = PackedColorArray([Color(0, 0, 0, 0), tint, tint, Color(0, 0, 0, 0)])
			gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.56, 0.68])
			texture.fill = GradientTexture2D.FILL_SQUARE
			texture.fill_from = Vector2(0.5, 0.5)
			texture.fill_to = Vector2(1.0, 0.5)
		"codex":
			# Codex: a filled disc inside a thin ring.
			gradient.colors = PackedColorArray([tint, Color(0, 0, 0, 0), tint, tint, Color(0, 0, 0, 0), tint, Color(0, 0, 0, 0)])
			gradient.offsets = PackedFloat32Array([0.0, 0.20, 0.26, 0.46, 0.52, 0.62, 0.72])
			texture.fill = GradientTexture2D.FILL_RADIAL
			texture.fill_from = Vector2(0.5, 0.5)
			texture.fill_to = Vector2(1.0, 0.5)
		"launch":
			# Outward charge: bright core, hard edge, transparent rim.
			gradient.colors = PackedColorArray([tint, tint, Color(0, 0, 0, 0)])
			gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.92])
			texture.fill = GradientTexture2D.FILL_RADIAL
			texture.fill_from = Vector2(0.5, 0.5)
			texture.fill_to = Vector2(1.0, 0.5)
		_:
			# War table: a burning core inside a command ring.
			gradient.colors = PackedColorArray([Color(0, 0, 0, 0), tint, tint, Color(0, 0, 0, 0), tint, Color(0, 0, 0, 0)])
			gradient.offsets = PackedFloat32Array([0.0, 0.32, 0.46, 0.56, 0.72, 0.82])
			texture.fill = GradientTexture2D.FILL_RADIAL
			texture.fill_from = Vector2(0.5, 0.5)
			texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	return texture


# -------------------------------------------------------------------- sprites

func _new_sprite() -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.no_depth_test = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.pixel_size = UNIT
	add_child(sprite)
	sprite.hide()
	sprites.append(sprite)
	# A billboard otherwise floats: every actor gets a soft contact shadow on the
	# stone, which is what plants a 2D cast inside a 3D camp.
	var shadow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = soft_blob()
	mat.albedo_color = Color(0.035, 0.05, 0.08, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	shadow.mesh = quad
	shadow.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	shadow.visible = false
	add_child(shadow)
	shadows.append(shadow)
	return sprite


## The player's own sigil: an additive ring on the floor under the hero, tinted by
## the selected character and pulsing slowly, so the controlled figure is always
## the brightest thing the camera is aimed at.
func _build_hero_ring() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.9, 1.9)
	hero_ring_material = StandardMaterial3D.new()
	hero_ring_material.albedo_texture = load("res://assets/world/landmarks/extraction-sigil.png")
	hero_ring_material.albedo_color = Color(1, 1, 1, 0.45)
	hero_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hero_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hero_ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hero_ring_material.emission_enabled = true
	hero_ring_material.emission = Color.WHITE
	hero_ring_material.emission_energy_multiplier = 1.5
	hero_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = hero_ring_material
	hero_ring = MeshInstance3D.new()
	hero_ring.name = "HeroSigil"
	hero_ring.mesh = quad
	hero_ring.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(hero_ring)


## Colour the ring for the selected hero and keep it planted on the stone.
func _update_hero_ring() -> void:
	if hero_ring == null:
		return
	var tone: Color = Catalog.HEROES[clampi(hero, 0, Catalog.HEROES.size() - 1)].color
	var pulse := 0.55 + 0.18 * sin(time * 2.4)
	hero_ring_material.emission = tone
	hero_ring_material.albedo_color = Color(tone.r, tone.g, tone.b, 0.30 + pulse * 0.22)
	hero_ring_material.emission_energy_multiplier = 1.1 + pulse
	hero_ring.position = point(hero_at, ground_height(hero_at) + 4.5)
	hero_ring.scale = Vector3.ONE * (0.96 + pulse * 0.06)

## One soft radial blob, shared by every contact shadow.
func soft_blob() -> GradientTexture2D:
	if soft_blob_texture:
		return soft_blob_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0)])
	soft_blob_texture = GradientTexture2D.new()
	soft_blob_texture.gradient = gradient
	soft_blob_texture.width = 128
	soft_blob_texture.height = 128
	soft_blob_texture.fill = GradientTexture2D.FILL_RADIAL
	soft_blob_texture.fill_from = Vector2(0.5, 0.5)
	soft_blob_texture.fill_to = Vector2(1.0, 0.5)
	return soft_blob_texture


## Places one animation frame from an atlas as a depth-tested billboard.
##
## An upright quad seen from a pitched camera loses `cos(pitch)` of its height, so
## the vertical scale is divided by that projection: without it the cast reads as a
## flattened pancake on the floor. The same compensation the raid's presentation
## layer uses is applied here, which is what keeps a camp figure identical to the
## same hero in battle. `offset` keeps the authored frame centred over the anchor.
func submit_sprite(texture: Texture2D, rect: Rect2, region: Rect2, tint: Color, pose: Transform2D) -> void:
	if used == sprites.size():
		_new_sprite()
	var sprite := sprites[used]
	used += 1
	sprite.show()
	sprite.texture = texture
	sprite.region_enabled = region.size != Vector2.ZERO
	sprite.region_rect = region
	var source_size := region.size if sprite.region_enabled else texture.get_size()
	var factor := rect.size / source_size
	var vertical_projection := maxf(0.1, camp_camera.global_basis.y.dot(Vector3.UP))
	sprite.scale = Vector3(factor.x, factor.y / vertical_projection, 1)
	var centre := rect.get_center() - CharacterMetrics.FOOT_OFFSET
	sprite.offset = Vector2(centre.x / factor.x, -centre.y / factor.y)
	sprite.flip_h = pose.determinant() < 0
	if sprite.flip_h:
		sprite.offset.x = -sprite.offset.x
	var base := ground_height(pose.origin)
	sprite.position = point(pose.origin, base + 2)
	sprite.modulate = tint
	var shadow := shadows[used - 1]
	shadow.visible = true
	shadow.position = point(pose.origin, base + 3)
	shadow.scale = Vector3(0.62, 0.40, 1.0)


func begin_sprites() -> void:
	used = 0


func end_sprites() -> void:
	for i in range(used, sprites.size()):
		sprites[i].hide()
		if i < shadows.size():
			shadows[i].visible = false


## Rebuilds every billboard for this frame: the player, the working smith and one
## ally per extra squad member. The war table is deliberately left clear so the
## player's own station is not crowded by idle figures.
func refresh_sprites() -> void:
	begin_sprites()
	var hero_frame: Dictionary = frames.motion_frame(hero, "run" if hero_walking else "idle", hero_phase, 0.0)
	submit_sprite(hero_frame.texture, hero_frame.rect, Rect2(), Color("f6f9ff"),
		Transform2D(Vector2(hero_facing, 0), Vector2.DOWN, hero_at))
	for item in npc_plan:
		var npc_hero := int(item.hero)
		# The smith uses the attack row as a hammer swing, held on the impact frames
		# so he always reads as hitting something hard.
		var swing: Dictionary = frames.attack_frame(npc_hero, 1, 1 if fmod(routine, 1.1) < 0.55 else 3)
		submit_sprite(swing.texture, swing.rect, Rect2(), Color("c6d0e8"),
			Transform2D(Vector2(float(item.facing), 0), Vector2.DOWN, safe_position(item.at)))
	# Extra squad members stand in a loose line behind the table.
	var slot := 0
	for member in squad:
		if slot >= 3:
			break
		var hero_id := int(member.get("hero", 0))
		var frame: Dictionary = frames.motion_frame(hero_id, "idle", routine * 5.0 + slot, 0.0)
		var at := safe_position(Vector2(3180, 2600 + slot * 150))
		submit_sprite(frame.texture, frame.rect, Rect2(), Color("d6ddf0"), Transform2D(Vector2.LEFT, Vector2.DOWN, at))
		slot += 1
	end_sprites()
	_update_hero_ring()


# ---------------------------------------------------------------------- storm

func _build_audio() -> void:
	audio_root = Node.new()
	audio_root.name = "StormAudio"
	add_child(audio_root)
	bus["wind"] = _make_wind()
	bus["rumble"] = _make_rumble()
	bus["thunder"] = _make_thunder()
	bus["bell"] = _make_bell()
	wind_player = _looping("wind", -15.0)
	rumble_player = _looping("rumble", -19.0)
	for i in 3:
		var player := AudioStreamPlayer.new()
		player.volume_db = -8.0
		audio_root.add_child(player)
		thunder_players.append(player)


func _looping(key: String, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream: AudioStreamWAV = bus[key]
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.data.size() / 2)
	player.stream = stream
	player.volume_db = volume
	audio_root.add_child(player)
	player.play()
	return player


func _wav(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream


func _make_wind() -> AudioStreamWAV:
	var rate := 22050
	var length := rate * 6
	var samples := PackedFloat32Array()
	samples.resize(length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261
	var low := 0.0
	var lower := 0.0
	for i in length:
		var t := float(i) / rate
		var white := rng.randf_range(-1.0, 1.0)
		low = low * 0.965 + white * 0.035
		lower = lower * 0.995 + low * 0.005
		var gust := 0.55 + 0.45 * sin(t * 0.7) * sin(t * 0.23 + 1.2)
		samples[i] = (low * 22.0 + lower * 40.0) * gust * 0.6
	var fade := rate / 2
	for i in fade:
		var mix := float(i) / fade
		samples[i] = lerpf(samples[length - fade + i], samples[i], mix)
	return _wav(samples, rate)


func _make_rumble() -> AudioStreamWAV:
	var rate := 22050
	var length := rate * 5
	var samples := PackedFloat32Array()
	samples.resize(length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 811
	var low := 0.0
	for i in length:
		var t := float(i) / rate
		low = low * 0.9985 + rng.randf_range(-1.0, 1.0) * 0.0015
		samples[i] = low * 11.0 * (0.7 + 0.3 * sin(t * 0.42))
	var fade := rate / 2
	for i in fade:
		var mix := float(i) / fade
		samples[i] = lerpf(samples[length - fade + i], samples[i], mix)
	return _wav(samples, rate)


func _make_thunder() -> AudioStreamWAV:
	var rate := 22050
	var length := int(rate * 3.2)
	var samples := PackedFloat32Array()
	samples.resize(length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	var boom := 0.0
	var crack := 0.0
	for i in length:
		var t := float(i) / rate
		var white := rng.randf_range(-1.0, 1.0)
		boom = boom * 0.9992 + white * 0.0008
		crack = crack * 0.86 + white * 0.14
		var body := exp(-t * 1.05)
		var burst := exp(-t * 9.0)
		var ripple := 0.6 + 0.4 * sin(t * 17.0 + sin(t * 6.3) * 2.0)
		samples[i] = (boom * 34.0 * body + crack * 0.55 * burst * ripple) * 0.9
	return _wav(samples, rate)


func _make_bell() -> AudioStreamWAV:
	var rate := 22050
	var length := int(rate * 2.6)
	var samples := PackedFloat32Array()
	samples.resize(length)
	var partials := [1.0, 2.02, 2.98, 4.21, 5.43]
	for i in length:
		var t := float(i) / rate
		var value := 0.0
		for p in partials.size():
			value += sin(t * TAU * 176.0 * float(partials[p])) * pow(0.62, p) * exp(-t * (1.4 + p * 0.55))
		samples[i] = value * 0.34
	return _wav(samples, rate)


func play_bell() -> void:
	if not bus.has("bell"):
		return
	var player := AudioStreamPlayer.new()
	player.stream = bus["bell"]
	player.volume_db = -6.0
	audio_root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func thunder(power: float) -> void:
	if thunder_players.is_empty():
		return
	var player: AudioStreamPlayer = thunder_players[thunder_cursor % thunder_players.size()]
	thunder_cursor += 1
	player.stream = bus["thunder"]
	player.volume_db = -6.0 - (1.0 - power) * 10.0
	player.pitch_scale = 0.86 + power * 0.28
	player.play()


## Fires one strike: flash, a real cloud-to-ground channel, ground light and
## thunder. The channel is built in three dimensions, so it crosses the camera
## frame instead of lying flat on the ground.
func strike(power: float = 1.0, distance: float = 900.0) -> void:
	storm_salt += 1
	var rng := RandomNumberGenerator.new()
	var angle := randf_range(0, TAU)
	var base := camera_focus() + Vector2.from_angle(angle) * distance
	var lateral := Vector2.from_angle(angle + randf_range(-0.4, 0.4)) * distance * randf_range(0.08, 0.34)
	var top := Vector3((base.x + lateral.x) * UNIT, randf_range(1500.0, 2600.0) * UNIT, (base.y + lateral.y) * UNIT)
	var foot := Vector3(base.x * UNIT, 0.0, base.y * UNIT)
	flash = minf(3.0, flash + power * 1.5)
	flash_bias = power * 0.35
	strike_tally += 1
	if sky_material:
		sky_material.set_shader_parameter("bolt_seed", float(storm_salt))
	var bolt := {"t": 0.0, "life": 0.52, "materials": [] as Array}
	var node := Node3D.new()
	node.name = "Bolt%d" % storm_salt
	storm.add_child(node)
	var trunks := 2 + int(power * 3.0)
	for i in trunks:
		var path := _jagged(top, foot, rng, power)
		_add_shaft(node, bolt, path, 0.17 + power * 0.40)
		if i > 0:
			# Fork off a joint of the trunk, as a real channel does.
			var joint: Vector3 = path[int(path.size() * 0.55)]
			var tip := joint + Vector3(rng.randf_range(-7.0, 7.0), rng.randf_range(-6.0, 1.5),
				rng.randf_range(-7.0, 7.0))
			_add_shaft(node, bolt, _jagged(joint, tip, rng, power * 0.6), 0.09 + power * 0.20)
	bolt["node"] = node
	bolts.append(bolt)
	flash_light.light_energy = 4.2 * power
	# Ground impact: a hard light and an expanding sigil where the channel lands.
	var impact := OmniLight3D.new()
	impact.light_color = Color("d4e4ff")
	impact.light_energy = 10.0 * power
	impact.omni_range = 16.0 * power + 6.0
	impact.position = foot + Vector3(0, 1.4, 0)
	node.add_child(impact)
	bolt["impact"] = impact
	var ring_mesh := QuadMesh.new()
	ring_mesh.size = Vector2(7.0, 7.0)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_texture = load("res://assets/world/landmarks/boss-sigil.png")
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.emission_enabled = true
	ring_mat.emission = Color("bcd8ff")
	ring_mat.emission_energy_multiplier = 4.0
	var ring := MeshInstance3D.new()
	ring.name = "Impact"
	ring.mesh = ring_mesh
	ring.material_override = ring_mat
	ring.rotation.x = -PI * 0.5
	ring.position = foot + Vector3(0, 0.35, 0)
	node.add_child(ring)
	bolt["ring"] = ring
	thunder(clampf(power, 0.3, 1.0))
	if power > 0.85 and randf() < 0.5:
		play_bell()


func _add_shaft(node: Node3D, bolt: Dictionary, path: Array, width: float) -> void:
	var holder := MeshInstance3D.new()
	holder.mesh = _ribbon(path, width)
	var mat := ShaderMaterial.new()
	mat.shader = BOLT
	mat.set_shader_parameter("seed", randf() * 7.0)
	mat.set_shader_parameter("brightness", 2.6 + width * 1.5)
	mat.set_shader_parameter("life", 0.52)
	holder.material_override = mat
	node.add_child(holder)
	bolt.materials.append(mat)


## A jagged cloud-to-ground path. It sways hardest halfway down, so no two
## strikes share a silhouette.
func _jagged(from: Vector3, to: Vector3, rng: RandomNumberGenerator, power: float) -> Array:
	var points: Array = []
	var steps := 9 + int(power * 7.0)
	var span := from.distance_to(to)
	for i in range(steps + 1):
		var t := float(i) / steps
		var at: Vector3 = from.lerp(to, t)
		var sway := sin(t * PI) * span * 0.09 * (0.6 + power * 0.7)
		at.x += rng.randf_range(-1.0, 1.0) * sway
		at.z += rng.randf_range(-1.0, 1.0) * sway
		points.append(at)
	return points


## The ribbon's width axis is screen-horizontal. The camp camera never yaws, so a
## vertical curtain always faces the player: exactly what a bolt should look like.
func _ribbon(path: Array, width: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var span := maxf(1.0, float(path.size() - 1))
	for i in path.size():
		var at: Vector3 = path[i]
		var taper := 0.45 + 1.55 * (1.0 - float(i) / span)
		var half := Vector3(1.0, 0.0, 0.0) * width * taper * 0.5
		for pair in [-1.0, 1.0]:
			surface.set_uv(Vector2(0.5 + pair * 0.5, 1.0 - float(i) / span))
			surface.add_vertex(at + half * pair)
	return surface.commit()


func _process(dt: float) -> void:
	var step := minf(dt, 0.05)
	time += step
	routine += step
	_update_fire(step)
	_update_storm(step)
	_update_hero(step)
	refresh_sprites()
	update_occlusion(step)
	if wind_player and not wind_player.playing:
		wind_player.play()
	if rumble_player and not rumble_player.playing:
		rumble_player.play()


func _update_hero(dt: float) -> void:
	if hero_walking:
		hero_phase += dt * 9.0
	else:
		hero_phase = 0.0
	# The lamp rides the hero so the player is never a dark silhouette.
	hero_lamp.position = lerp(hero_lamp.position,
		point(hero_at, ground_height(hero_at) + 300.0), 0.35)
	# Framed on the hero: a fast exponential follow keeps the player centred while
	# walking, without a snap that would make the whole camp jitter.
	site_focus = site_focus.lerp(camera_focus_target(), 1.0 - exp(-dt * 11.0))
	set_camera_focus(site_focus)


func camera_focus_target() -> Vector2:
	# The player is the subject of this map: the camera is locked to the hero and
	# never slides toward a station or the fire, so the controlled character is
	# always framed dead centre.
	return hero_at


func _update_storm(dt: float) -> void:
	flash = maxf(0.0, flash - dt * 3.4)
	flash_bias = maxf(0.0, flash_bias - dt * 0.9)
	flash_light.light_energy = maxf(0.0, flash_light.light_energy - dt * 26.0)
	next_strike -= dt
	if next_strike <= 0.0:
		var power := randf_range(0.35, 1.0)
		if randf() < 0.35:
			# Distant sheet lightning: sky only, no shaft.
			flash = minf(3.0, flash + power * 1.1)
			flash_bias = power * 0.2
			next_strike = randf_range(0.35, 0.9)
		else:
			strike(power, randf_range(520.0, 1500.0))
			next_strike = randf_range(0.35, 1.1) if power > 0.8 else randf_range(1.2, 3.4)
		if randf() < 0.25:
			next_strike = randf_range(2.6, 4.6)
	if sky_material:
		sky_material.set_shader_parameter("flash", flash)
		sky_material.set_shader_parameter("flash_bias", flash_bias)
	for i in range(bolts.size() - 1, -1, -1):
		var bolt: Dictionary = bolts[i]
		bolt.t = float(bolt.t) + dt * storm_age
		for mat in bolt.materials:
			mat.set_shader_parameter("age", float(bolt.t))
		var progress := clampf(float(bolt.t) / float(bolt.life), 0.0, 1.0)
		if bolt.has("impact"):
			bolt.impact.light_energy = 10.0 * (1.0 - progress) * (1.0 - progress)
		if bolt.has("ring"):
			bolt.ring.scale = Vector3.ONE * (0.35 + progress * 2.1)
			var ring_mat: StandardMaterial3D = bolt.ring.material_override
			ring_mat.emission_energy_multiplier = 4.5 * (1.0 - progress)
		if float(bolt.t) >= float(bolt.life):
			# Detach immediately so the scene never keeps a dead strike, then free.
			storm.remove_child(bolt.node)
			bolt.node.queue_free()
			bolts.remove_at(i)
	if world_environment and world_environment.environment:
		world_environment.environment.ambient_light_energy = 0.215 + flash * 0.40
		moon.light_energy = 0.32 + flash * 0.30


func _update_fire(dt: float) -> void:
	for entry in braziers:
		var light: OmniLight3D = entry.light
		var flicker := 0.84 + 0.16 * sin(time * 11.0 + float(entry.seed)) + 0.08 * sin(time * 23.0)
		light.light_energy = float(entry.energy) * flicker
	for node in flames:
		var material: ShaderMaterial = node.material_override
		var life: float = float(node.get_meta("life", 0.8))
		material.set_shader_parameter("age", fmod(time, life))
		material.set_shader_parameter("life", life)
		# Shader quads cannot billboard themselves, and cameras do not rotate on
		# the vertical axis here, so one yaw per frame keeps every flame facing us.
		var facing := atan2(camp_camera.global_basis.z.x, camp_camera.global_basis.z.z)
		var spin := float(node.get_meta("spin", 0.0))
		node.rotation = Vector3(0, facing + spin * time, 0)


# --------------------------------------------------------------- interactivity

func station_at(p: Vector2) -> Dictionary:
	var best := {}
	var distance := INF
	for station in stations:
		var target: Vector2 = station.at + station.offset
		var d := p.distance_to(target)
		if d < float(station.radius) and d < distance:
			distance = d
			best = station
	return best


func station_by_id(id: String) -> Dictionary:
	for station in stations:
		if str(station.id) == id:
			return station
	return {}


func hero_position() -> Vector2:
	return hero_at


func force_strike(power: float = 1.0, distance: float = 900.0) -> void:
	next_strike = 1.2
	strike(power, distance)


func storm_state() -> Dictionary:
	return {"flash": flash, "bolts": bolts.size(), "strikes": strike_tally, "next": next_strike,
		"time": time}
