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
		s.players[1].p=Vector2(650,580)
		app.rogue_field.camera_x=150
		app.toast_time=0
		await screenshot("res://build/rogue-minions-f%d.png" % [floor_index+1])
		s.raid.area=5
		s.roguelike.enter(s)
		s.enemies.clear()
		s.raid.wave=3
		s.roguelike.spawn_wave(s)
		var boss: Dictionary=s.enemies[0]
		boss.p=s.roguelike.spawn_point(s,Vector2(2490,580))
		s.players[1].p=s.roguelike.spawn_point(s,Vector2(2310,600))
		app.rogue_field.camera_x=1560
		for skill in 5:
			combat.reset()
			s.bullets.clear()
			combat.begin_skill(s,boss,skill,s.players[1])
			combat.update(s,boss,boss.boss_windup*0.45)
			combat.tick(s,boss.boss_windup*0.45)
			await screenshot("res://build/rogue-boss-f%d-s%d-warning.png" % [floor_index+1,skill+1])
			combat.update(s,boss,boss.boss_windup*0.55+0.08)
			combat.tick(s,boss.boss_windup*0.55+0.08)
			await screenshot("res://build/rogue-boss-f%d-s%d-impact.png" % [floor_index+1,skill+1])
	app.queue_free()
	await process_frame
	print("BOSS VISUAL: five minion crowds and all 25 skills captured, warning + impact")
	quit()
