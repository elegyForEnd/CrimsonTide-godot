extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(app: Node, tag: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/feiyue-3d-%s.png" % tag)

func run() -> void:
	root.size=Vector2i(1280,800)
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-feiyue-3d-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	var session: TideSession=app.session
	session.set_physics_process(false)
	session.enemies.clear()
	var p: Dictionary=session.players[1]
	p.p=Vector2(1300,1100)
	p.aim=Vector2.RIGHT
	p.strike_aim=Vector2.RIGHT
	p.move_dir=Vector2.RIGHT
	p.motion="idle"
	p.weapon=1
	p.swing_time=0.0
	p.cast_time=0.0
	app.field.camera=p.p
	await capture(app,"idle")
	for weapon in [1,2,3]:
		p.weapon=weapon
		p.swing_total=0.88
		p.swing_time=p.swing_total-float(Catalog.weapon(weapon).windup)
		await capture(app,"weapon-%d-impact" % weapon)
	p.swing_time=0.0
	p.motion="run"
	app.field.move_phases[1]=1.0
	await capture(app,"run")
	p.motion="dodge"
	p.dodge_dir=Vector2.RIGHT
	p.dodge_time=TideSession.DODGE_DURATION*0.5
	await capture(app,"dodge")
	app.queue_free()
	await process_frame
	print("FEIYUE IN GAME: 6 captures completed")
	quit()
