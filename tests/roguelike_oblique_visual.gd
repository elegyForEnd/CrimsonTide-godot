extends SceneTree

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-oblique-visual.json"
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
		var p: Dictionary=app.session.players[1]
		var map=app.session.ruins
		p.p=map.safe_point(Vector2(map.width*.38,map.lane_center(map.width*.38)))
		app.toast_time=0
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/rogue-oblique-f%d-center.png" % (floor_index+1))
		if floor_index==0:
			var before: float=app.rogue_field.camera_y
			p.p=map.move(p.p,Vector2(0,map.extent.y),15)
			await create_timer(.5).timeout
			assert(app.rogue_field.camera_y>before,"Walking down moves the map upwards")
			assert(not map.blocked(p.p,15),"Player stays on the foreground boundary")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/rogue-oblique-down.png")
		app.session.roguelike.clear_room(app.session)
		preload("res://tests/rogue_reward_flow.gd").claim(app.session,p)
		p.p=map.exit_position(1)
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/rogue-oblique-f%d-fork.png" % (floor_index+1))
	app.queue_free()
	await process_frame
	print("ROGUE OBLIQUE VISUAL PASS")
	quit()
