extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1440,900)
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-generated-attacks-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	var s: TideSession=app.session
	s.set_physics_process(false)
	s.enemies.clear()
	var p: Dictionary=s.players[1]
	p.p=Vector2(1300,1100)
	p.aim=Vector2.RIGHT
	p.strike_aim=Vector2.RIGHT
	p.motion="idle"
	p.weapon=2
	p.swing_total=0.88
	s.raid.kind=1
	s.expedition.spawn_boss(s)
	var e: Dictionary=s.enemies.back()
	e.p=p.p+Vector2(200,25)
	e.facing=-1.0
	e.attack_total=2.0
	e.attack_marks=[1.0]
	e.windup=1.0
	app.field.camera=p.p+Vector2(100,0)
	for phase in [["opening",0.0,0.0],["impact",0.34,1.0],["return",0.86,1.98]]:
		p.swing_time=p.swing_total-float(phase[1])
		e.attack_time=e.attack_total-float(phase[2])
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/generated-attack-%s.png" % phase[0])
	app.queue_free()
	await process_frame
	print("GENERATED ATTACK VISUAL: opening, impact and return captured in game")
	quit()
