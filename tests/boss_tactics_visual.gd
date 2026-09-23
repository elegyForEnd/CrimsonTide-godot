extends SceneTree
const T = preload("res://scripts/boss_tactics.gd")

func _initialize() -> void:
	call_deferred("run")

func capture(tag: String) -> void:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tactics-"+tag+".png")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-tactics-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	var s: TideSession=app.session
	s.set_physics_process(false)
	s.enemies.clear()
	s.raid.kind=1
	s.expedition.spawn_boss(s)
	var e: Dictionary=s.enemies.back()
	var p: Dictionary=s.players[1]
	p.p=e.p+Vector2(140,70)
	app.field.camera=p.p
	T.start_guard(e,Vector2.RIGHT)
	T.update_guard(e,0.4)
	await capture("guard")
	e.guard_time=0
	s.expedition.cast_boss(s,e,p,"feint",Vector2.RIGHT,p.p)
	await capture("fast-slow")
	s.raid.hazards=[]
	e.attack_time=0
	e.guard_cd=0
	T.start_guard(e,Vector2.RIGHT)
	T.update_guard(e,0.4)
	s.damage_enemy(e,88,1,Vector2.LEFT,58,2)
	await capture("break")
	app.queue_free()
	await process_frame
	print("BOSS TACTICS VISUAL PASS")
	quit()
