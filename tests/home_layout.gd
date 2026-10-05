extends SceneTree
## Real walking connectivity, door traversal, material proportions and roof cutaway.
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)
func run() -> void:
	var screen = preload("res://scripts/camp_screen.gd").new()
	root.add_child(screen)
	await process_frame
	screen.set_process(false)
	var site = screen.site
	site.set_process(false)
	check(site.architecture.buildings.size() == 1,"only the edge library is enclosed")
	check(site.architecture.open_stations.size() == 5,"council and four working stations remain open")
	var origin := Vector2(1050,1250)
	var step := 40.0
	var start := Vector2i(((site.SPAWN-origin)/step).round())
	var visited := {start:true}
	var pending: Array[Vector2i] = [start]
	var cached := {}
	var cursor := 0
	while cursor < pending.size():
		var current := pending[cursor]
		cursor += 1
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = current+direction
			if next.x < 0 or next.y < 0 or next.x > 97 or next.y > 89 or visited.has(next): continue
			if not cached.has(next): cached[next] = site.is_walkable(origin+Vector2(next)*step)
			if cached[next]:
				visited[next] = true
				pending.append(next)
	for station in site.stations:
		var target: Vector2 = station.at+station.offset
		var cell := Vector2i(((target-origin)/step).round())
		var reachable := false
		for x in range(-2,3):
			for y in range(-2,3):
				var candidate := cell+Vector2i(x,y)
				var at := origin+Vector2(candidate)*step
				if visited.has(candidate) and site.station_at(at).get("id","") == station.id: reachable = true
		check(reachable,"walk from spawn to "+str(station.id))
	for room in site.architecture.buildings:
		var outside: Vector2 = room.door+Vector2(0,120)
		var inside: Vector2 = site.move_actor(outside,Vector2(0,-220))
		check(inside.distance_to(outside+Vector2(0,-220)) < 1,"enter library through the physical doorway")
		check(not site.is_walkable(room.rect.position+Vector2(0,100)),"library side wall blocks walking")
		site.hero_at = inside
		site.architecture.update()
		check(not room.roofs[0].visible,"entering cuts away the roof")
		site.hero_at = outside
		site.architecture.update()
		check(room.roofs[0].visible,"leaving restores the roof")
	for child in site.scenery.get_children():
		if child.has_meta("source_model") and child.get_child_count() > 0:
			var scale: Vector3 = child.get_child(0).scale
			check(is_equal_approx(scale.x,scale.y) and is_equal_approx(scale.y,scale.z),"uniform asset scale: "+child.name)
	if DisplayServer.get_name() != "headless":
		screen.hud.hide()
		screen.marker_layer.hide()
		site.hero_at = site.SPAWN
		site.refresh_sprites()
		site.set_camera_focus(Vector2(2800,2900),true)
		site.camp_camera.size = 36
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/home-castle-courtyard-overview.png")
		site.hero_at = site.architecture.buildings[0].door+Vector2(0,-100)
		site.refresh_sprites()
		site.update_occlusion(1.0)
		site.architecture.update()
		site.set_camera_focus(site.hero_at,true)
		site.camp_camera.size = 12
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/home-library-interior.png")
	print("HOME LAYOUT: ",checks," checks, ",failures," failures; ",visited.size()," reachable grid points")
	screen.queue_free()
	await process_frame
	quit(1 if failures else 0)
