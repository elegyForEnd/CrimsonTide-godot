extends SceneTree
var app: Node

func _initialize() -> void:
	call_deferred("run")

func capture(tag: String) -> void:
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/wild-boss-"+tag+".png")

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-wild-bosses-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	var s: TideSession=app.session
	s.set_physics_process(false)
	var p: Dictionary=s.players[1]
	p.invuln=1000
	for index in 3:
		s.enemies.clear()
		s.raid.hazards=[]
		app.field.boss_fx.reset()
		var e: Dictionary
		if index<2:
			s.wild_bosses.spawn_mini(s,index+1)
			e=s.enemies.back()
			p.p=e.p+Vector2(180,25)
			s.wild_bosses.cast(s,e,p,"molt" if index==0 else "front",Vector2.RIGHT)
		else:
			s.raid.phase="boss"
			s.raid.day=3
			s.raid.kind=2
			s.wild_bosses.spawn_final(s)
			e=s.enemies.back()
			p.p=e.p+Vector2(180,25)
			s.wild_bosses.cast(s,e,p,"black_tide",Vector2.RIGHT)
		app.field.camera=p.p
		s.BossPresentation.send(s,e,"entrance")
		for h in s.raid.hazards: h.time=float(h.total)*0.45
		await capture(["earth","storm","abyss"][index])
	app.queue_free()
	for i in 3: await process_frame
	print("WILD BOSS VISUAL: 3 captures")
	quit()
