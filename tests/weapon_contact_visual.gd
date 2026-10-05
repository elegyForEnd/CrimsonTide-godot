extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.profile.path="user://test-contact-polish.json"
	app.session.solo({"hero":0}); app.session.launch(false,1729)
	app.session.set_physics_process(false); app.session.enemies.clear()
	var p: Dictionary=app.session.players[1]
	p.p=app.session.raid.center+Vector2(-70,0); p.aim=Vector2.RIGHT; p.weapon=17
	app.session.spawn_enemy(p.p+Vector2(90,0),2)
	var enemy: Dictionary=app.session.enemies.back()
	enemy.p=p.p+Vector2(90,0); enemy.home=enemy.p
	enemy.hp=999; enemy.max_hp=999
	app.field.camera=p.p
	await create_timer(.2).timeout
	app.session.attack(p)
	p.pending_strike=false; p.swing_time=maxf(.06,p.swing_total-Catalog.weapon(p.weapon).windup-.02)
	app.session.release_strike(p)
	app.session.combat_event.emit({"kind":"impact","p":enemy.p,"aim":Vector2.RIGHT,"id":1,"enemy_id":enemy.id,"weapon":1,"weapon_index":17,"heavy":false,"damage":38.0})
	await create_timer(.035).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/weapon-contact-polished.png")
	app.queue_free(); await process_frame
	print("CONTACT VISUAL captured")
	quit()
