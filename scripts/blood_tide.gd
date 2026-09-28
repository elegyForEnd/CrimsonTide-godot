extends RefCounted
## Half-resolution atmospheric pass, composited between actors and the field HUD.
## Reuses authoritative circle coordinates; no gameplay or network state of its own.
var viewport: SubViewport
var surface: ColorRect
var material: ShaderMaterial
var active := false

func setup(owner: Node) -> void:
	viewport=SubViewport.new()
	viewport.transparent_bg=true
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
	owner.add_child(viewport)
	material=ShaderMaterial.new()
	material.shader=preload("res://resources/blood_tide.gdshader")
	surface=ColorRect.new()
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface.material=material
	viewport.add_child(surface)

func update(field: Node2D) -> void:
	var size: Vector2=field.get_viewport_rect().size
	var radius: float=field.session.safe_radius()
	var center: Vector2=field.session.safe_center()
	active=field.is_visible_in_tree() and field.session.map_id=="border" and not field.map_open
	active=active and field.camera.distance_to(center)+size.length()*0.7+180.0>radius
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active: return
	var resolution := Vector2i((size * 0.5).ceil())
	if viewport.size!=resolution:
		viewport.size=resolution
		surface.size=Vector2(resolution)
	var inverse := Transform2D.IDENTITY
	inverse.origin=-field.offset
	if field.has_method("ground_transform"): inverse=field.ground_transform().affine_inverse()
	material.set_shader_parameter("world_origin",inverse.origin)
	material.set_shader_parameter("world_axis_x",inverse.x)
	material.set_shader_parameter("world_axis_y",inverse.y)
	material.set_shader_parameter("view_size",size)
	material.set_shader_parameter("safe_center",center)
	material.set_shader_parameter("safe_radius",radius)
	material.set_shader_parameter("elapsed",field.clock)

func draw(field: Node2D) -> void:
	if not active: return
	field.draw_set_transform(Vector2.ZERO)
	field.draw_texture_rect(viewport.get_texture(),field.get_viewport_rect(),false)
