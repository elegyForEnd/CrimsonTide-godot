extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-ground-visual.json"
	root.add_child(app)
	await process_frame
	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.launch(false,3162920)
	app.session.set_physics_process(false)
	var p: Dictionary=app.session.players[1]
	p.p=app.session.ruins.move(Vector2(450,app.session.ruins.lane_center(450)),Vector2(0,-600),15)
	app.toast_time=0
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/rogue-ground-boundary.png")
	app.queue_free()
	await process_frame
	print("ROGUE GROUND VISUAL PASS")
	quit()
