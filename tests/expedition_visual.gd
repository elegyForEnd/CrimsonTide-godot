extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(tag: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/raid-"+tag+".png")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-raid-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	var s: TideSession=app.session
	var p: Dictionary=s.players[1]
	var failed := false
	for kind in 3:
		s.enemies.clear()
		s.expedition.prepare_day(s,2)
		s.raid.day=3 if kind==2 else 2
		s.raid.kind=kind
		s.raid.time=s.duration
		s.expedition.spawn_boss(s)
		p.p=s.safe_center()+Vector2(150,-80)
		app.field.camera=p.p
		app.field.combat.reset()
		app.toast_time=0
		var e: Dictionary=s.enemies.back()
		e.cd=0
		e.hp=e.max_hp*0.25
		s.expedition.update_boss(s,e,0.01)
		await capture("boss%d" % kind)
	s.raid.day=2
	s.raid.phase="choice"
	s.enemies.clear()
	s.raid.hazards=[]
	await capture("choice")
	app.hud.raid_continue.pressed.emit()
	failed=failed or not s.raid.choices.get(1,false)
	app.hud.raid_wait.pressed.emit()
	failed=failed or s.raid.choices.get(1,false)
	app.toggle_map()
	await capture("map")
	app.toggle_map()
	s.raid.day=3
	s.raid.phase="complete"
	await capture("complete")
	app.hud.raid_extract.pressed.emit()
	failed=failed or p.status!="extracted"
	app.queue_free()
	await process_frame
	print("RAID VISUAL AND CHOICE UI ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
