extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(tag: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/area-"+tag+".png")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-area-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	var s: TideSession=app.session
	s.set_physics_process(false)
	s.spawn_timer=999
	var p: Dictionary=s.players[1]
	p.p=s.ruins.sites[15].p+Vector2(0,90)
	p.invuln=999
	app.field.camera=p.p
	s.simulate(0.01)
	await capture("combat")
	for e in s.enemies:
		if e.habitat==15: e.hp=0
	s.simulate(0.01)
	app.toast_time=0
	await capture("cleared")
	app.toggle_map()
	await capture("map")
	app.toggle_map()
	app.loot_action()
	s.advance_search(p,30)
	app.show_inventory()
	await capture("reward")
	app.queue_free()
	await process_frame
	print("AREA REWARD VISUAL PASS")
	quit()
