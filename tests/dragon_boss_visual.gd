extends SceneTree
var app: Node

func _initialize() -> void:
	call_deferred("run")

func capture(tag: String) -> void:
	await create_timer(0.18).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/dragon-boss-"+tag+".png")

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-dragon-boss-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1741)
	var s: TideSession=app.session
	s.set_physics_process(false)
	s.enemies.clear()
	s.expedition.prepare_day(s,2)
	var e: Dictionary={}
	for candidate in s.enemies:
		if candidate.get("dragon_boss",false): e=candidate
	if e.is_empty():
		push_error("Dragon failed to spawn for visual test")
		quit(1)
		return
	s.enemies=[e]
	var p: Dictionary=s.players[1]
	p.invuln=1000
	p.p=e.p+Vector2(190,25)
	app.field.camera=p.p
	s.dragon_boss.cast(s,e,p,"breath",Vector2.RIGHT)
	s.BossPresentation.send(s,e,"entrance")
	for h in s.raid.hazards: h.time=float(h.total)*0.43
	await capture("breath")
	s.raid.hazards=[]
	s.dragon_boss.cast(s,e,p,"tail",Vector2.RIGHT)
	for h in s.raid.hazards: h.time=float(h.total)*0.43
	await capture("tail")
	app.queue_free()
	for i in 3: await process_frame
	print("DRAGON BOSS VISUAL: 2 captures")
	quit()
