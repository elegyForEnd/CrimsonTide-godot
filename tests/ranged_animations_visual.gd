extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-ranged-animations-visual.json"
	root.add_child(app)
	for mode in ["expedition","roguelike"]:
		app.session.running=false
		app.session.solo({"hero":0,"mode":mode})
		app.session.players[1].ready=true
		assert(app.session.launch(false,1729),"Preview must enter actual combat")
		var s: TideSession=app.session
		s.set_physics_process(false)
		s.enemies.clear()
		if mode=="roguelike":
			s.raid.phase="rogue_combat"
			s.players[1].rogue_selection={}
			s.players[1].build_reward_queue=[]
		if mode=="expedition": app.field.world_3d.view_camera.make_current()
		var base: Dictionary=s.players[1]
		base.p=Vector2(700,575) if mode=="roguelike" else Vector2(1300,1100)
		base.aim=Vector2.RIGHT; base.strike_aim=Vector2.RIGHT; base.motion="idle"
		for hero in range(1,4):
			var p: Dictionary=base.duplicate(true)
			p.id=hero+1; p.hero=hero; p.name=Catalog.HEROES[hero].name
			p.p=base.p+Vector2(hero*100,0)
			s.players[p.id]=p
		for weapon in [0,16]:
			for p: Dictionary in s.players.values():
				p.weapon=weapon; p.swing_total=Catalog.weapon(weapon).rate
				p.swing_time=p.swing_total-Catalog.weapon(weapon).windup
				p.cast_time=0.0; p.pending_strike=false
			await create_timer(.4).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://output/ranged-animation/%s-%s.png" % [mode,"bow" if weapon==16 else "rifle"])
	app.queue_free()
	await process_frame
	print("RANGED VISUAL: campaign and rogue bow/rifle, four heroes captured")
	quit()
