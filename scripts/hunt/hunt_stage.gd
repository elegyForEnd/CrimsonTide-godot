extends Node3D
## 血潮深潜 · 固定第一人称舞台
##
## 3D 引擎渲染、固定机位、满屏输出，观感压成伪 2D：没有自由镜头、没有玩家身体，
## 地区背景由少量 CC0 场景件 + 雾 + 昼夜灯光拼成。以后换成画好的 2D 背景时，
## 只要把 `HuntScreen` 的 stage 层换掉，热点坐标与规则都不用动。

const Assets = preload("res://scripts/scene_assets.gd")
const Data = preload("res://scripts/hunt/hunt_data.gd")
const Art = preload("res://scripts/hunt/hunt_art.gd")
const GROUND := {
	"street": "res://assets/world/ground-1-1.jpg",
	"forest": "res://assets/world/ground-0-1.jpg",
	"hospital": "res://assets/world/ground-2-1.jpg",
	"docks": "res://assets/world/ground-3-0.jpg",
	"institute": "res://assets/world/ground-2-2.jpg",
	"catacombs": "res://assets/world/ground-2-0.jpg",
	"square": "res://assets/world/ground-1-2.jpg",
	"altar": "res://assets/world/ground-3-2.jpg",
}
const PHASE_TINT := {
	"day": Color(0.82, 0.78, 0.70),
	"dusk": Color(0.62, 0.38, 0.30),
	"night": Color(0.25, 0.32, 0.48),
}

var assets := Assets.new()
var root: Node3D
var camera: Camera3D
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var fill: OmniLight3D
var area_id := ""
var phase := "day"
var built := false
## 正式背景（8 区 × 3 时段）到位时走「画片模式」：整屏一张 2K 背景，
## 3D 箱庭整套不生成；素材缺失才退回原来的 CC0 场景件拼装。
var painted := false
var back_layer: CanvasLayer
var back_rect: TextureRect

func _ready() -> void:
	_build_camera()

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "HuntCamera"
	camera.position = Vector3(0.0, 1.92, 7.0)
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 90.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.72, -10.0), Vector3.UP)

func build(p_area: String, p_phase: String) -> void:
	if root and is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	assets = Assets.new()
	world_env = null
	sun = null
	fill = null
	back_layer = null
	back_rect = null
	painted = false
	area_id = p_area
	phase = p_phase
	var theme := str(Data.area(p_area).get("theme", p_area))
	root = Node3D.new()
	root.name = "Stage"
	add_child(root)
	# 有正式背景就直接铺画片：背景里已经烘好机位、雾和昼夜调色，
	# 再叠 3D 箱庭只会出现两套透视打架。
	var painted_texture := Art.background(p_area, p_phase)
	if painted_texture != null:
		_build_painted(painted_texture)
		painted = true
		built = true
		if camera:
			camera.current = true
		return
	world_env = WorldEnvironment.new()
	world_env.environment = _environment(theme)
	root.add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.rotation_degrees = Vector3(-35.0, -32.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	root.add_child(sun)
	fill = OmniLight3D.new()
	fill.name = "FillLight"
	fill.position = Vector3(0.0, 3.2, 1.5)
	fill.omni_range = 14.0
	fill.light_energy = 0.7
	root.add_child(fill)
	_build_ground(theme)
	_build_shell(theme)
	_build_backdrop(theme)
	_build_props(theme)
	_build_foreground(theme)
	apply_phase(p_phase)
	if camera:
		camera.current = true
	built = true

## 画片模式：CanvasLayer + 满屏 TextureRect。放在 SubViewport 里，
## 尺寸就是 1440×900，KEEP_ASPECT_COVERED 会把 16:9 原图左右各裁掉一点。
func _build_painted(tex: Texture2D) -> void:
	back_layer = CanvasLayer.new()
	back_layer.name = "PaintedLayer"
	back_layer.layer = -10
	root.add_child(back_layer)
	back_rect = TextureRect.new()
	back_rect.name = "PaintedBackdrop"
	back_rect.texture = tex
	back_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_layer.add_child(back_rect)
	back_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## 箱庭外壳：三面墙（室内再加天花板）把画面封死，正面视角永远看不到地面边缘和天空接缝。
## 墙用普通 PBR 材质（不是 unshaded），所以昼夜灯光会真实地落在墙上。
func _build_shell(theme: String) -> void:
	var wall_tint := Color(0.15, 0.13, 0.13)
	match theme:
		"forest":
			wall_tint = Color(0.07, 0.10, 0.08)
		"hospital":
			wall_tint = Color(0.12, 0.15, 0.14)
		"docks":
			wall_tint = Color(0.09, 0.12, 0.15)
		"institute":
			wall_tint = Color(0.12, 0.12, 0.16)
		"catacombs":
			wall_tint = Color(0.11, 0.09, 0.10)
		"square":
			wall_tint = Color(0.15, 0.13, 0.12)
		"altar":
			wall_tint = Color(0.17, 0.08, 0.10)
	_wall(Vector3(0, 6.0, -18.0), Vector2(46, 15), wall_tint)
	_wall(Vector3(-14.0, 5.5, -8.0), Vector2(28, 13), wall_tint.darkened(0.12), 90.0)
	_wall(Vector3(14.0, 5.5, -8.0), Vector2(28, 13), wall_tint.darkened(0.12), -90.0)
	var indoor := theme in ["hospital", "institute", "catacombs", "altar"]
	if indoor:
		_wall(Vector3(0, 7.6, -8.0), Vector2(34, 30), wall_tint.darkened(0.35), 0.0, 90.0)
		_omni(Vector3(-6.0, 3.4, -6.0), Color(1.0, 0.72, 0.48), 0.55, 12.0)
		_omni(Vector3(6.0, 3.4, -8.0), Color(0.62, 0.80, 0.88), 0.40, 13.0)
	else:
		# 室外箱庭：左右各加一道低矮的残墙/树篱，挡住地面边缘的水平线。
		_box(Vector3(0.8, 2.2, 18.0), Vector3(-12.6, 1.1, -7.0), wall_tint.darkened(0.2))
		_box(Vector3(0.8, 2.2, 18.0), Vector3(12.6, 1.1, -7.0), wall_tint.darkened(0.2))

func _wall(at: Vector3, size: Vector2, colour: Color, rot_y: float = 0.0, rot_x: float = 0.0) -> void:
	var mesh := QuadMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = Vector3(rot_x, rot_y, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.96
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	root.add_child(node)

func _omni(at: Vector3, colour: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	root.add_child(light)

func _environment(p_area: String) -> Environment:
	var env := Environment.new()
	var indoor := p_area in ["hospital", "institute", "catacombs"]
	if indoor:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.035, 0.04, 0.055)
	else:
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.035, 0.045, 0.075)
		sky_mat.sky_horizon_color = Color(0.26, 0.24, 0.27)
		sky_mat.ground_horizon_color = Color(0.20, 0.18, 0.20)
		sky_mat.ground_bottom_color = Color(0.06, 0.055, 0.065)
		sky_mat.sun_angle_max = 18.0
		sky_mat.sun_curve = 0.10
		sky.sky_material = sky_mat
		env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if not indoor else Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.46, 0.55)
	env.ambient_light_energy = 0.72 if not indoor else 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.02
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.96
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.72
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.18
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.17, 0.22)
	env.fog_density = 0.014
	env.fog_height = 0.0
	env.fog_height_density = 0.0
	env.fog_sky_affect = 0.25
	if p_area in ["hospital", "institute", "catacombs"]:
		env.fog_density = 0.012
	if p_area == "altar":
		env.glow_intensity = 0.9
	return env

func _build_ground(p_area: String) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(44, 44)
	var node := MeshInstance3D.new()
	node.name = "Ground"
	node.mesh = mesh
	node.position = Vector3(0, 0, -6)
	var mat := StandardMaterial3D.new()
	var texture_path := str(GROUND.get(p_area, GROUND["street"]))
	if ResourceLoader.exists(texture_path):
		mat.albedo_texture = load(texture_path)
	mat.albedo_color = Color(0.46, 0.43, 0.40)
	mat.roughness = 0.92
	mat.uv1_scale = Vector3(9, 9, 1)
	node.material_override = mat
	root.add_child(node)

func _build_backdrop(p_area: String) -> void:
	# 箱庭外壳（`_build_shell`）已经负责封边，这里只留一条很低的远景剪影，
	# 不再放整块 backdrop——那块在正面视角里会变成一条突兀的亮带。
	if p_area in ["street", "square", "docks"]:
		var strip := MeshInstance3D.new()
		var strip_mesh := QuadMesh.new()
		strip_mesh.size = Vector2(46, 2.2)
		strip.mesh = strip_mesh
		strip.position = Vector3(0, 1.1, -16.5)
		var strip_mat := StandardMaterial3D.new()
		strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		strip_mat.albedo_color = Color(0.08, 0.075, 0.08)
		strip.material_override = strip_mat
		root.add_child(strip)

func _place(key: String, at: Vector3, size: Vector3, tint: Color = Color.WHITE, foliage: Color = Color.WHITE) -> void:
	if not root:
		return
	# The shared scene shader multiplies by tint; authored tints here are kept dark
	# for mood, then lifted just enough that silhouettes survive the night grade.
	var lifted := Color(minf(1.0, tint.r * 1.15), minf(1.0, tint.g * 1.15), minf(1.0, tint.b * 1.15), tint.a)
	var holder: Node3D = assets.place(root, key, at, size, lifted, foliage)
	# The camp's authored lighting rig is tuned for its own camera. In this fixed
	# stage the custom light() response can leave a whole building at near-black;
	# use ordinary PBR surfaces (texture kept) so silhouettes read at every phase.
	for mesh in assets.meshes(holder):
		for surface in mesh.mesh.get_surface_count():
			var base := mesh.get_active_material(surface)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = lifted
			mat.roughness = 0.94
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			var leafy := key.begins_with("nature/") or key.begins_with("halloween/tree")
			if base is ShaderMaterial:
				mat.albedo_texture = base.get_shader_parameter("atlas")
			elif base is BaseMaterial3D:
				mat.albedo_texture = base.albedo_texture
			if leafy and mat.albedo_texture != null:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold = 0.5
			mesh.set_surface_override_material(surface, mat)

func _box(size: Vector3, at: Vector3, colour: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	node.material_override = mat
	root.add_child(node)

func _build_props(p_area: String) -> void:
	match p_area:
		"street":
			_place("medieval/building_tavern_red", Vector3(-6.8, 0, -10.5), Vector3(0, 7.5, 0), Color(0.52, 0.46, 0.42))
			_place("medieval/building_market_red", Vector3(7.0, 0, -11.0), Vector3(0, 7.0, 0), Color(0.46, 0.41, 0.40))
			_place("halloween/tree_dead_large", Vector3(-3.4, 0, -8.5), Vector3(0, 5.0, 0), Color(0.32, 0.30, 0.28))
			_place("halloween/tree_dead_medium", Vector3(3.2, 0, -9.0), Vector3(0, 3.8, 0), Color(0.34, 0.31, 0.28))
			_place("dungeon/rubble_large", Vector3(0.8, 0, -6.0), Vector3(0, 1.2, 0), Color(0.32, 0.30, 0.28))
			_box(Vector3(4.8, 1.6, 2.0), Vector3(-1.4, 0.8, -7.2), Color(0.22, 0.21, 0.22))
			_box(Vector3(0.9, 2.4, 0.9), Vector3(3.6, 1.2, -6.4), Color(0.24, 0.23, 0.24))
		"forest":
			for i in 7:
				var x := -7.5 + i * 2.5
				_place("nature/tree_1" if i % 2 == 0 else "nature/tree_3", Vector3(x, 0, -8.0 - float(i % 3) * 1.2),
					Vector3(0, 6.0 + float(i % 2) * 2.0, 0), Color(0.30, 0.36, 0.29), Color(0.22, 0.30, 0.22))
			_place("halloween/tree_dead_large", Vector3(-2.0, 0, -6.5), Vector3(0, 5.5, 0), Color(0.27, 0.25, 0.23))
			_place("medieval/rock_single_A", Vector3(4.8, 0, -5.8), Vector3(0, 1.4, 0), Color(0.34, 0.35, 0.32))
			_place("medieval/rock_single_B", Vector3(-5.2, 0, -6.8), Vector3(0, 1.1, 0), Color(0.33, 0.35, 0.32))
			_place("halloween/gravestone", Vector3(1.8, 0, -11.0), Vector3(0, 2.0, 0), Color(0.33, 0.32, 0.31))
		"hospital":
			for x in [-7.5, -3.0, 3.0, 7.5]:
				_place("dungeon/wall", Vector3(x, 0, -11.0), Vector3(4.5, 5.0, 0), Color(0.42, 0.45, 0.42))
			_place("dungeon/column", Vector3(-5.5, 0, -6.0), Vector3(0, 4.5, 0), Color(0.46, 0.48, 0.44))
			_place("dungeon/column", Vector3(5.5, 0, -6.0), Vector3(0, 4.5, 0), Color(0.46, 0.48, 0.44))
			_box(Vector3(3.4, 1.1, 1.6), Vector3(-2.4, 0.55, -5.2), Color(0.32, 0.34, 0.32))
			_box(Vector3(3.4, 1.1, 1.6), Vector3(2.6, 0.55, -5.8), Color(0.30, 0.32, 0.31))
			_place("dungeon/torch_lit", Vector3(-6.8, 2.0, -9.6), Vector3(0, 1.4, 0), Color(0.7, 0.9, 0.7))
		"docks":
			var water := MeshInstance3D.new()
			var water_mesh := PlaneMesh.new()
			water_mesh.size = Vector2(42, 20)
			water.mesh = water_mesh
			water.position = Vector3(0, -0.3, -12.0)
			var water_mat := StandardMaterial3D.new()
			water_mat.albedo_color = Color(0.06, 0.12, 0.15)
			water_mat.metallic = 0.3
			water_mat.roughness = 0.25
			water.material_override = water_mat
			root.add_child(water)
			for i in 4:
				_box(Vector3(3.0, 2.2, 2.4), Vector3(-6.0 + i * 4.0, 1.1, -7.0 - float(i % 2) * 1.8), Color(0.18, 0.22, 0.26))
			_place("dungeon/column", Vector3(-5.0, 0, -4.5), Vector3(0, 5.0, 0), Color(0.26, 0.31, 0.34))
			_place("dungeon/column", Vector3(5.2, 0, -5.0), Vector3(0, 5.0, 0), Color(0.26, 0.31, 0.34))
			_place("medieval/waterplant_A", Vector3(1.2, 0, -5.6), Vector3(0, 1.2, 0), Color(0.22, 0.34, 0.29))
		"institute":
			for x in [-7.5, -3.0, 3.0, 7.5]:
				_place("dungeon/wall", Vector3(x, 0, -11.5), Vector3(4.5, 5.4, 0), Color(0.34, 0.34, 0.40))
			_place("dungeon/table_long_decorated_A", Vector3(-2.0, 0.7, -5.8), Vector3(0, 1.2, 0), Color(0.36, 0.36, 0.40))
			_place("dungeon/shelf_small_candles", Vector3(5.2, 0.5, -6.0), Vector3(0, 1.8, 0), Color(0.42, 0.39, 0.40))
			_place("dungeon/torch_lit", Vector3(-6.8, 2.2, -9.8), Vector3(0, 1.5, 0), Color(0.9, 0.40, 0.40))
			_place("dungeon/barrier", Vector3(6.5, 0, -5.0), Vector3(0, 1.6, 0), Color(0.46, 0.44, 0.48))
			_box(Vector3(1.4, 2.0, 1.4), Vector3(0.6, 1.0, -5.0), Color(0.18, 0.20, 0.24))
		"catacombs":
			for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
				_place("dungeon/wall_arched" if x == 0.0 else "dungeon/wall", Vector3(x, 0, -12.0), Vector3(4.2, 5.0, 0), Color(0.34, 0.31, 0.31))
			for x in [-6.0, -2.5, 2.5, 6.0]:
				_place("dungeon/column", Vector3(x, 0, -7.2), Vector3(0, 4.4, 0), Color(0.38, 0.34, 0.33))
			for i in 4:
				_place("halloween/gravestone", Vector3(-4.5 + i * 3.0, 0, -5.0), Vector3(0, 1.8, 0), Color(0.32, 0.29, 0.29))
			_place("halloween/shrine_candles", Vector3(0.0, 0, -9.0), Vector3(0, 2.4, 0), Color(0.75, 0.52, 0.32))
			_box(Vector3(4.2, 1.0, 2.0), Vector3(0.0, 0.5, -5.6), Color(0.25, 0.23, 0.24))
		"square":
			_place("medieval/building_tower_A_red", Vector3(-6.8, 0, -11.0), Vector3(0, 9.0, 0), Color(0.50, 0.45, 0.40))
			_place("medieval/building_church_red", Vector3(6.8, 0, -12.0), Vector3(0, 8.0, 0), Color(0.48, 0.43, 0.39))
			_place("halloween/arch", Vector3(0.0, 0, -8.5), Vector3(0, 5.2, 0), Color(0.40, 0.37, 0.35))
			_place("halloween/bench_decorated", Vector3(-4.8, 0, -5.5), Vector3(0, 1.2, 0), Color(0.34, 0.31, 0.29))
			_place("halloween/bench_decorated", Vector3(4.8, 0, -5.5), Vector3(0, 1.2, 0), Color(0.34, 0.31, 0.29))
			_place("halloween/tree_dead_large", Vector3(-5.5, 0, -7.0), Vector3(0, 5.0, 0), Color(0.28, 0.26, 0.24))
		"altar":
			_place("halloween/arch", Vector3(0.0, 0, -9.0), Vector3(0, 6.5, 0), Color(0.48, 0.28, 0.31))
			_place("halloween/crypt", Vector3(-6.5, 0, -12.0), Vector3(0, 5.0, 0), Color(0.34, 0.25, 0.28))
			_place("halloween/crypt", Vector3(6.5, 0, -12.0), Vector3(0, 5.0, 0), Color(0.34, 0.25, 0.28))
			for x in [-4.5, 0.0, 4.5]:
				_place("dungeon/column", Vector3(x, 0, -7.0), Vector3(0, 4.8, 0), Color(0.36, 0.27, 0.29))
			_place("halloween/shrine_candles", Vector3(0.0, 0, -6.5), Vector3(0, 2.8, 0), Color(0.95, 0.40, 0.40))
			_box(Vector3(5.2, 0.7, 3.2), Vector3(0.0, 0.35, -4.8), Color(0.30, 0.15, 0.18))

## 近景陈设：把箱庭的前景填起来，避免左右两侧只剩空墙。
func _build_foreground(theme: String) -> void:
	match theme:
		"street":
			_box(Vector3(0.5, 3.4, 0.5), Vector3(-8.4, 1.7, -3.0), Color(0.16, 0.15, 0.15))
			_box(Vector3(1.4, 0.5, 0.5), Vector3(-8.4, 3.4, -3.0), Color(0.30, 0.22, 0.20))
			_omni(Vector3(-8.4, 3.2, -3.0), Color(1.0, 0.72, 0.42), 0.8, 9.0)
			_place("halloween/bench_decorated", Vector3(8.2, 0, -4.2), Vector3(0, 1.2, 0), Color(0.30, 0.27, 0.25))
		"forest":
			_place("nature/tree_1", Vector3(-6.8, 0, -3.4), Vector3(0, 7.2, 0), Color(0.26, 0.32, 0.25), Color(0.18, 0.26, 0.18))
			_place("nature/tree_3", Vector3(7.2, 0, -3.8), Vector3(0, 6.4, 0), Color(0.26, 0.32, 0.25), Color(0.18, 0.26, 0.18))
			_place("medieval/rock_single_A", Vector3(5.4, 0, -3.2), Vector3(0, 1.1, 0), Color(0.30, 0.32, 0.29))
		"hospital":
			_box(Vector3(0.25, 3.2, 3.4), Vector3(-9.2, 1.6, -3.2), Color(0.24, 0.28, 0.25))
			_box(Vector3(0.25, 3.2, 3.4), Vector3(9.2, 1.6, -3.2), Color(0.24, 0.28, 0.25))
			_box(Vector3(2.4, 0.7, 1.1), Vector3(6.2, 0.35, -4.0), Color(0.30, 0.32, 0.31))
			_omni(Vector3(0, 2.8, -9.0), Color(0.70, 0.95, 0.85), 0.7, 12.0)
		"docks":
			for i in 4:
				_box(Vector3(0.5, 2.6, 0.5), Vector3(-7.4 + i * 1.6, 1.3, -2.6), Color(0.16, 0.14, 0.12))
			_box(Vector3(1.6, 1.2, 1.4), Vector3(7.6, 0.6, -4.0), Color(0.22, 0.20, 0.18))
			_omni(Vector3(0, 3.4, -5.0), Color(0.85, 0.65, 0.40), 0.6, 10.0)
		"institute":
			_box(Vector3(0.2, 3.4, 4.0), Vector3(-9.4, 1.7, -2.8), Color(0.20, 0.26, 0.28))
			_box(Vector3(0.2, 3.4, 4.0), Vector3(9.4, 1.7, -2.8), Color(0.20, 0.26, 0.28))
			_box(Vector3(2.2, 0.9, 1.0), Vector3(-7.8, 0.45, -4.2), Color(0.24, 0.26, 0.30))
			_omni(Vector3(-6.0, 3.6, -4.0), Color(0.60, 0.90, 0.95), 0.5, 9.0)
		"catacombs":
			for side in [-1, 1]:
				for i in 3:
					_box(Vector3(0.9, 1.1, 0.7), Vector3(side * 9.4, 1.2 + i * 1.1, -3.4 - i * 1.2), Color(0.13, 0.11, 0.11))
			_omni(Vector3(0, 2.6, -6.0), Color(1.0, 0.62, 0.35), 0.55, 8.0)
		"square":
			var basin := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 3.0
			cyl.bottom_radius = 3.2
			cyl.height = 0.8
			basin.mesh = cyl
			basin.position = Vector3(0, 0.4, -4.0)
			var stone := StandardMaterial3D.new()
			stone.albedo_color = Color(0.30, 0.29, 0.27)
			stone.roughness = 0.95
			basin.material_override = stone
			root.add_child(basin)
			_place("halloween/tree_dead_large", Vector3(-8.6, 0, -4.0), Vector3(0, 5.2, 0), Color(0.26, 0.24, 0.22))
		"altar":
			for i in 3:
				_box(Vector3(9.0 - i * 0.8, 0.35, 1.2), Vector3(0, 0.18 + i * 0.35, -2.4 + i * 1.2), Color(0.22, 0.16, 0.17))
			_omni(Vector3(-5.5, 2.4, -4.5), Color(1.0, 0.30, 0.30), 0.9, 9.0)
			_omni(Vector3(5.5, 2.4, -4.5), Color(1.0, 0.30, 0.30), 0.9, 9.0)

func apply_phase(p_phase: String) -> void:
	phase = p_phase
	if painted:
		if back_rect and is_instance_valid(back_rect):
			var next := Art.background(area_id, p_phase)
			if next != null:
				back_rect.texture = next
		return
	if not built:
		return
	var tint: Color = PHASE_TINT.get(p_phase, PHASE_TINT["day"])
	if world_env and world_env.environment:
		var env := world_env.environment
		env.ambient_light_color = tint * 1.15
		env.ambient_light_energy = 0.75 if p_phase == "day" else (0.48 if p_phase == "dusk" else 0.42)
		env.fog_light_color = tint * 0.55
		env.fog_density = 0.014 if p_phase == "night" else 0.010
	if sun:
		match p_phase:
			"day":
				sun.light_color = Color(1.0, 0.90, 0.76)
				sun.light_energy = 1.75
				sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
			"dusk":
				sun.light_color = Color(1.0, 0.52, 0.32)
				sun.light_energy = 1.05
				sun.rotation_degrees = Vector3(-18.0, -58.0, 0.0)
			_:
				sun.light_color = Color(0.48, 0.60, 0.90)
				sun.light_energy = 0.48
				sun.rotation_degrees = Vector3(-12.0, 22.0, 0.0)
	if fill:
		fill.light_color = tint
		fill.light_energy = 1.05 if p_phase == "day" else (0.65 if p_phase == "dusk" else 0.52)
