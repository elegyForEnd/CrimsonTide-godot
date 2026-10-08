extends SceneTree
func _initialize() -> void: call_deferred("run")
func screenshot(path: String) -> void:
	await create_timer(0.05).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-boss-visual.json"
	root.add_child(app)
	await process_frame
	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	var s=app.session
	var combat=s.roguelike.combat
	for floor_index in 5:
		s.raid.floor=floor_index+1
		s.roguelike.new_floor(s)
		s.raid.area=1
		s.roguelike.enter(s)
		s.raid.room_left=true
		s.players[1].p=Vector2(650,580)
		app.rogue_field.camera_x=150
		app.toast_time=0
		await screenshot("res://build/rogue-minions-f%d.png" % [floor_index+1])
		s.raid.node=str(s.rogue_graph.boss)
		s.raid.area=s.roguelike.depth_count(s)
		s.roguelike.enter(s)
		s.enemies.clear()
		# Boss rooms are selected through raid.room now; use an explicit visual fixture.
		s.spawn_enemy(s.roguelike.spawn_point(s,Vector2(2490,580)),4)
		combat.setup_boss(s.enemies.back(),floor_index,s)
		var boss: Dictionary=s.enemies[0]
		boss.p=s.roguelike.spawn_point(s,Vector2(2490,580))
		s.players[1].p=s.roguelike.spawn_point(s,Vector2(2310,600))
		app.rogue_field.camera_x=1560
		for skill in 5:
			combat.reset()
			s.enemies=[boss] # Previous skill's constructs are not part of this capture.
			app.rogue_field.reset_effects()
			s.bullets.clear()
			combat.begin_skill(s,boss,skill,s.players[1])
			s.BossChoreography.advance(s,.01)
			app.rogue_field.area_signature="%d:%d" % [s.raid.floor,s.raid.area]
			s.BossChoreography.advance(s,boss.boss_windup*.45)
			combat.update(s,boss,boss.boss_windup*0.45)
			combat.tick(s,boss.boss_windup*0.45)
			await screenshot("res://build/rogue-choreography-f%d-s%d-warning.png" % [floor_index+1,skill+1])
			var remaining := float(boss.boss_windup)*.55+.08
			for fx in combat.effects:
				if fx.damage>0: remaining=float(fx.delay)+.06; break
			s.BossChoreography.advance(s,remaining)
			combat.update(s,boss,remaining)
			combat.tick(s,remaining)
			await screenshot("res://build/rogue-choreography-f%d-s%d-impact.png" % [floor_index+1,skill+1])
	app.queue_free()
	await process_frame
	print("BOSS VISUAL: five minion crowds and all 25 skills captured, warning + impact")
	quit()
