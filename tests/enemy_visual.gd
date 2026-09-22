extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-enemy-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	app.session.enemies.clear()
	var p: Dictionary=app.session.players[1]
	p.p=Vector2(1300,1100)
	app.field.camera=p.p
	for kind in 4:
		app.session.spawn_enemy(Vector2(1900,1100),kind)
		var e: Dictionary=app.session.enemies[-1]
		e.p=p.p+Vector2(-220+kind*145,-105)
		e.facing=1.0
		e.moving=true
		e.motion_phase=kind
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/enemies-battle.png")
	for e in app.session.enemies:
		e.attack_total=[0.62,0.84,1.0,0.72][e.type]
		e.attack_time=e.attack_total-[0.26,0.42,0.56,0.32][e.type]-0.04
		e.attack_released=true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/enemies-attack.png")
	for e in app.session.enemies:
		app.session.broadcast_combat({"kind":"enemy_defeated","p":e.p,"type":e.type,"facing":e.facing})
	app.session.enemies.clear()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/enemies-defeated.png")
	app.queue_free()
	await process_frame
	await process_frame
	print("ENEMY VISUAL: movement and contact screenshots saved")
	quit()
