extends Node2D
## The roguelike has a separate flat Canvas renderer. Render the SAME native
## spatial VFX into a transparent 3D viewport, calibrated to that field's camera.
## Story/expedition attach directly to their existing 3D worlds instead.
var field: CanvasItem
var viewport: SubViewport
var world: Node3D
var view_camera: Camera3D
var world_scale := Vector3(1,1,1)

func _ready() -> void:
	var composite := ShaderMaterial.new()
	composite.shader=preload("res://resources/weapon_vfx_composite.gdshader")
	material=composite
	viewport=SubViewport.new(); viewport.own_world_3d=true; viewport.transparent_bg=true
	viewport.size=Vector2i(1440,900)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world=Node3D.new(); viewport.add_child(world)
	view_camera=Camera3D.new(); view_camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	view_camera.near=.05; view_camera.far=200; viewport.add_child(view_camera)
	var height := Vector3(0,24,19).normalized()
	# Make projected X/Z exactly match the flat simulation map, and world Y
	# exactly match its upright sprite height. The underlying meshes stay 3D.
	world_scale=Vector3(1,1/height.z,1/height.y)
	world.scale=world_scale
	sync()

func sync() -> void:
	if viewport==null or not is_instance_valid(field): return
	visible=field.is_visible_in_tree()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	var dimensions: Vector2=field.size
	viewport.size=Vector2i(dimensions.max(Vector2.ONE))
	view_camera.size=dimensions.y*.01
	var center: Vector2=field.camera_offset()+dimensions*.5
	var focus := Vector3(center.x*.01,0,center.y*.01*world_scale.z)
	view_camera.position=focus+Vector3(0,24,19)
	view_camera.look_at(focus); view_camera.make_current()
	queue_redraw()

func socket(id: int) -> Dictionary:
	var value: Dictionary=field.weapon_effect_socket(id).duplicate(true)
	var inverse := field.get_global_transform().affine_inverse()
	for key in ["tip","grip","stroke_tip","stroke_pivot","stroke_center"]:
		if value.has(key): value[key]=inverse*Vector2(value[key])
	for key in ["charge_points", "charge_paths"]:
		if not value.has(key): continue
		if key=="charge_points":
			for i in value[key].size(): value[key][i]=inverse*Vector2(value[key][i])
		else:
			for track in value[key]:
				for i in track.size(): track[i]=inverse*Vector2(track[i])
	return value

func _draw() -> void:
	if viewport==null or not is_instance_valid(field): return
	draw_set_transform_matrix(get_global_transform().affine_inverse()*field.get_global_transform())
	draw_texture_rect(viewport.get_texture(),Rect2(Vector2.ZERO,field.size),false)
	draw_set_transform(Vector2.ZERO)
