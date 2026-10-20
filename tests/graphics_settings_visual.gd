extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/" + file + ".png")

func run() -> void:
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.show_title()
	await process_frame
	app.show_settings()
	await process_frame
	app.show_graphics_settings()
	await process_frame
	await capture("graphics-settings")
	print("GRAPHICS SETTINGS: 1 capture completed")
	quit()
