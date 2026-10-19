extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path = "user://test-mapgen-scene.json"
	app.session.solo({"hero": 0})
	app.session.mapgen_enabled = true
	app.session.launch(false, 20261019)
	app.session.set_physics_process(false)
	if app.inventory_open:
		app.close_bag()
	print("SCENE generated=", app.session.ruins.generated, " fog=", app.field.fog != null, " bag=", app.inventory_open)
	var p: Dictionary = app.session.players[1]
	for i in [0, 4, 8]:
		if i >= app.session.ruins.sites.size():
			continue
		p.p = app.session.ruins.sites[i].p + Vector2(0, 190)
		app.field.camera = p.p
		app.field.smooth_positions.clear()
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/mapgen-scene-%d.png" % i)
	p.p = app.session.ruins.spawn
	app.field.camera = p.p
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/mapgen-spawn.png")
	var lake: Dictionary = {}
	for candidate in app.session.ruins.lakes:
		if lake.is_empty() or float(candidate.radius) > float(lake.radius):
			lake = candidate
	if not lake.is_empty():
		p.p = lake.center
		app.field.smooth_positions.clear()
		await create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/mapgen-lake.png")
		p.p = lake.center + Vector2(float(lake.radius) * 0.85, 0)
		app.field.smooth_positions.clear()
		await create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/mapgen-lake-shore.png")
	if not app.session.ruins.rivers.is_empty():
		var best := Vector2.ZERO
		var best_score := -INF
		for river in app.session.ruins.rivers:
			var river_points: PackedVector2Array = river.get("points", PackedVector2Array())
			for point: Vector2 in river_points:
				var lake_gap := INF
				for candidate in app.session.ruins.lakes:
					lake_gap = minf(lake_gap, point.distance_to(candidate.center) - float(candidate.radius))
				var site_gap := INF
				for site in app.session.ruins.sites:
					site_gap = minf(site_gap, _rect_gap(site.get("rect", Rect2(site.p, Vector2.ZERO)), point))
				var bridge_gap := INF
				for bridge: Rect2 in app.session.ruins.bridges:
					bridge_gap = minf(bridge_gap, _rect_gap(bridge, point))
				var extent: Vector2 = app.session.ruins.extent
				var edge := minf(minf(point.x, point.y), minf(extent.x - point.x, extent.y - point.y))
				var score := minf(bridge_gap, 900.0) * 2.0 + site_gap * 0.5 + minf(lake_gap, 500.0) * 0.4 + minf(edge, 800.0) * 0.2
				if score > best_score:
					best_score = score
					best = point
		if best != Vector2.ZERO:
			print("RIVER shot at ", best, " depth=", app.session.ruins.terrain.water_depth_at(best))
			p.p = best
			app.field.smooth_positions.clear()
			await create_timer(0.45).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/mapgen-river.png")
			# Second frame zoomed out 2.4x: one screen still shows the river's width
			# against its banks instead of a single bank filling the view.
			app.field.set_process(false)
			app.field.world_3d.view_camera.size = root.get_visible_rect().size.y * 0.01 * 2.4
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/mapgen-river-wide.png")
			app.field.set_process(true)
	app.toggle_map()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/mapgen-atlas.png")
	app.toggle_map()
	app.queue_free()
	await process_frame
	await process_frame
	print("MAPGEN SCENE VISUAL: captured")
	quit()

func _rect_gap(rect: Rect2, at: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - at.x, 0.0), at.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - at.y, 0.0), at.y - rect.end.y)
	return Vector2(dx, dy).length()
