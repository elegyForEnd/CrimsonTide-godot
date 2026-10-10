extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+file+".png")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-combat-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	app.session.enemies.clear()
	var p: Dictionary=app.session.players[1]
	p.p=Vector2(1300,1100)
	p.aim=Vector2.RIGHT
	app.field.camera=p.p
	for hero in 3:
		# The temporary issue weapon first, then the three field weapons a raid can
		# hand out; every one of them has to animate.
		for weapon in [Catalog.starter_index(hero),1,2,3]:
			app.field.combat.reset()
			app.session.bullets.clear()
			p.hero=hero
			p.weapon=weapon
			p.attack=0.0
			p.swing_time=0.0
			p.cast_time=0.0
			app.session.attack(p)
			await create_timer(Catalog.weapon(weapon).windup).timeout
			p.swing_time=p.swing_total-Catalog.weapon(weapon).windup-0.04
			app.session.release_strike(p)
			await create_timer(0.065).timeout
			await capture("combat-h%d-w%d" % [hero,weapon])
		p.swing_time=0.0
		p.skill=0.0
		# Physics is frozen in this fixture, so mana does not regenerate between heroes.
		p.mana=p.max_mana
		app.field.combat.reset()
		app.session.perform(1,"skill")
		if not app.ultimate.active:
			push_error("Ultimate preview failed to start for hero %d" % hero); quit(1); return
		await app.ultimate.ended
		await create_timer(0.23).timeout
		await capture("combat-skill-%d" % hero)
	print("COMBAT VISUAL: 21 captures completed")
	quit()
