extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-map-visual.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	var p: Dictionary=app.session.players[1]
	for i in [0,4,5,6,9,12,15]:
		p.p=app.session.ruins.sites[i].p+Vector2(0,190)
		app.field.camera=p.p
		app.field.smooth_positions.clear()
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/map-region-%d.png" % i)
	p.p=Vector2(Ruins.river_x(2400)-100,2400)
	app.field.camera=p.p
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/map-bridge.png")
	app.toggle_map()
	assert(not app.page.visible)
	var event := InputEventKey.new()
	event.physical_keycode=KEY_2
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	assert(app.field.map_filter==1)
	event=InputEventKey.new()
	event.physical_keycode=KEY_1
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	assert(app.field.map_filter==0)
	var point: Vector2=app.field.map_rect().position+app.session.ruins.sites[6].p/Ruins.SIZE*app.field.map_rect().size
	root.warp_mouse(point)
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	click.position=point
	Input.parse_input_event(click)
	await process_frame
	assert(app.field.waypoint.x>=0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/map-atlas.png")
	app.toggle_map()
	assert(app.page.visible)
	app.queue_free()
	await process_frame
	await process_frame
	print("MAP VISUAL: six regions, bridge and atlas captured")
	quit()
