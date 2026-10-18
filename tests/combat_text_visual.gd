extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(file: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/" + file + ".png")

func run() -> void:
	var background := ColorRect.new()
	background.color = Color("0d0a10")
	background.size = root.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var text: Node2D = preload("res://scripts/combat_text.gd").new()
	text.projector = func(at: Vector2) -> Vector2: return at
	root.add_child(text)

	# A representative frame: ordinary, heavy, hurt, heal and burn together.
	text.push("damage", Vector2(250, 300), 128.0)
	text.push("damage", Vector2(430, 300), 246.0, {"heavy": true})
	text.push("hurt", Vector2(610, 300), 37.0)
	text.push("heal", Vector2(790, 300), 45.0)
	text.push("dot", Vector2(970, 300), 6.0)
	text.advance(0.08)
	await capture("combat-text-on")

	# The first 70ms is the white core flash; capture it separately so the
	# effect can be inspected without guessing from the settled frame.
	text.reset()
	text.push("damage", Vector2(430, 420), 246.0, {"heavy": true})
	text.push("heal", Vector2(610, 420), 45.0)
	text.advance(0.02)
	await capture("combat-text-flash")

	var graphics: Node = root.get_node_or_null("GraphicsQuality")
	if graphics != null:
		graphics.damage_ghost = false
		graphics.damage_flash = false
	text.reset()
	text.push("damage", Vector2(250, 530), 128.0)
	text.push("damage", Vector2(430, 530), 246.0, {"heavy": true})
	text.push("hurt", Vector2(610, 530), 37.0)
	text.push("heal", Vector2(790, 530), 45.0)
	text.push("dot", Vector2(970, 530), 6.0)
	text.advance(0.08)
	await capture("combat-text-off")

	if graphics != null:
		graphics.damage_ghost = true
		graphics.damage_flash = true
	print("COMBAT TEXT VISUAL: 3 captures completed")
	quit()
