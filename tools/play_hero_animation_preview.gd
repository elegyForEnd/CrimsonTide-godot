extends SceneTree

func _initialize() -> void:
	if "--animation-capture" in OS.get_cmdline_user_args(): root.hide()
	call_deferred("run")

func run() -> void:
	root.title="血潮守望 · 原版图集"
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://hero-animation-preview.json"
	root.add_child(app)
	app.session.solo({"hero":0,"name":"动画试看·绯月"})
	app.session.launch(false,1729)
	print("GAME READY: original hero atlas animations; WASD move, left mouse attack")
	if not "--animation-capture" in OS.get_cmdline_user_args():
		root.show()
		root.grab_focus()
		return
	var s: TideSession=app.session
	s.set_physics_process(false)
	s.enemies.clear()
	var p: Dictionary=s.players[1]
	p.p=Vector2(1300,1100)
	p.aim=Vector2.RIGHT
	p.strike_aim=Vector2.RIGHT
	p.move_dir=Vector2.RIGHT
	app.field.camera=p.p
	for state in ["walk","sword"]:
		p.motion="walk" if state=="walk" else "idle"
		p.swing_total=0.8
		p.swing_time=0.0 if state=="walk" else 0.4
		p.cast_time=0.0
		app.field.move_phases[1]=1.0
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://output/hero-animation-v4/game-%s.png" % state)
	print("ANIMATION GAME CAPTURE: walk and sword rendered")
	quit()
