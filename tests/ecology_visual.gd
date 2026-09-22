extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-ecology-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	app.session.enemies.clear()
	var p: Dictionary=app.session.players[1]
	p.p=Vector2(1300,1100)
	app.field.camera=p.p
	for kind in range(5,11):
		app.session.spawn_enemy(Vector2.ZERO,kind)
		var e: Dictionary=app.session.enemies[-1]
		e.p=p.p+Vector2(-380+(kind-5)*150,-100)
		e.facing=1.0
		e.moving=true
		e.motion_phase=1
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/ecology-monsters.png")
	for e in app.session.enemies:
		e.attack_total=Ecology.WINDUP[e.type]+0.6
		e.attack_time=e.attack_total-Ecology.WINDUP[e.type]*0.65
		e.attack_aim=Vector2.DOWN
		e["attack_point"]=e.p+Vector2(0,150)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/ecology-telegraphs.png")
	app.toggle_map()
	app.field.map_filter=3
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/ecology-map.png")
	app.queue_free()
	await process_frame
	await process_frame
	print("ECOLOGY VISUAL saved")
	quit()
