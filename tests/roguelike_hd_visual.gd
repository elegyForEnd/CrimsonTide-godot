extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	await create_timer(.06).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-hd-visual.json"
	root.add_child(app)
	await process_frame
	var s=app.session
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729)
	s.set_physics_process(false)
	var field=app.rogue_field
	for f in 5:
		s.raid.floor=f+1; s.raid.area=1; s.roguelike.enter(s)
		s.enemies.clear(); s.bullets.clear(); s.roguelike.combat.reset()
		field.camera_x=0; s.players[1].p=Vector2(350,600)
		for v in 8:
			s.roguelike.spawn_minion(s,Vector2(470+v*110,575+v%2*70),f,v,false)
		await capture("res://build/rogue-hd-minions-f%d-idle.png" % [f+1])
		for k in 2:
			field.reset_effects()
			for e in s.enemies:
				e.minion_skill=k; e.minion_windup=.55; e.attack_total=.95; e.attack_time=.25
				e.attack_released=true; e.attack_aim=Vector2.RIGHT; e.attack_point=e.p+Vector2(80,0)
				s.roguelike.combat.minion_event(s,e,"release")
			await capture("res://build/rogue-hd-minions-f%d-skill%d.png" % [f+1,k+1])
		s.enemies.clear(); s.roguelike.combat.reset()
		s.spawn_enemy(Vector2(970,610),4)
		var boss: Dictionary=s.enemies[0]
		s.roguelike.combat.setup_boss(boss,f)
		await capture("res://build/rogue-hd-boss-f%d-idle.png" % [f+1])
		for k in 5:
			s.roguelike.combat.reset(); field.reset_effects()
			s.roguelike.combat.begin_skill(s,boss,k,s.players[1])
			s.roguelike.combat.update(s,boss,boss.boss_windup+.12)
			s.roguelike.combat.tick(s,boss.boss_windup+.12)
			await capture("res://build/rogue-hd-boss-f%d-skill%d.png" % [f+1,k+1])
	app.queue_free()
	await process_frame
	print("HD VISUAL: 40 minions with two skill animations, five bosses with 25 eight-frame skills captured")
	quit()
