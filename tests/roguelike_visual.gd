extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(tag: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/rogue-"+tag+".png")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-visual.json"
	root.add_child(app)
	await process_frame
	app.profile.data.coins=160
	app.show_rogue_setup()
	await capture("setup")
	app.session.solo({"hero":0,"mode":"roguelike","rogue_rerolls":2})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	for i in 5:
		app.session.raid.floor=i+1
		app.session.raid.area=1
		app.session.roguelike.new_floor(app.session)
		app.session.roguelike.enter(app.session)
		await capture("floor-%d" % (i+1))
	app.session.players[1].p=Vector2(2100,580)
	await capture("scroll")
	assert(app.rogue_field.camera_x>500,"Camera follows long map")
	app.session.enemies.clear()
	app.session.roguelike.clear_room(app.session)
	preload("res://tests/rogue_reward_flow.gd").pick(app.session,app.session.players[1])
	await capture("reward")

	app.show_rogue_setup()
	app.rogue_cards=2
	app.rogue_weapon=1
	app.start_rogue()
	app.session.set_physics_process(false)
	assert(app.profile.data.coins==160,"Current free preparation preserves coins")
	assert(app.session.players[1].rogue_rerolls==2,"Purchased refresh cards in run")
	app.start_rogue()
	assert(app.profile.data.coins==160,"Duplicate launch click cannot charge twice")
	app.profile.data.coins=0
	app.show_rogue_setup()
	var seed_before: int=app.session.seed_value
	app.start_rogue()
	assert(app.page_name=="rogue_game" or app.session.running,"Free launch remains available with zero coins")
	print("ROGUE VISUAL / UI CHECKS PASS")
	app.queue_free()
	await process_frame
	quit()
