extends SceneTree

# Normalize the entire illustration uniformly, then bake subtle secondary motion.
func _initialize() -> void:
	root.hide()
	call_deferred("run")

func make_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1254, 1254)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 7:
		push_error("Expected input output bbox-left top right bottom phase")
		quit(1)
		return
	var source := Image.load_from_file(args[0])
	var bounds := Rect2(float(args[2]), float(args[3]), float(args[4]) - float(args[2]), float(args[5]) - float(args[3]))
	var scale_factor := 988.0 / bounds.size.y
	var viewport := make_viewport()
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(source)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * scale_factor
	# Match original body bounds center and support-foot baseline.
	sprite.position = Vector2(583.5, 1166.0) - Vector2(bounds.get_center().x, bounds.end.y) * scale_factor
	if args.size() > 7 and args[7] == "locked":
		# Later poses use the fixed first-frame canvas; changing stride width
		# must not shift the torso horizontally or rescale the head.
		sprite.scale = Vector2.ONE
		sprite.position = Vector2(0.0, 1166.0 - bounds.end.y)
	viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var normalized := viewport.get_texture().get_image()
	var hair_viewport := make_viewport()
	var hair_sprite := Sprite2D.new()
	hair_sprite.centered = false
	hair_sprite.texture = ImageTexture.create_from_image(normalized)
	hair_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/hero_hair_motion.gdshader")
	material.set_shader_parameter("image_size", Vector2(1254, 1254))
	material.set_shader_parameter("phase", float(args[6]))
	hair_sprite.material = material
	hair_viewport.add_child(hair_sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := hair_viewport.get_texture().get_image().save_png(args[1])
	print("V4 BAKE: ", args[1], " scale=", scale_factor, " error=", error)
	quit(0 if error == OK else 1)
