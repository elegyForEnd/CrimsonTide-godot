extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(tag: String) -> void:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/landmark-%s.png" % tag)

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-landmark-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	var s: TideSession=app.session
	var p: Dictionary=s.players[1]
	s.enemies.clear()
	s.expedition.prepare_day(s,2)
	p.p=s.ruins.exits[0]
	app.field.camera=p.p
	await capture("extraction-idle")
	p.target="exit:0"
	p.channel=2.8
	p.channel_total=4.0
	await capture("extraction-channel")
	p.target=""
	p.channel=0.0
	s.emit_effect("extract",p.p)
	await capture("extraction-burst")
	p.p=s.safe_center()
	app.field.camera=p.p
	await capture("boss-sigil")
	p.p=s.ruins.shrines[0].p
	app.field.camera=p.p
	await capture("shrine-sigil")
	p.p=s.ruins.exits[0]
	app.field.camera=p.p
	s.interact(p,true,0.1)
	s.interact(p,true,4.0)
	var extracted: bool=p.status=="extracted"
	app.queue_free()
	await process_frame
	print("LANDMARK VISUAL AND EXTRACTION ","PASS" if extracted else "FAIL")
	quit(0 if extracted else 1)
