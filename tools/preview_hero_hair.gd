extends SceneTree

func _initialize() -> void:
	root.hide()
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var source_path := args[0] if args.size() > 0 else "res://output/hero-animation-v3/hero-0/walk/000.png"
	var image := Image.load_from_file(source_path)
	var viewport := SubViewport.new()
	viewport.size = image.get_size()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/hero_hair_motion.gdshader")
	material.set_shader_parameter("image_size", Vector2(image.get_size()))
	sprite.material = material
	viewport.add_child(sprite)
	var output := args[1] if args.size() > 1 else "res://output/hero-animation-v3/hero-0/hair-preview"
	DirAccess.make_dir_recursive_absolute(output)
	for frame in 24:
		material.set_shader_parameter("phase", TAU * float(frame) / 24.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		var error := rendered.save_png("%s/%03d.png" % [output, frame])
		if error != OK:
			push_error("Hair preview frame failed: %d" % error)
			quit(1)
			return
	print("HAIR PREVIEW: 24 frames rendered, fixed body and original texture palette")
	quit()
