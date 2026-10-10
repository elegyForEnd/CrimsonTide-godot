extends RefCounted
static func build(parent: Control, graphics: Node, at: Vector2) -> void:
	var box := VBoxContainer.new(); box.position=at; box.size=Vector2(640,360)
	box.add_theme_constant_override("separation",16); parent.add_child(box)
	var quality := OptionButton.new(); quality.name="GraphicsQuality"
	for text in ["高画质 · 体积雾 / 湿地反射","标准 · 更轻的光照效果","兼容 · 重启后使用 OpenGL"]: quality.add_item(text)
	quality.select(graphics.quality); box.add_child(quality)
	var upscale := OptionButton.new(); upscale.name="GraphicsUpscale"
	for text in ["FSR2 · 清晰与性能平衡","FSR1 · 减少时间残影","原生分辨率"]: upscale.add_item(text)
	upscale.select(graphics.upscale); box.add_child(upscale)
	quality.item_selected.connect(func(i: int): graphics.quality=i; graphics.save())
	upscale.item_selected.connect(func(i: int): graphics.upscale=i; graphics.save())
	var description := Label.new()
	description.text="输出分辨率由窗口 / 全屏决定。\n超分只调整3D画面，界面保持清晰。\n高画质目标为4K输出60帧；兼容模式需重启。"
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(description)
	var restart := Button.new(); restart.text="保存画质并重启游戏"; box.add_child(restart)
	restart.pressed.connect(func():
		graphics.save()
		var arguments: PackedStringArray=graphics.launch_arguments()
		arguments.append_array(["--rendering-method","gl_compatibility" if graphics.quality==2 else "forward_plus"])
		arguments.append_array(["--","--skip-intro"])
		arguments.append_array(OS.get_cmdline_user_args())
		if OS.create_instance(arguments)>=0: parent.get_tree().quit())
