extends SceneTree
# Asset contact sheet: deliberately synchronize poses for side-by-side VFX inspection.
# Live combat cadence is verified separately by roguelike_attack_timing.gd.
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	await create_timer(.07).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-minion-vfx-visual.json"
	root.add_child(app)
	await process_frame
	var s=app.session
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	s.set_physics_process(false)
	for floor_index in 5:
		s.raid.floor=floor_index+1
		s.roguelike.new_floor(s)
		s.raid.area=1
		s.roguelike.enter(s)
		s.enemies.clear()
		s.bullets.clear()
		s.players[1].p=Vector2(680,620)
		s.players[1].invuln=20
		app.rogue_field.camera_x=0
		app.rogue_field._process(0)
		app.toast_time=0
		for variant in 4:
			s.roguelike.spawn_minion(s,s.roguelike.spawn_point(s,Vector2(520+variant*190,550)),floor_index,variant,false)
			var e: Dictionary=s.enemies.back()
			e.attack_total=.9
			e.attack_time=.9
			e.attack_released=false
			e.attack_aim=Vector2.RIGHT
			e.attack_point=e.p+Vector2(65,65)
			s.roguelike.combat.minion_event(s,e,"charge")
		await capture("res://build/rogue-minion-f%d-charge.png" % [floor_index+1])
		for e in s.enemies: s.roguelike.combat.update(s,e,.56)
		s.roguelike.combat.tick(s,.02)
		await capture("res://build/rogue-minion-f%d-release.png" % [floor_index+1])
		s.roguelike.combat.tick(s,.46)
		await capture("res://build/rogue-minion-f%d-ground.png" % [floor_index+1])
	app.queue_free()
	await process_frame
	await process_frame
	print("ROGUE MINION VFX VISUAL: 20 minions, five themes, 15 snapshots")
	quit()
