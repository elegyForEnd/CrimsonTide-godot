extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-spells-visual.json"
	app.session.solo({"hero":1})
	app.session.launch(false,4137)
	app.session.set_physics_process(false)
	app.session.enemies.clear()
	var p: Dictionary=app.session.players[1]
	p.p=Vector2(1300,1100)
	p.aim=Vector2.RIGHT
	app.field.camera=p.p
	for index in range(4,12):
		app.field.combat.reset()
		app.session.bullets.clear()
		p.weapon=index
		p.attack=0.0
		p.swing_time=0.0
		p.cast_time=0.0
		p.pending_strike=false
		app.session.attack(p)
		p.pending_strike=false
		p.swing_time=p.swing_total-Catalog.weapon(index).windup-0.02
		app.session.release_strike(p)
		for step in 12:
			app.session.update_bullets(0.01)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/spell-%d.png" % index)
	print("SPELL VISUAL: 8 captures completed")
	quit()
