extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-regions.json"
	root.add_child(app)
	await process_frame
	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	for floor_index in 5:
		app.session.raid.floor=floor_index+1
		app.session.roguelike.new_floor(app.session)
		for area in 5:
			app.session.raid.area=area+1
			app.session.roguelike.enter(app.session)
			app.rogue_field.camera_x=0
			app.toast_time=0
			if area==2:
				app.session.players[1].p=Vector2(1500,580)
				app.rogue_field.camera_x=900
			await create_timer(0.15).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/rogue-regions-f%d-a%d.png" % [floor_index+1,area+1])
	app.queue_free()
	await process_frame
	print("REGION VISUAL CHECKS COMPLETE")
	quit()
