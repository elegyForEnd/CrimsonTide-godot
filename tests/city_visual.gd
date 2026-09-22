extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-city-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	var p: Dictionary=app.session.players[1]
	p.p=app.session.CITY_GATE
	app.session.travel_city()
	for entry in [["entrance",RoyalCity.GATE-Vector2(0,140)],["throne",RoyalCity.BOSS+Vector2(120,100)]]:
		p.p=entry[1]
		app.field.camera=p.p
		if entry[0]=="throne":
			var e: Dictionary=app.session.enemies[0]
			e.attack_time=2.4
			e.attack_total=2.65
			e["move_name"]="combo"
			e.attack_aim=(p.p-e.p).normalized()
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/city-%s.png" % entry[0])
	app.toggle_map()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/city-atlas.png")
	app.toggle_map()
	app.session.enemies[0].hp=0
	app.session.simulate(0.01)
	p.p=app.session.ruins.chests.back().p
	app.field.camera=p.p
	app.loot_action()
	app.session.advance_search(p,20)
	app.show_inventory()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/city-treasure.png")
	app.close_bag()
	app.queue_free()
	await process_frame
	await process_frame
	print("CITY VISUAL PASS")
	quit()
