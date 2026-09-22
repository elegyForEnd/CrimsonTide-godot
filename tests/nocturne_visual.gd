extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+file+".png")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-nocturne-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	var p: Dictionary=app.session.players[1]
	p.p=Vector2(1300,1100)
	app.field.camera=p.p
	for group in [[0,1,2,3,5],[6,7,8,9,10],[11,12,13],[14,15,16]]:
		app.session.enemies.clear()
		for i in group.size():
			app.session.spawn_enemy(Vector2.ZERO,group[i])
			var e: Dictionary=app.session.enemies[-1]
			e.p=p.p+Vector2((i-(group.size()-1)/2.0)*(260 if group[0]>=14 else 170),-50 if group[0]>=14 else -85)
			e.facing=1.0
			e.moving=true
			e.motion_phase=1
		await create_timer(0.1).timeout
		await capture("nocturne-roster-"+str(group[0]))
		if group[0] in [11,14]:
			for e in app.session.enemies:
				e.attack_total=Ecology.WINDUP[e.type]+0.75
				e.attack_time=e.attack_total-Ecology.WINDUP[e.type]*0.65
				e.attack_aim=Vector2.DOWN
				e["attack_point"]=e.p+Vector2(0,150)
				e["attack_start"]=e.p
			await capture("nocturne-telegraphs" if group[0]==11 else "nocturne-large-telegraphs")
	app.toggle_map()
	app.field.map_filter=3
	await capture("nocturne-habitats")
	app.queue_free()
	await process_frame
	await process_frame
	print("NOCTURNE VISUAL saved")
	quit()
