extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	await create_timer(.12).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-vfx-visual.json"
	root.add_child(app)
	await process_frame
	var s=app.session
	s.solo({"hero":3,"mode":"roguelike"})
	s.launch(false,1729)
	s.set_physics_process(false)
	s.raid.floor=2
	s.roguelike.new_floor(s)
	s.raid.area=5
	s.roguelike.enter(s)
	s.enemies.clear()
	s.raid.wave=3
	s.roguelike.spawn_wave(s)
	var boss: Dictionary=s.enemies[0]
	boss.p=s.roguelike.spawn_point(s,Vector2(2490,580))
	s.players[1].p=s.roguelike.spawn_point(s,Vector2(2290,580))
	app.rogue_field.camera_x=1650
	app.rogue_field._process(0)
	app.toast_time=0
	var combat=s.roguelike.combat
	# Node routes no longer guarantee a guardian in area 5; explicitly initialize one.
	combat.setup_boss(boss,1,s)
	combat.begin_skill(s,boss,0,s.players[1])
	combat.update(s,boss,boss.boss_windup+.08)
	combat.tick(s,boss.boss_windup+.08)
	s.combat_event.emit({"kind":"strike","p":s.players[1].p,"id":1,"weapon":1,"aim":Vector2.RIGHT})
	await capture("res://build/rogue-vfx-attack.png")
	s.combat_event.emit({"kind":"skill","p":s.players[1].p,"id":1,"hero":3,"aim":Vector2.RIGHT})
	s.combat_event.emit({"kind":"necromancer-fire","p":s.players[1].p,"id":1,"aim":Vector2.RIGHT,"duration":6.0})
	await capture("res://build/rogue-vfx-ultimate.png")
	app.queue_free()
	await process_frame
	await process_frame
	print("ROGUE VFX VISUAL: hero strike, original ultimate and textured enemy particles captured")
	quit()
