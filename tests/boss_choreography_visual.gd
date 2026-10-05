extends SceneTree
var app: Node
var s: TideSession

func _initialize() -> void:
	call_deferred("run")

func capture(tag: String) -> void:
	await create_timer(.08).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/boss-choreography-"+tag+".png")

func step(seconds: float) -> void:
	for i in ceili(seconds/.05): s.simulate(.05)

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-boss-choreography-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	s=app.session
	s.set_physics_process(false)
	var p: Dictionary=s.players[1]
	p.invuln=1000
	for kind in 4:
		s.enemies.clear()
		s.raid.hazards=[]
		s.raid.phase="explore"
		s.raid.kind=mini(kind,2)
		s.raid.day=3 if kind==2 else 2
		if kind==3: s.spawn_enemy(s.raid.center,4)
		else: s.expedition.spawn_boss(s)
		var e: Dictionary=s.enemies.back()
		p.p=e.p+Vector2(180,25)
		app.field.camera=p.p
		app.field.boss_fx.reset()
		app.field.combat.reset()
		var move: String=s.BossChoreography.names(e)[2 if kind==0 else 0]
		if kind==3: s.start_knight_attack(e,move,Vector2.RIGHT)
		else: s.expedition.cast_boss(s,e,p,move,Vector2.RIGHT,p.p)
		s.raid.phase="boss"
		step(.4)
		await capture(str(kind)+"-warning")
		step(maxf(.05,float(e.windup)-.4+.06))
		await capture(str(kind)+"-release")
		if kind==1:
			await create_timer(.25).timeout
			await capture(str(kind)+"-release-late")
		s.raid.hazards=[]
		app.field.boss_fx.reset()
		e.attack_time=0
		e["phase"]=3 if kind==2 else 2
		s.BossPresentation.send(s,e,"phase")
		await create_timer(.35).timeout
		await capture(str(kind)+"-phase")
	app.queue_free()
	for i in 3: await process_frame
	await create_timer(.3).timeout
	print("BOSS VFX VISUAL PASS: 13 captures")
	quit()
