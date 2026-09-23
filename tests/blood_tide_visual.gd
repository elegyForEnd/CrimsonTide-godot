extends SceneTree
var app: Node

func _initialize() -> void:
	call_deferred("run")

func capture(tag: String) -> void:
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/blood-tide-"+tag+".png")

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-blood-tide-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	var s: TideSession=app.session
	s.set_physics_process(false)
	s.enemies.clear()
	app.toast_time=0
	s.raid.center=Vector2(3200,2400)
	s.raid.phase="boss"
	var p: Dictionary=s.players[1]
	for scenario in ["inside","edge","outside"]:
		var distance_from_center: float={"inside":0.0,"edge":510.0,"outside":850.0}[scenario]
		p.p=s.safe_center()+Vector2(distance_from_center,0)
		app.field.camera=p.p
		app.field.smooth_positions.clear()
		await capture(scenario)
		assert(app.field.blood_tide.active)
	await create_timer(1.0).timeout
	await capture("moving-mist")
	s.raid.phase="explore"
	s.raid.time=s.duration-12.0
	p.p=s.safe_center()+Vector2(s.safe_radius()-30.0,0)
	app.field.camera=p.p
	await capture("shrinking")
	assert(is_equal_approx(float(app.field.blood_tide.material.get_shader_parameter("safe_radius")),s.safe_radius()))
	s.raid.phase="boss"
	s.raid.day=3
	p.p=s.safe_center()+Vector2(590,0)
	app.field.camera=p.p
	await capture("third-day")
	assert(is_equal_approx(float(app.field.blood_tide.material.get_shader_parameter("safe_radius")),620.0))
	app.field.map_open=true
	await capture("map")
	assert(not app.field.blood_tide.active)
	app.field.map_open=false
	s.raid.phase="choice"
	await capture("clear")
	assert(not app.field.blood_tide.active)
	s.map_id="city"
	await process_frame
	await process_frame
	assert(not app.field.blood_tide.active)
	app.queue_free()
	for i in 3: await process_frame
	print("BLOOD TIDE VISUAL PASS: inside, edge, outside, animation, shrinking, third day, map, intermission, interior")
	quit()
