extends SceneTree
var app: Node
func _initialize() -> void: call_deferred("run")
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://boss-special-choreography-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	var s: TideSession=app.session
	s.set_physics_process(false)
	var tags := ["mirror","ember","moon","earth","storm","abyss","dragon","hidden"]
	for index in tags.size():
		s.enemies.clear()
		s.bullets.clear()
		s.raid.hazards=[]
		s.raid.phase="explore"
		app.field.boss_fx.reset()
		match index:
			0,1: s.mini_bosses.spawn(s,1,index)
			2: s.expedition.spawn_boss(s,true)
			3,4: s.wild_bosses.spawn_mini(s,1,index-3)
			5: s.wild_bosses.spawn_final(s)
			6: s.dragon_boss.spawn(s,1)
			7: s.expedition.spawn_boss(s)
		var e: Dictionary=s.enemies.back()
		if index==7: e["hidden_final"]=true; e.boss_kind=4; e.boss_name="冥火尸王 · 墓玥"
		var p: Dictionary=s.players[1]
		p.p=e.p+Vector2(190,0)
		p.invuln=999
		app.field.camera=p.p
		s.raid.phase="boss"
		s.BossChoreography.start(s,e,s.BossChoreography.names(e)[2 if index==3 else 0],Vector2.RIGHT,p.p)
		for tick in ceili((float(e.windup)+.08)/.05): s.simulate(.05)
		await create_timer(.08).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/boss-special-choreography-"+tags[index]+".png")
	app.queue_free()
	await process_frame
	print("SPECIAL BOSS CHOREOGRAPHY VISUAL: 8 captures")
	quit()
