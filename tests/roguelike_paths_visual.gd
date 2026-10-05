extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-paths-visual.json"
	root.add_child(app)
	await process_frame
	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	for floor_index in 5:
		app.session.raid.floor=floor_index+1
		app.session.raid.area=1
		app.session.roguelike.new_floor(app.session)
		app.session.roguelike.enter(app.session)
		app.session.enemies.clear()
		app.session.roguelike.clear_room(app.session)
		preload("res://tests/rogue_reward_flow.gd").claim(app.session,app.session.players[1])
		app.session.players[1].p=app.session.ruins.exit_position(0)-Vector2(70,0)
		app.rogue_field.camera_x=app.session.ruins.width-1440
		app.toast_time=0
		await create_timer(.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/rogue-night-paths-f%d.png" % (floor_index+1))
		assert(app.rogue_field.backdrop.material==null,"Image artwork supplies the distant blur")
	app.session.raid.area=2
	app.session.raid.route[1]="shop"
	app.session.roguelike.enter(app.session)
	app.session.players[1].p=app.session.ruins.exit_position(1)-Vector2(25,0)
	await create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/rogue-night-paths-shop.png")
	app.queue_free()
	await process_frame
	print("ROGUE PATHS VISUAL PASS")
	quit()
