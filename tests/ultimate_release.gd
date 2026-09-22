extends SceneTree

var failures := 0
var checks := 0
var releases := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(title)

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.session.solo(app.config())
	app.session.launch(false,1729)
	var session: TideSession=app.session
	session.set_physics_process(false)
	session.enemies.clear()
	session.ruins.walls.clear()
	session.spawn_timer=9999
	var p: Dictionary=session.players[1]
	p.p=Vector2(1350,1100)
	p.aim=Vector2.RIGHT
	app.field.camera=p.p
	session.combat_event.connect(func(data: Dictionary):
		if data.kind=="skill": releases+=1
	)
	for hero in 3:
		p.hero=hero
		p.skill=0.0
		p.hp=p.max_hp-60.0
		p.aim=Vector2.RIGHT
		session.enemies.clear()
		session.spawn_enemy(p.p+Vector2(90,0),2)
		var enemy: Dictionary=session.enemies[0]
		enemy.p=p.p+Vector2(90,0)
		enemy.hp=500.0
		enemy.max_hp=500.0
		app.field.combat.reset()
		app.sound.last_played.clear()
		var before := releases
		session.action("skill")
		check(app.ultimate.active and paused,"Accepted Q pauses solo CG")
		check(enemy.hp==500 and p.hp==p.max_hp-60,"No damage or healing before CG ends")
		check(releases==before and app.field.combat.motes.is_empty(),"No skill VFX/event during CG")
		session.action("skill")
		check(releases==before,"Repeated Q cannot settle pending cast")
		app.ultimate.set_process(false)
		app.ultimate._process(app.ultimate.impact_time+.01)
		check(releases==before and enemy.hp==500,"CG portrait flash is not the gameplay release")
		app.ultimate._process(app.ultimate.duration)
		app.ultimate.set_process(true)
		check(not paused and not app.ultimate.active,"CG ends before gameplay resumes")
		check(releases==before+1 and not session.pending_ultimates.has(1),"Exactly one release at CG end")
		check(p.hp==p.max_hp-15 if hero==1 else enemy.hp==385,"Healing or damage settles at release")
		check(not app.field.combat.motes.is_empty(),"Release creates visible world VFX")
		var found := false
		for voice in app.sound.voices:
			if voice.playing and voice.get_meta("cue","")=="skill":
				found=found or voice.stream==app.sound.clips.skill[hero]
		check(found,"Local hero plays the correct release sound")
		session.release_ultimate(1)
		check(releases==before+1,"Repeated completion cannot double damage")
		app.sound.stop_cue("skill",1)

	p.skill=0.0
	session.action("skill")
	var before := releases
	var skip := InputEventKey.new()
	skip.physical_keycode=KEY_ESCAPE
	skip.pressed=true
	app.ultimate._input(skip)
	check(not paused and releases==before+1,"User skip releases once and resumes")
	p.skill=0.0
	session.action("skill")
	before=releases
	app.show_title()
	check(not paused and releases==before and session.pending_ultimates.is_empty(),"Leaving game cancels cast without damage or sound")

	# Use a real ENet authority, with physics stepped explicitly to test timing.
	check(session.host({"hero":0})==OK,"Online test host starts")
	session.launch(false,1729)
	session.enemies.clear()
	session.spawn_timer=9999
	p=session.players[1]
	p.p=Vector2(1350,1100)
	app.field.camera=p.p
	before=releases
	session.action("skill")
	check(not paused and app.ultimate.active,"Online CG leaves simulation running")
	app.ultimate.stop()
	check(releases==before,"Skipping online CG cannot accelerate host release")
	session.simulate(.80)
	check(releases==before,"Online skill waits for full short duration")
	session.simulate(.06)
	check(releases==before+1,"Host releases after 0.85 seconds")
	p.skill=0.0
	session.action("skill")
	session.down(p)
	session.simulate(1.0)
	check(releases==before+1 and session.pending_ultimates.is_empty(),"Downing cancels pending online skill")
	session.disconnect_room()
	app.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("ULTIMATE RELEASE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
