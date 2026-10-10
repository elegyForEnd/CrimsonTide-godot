extends Node3D
## 晨钟家园 · 独立营地地图（Hearthhaven）
##
## A standalone pre-raid map. It owns its camera, its garden, its interactable
## stations and its hero/NPC billboards, and shares nothing with the raid map but
## the CC0 scene-asset library — so nothing here can move a collision rectangle
## in any expedition map.
##
## Layout convention matches the rest of the project: simulation space is 2D in
## "pixels" with 100 px = 1 m, and simulation (x, y) maps to 3D (x, 0, z).

const UNIT := 0.01
const AssetLibrary = preload("res://scripts/scene_assets.gd")
const Frames = preload("res://scripts/character_frames.gd")

const GROUND := "res://assets/home/generated/stone-path-v1.png"
const SKY := preload("res://resources/storm_sky.gdshader")
const BOLT := preload("res://resources/storm_bolt.gdshader")
const BURST := preload("res://resources/energy_burst.gdshader")

const CENTRE := Vector2(2800, 2800)
const SPAWN := Vector2(2800, 3180)
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
var architecture = preload("res://scripts/home_architecture.gd").new()
const CODEX_AT := Vector2(4140, 3960)
const SHOP_AT := Vector2(1600, 3180)
const PATHS := [Rect2(2670,2260,260,2510), Rect2(1220,2780,2890,200), Rect2(2000,2880,180,900), Rect2(1980,2270,1470,170), Rect2(2910,4120,1360,180)]
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
const Idle = preload("res://scripts/character_idle.gd")
var idle_billboards = preload("res://scripts/character_idle_billboards.gd").new()
var sprites: Array[Sprite3D] = []
var shadows: Array[MeshInstance3D] = []
var soft_blob_texture: GradientTexture2D
var used := 0
var flames: Array = []
var braziers: Array = []
var materials: Dictionary = {}
var built := false
var home_state: Dictionary = {}
var crop_layer := Node3D.new()
var crop_signature := ""
const LAKE := Rect2(3500, 1530, 1220, 980)
var SHORE := PackedVector2Array([Vector2(3500,1700),Vector2(3670,1480),Vector2(4200,1430),Vector2(4660,1610),Vector2(4800,1990),Vector2(4640,2430),Vector2(4150,2580),Vector2(3750,2530),Vector2(3460,2300),Vector2(3400,1960)])
const DOCK := Rect2(3270, 2300, 850, 180)

func garden_at(index: int) -> Vector2:
	return Vector2(1450 + (index % 3) * 240, 2060 + int(index / 3) * 240)
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
var hero_idle_time := 0.0
var hero_activity := ""
var hero_activity_progress := 0.0
var activity_frames = preload("res://scripts/home_activity_frames.gd").new()
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
	add_child(idle_billboards)
	# Two catalog models live outside models.json; register them like world_3d does.
	assets.registry["nature/tree_1"] = "res://assets/vendor/quaternius/NormalTree_1.fbx"
	assets.registry["nature/tree_3"] = "res://assets/vendor/quaternius/NormalTree_3.fbx"
	scenery.name = "Scenery"
	storm.name = "Storm"
	add_child(scenery)
	add_child(storm)
	_build_lighting()
	_build_audio()
	wind_player.volume_db = -32
	rumble_player.volume_db = -80


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
	if not Rect2(1050,1250,3900,3600).has_point(at): return false
	if Geometry2D.is_point_in_polygon(at,SHORE) and not DOCK.grow(-ACTOR_RADIUS).has_point(at): return false
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
	if Vector2(entry.node.global_position.x,entry.node.global_position.z).distance_to(hero_at*UNIT)>22.0:
		return false
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
	architecture.update()
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
	camp_camera.size = float(viewport.get_visible_rect().size.y) * UNIT * 1.6


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
	if parent != crop_layer and (mesh is BoxMesh or mesh is CylinderMesh) and mesh.get_aabb().size.y > 0.12:
		register_occluder(node)
	return node


func prop(key: String, at: Vector2, size: Vector3, tint: Color = Color.WHITE,
		foliage: Color = Color.WHITE, angle: float = 0.0, base: float = 0.0, parent: Node3D = null) -> Node3D:
	# Home props keep their authored proportions, fitting inside the requested box.
	var sample := assets.instance(key, tint, foliage)
	var source_box: AABB = assets.bounds[key]
	sample.free()
	var factor := size.y / source_box.size.y
	if size.x > 0: factor = minf(factor, size.x / source_box.size.x)
	if size.z > 0: factor = minf(factor, size.z / source_box.size.z)
	var node := assets.place(parent if parent else scenery, key, point(at, maxf(base, ground_height(at))), Vector3(0, source_box.size.y * factor, 0) * UNIT, tint, foliage, angle)
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
	architecture.site = self
	_build_home_ground()
	architecture.castle_boundary()
	_build_home_village()
	_build_gate()
	_build_forge()
	_build_depot()
	_build_codex()
	_build_garden()
	_build_lake()
	_build_stations()
	_build_hero_ring()
	hero_at = safe_position(hero_at)
	# Only the smith is kept: he is a working silhouette at the forge, while idle
	# figures standing around the war table only crowded the player's own station.
	npc_plan = [
		{"at": Vector2(3560, 3255), "hero": 2, "facing": -1.0},
	]
	for item in npc_plan:
		npc_sprites.append(_new_sprite())


func home_box(at: Vector2, size: Vector3, color: Color, height: float = 0.0, parent: Node3D = null) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size * UNIT
	return mesh_node(box, point(at, height + size.y * 0.5), material(color), parent)


func _build_home_ground() -> void:
	var ground := PlaneMesh.new()
	ground.size = Vector2(70,70)
	var grass := ShaderMaterial.new()
	grass.shader = preload("res://resources/home_ground.gdshader")
	grass.set_shader_parameter("meadow",load("res://assets/home/generated/meadow-v1.png"))
	mesh_node(ground, point(CENTRE,-4), grass)
	for path in PATHS:
		var road := home_box(path.get_center(),Vector3(path.size.x,2,path.size.y),Color("454553"))
		road.material_override = material(Color("a39bab"),load("res://assets/courtyard.png"),0.98,0.22)
	# An occupied civic square, with a clear approach to the meeting hall.
	var courtyard := home_box(Vector2(2800,3190),Vector3(1040,4,470),Color("4e4c5c"))
	courtyard.material_override = material(Color("aaa0ad"),load("res://assets/courtyard.png"),0.98,0.22)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7841
	for i in 38:
		var angle := i * TAU / 38
		var direction := Vector2.from_angle(angle)
		var distance := 1.0/maxf(absf(direction.x)/2060.0,absf(direction.y)/1940.0)
		var at := Vector2(3000,3035)+direction*distance
		if at.y > 4700 and at.x > 2350 and at.x < 3250: continue
		prop("nature/tree_1" if i % 3 else "nature/tree_3",at,Vector3(0,rng.randf_range(310,450),0),Color("aca1b4"),Color("785568"),angle)
	for at in [Vector2(1220,1630),Vector2(4560,2930),Vector2(4490,3890),Vector2(1390,4030)]:
		prop("medieval/rock_single_A",at,Vector3(160,100,140),Color("626472"))

func _build_home_village() -> void:
	_build_war_table()
	# Two rear spires frame the sanctuary, rather than rows of residential boxes.
	for at in [Vector2(2270,1570),Vector2(3070,1570)]:
		architecture.model("spire_01",at,0.18)
		obstacles.append({"at":at,"half":Vector2(65,65),"angle":0.0})
	architecture.open_station("kitchen",Vector2(2650,2060),true)
	architecture.workbench(Vector2(2650,1990),175)
	_brazier(Vector2(2860,1940),0.65)
	architecture.open_station("shop",SHOP_AT,true)
	prop("dungeon/chest",SHOP_AT+Vector2(-160,-90),Vector3(95,70,80),Color("988a85"))
	# Fountain, seats and garden edges belong to the public court, off the route.
	var court_light := OmniLight3D.new()
	court_light.position = point(Vector2(2800,3100),330)
	court_light.light_color = Color("bac5ef")
	court_light.light_energy = 0.7
	court_light.omni_range = 10.0
	scenery.add_child(court_light)
	band(Vector2(2800,3190),175,1.0,4.0,Color("91747f"),64,5)
	for at in [Vector2(2460,3350),Vector2(3130,3350),Vector2(2260,2380),Vector2(3220,2380)]:
		home_box(at,Vector3(145,24,70),Color("4d4559"))
		obstacles.append({"at":at,"half":Vector2(72.5,35),"angle":0.0})
		for i in 5:
			var rose := SphereMesh.new()
			rose.radius = 0.12
			rose.height = 0.20
			mesh_node(rose,point(at+Vector2(-50+i*25,0),35),material(Color("6f334c")))
	architecture.model("fountain",Vector2(2410,3200),0.85,0,4)
	obstacles.append({"at":Vector2(2410,3200),"half":Vector2(85,85),"angle":0.0})
	for at in [Vector2(2200,3150),Vector2(3120,3210)]:
		prop("halloween/bench_decorated",at,Vector3(140,65,65),Color("8a7985"))
	for at in [Vector2(2440,3950),Vector2(3120,4090),Vector2(2320,2360),Vector2(3150,2340),Vector2(1280,2820),Vector2(4050,2820)]:
		var stem := CylinderMesh.new()
		stem.top_radius = 0.035
		stem.bottom_radius = 0.055
		stem.height = 1.4
		mesh_node(stem,point(at,70),material(Color("292633")))
		architecture.model("chandelier_01",at,0.10,0,100)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("efb49a")
		lamp.light_energy = 0.5
		lamp.omni_range = 3.0
		lamp.position = point(at,155)
		scenery.add_child(lamp)

func _build_garden() -> void:
	crop_layer.name = "GrowingCrops"
	scenery.add_child(crop_layer)
	for i in 9:
		var at := garden_at(i)
		home_box(at,Vector3(202,12,185),Color("3d303c"))
		for side in [-1,1]:
			home_box(at+Vector2(side*102,0),Vector3(9,20,199),Color("77717e"))
			home_box(at+Vector2(0,side*95),Vector3(210,20,9),Color("77717e"))
		for row in 4:
			home_box(at+Vector2(0,-65+row*42),Vector3(182,6,8),Color("75604a"),12)
	prop("dungeon/chest",Vector2(1240,2650),Vector3(85,60,65),Color("b9ab86"))
	refresh_crops({})


func refresh_crops(state: Dictionary) -> void:
	home_state = state
	var signature := str(state.get("beds",6))
	var stages: Array = []
	for i in 9:
		var plot: Dictionary = state.get("plots",[])[i] if state.get("plots",[]).size()>i else {}
		var crop := str(plot.get("crop",""))
		var stage := 0
		if preload("res://scripts/homestead.gd").CROPS.has(crop):
			var duration: float = preload("res://scripts/homestead.gd").CROPS[crop].seconds * (0.65 if plot.get("watered",false) else 1.0)
			stage = 3 if Time.get_unix_time_from_system()-float(plot.planted)>=duration else (2 if Time.get_unix_time_from_system()-float(plot.planted)>duration*0.4 else 1)
		stages.append({"crop":crop,"stage":stage})
		signature += crop+str(stage)
	if signature==crop_signature: return
	crop_signature = signature
	for child in crop_layer.get_children():
		crop_layer.remove_child(child)
		child.queue_free()
	for i in 9:
		var stage: int = stages[i].stage
		if i>=int(state.get("beds",6)):
			for angle in [-0.55,0.55]:
				var plank := home_box(garden_at(i),Vector3(175,5,13),Color("9c8a68"),20,crop_layer)
				plank.rotation.y = angle
		if stage==0: continue
		var tint := Color(preload("res://scripts/homestead.gd").CROPS[stages[i].crop].color)
		for j in 6:
			var at := garden_at(i)+Vector2(-60+(j%3)*60,-42+int(j/3)*84)
			if stage==3:
				var plant := Sprite3D.new()
				var crop_texture: AtlasTexture = preload("res://scripts/home_art.gd").icon(str(stages[i].crop))
				plant.texture = crop_texture.atlas
				plant.region_enabled = true
				plant.region_rect = crop_texture.region
				plant.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
				plant.pixel_size = 0.0019
				plant.position = point(at,48)
				plant.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
				plant.no_depth_test = false
				crop_layer.add_child(plant)
				continue
			var stem := CylinderMesh.new()
			stem.top_radius = 0.035
			stem.bottom_radius = 0.05
			stem.height = 0.18*stage
			mesh_node(stem,point(at,16+9*stage),material(Color("739663")),crop_layer)
			var leaf := SphereMesh.new()
			leaf.radius = 0.10+stage*0.035
			leaf.height = 0.18+stage*0.075
			mesh_node(leaf,point(at,18+18*stage),material(tint if stage==3 else Color("80ad70")),crop_layer)


func _build_lake() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in Geometry2D.triangulate_polygon(SHORE):
		var at: Vector2 = SHORE[index]
		surface.set_normal(Vector3.UP)
		surface.set_uv((at-LAKE.position)/LAKE.size)
		surface.add_vertex(point(at,5))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://resources/home_water.gdshader")
	mat.set_shader_parameter("water_color",Color("192b44"))
	mesh_node(surface.commit(),Vector3.ZERO,mat).name = "MoonwaterLake"
	for i in SHORE.size():
		var start: Vector2 = SHORE[i]
		var end: Vector2 = SHORE[(i+1)%SHORE.size()]
		var count := maxi(1,int(start.distance_to(end)/100))
		for j in count:
			var at := start.lerp(end,float(j)/count)
			# Keep the footpath and the mouth of the dock open.
			if DOCK.grow(55).has_point(at): continue
			prop("medieval/rock_single_A",at,Vector3(105,38+(j%3)*12,70),Color("879783"),Color.WHITE,(end-start).angle())
	for i in 17:
		home_box(Vector2(3290+i*48,2390),Vector3(45,14,180),Color("716676"),22)
	for at in [Vector2(3300,2320),Vector2(3300,2460),Vector2(4080,2320),Vector2(4080,2460)]:
		home_box(at,Vector3(16,85,16),Color("514a5a"))

	for at in [Vector2(3530,1700),Vector2(4630,2130),Vector2(4380,2480)]:
		prop("medieval/waterplant_A",at,Vector3(0,100,0),Color("c0c79c"),Color("7da688"))


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
	sky_material.set_shader_parameter("horizon", Color("809caa"))
	sky_material.set_shader_parameter("zenith", Color("31485c"))
	sky_material.set_shader_parameter("moon_color", Color("ffe5b8"))
	sky_material.set_shader_parameter("coverage", 0.25)
	var sky_node := MeshInstance3D.new()
	sky_node.name = "Thunderhead"
	sky_node.mesh = dome
	sky_node.material_override = sky_material
	sky_node.position = Vector3(0, 40, 0)
	add_child(sky_node)

	moon = DirectionalLight3D.new()
	moon.name = "BloodMoon"
	moon.rotation_degrees = Vector3(-54, -36, 0)
	moon.light_color = Color("a3b8ee")
	moon.light_energy = 0.72
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 55.0
	add_child(moon)

	hero_lamp = OmniLight3D.new()
	hero_lamp.name = "HeroLamp"
	hero_lamp.light_color = Color("b9cdf2")
	hero_lamp.light_energy = 0.25
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
	env.ambient_light_color = Color("8795bc")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# A night storm has to stay dark: heavy fog here would wash the map to grey.
	env.fog_enabled = false
	env.fog_light_color = Color("33465c")
	env.fog_light_energy = 0.55
	env.fog_density = 0.0005
	env.glow_enabled = true
	env.glow_intensity = 0.95
	env.glow_bloom = 0.06
	env.glow_strength = 1.1
	env.glow_hdr_threshold = 0.7
	world_environment = WorldEnvironment.new()
	world_environment.environment = env
	camp_camera.environment=env
	world_environment.add_to_group("quality_environment")
	if has_node("/root/GraphicsQuality"): get_node("/root/GraphicsQuality").configure(env)
	add_child(world_environment)


func _build_war_table() -> void:
	# An open nave court: rose window backdrop, arcades and a usable council table.
	architecture.open_station("council",CENTRE)
	architecture.model("wall_rose_window_01",CENTRE+Vector2(0,-240),0.28)
	obstacles.append({"at":CENTRE+Vector2(0,-240),"half":Vector2(112,20),"angle":0.0})
	for side in [-1,1]:
		architecture.model("doorway_inner_01",CENTRE+Vector2(side*235,-220),0.22)
		for edge in [-1,1]:
			obstacles.append({"at":CENTRE+Vector2(side*235+edge*74,-220),"half":Vector2(14,25),"angle":0.0})
	var table: Node3D = architecture.workbench(CENTRE,210)
	table.name = "WarChart"
	for side in [-1,1]:
		prop("dungeon/chair",CENTRE+Vector2(side*160,0),Vector3(70,85,70),Color("ceb595"),Color.WHITE,side*PI/2)
	# Quiet parchment and engraved route lines, without a decorative item atlas.
	home_box(CENTRE,Vector3(140,2,70),Color("aaa0a3"),93)
	for i in 3:
		home_box(CENTRE+Vector2(0,-22+i*22),Vector3(110,1,2),Color("55536a"),95)

func _build_gate() -> void:
	var at := Vector2(2800,4420)
	for side in [-1,1]:
		architecture.model("column_small_01",at+Vector2(side*220,0),0.4)
		obstacles.append({"at":at+Vector2(side*220,0),"half":Vector2(35,35),"angle":0.0})
		prop("dungeon/banner_red",at+Vector2(side*235,-20),Vector3(0,130,0),Color("bd8695"),Color.WHITE,side*PI/2,160)
	var lintel := home_box(at,Vector3(500,35,55),Color("9faaa7"),300)
	lintel.name = "DepartureLintel"
	band(at+Vector2(0,180),150,1.2,8,Color("7ec8cf"),40,4)

func _build_forge() -> void:
	var at := Vector2(3560,3150)
	architecture.open_station("forge",at,true)
	var anvil_at := at+Vector2(150,-60)
	obstacles.append({"at":anvil_at,"half":Vector2(80,40),"angle":0.0})
	var stump := CylinderMesh.new()
	stump.bottom_radius = 0.36
	stump.top_radius = 0.31
	stump.height = 0.64
	mesh_node(stump,point(anvil_at,40),material(Color("665240")))
	var anvil := home_box(anvil_at,Vector3(115,36,52),Color("444c51"),72)
	anvil.name = "Anvil"
	anvil.set_meta("anvil",anvil_at)
	architecture.workbench(at+Vector2(-110,-70),175)
	_brazier(at+Vector2(200,-130),0.8)
	architecture.model("spire_01",at+Vector2(210,-145),0.11,0,420,true)

func _build_depot() -> void:
	var at := Vector2(2180,3560)
	architecture.open_station("quartermaster",at,true)
	architecture.workbench(at+Vector2(0,-90),175)
	for side in [-1,1]:
		prop("dungeon/chest",at+Vector2(side*200,-100),Vector3(90,65,70),Color("d4c09e"))
	prop("dungeon/chest",at+Vector2(-180,-30),Vector3(95,70,80),Color("a39694"))

func _build_codex() -> void:
	architecture.house("library",CODEX_AT)
	prop("dungeon/shelf_small_candles",CODEX_AT+Vector2(-190,-80),Vector3(150,120,80),Color("ddc8a8"))
	architecture.workbench(CODEX_AT+Vector2(70,-80),175)
	prop("dungeon/chair",CODEX_AT+Vector2(70,60),Vector3(60,75,60),Color("c8b393"))

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
			"at": CENTRE, "offset": Vector2(0, 140), "radius": 250.0,
			"hint": "编队 · 换装 · 天赋", "tint": Color("ffd9a6"), "icon": "command", "action": "table"},
		{"id": STATION_FORGE, "name": "锻炉", "en": "THE FORGE", "no": "02",
			"at": Vector2(3560, 3150), "offset": Vector2(0, 90), "radius": 215.0,
			"hint": "灵契天赋 · 永久成长", "tint": Color("9fd0ff"), "icon": "forge", "action": "forge"},
		{"id": STATION_QUARTER, "name": "军需官", "en": "QUARTERMASTER", "no": "03",
			"at": Vector2(2180, 3560), "offset": Vector2(0, 90), "radius": 215.0,
			"hint": "补给 · 急救针", "tint": Color("bfeecb"), "icon": "supply", "action": "quarter"},
		{"id": STATION_CODEX, "name": "晨钟书匣", "en": "THE CODEX", "no": "04",
			"at": CODEX_AT, "offset": Vector2(0, 100), "radius": 205.0,
			"hint": "守夜手册", "tint": Color("dcc7ff"), "icon": "codex", "action": "codex"},
		{"id": STATION_GATE, "name": "搜打撤闸门", "en": "EXTRACTION", "no": "05",
			"at": Vector2(2800, 4420), "offset": Vector2(0, 230), "radius": 265.0,
			"hint": "搜打撤 · 全队出发", "tint": Color("8fe6ff"), "icon": "launch", "action": "launch"},
	]
	stations.append_array([
		{"id":"rogue_gate","name":"魔境传送门","en":"ROGUE ADVENTURE","no":"10","at":Vector2(4050,3450),"offset":Vector2.ZERO,"radius":230.0,"hint":"五层闯关 · 开局商店 · 联机合作","tint":Color("ce92ff"),"icon":"codex","action":"rogue"},
		{"id":"garden","name":"晨光菜园","en":"THE GARDEN","no":"06","at":Vector2(2030,2300),"offset":Vector2.ZERO,"radius":200.0,"hint":"播种 · 浇水 · 收获","tint":Color("a8db93"),"icon":"supply","action":"garden"},
		{"id":"fish","name":"月湾栈桥","en":"MOONWATER","no":"07","at":Vector2(3370,2390),"offset":Vector2.ZERO,"radius":170.0,"hint":"抛竿 · 精准收竿","tint":Color("80d8df"),"icon":"supply","action":"fish"},
		{"id":"kitchen","name":"炉边厨房","en":"HEARTH KITCHEN","no":"08","at":Vector2(2650,2060),"offset":Vector2(0,100),"radius":170.0,"hint":"烹饪 · 出征餐食","tint":Color("efbe87"),"icon":"forge","action":"kitchen"},
		{"id":"home_shop","name":"家园商店","en":"SEEDS & TACKLE","no":"09","at":SHOP_AT,"offset":Vector2(0,160),"radius":170.0,"hint":"种子 · 钓竿 · 出售收获","tint":Color("ead699"),"icon":"supply","action":"home_shop"},
	])
	# An upright arc makes the eastern mode entrance visible from the walking path.
	var portal_at := Vector2(4050,3450)
	var ring := TorusMesh.new()
	ring.inner_radius=0.88
	ring.outer_radius=1.06
	ring.rings=32
	ring.ring_segments=12
	var portal := mesh_node(ring,point(portal_at,115),glow_material(Color("aa63ed"),1.4))
	portal.rotation.x=PI/2
	for side in [-1,1]:
		var pillar := BoxMesh.new()
		pillar.size=Vector3(.38,1.5,.48)
		mesh_node(pillar,point(portal_at+Vector2(side*118,0),75),material(Color("403752")))
		obstacles.append({"at":portal_at+Vector2(side*118,0),"half":Vector2(19,24),"angle":0.0})
	for station in stations:
		var node := Node3D.new()
		node.name = "Station_"+str(station.id)
		node.position = point(station.at+station.offset)
		scenery.add_child(node)
		station["node"] = node



## Classic facilities use procedural badges; home facilities use ImageGen icons.
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
	hero_ring_material.albedo_texture = station_icon("command",Color("e6c58b"))
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
	idle_billboards.begin()
	var hero_frame: Dictionary = activity_frames.frame(hero,hero_activity,hero_activity_progress,frames.walk_height(hero)) if not hero_activity.is_empty() else {}
	if hero_frame.is_empty(): hero_frame = frames.motion_frame(hero, "run" if hero_walking else "idle", hero_phase, 0.0)
	if not hero_walking and hero_activity.is_empty():
		var weapon := Catalog.starter_index(hero)
		hero_frame=frames.held_idle_frame(hero,weapon,hero_phase/2.0)
		var side: float=float(hero_frame.get("hand_side",1.0))
		var data := Idle.geometry(hero_frame,weapon,hero_idle_time,smoothstep(0.0,.28,hero_idle_time),side)
		idle_billboards.submit(0,data,point(hero_at,ground_height(hero_at)+3),camp_camera,hero_facing,Color("f6f9ff"),soft_blob())
	else:
		submit_sprite(hero_frame.texture, hero_frame.rect, hero_frame.get("region",Rect2()), Color("f6f9ff"),
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
		var weapon := Catalog.starter_index(hero_id)
		frame=frames.held_idle_frame(hero_id,weapon,routine+slot)
		var side: float=float(frame.get("hand_side",1.0))
		var data := Idle.geometry(frame,weapon,routine+slot,1.0,side)
		idle_billboards.submit(slot+1,data,point(at,ground_height(at)+3),camp_camera,-1.0,Color("d6ddf0"),soft_blob())
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
	# Home weather is calm; the raid keeps its own storm.
	sky_material.set_shader_parameter("flash", 0.0)
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
		hero_idle_time = 0.0
	else:
		hero_idle_time += dt
		hero_phase = hero_idle_time * 2.0
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
		moon.light_energy = 0.72 + flash * 0.30


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
